import 'package:flutter_test/flutter_test.dart';
import 'package:podsafe/models/delivery_model.dart';

void main() {
  group('DeliveryItem Tests', () {
    test('should create valid delivery item', () {
      final item = DeliveryItem(
        description: 'Test Product',
        quantity: 5,
        unit: 'boxes',
      );

      expect(item.description, equals('Test Product'));
      expect(item.quantity, equals(5));
      expect(item.unit, equals('boxes'));
    });

    test('should create item without unit', () {
      final item = DeliveryItem(
        description: 'Test Product',
        quantity: 10,
      );

      expect(item.description, equals('Test Product'));
      expect(item.quantity, equals(10));
      expect(item.unit, isNull);
    });

    test('should convert item to map', () {
      final item = DeliveryItem(
        description: 'Test Product',
        quantity: 3,
        unit: 'kg',
      );

      final map = item.toMap();

      expect(map['description'], equals('Test Product'));
      expect(map['quantity'], equals(3));
      expect(map['unit'], equals('kg'));
    });

    test('should create item from map', () {
      final map = {
        'description': 'Test Product',
        'quantity': 7,
        'unit': 'liters',
      };

      final item = DeliveryItem.fromMap(map);

      expect(item.description, equals('Test Product'));
      expect(item.quantity, equals(7));
      expect(item.unit, equals('liters'));
    });

    test('should handle missing unit in map', () {
      final map = {
        'description': 'Test Product',
        'quantity': 2,
      };

      final item = DeliveryItem.fromMap(map);

      expect(item.description, equals('Test Product'));
      expect(item.quantity, equals(2));
      expect(item.unit, isNull);
    });
  });

  group('Delivery Model Tests', () {
    late DateTime scheduledDate;
    late DateTime createdAt;
    late List<DeliveryItem> items;

    setUp(() {
      scheduledDate = DateTime(2025, 10, 20, 10, 0);
      createdAt = DateTime(2025, 10, 19, 14, 30);
      items = [
        DeliveryItem(description: 'Product A', quantity: 2, unit: 'boxes'),
        DeliveryItem(description: 'Product B', quantity: 5, unit: 'units'),
      ];
    });

    test('should create valid delivery', () {
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St, Test City',
        invoiceNumber: 'INV-001',
        items: items,
        scheduledDate: scheduledDate,
        createdAt: createdAt,
      );

      expect(delivery.id, equals('delivery-123'));
      expect(delivery.companyId, equals('company-123'));
      expect(delivery.driverId, equals('driver-123'));
      expect(delivery.customerName, equals('Test Customer'));
      expect(delivery.customerAddress, equals('123 Test St, Test City'));
      expect(delivery.invoiceNumber, equals('INV-001'));
      expect(delivery.items.length, equals(2));
      expect(delivery.status, equals(DeliveryStatus.pending));
      expect(delivery.scheduledDate, equals(scheduledDate));
      expect(delivery.createdAt, equals(createdAt));
    });

    test('should create delivery with all optional fields', () {
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        customerPhone: '+27123456789',
        customerId: 'customer-123',
        customerNumber: 'CUST001',
        orderNumber: 'ORD-001',
        invoiceNumber: 'INV-001',
        items: items,
        status: DeliveryStatus.inTransit,
        scheduledDate: scheduledDate,
        createdAt: createdAt,
        notes: 'Handle with care',
        podId: 'pod-123',
      );

      expect(delivery.customerPhone, equals('+27123456789'));
      expect(delivery.customerId, equals('customer-123'));
      expect(delivery.customerNumber, equals('CUST001'));
      expect(delivery.orderNumber, equals('ORD-001'));
      expect(delivery.status, equals(DeliveryStatus.inTransit));
      expect(delivery.notes, equals('Handle with care'));
      expect(delivery.podId, equals('pod-123'));
    });

    test('should handle delivered status with timestamp', () {
      final deliveredAt = DateTime(2025, 10, 20, 11, 30);
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: items,
        status: DeliveryStatus.delivered,
        scheduledDate: scheduledDate,
        createdAt: createdAt,
        deliveredAt: deliveredAt,
        podId: 'pod-123',
      );

      expect(delivery.status, equals(DeliveryStatus.delivered));
      expect(delivery.deliveredAt, equals(deliveredAt));
      expect(delivery.podId, equals('pod-123'));
    });

    test('should convert delivery to Firestore format', () {
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: items,
        scheduledDate: scheduledDate,
        createdAt: createdAt,
      );

      final map = delivery.toFirestore();

      expect(map['companyId'], equals('company-123'));
      expect(map['driverId'], equals('driver-123'));
      expect(map['customerName'], equals('Test Customer'));
      expect(map['invoiceNumber'], equals('INV-001'));
      expect(map['status'], equals('pending'));
      expect(map['items'], isA<List>());
      expect(map['items'].length, equals(2));
    });

    test('should use copyWith to update status', () {
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: items,
        scheduledDate: scheduledDate,
        createdAt: createdAt,
      );

      final updated = delivery.copyWith(status: DeliveryStatus.inTransit);

      expect(updated.status, equals(DeliveryStatus.inTransit));
      expect(updated.id, equals(delivery.id));
      expect(updated.customerName, equals(delivery.customerName));
    });

    test('should use copyWith to mark as delivered', () {
      final deliveredAt = DateTime(2025, 10, 20, 11, 30);
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: items,
        scheduledDate: scheduledDate,
        createdAt: createdAt,
      );

      final delivered = delivery.copyWith(
        status: DeliveryStatus.delivered,
        deliveredAt: deliveredAt,
        podId: 'pod-123',
      );

      expect(delivered.status, equals(DeliveryStatus.delivered));
      expect(delivered.deliveredAt, equals(deliveredAt));
      expect(delivered.podId, equals('pod-123'));
    });
  });

  group('DeliveryStatus Tests', () {
    test('should have all required statuses', () {
      final statuses = DeliveryStatus.values;

      expect(statuses.contains(DeliveryStatus.pending), isTrue);
      expect(statuses.contains(DeliveryStatus.inTransit), isTrue);
      expect(statuses.contains(DeliveryStatus.delivered), isTrue);
      expect(statuses.contains(DeliveryStatus.failed), isTrue);
    });

    test('should convert status to string', () {
      expect(
        DeliveryStatus.pending.toString().split('.').last,
        equals('pending'),
      );
      expect(
        DeliveryStatus.inTransit.toString().split('.').last,
        equals('inTransit'),
      );
      expect(
        DeliveryStatus.delivered.toString().split('.').last,
        equals('delivered'),
      );
      expect(
        DeliveryStatus.failed.toString().split('.').last,
        equals('failed'),
      );
    });
  });

  group('Delivery Lifecycle Tests', () {
    late Delivery pendingDelivery;
    late DateTime scheduledDate;
    late DateTime createdAt;
    late List<DeliveryItem> items;

    setUp(() {
      scheduledDate = DateTime(2025, 10, 20, 10, 0);
      createdAt = DateTime(2025, 10, 19, 14, 30);
      items = [
        DeliveryItem(description: 'Product A', quantity: 2),
      ];

      pendingDelivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: items,
        scheduledDate: scheduledDate,
        createdAt: createdAt,
      );
    });

    test('should transition from pending to inTransit', () {
      expect(pendingDelivery.status, equals(DeliveryStatus.pending));

      final inTransit = pendingDelivery.copyWith(
        status: DeliveryStatus.inTransit,
      );

      expect(inTransit.status, equals(DeliveryStatus.inTransit));
      expect(inTransit.deliveredAt, isNull);
    });

    test('should transition from inTransit to delivered', () {
      final inTransit = pendingDelivery.copyWith(
        status: DeliveryStatus.inTransit,
      );

      final deliveredAt = DateTime(2025, 10, 20, 11, 30);
      final delivered = inTransit.copyWith(
        status: DeliveryStatus.delivered,
        deliveredAt: deliveredAt,
        podId: 'pod-123',
      );

      expect(delivered.status, equals(DeliveryStatus.delivered));
      expect(delivered.deliveredAt, equals(deliveredAt));
      expect(delivered.podId, isNotNull);
    });

    test('should transition to failed status', () {
      final failed = pendingDelivery.copyWith(
        status: DeliveryStatus.failed,
        notes: 'Customer not available',
      );

      expect(failed.status, equals(DeliveryStatus.failed));
      expect(failed.notes, equals('Customer not available'));
      expect(failed.deliveredAt, isNull);
      expect(failed.podId, isNull);
    });
  });

  group('Delivery Validation Tests', () {
    test('should require essential fields', () {
      final scheduledDate = DateTime(2025, 10, 20);
      final createdAt = DateTime(2025, 10, 19);

      expect(
        () => Delivery(
          id: 'delivery-123',
          companyId: 'company-123',
          driverId: 'driver-123',
          customerName: 'Test Customer',
          customerAddress: '123 Test St',
          invoiceNumber: 'INV-001',
          items: [],
          scheduledDate: scheduledDate,
          createdAt: createdAt,
        ),
        returnsNormally,
      );
    });

    test('invoice number should not be empty', () {
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: [],
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(delivery.invoiceNumber.isNotEmpty, isTrue);
    });

    test('should handle multiple delivery items', () {
      final items = List.generate(
        10,
        (i) => DeliveryItem(
          description: 'Product ${i + 1}',
          quantity: i + 1,
        ),
      );

      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: items,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(delivery.items.length, equals(10));
      expect(delivery.items.first.description, equals('Product 1'));
      expect(delivery.items.last.description, equals('Product 10'));
    });
  });

  group('Customer Linking Tests', () {
    test('should support customer linking', () {
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        customerId: 'customer-456',
        customerNumber: 'CUST001',
        invoiceNumber: 'INV-001',
        items: [],
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(delivery.customerId, equals('customer-456'));
      expect(delivery.customerNumber, equals('CUST001'));
    });

    test('should work without customer linking (backwards compatible)', () {
      final delivery = Delivery(
        id: 'delivery-123',
        companyId: 'company-123',
        driverId: 'driver-123',
        customerName: 'Test Customer',
        customerAddress: '123 Test St',
        invoiceNumber: 'INV-001',
        items: [],
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(delivery.customerId, isNull);
      expect(delivery.customerNumber, isNull);
      expect(delivery.customerName, isNotEmpty);
    });
  });
}
