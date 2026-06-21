import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/delivery_model.dart';

// Conditional import for web-specific functionality
import 'delivery_export_service_stub.dart'
    if (dart.library.html) 'delivery_export_service_web.dart' as platform;

/// Service for exporting deliveries to CSV format
class DeliveryExportService {
  /// Generate CSV template with example data
  static String generateTemplate({bool withExamples = true}) {
    final rows = <List<String>>[
      // Header row
      [
        'customerName',
        'customerAddress',
        'customerPhone',
        'customerNumber',
        'orderNumber',
        'invoiceNumber',
        'invoiceDate',
        'invoiceTotal',
        'taxAmount',
        'discountAmount',
        'scheduledDate',
        'driverEmail',
        'notes',
        'item1_description',
        'item1_quantity',
        'item1_unit',
        'item1_unitPrice',
        'item1_totalPrice',
        'item2_description',
        'item2_quantity',
        'item2_unit',
        'item2_unitPrice',
        'item2_totalPrice',
        'item3_description',
        'item3_quantity',
        'item3_unit',
        'item3_unitPrice',
        'item3_totalPrice',
      ],
    ];

    if (withExamples) {
      // Example rows
      rows.addAll([
        [
          'John Smith',
          '123 Main Street, City, State 12345',
          '+1234567890',
          'CUST001',
          'ORD001',
          'INV001',
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
          '1250.00',
          '187.50',
          '0.00',
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'john@driver.com',
          'Handle with care',
          'Box of Parts',
          '5',
          'boxes',
          '250.00',
          '1250.00',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Jane Doe',
          '456 Oak Avenue, Town, State 67890',
          '+9876543210',
          'CUST002',
          'ORD002',
          'INV002',
          DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 0))),
          '8960.00',
          '1344.00',
          '200.00',
          DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1))),
          'john@driver.com',
          '',
          'Laptop',
          '1',
          'unit',
          '6000.00',
          '6000.00',
          'Mouse',
          '2',
          'units',
          '296.00',
          '592.00',
          'Keyboard',
          '1',
          'unit',
          '368.00',
          '368.00',
        ],
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Export deliveries to CSV format
  static Future<String> exportDeliveriesToCSV(
    List<Delivery> deliveries,
    Map<String, String> driverEmails,
  ) async {
    final rows = <List<String>>[
      // Header row
      [
        'customerName',
        'customerAddress',
        'customerPhone',
        'customerNumber',
        'orderNumber',
        'invoiceNumber',
        'invoiceDate',
        'invoiceTotal',
        'taxAmount',
        'discountAmount',
        'scheduledDate',
        'driverEmail',
        'notes',
        'item1_description',
        'item1_quantity',
        'item1_unit',
        'item1_unitPrice',
        'item1_totalPrice',
        'item2_description',
        'item2_quantity',
        'item2_unit',
        'item2_unitPrice',
        'item2_totalPrice',
        'item3_description',
        'item3_quantity',
        'item3_unit',
        'item3_unitPrice',
        'item3_totalPrice',
      ],
    ];

    // Data rows
    for (var delivery in deliveries) {
      final items = delivery.items;
      final driverEmail = driverEmails[delivery.driverId] ?? '';

      rows.add([
        delivery.customerName,
        delivery.customerAddress,
        delivery.customerPhone ?? '',
        delivery.customerNumber ?? '',
        delivery.orderNumber ?? '',
        delivery.invoiceNumber,
        delivery.invoiceDate != null ? DateFormat('yyyy-MM-dd').format(delivery.invoiceDate!) : '',
        delivery.invoiceTotal?.toStringAsFixed(2) ?? '',
        delivery.taxAmount?.toStringAsFixed(2) ?? '',
        delivery.discountAmount?.toStringAsFixed(2) ?? '',
        DateFormat('yyyy-MM-dd').format(delivery.scheduledDate),
        driverEmail,
        delivery.notes ?? '',
        items.isNotEmpty ? items[0].description : '',
        items.isNotEmpty ? items[0].quantity.toString() : '',
        items.isNotEmpty ? (items[0].unit ?? '') : '',
        items.isNotEmpty ? (items[0].unitPrice?.toStringAsFixed(2) ?? '') : '',
        items.isNotEmpty ? (items[0].totalPrice?.toStringAsFixed(2) ?? '') : '',
        items.length > 1 ? items[1].description : '',
        items.length > 1 ? items[1].quantity.toString() : '',
        items.length > 1 ? (items[1].unit ?? '') : '',
        items.length > 1 ? (items[1].unitPrice?.toStringAsFixed(2) ?? '') : '',
        items.length > 1 ? (items[1].totalPrice?.toStringAsFixed(2) ?? '') : '',
        items.length > 2 ? items[2].description : '',
        items.length > 2 ? items[2].quantity.toString() : '',
        items.length > 2 ? (items[2].unit ?? '') : '',
        items.length > 2 ? (items[2].unitPrice?.toStringAsFixed(2) ?? '') : '',
        items.length > 2 ? (items[2].totalPrice?.toStringAsFixed(2) ?? '') : '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Download CSV file (web only)
  static void downloadCSV(String filename, String csvContent) {
    if (kIsWeb) {
      // Use platform-specific implementation
      platform.downloadFile(filename, csvContent);
    } else {
      // For mobile, would use path_provider + file write
      // Not implementing mobile download for now
      print('Mobile file download not implemented yet');
    }
  }

  /// Download template file
  static void downloadTemplate() {
    final csvContent = generateTemplate(withExamples: true);
    final filename = 'podsafe_delivery_template_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    downloadCSV(filename, csvContent);
  }

  /// Download deliveries export
  static Future<void> downloadDeliveryExport(
    List<Delivery> deliveries,
    Map<String, String> driverEmails,
  ) async {
    final csvContent = await exportDeliveriesToCSV(deliveries, driverEmails);
    final filename = 'podsafe_deliveries_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    downloadCSV(filename, csvContent);
  }
}
