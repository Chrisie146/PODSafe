/**
 * PODSafe Security Rules Test Suite
 * 
 * Tests multi-tenant isolation, role-based access, and security rules
 * Run: node test_security_rules.js
 * 
 * Prerequisites:
 * - Firebase Admin SDK initialized
 * - Test users created in Firestore
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const auth = admin.auth();

// Test configuration
const TEST_CONFIG = {
  company1: {
    name: 'Test Company Alpha',
    email: 'alpha@test.com',
    adminEmail: 'admin.alpha@test.com',
    adminName: 'Alpha Admin',
    driverEmail: 'driver.alpha@test.com',
    driverName: 'Alpha Driver'
  },
  company2: {
    name: 'Test Company Beta',
    email: 'beta@test.com',
    adminEmail: 'admin.beta@test.com',
    adminName: 'Beta Admin'
  }
};

const results = {
  passed: 0,
  failed: 0,
  tests: []
};

// Helper functions
function logTest(testName, passed, details = '') {
  const status = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`${status}: ${testName}`);
  if (details) console.log(`   ${details}`);
  
  results.tests.push({ testName, passed, details });
  if (passed) results.passed++;
  else results.failed++;
}

async function cleanupTestData() {
  console.log('\n🧹 Cleaning up test data...\n');
  
  try {
    // Delete test users
    const users = await auth.listUsers();
    for (const user of users.users) {
      if (user.email && user.email.includes('@test.com')) {
        await auth.deleteUser(user.uid);
        console.log(`Deleted user: ${user.email}`);
      }
    }
    
    // Delete test companies
    const companies = await db.collection('companies').get();
    for (const doc of companies.docs) {
      if (doc.data().email && doc.data().email.includes('@test.com')) {
        await doc.ref.delete();
        console.log(`Deleted company: ${doc.data().name}`);
      }
    }
    
    console.log('✅ Cleanup complete\n');
  } catch (error) {
    console.log(`⚠️  Cleanup error: ${error.message}\n`);
  }
}

async function createTestData() {
  console.log('📝 Creating test data...\n');
  
  const testData = {
    companies: {},
    users: {}
  };
  
  try {
    // Create Company 1
    const company1Ref = db.collection('companies').doc();
    const company1Id = company1Ref.id;
    
    await company1Ref.set({
      companyId: company1Id,
      name: TEST_CONFIG.company1.name,
      email: TEST_CONFIG.company1.email,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    testData.companies.company1 = {
      id: company1Id,
      ref: company1Ref
    };
    
    console.log(`✅ Created Company 1: ${TEST_CONFIG.company1.name} (${company1Id})`);
    
    // Create Company 1 Admin
    const admin1 = await auth.createUser({
      email: TEST_CONFIG.company1.adminEmail,
      password: 'TestPass123!',
      displayName: TEST_CONFIG.company1.adminName
    });
    
    await db.collection('users').doc(admin1.uid).set({
      email: TEST_CONFIG.company1.adminEmail,
      fullName: TEST_CONFIG.company1.adminName,
      role: 'admin',
      companyId: company1Id,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    testData.users.admin1 = {
      uid: admin1.uid,
      email: TEST_CONFIG.company1.adminEmail,
      companyId: company1Id,
      role: 'admin'
    };
    
    console.log(`✅ Created Admin 1: ${TEST_CONFIG.company1.adminEmail}`);
    
    // Create Company 1 Driver
    const driver1 = await auth.createUser({
      email: TEST_CONFIG.company1.driverEmail,
      password: 'TestPass123!',
      displayName: TEST_CONFIG.company1.driverName
    });
    
    await db.collection('users').doc(driver1.uid).set({
      email: TEST_CONFIG.company1.driverEmail,
      fullName: TEST_CONFIG.company1.driverName,
      role: 'driver',
      companyId: company1Id,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    testData.users.driver1 = {
      uid: driver1.uid,
      email: TEST_CONFIG.company1.driverEmail,
      companyId: company1Id,
      role: 'driver'
    };
    
    console.log(`✅ Created Driver 1: ${TEST_CONFIG.company1.driverEmail}`);
    
    // Create Company 2
    const company2Ref = db.collection('companies').doc();
    const company2Id = company2Ref.id;
    
    await company2Ref.set({
      companyId: company2Id,
      name: TEST_CONFIG.company2.name,
      email: TEST_CONFIG.company2.email,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    testData.companies.company2 = {
      id: company2Id,
      ref: company2Ref
    };
    
    console.log(`✅ Created Company 2: ${TEST_CONFIG.company2.name} (${company2Id})`);
    
    // Create Company 2 Admin
    const admin2 = await auth.createUser({
      email: TEST_CONFIG.company2.adminEmail,
      password: 'TestPass123!',
      displayName: TEST_CONFIG.company2.adminName
    });
    
    await db.collection('users').doc(admin2.uid).set({
      email: TEST_CONFIG.company2.adminEmail,
      fullName: TEST_CONFIG.company2.adminName,
      role: 'admin',
      companyId: company2Id,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    testData.users.admin2 = {
      uid: admin2.uid,
      email: TEST_CONFIG.company2.adminEmail,
      companyId: company2Id,
      role: 'admin'
    };
    
    console.log(`✅ Created Admin 2: ${TEST_CONFIG.company2.adminEmail}`);
    
    // Create test delivery for Company 1
    const delivery1Ref = await db.collection('deliveries').add({
      companyId: company1Id,
      driverId: driver1.uid,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    testData.delivery1 = {
      id: delivery1Ref.id,
      companyId: company1Id,
      driverId: driver1.uid
    };
    
    console.log(`✅ Created Delivery 1 for Company 1`);
    
    // Create test claim for Company 1
    const claim1Ref = await db.collection('companies').doc(company1Id)
      .collection('claims').add({
        companyId: company1Id,
        claimNumber: 'TEST-001',
        driverId: driver1.uid,
        status: 'open',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    testData.claim1 = {
      id: claim1Ref.id,
      companyId: company1Id
    };
    
    console.log(`✅ Created Claim 1 for Company 1`);
    
    console.log('\n✅ Test data creation complete\n');
    return testData;
    
  } catch (error) {
    console.error(`❌ Error creating test data: ${error.message}`);
    throw error;
  }
}

async function runSecurityTests(testData) {
  console.log('🔒 Running Security Tests...\n');
  console.log('='.repeat(60));
  console.log('\n');
  
  // Test 1: Multi-Tenant Isolation - Company Access
  console.log('📋 TEST SUITE: Multi-Tenant Isolation\n');
  
  try {
    const company1Doc = await db.collection('companies').doc(testData.companies.company1.id).get();
    logTest(
      'Company 1 exists and readable (Admin SDK)',
      company1Doc.exists,
      `Company: ${company1Doc.data()?.name}`
    );
  } catch (error) {
    logTest('Company 1 exists and readable', false, error.message);
  }
  
  // Test 2: User cannot change their role
  console.log('\n📋 TEST SUITE: Role Protection\n');
  
  try {
    // Attempt to change driver role to admin (should be blocked by rules)
    const userDoc = db.collection('users').doc(testData.users.driver1.uid);
    const userData = (await userDoc.get()).data();
    
    logTest(
      'Driver user has correct role',
      userData.role === 'driver',
      `Current role: ${userData.role}`
    );
    
    // Note: This test requires client SDK with user auth to properly test
    // With Admin SDK, we bypass security rules
    console.log('   ⚠️  Note: Role mutation tests require client SDK with user authentication');
    
  } catch (error) {
    logTest('Driver role verification', false, error.message);
  }
  
  // Test 3: Company Isolation - Claims
  console.log('\n📋 TEST SUITE: Claim Isolation\n');
  
  try {
    const claim = await db.collection('companies')
      .doc(testData.companies.company1.id)
      .collection('claims')
      .doc(testData.claim1.id)
      .get();
    
    logTest(
      'Claim exists in correct company',
      claim.exists && claim.data().companyId === testData.companies.company1.id,
      `Claim companyId: ${claim.data()?.companyId}`
    );
  } catch (error) {
    logTest('Claim isolation test', false, error.message);
  }
  
  // Test 4: Delivery Ownership
  console.log('\n📋 TEST SUITE: Delivery Ownership\n');
  
  try {
    const delivery = await db.collection('deliveries').doc(testData.delivery1.id).get();
    
    logTest(
      'Delivery has correct companyId',
      delivery.data().companyId === testData.companies.company1.id,
      `Delivery companyId: ${delivery.data()?.companyId}`
    );
    
    logTest(
      'Delivery has correct driverId',
      delivery.data().driverId === testData.users.driver1.uid,
      `Driver: ${testData.users.driver1.email}`
    );
  } catch (error) {
    logTest('Delivery ownership test', false, error.message);
  }
  
  // Test 5: Active User Field
  console.log('\n📋 TEST SUITE: User Active Status\n');
  
  try {
    const admin1 = await db.collection('users').doc(testData.users.admin1.uid).get();
    logTest(
      'Admin 1 is active',
      admin1.data().isActive === true,
      `isActive: ${admin1.data()?.isActive}`
    );
    
    const driver1 = await db.collection('users').doc(testData.users.driver1.uid).get();
    logTest(
      'Driver 1 is active',
      driver1.data().isActive === true,
      `isActive: ${driver1.data()?.isActive}`
    );
  } catch (error) {
    logTest('Active user status', false, error.message);
  }
  
  // Test 6: User Deactivation
  console.log('\n📋 TEST SUITE: User Deactivation\n');
  
  try {
    // Deactivate driver
    await db.collection('users').doc(testData.users.driver1.uid).update({
      isActive: false
    });
    
    const deactivatedUser = await db.collection('users').doc(testData.users.driver1.uid).get();
    logTest(
      'User can be deactivated',
      deactivatedUser.data().isActive === false,
      'User successfully deactivated'
    );
    
    // Reactivate for cleanup
    await db.collection('users').doc(testData.users.driver1.uid).update({
      isActive: true
    });
    
  } catch (error) {
    logTest('User deactivation', false, error.message);
  }
  
  // Test 7: Company Data Structure
  console.log('\n📋 TEST SUITE: Data Structure Validation\n');
  
  try {
    const company = await db.collection('companies').doc(testData.companies.company1.id).get();
    const data = company.data();
    
    logTest(
      'Company has required fields',
      data.hasOwnProperty('companyId') && 
      data.hasOwnProperty('name') && 
      data.hasOwnProperty('email') &&
      data.hasOwnProperty('isActive'),
      'All required fields present'
    );
    
    logTest(
      'Company companyId matches document ID',
      data.companyId === testData.companies.company1.id,
      `Match: ${data.companyId === testData.companies.company1.id}`
    );
  } catch (error) {
    logTest('Company structure validation', false, error.message);
  }
  
  // Test 8: User Data Structure
  console.log('\n📋 TEST SUITE: User Data Validation\n');
  
  try {
    const user = await db.collection('users').doc(testData.users.admin1.uid).get();
    const data = user.data();
    
    const requiredFields = ['email', 'fullName', 'role', 'companyId', 'isActive'];
    const hasAllFields = requiredFields.every(field => data.hasOwnProperty(field));
    
    logTest(
      'User has required fields',
      hasAllFields,
      `Fields: ${requiredFields.join(', ')}`
    );
    
    logTest(
      'User role is valid',
      ['admin', 'driver'].includes(data.role),
      `Role: ${data.role}`
    );
  } catch (error) {
    logTest('User structure validation', false, error.message);
  }
  
  console.log('\n' + '='.repeat(60));
}

function printTestSummary() {
  console.log('\n\n📊 TEST SUMMARY\n');
  console.log('='.repeat(60));
  console.log(`Total Tests: ${results.passed + results.failed}`);
  console.log(`✅ Passed: ${results.passed}`);
  console.log(`❌ Failed: ${results.failed}`);
  console.log(`Success Rate: ${((results.passed / (results.passed + results.failed)) * 100).toFixed(1)}%`);
  console.log('='.repeat(60));
  
  if (results.failed > 0) {
    console.log('\n❌ Failed Tests:\n');
    results.tests.filter(t => !t.passed).forEach(test => {
      console.log(`  • ${test.testName}`);
      if (test.details) console.log(`    ${test.details}`);
    });
  }
  
  console.log('\n');
}

async function runClientSDKWarning() {
  console.log('\n⚠️  IMPORTANT NOTES:\n');
  console.log('These tests use Firebase Admin SDK which BYPASSES security rules.');
  console.log('For comprehensive security testing, you need to:');
  console.log('');
  console.log('1. Use Firebase Client SDK with actual user authentication');
  console.log('2. Test from the Flutter app or web console');
  console.log('3. Attempt unauthorized operations and verify they are blocked');
  console.log('');
  console.log('Example tests to run manually:');
  console.log('  • Driver trying to read another company\'s data');
  console.log('  • User trying to change their own role');
  console.log('  • User trying to change their companyId');
  console.log('  • Inactive user trying to access any data');
  console.log('  • Driver trying to create/delete companies');
  console.log('');
  console.log('See: SECURITY_MANUAL_TEST_GUIDE.md for detailed manual test scenarios');
  console.log('');
}

// Main execution
async function main() {
  console.log('\n');
  console.log('🔐 PODSafe Security Rules Test Suite');
  console.log('='.repeat(60));
  console.log('\n');
  
  try {
    // Clean up any existing test data
    await cleanupTestData();
    
    // Create fresh test data
    const testData = await createTestData();
    
    // Run security tests
    await runSecurityTests(testData);
    
    // Print summary
    printTestSummary();
    
    // Show client SDK warning
    await runClientSDKWarning();
    
    // Cleanup option
    console.log('Do you want to clean up test data? (yes/no)');
    console.log('Leaving test data allows manual testing in Firebase Console\n');
    
    // For automated runs, set to auto-cleanup
    const autoCleanup = false; // Set to true for CI/CD
    
    if (autoCleanup) {
      await cleanupTestData();
    } else {
      console.log('⚠️  Test data NOT cleaned up. Clean up manually or run with autoCleanup=true\n');
    }
    
    process.exit(results.failed > 0 ? 1 : 0);
    
  } catch (error) {
    console.error('\n❌ Test suite failed:', error);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

module.exports = { createTestData, runSecurityTests, cleanupTestData };
