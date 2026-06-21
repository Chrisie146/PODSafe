import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:podsafe/firebase_options.dart';

/// Migration Script: Backfill User Roles and Active Status
/// 
/// This script updates existing users in Firestore to ensure they have:
/// - A valid role (default: manager for staff, driver for drivers)
/// - isActive flag (default: true)
/// - Proper approval status for drivers
/// 
/// USAGE:
/// 1. Run from terminal: dart run scripts/migrate_user_roles.dart
/// 2. Or add as a function in Firebase Console
/// 3. Review changes before running in production
/// 
/// SAFETY:
/// - Only updates users that are missing required fields
/// - Does not overwrite existing valid data
/// - Logs all changes for review
/// - Can be run multiple times safely (idempotent)

void main() async {
  print('🚀 Starting user role migration...\n');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized\n');
    
    final firestore = FirebaseFirestore.instance;
    
    // Get all users
    final usersSnapshot = await firestore.collection('users').get();
    
    print('📊 Found ${usersSnapshot.docs.length} users to process\n');
    print('${'='*60}\n');
    
    int updated = 0;
    int skipped = 0;
    int errors = 0;
    
    for (var doc in usersSnapshot.docs) {
      try {
        final data = doc.data();
        final userId = doc.id;
        final email = data['email'] ?? 'unknown';
        final currentRole = data['role'];
        
        print('Processing user: $email ($userId)');
        
        Map<String, dynamic> updates = {};
        
        // 1. Ensure user has a role
        if (currentRole == null || currentRole.isEmpty) {
          // Default role assignment logic
          // If user has driver-specific fields, assign driver role
          if (data.containsKey('licenseNumber') || 
              data.containsKey('vehicleInfo') ||
              data.containsKey('approvalStatus')) {
            updates['role'] = 'driver';
            print('  ➜ Assigning role: driver (has driver fields)');
          } else {
            // Default to manager for staff
            updates['role'] = 'manager';
            print('  ➜ Assigning role: manager (default staff)');
          }
        } else {
          print('  ✓ Has role: $currentRole');
        }
        
        // 2. Ensure user has isActive flag
        if (!data.containsKey('isActive')) {
          updates['isActive'] = true;
          print('  ➜ Setting isActive: true');
        } else {
          print('  ✓ Has isActive: ${data['isActive']}');
        }
        
        // 3. For drivers, ensure approvalStatus exists
        if ((currentRole == 'driver' || updates['role'] == 'driver')) {
          if (!data.containsKey('approvalStatus') || data['approvalStatus'] == null) {
            // Check if they were previously approved (legacy field)
            if (data.containsKey('approved') && data['approved'] == true) {
              updates['approvalStatus'] = 'approved';
              print('  ➜ Migrating approval: approved (from legacy field)');
            } else {
              updates['approvalStatus'] = 'pending';
              print('  ➜ Setting approvalStatus: pending');
            }
          } else {
            print('  ✓ Has approvalStatus: ${data['approvalStatus']}');
          }
        }
        
        // 4. Ensure companyId exists
        if (!data.containsKey('companyId') || data['companyId'] == null || data['companyId'].isEmpty) {
          print('  ⚠️  WARNING: User has no companyId! Please assign manually.');
          // You might want to set a default companyId or skip this user
          // updates['companyId'] = 'default-company'; // Uncomment if needed
        }
        
        // Apply updates if any
        if (updates.isNotEmpty) {
          await firestore.collection('users').doc(userId).update(updates);
          updated++;
          print('  ✅ Updated with ${updates.length} changes\n');
        } else {
          skipped++;
          print('  ⏭️  No changes needed\n');
        }
        
      } catch (e) {
        errors++;
        print('  ❌ Error processing user: $e\n');
      }
    }
    
    print('${'='*60}\n');
    print('📈 MIGRATION SUMMARY:');
    print('   Total users: ${usersSnapshot.docs.length}');
    print('   ✅ Updated: $updated');
    print('   ⏭️  Skipped: $skipped');
    print('   ❌ Errors: $errors');
    print('\n✨ Migration complete!\n');
    
  } catch (e) {
    print('❌ Fatal error: $e');
  }
}
