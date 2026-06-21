import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Conditional import: web uses `pdf_export_web.dart`, native (IO) uses `pdf_export_mobile.dart`
import 'pdf_export_web.dart' if (dart.library.io) 'pdf_export_mobile.dart';

/// Service for generating and downloading POD reports as PDF
class PODPdfGeneratorService {
  /// Generate complete POD report PDF with all details and images
  static Future<void> downloadPODReportPDF({
    required String podId,
    required Map<String, dynamic>? deliveryData,
    required Map<String, dynamic>? podData,
    required String? photoUrl,
    required List<String>? photoUrls,
    List<String>? documentUrls,  // 📄 NEW: Scanned documents
    List<Map<String, String>>? documentMetadata,  // 📄 NEW: Document types
    required String? signatureUrl,
    required String? stampPhotoUrl,
    required Timestamp? timestamp,
    required Map<String, dynamic>? location,
    required String? notes,
    required String? companyName,
    required String? companyLogoUrl,
    String? receiverName,  // 🆕 NEW: Receiver name for signature section
  }) async {
    try {
      debugPrint('📄 Generating POD PDF report for POD: $podId');

      // Create PDF document
      final pdf = pw.Document();

      // Fetch all images
      final photoBytes = photoUrl != null ? await _fetchImageBytes(photoUrl) : null;
      final List<Uint8List?> photoBytesList = photoUrls != null && photoUrls.isNotEmpty
          ? await Future.wait(photoUrls.map(_fetchImageBytes))
          : (photoBytes != null ? [photoBytes] : []);
      
      // 📄 NEW: Fetch scanned document images
      final List<Uint8List?> documentBytesList = documentUrls != null && documentUrls.isNotEmpty
          ? await Future.wait(documentUrls.map(_fetchImageBytes))
          : [];
      
      final signatureBytes =
          signatureUrl != null ? await _fetchImageBytes(signatureUrl) : null;
      final stampBytes = stampPhotoUrl != null ? await _fetchImageBytes(stampPhotoUrl) : null;
      final logoBytes = companyLogoUrl != null ? await _fetchImageBytes(companyLogoUrl) : null;

      // Optional: Static map image based on GPS location
      Uint8List? mapBytes;
      final locationLat = location?['latitude'];
      final locationLon = location?['longitude'];
      if (locationLat != null && locationLon != null) {
        final lat = (locationLat as num).toDouble();
        final lon = (locationLon as num).toDouble();
        final mapUrl = _buildStaticMapUrl(lat, lon);
        try {
          mapBytes = await _fetchImageBytes(mapUrl);
        } catch (e) {
          debugPrint('⚠️ Unable to fetch static map image: $e');
        }
      }

      // Build PDF with all content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // Header with Logo and Company Info
            _buildPDFHeaderWithBranding(podId, companyName, logoBytes),
            pw.SizedBox(height: 20),

            // Delivery Information Section (Enhanced)
            if (deliveryData != null) ...[
              _buildPDFSection('Customer Information', [
                _buildPDFInfoRow('Customer Name', deliveryData['customerName'] ?? 'N/A'),
                _buildPDFInfoRow('Customer Number', deliveryData['customerNumber'] ?? 'N/A'),
                _buildPDFInfoRow('Address', deliveryData['customerAddress'] ?? 'N/A'),
                _buildPDFInfoRow('Phone', deliveryData['customerPhone'] ?? 'N/A'),
                _buildPDFInfoRow('Receiver Name', podData?['receiverName'] ?? 'Not specified'),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Order & Invoice Section
            if (deliveryData != null) ...[
              _buildPDFSection('Order & Invoice Details', [
                _buildPDFInfoRow('Order Number', deliveryData['orderNumber'] ?? 'N/A'),
                _buildPDFInfoRow('Invoice Number', deliveryData['invoiceNumber'] ?? 'N/A'),
                _buildPDFInfoRow(
                  'Invoice Total',
                  '${deliveryData['currency'] ?? 'ZAR'} ${deliveryData['invoiceTotal'] ?? 'N/A'}',
                ),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Driver Information Section
            if (deliveryData != null) ...[
              _buildPDFSection('Driver Information', [
                _buildPDFInfoRow('Driver Name', deliveryData['driverName'] ?? 'N/A'),
                _buildPDFInfoRow('Driver Phone', deliveryData['driverPhone'] ?? 'N/A'),
                _buildPDFInfoRow('License Number', deliveryData['licenseNumber'] ?? 'N/A'),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Vehicle Information Section
            if (deliveryData != null) ...[
              _buildPDFSection('Vehicle Information', [
                _buildPDFInfoRow('Vehicle Registration', deliveryData['vehicleUsed'] ?? 'N/A'),
                _buildPDFInfoRow('Make', deliveryData['vehicleMake'] ?? 'N/A'),
                _buildPDFInfoRow('Model', deliveryData['vehicleModel'] ?? 'N/A'),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Delivery Time Section
            if (timestamp != null) ...[
              _buildPDFSection('Delivery Time', [
                _buildPDFInfoRow(
                  'Completed At',
                  DateFormat('EEEE, MMMM d, y • h:mm a').format(timestamp.toDate()),
                ),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Location Information
            if (location != null) ...[
              _buildPDFSection('GPS Location', [
                _buildPDFInfoRow('Latitude', location['latitude']?.toString() ?? 'N/A'),
                _buildPDFInfoRow('Longitude', location['longitude']?.toString() ?? 'N/A'),
                _buildPDFInfoRow(
                  'Accuracy',
                  '${location['accuracy']?.toStringAsFixed(1) ?? 'N/A'} meters',
                ),
              ]),
              pw.SizedBox(height: 15),
            ],

            // Map Image Section (optional)
            if (mapBytes != null) ...[
              _buildPDFSection('Delivery Location Map', []),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(mapBytes),
                    width: 460,
                    height: 240,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Delivery Photo Section - FULL PAGE IMAGES
            if (photoBytesList.isNotEmpty) ...[
              _buildPDFSection('Delivery Photo${photoBytesList.length > 1 ? 's' : ''}', []),
              pw.Text(
                'Photos are displayed on separate pages for maximum clarity',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 10),
            ],

            // 📄 NEW: Scanned Documents Section - FULL PAGE IMAGES
            if (documentBytesList.isNotEmpty) ...[
              _buildPDFSection('Scanned Documents (${documentBytesList.length})', []),
              pw.Text(
                'High-quality scanned documents with auto edge detection - displayed on separate pages',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 10),
            ],

            // Customer Signature Section
            if (signatureBytes != null) ...[
              _buildPDFSection('Customer Signature', []),
              // 🆕 NEW: Receiver name above signature
              if (receiverName != null && receiverName.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Received by: $receiverName',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
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

            // Stamp Photo Section
            if (stampBytes != null) ...[
              _buildPDFSection('Corporate Store Receipt Stamp', []),
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(stampBytes),
                  width: 300,
                  height: 200,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Notes Section
            if (notes != null && notes.isNotEmpty) ...[
              _buildPDFSection('Delivery Notes', []),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Text(
                  notes,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Footer
            _buildPDFFooter(podId),
          ],
        ),
      );

      // 🆕 NEW: Add full-page photos after main content
      if (photoBytesList.isNotEmpty) {
        for (int i = 0; i < photoBytesList.length; i++) {
          final photoBytes = photoBytesList[i];
          if (photoBytes != null) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(20),
                build: (context) => pw.Column(
                  children: [
                    // Header for photo page
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                      ),
                      child: pw.Text(
                        'Delivery Photo ${i + 1} of ${photoBytesList.length}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    // Full-page photo
                    pw.Expanded(
                      child: pw.Image(
                        pw.MemoryImage(photoBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }

      // 🆕 NEW: Add full-page scanned documents after photos
      if (documentBytesList.isNotEmpty) {
        for (int i = 0; i < documentBytesList.length; i++) {
          final documentBytes = documentBytesList[i];
          final metadata = documentMetadata?[i];
          if (documentBytes != null) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(20),
                build: (context) => pw.Column(
                  children: [
                    // Header for document page
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Scanned Document ${i + 1} of ${documentBytesList.length}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (metadata != null && metadata['type'] != null) ...[
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'Type: ${metadata['type']}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.green700,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    // Full-page document
                    pw.Expanded(
                      child: pw.Image(
                        pw.MemoryImage(documentBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }

      // Generate PDF bytes
      final pdfBytes = await pdf.save();

      // Download PDF
      await _downloadPDF(pdfBytes, podId);

      debugPrint('✅ POD PDF report downloaded successfully');
    } catch (e) {
      debugPrint('❌ Error generating POD PDF: $e');
      rethrow;
    }
  }

  /// Fetch image bytes from URL
  static Future<Uint8List> _fetchImageBytes(String imageUrl) async {
    try {
      debugPrint('🖼️ Fetching image: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200) {
        throw 'Failed to fetch image. Status: ${response.statusCode}';
      }

      return response.bodyBytes;
    } catch (e) {
      debugPrint('❌ Error fetching image: $e');
      throw 'Failed to fetch image from URL';
    }
  }

  static String _buildStaticMapUrl(double lat, double lon) {
    final center = '${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
    return 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$center'
        '&zoom=16'
        '&size=600x320'
        '&maptype=mapnik'
        '&markers=$center,red-pushpin';
  }

  /// Download PDF on web
  static Future<void> _downloadPDF(List<int> pdfBytes, String podId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'POD_${podId}_Report_$timestamp.pdf';
      // Convert to Uint8List and call platform-specific download handler
      final bytes = Uint8List.fromList(pdfBytes);
      await downloadPDF(filename.replaceAll('.pdf', ''), bytes);
      debugPrint('✅ PDF saved/download triggered: $filename');
    } catch (e) {
      debugPrint('❌ Error preparing PDF: $e');
      rethrow;
    }
  }

  /// Build PDF header with company branding
  static pw.Widget _buildPDFHeaderWithBranding(
    String podId,
    String? companyName,
    Uint8List? logoBytes,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Top row with logo and company info
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo on the left
            if (logoBytes != null) ...[
              pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Image(
                  pw.MemoryImage(logoBytes),
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(width: 20),
            ],
            
            // Company name and POD title on the right
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (companyName != null && companyName.isNotEmpty)
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'PROOF OF DELIVERY (POD) REPORT',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Official Delivery Documentation',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.blue, thickness: 2),
        pw.SizedBox(height: 8),
        
        // POD ID and Generated time
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'POD ID: $podId',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Generated: ${DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }


  /// Build PDF section with title
  static pw.Widget _buildPDFSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(
                color: PdfColors.blue,
                width: 3,
              ),
            ),
          ),
          padding: const pw.EdgeInsets.only(left: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  /// Build info row for PDF
  static pw.Widget _buildPDFInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
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

  /// Build PDF footer
  static pw.Widget _buildPDFFooter(String podId) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'This is an official Proof of Delivery document. Document ID: $podId',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
