import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Conditional import for web/mobile
import 'pdf_export_web.dart' if (dart.library.io) 'pdf_export_mobile.dart';

/// Service for generating PDF reports
/// Handles analytics report generation and download
class PDFExportService {
  /// Generate and export analytics report as PDF
  static Future<Uint8List?> generateAnalyticsReport({
    required String companyName,
    required DateTime startDate,
    required DateTime endDate,
    required int totalDeliveries,
    required int completedDeliveries,
    required int activeDeliveries,
    required int pendingDeliveries,
    required int failedDeliveries,
    required int totalDrivers,
    required int activeDrivers,
    required double completionRate,
    required double avgDeliveryTime,
    required double avgDaysToDeliver,
    required int onTimeDeliveries,
    required int lateDeliveries,
    required Map<String, int> deliveriesByStatus,
    required List<Map<String, dynamic>> topDrivers,
    required Map<String, int> deliveriesPerTruck,
    required int totalClaims,
    required List<Map<String, dynamic>> claimsPerCustomer,
    required Set<String> claimTypes,
    required Map<String, int> claimTypeCount,
    required List<Map<String, dynamic>> topCustomerDeliveries,
    String? companyLogoUrl,
  }) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('MMM dd, yyyy');

      // Fetch company logo if provided
      final logoBytes = companyLogoUrl != null ? await _fetchImageBytes(companyLogoUrl) : null;

      // Page 1: Cover & Summary
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Logo and Company Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo on the left (if available)
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
                  
                  // Company name and title on the right
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PODSafe',
                          style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF1976D2),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Analytics & Reports',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColor.fromInt(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated: ${DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromInt(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              // Report Period
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFFE0E0E0),
                    width: 1,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Report Period',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF666666),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Text(
                          '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Spacer(),
                        pw.Text(
                          '${endDate.difference(startDate).inDays} days',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColor.fromInt(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),

              // Summary Cards
              pw.Text(
                'Executive Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),

              // Key Metrics Grid
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE0E0E0),
                  width: 1,
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F5F5),
                    ),
                    children: [
                      _buildMetricCell('Total Deliveries', totalDeliveries.toString()),
                      _buildMetricCell('Completed', completedDeliveries.toString()),
                      _buildMetricCell('Pending', pendingDeliveries.toString()),
                      _buildMetricCell('Failed', failedDeliveries.toString()),
                    ],
                  ),
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFFFFFF),
                    ),
                    children: [
                      _buildMetricCell('Total Drivers', totalDrivers.toString()),
                      _buildMetricCell('Active Drivers', activeDrivers.toString()),
                      _buildMetricCell('Completion Rate', '${completionRate.toStringAsFixed(1)}%'),
                      _buildMetricCell('Avg Delivery Time', '${avgDeliveryTime.toStringAsFixed(1)}h'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Status Distribution
              pw.Text(
                'Delivery Status Distribution',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildStatusTable(deliveriesByStatus, totalDeliveries),

              pw.SizedBox(height: 30),

              // Insights
              pw.Text(
                'Key Insights',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildInsights(completionRate, activeDrivers, topDrivers, avgDaysToDeliver, onTimeDeliveries, lateDeliveries),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColor.fromInt(0xFFE0E0E0)),
              pw.SizedBox(height: 12),
              pw.Text(
                'This is an automatically generated report from PODSafe.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      );

      // Page 2: Top Drivers
      if (topDrivers.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Top Performing Drivers',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Top ${topDrivers.length} drivers by completed deliveries',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColor.fromInt(0xFF666666),
                  ),
                ),
                pw.SizedBox(height: 20),

                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor.fromInt(0xFFE0E0E0),
                    width: 1,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(4),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF1976D2),
                      ),
                      children: [
                        _buildHeaderCell('Rank'),
                        _buildHeaderCell('Driver Name'),
                        _buildHeaderCell('Completed'),
                        _buildHeaderCell('Active'),
                        _buildHeaderCell('Total'),
                      ],
                    ),
                    ...List.generate(
                      topDrivers.length,
                      (index) {
                        final driver = topDrivers[index];
                        final completed = driver['completed'] ?? 0;
                        final active = driver['active'] ?? 0;
                        final total = completed + active;
                        final isTop3 = index < 3;

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isTop3
                                ? PdfColor.fromInt(0xFFFFF9E6)
                                : PdfColor.fromInt(0xFFFFFFFF),
                          ),
                          children: [
                            _buildDataCell(_getMedalEmoji(index), isTop3),
                            _buildDataCell(driver['name'] ?? 'Unknown', false),
                            _buildDataCell(completed.toString(), false),
                            _buildDataCell(active.toString(), false),
                            _buildDataCell(total.toString(), isTop3),
                          ],
                        );
                      },
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),

                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF0F8FF),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Performance Summary',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF1565C0),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Top performing drivers based on completed deliveries. Use this data for performance recognition.',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Page 3: Fleet & Claims Analytics
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Fleet & Claims Analytics',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Deliveries per truck and claims summary',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromInt(0xFF666666),
                ),
              ),
              pw.SizedBox(height: 24),

              // Deliveries Per Truck Section
              pw.Text(
                'Deliveries Per Truck',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildDeliveriesPerTruckTable(deliveriesPerTruck),

              pw.SizedBox(height: 24),

              // Claims Summary Section
              pw.Text(
                'Claims Summary',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildClaimsSummaryTable(totalClaims, claimsPerCustomer, claimTypes),

              pw.SizedBox(height: 24),

              // Top Claim Types Section
              pw.Text(
                'Top Claim Types',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildTopClaimTypesTablePDF(claimTypeCount),

              pw.SizedBox(height: 24),

              // Top Customer Deliveries Section
              pw.Text(
                'Top Customers by Deliveries',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildTopCustomerDeliveriesPDF(topCustomerDeliveries),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColor.fromInt(0xFFE0E0E0)),
              pw.SizedBox(height: 12),
              pw.Text(
                'Page 3: Fleet & Claims Analytics • Generated: ${DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      );

      // Generate PDF bytes
      final Uint8List pdfBytes = await pdf.save();

      // Download file (platform-specific)
      final filename =
          'PODSafe_Analytics_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
      await downloadPDF(filename, pdfBytes);

      return pdfBytes;
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      rethrow;
    }
  }

  static pw.Widget _buildMetricCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(0xFF666666),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(String text, bool highlight) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: highlight
              ? PdfColor.fromInt(0xFFF57F17)
              : PdfColor.fromInt(0xFF333333),
        ),
      ),
    );
  }

  static pw.Widget _buildStatusTable(
    Map<String, int> deliveriesByStatus,
    int total,
  ) {
    final statusRows = deliveriesByStatus.entries.map((entry) {
      final status = entry.key;
      final count = entry.value;
      final percentage = total > 0 ? (count / total * 100) : 0;

      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: _getStatusColor(status),
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              _formatStatusText(status),
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              count.toString(),
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE0E0E0),
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F5F5),
          ),
          children: [
            _buildHeaderCell('Status'),
            _buildHeaderCell('Count'),
            _buildHeaderCell('Percent'),
          ],
        ),
        ...statusRows,
      ],
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return PdfColor.fromInt(0xFFE8F5E9);
      case 'pending':
        return PdfColor.fromInt(0xFFFFF3E0);
      case 'in transit':
      case 'in_transit':
        return PdfColor.fromInt(0xFFE3F2FD);
      case 'failed':
        return PdfColor.fromInt(0xFFFFEBEE);
      default:
        return PdfColor.fromInt(0xFFFFFFFF);
    }
  }

  static String _formatStatusText(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  static pw.Widget _buildInsights(
    double completionRate,
    int activeDrivers,
    List<Map<String, dynamic>> topDrivers,
    double avgDaysToDeliver,
    int onTimeDeliveries,
    int lateDeliveries,
  ) {
    final insights = <String>[];

    if (completionRate >= 90) {
      insights.add('✓ Excellent completion rate (${completionRate.toStringAsFixed(1)}%)');
    } else if (completionRate >= 80) {
      insights.add('○ Good completion rate (${completionRate.toStringAsFixed(1)}%)');
    } else {
      insights.add('△ Completion rate needs attention (${completionRate.toStringAsFixed(1)}%)');
    }

    if (activeDrivers > 0) {
      insights.add('Team has $activeDrivers active drivers');
    }

    if (topDrivers.isNotEmpty) {
      final topDriver = topDrivers.first;
      insights.add('Top performer: ${topDriver['name']} (${topDriver['completed']} deliveries)');
    }

    // Add delivery performance insights
    if (avgDaysToDeliver > 0) {
      if (avgDaysToDeliver <= 3) {
        insights.add('✓ Fast delivery performance (${avgDaysToDeliver.toStringAsFixed(1)} days avg)');
      } else if (avgDaysToDeliver <= 5) {
        insights.add('○ Moderate delivery performance (${avgDaysToDeliver.toStringAsFixed(1)} days avg)');
      } else {
        insights.add('△ Delivery performance needs improvement (${avgDaysToDeliver.toStringAsFixed(1)} days avg)');
      }
    }

    if (onTimeDeliveries > 0 || lateDeliveries > 0) {
      final totalWithInvoice = onTimeDeliveries + lateDeliveries;
      if (totalWithInvoice > 0) {
        final onTimeRate = (onTimeDeliveries / totalWithInvoice * 100).toStringAsFixed(1);
        insights.add('$onTimeDeliveries on-time deliveries ($onTimeRate% SLA compliance)');
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: insights
          .map(
            (insight) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '• ',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColor.fromInt(0xFF1976D2),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      insight,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static String _getMedalEmoji(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '${index + 1}.';
    }
  }

  static pw.Widget _buildDeliveriesPerTruckTable(Map<String, int> deliveriesPerTruck) {
    if (deliveriesPerTruck.isEmpty) {
      return pw.Text(
        'No truck data available',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
      );
    }

    // Sort by deliveries (descending)
    final sortedTrucks = deliveriesPerTruck.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final truckRows = sortedTrucks.map((entry) {
      final truckName = entry.key.isEmpty ? 'Unassigned' : entry.key;
      final deliveryCount = entry.value;

      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              truckName,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              deliveryCount.toString(),
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE0E0E0),
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F5F5),
          ),
          children: [
            _buildHeaderCell('Truck / Vehicle'),
            _buildHeaderCell('Deliveries'),
          ],
        ),
        ...truckRows,
      ],
    );
  }

  static pw.Widget _buildClaimsSummaryTable(
    int totalClaims,
    List<Map<String, dynamic>> claimsPerCustomer,
    Set<String> claimTypes,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Summary metrics
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFFEBEE),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Total Claims',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColor.fromInt(0xFFC62828),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    totalClaims.toString(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF3E5F5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Unique Customers with Claims',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColor.fromInt(0xFF6A1B9A),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    claimsPerCustomer.length.toString(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF6A1B9A),
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEDE7F6),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Claim Types',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColor.fromInt(0xFF512DA8),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    claimTypes.length.toString(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF512DA8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // Top customers with claims
        pw.Text(
          'Top Customers with Claims',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        _buildTopCustomersTable(claimsPerCustomer),
      ],
    );
  }

  static pw.Widget _buildTopCustomersTable(List<Map<String, dynamic>> claimsPerCustomer) {
    if (claimsPerCustomer.isEmpty) {
      return pw.Text(
        'No claims data available',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
      );
    }

    // Already sorted, take top 5
    final topCustomers = claimsPerCustomer.take(5).toList();

    final customerRows = topCustomers.map((customer) {
      final customerNumber = (customer['customerNumber'] as String?) ?? '';
      final customerName = (customer['customerName'] as String?) ?? 'Unknown';
      final claimCount = (customer['count'] as int?) ?? 0;

      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              customerNumber,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xFF666666),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              customerName.length > 20
                  ? '${customerName.substring(0, 20)}...'
                  : customerName,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              claimCount.toString(),
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE0E0E0),
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F5F5),
          ),
          children: [
            _buildHeaderCell('Customer Number / Name'),
            _buildHeaderCell(''),
            _buildHeaderCell('Claims'),
          ],
        ),
        ...customerRows,
      ],
    );
  }

  static pw.Widget _buildTopClaimTypesTablePDF(Map<String, int> claimTypeCount) {
    if (claimTypeCount.isEmpty) {
      return pw.Text(
        'No claim type data available',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
      );
    }

    // Sort by count descending, take top 8
    final sortedTypes = claimTypeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(8);

    final typeRows = sortedTypes.map((entry) {
      final claimType = entry.key;
      final count = entry.value;

      // Format claim type display name
      String displayName = claimType;
      if (claimType.toLowerCase() == 'short_weight' || claimType.toLowerCase() == 'shortweight') {
        displayName = 'Short Weight';
      } else if (claimType.toLowerCase() == 'damaged') {
        displayName = 'Damaged';
      } else if (claimType.toLowerCase() == 'shortage') {
        displayName = 'Shortage';
      } else if (claimType.toLowerCase() == 'other') {
        displayName = 'Other';
      } else if (claimType.toLowerCase() == 'returns') {
        displayName = 'Returns';
      }

      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              displayName,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              count.toString(),
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE0E0E0),
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F5F5),
          ),
          children: [
            _buildHeaderCell('Claim Type'),
            _buildHeaderCell('Count'),
          ],
        ),
        ...typeRows,
      ],
    );
  }

  static pw.Widget _buildTopCustomerDeliveriesPDF(List<Map<String, dynamic>> topCustomerDeliveries) {
    if (topCustomerDeliveries.isEmpty) {
      return pw.Text(
        'No customer delivery data available',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
      );
    }

    // Already sorted, take top 8
    final topCustomers = topCustomerDeliveries.take(8).toList();

    final customerRows = topCustomers.map((customer) {
      final customerNumber = (customer['customerNumber'] as String?) ?? '';
      final customerName = (customer['customerName'] as String?) ?? 'Unknown';
      final deliveryCount = (customer['count'] as int?) ?? 0;

      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  customerNumber,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF666666),
                  ),
                ),
                pw.Text(
                  customerName.length > 20
                      ? '${customerName.substring(0, 20)}...'
                      : customerName,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              deliveryCount.toString(),
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromInt(0xFFE0E0E0),
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F5F5),
          ),
          children: [
            _buildHeaderCell('Customer Number / Name'),
            _buildHeaderCell('Deliveries'),
          ],
        ),
        ...customerRows,
      ],
    );
  }

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
}
