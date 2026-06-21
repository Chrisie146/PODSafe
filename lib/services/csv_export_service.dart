import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

// Conditional import for web
import 'csv_export_web.dart' if (dart.library.io) 'csv_export_mobile.dart';

/// Service for exporting data to CSV files
/// Handles CSV generation, formatting, and browser downloads
class CSVExportService {
  /// Export data to CSV file
  /// 
  /// [filename] - Name of the file (without extension)
  /// [headers] - Column headers
  /// [rows] - Data rows (each row is a list matching headers length)
  /// 
  /// Returns the file path on mobile platforms, null on web
  static Future<String?> exportToCSV({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    try {
      // Create CSV data with headers
      final List<List<dynamic>> csvData = [headers, ...rows];

      // Convert to CSV string
      final String csv = const ListToCsvConverter().convert(csvData);

      // Add BOM for proper Excel UTF-8 encoding
      final String csvWithBom = '\uFEFF$csv';

      // Create blob and download (platform-specific)
      final bytes = utf8.encode(csvWithBom);
      
      // Call platform-specific download implementation
      final result = await downloadCSV(filename, bytes);
      
      // On mobile, result is a file path; on web, it's null
      return result is String ? result : null;
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      rethrow;
    }
  }

  /// Format DateTime to readable string
  static String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format DateTime with time
  static String formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy h:mm a').format(date);
  }

  /// Format timestamp to readable string
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is DateTime) {
        return formatDateTime(timestamp);
      }
      // Handle Firestore Timestamp
      final date = timestamp.toDate() as DateTime;
      return formatDateTime(date);
    } catch (e) {
      return 'N/A';
    }
  }

  /// Clean text for CSV (remove commas, quotes, newlines)
  static String cleanText(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('  ', ' ')
        .trim();
  }

  /// Format phone number
  static String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'N/A';
    return phone;
  }

  /// Format currency
  static String formatCurrency(double? amount) {
    if (amount == null) return '\$0.00';
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Format status text
  static String formatStatus(String? status) {
    if (status == null || status.isEmpty) return 'N/A';
    return status.toUpperCase();
  }

  /// Get current timestamp for filename
  static String getTimestamp() {
    return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  }

  /// Generate filename with timestamp
  static String generateFilename(String baseName) {
    return '${baseName}_${getTimestamp()}';
  }

  // ============================================================================
  // DRIVER EXPORT
  // ============================================================================

  /// Export driver list to CSV
  static Future<String?> exportDrivers({
    required List<Map<String, dynamic>> drivers,
    String? filterStatus,
    String? searchQuery,
  }) async {
    final headers = [
      'Name',
      'Email',
      'Phone',
      'Status',
      'Registration Date',
      'Last Active',
      'Total Deliveries',
      'Approved By',
    ];

    final rows = drivers.map((driver) {
      return [
        cleanText(driver['name'] ?? 'N/A'),
        cleanText(driver['email'] ?? 'N/A'),
        formatPhone(driver['phone']),
        formatStatus(driver['approvalStatus'] ?? 'pending'),
        formatTimestamp(driver['createdAt']),
        formatTimestamp(driver['lastActive']),
        (driver['totalDeliveries'] ?? 0).toString(),
        cleanText(driver['approvedBy'] ?? 'N/A'),
      ];
    }).toList();

    // Create filename with filters
    String filename = 'drivers_export';
    if (filterStatus != null && filterStatus != 'all') {
      filename += '_${filterStatus.toLowerCase()}';
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filename += '_filtered';
    }

    return await exportToCSV(
      filename: generateFilename(filename),
      headers: headers,
      rows: rows,
    );
  }

  // ============================================================================
  // DELIVERY EXPORT
  // ============================================================================

  /// Export delivery list to CSV
  static Future<String?> exportDeliveries({
    required List<Map<String, dynamic>> deliveries,
    String? filterStatus,
    String? filterDate,
  }) async {
    final headers = [
      'Tracking Number',
      'Customer Name',
      'Customer Phone',
      'Delivery Address',
      'Scheduled Date',
      'Invoice Date',
      'Status',
      'Driver Name',
      'Notes',
      'Created Date',
      'Completed Date',
    ];

    final rows = deliveries.map((delivery) {
      return [
        cleanText(delivery['trackingNumber'] ?? 'N/A'),
        cleanText(delivery['customerName'] ?? 'N/A'),
        formatPhone(delivery['customerPhone']),
        cleanText(delivery['address'] ?? 'N/A'),
        formatTimestamp(delivery['scheduledDate']),
        formatTimestamp(delivery['invoiceDate']),
        formatStatus(delivery['status'] ?? 'pending'),
        cleanText(delivery['driverName'] ?? 'Unassigned'),
        cleanText(delivery['notes'] ?? ''),
        formatTimestamp(delivery['createdAt']),
        formatTimestamp(delivery['completedAt']),
      ];
    }).toList();

    // Create filename with filters
    String filename = 'deliveries_export';
    if (filterStatus != null && filterStatus != 'all') {
      filename += '_${filterStatus.toLowerCase()}';
    }
    if (filterDate != null && filterDate != 'all') {
      filename += '_${filterDate.toLowerCase()}';
    }

    return await exportToCSV(
      filename: generateFilename(filename),
      headers: headers,
      rows: rows,
    );
  }

  // ============================================================================
  // CLAIM EXPORT
  // ============================================================================

  /// Export claims list to CSV
  static Future<String?> exportClaims({
    required List<Map<String, dynamic>> claims,
    String? filterStatus,
    String? filterType,
  }) async {
    final headers = [
      'Claim ID',
      'Driver Name',
      'Claim Type',
      'Description',
      'Status',
      'Created Date',
      'Updated Date',
      'Resolution Notes',
      'Amount',
    ];

    final rows = claims.map((claim) {
      return [
        cleanText(claim['id'] ?? 'N/A'),
        cleanText(claim['driverName'] ?? 'N/A'),
        cleanText(claim['type'] ?? 'N/A'),
        cleanText(claim['description'] ?? 'N/A'),
        formatStatus(claim['status'] ?? 'pending'),
        formatTimestamp(claim['createdAt']),
        formatTimestamp(claim['updatedAt']),
        cleanText(claim['resolutionNotes'] ?? 'N/A'),
        formatCurrency(claim['claimAmount']?.toDouble()),
      ];
    }).toList();

    // Create filename with filters
    String filename = 'claims_export';
    if (filterStatus != null && filterStatus != 'all') {
      filename += '_${filterStatus.toLowerCase()}';
    }
    if (filterType != null && filterType != 'all') {
      filename += '_${filterType.toLowerCase()}';
    }

    return await exportToCSV(
      filename: generateFilename(filename),
      headers: headers,
      rows: rows,
    );
  }

  // ============================================================================
  // POD EXPORT
  // ============================================================================

  /// Export PODs list to CSV
  static Future<String?> exportPODs({
    required List<Map<String, dynamic>> pods,
    String? filterStatus,
  }) async {
    final headers = [
      'Delivery ID',
      'Tracking Number',
      'Customer Name',
      'Delivery Address',
      'Delivered Date',
      'Status',
      'Has Signature',
      'Has Photo',
      'Recipient Name',
      'Notes',
    ];

    final rows = pods.map((pod) {
      return [
        cleanText(pod['deliveryId'] ?? 'N/A'),
        cleanText(pod['trackingNumber'] ?? 'N/A'),
        cleanText(pod['customerName'] ?? 'N/A'),
        cleanText(pod['deliveryAddress'] ?? 'N/A'),
        formatTimestamp(pod['timestamp']),
        formatStatus(pod['status'] ?? 'delivered'),
        (pod['signatureUrl'] != null && pod['signatureUrl'].toString().isNotEmpty) ? 'Yes' : 'No',
        (pod['photoUrls'] != null && (pod['photoUrls'] as List).isNotEmpty) || (pod['photoUrl'] != null && pod['photoUrl'].toString().isNotEmpty) ? 'Yes' : 'No',
        cleanText(pod['recipientName'] ?? 'N/A'),
        cleanText(pod['notes'] ?? ''),
      ];
    }).toList();

    // Create filename with filters
    String filename = 'pods_export';
    if (filterStatus != null && filterStatus != 'all') {
      filename += '_${filterStatus.toLowerCase()}';
    }

    return await exportToCSV(
      filename: generateFilename(filename),
      headers: headers,
      rows: rows,
    );
  }

  // ============================================================================
  // ANALYTICS EXPORT
  // ============================================================================

  /// Export analytics summary to CSV
  static Future<String?> exportAnalyticsSummary({
    required Map<String, dynamic> summary,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final headers = ['Metric', 'Value'];

    final rows = [
      ['Report Period', '${formatDate(startDate)} - ${formatDate(endDate)}'],
      ['Total Deliveries', summary['totalDeliveries']?.toString() ?? '0'],
      ['Completed Deliveries', summary['completedDeliveries']?.toString() ?? '0'],
      ['Pending Deliveries', summary['pendingDeliveries']?.toString() ?? '0'],
      ['In Transit Deliveries', summary['inTransitDeliveries']?.toString() ?? '0'],
      ['Completion Rate', '${summary['completionRate']?.toStringAsFixed(1) ?? '0'}%'],
      ['Active Drivers', summary['activeDrivers']?.toString() ?? '0'],
      ['Total Drivers', summary['totalDrivers']?.toString() ?? '0'],
      ['Total Claims', summary['totalClaims']?.toString() ?? '0'],
      ['Pending Claims', summary['pendingClaims']?.toString() ?? '0'],
      ['Total PODs', summary['totalPODs']?.toString() ?? '0'],
    ];

    return await exportToCSV(
      filename: generateFilename('analytics_summary'),
      headers: headers,
      rows: rows,
    );
  }
}
