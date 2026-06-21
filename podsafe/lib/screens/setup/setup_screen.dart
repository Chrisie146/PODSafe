import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/data_migration_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _runSetup() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    _addLog('🚀 Starting Firebase Setup...\n');

    try {
      await _createTestCompany();
      await _createTestUsers();
      await _createTestDelivery();

      // Sign out after setup
      await FirebaseAuth.instance.signOut();

      _addLog('\n🎉 Setup completed successfully!');
      _addLog('\n📋 Test Credentials:');
      _addLog('Admin: admin@podsafe.com / Admin123!');
      _addLog('Driver: driver@podsafe.com / Driver123!');
      _addLog('\n⚠️  Change passwords in production!');
    } catch (e) {
      _addLog('❌ Setup failed: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _createTestCompany() async {
    _addLog('📦 Creating test company...');

    try {
      final firestore = FirebaseFirestore.instance;
      final companyDoc = await firestore.collection('companies').doc('company-001').get();

      if (companyDoc.exists) {
        _addLog('ℹ️  Company already exists\n');
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

      _addLog('✅ Company created (company-001)\n');
    } catch (e) {
      _addLog('⚠️  Company failed: $e\n');
    }
  }

  Future<void> _createTestUsers() async {
    _addLog('👥 Creating test users...');

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    // Admin User
    try {
      _addLog('  Creating admin...');
      UserCredential? adminCredential;

      try {
        adminCredential = await auth.createUserWithEmailAndPassword(
          email: 'admin@podsafe.com',
          password: 'Admin123!',
        );
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          _addLog('  ℹ️  Admin exists, signing in...');
          adminCredential = await auth.signInWithEmailAndPassword(
            email: 'admin@podsafe.com',
            password: 'Admin123!',
          );
        } else {
          rethrow;
        }
      }

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

      _addLog('  ✅ Admin created');
    } catch (e) {
      _addLog('  ⚠️  Admin failed: $e');
    }

    // Driver User
    try {
      _addLog('  Creating driver...');
      UserCredential? driverCredential;

      try {
        driverCredential = await auth.createUserWithEmailAndPassword(
          email: 'driver@podsafe.com',
          password: 'Driver123!',
        );
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          _addLog('  ℹ️  Driver exists, signing in...');
          driverCredential = await auth.signInWithEmailAndPassword(
            email: 'driver@podsafe.com',
            password: 'Driver123!',
          );
        } else {
          rethrow;
        }
      }

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

      _addLog('  ✅ Driver created');
    } catch (e) {
      _addLog('  ⚠️  Driver failed: $e');
    }

    // Keep admin signed in for delivery creation
    // Sign in as admin if not already signed in
    if (FirebaseAuth.instance.currentUser == null || 
        FirebaseAuth.instance.currentUser!.email != 'admin@podsafe.com') {
      await auth.signInWithEmailAndPassword(
        email: 'admin@podsafe.com',
        password: 'Admin123!',
      );
    }
    
    _addLog('✅ Users created\n');
  }

  Future<void> _createTestDelivery() async {
    _addLog('🚚 Creating test delivery...');

    try {
      final firestore = FirebaseFirestore.instance;

      final driverQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: 'driver@podsafe.com')
          .limit(1)
          .get();

      if (driverQuery.docs.isEmpty) {
        _addLog('⚠️  Driver not found\n');
        return;
      }

      final driverUid = driverQuery.docs.first.id;

      final existingDelivery = await firestore
          .collection('deliveries')
          .where('companyId', isEqualTo: 'company-001')
          .where('customerName', isEqualTo: 'John Doe')
          .limit(1)
          .get();

      if (existingDelivery.docs.isNotEmpty) {
        _addLog('ℹ️  Delivery exists\n');
        return;
      }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    await firestore.collection('deliveries').add({
      'companyId': 'company-001',
      'driverId': driverUid,
      'customerName': 'John Doe',
      'customerAddress': '456 Oak Ave, City, State 12345',
      'customerPhone': '+1234567892',
      'invoiceNumber': 'INV-TEST-001',
      'items': [
        {
          'description': 'Test Package',
          'quantity': 1,
          'unit': 'box',
        }
      ],
      'status': 'pending',
      'scheduledDate': Timestamp.fromDate(today.add(const Duration(hours: 10))),
      'notes': 'Test delivery - Handle with care',
      'createdAt': FieldValue.serverTimestamp(),
    });      _addLog('✅ Delivery created\n');
    } catch (e) {
      _addLog('⚠️  Delivery failed: $e\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Setup'),
        backgroundColor: const Color(0xFF2E7D8C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Firebase Test Data Setup',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will create test users, company, and sample delivery in Firebase.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runSetup,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_isRunning ? 'Running Setup...' : 'Run Setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D8C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Migration Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DataMigrationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Migrate to Multi-Company'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                
                const SizedBox(height: 8),
                const Text(
                  'Run this once if you have existing data to migrate.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        color: Colors.greenAccent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
