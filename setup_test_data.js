/**
 * Quick Test Data Setup Script
 * Creates minimal test data for security rule testing
 */

const admin = require('firebase-admin');

// Check for service account key
const fs = require('fs');
if (!fs.existsSync('./service-account-key.json')) {
  console.error('❌ ERROR: service-account-key.json not found!');
  console.log('\nPlease download your Firebase service account key:');
  console.log('1. Go to Firebase Console → Project Settings → Service Accounts');
  console.log('2. Click "Generate New Private Key"');
  console.log('3. Save as service-account-key.json in this directory');
  console.log('');
  process.exit(1);
}

const serviceAccount = require('./service-account-key.json');

// Initialize
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function quickSetup() {
  console.log('\n🚀 PODSafe Quick Test Data Setup\n');
  console.log('This will create:');
  console.log('  • 2 test companies');
  console.log('  • 3 test users (2 admins, 1 driver)');
  console.log('  • 1 test delivery');
  console.log('  • 1 test claim');
  console.log('');
  
  try {
    // Company 1
    console.log('Creating Company Alpha...');
    const company1Ref = db.collection('companies').doc();
    const company1Id = company1Ref.id;
    
    await company1Ref.set({
      companyId: company1Id,
      name: 'Test Company Alpha',
      email: 'alpha@test.com',
      phoneNumber: '+27111111111',
      address: '123 Test Street, Johannesburg',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Company Alpha created: ${company1Id}`);
    
    // Admin 1
    console.log('Creating Admin for Company Alpha...');
    const admin1 = await auth.createUser({
      email: 'admin.alpha@test.com',
      password: 'TestPass123!',
      displayName: 'Alpha Admin'
    });
    
    await db.collection('users').doc(admin1.uid).set({
      email: 'admin.alpha@test.com',
      fullName: 'Alpha Admin',
      role: 'admin',
      companyId: company1Id,
      phoneNumber: '+27111111111',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Admin created: admin.alpha@test.com`);
    
    // Driver 1
    console.log('Creating Driver for Company Alpha...');
    const driver1 = await auth.createUser({
      email: 'driver.alpha@test.com',
      password: 'TestPass123!',
      displayName: 'Alpha Driver'
    });
    
    await db.collection('users').doc(driver1.uid).set({
      email: 'driver.alpha@test.com',
      fullName: 'Alpha Driver',
      role: 'driver',
      companyId: company1Id,
      phoneNumber: '+27111111112',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Driver created: driver.alpha@test.com`);
    
    // Company 2
    console.log('Creating Company Beta...');
    const company2Ref = db.collection('companies').doc();
    const company2Id = company2Ref.id;
    
    await company2Ref.set({
      companyId: company2Id,
      name: 'Test Company Beta',
      email: 'beta@test.com',
      phoneNumber: '+27222222222',
      address: '456 Test Avenue, Cape Town',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Company Beta created: ${company2Id}`);
    
    // Admin 2
    console.log('Creating Admin for Company Beta...');
    const admin2 = await auth.createUser({
      email: 'admin.beta@test.com',
      password: 'TestPass123!',
      displayName: 'Beta Admin'
    });
    
    await db.collection('users').doc(admin2.uid).set({
      email: 'admin.beta@test.com',
      fullName: 'Beta Admin',
      role: 'admin',
      companyId: company2Id,
      phoneNumber: '+27222222222',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Admin created: admin.beta@test.com`);
    
    // Test Delivery
    console.log('Creating test delivery...');
    const deliveryRef = await db.collection('deliveries').add({
      companyId: company1Id,
      driverId: driver1.uid,
      driverName: 'Alpha Driver',
      customerName: 'Test Customer',
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Delivery created: ${deliveryRef.id}`);
    
    // Test Claim
    console.log('Creating test claim...');
    const claimRef = await db.collection('companies').doc(company1Id)
      .collection('claims').add({
        companyId: company1Id,
        claimNumber: 'TEST-001',
        driverId: driver1.uid,
        driverName: 'Alpha Driver',
        status: 'open',
        description: 'Test claim for security testing',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    console.log(`✅ Claim created: ${claimRef.id}`);
    
    // Summary
    console.log('\n✅ TEST DATA SETUP COMPLETE!\n');
    console.log('='.repeat(60));
    console.log('CREDENTIALS FOR TESTING:\n');
    console.log('Company Alpha Admin:');
    console.log('  Email: admin.alpha@test.com');
    console.log('  Password: TestPass123!');
    console.log(`  CompanyId: ${company1Id}\n`);
    
    console.log('Company Alpha Driver:');
    console.log('  Email: driver.alpha@test.com');
    console.log('  Password: TestPass123!');
    console.log(`  CompanyId: ${company1Id}\n`);
    
    console.log('Company Beta Admin:');
    console.log('  Email: admin.beta@test.com');
    console.log('  Password: TestPass123!');
    console.log(`  CompanyId: ${company2Id}\n`);
    
    console.log('='.repeat(60));
    console.log('\nNEXT STEPS:');
    console.log('1. Run: node test_security_rules.js');
    console.log('2. Follow: SECURITY_MANUAL_TEST_GUIDE.md');
    console.log('3. Test in Firebase Console with above credentials');
    console.log('');
    
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      console.log('\n⚠️  Test users already exist!');
      console.log('Run cleanup first or use existing credentials.\n');
    } else {
      console.error('❌ Error:', error.message);
    }
    process.exit(1);
  }
}

quickSetup().then(() => process.exit(0));
