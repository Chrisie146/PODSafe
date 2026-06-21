import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Setup Script
/// This script automatically creates test users and initial data in Firebase
/// Run with: flutter run lib/setup/firebase_setup_script.dart

Future<void> main() async {
  print('🚀 Starting Firebase Setup...\n');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized\n');
    
    // Run setup steps
    await createTestCompany();
    await createTestUsers();
    await createTestDelivery();
    
    print('\n🎉 Firebase setup completed successfully!');
    print('\n📋 Test Credentials:');
    print('Admin - Email: admin@podsafe.com, Password: Admin123!');
    print('Driver - Email: driver@podsafe.com, Password: Driver123!');
    print('\n⚠️  Remember to change passwords in production!\n');
    
  } catch (e) {
    print('❌ Setup failed: $e');
  }
}

/// Create test company
Future<void> createTestCompany() async {
  print('📦 Creating test company...');
  
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Check if company already exists
    final companyDoc = await firestore.collection('companies').doc('company-001').get();
    
    if (companyDoc.exists) {
      print('ℹ️  Company already exists, skipping...\n');
      return;
    }
    
    await firestore.collection('companies').doc('company-001').set({
      'name': 'Test Company',
      'address': '123 Main St, City, State 12345',
      'contactEmail': 'contact@testcompany.com',
      'contactPhone': '+1234567890',
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'subscriptionPlan': 'premium',
      'subscriptionExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 365)),
      ),
    });
    
    print('✅ Test company created (ID: company-001)\n');
  } catch (e) {
    print('⚠️  Company creation failed: $e\n');
  }
}

/// Create test users (Admin and Driver)
Future<void> createTestUsers() async {
  print('👥 Creating test users...');
  
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  
  // Admin User
  try {
    print('  Creating admin user...');
    UserCredential adminCredential;
    
    try {
      // Try to create the user
      adminCredential = await auth.createUserWithEmailAndPassword(
        email: 'admin@podsafe.com',
        password: 'Admin123!',
      );
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        print('  ℹ️  Admin user already exists in Auth, signing in...');
        adminCredential = await auth.signInWithEmailAndPassword(
          email: 'admin@podsafe.com',
          password: 'Admin123!',
        );
      } else {
        rethrow;
      }
    }
    
    // Create/Update Firestore document
    final adminUid = adminCredential.user!.uid;
    await firestore.collection('users').doc(adminUid).set({
      'id': adminUid,
      'email': 'admin@podsafe.com',
      'fullName': 'Admin User',
      'role': 'admin',
      'companyId': 'company-001',
      'phoneNumber': '+1234567890',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    print('  ✅ Admin user created (UID: $adminUid)');
  } catch (e) {
    print('  ⚠️  Admin user creation failed: $e');
  }
  
  // Driver User
  try {
    print('  Creating driver user...');
    UserCredential driverCredential;
    
    try {
      // Try to create the user
      driverCredential = await auth.createUserWithEmailAndPassword(
        email: 'driver@podsafe.com',
        password: 'Driver123!',
      );
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        print('  ℹ️  Driver user already exists in Auth, signing in...');
        driverCredential = await auth.signInWithEmailAndPassword(
          email: 'driver@podsafe.com',
          password: 'Driver123!',
        );
      } else {
        rethrow;
      }
    }
    
    // Create/Update Firestore document
    final driverUid = driverCredential.user!.uid;
    await firestore.collection('users').doc(driverUid).set({
      'id': driverUid,
      'email': 'driver@podsafe.com',
      'fullName': 'Test Driver',
      'role': 'driver',
      'companyId': 'company-001',
      'phoneNumber': '+1234567891',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    print('  ✅ Driver user created (UID: $driverUid)');
  } catch (e) {
    print('  ⚠️  Driver user creation failed: $e');
  }
  
  // Sign out after creation
  await auth.signOut();
  print('✅ Test users created\n');
}

/// Create test delivery
Future<void> createTestDelivery() async {
  print('🚚 Creating test delivery...');
  
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Get driver UID
    final driverQuery = await firestore
        .collection('users')
        .where('email', isEqualTo: 'driver@podsafe.com')
        .limit(1)
        .get();
    
    if (driverQuery.docs.isEmpty) {
      print('⚠️  Driver not found, skipping delivery creation\n');
      return;
    }
    
    final driverUid = driverQuery.docs.first.id;
    
    // Check if test delivery already exists
    final existingDelivery = await firestore
        .collection('deliveries')
        .where('companyId', isEqualTo: 'company-001')
        .where('customerName', isEqualTo: 'John Doe')
        .limit(1)
        .get();
    
    if (existingDelivery.docs.isNotEmpty) {
      print('ℹ️  Test delivery already exists, skipping...\n');
      return;
    }
    
    await firestore.collection('deliveries').add({
      'companyId': 'company-001',
      'assignedDriverId': driverUid,
      'customerName': 'John Doe',
      'customerPhone': '+1234567892',
      'customerEmail': 'john.doe@example.com',
      'deliveryAddress': '456 Oak Ave, City, State 12345',
      'pickupAddress': '789 Pine Rd, City, State 12345',
      'status': 'assigned',
      'priority': 'normal',
      'scheduledPickupTime': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 2)),
      ),
      'scheduledDeliveryTime': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 4)),
      ),
      'items': [
        {
          'name': 'Package 1',
          'quantity': 10,
          'weight': 5.5,
          'description': 'Premium product boxes',
          'unit': 'boxes',
        },
        {
          'name': 'Package 2',
          'quantity': 5,
          'weight': 3.2,
          'description': 'Standard product units',
          'unit': 'units',
        }
      ],
      'specialInstructions': 'Handle with care',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ Test delivery created\n');
  } catch (e) {
    print('⚠️  Delivery creation failed: $e\n');
  }
}
