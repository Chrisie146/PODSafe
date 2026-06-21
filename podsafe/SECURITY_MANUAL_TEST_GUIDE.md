# 🧪 PODSafe Security Rules - Manual Testing Guide

**Purpose:** Verify security rules work correctly with real user authentication  
**Estimated Time:** 30-45 minutes  
**Prerequisites:** Secure rules deployed, test companies/users created

---

## 🎯 TESTING STRATEGY

Security rules can only be fully tested with **client SDK** (not Admin SDK) because:
- Admin SDK bypasses all security rules
- Client SDK enforces rules based on authenticated user context
- Real-world scenarios require user authentication tokens

---

## 📋 PRE-TEST SETUP

### **1. Create Test Data**

Run the automated script first:
```bash
node test_security_rules.js
```

This creates:
- ✅ Company Alpha (with Admin + Driver)
- ✅ Company Beta (with Admin)
- ✅ Test delivery for Company Alpha
- ✅ Test claim for Company Alpha

### **2. Note Down Test Credentials**

```
Company Alpha Admin:
  Email: admin.alpha@test.com
  Password: TestPass123!
  CompanyId: [from console]

Company Alpha Driver:
  Email: driver.alpha@test.com
  Password: TestPass123!
  CompanyId: [same as above]

Company Beta Admin:
  Email: admin.beta@test.com
  Password: TestPass123!
  CompanyId: [from console]
```

---

## 🧪 TEST SCENARIOS

### **TEST 1: Multi-Tenant Isolation (CRITICAL)**

**Goal:** Verify users cannot access other companies' data

#### **1.1 Company Data Access**

**Steps:**
1. Login as `admin.alpha@test.com`
2. Try to read Company Beta's document
3. Should be **DENIED**

**Firebase Console Test:**
```javascript
// In browser console with user authenticated
const db = firebase.firestore();

// Get own company (should work)
db.collection('companies').doc('[alpha-company-id]').get()
  .then(doc => console.log('✅ Own company:', doc.data()))
  .catch(err => console.log('❌ Error:', err));

// Try to get other company (should fail)
db.collection('companies').doc('[beta-company-id]').get()
  .then(doc => console.log('❌ SECURITY BREACH:', doc.data()))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied for Company Beta

---

#### **1.2 Claims Isolation**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to list claims from Company Beta
3. Should return empty or be denied

**Test:**
```javascript
// Should work - own company claims
db.collection('companies').doc('[alpha-company-id]')
  .collection('claims').get()
  .then(snap => console.log('✅ Own claims:', snap.size))
  .catch(err => console.log('❌ Error:', err));

// Should fail - other company claims
db.collection('companies').doc('[beta-company-id]')
  .collection('claims').get()
  .then(snap => console.log('❌ SECURITY BREACH:', snap.size))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ✅ Own company accessible, ❌ Other company blocked

---

#### **1.3 Delivery Isolation**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to query all deliveries
3. Should only see own company's deliveries

**Test:**
```javascript
// List all deliveries (should be filtered by security rules)
db.collection('deliveries').get()
  .then(snap => {
    snap.forEach(doc => {
      const data = doc.data();
      console.log(`Delivery ${doc.id}: companyId=${data.companyId}`);
      // All should match driver's companyId
    });
  });
```

**Expected Result:** Only sees deliveries from Company Alpha

---

### **TEST 2: Role-Based Access Control (CRITICAL)**

**Goal:** Verify drivers cannot perform admin actions

#### **2.1 User Management**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to create a new user
3. Should be **DENIED**

**Test:**
```javascript
// Try to create user (driver should not be able to)
db.collection('users').add({
  email: 'hacker@test.com',
  fullName: 'Hacker User',
  role: 'admin', // trying to create admin
  companyId: '[alpha-company-id]',
  isActive: true,
  createdAt: firebase.firestore.FieldValue.serverTimestamp()
})
  .then(() => console.log('❌ SECURITY BREACH: Driver created user!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied

---

#### **2.2 Company Settings**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to update company settings
3. Should be **DENIED**

**Test:**
```javascript
// Try to update company (driver should not be able to)
db.collection('companies').doc('[alpha-company-id]')
  .update({
    name: 'HACKED COMPANY'
  })
  .then(() => console.log('❌ SECURITY BREACH: Driver updated company!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied

---

#### **2.3 Admin-Only Collections**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to access integrations or settings
3. Should be **DENIED**

**Test:**
```javascript
// Try to read integrations (admin-only)
db.collection('companies').doc('[alpha-company-id]')
  .collection('integrations').get()
  .then(snap => console.log('❌ SECURITY BREACH: Driver read integrations!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied

---

### **TEST 3: User Self-Modification (CRITICAL)**

**Goal:** Verify users cannot escalate privileges

#### **3.1 Role Escalation Prevention**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to change own role to 'admin'
3. Should be **DENIED**

**Test:**
```javascript
// Get own user ID
const currentUser = firebase.auth().currentUser;

// Try to change role (should fail)
db.collection('users').doc(currentUser.uid)
  .update({
    role: 'admin'
  })
  .then(() => console.log('❌ SECURITY BREACH: User changed own role!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied (role in notChanging list)

---

#### **3.2 Company Switching Prevention**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to change own companyId to Company Beta
3. Should be **DENIED**

**Test:**
```javascript
const currentUser = firebase.auth().currentUser;

// Try to switch companies (should fail)
db.collection('users').doc(currentUser.uid)
  .update({
    companyId: '[beta-company-id]'
  })
  .then(() => console.log('❌ SECURITY BREACH: User switched companies!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied (companyId in notChanging list)

---

#### **3.3 Allowed Self-Updates**

**Steps:**
1. Login as `driver.alpha@test.com`
2. Try to update own fullName or phoneNumber
3. Should **SUCCEED**

**Test:**
```javascript
const currentUser = firebase.auth().currentUser;

// Try to update allowed fields (should work)
db.collection('users').doc(currentUser.uid)
  .update({
    fullName: 'Updated Driver Name',
    phoneNumber: '+27999999999'
  })
  .then(() => console.log('✅ User updated allowed fields'))
  .catch(err => console.log('❌ Unexpected error:', err.message));
```

**Expected Result:** ✅ Success

---

### **TEST 4: Active User Enforcement (CRITICAL)**

**Goal:** Verify deactivated users lose all access

#### **4.1 Deactivate and Test**

**Steps:**
1. As admin, deactivate `driver.alpha@test.com`
2. Login as that driver
3. Try to access any data
4. Should be **DENIED**

**Setup (via Admin SDK or Cloud Function):**
```javascript
// Deactivate user (admin action)
db.collection('users').doc('[driver-uid]').update({
  isActive: false
});
```

**Test (as deactivated user):**
```javascript
// Try to read own company (should fail - not active)
db.collection('companies').doc('[alpha-company-id]').get()
  .then(doc => console.log('❌ SECURITY BREACH: Inactive user accessed data!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied (isActiveUser() check fails)

---

### **TEST 5: Company Creation Prevention (CRITICAL)**

**Goal:** Verify users cannot create companies

#### **5.1 Direct Company Creation**

**Steps:**
1. Login as any user
2. Try to create a company document
3. Should be **DENIED**

**Test:**
```javascript
// Try to create company (should fail for all users)
db.collection('companies').add({
  name: 'Hacker Company',
  email: 'hacker@evil.com',
  companyId: 'evil-id',
  isActive: true,
  createdAt: firebase.firestore.FieldValue.serverTimestamp()
})
  .then(() => console.log('❌ SECURITY BREACH: User created company!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Permission denied (allow create: if false)

---

### **TEST 6: Input Validation (MEDIUM PRIORITY)**

**Goal:** Verify invalid data is rejected

#### **6.1 Invalid Role**

**Test:**
```javascript
// Try to create user with invalid role (via admin)
db.collection('users').add({
  email: 'test@test.com',
  fullName: 'Test User',
  role: 'superuser', // invalid role
  companyId: '[alpha-company-id]',
  isActive: true,
  createdAt: firebase.firestore.FieldValue.serverTimestamp()
})
  .then(() => console.log('❌ SECURITY BREACH: Invalid role accepted!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Validation error

---

#### **6.2 Invalid Email Format**

**Test:**
```javascript
// Try to create user with invalid email
db.collection('users').add({
  email: 'not-an-email',
  fullName: 'Test User',
  role: 'driver',
  companyId: '[alpha-company-id]',
  isActive: true,
  createdAt: firebase.firestore.FieldValue.serverTimestamp()
})
  .then(() => console.log('❌ SECURITY BREACH: Invalid email accepted!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ❌ Validation error

---

### **TEST 7: Storage Rules (HIGH PRIORITY)**

**Goal:** Verify file upload security

#### **7.1 Company Asset Isolation**

**Test:**
```javascript
const storage = firebase.storage();

// Try to upload to own company (should work for admin)
storage.ref(`companies/[alpha-company-id]/assets/test.jpg`)
  .put(file)
  .then(() => console.log('✅ Upload to own company succeeded'))
  .catch(err => console.log('❌ Error:', err));

// Try to upload to other company (should fail)
storage.ref(`companies/[beta-company-id]/assets/test.jpg`)
  .put(file)
  .then(() => console.log('❌ SECURITY BREACH: Uploaded to other company!'))
  .catch(err => console.log('✅ Correctly blocked:', err.message));
```

**Expected Result:** ✅ Own company works, ❌ Other company blocked

---

## ✅ TEST RESULTS CHECKLIST

Use this checklist to track your manual testing:

### Multi-Tenant Isolation
- [ ] Users cannot read other companies' company docs
- [ ] Users cannot read other companies' claims
- [ ] Users cannot read other companies' PODs
- [ ] Users cannot list other companies' data
- [ ] Deliveries are properly filtered by company

### Role-Based Access
- [ ] Drivers cannot create users
- [ ] Drivers cannot update company settings
- [ ] Drivers cannot access admin-only collections
- [ ] Admins can manage users in their company
- [ ] Admins cannot manage users in other companies

### User Protection
- [ ] Users cannot change their own role
- [ ] Users cannot change their own companyId
- [ ] Users CAN update allowed fields (name, phone)
- [ ] Deactivated users cannot access any data

### Company Creation
- [ ] Users cannot create companies directly
- [ ] Company creation only works via Cloud Functions

### Input Validation
- [ ] Invalid roles are rejected
- [ ] Invalid email formats are rejected
- [ ] Required fields are enforced
- [ ] String length limits are enforced

### Storage Security
- [ ] Users can only upload to their company's storage
- [ ] File size limits are enforced
- [ ] File type restrictions work

---

## 📊 REPORTING ISSUES

If any test fails, document:
1. **Test name** (e.g., "Multi-Tenant Isolation - Company Data Access")
2. **Expected behavior** (e.g., "Should be denied")
3. **Actual behavior** (e.g., "User could read other company's data")
4. **User context** (email, role, companyId)
5. **Error message** (if any)
6. **Steps to reproduce**

---

## 🔄 AFTER TESTING

1. **Cleanup Test Data** (optional)
   ```bash
   node test_security_rules.js
   # Then choose cleanup option
   ```

2. **Review Failed Tests**
   - Identify patterns
   - Update security rules if needed
   - Re-deploy and re-test

3. **Document Results**
   - Update security audit log
   - Note any edge cases found
   - Plan for additional testing scenarios

---

## 🎯 SUCCESS CRITERIA

All tests should show:
- ✅ Multi-tenant isolation working (no cross-company access)
- ✅ Role-based access enforced (drivers blocked from admin actions)
- ✅ User protection working (no privilege escalation)
- ✅ Company creation locked (invite-only system)
- ✅ Deactivated users blocked completely

If any critical test fails, **DO NOT deploy to production** until fixed.
