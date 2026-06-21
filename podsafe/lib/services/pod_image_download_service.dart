import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

/// Service for downloading POD images and related files
class PODImageDownloadService {
  /// Download a single image (web and mobile)
  static Future<void> downloadImage(String imageUrl, String filename) async {
    try {
      debugPrint('📥 Downloading image: $filename from $imageUrl');
      
      if (kIsWeb) {
        // Web implementation: Download directly
        await _downloadImageWeb(imageUrl, filename);
      } else {
        // Mobile: Open in external application
        final uri = Uri.parse(imageUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not open URL: $imageUrl';
        }
      }
      
      debugPrint('✅ Image download initiated: $filename');
    } catch (e) {
      debugPrint('❌ Error downloading image: $e');
      rethrow;
    }
  }

  /// Download image on web platform
  static Future<void> _downloadImageWeb(String imageUrl, String filename) async {
    try {
      debugPrint('🌐 Web download starting for: $filename');
      
      // On web, simply open the URL with download parameter
      // Firebase Storage URLs support ?alt=media parameter for download
      final downloadUrl = imageUrl.contains('?')
          ? '$imageUrl&alt=media'
          : '$imageUrl?alt=media';
      
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        throw 'Could not launch download URL: $downloadUrl';
      }
      
      debugPrint('✅ Web download triggered for: $filename');
    } catch (e) {
      debugPrint('❌ Web download error: $e');
      rethrow;
    }
  }

  /// Download multiple images as a package
  static Future<void> downloadMultipleImages(
    Map<String, String> images,
    String podId,
  ) async {
    try {
      debugPrint('📥 Downloading ${images.length} POD images for POD: $podId');
      
      // Download each image
      for (final entry in images.entries) {
        final name = entry.key;
        final url = entry.value;
        final filename = '${podId}_$name';
        
        try {
          await downloadImage(url, filename);
          // Add delay between downloads to avoid overwhelming the system
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('⚠️ Failed to download $name: $e');
          // Continue with next image even if one fails
        }
      }
      
      debugPrint('✅ Batch download completed for POD: $podId');
    } catch (e) {
      debugPrint('❌ Error during batch download: $e');
      rethrow;
    }
  }

  /// Create a shareable download link (for web)
  static String createDownloadLink(String firebaseStorageUrl) {
    // Firebase Storage URLs are already directly downloadable
    // Add download parameter if needed
    if (firebaseStorageUrl.contains('?')) {
      return '$firebaseStorageUrl&alt=media';
    }
    return '$firebaseStorageUrl?alt=media';
  }

  /// Get suggested filename based on POD data
  static String generateFilename(
    String type, // 'signature', 'photo', 'stamp'
    String podId,
    String? customerName,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedCustomer = customerName
        ?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll('_+', '_')
        .toLowerCase() ??
        'customer';
    
    return '${podId}_${sanitizedCustomer}_${type}_$timestamp.jpg';
  }
}
