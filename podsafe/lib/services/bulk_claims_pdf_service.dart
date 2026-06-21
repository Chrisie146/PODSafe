import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/vehicle_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';

// Platform-specific download
import 'bulk_pod_download_stub.dart' if (dart.library.html) 'bulk_pod_download_web.dart' as platform;

/// Service for bulk downloading claims as PDF reports or CSV
class BulkClaimsPdfService {
  /// Download multiple claims as individual PDFs in a ZIP file
  static Future<void> downloadClaimsAsZip({
    required List<String> claimIds,
    required String companyId,
    required Function(double) onProgress,
    String? companyLogoUrl,
  }) async {
    try {
      debugPrint('📦 Starting bulk claims PDF download as ZIP for ${claimIds.length} claims');
      onProgress(0.0);

      final archive = Archive();
      int processedCount = 0;

      for (final claimId in claimIds) {
        try {
          debugPrint('📄 Processing Claim: $claimId');

          // Fetch claim data from Firestore (under company collection)
          final claimDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('claims')
              .doc(claimId)
              .get();

          if (!claimDoc.exists) {
            debugPrint('⚠️ Claim not found: $claimId');
            continue;
          }

          final claimData = claimDoc.data() as Map<String, dynamic>;

          // Generate PDF for this claim
          final pdfBytes = await _generateClaimPDF(
            claimId: claimId,
            claimData: claimData,
            companyLogoUrl: companyLogoUrl,
          );

          if (pdfBytes != null) {
            // Add PDF to archive
            archive.addFile(ArchiveFile(
              'Claim_${claimData['invoiceNumber'] ?? claimId}.pdf',
              pdfBytes.length,
              pdfBytes,
            ));
            debugPrint('✅ Added claim PDF to archive');
          }

          processedCount++;
          onProgress(processedCount / claimIds.length);
        } catch (e) {
          debugPrint('❌ Error processing claim $claimId: $e');
          continue;
        }
      }

      if (archive.files.isEmpty) {
        debugPrint('⚠️ No claims were processed');
        return;
      }

      // Create ZIP file
      final zipData = ZipEncoder().encode(archive);

      debugPrint('✅ ZIP file created: ${zipData.length} bytes');

      // Download
      final fileName = 'Claims_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip';
      platform.downloadFile(Uint8List.fromList(zipData), fileName);

      debugPrint('✅ Claims PDF ZIP download initiated');
    } catch (e) {
      debugPrint('❌ Error downloading claims: $e');
      rethrow;
    }
  }

  /// Export claims as CSV file
  static Future<void> exportClaimsAsCSV({
    required List<String> claimIds,
    required String companyId,
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('📊 Starting claims CSV export for ${claimIds.length} claims');
      onProgress(0.0);

      final csvData = <List<dynamic>>[
        [
          'Claim ID',
          'Invoice #',
          'Driver Name',
          'Claim Type',
          'Description',
          'Status',
          'Amount (ZAR)',
          'Created Date',
          'Updated Date',
          'Resolution Notes',
        ]
      ];

      int processedCount = 0;

      for (final claimId in claimIds) {
        try {
          final claimDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('claims')
              .doc(claimId)
              .get();

          if (!claimDoc.exists) continue;

          final claimData = claimDoc.data() as Map<String, dynamic>;

          csvData.add([
            claimId,
            claimData['invoiceNumber'] ?? 'N/A',
            claimData['driverName'] ?? 'N/A',
            claimData['type']?.toString().split('.').last ?? 'N/A',
            claimData['description'] ?? '',
            claimData['status']?.toString().split('.').last ?? 'N/A',
            claimData['claimAmount']?.toString() ?? '0.00',
            claimData['createdAt'] != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(_parseDateTime(claimData['createdAt']) ?? DateTime.now())
                : '',
            claimData['updatedAt'] != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(_parseDateTime(claimData['updatedAt']) ?? DateTime.now())
                : '',
            claimData['resolutionNotes'] ?? '',
          ]);

          processedCount++;
          onProgress(processedCount / claimIds.length);
        } catch (e) {
          debugPrint('⚠️ Error processing claim $claimId: $e');
          continue;
        }
      }

      if (csvData.length <= 1) {
        debugPrint('⚠️ No claims to export');
        return;
      }

      // Convert to CSV
      final csvContent = const ListToCsvConverter().convert(csvData);
      final csvBytes = utf8.encode(csvContent);

      // Download
      final fileName = 'Claims_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      platform.downloadFile(Uint8List.fromList(csvBytes), fileName);

      debugPrint('✅ Claims CSV export initiated');
    } catch (e) {
      debugPrint('❌ Error exporting claims: $e');
      rethrow;
    }
  }

  /// Helper: Generate PDF for a single claim
  static Future<Uint8List?> _generateClaimPDF({
    required String claimId,
    required Map<String, dynamic> claimData,
    String? companyLogoUrl,
  }) async {
    try {
      debugPrint('📋 Generating PDF for Claim: $claimId');

      // Fetch delivery info if deliveryId exists
      Map<String, dynamic>? deliveryData;
      if (claimData['deliveryId'] != null) {
        try {
          final deliveryDoc = await FirebaseFirestore.instance
              .collection('deliveries')
              .doc(claimData['deliveryId'])
              .get();
          deliveryData = deliveryDoc.data();
        } catch (e) {
          debugPrint('⚠️ Error fetching delivery info: $e');
        }
      }

      // Fetch driver information
      Map<String, dynamic>? driverInfo;
      if (claimData['driverId'] != null) {
        try {
          final driverDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(claimData['driverId'])
              .get();
          driverInfo = driverDoc.data();
        } catch (e) {
          debugPrint('⚠️ Error fetching driver info: $e');
        }
      }

      // Fetch vehicle information (NEW: Phase 1 enhancement)
      Map<String, dynamic>? vehicleInfo;
      if (deliveryData?['vehicleUsed'] != null) {
        try {
          final vehicleUsed = deliveryData!['vehicleUsed'] as String;
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

      // Fetch company logo if provided
      final logoBytes = companyLogoUrl != null ? await _downloadImageFromUrl(companyLogoUrl) : null;

      // Download claim photos
      List<Uint8List?> photoBytes = [];
      final List<dynamic> photoUrls = claimData['photoUrls'] ?? [];
      for (final photoUrl in photoUrls) {
        if (photoUrl is String && photoUrl.isNotEmpty) {
          final bytes = await _downloadImageFromUrl(photoUrl);
          photoBytes.add(bytes);
        }
      }

      // Download scanned documents (NEW: Phase 1 enhancement)
      List<Uint8List?> documentBytes = [];
      final List<dynamic> documentUrls = claimData['documentUrls'] ?? [];
      List<Map<String, dynamic>> documentMetadata = [];
      final List<dynamic> docMetadata = claimData['documentMetadata'] ?? [];
      
      for (int i = 0; i < documentUrls.length; i++) {
        final docUrl = documentUrls[i];
        if (docUrl is String && docUrl.isNotEmpty) {
          final bytes = await _downloadImageFromUrl(docUrl);
          documentBytes.add(bytes);
          if (i < docMetadata.length && docMetadata[i] is Map) {
            documentMetadata.add(Map<String, dynamic>.from(docMetadata[i]));
          }
        }
      }

      // Download customer signature
      Uint8List? customerSignatureBytes;
      if (claimData['customerSignatureUrl'] is String && 
          (claimData['customerSignatureUrl'] as String).isNotEmpty) {
        customerSignatureBytes = await _downloadImageFromUrl(claimData['customerSignatureUrl']);
      }

      // Download approval signature
      Uint8List? approvalSignatureBytes;
      if (claimData['signatureUrl'] is String && 
          (claimData['signatureUrl'] as String).isNotEmpty) {
        approvalSignatureBytes = await _downloadImageFromUrl(claimData['signatureUrl']);
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // Header with Logo and Company Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Logo on the left (if available)
                if (logoBytes != null) ...[
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(width: 15),
                ],
                
                // Title and subtitle on the right
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CLAIM REPORT',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Official Claim Documentation',
                        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Claim ID and date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Claim ID: $claimId'),
                pw.Text(
                  'Generated: ${DateFormat('MMM dd, yyyy \'at\' h:mm a').format(DateTime.now())}',
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Claim Details
            _buildClaimSection('Claim Information', [
              _buildInfoRow('Invoice Number', claimData['invoiceNumber'] ?? 'N/A'),
              _buildInfoRow('Claim Type', claimData['type']?.toString().split('.').last ?? 'N/A'),
              _buildInfoRow('Status', claimData['status']?.toString().split('.').last ?? 'N/A'),
              _buildInfoRow(
                'Claim Amount',
                'ZAR ${claimData['claimAmount']?.toString() ?? '0.00'}',
              ),
            ]),
            pw.SizedBox(height: 15),

            // Customer Information
            _buildClaimSection('Customer Information', [
              _buildInfoRow('Customer Name', claimData['customerName'] ?? 'N/A'),
              _buildInfoRow('Customer Number', claimData['customerAccountNumber'] ?? 'N/A'),
              _buildInfoRow('Customer Address', deliveryData?['customerAddress'] ?? 'N/A'),
              _buildInfoRow('Customer Phone', deliveryData?['customerPhone'] ?? 'N/A'),
            ]),
            pw.SizedBox(height: 15),

            // Driver Information
            _buildClaimSection('Driver Information', [
              _buildInfoRow(
                'Driver Name',
                driverInfo?['displayName'] ?? driverInfo?['fullName'] ?? claimData['driverName'] ?? 'N/A',
              ),
              _buildInfoRow('Driver Phone', driverInfo?['phoneNumber'] ?? 'N/A'),
              _buildInfoRow('License Number', driverInfo?['licenseNumber'] ?? 'N/A'),
            ]),
            pw.SizedBox(height: 15),

            // Order Details
            _buildClaimSection('Order Details', [
              _buildInfoRow('Order Number', deliveryData?['orderNumber'] ?? 'N/A'),
              _buildInfoRow('Invoice Total', '${deliveryData?['currency'] ?? 'ZAR'} ${deliveryData?['invoiceTotal'] ?? 'N/A'}'),
              _buildInfoRow('Delivery Date', deliveryData?['scheduledDate'] != null
                  ? _formatTimestamp(deliveryData!['scheduledDate'])
                  : 'N/A'),
            ]),
            pw.SizedBox(height: 15),

            // Vehicle Information (NEW: Phase 1 enhancement)
            _buildClaimSection('Vehicle Information', [
              _buildInfoRow('Vehicle Registration', deliveryData?['vehicleUsed'] ?? 'N/A'),
              _buildInfoRow('Make', vehicleInfo?['make'] ?? 'N/A'),
              _buildInfoRow('Model', vehicleInfo?['model'] ?? 'N/A'),
            ]),
            pw.SizedBox(height: 15),

            // GPS Location (NEW: Phase 1 enhancement)
            if (claimData['gpsLocation'] != null && (claimData['gpsLocation'] is Map)) ...[
              _buildClaimSection('GPS Location', [
                _buildInfoRow('Latitude', claimData['gpsLocation']['latitude']?.toString() ?? 'N/A'),
                _buildInfoRow('Longitude', claimData['gpsLocation']['longitude']?.toString() ?? 'N/A'),
                _buildInfoRow(
                  'Accuracy',
                  '${(claimData['gpsLocation']['accuracy'] as num?)?.toStringAsFixed(1) ?? 'N/A'} meters',
                ),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Claim Description
            _buildClaimSection('Claim Description', [
              pw.Text(
                claimData['description'] ?? 'No description provided',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ]),
            pw.SizedBox(height: 15),

            // Timeline
            _buildClaimSection('Timeline', [
              _buildInfoRow(
                'Created',
                claimData['createdAt'] != null
                    ? _formatTimestamp(claimData['createdAt'])
                    : 'N/A',
              ),
              _buildInfoRow(
                'Last Updated',
                claimData['updatedAt'] != null
                    ? _formatTimestamp(claimData['updatedAt'])
                    : 'N/A',
              ),
            ]),
            pw.SizedBox(height: 15),

            // Resolution Notes (if available)
            if (claimData['resolutionNotes'] != null && (claimData['resolutionNotes'] as String).isNotEmpty) ...[
              _buildClaimSection('Resolution Notes', [
                pw.Text(
                  claimData['resolutionNotes'],
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Evidence Section (Photos, Signatures, Attachments)
            ..._buildEvidenceSection(
              claimData,
              photoBytes: photoBytes,
              documentBytes: documentBytes,
              documentMetadata: documentMetadata,
              customerSignatureBytes: customerSignatureBytes,
              approvalSignatureBytes: approvalSignatureBytes,
            ),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'This is an official claim report generated by PodSafe',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      debugPrint('✅ PDF generated: ${pdfBytes.length} bytes');
      return Uint8List.fromList(pdfBytes);
    } catch (e) {
      debugPrint('❌ Error generating PDF for claim $claimId: $e');
      return null;
    }
  }

  /// Helper: Build section with title and rows
  static pw.Widget _buildClaimSection(String title, List<pw.Widget> content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...content,
      ],
    );
  }

  /// Helper: Build info row (key-value pair)
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
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
      debugPrint('⚠️ Failed to download image: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('⚠️ Error downloading image from $url: $e');
      return null;
    }
  }

  /// Helper: Build evidence section with photos and signatures
  static List<pw.Widget> _buildEvidenceSection(
    Map<String, dynamic> claimData, {
    List<Uint8List?>? photoBytes,
    List<Uint8List?>? documentBytes,
    List<Map<String, dynamic>>? documentMetadata,
    Uint8List? customerSignatureBytes,
    Uint8List? approvalSignatureBytes,
  }) {
    final widgets = <pw.Widget>[];
    
    try {
      bool hasEvidence = false;
      
      // Check for photos - display embedded images if available
      final List<dynamic> photoUrls = claimData['photoUrls'] ?? [];
      if (photoBytes != null && photoBytes.isNotEmpty) {
        hasEvidence = true;
        for (int i = 0; i < photoBytes.length; i++) {
          if (photoBytes[i] != null) {
            widgets.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Claim Photo ${i + 1}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(photoBytes[i]!),
                      width: 350,
                      height: 250,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],
              ),
            );
          }
        }
        if (widgets.isNotEmpty) {
          widgets.add(pw.SizedBox(height: 15));
        }
      } else if (photoUrls.isNotEmpty) {
        // Fallback to URL display if images couldn't be downloaded
        hasEvidence = true;
        widgets.add(
          _buildClaimSection('Claim Photos', [
            pw.Text(
              'Total photos attached: ${photoUrls.length}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Photo URLs:',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            for (int i = 0; i < photoUrls.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 5, left: 20),
                child: pw.Text(
                  '${i + 1}. ${photoUrls[i]}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue),
                  maxLines: 3,
                ),
              ),
          ]),
        );
        widgets.add(pw.SizedBox(height: 15));
      }
      
      // Check for scanned documents (NEW: Phase 1 enhancement)
      if (documentBytes != null && documentBytes.isNotEmpty) {
        hasEvidence = true;
        widgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Scanned Document${documentBytes.length > 1 ? 's' : ''}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              for (int i = 0; i < documentBytes.length; i++) ...[
                if (documentBytes[i] != null) ...[
                  // Document type label
                  if (i < (documentMetadata?.length ?? 0))
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        documentMetadata![i]['type'] ?? 'Document',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(documentBytes[i]!),
                      width: 350,
                      height: 250,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  if (i < documentBytes.length - 1) pw.SizedBox(height: 10),
                ],
              ],
              pw.SizedBox(height: 10),
            ],
          ),
        );
        widgets.add(pw.SizedBox(height: 15));
      }
      
      // Check for customer signature - display embedded image if available
      if (customerSignatureBytes != null) {
        hasEvidence = true;
        widgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer Signature',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(customerSignatureBytes),
                  width: 250,
                  height: 100,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        );
        widgets.add(pw.SizedBox(height: 15));
      } else if (claimData['customerSignatureUrl'] != null && 
                 (claimData['customerSignatureUrl'] as String).isNotEmpty) {
        // Fallback to URL if image couldn't be downloaded
        hasEvidence = true;
        widgets.add(
          _buildClaimSection('Customer Signature', [
            pw.Text(
              'Customer has signed the claim',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              claimData['customerSignatureUrl'],
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue),
              maxLines: 2,
            ),
          ]),
        );
        widgets.add(pw.SizedBox(height: 15));
      }
      
      // Check for approval signature - display embedded image if available
      if (approvalSignatureBytes != null) {
        hasEvidence = true;
        widgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Approval Signature',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(approvalSignatureBytes),
                  width: 250,
                  height: 100,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        );
        widgets.add(pw.SizedBox(height: 15));
      } else if (claimData['signatureUrl'] != null && 
                 (claimData['signatureUrl'] as String).isNotEmpty) {
        // Fallback to URL if image couldn't be downloaded
        hasEvidence = true;
        widgets.add(
          _buildClaimSection('Approval Signature', [
            pw.Text(
              'Approved by manager/reviewer',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              claimData['signatureUrl'],
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue),
              maxLines: 2,
            ),
          ]),
        );
        widgets.add(pw.SizedBox(height: 15));
      }
      
      // Check for attachments
      final List<dynamic> attachmentUrls = claimData['attachmentUrls'] ?? [];
      if (attachmentUrls.isNotEmpty) {
        hasEvidence = true;
        widgets.add(
          _buildClaimSection('Attachments', [
            pw.Text(
              'Total files attached: ${attachmentUrls.length}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'File URLs:',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            for (int i = 0; i < attachmentUrls.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 5, left: 20),
                child: pw.Text(
                  '${i + 1}. ${attachmentUrls[i]}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue),
                  maxLines: 3,
                ),
              ),
          ]),
        );
        widgets.add(pw.SizedBox(height: 15));
      }
      
      // If no evidence, show message
      if (!hasEvidence) {
        widgets.add(
          _buildClaimSection('Evidence', [
            pw.Text(
              'No evidence attached to this claim',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ]),
        );
        widgets.add(pw.SizedBox(height: 15));
      }
    } catch (e) {
      debugPrint('⚠️ Error building evidence section: $e');
      widgets.add(
        _buildClaimSection('Evidence', [
          pw.Text(
            'Error loading evidence',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.red),
          ),
        ]),
      );
    }
    
    return widgets;
  }

  /// Helper: Format timestamp from either Timestamp or String
  static String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime dateTime;
      
      if (timestamp is Timestamp) {
        // It's a Firebase Timestamp
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        // It's a string (ISO 8601 format)
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }
      
      return DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(dateTime);
    } catch (e) {
      debugPrint('⚠️ Error formatting timestamp: $e');
      return 'N/A';
    }
  }

  /// Helper: Parse timestamp to DateTime (handles both Timestamp and String formats)
  static DateTime? _parseDateTime(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error parsing timestamp: $e');
      return null;
    }
  }
}
