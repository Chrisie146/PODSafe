# POD Upload Permission Fix - Testing Guide

## ✅ What Was Fixed

**Issue:** Drivers getting "Cloud Firestore permission denied" when uploading PODs  
**Cause:** Missing Storage rules for `signatures/`, `photos/`, `pdfs/` paths + loose Firestore POD collection security  
**Fix:** Added proper Storage rules + tightened Firestore POD collection with company validation

---

## 🧪 How to Test

### Prerequisites
- ✅ Rules deployed to Firebase
- ✅ App cleaned and dependencies reinstalled
- ✅ You have a test driver account

### Test Steps

#### 1. **Start the App**
```powershell
cd c:\Users\christopherm\PODSafe\podsafe
flutter run -d chrome
```

#### 2. **Login as Driver**
- Email: `driver@podsafe.com`
- Password: `Driver123!`

#### 3. **Navigate to Delivery**
- Should see your company's deliveries
- Click on "John Doe" delivery or first undelivered delivery

#### 4. **Click "Capture POD"** 
- Should open POD capture screen
- No errors should appear

#### 5. **Capture Signature**
- Click "Capture Signature" button
- Draw something on the signature pad
- Click "Capture Signature" to save
- **Expected:** Signature uploads to Firebase Storage without error

#### 6. **Take Photo**
- Click "Take Photo" button
- Select or take a photo
- **Expected:** Photo uploads to Firebase Storage without error

#### 7. **Add Optional Notes** (if available)
- Add delivery notes
- **Expected:** Form accepts the data

#### 8. **Submit POD**
- Click "Submit POD" button
- **Expected:** Success! POD is created

### Expected Results ✅

✅ **Console Output (no errors):**
```
📝 Uploading signature... (bytes)
📤 Upload successful! URL: https://firebasestorage.googleapis.com/...
📝 Uploading photo... (bytes)
📤 Upload successful! URL: https://firebasestorage.googleapis.com/...
✅ POD submitted successfully!
```

✅ **Firebase Console - Storage:**
- Check bucket for new files in:
  - `signatures/{deliveryId}_*.png`
  - `photos/{deliveryId}_*.jpg`

✅ **Firebase Console - Firestore:**
- Check `pods` collection for new document
- Document should have:
  - `companyId`
  - `driverId`
  - `deliveryId`
  - `signatureUrl`
  - `photoUrl`
  - `createdAt`

✅ **Firebase Console - Deliveries:**
- Check delivery document
- Status should be updated to `"delivered"`

---

## ❌ Troubleshooting

### **Error: "Cloud Firestore permission denied"**
- **Cause:** Rules not deployed
- **Fix:** 
  ```powershell
  firebase deploy --only firestore:rules,storage:rules
  ```

### **Error: "Storage permission denied"**
- **Cause:** Missing Storage rules for `/signatures`, `/photos`, `/pdfs` paths
- **Fix:** Verify `storage.rules` has the new rules (check for `match /signatures/{fileName}`)

### **No error but file doesn't appear in Storage**
- **Cause:** File uploaded to wrong path
- **Check:** Look in Firebase Console → Storage → bucket → all paths
- **Verify:** Code should be uploading to root-level paths: `signatures/`, `photos/`, `pdfs/`

### **File uploaded but POD not created**
- **Cause:** Firestore `pods` collection write failed
- **Check:** Browser console for errors
- **Fix:** Verify user has `companyId` set in their profile

### **Can read POD but can't update it**
- **Cause:** Firestore update rules stricter than create
- **Check:** Rules prevent changing `companyId`, `driverId`, `deliveryId`, `createdAt`
- **Fix:** Don't modify these fields after creation

---

## 📊 Verification Checklist

After testing, verify:

- [ ] App runs without crashes
- [ ] Driver can login
- [ ] Deliveries load from Firestore
- [ ] POD capture screen opens
- [ ] Signature uploads without permission error
- [ ] Photo uploads without permission error  
- [ ] POD document created in Firestore
- [ ] Delivery status updates to "delivered"
- [ ] Files appear in Firebase Storage
- [ ] No data accessible across companies (multi-tenant isolation)

---

## 🔍 Key Security Validations

The rules now ensure:

1. **User must be authenticated** ✅
2. **User must be active** (`isActive == true`) ✅
3. **User must belong to company** (via `companyId` check) ✅
4. **POD must include `companyId`** ✅
5. **POD documents match user's company** ✅
6. **File types/sizes validated** ✅
7. **Critical fields protected from changes** ✅

---

## 📱 Mobile Testing

For testing on Android/iOS device:

```powershell
flutter run -d <device_id>
```

Then repeat the same steps above with actual camera.

---

## 💾 Logs to Check

**Browser Console (Flutter Web):**
```
flutter: 📝 Uploading signature...
flutter: 📤 Upload progress: 25.0%
flutter: 📤 Upload progress: 50.0%
flutter: 📤 Upload successful! URL: ...
```

**Firebase Console:**
- Firestore → Logs → Filter by collection: `pods`
- Storage → Rules Playground → Test the rules

---

## 🎯 Success Criteria

- ✅ POD signatures upload successfully
- ✅ POD photos upload successfully  
- ✅ POD documents created in Firestore
- ✅ No permission errors in console
- ✅ Files appear in Firebase Storage
- ✅ Delivery status updates
- ✅ Multi-tenant isolation maintained

---

## 📞 If Issues Persist

1. **Check Firebase project:**
   - Right project selected? (`podsafe-92a3e`)
   - Are you in dev/staging/production? (`firebase use <project>`)

2. **Check rules syntax:**
   ```powershell
   firebase deploy --only firestore:rules --debug
   ```

3. **Check authentication:**
   - User has valid Firebase Auth token
   - User document exists with `companyId`
   - `isActive` is `true`

4. **Check delivery document:**
   - Delivery exists in Firestore
   - Has `driverId` matching current user
   - Has `companyId` matching user's company

---

**Happy testing! 🚀**
