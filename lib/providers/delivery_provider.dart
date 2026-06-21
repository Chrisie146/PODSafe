import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';
import '../services/offline_service.dart';

class DeliveryProvider with ChangeNotifier {
  final DeliveryService _deliveryService = DeliveryService();
  final OfflineService _offlineService = OfflineService();
  final Logger _logger = Logger();
  
  List<Delivery> _deliveries = [];
  final List<Delivery> _todaysDeliveries = [];
  Delivery? _selectedDelivery;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, int> _deliveryStats = {};
  
  // Getters
  List<Delivery> get deliveries => _deliveries;
  List<Delivery> get todaysDeliveries => _todaysDeliveries;
  Delivery? get selectedDelivery => _selectedDelivery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, int> get deliveryStats => _deliveryStats;
  
  // Load deliveries for a driver
  Future<void> loadDriverDeliveries(String driverId) async {
    _setLoading(true);
    _clearError();
    
    try {
      bool isOnline = await _offlineService.isOnline();
      
      if (isOnline) {
        // Load from Firebase and cache offline
        _deliveryService.getDeliveriesForDriver(driverId).listen((deliveries) {
          _deliveries = deliveries;
          _offlineService.saveDeliveriesOffline(deliveries);
          notifyListeners();
        });
      } else {
        // Load from offline cache
        _deliveries = await _offlineService.getOfflineDeliveries();
        notifyListeners();
      }
      
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load deliveries: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Load today's deliveries for a driver
  Future<void> loadTodaysDeliveries(String driverId) async {
    _logger.i('📅 Loading today\'s deliveries for driver: $driverId');
    _setLoading(true);
    _clearError();
    
    try {
      DateTime today = DateTime.now();
      bool isOnline = await _offlineService.isOnline();
      
      if (isOnline) {
        // Load all driver deliveries and filter for today client-side
        // This avoids the need for a complex composite index
        // Get the stream and wait for first data
        final stream = _deliveryService.getDeliveriesForDriver(driverId);
        
        // Get the first emission from the stream
        final allDeliveries = await stream.first;
        
        _logger.i('📦 Filtering ${allDeliveries.length} deliveries for today');
        _deliveries = allDeliveries.where((delivery) {
          final isSameDay = delivery.scheduledDate.year == today.year &&
                 delivery.scheduledDate.month == today.month &&
                 delivery.scheduledDate.day == today.day;
          if (isSameDay) {
            _logger.i('   ✅ Today: ${delivery.customerName}');
          }
          return isSameDay;
        }).toList();
        _logger.i('📊 Found ${_deliveries.length} deliveries for today');
        
        // Now set up ongoing listener for real-time updates
        stream.listen((allDeliveries) {
          _logger.i('🔄 Real-time update: ${allDeliveries.length} deliveries');
          _deliveries = allDeliveries.where((delivery) {
            final isSameDay = delivery.scheduledDate.year == today.year &&
                   delivery.scheduledDate.month == today.month &&
                   delivery.scheduledDate.day == today.day;
            return isSameDay;
          }).toList();
          notifyListeners();
        });
        
        notifyListeners();
      } else {
        // Filter offline deliveries for today
        List<Delivery> allDeliveries = await _offlineService.getOfflineDeliveries();
        _deliveries = allDeliveries.where((delivery) {
          return delivery.scheduledDate.year == today.year &&
                 delivery.scheduledDate.month == today.month &&
                 delivery.scheduledDate.day == today.day;
        }).toList();
        notifyListeners();
      }
      
      _setLoading(false);
    } catch (e) {
      _logger.i('❌ Error loading today\'s deliveries: $e');
      _setError('Failed to load today\'s deliveries: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Force refresh today's deliveries - call this when navigating back to dashboard
  Future<void> refreshTodaysDeliveries(String driverId) async {
    _logger.i('🔄 Refreshing today\'s deliveries');
    // Simply call loadTodaysDeliveries again to pull fresh data
    await loadTodaysDeliveries(driverId);
  }
  
  // Load company deliveries (admin view)
  Future<void> loadCompanyDeliveries(String companyId) async {
    _setLoading(true);
    _clearError();
    
    try {
      _deliveryService.getCompanyDeliveries(companyId).listen((deliveries) {
        _deliveries = deliveries;
        notifyListeners();
      });
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load company deliveries: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Get delivery by ID
  Future<void> loadDeliveryById(String deliveryId) async {
    _setLoading(true);
    _clearError();
    
    try {
      Delivery? delivery = await _deliveryService.getDeliveryById(deliveryId);
      if (delivery != null) {
        _selectedDelivery = delivery;
      } else {
        _setError('Delivery not found');
      }
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load delivery: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Create new delivery
  Future<bool> createDelivery(Delivery delivery) async {
    _setLoading(true);
    _clearError();
    
    try {
      bool isOnline = await _offlineService.isOnline();
      
      if (isOnline) {
        String deliveryId = await _deliveryService.createDelivery(delivery);
        _selectedDelivery = delivery.copyWith(id: deliveryId);
        notifyListeners();
      } else {
        // Queue for sync when online
        await _offlineService.addToSyncQueue({
          'type': 'createDelivery',
          'data': delivery.toFirestore(),
        });
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to create delivery: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  // Update delivery
  Future<bool> updateDelivery(Delivery delivery) async {
    _setLoading(true);
    _clearError();
    
    try {
      bool isOnline = await _offlineService.isOnline();
      
      if (isOnline) {
        await _deliveryService.updateDelivery(delivery);
        _selectedDelivery = delivery;
        
        // Update in local list
        int index = _deliveries.indexWhere((d) => d.id == delivery.id);
        if (index != -1) {
          _deliveries[index] = delivery;
        }
        
        // Update in today's list
        int todayIndex = _todaysDeliveries.indexWhere((d) => d.id == delivery.id);
        if (todayIndex != -1) {
          _todaysDeliveries[todayIndex] = delivery;
        }
        
        notifyListeners();
      } else {
        // Queue for sync when online
        await _offlineService.addToSyncQueue({
          'type': 'updateDelivery',
          'data': delivery.toFirestore(),
          'id': delivery.id,
        });
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update delivery: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  // Update delivery status
  Future<bool> updateDeliveryStatus(String deliveryId, DeliveryStatus status) async {
    _setLoading(true);
    _clearError();
    
    try {
      bool isOnline = await _offlineService.isOnline();
      
      if (isOnline) {
        await _deliveryService.updateDeliveryStatus(deliveryId, status);
        
        // Update local delivery if it's selected
        if (_selectedDelivery?.id == deliveryId) {
          _selectedDelivery = _selectedDelivery!.copyWith(
            status: status,
            deliveredAt: status == DeliveryStatus.delivered ? DateTime.now() : null,
          );
        }
        
        notifyListeners();
      } else {
        // Queue for sync when online
        await _offlineService.addToSyncQueue({
          'type': 'updateDeliveryStatus',
          'deliveryId': deliveryId,
          'status': status.toString().split('.').last,
        });
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update delivery status: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  // Link POD to delivery
  Future<bool> linkPODToDelivery(String deliveryId, String podId) async {
    try {
      bool isOnline = await _offlineService.isOnline();
      
      if (isOnline) {
        await _deliveryService.linkPODToDelivery(deliveryId, podId);
        
        // Update local delivery
        if (_selectedDelivery?.id == deliveryId) {
          _selectedDelivery = _selectedDelivery!.copyWith(
            podId: podId,
            status: DeliveryStatus.delivered,
            deliveredAt: DateTime.now(),
          );
          notifyListeners();
        }
      } else {
        // Queue for sync when online
        await _offlineService.addToSyncQueue({
          'type': 'linkPODToDelivery',
          'deliveryId': deliveryId,
          'podId': podId,
        });
      }
      
      return true;
    } catch (e) {
      _setError('Failed to link POD to delivery: ${e.toString()}');
      return false;
    }
  }
  
  // Load delivery statistics
  Future<void> loadDeliveryStats(String companyId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Map<String, int> stats = await _deliveryService.getDeliveryStats(
        companyId,
        startDate: startDate,
        endDate: endDate,
      );
      _deliveryStats = stats;
      notifyListeners();
    } catch (e) {
      _logger.i('Failed to load delivery stats: $e');
    }
  }
  
  // Search deliveries
  Future<void> searchDeliveries(String companyId, String searchTerm) async {
    _setLoading(true);
    _clearError();
    
    try {
      List<Delivery> searchResults = await _deliveryService.searchDeliveries(companyId, searchTerm);
      _deliveries = searchResults;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to search deliveries: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Set selected delivery
  void setSelectedDelivery(Delivery delivery) {
    _selectedDelivery = delivery;
    notifyListeners();
  }
  
  // Clear selected delivery
  void clearSelectedDelivery() {
    _selectedDelivery = null;
    notifyListeners();
  }
  
  // Sync offline data when coming online
  Future<void> syncOfflineData() async {
    try {
      bool isOnline = await _offlineService.isOnline();
      if (!isOnline) return;
      
      List<Map<String, dynamic>> syncQueue = await _offlineService.getSyncQueue();
      
      for (Map<String, dynamic> operation in syncQueue) {
        try {
          switch (operation['type']) {
            case 'createDelivery':
              // Convert map back to delivery and create
              // This would need proper implementation based on your needs
              break;
            case 'updateDelivery':
              // Similar for updates
              break;
            case 'updateDeliveryStatus':
              await _deliveryService.updateDeliveryStatus(
                operation['deliveryId'],
                DeliveryStatus.values.firstWhere(
                  (e) => e.toString().split('.').last == operation['status'],
                ),
              );
              break;
            case 'linkPODToDelivery':
              await _deliveryService.linkPODToDelivery(
                operation['deliveryId'],
                operation['podId'],
              );
              break;
          }
          
          // Remove successful operation from queue
          await _offlineService.removeFromSyncQueue(operation['id']);
        } catch (e) {
          _logger.i('Failed to sync operation: ${operation['type']}, error: $e');
        }
      }
    } catch (e) {
      _logger.i('Failed to sync offline data: $e');
    }
  }
  
  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
  }
  
  // Clear all data
  void clearData() {
    _deliveries.clear();
    _todaysDeliveries.clear();
    _selectedDelivery = null;
    _deliveryStats.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
