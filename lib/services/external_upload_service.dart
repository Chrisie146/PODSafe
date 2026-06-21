import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/external_delivery_token.dart';
import '../models/delivery_model.dart';

class ExternalUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Create a new upload token for a delivery
  Future<ExternalDeliveryToken> createUploadToken({
    required String deliveryId,
    required String companyId,
    required String providerName,
    String? providerContact,
    int? expiryDays, // Optional expiry (e.g., 7 days)
  }) async {
    final token = ExternalDeliveryToken.generateToken();
    final now = DateTime.now();
    
    final tokenData = ExternalDeliveryToken(
      id: token,
      deliveryId: deliveryId,
      companyId: companyId,
      providerName: providerName,
      providerContact: providerContact,
      createdAt: now,
      expiresAt: expiryDays != null ? now.add(Duration(days: expiryDays)) : null,
    );

    // Save to Firestore
    await _firestore
        .collection('external_delivery_tokens')
        .doc(token)
        .set(tokenData.toFirestore());

    // Update delivery with the token
    await _firestore.collection('deliveries').doc(deliveryId).update({
      'uploadToken': token,
    });

    return tokenData;
  }

  /// Validate and retrieve token information
  Future<ExternalDeliveryToken?> getToken(String token) async {
    try {
      final doc = await _firestore
          .collection('external_delivery_tokens')
          .doc(token)
          .get();

      if (!doc.exists) return null;

      final tokenData = ExternalDeliveryToken.fromFirestore(doc);
      
      // Check if token is valid
      if (!tokenData.isValid()) return null;

      return tokenData;
    } catch (e) {
      debugPrint('Error getting token: $e');
      return null;
    }
  }

  /// Get delivery information for the token
  Future<Delivery?> getDeliveryForToken(String token) async {
    try {
      final tokenData = await getToken(token);
      if (tokenData == null) return null;

      final deliveryDoc = await _firestore
          .collection('deliveries')
          .doc(tokenData.deliveryId)
          .get();

      if (!deliveryDoc.exists) return null;

      return Delivery.fromFirestore(deliveryDoc);
    } catch (e) {
      debugPrint('Error getting delivery for token: $e');
      return null;
    }
  }

  /// Upload documents using the token
  Future<bool> uploadDocuments({
    required String token,
    required List<File> files,
    String? notes,
  }) async {
    try {
      final tokenData = await getToken(token);
      if (tokenData == null) {
        debugPrint('Invalid or expired token');
        return false;
      }

      // Upload files to Firebase Storage
      final uploadedUrls = <String>[];
      
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName = 'third_party_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = _storage.ref().child(
          'companies/${tokenData.companyId}/deliveries/${tokenData.deliveryId}/third_party/$fileName'
        );

        final uploadTask = await storageRef.putFile(file);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      }

      // Update token as used with uploaded files
      await _firestore
          .collection('external_delivery_tokens')
          .doc(token)
          .update({
        'isUsed': true,
        'uploadedFiles': uploadedUrls,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadNotes': notes,
      });

      // Update delivery with the uploaded documents
      await _firestore
          .collection('deliveries')
          .doc(tokenData.deliveryId)
          .update({
        'thirdPartyDocs': uploadedUrls,
        'status': 'delivered', // Auto-mark as delivered when docs uploaded
      });

      debugPrint('Successfully uploaded ${uploadedUrls.length} files');
      return true;
    } catch (e) {
      debugPrint('Error uploading documents: $e');
      return false;
    }
  }

  /// Upload documents from web (using bytes instead of File)
  Future<bool> uploadDocumentsWeb({
    required String token,
    required List<Uint8List> filesBytes,
    required List<String> fileNames,
    String? notes,
  }) async {
    try {
      final tokenData = await getToken(token);
      if (tokenData == null) {
        debugPrint('Invalid or expired token');
        return false;
      }

      // Upload files to Firebase Storage
      final uploadedUrls = <String>[];
      
      for (int i = 0; i < filesBytes.length; i++) {
        final bytes = filesBytes[i];
        final fileName = 'third_party_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = _storage.ref().child(
          'companies/${tokenData.companyId}/deliveries/${tokenData.deliveryId}/third_party/$fileName'
        );

        final uploadTask = await storageRef.putData(bytes);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      }

      // Update token as used with uploaded files
      await _firestore
          .collection('external_delivery_tokens')
          .doc(token)
          .update({
        'isUsed': true,
        'uploadedFiles': uploadedUrls,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadNotes': notes,
      });

      // Update delivery with the uploaded documents
      await _firestore
          .collection('deliveries')
          .doc(tokenData.deliveryId)
          .update({
        'thirdPartyDocs': uploadedUrls,
        'status': 'delivered', // Auto-mark as delivered when docs uploaded
      });

      debugPrint('Successfully uploaded ${uploadedUrls.length} files');
      return true;
    } catch (e) {
      debugPrint('Error uploading documents: $e');
      return false;
    }
  }

  /// Generate shareable upload link
  String generateUploadLink(String token, {String? baseUrl}) {
    // Use provided baseUrl, or default to Firebase hosting URL
    // For production, this should be your custom domain or Firebase hosting URL
    final base = baseUrl ?? 'https://podsafe-92a3e.web.app';
    return '$base/upload/$token';
  }

  /// Revoke/invalidate a token
  Future<void> revokeToken(String token) async {
    await _firestore
        .collection('external_delivery_tokens')
        .doc(token)
        .update({
      'isUsed': true,
      'expiresAt': Timestamp.now(),
    });
  }
}
