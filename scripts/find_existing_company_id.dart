import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:podsafe/firebase_options.dart';

/// Script to find existing companyIds in your database
/// This will help you identify the correct companyId to use
/// 
/// Run with: dart run scripts/find_existing_company_id.dart

Future<void> main() async {
  print('🔍 Finding existing company IDs in your database...\n');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized\n');
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
    return;
  }

  final firestore = FirebaseFirestore.instance;

  try {
    // Check deliveries collection
    print('📦 Checking deliveries collection...');
    final deliveriesSnapshot = await firestore
        .collection('deliveries')
        .limit(10)
        .get();

    final deliveryCompanyIds = <String>{};
    for (var doc in deliveriesSnapshot.docs) {
      final companyId = doc.data()['companyId'] as String?;
      if (companyId != null && companyId.isNotEmpty) {
        deliveryCompanyIds.add(companyId);
      }
    }

    if (deliveryCompanyIds.isNotEmpty) {
      print('✅ Found ${deliveriesSnapshot.docs.length} deliveries');
      print('   Company IDs used: ${deliveryCompanyIds.join(", ")}\n');
    } else {
      print('⚠️  No deliveries found or no companyId field\n');
    }

    // Check users collection
    print('👥 Checking users collection...');
    final usersSnapshot = await firestore
        .collection('users')
        .get();

    final userCompanyIds = <String, List<String>>{};
    for (var doc in usersSnapshot.docs) {
      final email = doc.data()['email'] as String?;
      final companyId = doc.data()['companyId'] as String?;
      final role = doc.data()['role'] as String?;
      
      if (companyId != null && companyId.isNotEmpty) {
        if (!userCompanyIds.containsKey(companyId)) {
          userCompanyIds[companyId] = [];
        }
        userCompanyIds[companyId]!.add('$email ($role)');
      } else {
        print('   ⚠️  User without companyId: $email ($role)');
      }
    }

    if (userCompanyIds.isNotEmpty) {
      print('✅ Found ${usersSnapshot.docs.length} users');
      print('   Company IDs breakdown:');
      userCompanyIds.forEach((companyId, users) {
        print('   - $companyId: ${users.length} users');
        for (var user in users) {
          print('     • $user');
        }
      });
      print('');
    }

    // Check customers collection
    print('👤 Checking customers collection...');
    final customersSnapshot = await firestore
        .collection('customers')
        .limit(10)
        .get();

    final customerCompanyIds = <String>{};
    for (var doc in customersSnapshot.docs) {
      final companyId = doc.data()['companyId'] as String?;
      if (companyId != null && companyId.isNotEmpty) {
        customerCompanyIds.add(companyId);
      }
    }

    if (customerCompanyIds.isNotEmpty) {
      print('✅ Found ${customersSnapshot.docs.length} customers');
      print('   Company IDs used: ${customerCompanyIds.join(", ")}\n');
    } else {
      print('⚠️  No customers found or no companyId field\n');
    }

    // Summary
    print('═══════════════════════════════════════════════════════════');
    print('📊 SUMMARY');
    print('═══════════════════════════════════════════════════════════');
    
    final allCompanyIds = <String>{
      ...deliveryCompanyIds,
      ...userCompanyIds.keys,
      ...customerCompanyIds,
    };

    if (allCompanyIds.isEmpty) {
      print('❌ No company IDs found in any collection!');
      print('   Your data might not have companyId fields yet.');
      print('   You may need to run a migration script.');
    } else if (allCompanyIds.length == 1) {
      final correctId = allCompanyIds.first;
      print('✅ Found ONE company ID: $correctId');
      print('');
      print('🎯 ACTION REQUIRED:');
      print('═══════════════════════════════════════════════════════════');
      print('Update your admin user with this company ID:');
      print('');
      print('1. Go to Firebase Console → Firestore → users collection');
      print('2. Find your admin user document');
      print('3. Update the companyId field to: $correctId');
      print('4. Refresh your app (press R in terminal)');
      print('');
      print('OR run this command to fix automatically:');
      print('   (Edit the script below with your admin email)');
    } else {
      print('⚠️  Found MULTIPLE company IDs: ${allCompanyIds.join(", ")}');
      print('');
      print('This suggests you might have data from multiple companies');
      print('or inconsistent companyId values.');
      print('');
      print('🎯 ACTION REQUIRED:');
      print('Check which companyId has the most data and use that one.');
    }

    print('═══════════════════════════════════════════════════════════\n');

  } catch (e) {
    print('❌ Error: $e');
  }
}
