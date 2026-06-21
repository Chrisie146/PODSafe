# 🚨 URGENT FIX: Wrong Firebase Project

## The Problem

Your `android/app/google-services.json` is configured for **podsafe-production**, but:
1. Firestore is NOT enabled in podsafe-production
2. You've been adding SHA certificates to **podsafe-92a3e** (development)
3. Your code says Environment.development but Android is using production config

## The Solution

You need to download the correct `google-services.json` for **podsafe-92a3e** (development).

### Steps to Fix (3 minutes):

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/project/podsafe-92a3e/settings/general

2. **Find Your Android App:**
   - Scroll to "Your apps"
   - Look for `com.example.podsafe` (Android app)
   - **If it doesn't exist, you need to add it first!**

3. **Add Android App (if needed):**
   - Click "Add app" → Android icon
   - Package name: `com.example.podsafe`
   - Click "Register app"
   - **ADD YOUR SHA CERTIFICATES HERE:**
     - SHA-1: `F0:F5:43:03:03:8C:35:FF:3F:E5:D4:60:9D:33:F6:0E:E1:99:42:3F`
     - SHA-256: `AD:73:DD:AB:55:5C:28:9D:0D:B6:28:0E:62:84:69:9D:FC:B7:62:47:D0:89:3C:DB:CF:41:31:79:D9:EF:B3:29`
   - Download `google-services.json`

4. **OR Download from Existing App:**
   - If the Android app already exists in podsafe-92a3e
   - Click the settings icon next to it
   - Download `google-services.json`

5. **Replace the File:**
   ```powershell
   # Backup current file
   Copy-Item android\app\google-services.json android\app\google-services-production.json
   
   # Replace with downloaded file
   # Move your downloaded google-services.json to:
   # C:\Users\christopherm\PODSafe\podsafe\android\app\google-services.json
   ```

6. **Rebuild:**
   ```bash
   flutter clean
   flutter run
   ```

## What You Should See in the New File

```json
{
  "project_info": {
    "project_id": "podsafe-92a3e",  ← Should be THIS, not "podsafe-production"
    ...
  }
}
```

## Why This Happened

Android uses `google-services.json` which overrides the Flutter Firebase options. The file was configured for production, but Firestore isn't set up there.

## Quick Check

Before downloading, verify in Firebase Console:
- Project: **podsafe-92a3e**
- Android app: **com.example.podsafe**
- SHA certificates: **Added** (both SHA-1 and SHA-256)

## Alternative: Enable Firestore in Production

If you want to use podsafe-production instead:
1. Go to https://console.firebase.google.com/project/podsafe-production
2. Click "Firestore Database" in left menu
3. Click "Create database"
4. Choose "Start in test mode" for now
5. Add your SHA certificates to the Android app in podsafe-production

**But I recommend using podsafe-92a3e for development!**

---

## Your SHA Certificates (for reference):

**SHA-1:**
```
F0:F5:43:03:03:8C:35:FF:3F:E5:D4:60:9D:33:F6:0E:E1:99:42:3F
```

**SHA-256:**
```
AD:73:DD:AB:55:5C:28:9D:0D:B6:28:0E:62:84:69:9D:FC:B7:62:47:D0:89:3C:DB:CF:41:31:79:D9:EF:B3:29
```
