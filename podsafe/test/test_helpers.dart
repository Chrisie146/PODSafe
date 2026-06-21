import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Test helper utilities for PODSafe tests
class TestHelpers {
  /// Create a mock Firebase Auth instance with a signed-in user
  static MockFirebaseAuth createMockAuth({
    bool isSignedIn = true,
    String uid = 'test-user-123',
    String email = 'test@example.com',
    String displayName = 'Test User',
  }) {
    final user = MockUser(
      isAnonymous: false,
      uid: uid,
      email: email,
      displayName: displayName,
    );

    return MockFirebaseAuth(
      signedIn: isSignedIn,
      mockUser: user,
    );
  }

  /// Create a fake Firestore instance for testing
  static FakeFirebaseFirestore createMockFirestore() {
    return FakeFirebaseFirestore();
  }

  /// Seed mock Firestore with test data
  static Future<void> seedFirestore(FakeFirebaseFirestore firestore) async {
    // Add test company
    await firestore.collection('companies').doc('test-company-123').set({
      'name': 'Test Company',
      'email': 'company@test.com',
      'createdAt': DateTime.now(),
      'isActive': true,
    });

    // Add test user
    await firestore.collection('users').doc('test-user-123').set({
      'fullName': 'Test User',
      'email': 'test@example.com',
      'role': 'admin',
      'companyId': 'test-company-123',
      'isApproved': true,
      'createdAt': DateTime.now(),
    });

    // Add test driver
    await firestore.collection('users').doc('test-driver-123').set({
      'fullName': 'Test Driver',
      'email': 'driver@example.com',
      'role': 'driver',
      'companyId': 'test-company-123',
      'isApproved': true,
      'createdAt': DateTime.now(),
    });

    // Add test customer
    await firestore.collection('customers').doc('test-customer-123').set({
      'name': 'Test Customer',
      'accountNumber': 'CUST001',
      'email': 'customer@example.com',
      'phone': '+27123456789',
      'companyId': 'test-company-123',
      'createdAt': DateTime.now(),
    });

    // Add test delivery
    await firestore.collection('deliveries').doc('test-delivery-123').set({
      'companyId': 'test-company-123',
      'customerId': 'test-customer-123',
      'customerName': 'Test Customer',
      'driverId': 'test-driver-123',
      'driverName': 'Test Driver',
      'status': 'pending',
      'address': '123 Test Street, Test City',
      'scheduledDate': DateTime.now(),
      'createdAt': DateTime.now(),
    });

    // Add test claim
    await firestore
        .collection('companies')
        .doc('test-company-123')
        .collection('claims')
        .doc('test-claim-123')
        .set({
      'title': 'Test Claim',
      'description': 'Test claim description',
      'type': 'damaged',
      'status': 'submitted',
      'priority': 'medium',
      'companyId': 'test-company-123',
      'driverId': 'test-driver-123',
      'driverName': 'Test Driver',
      'deliveryId': 'test-delivery-123',
      'filingContext': 'atDeliverySite',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'photoUrls': [],
      'comments': [],
    });
  }

  /// Create test DateTime with specific time
  static DateTime createTestDate({
    int year = 2025,
    int month = 10,
    int day = 19,
    int hour = 10,
    int minute = 0,
  }) {
    return DateTime(year, month, day, hour, minute);
  }

  /// Wait for async operations to complete
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }
}

/// Custom matchers for testing
class CustomMatchers {
  /// Matcher to check if a DateTime is close to another (within seconds)
  static Matcher isCloseTo(DateTime expected, {int seconds = 5}) {
    return predicate<DateTime>(
      (actual) {
        final difference = actual.difference(expected).inSeconds.abs();
        return difference <= seconds;
      },
      'is within $seconds seconds of $expected',
    );
  }

  /// Matcher to check if a string contains all words
  static Matcher containsAllWords(List<String> words) {
    return predicate<String>(
      (actual) {
        return words.every((word) => actual.toLowerCase().contains(word.toLowerCase()));
      },
      'contains all words: ${words.join(", ")}',
    );
  }
}

/// Mock data builders
class MockData {
  static Map<String, dynamic> mockDelivery({
    String id = 'mock-delivery-1',
    String status = 'pending',
    String? driverId,
  }) {
    return {
      'id': id,
      'companyId': 'test-company-123',
      'customerId': 'test-customer-123',
      'customerName': 'Mock Customer',
      'driverId': driverId ?? 'test-driver-123',
      'driverName': 'Mock Driver',
      'status': status,
      'address': '123 Mock Street',
      'scheduledDate': DateTime.now(),
      'createdAt': DateTime.now(),
    };
  }

  static Map<String, dynamic> mockClaim({
    String id = 'mock-claim-1',
    String status = 'submitted',
  }) {
    return {
      'id': id,
      'title': 'Mock Claim',
      'description': 'Mock claim description',
      'type': 'damaged',
      'status': status,
      'priority': 'medium',
      'companyId': 'test-company-123',
      'driverId': 'test-driver-123',
      'deliveryId': 'test-delivery-123',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };
  }

  static Map<String, dynamic> mockUser({
    String id = 'mock-user-1',
    String role = 'admin',
  }) {
    return {
      'id': id,
      'fullName': 'Mock User',
      'email': 'mock@example.com',
      'role': role,
      'companyId': 'test-company-123',
      'isApproved': true,
      'createdAt': DateTime.now(),
    };
  }
}
