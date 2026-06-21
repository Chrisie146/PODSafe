import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

/// Service for handling file uploads to Firebase Storage
class FileUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image from device (web and mobile)
  static Future<XFile?> pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Upload image to Firebase Storage and return download URL
  static Future<String?> uploadCompanyLogo({
    required String companyId,
    required XFile imageFile,
  }) async {
    try {
      // Create a unique filename with timestamp
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'companies/$companyId/branding/$fileName';
      final ref = _storage.ref(storagePath);

      // Upload file - handle both web and mobile
      final UploadTask uploadTask;
      
      if (kIsWeb) {
        // On web, use bytes directly
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'uploadedBy': companyId},
          ),
        );
      } else {
        // On mobile, use File path
        uploadTask = ref.putFile(
          File(imageFile.path),
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'uploadedBy': companyId},
          ),
        );
      }

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Logo uploaded successfully: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Firebase storage error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      return null;
    }
  }

  /// Upload app logo to Firebase Storage
  static Future<String?> uploadAppLogo({
    required String companyId,
    required XFile imageFile,
  }) async {
    try {
      final fileName = 'app_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'companies/$companyId/branding/$fileName';
      final ref = _storage.ref(storagePath);

      // Handle both web and mobile
      final UploadTask uploadTask;
      
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'type': 'appLogo', 'uploadedBy': companyId},
          ),
        );
      } else {
        uploadTask = ref.putFile(
          File(imageFile.path),
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'type': 'appLogo', 'uploadedBy': companyId},
          ),
        );
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('App logo uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading app logo: $e');
      return null;
    }
  }

  /// Delete a file from Firebase Storage
  static Future<bool> deleteFile(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      await ref.delete();
      debugPrint('File deleted successfully: $storagePath');
      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  /// Get download URL for a file
  static Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      final String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error getting download URL: $e');
      return null;
    }
  }

  /// Get metadata for a file
  static Future<FullMetadata?> getFileMetadata(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      final metadata = await ref.getMetadata();
      return metadata;
    } catch (e) {
      debugPrint('Error getting file metadata: $e');
      return null;
    }
  }
}
