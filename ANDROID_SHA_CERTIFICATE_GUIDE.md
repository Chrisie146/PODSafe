# Android SHA Certificate Setup for Firebase Auth

## Problem
Android Firebase Auth requires SHA-1/SHA-256 certificates to be registered in Firebase Console to work properly. Without them, you'll get:
```
Error: CONFIGURATION_NOT_FOUND
reCAPTCHA configuration error
```

## Quick Fix: Use Web Version
For immediate testing, use the web version instead:
```bash
flutter run -d chrome --web-port=5000
```
Web authentication works without SHA certificates!

## Permanent Solution: Add SHA Certificates to Firebase

### Step 1: Get SHA Certificates

#### Option A: Using Android Studio (Easiest)
1. Open Android Studio
2. Open the project: `C:\Users\christopherm\PODSafe\podsafe\android`
3. Click **Gradle** tab (right side)
4. Navigate to: `podsafe > android > Tasks > android > signingReport`
5. Double-click **signingReport**
6. View output in "Run" tab at bottom
7. Copy both SHA-1 and SHA-256 values

#### Option B: Using Command Line
If you have Java installed:
```powershell
# For debug keystore
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Look for lines like:
# SHA1: A1:B2:C3:D4:E5:F6:...
# SHA256: 1A:2B:3C:4D:5E:6F:...
```

#### Option C: Using Gradle (In Android Project Directory)
```powershell
cd android
.\gradlew signingReport

# Look for "Variant: debug" section
# Copy SHA1 and SHA-256 values
```

### Step 2: Add to Firebase Console

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/project/podsafe-92a3e
   - Click on **Project Settings** (gear icon)

2. **Select Your Android App:**
   - Scroll to "Your apps" section
   - Click on the Android app (`com.example.podsafe`)

3. **Add SHA Certificates:**
   - Scroll to "SHA certificate fingerprints" section
   - Click **"Add fingerprint"**
   - Paste SHA-1 value
   - Click **"Add fingerprint"** again
   - Paste SHA-256 value
   - Click **"Save"**

4. **Download New config:**
   - Click **"Download google-services.json"**
   - Replace file at: `android/app/google-services.json`

### Step 3: Rebuild App
```bash
flutter clean
flutter pub get
flutter run
```

## Debug Keystore Default Values

If you can't find your debug keystore, here are the defaults:

**Location:**
- Windows: `C:\Users\<username>\.android\debug.keystore`
- Mac/Linux: `~/.android/debug.keystore`

**Credentials:**
- Keystore password: `android`
- Alias: `androiddebugkey`
- Alias password: `android`

## Alternative: Create New Debug Keystore

If your debug keystore is missing:
```bash
keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000
```

## For Production Release

When building for release, you'll need to:
1. Create a release keystore
2. Get SHA-1/SHA-256 from release keystore
3. Add release certificates to Firebase Console
4. Sign your APK with release keystore

## Workaround for Immediate Testing

If you need Android testing immediately without SHA setup:

### Use Firebase Local Emulator
```bash
# Start Auth emulator
firebase emulators:start --only auth

# In lib/main.dart, connect to emulator:
if (kDebugMode) {
  await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
}
```
Note: Use `10.0.2.2` for Android emulator (not `localhost`)

### Or Test on Web
```bash
flutter run -d chrome --web-port=5000
```
- Login: john@driver.com / driver123
- Full QR code testing available
- No SHA certificates needed

## Verification

After adding SHA certificates, you should see:
```
✅ Successfully logged in
✅ No CONFIGURATION_NOT_FOUND errors
✅ Driver dashboard loads
```

## Current Status

**Working Platforms:**
- ✅ Web (Chrome) - No SHA needed
- ✅ iOS (when built) - Different cert system
- ⚠️ Android - Needs SHA certificates

**Test Account:**
- Email: john@driver.com
- Password: driver123

## Next Steps

1. **For immediate testing:** Use web version (`flutter run -d chrome --web-port=5000`)
2. **For Android:** Add SHA certificates using steps above
3. **Test QR codes:** Follow QR_CODE_TESTING_GUIDE.md

## Helpful Links
- [Firebase Android Setup](https://firebase.google.com/docs/android/setup)
- [SHA Certificate Guide](https://developers.google.com/android/guides/client-auth)
- [Debug Keystore Info](https://developer.android.com/studio/publish/app-signing#debug-mode)
