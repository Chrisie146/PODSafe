# 🔐 PODSafe Security Rules - Hardened Configuration

**Created:** November 18, 2025  
**Status:** ✅ Ready for Production  
**Security Level:** Enterprise-Grade Multi-Tenant Isolation

---

## 📋 EXECUTIVE SUMMARY

PODSafe security rules have been completely rewritten to implement:

- ✅ **Invite-only user system** (no public registration)
- ✅ **Strict multi-tenant isolation** (companies cannot access each other's data)
- ✅ **Role-based access control** (admin vs driver permissions)
- ✅ **Input validation** (field types, sizes, formats)
- ✅ **Critical field protection** (cannot change companyId, role without authorization)
- ✅ **Active user enforcement** (deactivated users blocked)
- ✅ **Comprehensive audit trails** (all changes tracked)

---

## 🚨 CRITICAL CHANGES (Breaking)

### **1. Company Creation Locked Down**
```javascript
// BEFORE:
allow create: if true; // ❌ Anyone could create companies

// AFTER:
allow create: if false; // ✅ Only via Cloud Functions
```

**Impact:** Users cannot self-register. You MUST use Cloud Functions to create companies/users.

### **2. Company Codes Secured**
```javascript
// BEFORE:
allow read, write: if true; // ❌ Public access

// AFTER:
allow read, write: if false; // ✅ No direct access
```

**Impact:** Company codes can only be managed via Cloud Functions.

### **3. Multi-Tenant Isolation Enforced**
```javascript
// BEFORE:
allow read: if isSignedIn(); // ❌ Any user could read any company

// AFTER:
allow read: if isCompanyMember(companyId); // ✅ Only your company
```

**Impact:** Users can ONLY access data from their own company.

### **4. User Document Protection**
```javascript
// BEFORE:
allow update: if isSignedIn(); // ❌ Users could change their role/company

// AFTER:
allow update: if ... && notChanging(['role', 'companyId', ...]); // ✅ Critical fields locked
```

**Impact:** Users cannot escalate privileges or switch companies.

---

## 🔧 DEPLOYMENT INSTRUCTIONS

### **Step 1: Backup Current Rules**

```powershell
# Automatic backup when running deployment script
.\deploy_secure_rules.ps1
```

### **Step 2: Review Changes**

Compare files:
- `firestore.rules.secure` vs `firestore.rules`
- `storage.rules.secure` vs `storage.rules`

### **Step 3: Deploy to Staging First**

```powershell
# Switch to staging environment
firebase use staging

# Deploy secure rules
firebase deploy --only firestore:rules,storage

# Test thoroughly!
```

### **Step 4: Deploy to Production**

```powershell
# Switch to production
firebase use prod

# Run deployment script
.\deploy_secure_rules.ps1

# Follow prompts
```

### **Step 5: Deploy Cloud Functions**

```powershell
cd functions
npm install
npm run deploy
```

---

## 👥 USER MANAGEMENT (Post-Deployment)

### **Create a Company (Super Admin Only)**

```javascript
// From Firebase Console or admin script
const functions = require('firebase-functions');
const createCompany = httpsCallable(functions, 'createCompany');

const result = await createCompany({
  name: 'ACME Transport Ltd',
  email: 'info@acme.com',
  phone: '+27123456789',
  address: '123 Main St, Johannesburg',
  adminEmail: 'admin@acme.com',
  adminName: 'John Admin'
});

// Returns: { companyId, resetLink, adminUserId }
// Send resetLink to admin via email
```

### **Invite Users (Admin Function)**

```javascript
// From admin panel in the app
const inviteUser = httpsCallable(functions, 'inviteUser');

const result = await inviteUser({
  email: 'driver@acme.com',
  fullName: 'Jane Driver',
  role: 'driver',
  phoneNumber: '+27987654321'
});

// Returns: { userId, resetLink }
// Send resetLink to user via email
```

### **Deactivate Users**

```javascript
const deactivateUser = httpsCallable(functions, 'deactivateUser');

await deactivateUser({ userId: 'abc123' });
// User immediately loses all access
```

---

## 🔍 SECURITY FEATURES

### **Multi-Tenant Isolation**

Every company-scoped collection enforces:
```javascript
function isCompanyMember(companyId) {
  return isAuthenticated() && 
         getUserData().companyId == companyId;
}
```

**Protected Collections:**
- companies/{companyId}
- companies/{companyId}/claims
- companies/{companyId}/pods
- companies/{companyId}/vehicles
- companies/{companyId}/conversations
- deliveries (filtered by driver's company)

### **Role-Based Access Control**

**Admin Privileges:**
- Create/update/delete users in their company
- Manage company settings
- View all data within company
- Invite new users
- Manage integrations

**Driver Privileges:**
- View deliveries assigned to them
- Create/update PODs for their deliveries
- Create claims for missing PODs
- Update own profile (limited)
- Participate in conversations

### **Input Validation**

**Email Validation:**
```javascript
function isValidEmail(email) {
  return email.matches('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$');
}
```

**String Length:**
```javascript
function isValidString(value, minLen, maxLen) {
  return value is string && 
         value.size() >= minLen && 
         value.size() <= maxLen;
}
```

**Applied to:**
- User names (2-100 chars)
- Claim numbers (1-50 chars)
- Chat messages (1-5000 chars)
- All user input fields

### **Critical Field Protection**

Fields that CANNOT be changed after creation:
- `companyId` (prevents company switching)
- `role` (admins can change, users cannot)
- `createdAt` (audit trail)
- `email` (identity protection)
- Document IDs

### **Active User Enforcement**

All operations require:
```javascript
function isActiveUser() {
  return isAuthenticated() && 
         getUserData().isActive == true;
}
```

Deactivated users immediately lose all access.

---

## 📊 SECURITY TESTING CHECKLIST

### **Multi-Tenant Isolation Tests**

- [ ] User from Company A cannot read Company B's data
- [ ] User from Company A cannot update Company B's data
- [ ] User from Company A cannot list Company B's collections
- [ ] Deliveries are filtered by company
- [ ] PODs are scoped to company
- [ ] Claims are scoped to company

### **Authentication Tests**

- [ ] Unauthenticated users cannot access any data
- [ ] Deactivated users cannot access any data
- [ ] Users cannot create companies directly
- [ ] Users cannot access company codes

### **Authorization Tests**

- [ ] Drivers cannot access admin-only functions
- [ ] Drivers cannot manage users
- [ ] Drivers cannot change company settings
- [ ] Users cannot change their own role
- [ ] Users cannot change their own companyId
- [ ] Users cannot update other users' documents

### **Input Validation Tests**

- [ ] Invalid emails are rejected
- [ ] Strings exceeding max length are rejected
- [ ] Invalid roles are rejected (only 'admin' or 'driver')
- [ ] Required fields are enforced
- [ ] Invalid status values are rejected

### **Cloud Functions Tests**

- [ ] createCompany works correctly
- [ ] inviteUser works correctly
- [ ] deactivateUser works correctly
- [ ] reactivateUser works correctly
- [ ] Only admins can invite users
- [ ] Users are created in correct company

---

## 🔄 ROLLBACK PROCEDURE

If issues arise after deployment:

### **Quick Rollback (Local)**

```powershell
# Find backup
cd security_rules_backups

# Restore (replace with your timestamp)
Copy-Item "firestore.rules.backup.20251118_143025" "../firestore.rules" -Force
Copy-Item "storage.rules.backup.20251118_143025" "../storage.rules" -Force

# Deploy old rules
firebase deploy --only firestore:rules,storage
```

### **Emergency Rollback (Firebase Console)**

1. Go to Firebase Console
2. Navigate to Firestore → Rules
3. Click "View previous versions"
4. Select last working version
5. Click "Publish"

---

## 📈 MONITORING & ALERTS

### **What to Monitor**

1. **Rule Violations** (Firebase Console → Firestore → Rules)
   - Watch for denied read/write attempts
   - Investigate unusual patterns

2. **Authentication Failures**
   - Track failed login attempts
   - Monitor deactivated user access attempts

3. **Cloud Function Errors**
   - createCompany failures
   - inviteUser failures
   - Permission denied errors

4. **Cross-Company Access Attempts**
   - Any errors mentioning "not same company"
   - Multiple failed read attempts

### **Alert Thresholds**

- **Critical:** >10 rule violations per hour
- **Warning:** >5 permission denied errors per hour
- **Info:** Any super admin action (company creation)

---

## 🐛 KNOWN LIMITATIONS

1. **Legacy Collections**
   - `drivers/`, `pods/`, `claims/` at root level still exist
   - Should migrate to company-scoped: `companies/{id}/drivers/`
   - Current rules provide basic protection

2. **External Tokens**
   - Third-party upload tokens are publicly readable (by design)
   - Consider moving validation to Cloud Functions for tighter control

3. **Performance**
   - Each rule checks user document (cached by Firebase)
   - High-volume apps may need caching strategy

---

## 📚 ADDITIONAL RESOURCES

- **Firestore Security Rules Docs:** https://firebase.google.com/docs/firestore/security/get-started
- **Storage Security Rules Docs:** https://firebase.google.com/docs/storage/security
- **Cloud Functions Docs:** https://firebase.google.com/docs/functions
- **Testing Rules:** https://firebase.google.com/docs/firestore/security/test-rules-emulator

---

## ✅ POST-DEPLOYMENT CHECKLIST

- [ ] Backup rules deployed
- [ ] Secure rules tested in staging
- [ ] Secure rules deployed to production
- [ ] Cloud Functions deployed
- [ ] First company created successfully
- [ ] First user invited successfully
- [ ] Multi-tenant isolation verified
- [ ] Role-based access verified
- [ ] Monitoring enabled
- [ ] Alert thresholds configured
- [ ] Team trained on new user management process
- [ ] Documentation updated
- [ ] Rollback procedure tested

---

## 🎯 NEXT STEPS

1. **Test in Staging** (2-4 hours)
   - Create test company
   - Invite test users
   - Verify isolation
   - Test all user flows

2. **Deploy to Production** (30 min)
   - Run deployment script
   - Verify rules active
   - Create first client company

3. **Monitor** (first 48 hours)
   - Watch for rule violations
   - Investigate any denied requests
   - Address issues quickly

4. **Iterate** (ongoing)
   - Collect feedback
   - Refine rules as needed
   - Add additional validation
   - Enhance monitoring

---

**Questions? Issues?**  
Review logs in Firebase Console or check `security_rules_backups/` for rollback options.
