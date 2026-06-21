import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/ocr_fields_model.dart';
import '../models/delivery_model.dart';

/// Repository for POD document operations (upload, save, matching)
class PodRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  PodRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Upload an image to Firebase Storage
  /// Returns the storage path (e.g., gs://bucket/pods/uid/2024/10/uuid.jpg)
  Future<String> uploadImage(
    XFile image, {
    required String uid,
    required String companyId,
  }) async {
    try {
      final timestamp = DateTime.now();
      final fileName = const Uuid().v4();
      
      final path = 'pods/$companyId/$uid/${timestamp.year}/'
          '${timestamp.month.toString().padLeft(2, '0')}/$fileName.jpg';

      final ref = _storage.ref(path);
      final file = await image.readAsBytes();
      
      await ref.putData(file);
      final downloadUrl = await ref.getDownloadURL();

      if (kDebugMode) {
        print('Image uploaded to: $path');
        print('Download URL: $downloadUrl');
      }

      return path;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      rethrow;
    }
  }

  /// Save POD document to Firestore
  Future<String> savePodDocument({
    required String companyId,
    required String driverId,
    required String storagePath,
    required OcrFields fields,
    required DetectionFlags flags,
    String? matchedDeliveryId,
  }) async {
    try {
      final doc = PodDocument(
        id: const Uuid().v4(),
        companyId: companyId,
        type: _detectDocumentType(fields),
        storagePath: storagePath,
        capturedAt: DateTime.now(),
        capturedByUid: driverId,
        fields: fields,
        flags: flags,
        matchedDeliveryId: matchedDeliveryId,
        status: _determineInitialStatus(fields, flags, matchedDeliveryId),
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .doc(doc.id)
          .set(doc.toFirestore());

      if (kDebugMode) {
        print('POD document saved: ${doc.id}');
      }

      return doc.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving POD document: $e');
      }
      rethrow;
    }
  }

  /// Try to auto-match a POD to an existing delivery
  /// Looks for deliveries with matching invoiceNo, branch/site, and date within ±2 days
  Future<String?> tryAutoMatchDelivery({
    required String companyId,
    required OcrFields fields,
  }) async {
    try {
      if (fields.invoiceNo == null || fields.documentDate == null) {
        return null;
      }

      // Build query filters
      Query query = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('deliveries')
          .where('invoiceNumber', isEqualTo: fields.invoiceNo);

      // Get all matching invoice numbers first (Firestore doesn't support OR on same field)
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('No deliveries found with invoiceNo: ${fields.invoiceNo}');
        }
        return null;
      }

      // Filter by date and branch/site
      final targetDate = fields.documentDate!;

      for (final doc in snapshot.docs) {
        final delivery = Delivery.fromFirestore(doc);

        // Check date match (±2 days)
        final daysDiff =
            delivery.scheduledDate.difference(targetDate).inDays.abs();
        if (daysDiff > 2) continue;

        // Check branch/site match
        final branchMatches = (fields.branch != null &&
                delivery.id.toLowerCase().contains(fields.branch!.toLowerCase())) ||
            (fields.site != null &&
                delivery.customerAddress
                    .toLowerCase()
                    .contains(fields.site!.toLowerCase()));

        if (branchMatches) {
          if (kDebugMode) {
            print(
                'Auto-matched POD to delivery: ${delivery.id} (invoiceNo: ${fields.invoiceNo})');
          }
          return delivery.id;
        }
      }

      if (kDebugMode) {
        print('No matching delivery found for invoiceNo: ${fields.invoiceNo}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error auto-matching delivery: $e');
      }
      return null; // Don't throw - matching failure is not critical
    }
  }

  /// Update POD document status
  Future<void> updatePodStatus(
    String companyId,
    String podId,
    String newStatus, {
    String? notes,
  }) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .doc(podId)
          .update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
        if (notes != null) 'notes': notes,
      });

      if (kDebugMode) {
        print('POD status updated: $podId -> $newStatus');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating POD status: $e');
      }
      rethrow;
    }
  }

  /// Link a POD to a delivery
  Future<void> linkPodToDelivery(
    String companyId,
    String podId,
    String deliveryId,
  ) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .doc(podId)
          .update({
        'matchedDeliveryId': deliveryId,
        'status': 'Pending Verification',
        'updatedAt': Timestamp.now(),
      });

      // Also update the delivery with POD reference
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('deliveries')
          .doc(deliveryId)
          .update({
        'podId': podId,
      });

      if (kDebugMode) {
        print('POD $podId linked to delivery $deliveryId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error linking POD to delivery: $e');
      }
      rethrow;
    }
  }

  /// Get POD document by ID
  Future<PodDocument?> getPodById(String companyId, String podId) async {
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .doc(podId)
          .get();

      if (doc.exists) {
        return PodDocument.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting POD: $e');
      }
      rethrow;
    }
  }

  /// Get PODs for a driver (recent first)
  Future<List<PodDocument>> getPodsByDriver(
    String companyId,
    String driverId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .where('capturedByUid', isEqualTo: driverId)
          .orderBy('capturedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => PodDocument.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting driver PODs: $e');
      }
      rethrow;
    }
  }

  /// Get PODs by status (for admin review)
  Future<List<PodDocument>> getPodsByStatus(
    String companyId,
    String status, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .where('status', isEqualTo: status)
          .orderBy('capturedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => PodDocument.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting PODs by status: $e');
      }
      rethrow;
    }
  }

  /// Helper: Detect document type from OCR fields
  String _detectDocumentType(OcrFields fields) {
    final text = (fields.ocrRawText ?? '').toLowerCase();

    if (text.contains('invoice') ||
        text.contains('total due') ||
        text.contains('tax invoice')) {
      return 'invoice';
    } else if (text.contains('delivery') ||
        text.contains('pod') ||
        text.contains('proof of delivery')) {
      return 'delivery_note';
    }

    return 'unknown';
  }

  /// Helper: Determine initial status based on document quality
  String _determineInitialStatus(
    OcrFields fields,
    DetectionFlags flags,
    String? matchedDeliveryId,
  ) {
    // If matched to a delivery, it's pending verification
    if (matchedDeliveryId != null) {
      return 'Pending Verification';
    }

    // If critical fields are missing, needs review
    if (fields.invoiceNo == null || fields.totalIncl == null) {
      return 'Needs Review';
    }

    // If not confident or has warnings, needs review
    if (!flags.ocrConfident || flags.warnings.isNotEmpty) {
      return 'Needs Review';
    }

    // If no signature/stamp detected, needs review
    if (!flags.hasSignature || !flags.hasStamp) {
      return 'Needs Review';
    }

    return 'Pending';
  }
}
