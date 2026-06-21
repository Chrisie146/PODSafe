# Quick Test Account Setup Guide

**Project:** podsafe-92a3e (Development)  
**Status:** Ready to create test accounts  
**Time Required:** 5 minutes

---

## 🎯 Current Situation

You're in **DEVELOPMENT** mode using Firebase project: **`podsafe-92a3e`**

To test the QR code system, you need:
1. ✅ A **company** (admin account)
2. ✅ A **driver** account (approved by admin)
3. ✅ Test **deliveries** to capture PODs

---

## 🚀 Quick Setup (Option 1: Use Firebase Console)

### Step 1: Create Admin Account via Firebase Console

1. **Open Firebase Console:**
   ```
   https://console.firebase.google.com/project/podsafe-92a3e
   ```

2. **Go to Authentication:**
   - Click "Authentication" in left menu
   - Click "Users" tab
   - Click "Add user"

3. **Create Admin User:**
   - Email: `admin@test.com`
   - Password: `Test123!`
   - Click "Add user"
   - Copy the **User UID** (you'll need this)

4. **Go to Firestore Database:**
   - Click "Firestore Database" in left menu
   - Click "Start collection" or find existing `companies` collection

5. **Create Company Document:**
   - Collection: `companies`
   - Document ID: Click "Auto-ID"
   - Fields:
     ```
     name: "Test Company"
     email: "admin@test.com"
     phone: "555-0100"
     address: "123 Test St"
     city: "Test City"
     state: "TS"
     zipCode: "12345"
     createdAt: (timestamp) - Click "Add timestamp"
     adminId: (string) - YOUR ADMIN USER UID
     isActive: (boolean) true
     ```
   - Copy the **Company ID** (document ID)

6. **Create User Document:**
   - Collection: `users`
   - Document ID: YOUR ADMIN USER UID (same as auth UID)
   - Fields:
     ```
     email: "admin@test.com"
     firstName: "Test"
     lastName: "Admin"
     role: "admin"
     companyId: YOUR COMPANY ID
     phone: "555-0100"
     isActive: (boolean) true
     approvalStatus: "approved"
     createdAt: (timestamp)
     ```

### Step 2: Login as Admin

1. Run your app: `flutter run -d chrome --web-port=5000`
2. Login with:
   - Email: `admin@test.com`
   - Password: `Test123!`
3. You should see the **Admin Dashboard**

### Step 3: Create Driver via App

1. In the app, logout (if logged in)
2. On login screen, click **"Register as Driver"**
3. Fill in:
   - Email: `driver@test.com`
   - Password: `Test123!`
   - First Name: `Test`
   - Last Name: `Driver`
   - Phone: `555-0200`
   - Company Code: YOUR COMPANY ID (from step 1)
4. Submit registration
5. You'll see "Pending Approval" screen

### Step 4: Approve Driver (as Admin)

1. Login as admin (`admin@test.com`)
2. Go to **Driver Management**
3. Find "Test Driver" with status "Pending"
4. Click **"Approve"** button
5. Driver is now approved!

### Step 5: Login as Driver

1. Logout from admin account
2. Login with driver credentials:
   - Email: `driver@test.com`
   - Password: `Test123!`
3. You should see the **Driver Dashboard**

---

## 🚀 Quick Setup (Option 2: Firebase CLI Script)

Create a file called `setup-test-accounts.js` in your project root:

```javascript
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./path-to-your-service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function setupTestAccounts() {
  try {
    // 1. Create Admin User
    const adminUser = await auth.createUser({
      email: 'admin@test.com',
      password: 'Test123!',
      displayName: 'Test Admin'
    });
    console.log('✅ Created admin user:', adminUser.uid);

    // 2. Create Company
    const companyRef = await db.collection('companies').add({
      name: 'Test Company',
      email: 'admin@test.com',
      phone: '555-0100',
      address: '123 Test St',
      city: 'Test City',
      state: 'TS',
      zipCode: '12345',
      adminId: adminUser.uid,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Created company:', companyRef.id);

    // 3. Create Admin User Doc
    await db.collection('users').doc(adminUser.uid).set({
      email: 'admin@test.com',
      firstName: 'Test',
      lastName: 'Admin',
      role: 'admin',
      companyId: companyRef.id,
      phone: '555-0100',
      isActive: true,
      approvalStatus: 'approved',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Created admin user document');

    // 4. Create Driver User
    const driverUser = await auth.createUser({
      email: 'driver@test.com',
      password: 'Test123!',
      displayName: 'Test Driver'
    });
    console.log('✅ Created driver user:', driverUser.uid);

    // 5. Create Driver User Doc (already approved)
    await db.collection('users').doc(driverUser.uid).set({
      email: 'driver@test.com',
      firstName: 'Test',
      lastName: 'Driver',
      role: 'driver',
      companyId: companyRef.id,
      phone: '555-0200',
      isActive: true,
      approvalStatus: 'approved',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Created driver user document');

    console.log('\n🎉 Setup complete!');
    console.log('\nLogin credentials:');
    console.log('📧 Admin:  admin@test.com  / Test123!');
    console.log('🚗 Driver: driver@test.com / Test123!');
    console.log(`\n🏢 Company ID: ${companyRef.id}`);

  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit();
}

setupTestAccounts();
```

Then run:
```bash
npm install firebase-admin
node setup-test-accounts.js
```

---

## 🧪 Test Credentials

After setup, you'll have:

### Admin Account
- **Email:** `admin@test.com`
- **Password:** `Test123!`
- **Role:** Admin
- **Can:** Manage drivers, create deliveries, view PODs

### Driver Account
- **Email:** `driver@test.com`
- **Password:** `Test123!`
- **Role:** Driver
- **Can:** View deliveries, capture PODs, generate QR codes

---

## 📋 Next Steps After Login

### As Driver:
1. ✅ View assigned deliveries
2. ✅ Start a delivery
3. ✅ Capture POD (photo + signature)
4. ✅ View QR code
5. ✅ Test QR code scanning

### As Admin:
1. ✅ Create test customer
2. ✅ Create test delivery
3. ✅ Assign to driver
4. ✅ Monitor delivery progress
5. ✅ View POD in POD Viewer

---

## 🔍 Checking Current Users

To see if you already have users, check Firebase Console:

1. Go to: `https://console.firebase.google.com/project/podsafe-92a3e/authentication/users`
2. You'll see all registered users
3. Check their email addresses

---

## ❓ Troubleshooting

### "Can't login as driver"

**Possible causes:**
1. ❌ No driver account exists → **Create one** (see steps above)
2. ❌ Driver not approved → **Approve in admin dashboard**
3. ❌ Wrong email/password → **Double-check credentials**
4. ❌ User document missing → **Create in Firestore**

### "Pending Approval" screen

This means:
- ✅ Driver account created successfully
- ❌ Admin hasn't approved yet
- 🔧 **Solution:** Login as admin and approve driver

### "Invalid credentials"

This means:
- ❌ Email or password is wrong
- ❌ User doesn't exist in Firebase Auth
- 🔧 **Solution:** Create account via Firebase Console or app registration

---

## 🎯 Recommended Approach (Fastest)

**For Testing QR Codes:**

1. **Use Firebase Console** (5 min):
   - Create admin user in Authentication
   - Create company in Firestore
   - Create admin user document in Firestore
   - Login as admin in app

2. **Use App Registration** (2 min):
   - Register driver via app
   - Approve driver in admin dashboard
   - Login as driver

3. **Create Test Delivery** (2 min):
   - As admin: Create customer
   - Create delivery assigned to driver
   - As driver: Capture POD
   - View QR code!

**Total time:** ~9 minutes

---

## 🚀 Quick Test Flow

```
1. Create admin account (Firebase Console) → 3 min
   ↓
2. Login as admin → 1 min
   ↓
3. Register driver (via app) → 2 min
   ↓
4. Approve driver (admin dashboard) → 1 min
   ↓
5. Login as driver → 1 min
   ↓
6. Create delivery (as admin) → 2 min
   ↓
7. Capture POD (as driver) → 3 min
   ↓
8. View QR code! → ✅ SUCCESS
```

---

## 📞 Need Help?

If you're still stuck, let me know:
- What screen are you seeing?
- What error message appears?
- Can you access Firebase Console?

I can help you set up accounts step-by-step!

---

**Status:** Ready to create test accounts  
**Environment:** Development (podsafe-92a3e)  
**Next Action:** Choose setup option (Console or Script)
