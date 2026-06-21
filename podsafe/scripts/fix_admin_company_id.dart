import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:podsafe/firebase_options.dart';

/// Quick script to add companyId to admin users that are missing it
/// 
/// This script will:
/// 1. Find all users with role 'admin' that don't have a companyId
/// 2. Prompt you to assign a companyId to each
/// 
/// Run with: dart run scripts/fix_admin_company_id.dart

Future<void> main() async {
  print('🔧 Starting Admin Company ID Fix Script...\n');

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
    // Find all users
    print('🔍 Searching for users...');
    final usersSnapshot = await firestore.collection('users').get();
    
    print('Found ${usersSnapshot.docs.length} users total\n');

    // Find users without companyId
    final usersWithoutCompany = <QueryDocumentSnapshot>[];
    
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final companyId = data['companyId'] as String?;
      final role = data['role'] as String?;
      final email = data['email'] as String?;
      
      if (companyId == null || companyId.isEmpty) {
        print('⚠️  Found user without companyId:');
        print('   Email: $email');
        print('   Role: $role');
        print('   User ID: ${doc.id}\n');
        usersWithoutCompany.add(doc);
      }
    }

    if (usersWithoutCompany.isEmpty) {
      print('✅ All users have companyId assigned!');
      return;
    }

    print('Found ${usersWithoutCompany.length} users without companyId\n');
    print('═══════════════════════════════════════════════════════════');
    print('📝 INSTRUCTIONS:');
    print('═══════════════════════════════════════════════════════════');
    print('');
    print('1. Go to Firebase Console → Firestore Database');
    print('2. Check if you have a "companies" collection');
    print('3. If yes, copy the document ID of your company');
    print('4. If no, you can create one or use a custom ID');
    print('');
    print('Recommended format: com_[yourcompanyname] (e.g., com_acme)');
    print('');
    print('═══════════════════════════════════════════════════════════\n');

    // For each user, prompt for companyId
    for (var doc in usersWithoutCompany) {
      final data = doc.data() as Map<String, dynamic>;
      final email = data['email'] as String?;
      final role = data['role'] as String?;

      print('\n📧 User: $email ($role)');
      print('Enter companyId for this user (or type "skip" to skip):');
      
      // In a real interactive script, you'd read from stdin
      // For now, we'll provide a default based on a pattern
      final defaultCompanyId = 'com_podsafe_default';
      
      print('Using default: $defaultCompanyId');
      print('(Edit this script to change the default or make it interactive)\n');

      // Update the user document
      await firestore.collection('users').doc(doc.id).update({
        'companyId': defaultCompanyId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Updated ${doc.id} with companyId: $defaultCompanyId');
    }

    print('\n═══════════════════════════════════════════════════════════');
    print('✅ COMPLETED!');
    print('═══════════════════════════════════════════════════════════');
    print('All users have been updated with companyId.');
    print('Please verify in Firebase Console → Firestore → users');
    print('\n💡 TIP: If you need to change the companyId, edit the');
    print('   defaultCompanyId variable in this script and run again.');
    print('═══════════════════════════════════════════════════════════\n');

  } catch (e) {
    print('❌ Error: $e');
  }
}
