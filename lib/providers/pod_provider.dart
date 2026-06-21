import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/pod_model.dart';
import '../services/pod_service.dart';
import '../services/offline_service.dart';

class PODProvider with ChangeNotifier {
  final PODService _podService = PODService();
  final OfflineService _offlineService = OfflineService();
  final Logger _logger = Logger();
  
  List<PODRecord> _pods = [];
  PODRecord? _currentPOD;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, int> _podStats = {};
  
  // Form data for POD creation
  String? _signedBy;
  Uint8List? _signatureData;
  File? _photoFile;
  LocationData? _location;
  
  // Getters
  List<PODRecord> get pods => _pods;
  PODRecord? get currentPOD => _currentPOD;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  Map<String, int> get podStats => _podStats;
  
  // Form getters
  String? get signedBy => _signedBy;
  Uint8List? get signatureData => _signatureData;
  File? get photoFile => _photoFile;
  LocationData? get location => _location;
  
  // Check if POD form is complete
  bool get isFormComplete => 
      _signedBy != null && 
      _signedBy!.isNotEmpty && 
      _signatureData != null && 
      _photoFile != null && 
      _location != null;
  
  // Load PODs for a company
  Future<void> loadCompanyPODs(String companyId) async {
    _setLoading(true);
    _clearError();
    
    try {
      _podService.getCompanyPODs(companyId).listen((pods) {
        _pods = pods;
        notifyListeners();
      });
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load PODs: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Load PODs for a driver
  Future<void> loadDriverPODs(String driverId) async {
    _setLoading(true);
    _clearError();
    
    try {
      _podService.getDriverPODs(driverId).listen((pods) {
        _pods = pods;
        notifyListeners();
      });
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load driver PODs: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Get POD by ID
  Future<void> loadPODById(String podId) async {
    _setLoading(true);
    _clearError();
    
    try {
      PODRecord? pod = await _podService.getPODById(podId);
      if (pod != null) {
        _currentPOD = pod;
      } else {
        _setError('POD not found');
      }
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load POD: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Get POD by delivery ID
  Future<void> loadPODByDeliveryId(String deliveryId) async {
    _setLoading(true);
    _clearError();
    
    try {
      PODRecord? pod = await _podService.getPODByDeliveryId(deliveryId);
      _currentPOD = pod;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load POD for delivery: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Set form data
  void setSignedBy(String name) {
    _signedBy = name;
    notifyListeners();
  }
  
  void setSignatureData(Uint8List data) {
    _signatureData = data;
    notifyListeners();
  }
  
  void setPhotoFile(File file) {
    _photoFile = file;
    notifyListeners();
  }
  
  void setLocation(LocationData locationData) {
    _location = locationData;
    notifyListeners();
  }
  
  // Clear form data
  void clearFormData() {
    _signedBy = null;
    _signatureData = null;
    _photoFile = null;
    _location = null;
    _currentPOD = null;
    notifyListeners();
  }
  
  // Submit POD
  Future<bool> submitPOD({
    required String deliveryId,
    required String companyId,
    required String driverId,
    required String customerName,
    required String invoiceNumber,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isFormComplete) {
      _setError('Please complete all required fields');
      return false;
    }
    
    _setSubmitting(true);
    _clearError();
    
    try {
      bool isOnline = await _offlineService.isOnline();
      
      if (isOnline) {
        // Submit online
        String podId = await _podService.completePODSubmission(
          deliveryId: deliveryId,
          companyId: companyId,
          driverId: driverId,
          customerName: customerName,
          invoiceNumber: invoiceNumber,
          signedBy: _signedBy!,
          signatureBytes: _signatureData!,
          photoFile: _photoFile!,
          location: _location!,
          metadata: metadata,
        );
        
        // Update delivery with POD reference
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(deliveryId)
            .update({
              'podId': podId,
              'status': 'delivered',
              'deliveredAt': FieldValue.serverTimestamp(),
            });
        
        _currentPOD = await _podService.getPODById(podId);
        clearFormData();
        _setSubmitting(false);
        notifyListeners();
        return true;
      } else {
        // Save for offline sync
        String? offlinePhotoPath = await _offlineService.saveImageOffline(
          _photoFile!,
          'pod_photo_${deliveryId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        
        if (offlinePhotoPath != null) {
          await _offlineService.savePendingPOD({
            'deliveryId': deliveryId,
            'companyId': companyId,
            'driverId': driverId,
            'customerName': customerName,
            'invoiceNumber': invoiceNumber,
            'signedBy': _signedBy!,
            'signatureData': _signatureData!.toList(), // Convert to List<int> for JSON
            'photoPath': offlinePhotoPath,
            'location': _location!.toMap(),
            'metadata': metadata ?? {},
            'status': 'pending_sync',
          });
          
          clearFormData();
          _setSubmitting(false);
          notifyListeners();
          return true;
        } else {
          _setError('Failed to save POD for offline sync');
          _setSubmitting(false);
          return false;
        }
      }
    } catch (e) {
      _setError('Failed to submit POD: ${e.toString()}');
      _setSubmitting(false);
      return false;
    }
  }
  
  // Create POD record directly
  Future<bool> createPODRecord(PODRecord pod) async {
    _setLoading(true);
    _clearError();
    
    try {
      String podId = await _podService.createPODRecord(pod);
      _currentPOD = pod.copyWith(id: podId);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to create POD record: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  // Update POD record
  Future<bool> updatePODRecord(PODRecord pod) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _podService.updatePODRecord(pod);
      _currentPOD = pod;
      
      // Update in local list
      int index = _pods.indexWhere((p) => p.id == pod.id);
      if (index != -1) {
        _pods[index] = pod;
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update POD record: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  // Load POD statistics
  Future<void> loadPODStats(String companyId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Map<String, int> stats = await _podService.getPODStats(
        companyId,
        startDate: startDate,
        endDate: endDate,
      );
      _podStats = stats;
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to load POD stats: $e');
    }
  }
  
  // Search PODs
  Future<void> searchPODs(String companyId, String searchTerm) async {
    _setLoading(true);
    _clearError();
    
    try {
      List<PODRecord> searchResults = await _podService.searchPODs(companyId, searchTerm);
      _pods = searchResults;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to search PODs: ${e.toString()}');
      _setLoading(false);
    }
  }
  
  // Upload individual files (for manual uploads)
  Future<String?> uploadSignature(Uint8List signatureBytes, String deliveryId) async {
    try {
      return await _podService.uploadSignature(signatureBytes, deliveryId);
    } catch (e) {
      _setError('Failed to upload signature: ${e.toString()}');
      return null;
    }
  }
  
  Future<String?> uploadPhoto(File photoFile, String deliveryId) async {
    try {
      return await _podService.uploadPhoto(photoFile, deliveryId);
    } catch (e) {
      _setError('Failed to upload photo: ${e.toString()}');
      return null;
    }
  }
  
  // Sync pending PODs when coming online
  Future<void> syncPendingPODs() async {
    try {
      bool isOnline = await _offlineService.isOnline();
      if (!isOnline) return;
      
      List<Map<String, dynamic>> pendingPODs = await _offlineService.getPendingPODs();
      
      for (Map<String, dynamic> podData in pendingPODs) {
        try {
          // Reconstruct signature data
          Uint8List signatureBytes = Uint8List.fromList(
            List<int>.from(podData['signatureData']),
          );
          
          // Get offline photo file
          File? photoFile = _offlineService.getOfflineImage(podData['photoPath']);
          if (photoFile == null) continue;
          
          // Submit the POD
          String podId = await _podService.completePODSubmission(
            deliveryId: podData['deliveryId'],
            companyId: podData['companyId'],
            driverId: podData['driverId'],
            customerName: podData['customerName'],
            invoiceNumber: podData['invoiceNumber'],
            signedBy: podData['signedBy'],
            signatureBytes: signatureBytes,
            photoFile: photoFile,
            location: LocationData.fromMap(podData['location']),
            metadata: Map<String, dynamic>.from(podData['metadata'] ?? {}),
          );
          
          // Update delivery with POD reference
          await FirebaseFirestore.instance
              .collection('deliveries')
              .doc(podData['deliveryId'])
              .update({
                'podId': podId,
                'status': 'delivered',
                'deliveredAt': FieldValue.serverTimestamp(),
              });
          
          // Remove from pending list
          await _offlineService.removePendingPOD(podData['offlineId']);
          
          _logger.i('Successfully synced POD: ${podData['invoiceNumber']} with ID: $podId');
        } catch (e) {
          _logger.e('Failed to sync POD: ${podData['invoiceNumber']}, error: $e');
        }
      }
      
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to sync pending PODs: $e');
    }
  }
  
  // Get pending PODs count (for offline indicator)
  Future<int> getPendingPODsCount() async {
    try {
      List<Map<String, dynamic>> pendingPODs = await _offlineService.getPendingPODs();
      return pendingPODs.length;
    } catch (e) {
      return 0;
    }
  }
  
  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setSubmitting(bool submitting) {
    _isSubmitting = submitting;
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
    _pods.clear();
    _currentPOD = null;
    _podStats.clear();
    clearFormData();
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }
}
