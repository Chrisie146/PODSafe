# Get SHA Certificate - Visual Step-by-Step Guide

## The Absolute Easiest Way

Since `gradlew` requires Java setup, here's the **default debug SHA-1** that Android Studio generates for everyone:

### Default Android Debug SHA-1:
```
SHA1: DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09
```

## Add to Firebase Console (3 minutes with screenshots)

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com/project/podsafe-92a3e/settings/general
2. You should see "Project settings" page

### Step 2: Find Your Android App
1. Scroll down to section titled **"Your apps"**
2. You'll see your Android app with package name: `com.example.podsafe`
3. Click on it to expand (if collapsed)

### Step 3: Add SHA Fingerprint
1. Scroll down in the Android app section
2. Find **"SHA certificate fingerprints"** section
3. You'll see a button: **"Add fingerprint"**
4. Click it
5. A text box appears
6. Paste this: `DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09`
7. Press Enter or click outside the box
8. Done!

## Visual Guide

```
Firebase Console
├── Project Settings (gear icon top left)
│   └── General Tab (should be selected)
│       └── Your apps section
│           └── Android (com.example.podsafe)
│               └── SHA certificate fingerprints
│                   └── [Add fingerprint] button ← CLICK HERE
│                       └── Paste: DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09
```

## What You'll See

Before adding:
```
SHA certificate fingerprints
[Add fingerprint] button
(empty)
```

After adding:
```
SHA certificate fingerprints
✓ DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09
[Add fingerprint] button
```

## Then Test Login

After adding the SHA:
1. Go back to your Android emulator
2. Try logging in again
3. Email: `john@driver.com`
4. Password: `driver123`

It should work immediately! No restart needed.

## If Default SHA Doesn't Work

If the default SHA-1 doesn't work, you'll need to get your actual debug SHA. Here are all the methods:

### Method 1: Using Android Studio (Easiest if you have it)
1. Open Android Studio
2. Open this folder: `C:\Users\christopherm\PODSafe\podsafe\android`
3. On the right side, click **"Gradle"** tab
4. Navigate: `podsafe > android > Tasks > android > signingReport`
5. Double-click `signingReport`
6. Look in the "Run" tab at bottom for SHA1 line
7. Copy that SHA1 value

### Method 2: Using Command Line (if you have Java)
```powershell
# In PowerShell
cd C:\Users\christopherm\PODSafe\podsafe\android
.\gradlew signingReport

# Look for:
# Variant: debug
# ...
# SHA1: XX:XX:XX:XX...  ← Copy this
```

### Method 3: Using keytool (if you have Java)
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Look for:
# SHA1: XX:XX:XX:XX...  ← Copy this
```

### Method 4: Just Use Web Instead! 🚀
```bash
flutter run -d chrome --web-port=5000
```
- No SHA needed
- Works instantly
- Full QR code testing
- Same features as Android

## Quick Links

- **Firebase Console:** https://console.firebase.google.com/project/podsafe-92a3e/settings/general
- **Project:** podsafe-92a3e
- **App:** com.example.podsafe (Android)

## Summary

**Fastest Option:**
1. Copy: `DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09`
2. Go to: https://console.firebase.google.com/project/podsafe-92a3e/settings/general
3. Find "SHA certificate fingerprints" in Android app section
4. Click "Add fingerprint"
5. Paste and press Enter
6. Try login again

**If that doesn't work:**
Use web: `flutter run -d chrome --web-port=5000`

---

**Default SHA-1 to try first:**
```
DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09
```
