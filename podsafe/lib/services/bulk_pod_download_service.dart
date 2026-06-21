import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/vehicle_utils.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Platform-specific download
import 'bulk_pod_download_stub.dart' if (dart.library.html) 'bulk_pod_download_web.dart' as platform;

/// Service for bulk downloading PODs as zip files or CSV reports
class BulkPODDownloadService {
  /// Download multiple PODs as individual PDFs in a ZIP file
  static Future<void> downloadPODsAsZip({
    required List<String> podIds,
    required String companyId,
    required Function(double) onProgress, // Progress callback 0.0 to 1.0
  }) async {
    try {
      debugPrint('📦 Starting bulk POD PDF download as ZIP for ${podIds.length} PODs');
      onProgress(0.0);

      final archive = Archive();
      int processedCount = 0;

      for (final podId in podIds) {
        try {
          debugPrint('📄 Processing POD: $podId');

          // Fetch POD data from Firestore
          final podDoc = await FirebaseFirestore.instance
              .collection('pods')
              .doc(podId)
              .get();

          if (!podDoc.exists) {
            debugPrint('⚠️ POD not found: $podId');
            continue;
          }

          final podData = podDoc.data() as Map<String, dynamic>;

          // Verify company ID matches
          if (podData['companyId'] != companyId) {
            debugPrint('⚠️ POD company mismatch: $podId');
            continue;
          }

          // Fetch related delivery data
          final deliveryId = podData['deliveryId'];
          Map<String, dynamic>? deliveryData;
          if (deliveryId != null) {
            final deliveryDoc = await FirebaseFirestore.instance
                .collection('deliveries')
                .doc(deliveryId)
                .get();
            deliveryData = deliveryDoc.data();
          }

          // Generate PDF for this POD
          final pdfBytes = await _generatePODPDF(
            podId: podId,
            podData: podData,
            deliveryData: deliveryData,
          );

          if (pdfBytes != null && pdfBytes.isNotEmpty) {
            // Add to archive with safe filename
            final customerName = (podData['customerName'] ?? 'Unknown')
                .toString()
                .replaceAll(RegExp(r'[^\w\s-]'), '');
            final invoiceNumber = podData['invoiceNumber'] ?? 'NOINV';
            final filename = 'POD_${invoiceNumber}_${customerName}_${podId.substring(0, 8)}.pdf';

            archive.addFile(ArchiveFile(filename, pdfBytes.length, pdfBytes));
            debugPrint('✅ Added PDF to archive: $filename (${pdfBytes.length} bytes)');
          } else {
            debugPrint('⚠️ No PDF generated for POD: $podId');
          }

          processedCount++;
          onProgress(processedCount / podIds.length);
        } catch (e) {
          debugPrint('❌ Error processing POD $podId: $e');
          continue;
        }
      }

      if (archive.files.isEmpty) {
        debugPrint('⚠️ No PDF files added to archive');
      }

      // Create ZIP file
      final zipData = ZipEncoder().encode(archive);
      // Download ZIP
      await _downloadFile(
        Uint8List.fromList(zipData),
        'PODs_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.zip',
      );
      debugPrint('✅ PODs ZIP file downloaded successfully (${archive.files.length} files)');

      onProgress(1.0);
    } catch (e) {
      debugPrint('❌ Error in bulk POD download: $e');
      rethrow;
    }
  }

  /// Download POD images (photos, signatures) as a ZIP file
  static Future<void> downloadPODImagesAsZip({
    required List<String> podIds,
    required String companyId,
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('📦 Starting bulk POD image download for ${podIds.length} PODs');
      onProgress(0.0);

      final archive = Archive();
      int processedCount = 0;

      for (final podId in podIds) {
        try {
          // Fetch POD data
          final podDoc = await FirebaseFirestore.instance
              .collection('pods')
              .doc(podId)
              .get();

          if (!podDoc.exists) continue;

          final podData = podDoc.data() as Map<String, dynamic>;

          // Verify company ID matches - CRITICAL for security
          if (podData['companyId'] != companyId) {
            debugPrint('⚠️ Skipping POD from different company: $podId');
            continue;
          }

          final customerName =
              (podData['customerName'] ?? 'Unknown').toString().replaceAll(
                    RegExp(r'[^\w\s-]'),
                    '',
                  );

          // Download and add photos
          final photoUrls = (podData['photoUrls'] != null && podData['photoUrls'] is List)
              ? List<String>.from(podData['photoUrls'])
              : (podData['photoUrl'] != null ? [podData['photoUrl']] : []);
          for (int i = 0; i < photoUrls.length; i++) {
            final photoBytes = await _downloadImageFromUrl(photoUrls[i]);
            if (photoBytes != null) {
              final suffix = photoUrls.length == 1 ? '' : '_${i + 1}';
              archive.addFile(
                ArchiveFile(
                  'POD_${podId}_${customerName}_photo$suffix.jpg',
                  photoBytes.length,
                  photoBytes,
                ),
              );
              debugPrint('✅ Added photo: POD_${podId}_${customerName}_photo$suffix.jpg');
            }
          }

          // Download and add signature
          if (podData['signatureUrl'] != null) {
            final signatureBytes =
                await _downloadImageFromUrl(podData['signatureUrl']);
            if (signatureBytes != null) {
              archive.addFile(
                ArchiveFile(
                  'POD_${podId}_${customerName}_signature.png',
                  signatureBytes.length,
                  signatureBytes,
                ),
              );
              debugPrint('✅ Added signature: POD_${podId}_${customerName}_signature.png');
            }
          }

          // Download and add stamp photo
          if (podData['stampPhotoUrl'] != null) {
            final stampBytes =
                await _downloadImageFromUrl(podData['stampPhotoUrl']);
            if (stampBytes != null) {
              archive.addFile(
                ArchiveFile(
                  'POD_${podId}_${customerName}_stamp.jpg',
                  stampBytes.length,
                  stampBytes,
                ),
              );
              debugPrint('✅ Added stamp: POD_${podId}_${customerName}_stamp.jpg');
            }
          }

          processedCount++;
          onProgress(processedCount / podIds.length);
        } catch (e) {
          debugPrint('❌ Error processing images for POD $podId: $e');
          continue;
        }
      }

      if (archive.files.isEmpty) {
        debugPrint('⚠️ No image files added to archive');
      }

      // Create ZIP file
      final zipData = ZipEncoder().encode(archive);
      await _downloadFile(
        Uint8List.fromList(zipData),
        'POD_Images_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.zip',
      );
      debugPrint('✅ POD images ZIP downloaded successfully');

      onProgress(1.0);
    } catch (e) {
      debugPrint('❌ Error in bulk image download: $e');
      rethrow;
    }
  }

  /// Export POD data as CSV
  static Future<void> exportPODsAsCSV({
    required List<String> podIds,
    required String companyId,
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('📊 Exporting ${podIds.length} PODs to CSV');
      onProgress(0.0);

      final rows = <List<String>>[
        [
          'POD ID',
          'Invoice Number',
          'Customer Name',
          'Driver Name',
          'Delivery ID',
          'Status',
          'Timestamp',
          'Location',
          'Signed By',
          'Phone',
          'Address',
        ],
      ];

      int processedCount = 0;

      for (final podId in podIds) {
        try {
          final podDoc = await FirebaseFirestore.instance
              .collection('pods')
              .doc(podId)
              .get();

          if (!podDoc.exists) continue;

          final podData = podDoc.data() as Map<String, dynamic>;

          // Verify company ID matches
          if (podData['companyId'] != companyId) {
            debugPrint('⚠️ Skipping POD from different company: $podId');
            continue;
          }

          // Fetch delivery data for additional info
          final deliveryId = podData['deliveryId'];
          Map<String, dynamic>? deliveryData;
          if (deliveryId != null) {
            final deliveryDoc = await FirebaseFirestore.instance
                .collection('deliveries')
                .doc(deliveryId)
                .get();
            deliveryData = deliveryDoc.data();
          }

          final location =
              podData['location'] != null ? podData['location']['address'] : 'N/A';
          final timestamp = podData['timestamp'] != null
              ? DateFormat('yyyy-MM-dd HH:mm:ss')
                  .format((podData['timestamp'] as Timestamp).toDate())
              : 'N/A';

          rows.add([
            podId,
            podData['invoiceNumber'] ?? 'N/A',
            podData['customerName'] ?? 'N/A',
            deliveryData?['driverName'] ?? 'N/A',
            podData['deliveryId'] ?? 'N/A',
            podData['status'] ?? 'pending',
            timestamp,
            location,
            podData['signedBy'] ?? 'N/A',
            deliveryData?['customerPhone'] ?? 'N/A',
            deliveryData?['customerAddress'] ?? 'N/A',
          ]);

          processedCount++;
          onProgress(processedCount / podIds.length);
        } catch (e) {
          debugPrint('❌ Error processing POD $podId for CSV: $e');
          continue;
        }
      }

      // Convert to CSV
      final csv = const ListToCsvConverter().convert(rows);

      // Download CSV
      await _downloadFile(
        Uint8List.fromList(csv.codeUnits),
        'POD_Export_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.csv',
      );

      debugPrint('✅ PODs exported to CSV successfully');
      onProgress(1.0);
    } catch (e) {
      debugPrint('❌ Error exporting PODs to CSV: $e');
      rethrow;
    }
  }

  /// Helper: Download image from URL
  static Future<Uint8List?> _downloadImageFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 30),
          );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error downloading image from $url: $e');
      return null;
    }
  }

  /// Helper: Generate PDF for a single POD
  static Future<Uint8List?> _generatePODPDF({
    required String podId,
    required Map<String, dynamic> podData,
    required Map<String, dynamic>? deliveryData,
  }) async {
    try {
      debugPrint('📋 Generating PDF for POD: $podId');

      // Fetch driver information
      Map<String, dynamic>? driverInfo;
      if (deliveryData?['driverId'] != null) {
        try {
          final driverDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(deliveryData!['driverId'])
              .get();
          driverInfo = driverDoc.data();
        } catch (e) {
          debugPrint('⚠️ Error fetching driver info: $e');
        }
      }

      // Fetch vehicle information
      Map<String, dynamic>? vehicleInfo;
      if (deliveryData?['vehicleUsed'] != null) {
        try {
          final vehicleUsed = deliveryData!['vehicleUsed'] as String;
          // Prefer company-scoped vehicles if companyId is present
          final companyId = deliveryData['companyId'] as String?;
          Map<String, dynamic>? vData;
          if (companyId != null && companyId.isNotEmpty) {
            final docSnap = await findVehicleDocForCompany(companyId, vehicleUsed);
            if (docSnap != null) vData = docSnap.data();
          } else {
            final docSnap = await FirebaseFirestore.instance.collection('vehicles').doc(vehicleUsed).get();
            if (docSnap.exists) vData = docSnap.data();
          }
          vehicleInfo = vData;
        } catch (e) {
          debugPrint('⚠️ Error fetching vehicle info: $e');
        }
      }

      final pdf = pw.Document();

      // Fetch all images
      final photoUrls = (podData['photoUrls'] != null && podData['photoUrls'] is List)
          ? List<String>.from(podData['photoUrls'])
          : (podData['photoUrl'] != null ? [podData['photoUrl']] : []);
      final List<Uint8List?> photoBytesList = await Future.wait(
          photoUrls.map((url) => _downloadImageFromUrl(url)));
      
      // 📄 NEW: Fetch scanned documents
      final documentUrls = (podData['documentUrls'] != null && podData['documentUrls'] is List)
          ? List<String>.from(podData['documentUrls'])
          : [];
      final List<Uint8List?> documentBytesList = await Future.wait(
          documentUrls.map((url) => _downloadImageFromUrl(url)));
      final List<Map<String, String>> documentMetadata = (podData['documentMetadata'] != null && podData['documentMetadata'] is List)
          ? (podData['documentMetadata'] as List).map((e) => Map<String, String>.from(e)).toList()
          : [];
      
      final signatureBytes = podData['signatureUrl'] != null
          ? await _downloadImageFromUrl(podData['signatureUrl'])
          : null;
      final stampBytes = podData['stampPhotoUrl'] != null
          ? await _downloadImageFromUrl(podData['stampPhotoUrl'])
          : null;

      // Build PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // Header
            pw.Text(
              'PROOF OF DELIVERY (POD) REPORT',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Official Delivery Documentation',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // POD ID and date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('POD ID: $podId'),
                pw.Text(
                  'Generated: ${DateFormat('MMM dd, yyyy \'at\' h:mm a').format(DateTime.now())}',
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Customer Information
            _buildPDFSection('Customer Information', [
              _buildPDFInfoRow('Customer Name', deliveryData?['customerName'] ?? 'N/A'),
              _buildPDFInfoRow('Customer Number', deliveryData?['customerNumber'] ?? 'N/A'),
              _buildPDFInfoRow('Address', deliveryData?['customerAddress'] ?? 'N/A'),
              _buildPDFInfoRow('Phone', deliveryData?['customerPhone'] ?? 'N/A'),
            ]),
            pw.SizedBox(height: 15),

            // Order & Invoice Details
            _buildPDFSection('Order & Invoice Details', [
              _buildPDFInfoRow('Order Number', deliveryData?['orderNumber'] ?? 'N/A'),
              _buildPDFInfoRow('Invoice Number', deliveryData?['invoiceNumber'] ?? 'N/A'),
              _buildPDFInfoRow(
                'Invoice Total',
                '${deliveryData?['currency'] ?? 'ZAR'} ${deliveryData?['invoiceTotal'] ?? 'N/A'}',
              ),
            ]),
            pw.SizedBox(height: 15),

            // Driver Information
            _buildPDFSection('Driver Information', [
              _buildPDFInfoRow(
                'Driver Name',
                driverInfo?['displayName'] ?? driverInfo?['fullName'] ?? 'N/A',
              ),
              _buildPDFInfoRow('Driver Phone', driverInfo?['phoneNumber'] ?? 'N/A'),
              _buildPDFInfoRow('License Number', driverInfo?['licenseNumber'] ?? 'N/A'),
            ]),
            pw.SizedBox(height: 15),

            // Vehicle Information
            _buildPDFSection('Vehicle Information', [
              _buildPDFInfoRow('Vehicle Registration', deliveryData?['vehicleUsed'] ?? 'N/A'),
              _buildPDFInfoRow('Make', vehicleInfo?['make'] ?? 'N/A'),
              _buildPDFInfoRow('Model', vehicleInfo?['model'] ?? 'N/A'),
            ]),
            pw.SizedBox(height: 15),

            // Delivery Time
            _buildPDFSection('Delivery Time', [
              _buildPDFInfoRow(
                'Completed At',
                podData['timestamp'] != null
                    ? DateFormat('EEEE, MMMM d, y \'at\' h:mm a')
                        .format((podData['timestamp'] as Timestamp).toDate())
                    : 'N/A',
              ),
            ]),
            pw.SizedBox(height: 15),

            // GPS Location
            if (podData['location'] != null) ...[
              _buildPDFSection('GPS Location', [
                _buildPDFInfoRow('Latitude', podData['location']['latitude']?.toString() ?? 'N/A'),
                _buildPDFInfoRow('Longitude', podData['location']['longitude']?.toString() ?? 'N/A'),
                _buildPDFInfoRow(
                  'Accuracy',
                  '${(podData['location']['accuracy'] as num?)?.toStringAsFixed(1) ?? 'N/A'} meters',
                ),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Delivery Photos
            if (photoBytesList.isNotEmpty) ...[
              pw.Text(
                'Delivery Photo${photoBytesList.length > 1 ? 's' : ''}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              for (int i = 0; i < photoBytesList.length; i++) ...[
                if (photoBytesList[i] != null) ...[
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(photoBytesList[i]!),
                      width: 400,
                      height: 300,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  if (photoBytesList.length > 1 && i < photoBytesList.length - 1)
                    pw.SizedBox(height: 10),
                ],
              ],
              pw.SizedBox(height: 15),
            ],

            // 📄 NEW: Scanned Documents Section
            if (documentBytesList.isNotEmpty) ...[
              pw.Text(
                'Scanned Document${documentBytesList.length > 1 ? 's' : ''}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              for (int i = 0; i < documentBytesList.length; i++) ...[
                if (documentBytesList[i] != null) ...[
                  // Document type label
                  if (i < documentMetadata.length)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        documentMetadata[i]['type'] ?? 'Document',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(documentBytesList[i]!),
                      width: 400,
                      height: 300,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  if (documentBytesList.length > 1 && i < documentBytesList.length - 1)
                    pw.SizedBox(height: 10),
                ],
              ],
              pw.SizedBox(height: 15),
            ],

            // Customer Signature
            if (signatureBytes != null) ...[
              pw.Text(
                'Customer Signature',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(signatureBytes),
                  width: 300,
                  height: 150,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Stamp
            if (stampBytes != null) ...[
              pw.Text(
                'Corporate Store Receipt Stamp',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(stampBytes),
                  width: 300,
                  height: 200,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ],
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      debugPrint('✅ PDF generated: ${pdfBytes.length} bytes');
      return Uint8List.fromList(pdfBytes);
    } catch (e) {
      debugPrint('❌ Error generating PDF for POD $podId: $e');
      return null;
    }
  }

  /// Build a PDF section with title and rows
  static pw.Widget _buildPDFSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...children,
      ],
    );
  }

  /// Build a PDF info row
  static pw.Widget _buildPDFInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  /// Helper: Download file to user's device
  static Future<void> _downloadFile(Uint8List bytes, String filename) async {
    platform.downloadFile(bytes, filename);
  }

  /// Get total size of PODs to download (for estimation)
  static Future<String> estimateDownloadSize(List<String> podIds) async {
    try {
      int totalBytes = 0;
      for (final podId in podIds) {
        final podDoc = await FirebaseFirestore.instance.collection('pods').doc(podId).get();
        if (podDoc.exists) {
          // Estimate based on document size (rough estimate)
          totalBytes += 500 * 1024; // 500KB per POD average
        }
      }
      return _formatBytes(totalBytes);
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Format bytes to human readable format
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
