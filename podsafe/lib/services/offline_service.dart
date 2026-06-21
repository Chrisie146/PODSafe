import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/delivery_model.dart';

class OfflineService {
  static const String _deliveriesKey = 'offline_deliveries';
  static const String _pendingPODsKey = 'pending_pods';
  static const String _syncQueueKey = 'sync_queue';
  
  // Check if device is online
  Future<bool> isOnline() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }
  
  // Stream to monitor connectivity changes
  Stream<ConnectivityResult> get connectivityStream => 
      Connectivity().onConnectivityChanged.map((results) => results.isNotEmpty ? results.first : ConnectivityResult.none);
  
  // Save deliveries for offline access
  Future<void> saveDeliveriesOffline(List<Delivery> deliveries) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> deliveryJsonList = deliveries
          .map((delivery) => jsonEncode(delivery.toFirestore()))
          .toList();
      
      await prefs.setStringList(_deliveriesKey, deliveryJsonList);
      print('Saved ${deliveries.length} deliveries for offline access');
    } catch (e) {
      print('Error saving deliveries offline: $e');
    }
  }
  
  // Get offline deliveries
  Future<List<Delivery>> getOfflineDeliveries() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? deliveryJsonList = prefs.getStringList(_deliveriesKey);
      
      if (deliveryJsonList != null) {
        List<Delivery> deliveries = deliveryJsonList
            .map((jsonString) {
              Map<String, dynamic> data = jsonDecode(jsonString);
              // Create a mock DocumentSnapshot-like object
              return Delivery(
                id: data['id'] ?? '',
                companyId: data['companyId'] ?? '',
                driverId: data['driverId'] ?? '',
                customerName: data['customerName'] ?? '',
                customerAddress: data['customerAddress'] ?? '',
                customerPhone: data['customerPhone'],
                invoiceNumber: data['invoiceNumber'] ?? '',
                items: (data['items'] as List<dynamic>?)
                    ?.map((item) => DeliveryItem.fromMap(item))
                    .toList() ?? [],
                status: DeliveryStatus.values.firstWhere(
                  (e) => e.toString().split('.').last == data['status'],
                  orElse: () => DeliveryStatus.pending,
                ),
                scheduledDate: DateTime.fromMillisecondsSinceEpoch(
                  data['scheduledDate'] ?? DateTime.now().millisecondsSinceEpoch,
                ),
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
                ),
                deliveredAt: data['deliveredAt'] != null 
                  ? DateTime.fromMillisecondsSinceEpoch(data['deliveredAt']) 
                  : null,
                notes: data['notes'],
                podId: data['podId'],
              );
            })
            .toList();
        
        print('Retrieved ${deliveries.length} deliveries from offline storage');
        return deliveries;
      }
      
      return [];
    } catch (e) {
      print('Error getting offline deliveries: $e');
      return [];
    }
  }
  
  // Save POD for later sync when online
  Future<void> savePendingPOD(Map<String, dynamic> podData) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? pendingPODs = prefs.getStringList(_pendingPODsKey) ?? [];
      
      podData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      podData['offlineId'] = DateTime.now().millisecondsSinceEpoch.toString();
      
      pendingPODs.add(jsonEncode(podData));
      await prefs.setStringList(_pendingPODsKey, pendingPODs);
      
      print('Saved POD for offline sync: ${podData['invoiceNumber']}');
    } catch (e) {
      print('Error saving pending POD: $e');
    }
  }
  
  // Get pending PODs to sync
  Future<List<Map<String, dynamic>>> getPendingPODs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? pendingPODs = prefs.getStringList(_pendingPODsKey);
      
      if (pendingPODs != null) {
        return pendingPODs
            .map((jsonString) => Map<String, dynamic>.from(jsonDecode(jsonString)))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting pending PODs: $e');
      return [];
    }
  }
  
  // Remove synced POD from pending list
  Future<void> removePendingPOD(String offlineId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? pendingPODs = prefs.getStringList(_pendingPODsKey) ?? [];
      
      pendingPODs.removeWhere((jsonString) {
        Map<String, dynamic> data = jsonDecode(jsonString);
        return data['offlineId'] == offlineId;
      });
      
      await prefs.setStringList(_pendingPODsKey, pendingPODs);
      print('Removed synced POD with offline ID: $offlineId');
    } catch (e) {
      print('Error removing pending POD: $e');
    }
  }
  
  // Clear all pending PODs
  Future<void> clearPendingPODs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingPODsKey);
      print('Cleared all pending PODs');
    } catch (e) {
      print('Error clearing pending PODs: $e');
    }
  }
  
  // Add operation to sync queue
  Future<void> addToSyncQueue(Map<String, dynamic> operation) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? syncQueue = prefs.getStringList(_syncQueueKey) ?? [];
      
      operation['queuedAt'] = DateTime.now().millisecondsSinceEpoch;
      operation['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      
      syncQueue.add(jsonEncode(operation));
      await prefs.setStringList(_syncQueueKey, syncQueue);
      
      print('Added operation to sync queue: ${operation['type']}');
    } catch (e) {
      print('Error adding to sync queue: $e');
    }
  }
  
  // Get sync queue
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? syncQueue = prefs.getStringList(_syncQueueKey);
      
      if (syncQueue != null) {
        return syncQueue
            .map((jsonString) => Map<String, dynamic>.from(jsonDecode(jsonString)))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting sync queue: $e');
      return [];
    }
  }
  
  // Remove operation from sync queue
  Future<void> removeFromSyncQueue(String operationId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? syncQueue = prefs.getStringList(_syncQueueKey) ?? [];
      
      syncQueue.removeWhere((jsonString) {
        Map<String, dynamic> data = jsonDecode(jsonString);
        return data['id'] == operationId;
      });
      
      await prefs.setStringList(_syncQueueKey, syncQueue);
      print('Removed operation from sync queue: $operationId');
    } catch (e) {
      print('Error removing from sync queue: $e');
    }
  }
  
  // Clear sync queue
  Future<void> clearSyncQueue() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncQueueKey);
      print('Cleared sync queue');
    } catch (e) {
      print('Error clearing sync queue: $e');
    }
  }
  
  // Save image file for offline use
  Future<String?> saveImageOffline(File imageFile, String fileName) async {
    try {
      // Get app documents directory
      Directory appDir = Directory('/storage/emulated/0/Android/data/com.podsafe.app/files');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      
      String filePath = '${appDir.path}/$fileName';
      File savedFile = await imageFile.copy(filePath);
      
      print('Saved image offline: $filePath');
      return savedFile.path;
    } catch (e) {
      print('Error saving image offline: $e');
      return null;
    }
  }
  
  // Get offline image file
  File? getOfflineImage(String filePath) {
    try {
      File file = File(filePath);
      if (file.existsSync()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting offline image: $e');
      return null;
    }
  }
  
  // Clean up old offline data
  Future<void> cleanupOfflineData({int maxDays = 7}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: maxDays));
      
      // Clean up pending PODs
      List<String>? pendingPODs = prefs.getStringList(_pendingPODsKey);
      if (pendingPODs != null) {
        List<String> validPODs = pendingPODs.where((jsonString) {
          Map<String, dynamic> data = jsonDecode(jsonString);
          DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
          return timestamp.isAfter(cutoffDate);
        }).toList();
        
        await prefs.setStringList(_pendingPODsKey, validPODs);
      }
      
      // Clean up sync queue
      List<String>? syncQueue = prefs.getStringList(_syncQueueKey);
      if (syncQueue != null) {
        List<String> validQueue = syncQueue.where((jsonString) {
          Map<String, dynamic> data = jsonDecode(jsonString);
          DateTime queuedAt = DateTime.fromMillisecondsSinceEpoch(data['queuedAt']);
          return queuedAt.isAfter(cutoffDate);
        }).toList();
        
        await prefs.setStringList(_syncQueueKey, validQueue);
      }
      
      print('Cleaned up offline data older than $maxDays days');
    } catch (e) {
      print('Error cleaning up offline data: $e');
    }
  }
  
  // Get offline storage statistics
  Future<Map<String, int>> getOfflineStats() async {
    try {
      List<Delivery> deliveries = await getOfflineDeliveries();
      List<Map<String, dynamic>> pendingPODs = await getPendingPODs();
      List<Map<String, dynamic>> syncQueue = await getSyncQueue();
      
      return {
        'deliveries': deliveries.length,
        'pendingPODs': pendingPODs.length,
        'syncQueue': syncQueue.length,
      };
    } catch (e) {
      print('Error getting offline stats: $e');
      return {};
    }
  }
}