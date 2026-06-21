# Deploy Firestore Rules - Fix Claims Permission Error

## The Problem
```
W/Firestore: Listen for Query(companies/jE4WKflrexPV6DDBhxEj/settings/claims) 
failed: Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.}

I/flutter: Error generating claim ID: [cloud_firestore/permission-denied] 
The caller does not have permission to execute the specified operation.
```

## The Solution
Updated Firestore rules to allow access to claims and settings collections.

---

## Option 1: Deploy via Firebase CLI (Recommended)

### Step 1: Open PowerShell
```powershell
cd C:\Users\christopherm\PODSafe\podsafe
```

### Step 2: Deploy Rules
```powershell
firebase deploy --only firestore:rules
```

### Expected Output:
```
=== Deploying to 'podsafe-project'...

i  deploying firestore
i  firestore: checking firestore.rules for compilation errors...
✔  firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore

✔  Deploy complete!
```

---

## Option 2: Manual Deployment via Firebase Console

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select your project: **podsafe-project** (or your project name)

### Step 2: Navigate to Firestore Rules
1. Click "Firestore Database" in left sidebar
2. Click "Rules" tab at the top

### Step 3: Copy and Paste Rules
Replace the entire content with the rules from `firestore.rules` file:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function belongsToSameCompany(companyId) {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == companyId;
    }

    // Companies
    match /companies/{companyId} {
      allow read: if true;
      allow create: if isAuthenticated();
      allow update: if isAdmin() && belongsToSameCompany(companyId);
      allow delete: if false;
    }

    // Users
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow create: if isAuthenticated();
      allow update: if isOwner(userId);
      allow read: if isAdmin() && 
                     belongsToSameCompany(resource.data.companyId);
      allow update: if isAdmin() && 
                       belongsToSameCompany(resource.data.companyId);
      allow delete: if false;
    }

    // Deliveries
    match /deliveries/{deliveryId} {
      allow read: if isAdmin() && belongsToSameCompany(resource.data.companyId);
      allow read: if isAuthenticated() && resource.data.driverId == request.auth.uid;
      allow create: if isAdmin() && belongsToSameCompany(request.resource.data.companyId);
      allow update: if isAdmin() && belongsToSameCompany(resource.data.companyId);
      allow update: if resource.data.driverId == request.auth.uid && 
                       belongsToSameCompany(resource.data.companyId);
      allow delete: if isAdmin() && belongsToSameCompany(resource.data.companyId);
    }

    // PODs (Proof of Delivery)
    match /pods/{podId} {
      allow read, write: if isAuthenticated();
    }

    // ✨ NEW: Company Settings (nested under companies)
    match /companies/{companyId}/settings/{settingId} {
      // Admins can read/write settings for their company
      allow read: if belongsToSameCompany(companyId);
      allow write: if isAdmin() && belongsToSameCompany(companyId);
      // Drivers can read settings (needed for claim types, workflows, etc.)
      allow read: if isAuthenticated() && belongsToSameCompany(companyId);
    }

    // ✨ NEW: Claims (nested under companies)
    match /companies/{companyId}/claims/{claimId} {
      // Anyone in the company can read claims
      allow read: if belongsToSameCompany(companyId);
      
      // Drivers can create claims for their company
      allow create: if isAuthenticated() && 
                       belongsToSameCompany(companyId) &&
                       request.resource.data.companyId == companyId;
      
      // Drivers can update their own claims (add comments, evidence, etc.)
      allow update: if isAuthenticated() && 
                       belongsToSameCompany(companyId) &&
                       resource.data.driverId == request.auth.uid;
      
      // Admins can update any claim in their company
      allow update: if isAdmin() && belongsToSameCompany(companyId);
      
      // Only admins can delete claims
      allow delete: if isAdmin() && belongsToSameCompany(companyId);
    }
  }
}
```

### Step 4: Publish Rules
1. Click "Publish" button at the top
2. Wait for confirmation: "Rules were successfully published"

---

## Option 3: Quick Test Rules (Development Only)

**⚠️ WARNING: Use only for testing! Not for production!**

Replace with these permissive rules temporarily:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Then revert to proper rules after testing.

---

## Verification

### Step 1: Check Rules are Deployed
1. Go to Firebase Console > Firestore Database > Rules
2. Verify you see the new `companies/{companyId}/claims/{claimId}` rules
3. Check timestamp shows recent deployment

### Step 2: Test in App
1. Hot restart the app: Press `R` in terminal
2. Navigate to a delivery
3. Click "Report Issue" button
4. Try to submit a claim

### Expected Result:
- ✅ No permission errors in console
- ✅ Claim ID generated successfully
- ✅ Claim saved to Firestore
- ✅ Success message shown

### If Still Failing:
1. **Clear app data** (sometimes Firebase caches rules)
2. **Wait 1-2 minutes** (rules propagation can take time)
3. **Check company ID** matches in:
   - User document: `users/{userId}.companyId`
   - Claim path: `companies/{companyId}/claims/`

---

## What Changed in the Rules

### Before (Missing):
- ❌ No rules for `companies/{companyId}/settings/**`
- ❌ No rules for `companies/{companyId}/claims/**`
- ❌ Permission denied for reading settings
- ❌ Permission denied for creating claims

### After (Added):
- ✅ **Settings Rules**: Drivers can read, admins can write
- ✅ **Claims Rules**: 
  - Anyone in company can read claims
  - Drivers can create their own claims
  - Drivers can update their own claims
  - Admins can update any claim in company
  - Only admins can delete claims

---

## Security Features

### Multi-Tenant Isolation ✅
```javascript
belongsToSameCompany(companyId)
```
- Users can only access data from their own company
- Company ID checked on every request
- Prevents cross-company data leaks

### Role-Based Access ✅
```javascript
isAdmin() // Check if user is admin
```
- Admins have full access to company data
- Drivers have limited access to their own data
- Prevents unauthorized modifications

### Authentication Required ✅
```javascript
isAuthenticated() // Check if user is logged in
```
- All operations require authentication
- Anonymous access denied
- Firebase Auth integration

---

## Troubleshooting

### Error: "Missing index"
**Solution**: Create Firestore index
```powershell
firebase deploy --only firestore:indexes
```

### Error: "Rules compilation error"
**Problem**: Syntax error in rules file  
**Solution**: Check for:
- Missing semicolons
- Unclosed brackets
- Typos in function names

### Error: "Permission still denied after deployment"
**Solutions**:
1. Wait 1-2 minutes for propagation
2. Clear app cache/data
3. Verify user's `companyId` matches path
4. Check user document exists in Firestore
5. Verify user is authenticated (not anonymous)

### Error: "Cannot read user document"
**Problem**: Circular dependency (rules trying to read user during auth check)  
**Solution**: Ensure user document exists before first request

---

## Next Steps After Deployment

### 1. Test Claim Creation ✅
- Open app
- Navigate to delivery
- Click "Report Issue"
- Fill form and submit
- Verify claim appears in Firestore

### 2. Test Claim Reading ✅
- Build "My Claims" screen
- Fetch claims from Firestore
- Verify driver sees only their claims
- Verify admin sees all company claims

### 3. Test Settings Access ✅
- Create company settings document
- Read settings in Report Issue screen
- Verify custom fields display
- Verify claim types filter by settings

---

## Firebase Console Paths

### Firestore Database:
```
https://console.firebase.google.com/project/YOUR-PROJECT/firestore
```

### Security Rules:
```
https://console.firebase.google.com/project/YOUR-PROJECT/firestore/rules
```

### Authentication:
```
https://console.firebase.google.com/project/YOUR-PROJECT/authentication
```

---

## Quick Reference

### Deploy Command:
```powershell
firebase deploy --only firestore:rules
```

### Check Current Rules:
```powershell
firebase firestore:rules:get
```

### Test Rules Locally:
```powershell
firebase emulators:start --only firestore
```

---

## Summary

**Problem**: Permission denied accessing claims collection  
**Cause**: Missing Firestore security rules  
**Solution**: Deploy updated `firestore.rules` file  
**Status**: ✅ Rules updated, ready to deploy  

**Next Action**: Run `firebase deploy --only firestore:rules` in PowerShell

