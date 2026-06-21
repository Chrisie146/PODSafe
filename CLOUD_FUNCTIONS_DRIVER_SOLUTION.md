# Production Driver Creation - Cloud Functions Solution

## Overview
Use Firebase Cloud Functions to create drivers server-side, allowing admin to stay logged in.

## Setup Steps

### 1. Initialize Cloud Functions

```bash
cd C:\Users\christopherm\PODSafe\podsafe
firebase init functions
```

Select:
- Language: TypeScript (or JavaScript)
- ESLint: Yes
- Install dependencies: Yes

### 2. Install Dependencies

```bash
cd functions
npm install firebase-admin
npm install firebase-functions
```

### 3. Create Cloud Function

**File: `functions/src/index.ts`**

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const createDriver = functions.https.onCall(async (data, context) => {
  // Verify caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be logged in to create drivers'
    );
  }

  // Verify caller is admin (check role in Firestore)
  const callerDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can create drivers'
    );
  }

  // Validate input
  const { email, password, displayName, phoneNumber, licenseNumber, vehicleInfo } = data;
  
  if (!email || !password || !displayName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email, password, and display name are required'
    );
  }

  try {
    // Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    // Create Firestore document
    await admin.firestore()
      .collection('users')
      .doc(userRecord.uid)
      .set({
        id: userRecord.uid,
        uid: userRecord.uid,
        email: email,
        displayName: displayName,
        fullName: displayName,
        phoneNumber: phoneNumber || null,
        licenseNumber: licenseNumber || null,
        vehicleInfo: vehicleInfo || null,
        role: 'driver',
        companyId: 'company_001', // Get from caller's company
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      uid: userRecord.uid,
      email: email,
      message: 'Driver created successfully'
    };

  } catch (error: any) {
    console.error('Error creating driver:', error);
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to create driver'
    );
  }
});

export const updateDriver = functions.https.onCall(async (data, context) => {
  // Verify caller is authenticated and admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const callerDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can update drivers');
  }

  const { driverId, displayName, phoneNumber, licenseNumber, vehicleInfo } = data;

  if (!driverId) {
    throw new functions.https.HttpsError('invalid-argument', 'Driver ID is required');
  }

  try {
    // Update Firestore document
    await admin.firestore()
      .collection('users')
      .doc(driverId)
      .update({
        displayName: displayName,
        phoneNumber: phoneNumber || null,
        licenseNumber: licenseNumber || null,
        vehicleInfo: vehicleInfo || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      message: 'Driver updated successfully'
    };

  } catch (error: any) {
    console.error('Error updating driver:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

### 4. Deploy Cloud Functions

```bash
firebase deploy --only functions
```

### 5. Update Flutter App to Use Cloud Function

**File: `lib/services/driver_service.dart`** (new file)

```dart
import 'package:cloud_functions/cloud_functions.dart';

class DriverService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>> createDriver({
    required String email,
    required String password,
    required String displayName,
    String? phoneNumber,
    String? licenseNumber,
    String? vehicleInfo,
  }) async {
    try {
      final result = await _functions.httpsCallable('createDriver').call({
        'email': email,
        'password': password,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'licenseNumber': licenseNumber,
        'vehicleInfo': vehicleInfo,
      });

      return {
        'success': true,
        'uid': result.data['uid'],
        'email': result.data['email'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Failed to create driver',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> updateDriver({
    required String driverId,
    required String displayName,
    String? phoneNumber,
    String? licenseNumber,
    String? vehicleInfo,
  }) async {
    try {
      await _functions.httpsCallable('updateDriver').call({
        'driverId': driverId,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'licenseNumber': licenseNumber,
        'vehicleInfo': vehicleInfo,
      });

      return {'success': true};
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Failed to update driver',
      };
    }
  }
}
```

### 6. Add Dependency to pubspec.yaml

```yaml
dependencies:
  cloud_functions: ^4.5.0
```

Run:
```bash
flutter pub get
```

### 7. Update create_driver_screen.dart

Replace the `_createNewDriver()` method:

```dart
Future<void> _createNewDriver() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();
  
  final driverService = DriverService();
  
  final result = await driverService.createDriver(
    email: email,
    password: password,
    displayName: _displayNameController.text.trim(),
    phoneNumber: _phoneController.text.trim().isEmpty 
        ? null 
        : _phoneController.text.trim(),
    licenseNumber: _licenseNumberController.text.trim().isEmpty 
        ? null 
        : _licenseNumberController.text.trim(),
    vehicleInfo: _vehicleInfoController.text.trim().isEmpty 
        ? null 
        : _vehicleInfoController.text.trim(),
  );

  if (!result['success']) {
    throw Exception(result['error']);
  }
  
  // Admin stays logged in!
  // No logout needed!
}
```

## Benefits

✅ **Admin stays logged in** - No logout/login cycle
✅ **Secure** - Server validates admin role
✅ **Production-ready** - Industry standard approach
✅ **Scalable** - Can add more features (email verification, etc.)
✅ **Proper separation** - Business logic on server, not client

## Cost

Firebase Cloud Functions:
- **Free tier**: 2M invocations/month
- Creating drivers is rare (not millions/month)
- **Essentially free** for your use case

## Testing

```bash
# Deploy
firebase deploy --only functions

# Test from app
1. Login as admin
2. Create driver
3. Admin stays logged in ✅
4. Driver account created ✅
5. Can immediately login as driver ✅
```
