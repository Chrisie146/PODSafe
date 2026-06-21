import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';

import 'package:podsafe/services/bulk_import_service.dart';
import 'package:podsafe/services/delivery_export_service.dart';

void main() {
  group('BulkImportService - invoiceDate parsing', () {
    test('accepts valid invoiceDate in yyyy-MM-dd format', () {
      // Arrange
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final csv = 'customerName,customerAddress,invoiceNumber,invoiceDate,scheduledDate\r\nJohn Smith,123 Main St,INV100,$dateStr,$dateStr\r\n';

      // Act
      final result = BulkImportService.parseCsv(csv);

  // Also inspect how the csv parser sees the rows
  final rawRows = const CsvToListConverter().convert(csv);
  print('RAW ROWS: $rawRows');
  print('RAW HEADERS: ${rawRows[0].map((e) => e.toString()).toList()}');

    // Debug prints (helpful if something goes wrong)
    print('DEBUG valid parse errors: ${result.errors.map((e) => '${e.field}:${e.message}').toList()}');
    print('DEBUG valid deliveries: ${result.validDeliveries.length}');

      // Assert
      expect(result.hasErrors, isFalse);
      expect(result.validDeliveries.length, equals(1));
  final parsed = result.validDeliveries.first;
  expect(parsed.invoiceNumber, equals('INV100'));
  // invoiceDate should parse to the same day and be non-null
  expect(parsed.invoiceDate, isNotNull);
  expect(DateFormat('yyyy-MM-dd').format(parsed.invoiceDate!), equals(dateStr));
    });

    test('rejects invalid invoiceDate format', () {
      // Arrange
  final csv = 'customerName,customerAddress,invoiceNumber,invoiceDate,scheduledDate\r\nJohn Smith,123 Main St,INV101,not-a-date,2025-10-20\r\n';

      // Act
      final result = BulkImportService.parseCsv(csv);

  final rawRows = const CsvToListConverter().convert(csv);
  print('RAW ROWS: $rawRows');
  print('RAW HEADERS: ${rawRows[0].map((e) => e.toString()).toList()}');

    // Debug prints
    print('DEBUG invalid parse errors: ${result.errors.map((e) => '${e.field}:${e.message}').toList()}');
    print('DEBUG invalid deliveries: ${result.validDeliveries.length}');

      // Assert
      expect(result.validDeliveries.isEmpty, isTrue);
      expect(result.hasErrors, isTrue);
      expect(result.errors.any((e) => e.field == 'invoiceDate'), isTrue);
    });
  });

  group('DeliveryExportService - template', () {
    test('generateTemplate includes invoiceDate header', () {
      // Act
      final csv = DeliveryExportService.generateTemplate(withExamples: false);
      final rows = const CsvToListConverter().convert(csv);
      final headers = rows.first.map((e) => e.toString().trim()).toList();

      // Assert
      expect(headers.contains('invoiceDate'), isTrue);
    });
  });
}
