# 🔐 Deploy Firestore RBAC Rules - URGENT

## ⚠️ Current Problem

**The manager user cannot see deliveries because:**
- ✅ Frontend RBAC is working (User Management button visible)
- ❌ **Backend Firestore rules are OLD** - don't recognize manager/logistics/accountant/filing_clerk roles
- ❌ All queries return `PERMISSION_DENIED` errors

**Error in logs:**
```
W/Firestore: Listen for Query(deliveries where companyId==jE4WKflrexPV6DDBhxEj...) 
failed: Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.}
```

---

## 🚀 Solution: Deploy New RBAC Rules

### Step 1: Backup Current Rules (Optional)

```powershell
# In case you need to rollback
Copy-Item firestore.rules firestore.rules.backup
```

### Step 2: Replace Rules File

```powershell
# Copy RBAC rules to production file
Copy-Item firestore.rules.rbac firestore.rules -Force
```

### Step 3: Deploy to Firebase

```powershell
# Deploy the new rules
firebase deploy --only firestore:rules
```

**Expected output:**
```
=== Deploying to 'your-project'...

i  deploying firestore
i  firestore: reading indexes from firestore.indexes.json...
i  firestore: reading rules from firestore.rules...
✔  firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore

✔  Deploy complete!
```

### Step 4: Verify Deployment

1. **Open Firebase Console**
2. **Go to Firestore Database** → **Rules tab**
3. **Check that rules now include:**
   - `hasRole()` function
   - `hasAnyRole()` function
   - `canManageDeliveries()` function
   - Manager/Logistics/Accountant role checks

---

## 📋 What the New Rules Enable

### For Manager Role:
```javascript
// Managers can now:
- Read deliveries in their company ✅
- Read PODs in their company ✅
- Read customers in their company ✅
- View analytics data ✅
- Approve deliveries/PODs ✅
// Managers CANNOT:
- Create/edit deliveries ❌
- Manage users ❌
- Manage drivers ❌
```

### Multi-Tenant Security:
- All queries are filtered by `companyId`
- Users can only see data from their own company
- Role permissions are enforced at the database level

---

## 🧪 Test After Deployment

### 1. Hot Restart the App
```powershell
# In the Flutter terminal, press:
R  # (capital R for hot restart)
```

### 2. Login as Manager
- Email: `testmanager@test.com`
- Password: `TestPass123`

### 3. Expected Results After Rule Deployment:
- ✅ Admin Dashboard loads
- ✅ Company stats show delivery counts
- ✅ "View Deliveries" button visible
- ✅ Can open Delivery Management screen
- ✅ Sees list of 24 deliveries
- ✅ User Management button HIDDEN (no permission)
- ✅ No + FAB on deliveries (view-only access)

---

## 🔍 Verify Rules in Firebase Console

After deployment, check:

1. **Go to Firebase Console** → Your Project
2. **Firestore Database** → **Rules** tab
3. **Look for these key sections:**

```javascript
// Should see RBAC helper functions:
function hasRole(role) {
  return isSignedIn() && getUserData().role == role;
}

function hasAnyRole(roles) {
  return isSignedIn() && getUserData().role in roles;
}

function canManageDeliveries() {
  return isActive() && hasAnyRole(['admin', 'manager', 'logistics']);
}

// Deliveries rules should include:
match /deliveries/{deliveryId} {
  // Admins, managers, and logistics can read
  allow read: if isActive() && 
                 hasAnyRole(['admin', 'manager', 'logistics', 'accountant', 'filing_clerk']) &&
                 belongsToCompany(resource.data.companyId);
  
  // Only logistics and admin can create
  allow create: if canManageDeliveries() && 
                   request.resource.data.companyId == getUserData().companyId;
}
```

---

## 📊 Before vs After

### BEFORE (Current State):
```
firestore.rules:
- isAdmin() → Only checks for 'admin' role
- isOwner() → Basic ownership checks
- No manager/logistics/accountant support
❌ Manager queries = PERMISSION_DENIED
```

### AFTER (With RBAC Rules):
```
firestore.rules.rbac:
- hasRole() → Checks any of 6 roles
- hasAnyRole() → Checks multiple roles
- canManageDeliveries() → Manager + Logistics + Admin
- canViewFinance() → Manager + Accountant + Admin
✅ Manager queries = SUCCESS
```

---

## ⚡ Quick Deploy Commands

```powershell
# All in one - backup, replace, deploy
Copy-Item firestore.rules firestore.rules.backup; Copy-Item firestore.rules.rbac firestore.rules -Force; firebase deploy --only firestore:rules
```

---

## 🐛 Troubleshooting

### Problem: "firebase: command not found"

**Solution:**
```powershell
npm install -g firebase-tools
firebase login
```

### Problem: Deploy fails with "Permission denied"

**Solution:**
```powershell
# Re-authenticate
firebase login --reauth
```

### Problem: Rules deployed but still getting PERMISSION_DENIED

**Solutions:**
1. **Wait 1-2 minutes** for rules to propagate globally
2. **Hard refresh the app** (hot restart with R)
3. **Check user document** in Firestore Console:
   - Verify `role: "manager"` is set correctly
   - Verify `isActive: true`
   - Verify `companyId: "jE4WKflrexPV6DDBhxEj"`
4. **Check deliveries collection:**
   - Verify documents have `companyId: "jE4WKflrexPV6DDBhxEj"`

### Problem: Admin can't create users after deploying rules

**Solution:**
Check that admin user document has:
```json
{
  "role": "admin",
  "isActive": true,
  "companyId": "jE4WKflrexPV6DDBhxEj"
}
```

---

## 📝 What Changed in Rules

### Old Rules (firestore.rules):
```javascript
// Deliveries - very basic
allow read: if isAuthenticated() && belongsToSameCompany(resource.data.companyId);
allow write: if isAdmin() && belongsToSameCompany(resource.data.companyId);
```

### New Rules (firestore.rules.rbac):
```javascript
// Deliveries - RBAC with multiple roles
allow read: if isActive() && 
               hasAnyRole(['admin', 'manager', 'logistics', 'accountant', 'filing_clerk']) &&
               belongsToCompany(resource.data.companyId);

// Only logistics and admin can create
allow create: if isActive() &&
                 hasAnyRole(['admin', 'logistics']) &&
                 request.resource.data.companyId == getUserData().companyId;

// Logistics, manager, and admin can update
allow update: if canManageDeliveries() && 
                 isCompanyDocument(resource.data) &&
                 isCompanyDocument(request.resource.data);
```

---

## ✅ Success Criteria

After deploying rules, you should see:

### In Firebase Console:
- ✅ Rules tab shows new RBAC functions
- ✅ Published timestamp is recent (just now)

### In Flutter App (as Manager):
- ✅ No more PERMISSION_DENIED errors in logs
- ✅ Dashboard shows delivery stats
- ✅ Can view deliveries list
- ✅ Can view POD details
- ✅ Can view customer list
- ✅ Cannot see User Management button
- ✅ Cannot see + FAB to create deliveries

### In Console Logs:
```
BEFORE:
W/Firestore: Listen for Query(...) failed: PERMISSION_DENIED

AFTER:
I/flutter: 📦 Loading deliveries for companyId: jE4WKflrexPV6DDBhxEj
I/flutter: ✅ Query created successfully
I/flutter: 📊 Document count: 24
```

---

## 🎯 Next Steps After Deployment

1. ✅ **Deploy rules** (this guide)
2. ✅ **Test manager access** (should work now)
3. ✅ **Test other roles:**
   - Create logistics user → Can create deliveries
   - Create accountant user → Can view analytics
   - Create filing clerk user → Can view deliveries
   - Create driver user → Needs approval, then sees assigned deliveries
4. ✅ **Continue with USER_MANAGEMENT_TESTING_GUIDE.md** Phase 5+

---

## 🔥 Deploy Now!

**Run this command to deploy:**

```powershell
Copy-Item firestore.rules.rbac firestore.rules -Force; firebase deploy --only firestore:rules
```

Then hot restart the app with **R** and login as manager to see deliveries! 🚀
