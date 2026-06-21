# Firebase Auth Android Login Fix

## Issue
When trying to login on Android emulator, Firebase Auth was failing with:
```
E/RecaptchaCallWrapper: Initial task failed for action RecaptchaAction(action=signInWithPassword)
with exception - An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]
I/flutter: Sign in error: [firebase_auth/unknown] An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]
```

## Root Causes

### 1. reCAPTCHA Configuration Missing
Firebase Auth on Android was trying to use reCAPTCHA verification but:
- No SHA-1/SHA-256 fingerprints configured in Firebase Console
- App Check not configured
- reCAPTCHA keys not set up

### 2. Import Naming Conflict
When adding `firebase_auth` import to fix the issue:
```
Error: 'AuthProvider' is imported from both 
'package:firebase_auth_platform_interface/src/auth_provider.dart' and 
'package:podsafe/providers/auth_provider.dart'.
```

## Solutions Applied

### Solution 1: Disable App Verification for Testing
Added code to disable Firebase Auth app verification in development mode:

```dart
// In lib/main.dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

// In main() function, after Firebase initialization:
if (kDebugMode && !kIsWeb) {
  try {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
    debugPrint('✅ Firebase Auth app verification disabled for testing');
  } catch (e) {
    debugPrint('⚠️ Could not disable app verification: $e');
  }
}
```

### Solution 2: Fix Import Naming Conflict
Used `hide` keyword to prevent Firebase's AuthProvider from conflicting with our app's AuthProvider:

```dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'providers/auth_provider.dart';  // Our custom AuthProvider
```

## For Production

For production builds, you should properly configure Firebase Auth:

### Option A: Add SHA Certificates (Recommended)
1. Get your app's SHA-1 and SHA-256 fingerprints:
   ```bash
   # Debug keystore
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # Release keystore
   keytool -list -v -keystore path/to/release.keystore -alias your-alias
   ```

2. Add to Firebase Console:
   - Go to Project Settings → Your Android App
   - Add SHA-1 and SHA-256 fingerprints
   - Download updated `google-services.json`
   - Replace `android/app/google-services.json`

### Option B: Configure App Check
1. Enable App Check in Firebase Console
2. Add App Check dependency to `pubspec.yaml`:
   ```yaml
   dependencies:
     firebase_app_check: ^0.2.1+0
   ```

3. Initialize in `main.dart`:
   ```dart
   import 'package:firebase_app_check/firebase_app_check.dart';
   
   await FirebaseAppCheck.instance.activate(
     androidProvider: AndroidProvider.debug, // or .playIntegrity for production
   );
   ```

### Option C: Use Firebase Auth Emulator (Development Only)
```dart
if (kDebugMode) {
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

## Verification

After applying the fix, you should be able to:
1. ✅ Launch app on Android emulator
2. ✅ Login with email/password (john@driver.com / driver123)
3. ✅ No reCAPTCHA errors in logs
4. ✅ Successful authentication

## Files Modified
- `lib/main.dart` - Added Firebase Auth import with `hide AuthProvider`, added app verification disable for testing

## Testing
```bash
# Clean build
flutter clean
flutter pub get

# Run on Android emulator
flutter run

# Login with test account
# Email: john@driver.com
# Password: driver123
```

## Common Issues

### Issue: Still getting CONFIGURATION_NOT_FOUND
**Solution**: Make sure the app verification disable code runs AFTER Firebase is initialized and BEFORE any login attempts.

### Issue: Web login works but Android doesn't
**Solution**: This is expected - web uses different authentication mechanisms. Android requires SHA certificates or App Check in production.

### Issue: Import conflict with other Firebase packages
**Solution**: Use `hide` or `as` keywords:
```dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
// or
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
```

## Environment Info
- Flutter: 3.8.1+
- Firebase Auth: Latest version from pubspec.yaml
- Platform: Android (sdk_gphone64_x86_64 emulator)
- Mode: Development (podsafe-92a3e project)

## References
- [Firebase Auth Android Setup](https://firebase.google.com/docs/auth/android/start)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
- [SHA Certificate Guide](https://developers.google.com/android/guides/client-auth)
