# 🔍 Image Loading Debug Guide

## Quick Diagnosis Steps

### Step 1: Hot Restart the App
The new fixes require a **full restart**, not just hot reload:

```
In your terminal where flutter run is active:
1. Press 'R' (capital R) for HOT RESTART
   OR
2. Press 'q' to quit, then run: flutter run
```

### Step 2: Run Image Diagnostics Tool

**From Admin Panel:**
1. Login as admin (admin@podsafe.com)
2. Navigate to **POD Viewer** screen
3. Tap the **bug icon** (🐛) in top-right
4. View the detailed diagnostic report

The diagnostic tool will show you:
- ✅ All POD documents in database
- ✅ Signature and photo URLs for each POD
- ✅ URL format (gs:// vs https://)
- ✅ Whether URLs are accessible
- ✅ Specific error messages if URLs fail

### Step 3: Interpret Results

#### Scenario A: "No PODs found"
**Meaning**: No deliveries have been completed with POD yet

**Solution**:
1. Login as driver
2. Complete a delivery
3. Capture signature and photo
4. Submit POD
5. Check again in admin panel

#### Scenario B: "Format: gs:// (needs conversion)"
**Meaning**: URL is in storage format, needs conversion to download URL

**Status**: 
- If shows "✅ Converted successfully" → URL is working, image should load
- If shows "❌ Failed to convert" → Storage permissions issue

**Solution if failing**:
- Check Firebase Storage rules
- Verify files exist in Firebase Console → Storage

#### Scenario C: "Format: https:// (direct download URL)"
**Meaning**: URL is already a download URL

**Status**:
- If shows "✅ URL looks valid" → Should work
- If images still don't load → Network/CORS issue

**Solution if failing**:
- Check internet connection
- Clear app cache
- Try on different device/platform

#### Scenario D: "Unknown URL format" or "null"
**Meaning**: URLs weren't saved properly during POD upload

**Solution**:
- Re-capture POD
- Check upload errors in driver app logs
- Verify Firebase Storage is properly configured

## Common Issues & Fixes

### Issue 1: AppCheck Warning (NOT the Problem)
```
W/StorageUtil: Error getting App Check token; using placeholder token instead.
```

**This is just a warning** and won't prevent images from loading. Firebase App Check is optional for development.

### Issue 2: Images Upload But Won't Display

**Check**:
1. Are URLs being saved? (Use diagnostic tool)
2. Is the format correct? (gs:// or https://)
3. Can the URL be converted? (Diagnostic will try)

**Fix**:
1. Hot restart app (press 'R' in terminal)
2. View POD details again
3. New `FirebaseStorageImage` widget should handle conversion

### Issue 3: "Failed to load signature/photo"

**Without diagnostic details, try**:
1. Tap the image area - new widget shows "Retry" button
2. Check error message displayed
3. Run diagnostic tool for details

**Possible causes**:
- Network timeout
- Firebase Storage rules
- File deleted
- URL expired (shouldn't happen with Firebase)

## Manual Verification

### Check Firebase Console:

1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to **Storage**
4. Look for folder: `pods/`
5. Inside you should see subfolders with delivery IDs
6. Each should contain:
   - `signature_*.png` files
   - `photo_*.jpg` files

### Check Firestore:

1. In Firebase Console → **Firestore Database**
2. Open `pods` collection
3. Select a POD document
4. Check fields:
   - `signatureUrl`: Should have value (gs:// or https://)
   - `photoUrl`: Should have value (gs:// or https://)
   - If missing → POD wasn't submitted properly

## Testing the Fix

### Test 1: View Existing POD
1. Hot restart app (press 'R')
2. Login as admin
3. POD Viewer → Select a POD
4. Images should load (or show detailed error)

### Test 2: Create New POD
1. Login as driver
2. Complete a delivery
3. Capture signature and photo  
4. Submit POD
5. Watch for upload success message
6. Login as admin
7. View the new POD
8. Images should load

### Test 3: Run Diagnostics
1. Admin → POD Viewer → Bug icon (🐛)
2. Review diagnostic report
3. All should show "✅ OK"

## If Images STILL Won't Load

### Get Detailed Error Info:

The new `FirebaseStorageImage` widget shows:
- ✅ Error message
- ✅ Retry button
- ✅ URL being used

**Report these details:**
1. Exact error message shown
2. URL format (from diagnostic or error display)
3. Platform (Android/iOS/Web)
4. Whether diagnostic says "OK" or fails

### Quick Workarounds:

#### Option A: Re-upload POD
1. Find the delivery
2. Capture POD again
3. New upload might work

#### Option B: Check Storage Rules
```javascript
// In storage.rules, ensure this exists:
match /pods/{deliveryId}/{fileName} {
  allow read: if request.auth != null;
  allow write: if request.auth != null;
}
```

Deploy rules:
```bash
firebase deploy --only storage
```

#### Option C: Test with New Delivery
Create a fresh delivery and POD to test if issue is with old data or current upload process.

## Summary of Files Changed

### New Files:
- ✅ `lib/widgets/firebase_storage_image.dart` - Smart image loader
- ✅ `lib/screens/debug/image_debug_screen.dart` - Diagnostic tool

### Modified Files:
- ✅ `lib/screens/admin/pod_details_screen.dart` - Uses new widget
- ✅ `lib/screens/admin/pod_viewer_screen.dart` - Added debug button

## Next Steps

1. **Hot restart the app** (press 'R')
2. **Run diagnostic tool** (bug icon in POD Viewer)
3. **Share diagnostic output** if images still fail
4. Look for the specific error message shown
