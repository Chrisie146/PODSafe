# 🧪 Security Testing Quick Start

## Setup Instructions

### 1. Install Dependencies
```bash
npm install
```

### 2. Get Firebase Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Save as `service-account-key.json` in the project root
6. **Never commit this file to Git!**

### 3. Create Test Data
```bash
npm run setup:test-data
```

This creates:
- 2 test companies (Alpha, Beta)
- 3 test users (2 admins, 1 driver)
- Sample delivery and claim

### 4. Run Automated Tests
```bash
npm run test:security
```

This runs automated validation using Admin SDK (limited security rule testing).

### 5. Run Manual Tests
Follow the comprehensive guide: **[SECURITY_MANUAL_TEST_GUIDE.md](./SECURITY_MANUAL_TEST_GUIDE.md)**

Manual testing is **CRITICAL** because:
- Admin SDK bypasses security rules
- Client SDK with user auth is needed for real testing
- Must verify multi-tenant isolation with actual users

---

## Test Credentials

After running `npm run setup:test-data`, use these credentials:

**Company Alpha Admin:**
- Email: `admin.alpha@test.com`
- Password: `TestPass123!`

**Company Alpha Driver:**
- Email: `driver.alpha@test.com`
- Password: `TestPass123!`

**Company Beta Admin:**
- Email: `admin.beta@test.com`
- Password: `TestPass123!`

---

## What Gets Tested

### ✅ Automated Tests (Admin SDK)
- Test data creation
- Data structure validation
- Basic field presence checks
- Company/user relationships

### ✅ Manual Tests (Client SDK - Required!)
- **Multi-tenant isolation** - Cross-company access blocked
- **Role-based access** - Drivers can't do admin tasks
- **Privilege escalation** - Users can't change their role
- **Company switching** - Users can't change companyId
- **Deactivated users** - No access when isActive=false
- **Company creation** - Only via Cloud Functions
- **Storage rules** - File upload restrictions

---

## Success Criteria

All manual tests must pass before production deployment:
- ✅ No cross-company data access
- ✅ Role restrictions enforced
- ✅ No self-privilege escalation
- ✅ Deactivated users fully blocked
- ✅ Company creation locked down

---

## Cleanup

Remove test data after testing:
```bash
node test_security_rules.js
# Choose cleanup option when prompted
```

Or use Firebase Console to manually delete:
- Users with `@test.com` emails
- Companies with "Test Company" names

---

## Important Notes

⚠️ **Admin SDK Limitation:**  
The automated test script uses Firebase Admin SDK which **bypasses all security rules**. It's useful for setup and data validation but cannot fully test security.

✅ **Client SDK Required:**  
Real security testing must use Firebase Client SDK with actual user authentication. Follow the manual test guide!

🔐 **Production Safety:**  
Never deploy until all manual security tests pass. Multi-tenant isolation is critical!
