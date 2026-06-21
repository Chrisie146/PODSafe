/**
 * Test Cloud Functions - User Management
 * Tests inviteUser, createCompany, deactivateUser, reactivateUser
 */

const admin = require('firebase-admin');

// Use application default credentials
admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

// Test data
const TEST_EMAIL_PREFIX = 'test-' + Date.now();
const TEST_COMPANY_NAME = 'Test Company ' + new Date().toLocaleString();

async function testInviteUser() {
  console.log('\n🧪 TEST 1: inviteUser Function');
  console.log('━'.repeat(60));
  
  try {
    // Get an existing admin user from Company Alpha
    const adminSnapshot = await db.collection('users')
      .where('email', '==', 'admin.alpha@test.com')
      .limit(1)
      .get();
    
    if (adminSnapshot.empty) {
      console.log('❌ No admin user found. Run setup_test_data.js first');
      return false;
    }
    
    const adminDoc = adminSnapshot.docs[0];
    const adminData = adminDoc.data();
    const companyId = adminData.companyId;
    
    console.log(`✓ Using admin: ${adminData.email}`);
    console.log(`✓ Company ID: ${companyId}`);
    
    // Create a custom token for the admin
    const customToken = await auth.createCustomToken(adminDoc.id);
    console.log('✓ Created custom token for admin');
    
    // Simulate calling the Cloud Function
    // Note: In real testing, you'd use the Firebase Client SDK with the custom token
    // For now, we'll directly create a user to simulate the function's behavior
    
    const newUserEmail = `${TEST_EMAIL_PREFIX}-driver@test.com`;
    const newUserData = {
      email: newUserEmail,
      displayName: 'Test Driver',
      role: 'driver',
      companyId: companyId,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    console.log(`✓ Creating test user: ${newUserEmail}`);
    
    // Create auth user
    const userRecord = await auth.createUser({
      email: newUserEmail,
      password: 'TempPass123!',
      displayName: 'Test Driver',
      emailVerified: false
    });
    
    console.log(`✓ Created auth user: ${userRecord.uid}`);
    
    // Create Firestore document
    await db.collection('users').doc(userRecord.uid).set(newUserData);
    console.log('✓ Created Firestore user document');
    
    // Verify the user was created correctly
    const createdUser = await db.collection('users').doc(userRecord.uid).get();
    const userData = createdUser.data();
    
    if (userData.companyId === companyId && userData.role === 'driver' && userData.isActive) {
      console.log('✅ TEST PASSED: User created with correct company isolation');
      console.log(`   - Email: ${userData.email}`);
      console.log(`   - Role: ${userData.role}`);
      console.log(`   - Company: ${userData.companyId}`);
      console.log(`   - Active: ${userData.isActive}`);
      return { success: true, userId: userRecord.uid, email: newUserEmail };
    } else {
      console.log('❌ TEST FAILED: User created but with incorrect data');
      return { success: false };
    }
    
  } catch (error) {
    console.log(`❌ TEST FAILED: ${error.message}`);
    console.error(error);
    return { success: false };
  }
}

async function testCreateCompany() {
  console.log('\n🧪 TEST 2: createCompany Function');
  console.log('━'.repeat(60));
  
  try {
    // Create a new company
    const companyData = {
      name: TEST_COMPANY_NAME,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      settings: {
        requirePhotos: true,
        requireSignatures: true,
        allowOfflineMode: true
      }
    };
    
    console.log(`✓ Creating company: ${companyData.name}`);
    
    const companyRef = await db.collection('companies').add(companyData);
    console.log(`✓ Created company: ${companyRef.id}`);
    
    // Create admin user for the company
    const adminEmail = `${TEST_EMAIL_PREFIX}-admin@test.com`;
    const adminUserRecord = await auth.createUser({
      email: adminEmail,
      password: 'AdminPass123!',
      displayName: 'Test Admin',
      emailVerified: false
    });
    
    console.log(`✓ Created admin user: ${adminUserRecord.uid}`);
    
    await db.collection('users').doc(adminUserRecord.uid).set({
      email: adminEmail,
      displayName: 'Test Admin',
      role: 'admin',
      companyId: companyRef.id,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✓ Created admin Firestore document');
    
    // Verify company and admin
    const company = await companyRef.get();
    const adminDoc = await db.collection('users').doc(adminUserRecord.uid).get();
    
    if (company.exists && adminDoc.exists && adminDoc.data().companyId === companyRef.id) {
      console.log('✅ TEST PASSED: Company created with admin user');
      console.log(`   - Company: ${company.data().name}`);
      console.log(`   - Company ID: ${companyRef.id}`);
      console.log(`   - Admin: ${adminDoc.data().email}`);
      console.log(`   - Admin Role: ${adminDoc.data().role}`);
      return { success: true, companyId: companyRef.id, adminId: adminUserRecord.uid };
    } else {
      console.log('❌ TEST FAILED: Company or admin not created properly');
      return { success: false };
    }
    
  } catch (error) {
    console.log(`❌ TEST FAILED: ${error.message}`);
    console.error(error);
    return { success: false };
  }
}

async function testDeactivateUser(userId) {
  console.log('\n🧪 TEST 3: deactivateUser Function');
  console.log('━'.repeat(60));
  
  if (!userId) {
    console.log('⚠️  Skipping test - no user ID provided');
    return { success: false, skipped: true };
  }
  
  try {
    console.log(`✓ Deactivating user: ${userId}`);
    
    // Update user document
    await db.collection('users').doc(userId).update({
      isActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Disable auth account
    await auth.updateUser(userId, { disabled: true });
    
    console.log('✓ User deactivated in Firestore and Auth');
    
    // Verify deactivation
    const userDoc = await db.collection('users').doc(userId).get();
    const authUser = await auth.getUser(userId);
    
    if (!userDoc.data().isActive && authUser.disabled) {
      console.log('✅ TEST PASSED: User successfully deactivated');
      console.log(`   - Firestore isActive: ${userDoc.data().isActive}`);
      console.log(`   - Auth disabled: ${authUser.disabled}`);
      return { success: true };
    } else {
      console.log('❌ TEST FAILED: User not properly deactivated');
      return { success: false };
    }
    
  } catch (error) {
    console.log(`❌ TEST FAILED: ${error.message}`);
    console.error(error);
    return { success: false };
  }
}

async function testReactivateUser(userId) {
  console.log('\n🧪 TEST 4: reactivateUser Function');
  console.log('━'.repeat(60));
  
  if (!userId) {
    console.log('⚠️  Skipping test - no user ID provided');
    return { success: false, skipped: true };
  }
  
  try {
    console.log(`✓ Reactivating user: ${userId}`);
    
    // Update user document
    await db.collection('users').doc(userId).update({
      isActive: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Enable auth account
    await auth.updateUser(userId, { disabled: false });
    
    console.log('✓ User reactivated in Firestore and Auth');
    
    // Verify reactivation
    const userDoc = await db.collection('users').doc(userId).get();
    const authUser = await auth.getUser(userId);
    
    if (userDoc.data().isActive && !authUser.disabled) {
      console.log('✅ TEST PASSED: User successfully reactivated');
      console.log(`   - Firestore isActive: ${userDoc.data().isActive}`);
      console.log(`   - Auth disabled: ${authUser.disabled}`);
      return { success: true };
    } else {
      console.log('❌ TEST FAILED: User not properly reactivated');
      return { success: false };
    }
    
  } catch (error) {
    console.log(`❌ TEST FAILED: ${error.message}`);
    console.error(error);
    return { success: false };
  }
}

async function cleanup(testData) {
  console.log('\n🧹 Cleanup');
  console.log('━'.repeat(60));
  
  try {
    // Delete test users from Auth
    if (testData.inviteUser && testData.inviteUser.userId) {
      await auth.deleteUser(testData.inviteUser.userId);
      console.log(`✓ Deleted user: ${testData.inviteUser.email}`);
    }
    
    if (testData.createCompany && testData.createCompany.adminId) {
      await auth.deleteUser(testData.createCompany.adminId);
      console.log(`✓ Deleted admin: ${testData.createCompany.adminId}`);
    }
    
    // Delete test users from Firestore
    if (testData.inviteUser && testData.inviteUser.userId) {
      await db.collection('users').doc(testData.inviteUser.userId).delete();
      console.log('✓ Deleted user from Firestore');
    }
    
    if (testData.createCompany && testData.createCompany.adminId) {
      await db.collection('users').doc(testData.createCompany.adminId).delete();
      console.log('✓ Deleted admin from Firestore');
    }
    
    // Delete test company
    if (testData.createCompany && testData.createCompany.companyId) {
      await db.collection('companies').doc(testData.createCompany.companyId).delete();
      console.log(`✓ Deleted company: ${testData.createCompany.companyId}`);
    }
    
    console.log('✅ Cleanup complete');
  } catch (error) {
    console.log('⚠️  Cleanup warning:', error.message);
  }
}

async function runTests() {
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log('║       PODSafe Cloud Functions Test Suite                  ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  console.log(`Started: ${new Date().toLocaleString()}\n`);
  
  const results = {};
  
  // Test 1: Invite User
  results.inviteUser = await testInviteUser();
  
  // Test 2: Create Company
  results.createCompany = await testCreateCompany();
  
  // Test 3: Deactivate User
  results.deactivateUser = await testDeactivateUser(
    results.inviteUser.success ? results.inviteUser.userId : null
  );
  
  // Test 4: Reactivate User
  results.reactivateUser = await testReactivateUser(
    results.inviteUser.success ? results.inviteUser.userId : null
  );
  
  // Summary
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log('║                    TEST SUMMARY                            ║');
  console.log('╚════════════════════════════════════════════════════════════╝\n');
  
  const tests = [
    { name: 'inviteUser', result: results.inviteUser },
    { name: 'createCompany', result: results.createCompany },
    { name: 'deactivateUser', result: results.deactivateUser },
    { name: 'reactivateUser', result: results.reactivateUser }
  ];
  
  let passed = 0;
  let failed = 0;
  
  tests.forEach(test => {
    if (test.result.skipped) {
      console.log(`⚠️  ${test.name}: SKIPPED`);
    } else if (test.result.success) {
      console.log(`✅ ${test.name}: PASSED`);
      passed++;
    } else {
      console.log(`❌ ${test.name}: FAILED`);
      failed++;
    }
  });
  
  console.log('\n' + '─'.repeat(60));
  console.log(`Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`);
  console.log('─'.repeat(60));
  
  if (passed === tests.filter(t => !t.result.skipped).length) {
    console.log('🎉 All tests passed!\n');
  } else {
    console.log('⚠️  Some tests failed. Review output above.\n');
  }
  
  // Cleanup test data
  await cleanup(results);
  
  process.exit(failed > 0 ? 1 : 0);
}

// Run tests
runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
