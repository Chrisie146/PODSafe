import 'package:flutter_test/flutter_test.dart';
import 'package:podsafe/models/delivery_model.dart';
import 'package:podsafe/utils/vehicle_utils.dart';

void main() {
  group('Vehicle assignment conflict detection', () {
    test('No deliveries -> available', () {
      final deliveries = <Delivery>[];
      final grouped = _groupDeliveriesByVehicle(deliveries);
      expect(grouped.length, 0);
    });

    test('Single driver -> no conflict', () {
      final today = DateTime.now();
      final deliveries = [
        Delivery(
          id: 'd1',
          companyId: 'c',
          driverId: 'driverA',
          customerName: 'Cust',
          customerAddress: 'Addr',
          invoiceNumber: 'INV1',
          items: [],
          scheduledDate: today,
          createdAt: today,
        ),
      ];

      final grouped = _groupDeliveriesByVehicle(deliveries);
      expect(grouped.length, 1);
      final drivers = grouped['']!.map((d) => d.driverId).toSet();
      expect(drivers.length, 1);
    });

    test('Multiple drivers -> conflict', () {
      final today = DateTime.now();
      final deliveries = [
        Delivery(
          id: 'd1',
          companyId: 'c',
          driverId: 'driverA',
          customerName: 'Cust',
          customerAddress: 'A1',
          invoiceNumber: 'INV1',
          items: [],
          scheduledDate: today,
          createdAt: today,
          vehicleUsed: 'REG001',
        ),
        Delivery(
          id: 'd2',
          companyId: 'c',
          driverId: 'driverB',
          customerName: 'Cust2',
          customerAddress: 'A2',
          invoiceNumber: 'INV2',
          items: [],
          scheduledDate: today,
          createdAt: today,
          vehicleUsed: 'REG001',
        ),
      ];

      final grouped = _groupDeliveriesByVehicle(deliveries);
      expect(grouped.length, 1);
      final drivers = grouped['REG001']!.map((d) => d.driverId).toSet();
      expect(drivers.length, 2);
    });

    test('Normalization handles formatting differences', () {
      final today = DateTime.now();
      final deliveries = [
        Delivery(
          id: 'd1',
          companyId: 'c',
          driverId: 'driverA',
          customerName: 'Cust',
          customerAddress: 'A1',
          invoiceNumber: 'INV1',
          items: [],
          scheduledDate: today,
          createdAt: today,
          vehicleUsed: 'ABC 123',
        ),
        Delivery(
          id: 'd2',
          companyId: 'c',
          driverId: 'driverB',
          customerName: 'Cust2',
          customerAddress: 'A2',
          invoiceNumber: 'INV2',
          items: [],
          scheduledDate: today,
          createdAt: today,
          vehicleUsed: 'abc123',
        ),
      ];

      final grouped = _groupDeliveriesByVehicle(deliveries);
      // We store both normalized and raw keys; ensure normalized key groups both
      expect(grouped[ 'ABC123']!.length, 2);
      final drivers = grouped['ABC123']!.map((d) => d.driverId).toSet();
      expect(drivers.length, 2);
    });
  });
}

Map<String, List<Delivery>> _groupDeliveriesByVehicle(List<Delivery> deliveries) {
  final map = <String, List<Delivery>>{};
  for (var d in deliveries) {
    final reg = d.vehicleUsed == null ? '' : normalizeRegistration(d.vehicleUsed!);
    map.putIfAbsent(reg, () => []).add(d);
    // Also store under the raw value to support docId matches
    final raw = d.vehicleUsed ?? '';
    if (raw.isNotEmpty) {
      map.putIfAbsent(raw, () => []).add(d);
    }
  }
  return map;
}
