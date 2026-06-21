# 🚀 Quick Action Guide - Admin Dashboard Issues

## Summary of Fixes Applied

### ✅ Issue 1: Today's Overview Showing No Deliveries - FIXED
- **Fixed files:**
  - `lib/screens/admin/admin_dashboard_screen.dart` (mobile)
  - `lib/screens/admin/admin_dashboard_desktop.dart` (desktop)
- **What was changed:** Added upper bound to scheduledDate query to properly filter only today's deliveries
- **Status:** Code changes applied, waiting for hot reload/restart

---

## ⚠️ Issue 2: Cannot Create Users - Permission Error

### Root Cause
Firebase Client SDK's `createUserWithEmailAndPassword` **signs out the admin** and signs in as the new user. When the app tries to write the user document to Firestore, the current session is the NEW USER (not admin), so Firestore security rules deny the write.

### Solution: Use Cloud Functions

You need to create Firebase Cloud Functions to handle user creation server-side using Admin SDK (which doesn't affect the current session).

#### Step-by-Step Setup:

**1. Initialize Cloud Functions (if not already done):**
```bash
cd C:\Users\christopherm\PODSafe\podsafe
firebase init functions
```

Select:
- JavaScript or TypeScript (recommend JavaScript for simplicity)
- Install dependencies with npm

**2. Install dependencies:**
```bash
cd functions
npm install firebase-admin firebase-functions
cd ..
```

**3. Create the Cloud Function:**

Edit `functions/index.js` and add:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: Create User
 * Allows admins to create users without affecting their session
 */
exports.createUser = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be logged in to create users'
    );
  }

  try {
    // Get caller's user document to verify admin role
    const callerDoc = await admin.firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();
    
    if (!callerDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'User profile not found'
      );
    }

    const callerData = callerDoc.data();
    
    // Verify caller is admin
    if (callerData.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only administrators can create users'
      );
    }

    const { email, password, fullName, role, phoneNumber } = data;
    const companyId = callerData.companyId;

    // Validate input
    if (!email || !password || !fullName || !role) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: email, password, fullName, or role'
      );
    }

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
        lastLoginAt: null,
        approvalStatus: role === 'driver' ? 'pending' : 'approved',
      });

    console.log(`User created: ${email} (${role}) by admin: ${callerData.email}`);

    return {
      success: true,
      userId: userRecord.uid,
      message: 'User created successfully'
    };

  } catch (error) {
    console.error('Error creating user:', error);
    
    // Re-throw HttpsError as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    // Handle Firebase Auth errors
    if (error.code) {
      if (error.code === 'auth/email-already-exists') {
        throw new functions.https.HttpsError(
          'already-exists',
          'An account already exists with this email address'
        );
      }
      if (error.code === 'auth/invalid-email') {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Invalid email address'
        );
      }
      if (error.code === 'auth/weak-password') {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Password is too weak. Must be at least 6 characters'
        );
      }
    }
    
    // Generic error
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create user: ' + error.message
    );
  }
});
```

**4. Deploy the Cloud Function:**
```bash
firebase deploy --only functions
```

**5. Update Flutter app to use Cloud Function:**

Modify `lib/providers/auth_provider.dart`:

```dart
Future<bool> createUserAsAdmin({
  required String email,
  required String password,
  required String fullName,
  required UserRole role,
  String? phoneNumber,
  String? adminEmail,  // No longer needed
  String? adminPassword,  // No longer needed
}) async {
  _setLoading(true);
  _clearError();
  
  try {
    // Ensure current user is admin
    if (_currentUser == null || _currentUser!.role != UserRole.admin) {
      throw Exception('Only administrators can create users');
    }
    
    // Call Cloud Function instead of using client SDK
    final callable = FirebaseFunctions.instance.httpsCallable('createUser');
    
    final result = await callable.call({
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role.toString().split('.').last,
      'phoneNumber': phoneNumber,
    });
    
    if (result.data['success'] == true) {
      print('User created via Cloud Function: ${result.data['userId']}');
      _setLoading(false);
      return true;
    } else {
      throw Exception(result.data['message'] ?? 'Failed to create user');
    }
  } catch (e) {
    print('Create user error: $e');
    _setError(e.toString());
    _setLoading(false);
    return false;
  }
}
```

**6. Update User Management Screen:**

Remove the admin password re-authentication dialog since it's no longer needed.

Modify `lib/screens/admin/user_management_screen.dart` (around line 757):

```dart
Future<void> _createUser() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }
  
  setState(() {
    _isLoading = true;
  });
  
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  try {
    // No need for admin password anymore!
    final success = await authProvider.createUserAsAdmin(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: _selectedRole,
      phoneNumber: _phoneController.text.trim().isEmpty 
          ? null 
          : _phoneController.text.trim(),
    );
    
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

**7. Add Cloud Functions to pubspec.yaml:**
```yaml
dependencies:
  cloud_functions: ^4.5.0  # Add this if not present
```

Then run:
```bash
flutter pub get
```

---

## ⚠️ Issue 3: No PODs Displaying

### Diagnosis Steps

The POD index exists correctly in `firestore.indexes.json`, so the issue is likely:

1. **No PODs in database yet** (most likely)
2. **CompanyId mismatch**
3. **Permission issue** (less likely since index exists)

### Check 1: Do PODs exist in database?

**Open Firebase Console:**
1. Go to https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database"
4. Look for `pods` collection
5. Check if there are any documents

**If NO documents exist:**
- This is normal if you haven't captured any PODs yet
- To test: Complete a delivery as a driver and capture a POD
- PODs will then appear

**If documents exist:**
- Check if they have `companyId` field
- Check if `companyId` matches your admin user's companyId

### Check 2: Verify your CompanyId

**Add debug logging:**

Open `lib/screens/admin/pod_viewer_screen.dart` and modify the `_getPODsStream` method (around line 169):

```dart
Stream<QuerySnapshot> _getPODsStream() {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final companyId = authProvider.companyId;

  // DEBUG: Print companyId
  print('🔍 [POD Viewer] Current user companyId: $companyId');

  if (companyId == null) {
    print('❌ [POD Viewer] ERROR: No company ID found!');
    return const Stream.empty();
  }

  Query query = FirebaseFirestore.instance
      .collection('pods')
      .where('companyId', isEqualTo: companyId)
      .orderBy('timestamp', descending: true);

  // Apply date filters
  if (_selectedFilter != 'all') {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedFilter) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(2020);
    }

    query = query.where(
      'timestamp',
      isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
    );
  }

  print('✅ [POD Viewer] Query created for companyId: $companyId');

  return query.snapshots();
}
```

**Hot reload the app** and check the debug console for these messages.

### Check 3: Test POD Creation

**If no PODs exist, create one:**

1. **Create a test delivery:**
   - Login as admin
   - Go to Delivery Management
   - Create a new delivery
   - Assign to a driver

2. **Complete delivery as driver:**
   - Logout
   - Login as the assigned driver
   - Open the delivery
   - Tap "Capture POD"
   - Add signature
   - Take photo
   - Submit

3. **View POD as admin:**
   - Logout
   - Login as admin
   - Go to POD Viewer
   - POD should now appear

---

## 🔥 Quick Commands

### Restart Flutter App (apply today's overview fix)
```bash
# In the terminal where flutter run is running, press:
R   # (capital R for full restart)
```

### Deploy Cloud Functions (fix user creation)
```bash
cd C:\Users\christopherm\PODSafe\podsafe
firebase deploy --only functions
```

### Check Flutter Errors
```bash
flutter analyze
```

### View Firebase Console
```bash
# Windows: Press Windows+R, then type:
start https://console.firebase.google.com
```

---

## 📝 Testing Checklist

### Test 1: Today's Overview (Should work after restart)
- [ ] Hot restart Flutter app (press `R`)
- [ ] Login as admin
- [ ] Check "Today's Overview" section
- [ ] Create a delivery for today
- [ ] Refresh dashboard
- [ ] Verify count increased

### Test 2: User Creation (After Cloud Functions deployed)
- [ ] Deploy Cloud Functions
- [ ] Restart Flutter app
- [ ] Login as admin
- [ ] Go to User Management
- [ ] Click "+ Add User"
- [ ] Fill in details
- [ ] Click "Create"
- [ ] Verify: No permission error
- [ ] Verify: Admin stays logged in
- [ ] Verify: New user in list

### Test 3: PODs
- [ ] Check Firebase Console for pods collection
- [ ] If no PODs: Create test POD (see steps above)
- [ ] Add debug logging (see above)
- [ ] Check console output
- [ ] Verify PODs display

---

## 🆘 Still Having Issues?

### Issue: Today's overview still showing zero
**Check:**
- Did you hot restart? (Press `R` not `r`)
- Are there actually deliveries scheduled for today in Firestore?
- Check Firebase Console → Firestore → deliveries → filter by scheduledDate

### Issue: Cloud Functions deployment fails
**Check:**
- Is Firebase CLI installed? `firebase --version`
- Are you logged in? `firebase login`
- Is project selected? `firebase use --add`
- Node.js installed? `node --version`

### Issue: PODs still not showing
**Check:**
- Run the app with: `flutter run -v` (verbose mode)
- Check console for Firestore errors
- Verify PODs exist in Firebase Console
- Verify companyId matches (use debug logging above)

---

## 📞 What to Report Back

If issues persist, please provide:

1. **For Today's Overview:**
   - Screenshot of admin dashboard
   - Number of deliveries in Firestore for today
   - Any console errors

2. **For User Creation:**
   - Exact error message
   - Cloud Functions deployment log output
   - Firebase Console → Functions (screenshot)

3. **For PODs:**
   - Debug console output (companyId logs)
   - Screenshot of pods collection in Firebase Console
   - Any Firestore errors in console

