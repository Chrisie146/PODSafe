import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// Conditional import to access `dart:html` on web, and a stub on other platforms
import '../utils/web_utils_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:share_plus/share_plus.dart';

/// Comprehensive backup service that exports ALL company data in one organized ZIP
///
/// Backup structure:
/// ```
/// PODSafe_Backup_20251024_143022.zip
/// ├── README.txt
/// ├── backup_info.json (metadata)
/// ├── deliveries/
/// │   ├── deliveries.csv
/// │   └── images/
/// │       └── [all delivery images]
/// ├── drivers/
/// │   └── drivers.csv
/// ├── claims/
/// │   ├── claims.csv
/// │   ├── pdfs/
/// │   │   └── [claim PDFs]
/// │   └── images/
/// │       └── [all evidence images]
/// └── pods/
///     ├── pods.csv
///     ├── pdfs/
///     │   └── [POD PDFs]
///     └── images/
///         └── [all POD images]
/// ```
class ComprehensiveBackupService {
  static const String _deliveriesCollection = 'deliveries';
  static const String _driversCollection = 'drivers';
  static const String _claimsCollection = 'claims';
  static const String _podsCollection = 'pods';

  /// Main backup function - exports everything for a company
  static Future<void> backupAllData({
    required String companyId,
    required Function(String message) onProgress,
  }) async {
    try {
      debugPrint('🔄 Starting comprehensive backup for company: $companyId');
      onProgress('Initializing backup...');

      // Create archive
      final archive = Archive();

      // 1. Add README
      onProgress('Creating backup structure...');
      final readmeBytes = _createReadme();
      archive.addFile(
        ArchiveFile('README.txt', readmeBytes.length, readmeBytes),
      );

      // 2. Add backup info (metadata)
      final backupInfo = {
        'backup_date': DateTime.now().toIso8601String(),
        'company_id': companyId,
        'app_version': '1.0.0',
        'backup_type': 'comprehensive',
      };
      final backupInfoBytes = utf8.encode(jsonEncode(backupInfo));
      archive.addFile(
        ArchiveFile(
          'backup_info.json',
          backupInfoBytes.length,
          backupInfoBytes,
        ),
      );

      // 3. Deliveries
      onProgress('Exporting deliveries...');
      try {
        await _addDeliveriesToArchive(archive, companyId, onProgress);
      } catch (e) {
        debugPrint('⚠️ Warning: Could not export deliveries: $e');
        onProgress('⚠️ Skipped deliveries (permission issue)');
      }

      // 4. Drivers
      onProgress('Exporting drivers...');
      try {
        await _addDriversToArchive(archive, companyId, onProgress);
      } catch (e) {
        debugPrint('⚠️ Warning: Could not export drivers: $e');
        onProgress('⚠️ Skipped drivers (permission issue)');
      }

      // 5. Claims
      onProgress('Exporting claims...');
      try {
        await _addClaimsToArchive(archive, companyId, onProgress);
      } catch (e) {
        debugPrint('⚠️ Warning: Could not export claims: $e');
        onProgress('⚠️ Skipped claims (permission issue)');
      }

      // 6. PODs
      onProgress('Exporting PODs...');
      try {
        await _addPodsToArchive(archive, companyId, onProgress);
      } catch (e) {
        debugPrint('⚠️ Warning: Could not export PODs: $e');
        onProgress('⚠️ Skipped PODs (permission issue)');
      }

      // 7. Verify archive has content
      if (archive.isEmpty) {
        throw Exception('No data was exported. Please check your permissions.');
      }

      // 8. Create ZIP and download
      onProgress('Creating backup file...');
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      if (zipBytes.isEmpty) {
        throw Exception('Failed to create ZIP file. Please try again.');
      }

      debugPrint('✅ ZIP created: ${zipBytes.length} bytes, ${archive.length} files');

      onProgress('Downloading backup...');
      _downloadFile(
        'PODSafe_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip',
        zipBytes,
      );

      // 9. Update last backup timestamp in Firestore
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .update({
        'lastBackupDate': DateTime.now(),
        'backupCount': FieldValue.increment(1),
      });

      debugPrint('✅ Backup completed successfully');
      onProgress('Backup complete! File downloading...');
    } catch (e) {
      debugPrint('❌ Backup error: $e');
      rethrow;
    }
  }

  /// Add deliveries and their images to archive
  static Future<void> _addDeliveriesToArchive(
    Archive archive,
    String companyId,
    Function(String message) onProgress,
  ) async {
    try {
      debugPrint('🔍 Querying deliveries for company: $companyId');
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection(_deliveriesCollection)
          .where('companyId', isEqualTo: companyId)
          .limit(1000)
          .get();

      debugPrint('📦 Found ${deliveriesSnapshot.docs.length} delivery documents');

      final rows = <List<String>>[
        [
          'Invoice',
          'Customer Name',
          'Address',
          'Phone',
          'Scheduled Date',
          'Driver Email',
          'Status',
          'Notes',
          'Created Date',
          'Has Images',
        ]
      ];

      final imageUrls = <String>[];

      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data();
        debugPrint('📄 Processing delivery: ${doc.id} - Invoice: ${data['invoiceNumber']}');
        
        rows.add([
          data['invoiceNumber']?.toString() ?? 'N/A',
          data['customerName']?.toString() ?? 'N/A',
          data['customerAddress']?.toString() ?? 'N/A',
          data['customerPhone']?.toString() ?? 'N/A',
          data['scheduledDate']?.toString() ?? 'N/A',
          data['driverEmail']?.toString() ?? 'N/A',
          data['status']?.toString() ?? 'N/A',
          data['notes']?.toString() ?? 'N/A',
          data['createdAt']?.toString() ?? 'N/A',
          (data['photoUrls'] != null && (data['photoUrls'] as List).isNotEmpty)
              ? 'Yes'
              : 'No',
        ]);

        // Collect image URLs
        if (data['photoUrls'] != null && data['photoUrls'] is List) {
          final urls = (data['photoUrls'] as List)
              .whereType<String>()
              .toList();
          debugPrint('🖼️ Found ${urls.length} images for delivery ${doc.id}');
          imageUrls.addAll(urls);
        }
      }

      debugPrint('📊 Total data rows (excluding header): ${rows.length - 1}');
      debugPrint('🖼️ Total image URLs collected: ${imageUrls.length}');

      // Add CSV
      final csvData = const ListToCsvConverter().convert(rows);
      final csvBytes = utf8.encode(csvData);
      debugPrint('💾 CSV size: ${csvBytes.length} bytes, ${rows.length} rows total');
      
      // Debug: show first data row if exists
      if (rows.length > 1) {
        debugPrint('📋 Sample row: ${rows[1].take(3).join(", ")}...');
      }
      
      archive.addFile(
        ArchiveFile(
          'deliveries/deliveries.csv',
          csvBytes.length,
          csvBytes,
        ),
      );

      // Download and add images
      if (imageUrls.isNotEmpty) {
        onProgress('Downloading ${imageUrls.length} delivery images...');
        await _addImagesToArchive(archive, imageUrls, 'deliveries/images/');
      }

      final dataRowCount = rows.length - 1; // Exclude header
      onProgress('✅ Added $dataRowCount deliveries to backup');
      debugPrint('✅ Added $dataRowCount deliveries to backup');
    } catch (e) {
      debugPrint('❌ Error adding deliveries: $e');
      rethrow;
    }
  }

  /// Add drivers to archive
  static Future<void> _addDriversToArchive(
    Archive archive,
    String companyId,
    Function(String message) onProgress,
  ) async {
    try {
      // Try to get drivers - may fail if drivers collection has permission issues
      final driversSnapshot = await FirebaseFirestore.instance
          .collection(_driversCollection)
          .where('companyId', isEqualTo: companyId)
          .limit(1000)
          .get();

      final rows = <List<String>>[
        [
          'Name',
          'Email',
          'Phone',
          'License Number',
          'Status',
          'Approved Date',
          'Created Date',
        ]
      ];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        rows.add([
          data['name']?.toString() ?? 'N/A',
          data['email']?.toString() ?? 'N/A',
          data['phone']?.toString() ?? 'N/A',
          data['licenseNumber']?.toString() ?? 'N/A',
          data['status']?.toString() ?? 'N/A',
          data['approvedDate']?.toString() ?? 'N/A',
          data['createdAt']?.toString() ?? 'N/A',
        ]);
      }

      // Add CSV
      final csvData = const ListToCsvConverter().convert(rows);
      final csvBytes = utf8.encode(csvData);
      archive.addFile(
        ArchiveFile(
          'drivers/drivers.csv',
          csvBytes.length,
          csvBytes,
        ),
      );

      debugPrint('✅ Added ${rows.length} drivers to backup');
    } catch (e) {
      debugPrint('❌ Error adding drivers: $e');
      rethrow;
    }
  }

  /// Add claims and their evidence to archive
  static Future<void> _addClaimsToArchive(
    Archive archive,
    String companyId,
    Function(String message) onProgress,
  ) async {
    try {
      debugPrint('🔍 Querying claims for company: $companyId');
    // Claims are stored under each company document: companies/{companyId}/claims
    final claimsSnapshot = await FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection(_claimsCollection)
      .limit(1000)
      .get();

      debugPrint('📦 Found ${claimsSnapshot.docs.length} claim documents');

      final rows = <List<String>>[
        [
          'Claim ID',
          'Invoice',
          'Driver Name',
          'Type',
          'Description',
          'Status',
          'Amount (ZAR)',
          'Created Date',
          'Updated Date',
          'Has Evidence',
        ]
      ];

      final imageUrls = <String>[];

      for (var doc in claimsSnapshot.docs) {
        final data = doc.data();
        debugPrint('📄 Processing claim: ${doc.id}');
        
        rows.add([
          doc.id,
          data['invoiceNumber']?.toString() ?? 'N/A',
          data['driverName']?.toString() ?? 'N/A',
          data['type']?.toString() ?? 'N/A',
          data['description']?.toString() ?? 'N/A',
          data['status']?.toString() ?? 'N/A',
          data['amount']?.toString() ?? '0.00',
          data['createdAt']?.toString() ?? 'N/A',
          data['updatedAt']?.toString() ?? 'N/A',
          _hasEvidence(data) ? 'Yes' : 'No',
        ]);

        // Collect image URLs
        if (data['photoUrls'] != null && data['photoUrls'] is List) {
          final urls = (data['photoUrls'] as List)
              .whereType<String>()
              .toList();
          debugPrint('🖼️ Found ${urls.length} photo URLs for claim ${doc.id}');
          imageUrls.addAll(urls);
        }
        if (data['customerSignature'] != null) {
          debugPrint('✍️ Found customer signature for claim ${doc.id}');
          imageUrls.add(data['customerSignature'].toString());
        }
        if (data['approvalSignature'] != null) {
          debugPrint('✍️ Found approval signature for claim ${doc.id}');
          imageUrls.add(data['approvalSignature'].toString());
        }
      }

      debugPrint('📊 Total data rows (excluding header): ${rows.length - 1}');
      debugPrint('🖼️ Total image URLs collected: ${imageUrls.length}');

      // Add CSV
      final csvData = const ListToCsvConverter().convert(rows);
      final csvBytes = utf8.encode(csvData);
      debugPrint('💾 CSV size: ${csvBytes.length} bytes');
      
      archive.addFile(
        ArchiveFile(
          'claims/claims.csv',
          csvBytes.length,
          csvBytes,
        ),
      );

      // Download and add images
      if (imageUrls.isNotEmpty) {
        onProgress('Downloading ${imageUrls.length} claim images...');
        await _addImagesToArchive(archive, imageUrls, 'claims/images/');
      }

      final dataRowCount = rows.length - 1;
      onProgress('✅ Added $dataRowCount claims to backup');
      debugPrint('✅ Added $dataRowCount claims to backup');
    } catch (e) {
      debugPrint('❌ Error adding claims: $e');
      rethrow;
    }
  }

  /// Add PODs and their images to archive
  static Future<void> _addPodsToArchive(
    Archive archive,
    String companyId,
    Function(String message) onProgress,
  ) async {
    try {
      debugPrint('🔍 Querying PODs for company: $companyId');
      final podsSnapshot = await FirebaseFirestore.instance
          .collection(_podsCollection)
          .where('companyId', isEqualTo: companyId)
          .limit(1000)
          .get();

      debugPrint('📦 Found ${podsSnapshot.docs.length} POD documents');

      final rows = <List<String>>[
        [
          'POD ID',
          'Invoice',
          'Customer Name',
          'Driver Name',
          'Status',
          'Delivered Date',
          'Created Date',
          'Has Signature',
          'Has Photos',
        ]
      ];

      final imageUrls = <String>[];

      for (var doc in podsSnapshot.docs) {
        final data = doc.data();
        debugPrint('📄 Processing POD: ${doc.id}');
        
        final hasPhotos =
            data['photoUrls'] != null && (data['photoUrls'] as List).isNotEmpty;
        final hasSignature =
            data['signatureUrl'] != null && data['signatureUrl'].toString().isNotEmpty;

        rows.add([
          doc.id,
          data['invoiceNumber']?.toString() ?? 'N/A',
          data['customerName']?.toString() ?? 'N/A',
          data['driverName']?.toString() ?? 'N/A',
          data['status']?.toString() ?? 'N/A',
          data['deliveredDate']?.toString() ?? 'N/A',
          data['createdAt']?.toString() ?? 'N/A',
          hasSignature ? 'Yes' : 'No',
          hasPhotos ? 'Yes' : 'No',
        ]);

        // Collect image URLs
        if (data['photoUrls'] != null && data['photoUrls'] is List) {
          final urls = (data['photoUrls'] as List)
              .whereType<String>()
              .toList();
          debugPrint('🖼️ Found ${urls.length} photo URLs for POD ${doc.id}');
          imageUrls.addAll(urls);
        }
        if (data['signatureUrl'] != null && data['signatureUrl'].toString().isNotEmpty) {
          debugPrint('✍️ Found signature for POD ${doc.id}');
          imageUrls.add(data['signatureUrl'].toString());
        }
      }

      debugPrint('📊 Total data rows (excluding header): ${rows.length - 1}');
      debugPrint('🖼️ Total image URLs collected: ${imageUrls.length}');

      // Add CSV
      final csvData = const ListToCsvConverter().convert(rows);
      final csvBytes = utf8.encode(csvData);
      debugPrint('💾 CSV size: ${csvBytes.length} bytes');
      
      archive.addFile(
        ArchiveFile(
          'pods/pods.csv',
          csvBytes.length,
          csvBytes,
        ),
      );

      // Download and add images
      if (imageUrls.isNotEmpty) {
        onProgress('Downloading ${imageUrls.length} POD images...');
        await _addImagesToArchive(archive, imageUrls, 'pods/images/');
      }

      final dataRowCount = rows.length - 1;
      onProgress('✅ Added $dataRowCount PODs to backup');
      debugPrint('✅ Added $dataRowCount PODs to backup');
    } catch (e) {
      debugPrint('❌ Error adding PODs: $e');
      rethrow;
    }
  }

  /// Download images and add to archive
  static Future<void> _addImagesToArchive(
    Archive archive,
    List<String> imageUrls,
    String archivePath,
  ) async {
    try {
      debugPrint('🖼️ Starting download of ${imageUrls.length} images to $archivePath');
      int imageCount = 0;
      int failedCount = 0;
      
      for (int i = 0; i < imageUrls.length; i++) {
        final url = imageUrls[i];
        try {
          debugPrint('⬇️ Downloading image ${i + 1}/${imageUrls.length}: $url');
          final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

          if (response.statusCode == 200) {
            // Extract filename from URL or create one
            final fileName = _extractImageFileName(url, imageCount);
            final imageBytes = response.bodyBytes;
            debugPrint('✅ Downloaded ${imageBytes.length} bytes -> $archivePath$fileName');
            
            archive.addFile(
              ArchiveFile(
                '$archivePath$fileName',
                imageBytes.length,
                imageBytes,
              ),
            );
            imageCount++;
          } else {
            debugPrint('❌ HTTP ${response.statusCode} for $url');
            failedCount++;
          }
        } catch (e) {
          debugPrint('⚠️ Could not download image $url: $e');
          failedCount++;
          // Continue with other images
        }
      }
      
      debugPrint('📊 Image download complete: $imageCount succeeded, $failedCount failed');
      if (imageCount > 0) {
        debugPrint('✅ Added $imageCount images to backup');
      }
    } catch (e) {
      debugPrint('❌ Error adding images: $e');
      // Don't rethrow - backup continues without images
    }
  }

  /// Extract filename from URL or create one
  static String _extractImageFileName(String url, int index) {
    try {
      final uri = Uri.parse(url);
      // Decode the path to handle URL-encoded characters
      final decodedPath = Uri.decodeComponent(uri.path);
      final pathSegments = decodedPath.split('/');
      
      if (pathSegments.isNotEmpty) {
        // Get the last segment (filename)
        String fileName = pathSegments.last;
        
        // Clean up the filename - remove any remaining special chars
        fileName = fileName.replaceAll(RegExp(r'[<>:"|?*]'), '_');
        
        if (fileName.isNotEmpty && fileName.contains('.')) {
          debugPrint('📝 Extracted filename: $fileName');
          return fileName;
        }
      }
    } catch (e) {
      debugPrint('Could not extract filename: $e');
    }
    
    // Fallback: create a simple numbered filename
    final fallbackName = 'image_${index.toString().padLeft(4, '0')}.jpg';
    debugPrint('📝 Using fallback filename: $fallbackName');
    return fallbackName;
  }

  /// Check if claim has evidence
  static bool _hasEvidence(Map<String, dynamic> claimData) {
    final hasPhotos = claimData['photoUrls'] != null &&
        (claimData['photoUrls'] as List).isNotEmpty;
    final hasCustomerSig = claimData['customerSignature'] != null;
    final hasApprovalSig = claimData['approvalSignature'] != null;

    return hasPhotos || hasCustomerSig || hasApprovalSig;
  }

  /// Create README content
  static List<int> _createReadme() {
    final content = '''
PODSafe COMPREHENSIVE BACKUP
============================

Backup Date: ${DateTime.now().toString()}
Version: 1.0.0

CONTENTS
--------
This backup contains:
✓ All Deliveries (CSV + Images)
✓ All Drivers (CSV)
✓ All Claims (CSV + Evidence Images)
✓ All PODs (CSV + Images)

FOLDER STRUCTURE
----------------
PODSafe_Backup_YYYYMMDD_HHMMSS.zip
├── README.txt (this file)
├── backup_info.json (backup metadata)
├── deliveries/
│   ├── deliveries.csv
│   └── images/ (delivery photos)
├── drivers/
│   └── drivers.csv
├── claims/
│   ├── claims.csv
│   └── images/ (photos, signatures, evidence)
└── pods/
    ├── pods.csv
    └── images/ (delivery photos, signatures)

HOW TO USE
----------
1. Extract the ZIP file to a safe location
2. Open CSV files in Excel, Google Sheets, or any spreadsheet application
3. View images in images/ subfolders
4. Keep this backup file for record-keeping and disaster recovery

RECOVERY
--------
If you need to restore data:
1. Extract the backup ZIP file
2. Contact PODSafe support with the backup files
3. We can restore your data to the system

KEEP SAFE
---------
This backup contains ALL your company data:
- Customer delivery information
- Driver details
- Claims and evidence
- Proof of Delivery records

Store backups in a secure location (cloud storage, external drive, etc.)

Questions? Contact PODSafe Support
''';

    return utf8.encode(content);
  }

  /// Save and share file on mobile platforms
  static Future<void> _downloadFile(String filename, List<int> bytes) async {
    try {
      // On web we can't use path_provider - trigger a browser download instead
      if (kIsWeb) {
        try {
          final blob = html.Blob([bytes], 'application/zip');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', filename);
          anchor.click();
          html.Url.revokeObjectUrl(url);
          return;
        } catch (e) {
          debugPrint('Web download failed: $e');
          throw Exception('Failed to download backup file on web: $e');
        }
      }

      // Native platforms - get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';

      // Write the file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Share the file
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: 'PODSafe Backup: $filename');
    } on MissingPluginException catch (e) {
      // This can happen in some environments (web, tests) where the plugin isn't
      // available/registered. If we're on web, fallback to a browser download. If
      // not, rethrow an explanatory exception.
      debugPrint('MissingPluginException while saving backup: $e');
      if (kIsWeb) {
        try {
          final blob = html.Blob([bytes], 'application/zip');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', filename);
          anchor.click();
          html.Url.revokeObjectUrl(url);
          return;
        } catch (e2) {
          debugPrint('Web fallback download failed: $e2');
          throw Exception('Failed to save backup file: $e2');
        }
      }
      throw Exception('Failed to save backup file: $e');
    } catch (e) {
      debugPrint('Error saving/sharing backup file: $e');
      throw Exception('Failed to save backup file: $e');
    }
  }
}
