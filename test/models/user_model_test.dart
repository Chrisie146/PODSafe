import 'package:flutter_test/flutter_test.dart';
import 'package:podsafe/models/user_model.dart';

void main() {
  group('User Model Tests', () {
    test('should create valid admin user', () {
      final user = AppUser(
        id: 'test-123',
        email: 'test@example.com',
        fullName: 'Test User',
        role: UserRole.admin,
        companyId: 'company-123',
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(user.id, equals('test-123'));
      expect(user.email, equals('test@example.com'));
      expect(user.fullName, equals('Test User'));
      expect(user.role, equals(UserRole.admin));
      expect(user.companyId, equals('company-123'));
      expect(user.isActive, isTrue);
    });

    test('should create valid driver user', () {
      final user = AppUser(
        id: 'driver-123',
        email: 'driver@example.com',
        fullName: 'Test Driver',
        role: UserRole.driver,
        companyId: 'company-123',
        isActive: true,
        createdAt: DateTime.now(),
        phoneNumber: '+27123456789',
        licenseNumber: 'DL12345',
        vehicleInfo: 'Toyota Hilux',
        approvalStatus: 'approved',
      );

      expect(user.role, equals(UserRole.driver));
      expect(user.phoneNumber, equals('+27123456789'));
      expect(user.licenseNumber, equals('DL12345'));
      expect(user.vehicleInfo, equals('Toyota Hilux'));
      expect(user.approvalStatus, equals('approved'));
    });

    test('should handle inactive user', () {
      final user = AppUser(
        id: 'test-123',
        email: 'test@example.com',
        fullName: 'Inactive User',
        role: UserRole.admin,
        companyId: 'company-123',
        isActive: false,
        createdAt: DateTime.now(),
      );

      expect(user.isActive, isFalse);
    });

    test('should convert user to Firestore format', () {
      final now = DateTime.now();
      final user = AppUser(
        id: 'test-123',
        email: 'test@example.com',
        fullName: 'Test User',
        role: UserRole.admin,
        companyId: 'company-123',
        isActive: true,
        createdAt: now,
      );

      final map = user.toFirestore();

      expect(map['email'], equals('test@example.com'));
      expect(map['fullName'], equals('Test User'));
      expect(map['role'], equals('admin'));
      expect(map['companyId'], equals('company-123'));
      expect(map['isActive'], isTrue);
    });

    test('should handle optional fields', () {
      final user = AppUser(
        id: 'test-123',
        email: 'test@example.com',
        fullName: 'Test User',
        role: UserRole.admin,
        companyId: 'company-123',
        isActive: true,
        createdAt: DateTime.now(),
        phoneNumber: '+27123456789',
        profileImageUrl: 'https://example.com/image.jpg',
        lastLoginAt: DateTime.now(),
      );

      expect(user.phoneNumber, equals('+27123456789'));
      expect(user.profileImageUrl, equals('https://example.com/image.jpg'));
      expect(user.lastLoginAt, isNotNull);
    });

    test('should handle driver approval workflow', () {
      final pendingDriver = AppUser(
        id: 'driver-123',
        email: 'driver@example.com',
        fullName: 'Pending Driver',
        role: UserRole.driver,
        companyId: 'company-123',
        isActive: true,
        createdAt: DateTime.now(),
        approvalStatus: 'pending',
      );

      expect(pendingDriver.approvalStatus, equals('pending'));
      expect(pendingDriver.approvedBy, isNull);
      expect(pendingDriver.approvedAt, isNull);

      // Simulate approval
      final approvedDriver = AppUser(
        id: pendingDriver.id,
        email: pendingDriver.email,
        fullName: pendingDriver.fullName,
        role: pendingDriver.role,
        companyId: pendingDriver.companyId,
        isActive: pendingDriver.isActive,
        createdAt: pendingDriver.createdAt,
        approvalStatus: 'approved',
        approvedBy: 'admin-123',
        approvedAt: DateTime.now(),
      );

      expect(approvedDriver.approvalStatus, equals('approved'));
      expect(approvedDriver.approvedBy, equals('admin-123'));
      expect(approvedDriver.approvedAt, isNotNull);
    });

    test('should convert role enum to string', () {
      expect(UserRole.admin.toString().split('.').last, equals('admin'));
      expect(UserRole.driver.toString().split('.').last, equals('driver'));
    });

    test('should handle different approval statuses', () {
      final statuses = ['pending', 'approved', 'rejected'];
      
      for (final status in statuses) {
        final driver = AppUser(
          id: 'driver-123',
          email: 'driver@example.com',
          fullName: 'Test Driver',
          role: UserRole.driver,
          companyId: 'company-123',
          isActive: true,
          createdAt: DateTime.now(),
          approvalStatus: status,
        );

        expect(driver.approvalStatus, equals(status));
      }
    });
  });

  group('Validation Tests', () {
    test('email should contain @ and .', () {
      final validEmails = [
        'test@example.com',
        'user+tag@domain.co.za',
        'admin@company.com',
      ];

      for (final email in validEmails) {
        expect(email.contains('@'), isTrue);
        expect(email.contains('.'), isTrue);
      }
    });

    test('should detect invalid email formats', () {
      final invalidEmails = [
        'notanemail',
        '@example.com',
        'user@',
        '',
      ];

      for (final email in invalidEmails) {
        final isValid = email.contains('@') && 
                        email.contains('.') && 
                        email.indexOf('@') > 0 &&
                        email.indexOf('.') > email.indexOf('@');
        expect(isValid, isFalse);
      }
    });

    test('role should be admin or driver', () {
      final validRoles = [UserRole.admin, UserRole.driver];
      
      for (final role in validRoles) {
        expect(
          role == UserRole.admin || role == UserRole.driver,
          isTrue,
        );
      }
    });

    test('companyId should not be empty', () {
      final companyId = 'test-company-123';
      expect(companyId.isNotEmpty, isTrue);
      expect(companyId.isNotEmpty, isTrue);
    });
  });

  group('Role-based Logic', () {
    test('admin users should have correct properties', () {
      final admin = AppUser(
        id: 'admin-123',
        email: 'admin@test.com',
        fullName: 'Test Admin',
        role: UserRole.admin,
        companyId: 'test-company-123',
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(admin.role, equals(UserRole.admin));
      expect(admin.role == UserRole.driver, isFalse);
      expect(admin.companyId, equals('test-company-123'));
      expect(admin.isActive, isTrue);
    });

    test('driver users should have driver-specific fields', () {
      final driver = AppUser(
        id: 'driver-123',
        email: 'driver@test.com',
        fullName: 'Test Driver',
        role: UserRole.driver,
        companyId: 'test-company-123',
        isActive: true,
        createdAt: DateTime.now(),
        licenseNumber: 'DL12345',
        vehicleInfo: 'Toyota Hilux',
        approvalStatus: 'approved',
      );

      expect(driver.role, equals(UserRole.driver));
      expect(driver.licenseNumber, isNotNull);
      expect(driver.vehicleInfo, isNotNull);
      expect(driver.approvalStatus, equals('approved'));
    });
  });
}
