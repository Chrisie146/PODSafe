import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/pod_model.dart';

class PODService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();
  
  // Create new POD record
  Future<String> createPODRecord(PODRecord pod) async {
    try {
      DocumentReference ref = await _firestore
          .collection('pods')
          .add(pod.toFirestore());
      return ref.id;
    } catch (e) {
      print('Create POD error: $e');
      throw Exception('Failed to create POD record');
    }
  }
  
  // Update POD record
  Future<void> updatePODRecord(PODRecord pod) async {
    try {
      await _firestore
          .collection('pods')
          .doc(pod.id)
          .update(pod.copyWith(updatedAt: DateTime.now()).toFirestore());
    } catch (e) {
      print('Update POD error: $e');
      throw Exception('Failed to update POD record');
    }
  }
  
  // Get POD by ID
  Future<PODRecord?> getPODById(String podId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('pods')
          .doc(podId)
          .get();
      
      if (doc.exists) {
        return PODRecord.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Get POD error: $e');
      return null;
    }
  }
  
  // Get PODs for a company
  Stream<List<PODRecord>> getCompanyPODs(String companyId) {
    return _firestore
        .collection('pods')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PODRecord.fromFirestore(doc))
            .toList());
  }
  
  // Get PODs for a specific driver
  Stream<List<PODRecord>> getDriverPODs(String driverId) {
    return _firestore
        .collection('pods')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PODRecord.fromFirestore(doc))
            .toList());
  }
  
  // Get POD by delivery ID
  Future<PODRecord?> getPODByDeliveryId(String deliveryId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('pods')
          .where('deliveryId', isEqualTo: deliveryId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return PODRecord.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Get POD by delivery error: $e');
      return null;
    }
  }
  
  // Upload signature image
  Future<String> uploadSignature(Uint8List signatureBytes, String deliveryId) async {
    try {
      String fileName = 'signatures/${deliveryId}_${_uuid.v4()}.png';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putData(
        signatureBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Upload signature error: $e');
      throw Exception('Failed to upload signature');
    }
  }
  
  // Upload photo
  Future<String> uploadPhoto(File photoFile, String deliveryId) async {
    try {
      String fileName = 'photos/${deliveryId}_${_uuid.v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putFile(
        photoFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Upload photo error: $e');
      throw Exception('Failed to upload photo');
    }
  }
  
  // Upload PDF
  Future<String> uploadPDF(Uint8List pdfBytes, String deliveryId) async {
    try {
      String fileName = 'pdfs/${deliveryId}_${_uuid.v4()}.pdf';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putData(
        pdfBytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
      
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Upload PDF error: $e');
      throw Exception('Failed to upload PDF');
    }
  }
  
  // Complete POD submission (with signature, photo, and PDF generation)
  Future<String> completePODSubmission({
    required String deliveryId,
    required String companyId,
    required String driverId,
    required String customerName,
    required String invoiceNumber,
    required String signedBy,
    required Uint8List signatureBytes,
    required File photoFile,
    required LocationData location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Upload signature and photo in parallel
      List<Future<String>> uploadTasks = [
        uploadSignature(signatureBytes, deliveryId),
        uploadPhoto(photoFile, deliveryId),
      ];
      
      List<String> uploadResults = await Future.wait(uploadTasks);
      String signatureUrl = uploadResults[0];
      String photoUrl = uploadResults[1];
      
      // Create POD record
      PODRecord pod = PODRecord(
        id: '', // Will be set by Firestore
        companyId: companyId,
        driverId: driverId,
        deliveryId: deliveryId,
        customerName: customerName,
        invoiceNumber: invoiceNumber,
        status: PODStatus.signed,
        timestamp: DateTime.now(),
        location: location,
        signedBy: signedBy,
        signatureUrl: signatureUrl,
        photoUrl: photoUrl,
        metadata: metadata ?? {},
        createdAt: DateTime.now(),
      );
      
      // Save POD record
      String podId = await createPODRecord(pod);
      
      return podId;
    } catch (e) {
      print('Complete POD submission error: $e');
      throw Exception('Failed to complete POD submission');
    }
  }
  
  // Get POD statistics
  Future<Map<String, int>> getPODStats(String companyId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore
          .collection('pods')
          .where('companyId', isEqualTo: companyId);
      
      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      QuerySnapshot snapshot = await query.get();
      
      Map<String, int> stats = {
        'total': 0,
        'signed': 0,
        'pending': 0,
        'missing': 0,
      };
      
      for (var doc in snapshot.docs) {
        PODRecord pod = PODRecord.fromFirestore(doc);
        stats['total'] = stats['total']! + 1;
        stats[pod.status.toString().split('.').last] = 
            (stats[pod.status.toString().split('.').last] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      print('Get POD stats error: $e');
      return {};
    }
  }
  
  // Delete POD record
  Future<void> deletePOD(String podId) async {
    try {
      await _firestore
          .collection('pods')
          .doc(podId)
          .delete();
    } catch (e) {
      print('Delete POD error: $e');
      throw Exception('Failed to delete POD record');
    }
  }
  
  // Search PODs
  Future<List<PODRecord>> searchPODs(String companyId, String searchTerm) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('pods')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      List<PODRecord> pods = snapshot.docs
          .map((doc) => PODRecord.fromFirestore(doc))
          .where((pod) =>
              pod.customerName.toLowerCase().contains(searchTerm.toLowerCase()) ||
              pod.invoiceNumber.toLowerCase().contains(searchTerm.toLowerCase()) ||
              (pod.signedBy?.toLowerCase().contains(searchTerm.toLowerCase()) ?? false))
          .toList();
      
      return pods;
    } catch (e) {
      print('Search PODs error: $e');
      return [];
    }
  }
}