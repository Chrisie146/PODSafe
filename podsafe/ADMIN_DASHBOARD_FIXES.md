# 🔧 Admin Dashboard Issues - Comprehensive Fixes

## Issues Identified

1. ✅ **Today's Overview showing no deliveries** - FIXED
2. ⚠️ **Insufficient permission error when creating users**
3. ⚠️ **No PODs displaying**

---

## Issue 1: Today's Overview Showing No Deliveries ✅ FIXED

### Problem
The query for today's deliveries was using `isGreaterThanOrEqualTo` without an upper bound, which may have been matching deliveries from future dates or not filtering correctly.

### Root Cause
```dart
// Old query - only lower bound
.where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
```

This query would match ALL deliveries scheduled today or in the future, which might not be what we want for "today's overview".

### Solution Applied
Added upper bound to properly filter only today's deliveries:

**Mobile Dashboard:**
```dart
final now = getSouthAfricanTime();
final startOfDay = DateTime(now.year, now.month, now.day);
final endOfDay = startOfDay.add(const Duration(days: 1));

final deliveriesSnapshot = await FirebaseFirestore.instance
    .collection('deliveries')
    .where('companyId', isEqualTo: companyId)
    .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
    .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
    .get();
```

**Desktop Dashboard:**
```dart
final now = getSouthAfricanTime();  // Uses SA timezone
final startOfDay = DateTime(now.year, now.month, now.day);
final endOfDay = startOfDay.add(const Duration(days: 1));

final deliveriesSnapshot = await FirebaseFirestore.instance
    .collection('deliveries')
    .where('companyId', isEqualTo: companyId)
    .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
    .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
    .get();
```

### Files Modified
- ✅ `lib/screens/admin/admin_dashboard_screen.dart` (mobile)
- ✅ `lib/screens/admin/admin_dashboard_desktop.dart` (desktop)

---

## Issue 2: Insufficient Permission Error When Creating Users

### Problem
Admin users are getting "insufficient permission" errors when trying to create new users in the User Management screen.

### Root Cause Analysis

The issue is in **Firestore Security Rules**. Let's look at the current rule:

```javascript
// Current rule in firestore.rules (lines 95-100)
// Only admins can create users in their company
allow create: if isAdmin() && 
                 request.resource.data.companyId == getUserData().companyId;

// Anyone can create during registration (special case)
allow create: if isSignedIn() && request.auth.uid == userId;
```

The problem is that when creating a user through the admin interface:
1. Admin creates user via `createUserWithEmailAndPassword` 
2. This creates a NEW Firebase Auth user
3. The new user's ID is different from the admin's ID
4. The rule checks `request.auth.uid == userId` which fails because:
   - `request.auth.uid` = the new user's ID (just created)
   - `userId` = the document path parameter
   - But admin is trying to write the document

### The Real Problem: Firebase Auth Limitation

The current implementation uses Firebase Client SDK's `createUserWithEmailAndPassword`, which **signs out the admin and signs in as the new user**. This is why:

1. Admin calls `createUserWithEmailAndPassword(newUser@email.com, password)`
2. Firebase creates the user AND signs in as that user
3. Admin is now signed out
4. When writing to Firestore `users/{newUserId}`, the current auth context is the NEW user
5. Firestore rule checks: "Is current user (newUser) an admin?" → NO
6. Permission denied

### Solution Options

#### Option A: Cloud Functions (RECOMMENDED for Production) ⭐

Create a Cloud Function that uses Firebase Admin SDK to create users without affecting the current session.

**Pros:**
- Admin never gets signed out
- More secure (server-side)
- Better UX
- Scalable

**Cons:**
- Requires Cloud Functions setup
- Need to deploy backend code

**Files to create:**
```
functions/
  ├── index.js           (Main Cloud Function)
  ├── package.json       (Dependencies)
  └── .gitignore
```

**Cloud Function code:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.createUser = functions.https.onCall(async (data, context) => {
  // Verify caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  // Get caller's user document
  const callerDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  const callerData = callerDoc.data();
  
  // Verify caller is admin
  if (!callerData || callerData.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can create users');
  }

  const { email, password, fullName, role, phoneNumber } = data;
  const companyId = callerData.companyId;

  try {
    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: fullName,
    });

    // Create user document in Firestore
    await admin.firestore()
      .collection('users')
      .doc(userRecord.uid)
      .set({
        email: email,
        fullName: fullName,
        role: role,
        companyId: companyId,
        phoneNumber: phoneNumber || null,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        approvalStatus: role === 'driver' ? 'pending' : 'approved',
      });

    return { success: true, userId: userRecord.uid };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

#### Option B: Fix Firestore Rules (TEMPORARY WORKAROUND) ⚠️

Modify Firestore rules to allow the newly created user to write their own document during the creation process.

**Current rule:**
```javascript
// Only admins can create users in their company
allow create: if isAdmin() && 
                 request.resource.data.companyId == getUserData().companyId;

// Anyone can create during registration (special case)
allow create: if isSignedIn() && request.auth.uid == userId;
```

**Issue:** The second rule `request.auth.uid == userId` only allows users to create their OWN document if they're already authenticated as that user. But during admin creation, the NEW user is authenticated but not yet an admin.

**Proposed Fix:**
```javascript
match /users/{userId} {
  // Users can read their own profile
  allow read: if isSignedIn() && request.auth.uid == userId;
  
  // Admins can read and list all users in their company
  allow read, list: if isAdmin() && 
                       get(/databases/$(database)/documents/users/$(userId)).data.companyId == getUserData().companyId;
  
  // Managers can list and read users in their company
  allow read, list: if isActive() &&
                       hasAnyRole(['manager', 'logistics']) &&
                       get(/databases/$(database)/documents/users/$(userId)).data.companyId == getUserData().companyId;
  
  // Allow user creation if:
  // 1. Creating their own account (registration) OR
  // 2. New user being created belongs to an existing company (admin creation)
  allow create: if isSignedIn() && 
                   request.auth.uid == userId &&
                   (
                     // Self-registration with new company
                     !exists(/databases/$(database)/documents/users/$(request.auth.uid)) ||
                     // Being created by admin in existing company
                     exists(/databases/$(database)/documents/companies/$(request.resource.data.companyId))
                   );
  
  // Users can update their own profile (limited fields)
  allow update: if isSignedIn() && 
                   request.auth.uid == userId &&
                   request.resource.data.role == resource.data.role &&
                   request.resource.data.companyId == resource.data.companyId &&
                   request.resource.data.isActive == resource.data.isActive;
  
  // Only admins can update user roles, status, and company assignment
  allow update: if isAdmin() && 
                   resource.data.companyId == getUserData().companyId &&
                   request.resource.data.companyId == getUserData().companyId;
  
  // No hard deletes
  allow delete: if false;
}
```

**⚠️ WARNING:** This workaround is less secure because it allows any authenticated user to create a document for themselves if a company exists. It's better than nothing but not production-ready.

### Recommended Action Plan

1. **Short-term (Today):** 
   - Deploy Cloud Functions solution
   - Update `auth_provider.dart` to call Cloud Function instead of client SDK
   - Test user creation

2. **Long-term:**
   - Keep Cloud Functions approach
   - Add proper error handling
   - Add audit logging

---

## Issue 3: No PODs Displaying

### Potential Root Causes

1. **No PODs in database yet**
   - Check Firebase Console → Firestore → `pods` collection
   - Are there any documents?

2. **Firestore index missing**
   - The query uses `companyId` + `timestamp` ordering
   - Check if index exists in `firestore.indexes.json`

3. **Permission issue**
   - Check Firestore rules for `pods` collection
   - Verify admin has read access

4. **CompanyId mismatch**
   - PODs might have different `companyId` than current user
   - Check data consistency

### Current POD Query
```dart
Query query = FirebaseFirestore.instance
    .collection('pods')
    .where('companyId', isEqualTo: companyId)
    .orderBy('timestamp', descending: true);
```

### Required Firestore Index
```json
{
  "collectionGroup": "pods",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "companyId",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "timestamp",
      "order": "DESCENDING"
    }
  ]
}
```

### Firestore Security Rule for PODs
```javascript
match /pods/{podId} {
  // Read: All active staff in company, plus assigned drivers
  allow read: if isActive() && (
    (hasAnyRole(['admin', 'manager', 'logistics', 'accountant', 'filing_clerk']) && 
     isCompanyDocument(resource.data)) ||
    (isApprovedDriver() && 
     resource.data.driverId == request.auth.uid &&
     isCompanyDocument(resource.data))
  );
  
  // Create: Drivers and filing clerks can upload PODs
  allow create: if isActive() &&
                   isCompanyDocument(request.resource.data) &&
                   hasAnyRole(['admin', 'manager', 'filing_clerk', 'driver']);
  
  // Update: Admin, Manager, Filing Clerk
  allow update: if isActive() &&
                   isCompanyDocument(resource.data) &&
                   hasAnyRole(['admin', 'manager', 'filing_clerk']);
  
  // Delete: Admin only
  allow delete: if isAdmin() && isCompanyDocument(resource.data);
}
```

### Diagnostic Steps

1. **Check Firebase Console:**
   ```
   Firebase Console → Firestore Database → pods collection
   ```
   - Are there any documents?
   - Do they have `companyId` field?
   - Do they have `timestamp` field?

2. **Check browser console:**
   - Open DevTools → Console
   - Look for Firestore errors
   - Look for "Missing index" errors

3. **Verify companyId:**
   ```dart
   // Add debug logging in pod_viewer_screen.dart
   print('Current companyId: $companyId');
   print('POD query: pods where companyId == $companyId');
   ```

4. **Check if index exists:**
   ```bash
   # Look in firestore.indexes.json
   # Should have pods collection with companyId + timestamp
   ```

5. **Test with simpler query:**
   ```dart
   // Temporarily remove orderBy to test
   Query query = FirebaseFirestore.instance
       .collection('pods')
       .where('companyId', isEqualTo: companyId);
       // .orderBy('timestamp', descending: true); // Comment out
   ```

### Solution Steps

#### Step 1: Verify Index Exists
Check `firestore.indexes.json` and add if missing:

```json
{
  "collectionGroup": "pods",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "companyId",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "timestamp",
      "order": "DESCENDING"
    }
  ]
}
```

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

#### Step 2: Verify POD Data Structure
Each POD document should have:
```json
{
  "companyId": "company-123",
  "deliveryId": "delivery-456",
  "driverId": "driver-789",
  "timestamp": Timestamp,
  "signatureUrl": "...",
  "photoUrl": "...",
  "location": {
    "latitude": -26.xxx,
    "longitude": 28.xxx
  },
  "recipientName": "John Doe"
}
```

#### Step 3: Add Debug Logging
Modify `pod_viewer_screen.dart`:

```dart
Stream<QuerySnapshot> _getPODsStream() {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final companyId = authProvider.companyId;

  print('🔍 POD Viewer - CompanyId: $companyId'); // DEBUG

  if (companyId == null) {
    print('❌ POD Viewer - No company ID!'); // DEBUG
    return const Stream.empty();
  }

  Query query = FirebaseFirestore.instance
      .collection('pods')
      .where('companyId', isEqualTo: companyId)
      .orderBy('timestamp', descending: true);

  print('🔍 POD Query created'); // DEBUG

  return query.snapshots();
}
```

---

## Quick Fix Commands

### 1. Deploy Firestore Indexes
```bash
firebase deploy --only firestore:indexes
```

### 2. Deploy Firestore Rules (if modified)
```bash
firebase deploy --only firestore:rules
```

### 3. Deploy Cloud Functions (for user creation fix)
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 4. Hot reload app
```bash
# In terminal where flutter is running, press 'r'
r
```

---

## Testing Checklist

### After Today's Overview Fix:
- [ ] Login as admin
- [ ] Check "Today's Overview" section
- [ ] Verify delivery counts are correct
- [ ] Create a new delivery for today
- [ ] Refresh dashboard
- [ ] Verify count increased

### After User Creation Fix:
- [ ] Login as admin
- [ ] Navigate to User Management
- [ ] Click "Add User" button
- [ ] Fill in user details
- [ ] Click "Create"
- [ ] Verify no permission error
- [ ] Verify admin stays logged in
- [ ] Verify new user appears in list
- [ ] Check Firebase Console → Authentication
- [ ] Verify new user exists

### After POD Display Fix:
- [ ] Login as admin
- [ ] Navigate to POD Viewer
- [ ] Verify PODs are displayed (if any exist)
- [ ] If no PODs: Create a delivery
- [ ] Complete delivery as driver
- [ ] Capture POD (signature + photo)
- [ ] Return to POD Viewer
- [ ] Verify POD appears in list

---

## Next Steps

1. ✅ Today's overview query fixed (already done)
2. ⚠️ Implement Cloud Functions for user creation
3. ⚠️ Debug POD display issue
4. ✅ Deploy changes
5. ✅ Test all features

