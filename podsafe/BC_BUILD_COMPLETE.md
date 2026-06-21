# ✅ Business Central Integration - Deployment Status

## Build Status: ✅ COMPLETE

```
✅ TypeScript compiled successfully
✅ lib/ directory created with all modules
✅ Firebase configuration set (placeholders)
✅ .env file created for future migration
```

---

## Next Steps to Deploy

### 1. ⚠️ Create Azure AD Multi-Tenant App

**You need to do this FIRST before deployment will work:**

1. Go to https://portal.azure.com
2. Navigate to **Azure Active Directory** → **App registrations** → **New registration**
3. Fill in:
   - **Name**: `PODSafe BC Integration`
   - **Supported account types**: ✅ **Accounts in any organizational directory (Any Azure AD directory - Multitenant)**
   - **Redirect URI**: 
     - Platform: `Web`
     - URL: `https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback`
4. Click **Register**
5. On the app page:
   - **Copy the Application (client) ID** ← You need this
   - Go to **Certificates & secrets** → **New client secret**
     - Description: `PODSafe Integration Secret`
     - Expires: `24 months`
     - Click **Add**
     - **⚠️ COPY THE SECRET VALUE NOW** (you can't see it again!)
6. Go to **API permissions** → **Add a permission** → **Dynamics 365 Business Central**
   - Select **Delegated permissions**:
     - ✅ `Financials.ReadWrite.All`
     - ✅ `user_impersonation`
   - Click **Add permissions**

### 2. 🔧 Update Firebase Configuration

**Replace the placeholders with your real Azure AD credentials:**

```powershell
firebase functions:config:set `
  bc.client_id="<PASTE_YOUR_CLIENT_ID_HERE>" `
  bc.client_secret="<PASTE_YOUR_SECRET_VALUE_HERE>"
```

**Verify:**
```powershell
firebase functions:config:get
```

### 3. 🚀 Deploy to Firebase

```powershell
firebase deploy --only functions:bcOAuthRedirect,functions:bcOAuthCallback,functions:bcPullShipments,functions:bcPushPod,functions:bcScheduledPull,functions:bcAutoPushPod,functions:bcHealth
```

**Or deploy all functions:**
```powershell
npm run deploy
```

### 4. ✅ Test the Integration

Once deployed, test the OAuth flow:

1. In your browser, go to:
   ```
   https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthRedirect?companyId=TEST_COMPANY
   ```

2. You should see Microsoft login page
3. Sign in with your Business Central trial account
4. Grant permissions
5. Should see success page with company list

6. Check Firestore:
   ```
   companies/TEST_COMPANY/integrations/businessCentral
   ```
   Should have the BC configuration saved

### 5. 🧪 Test Pull Shipments

```powershell
$body = @{
    companyId = "TEST_COMPANY"
    limit = 10
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://us-central1-podsafe-92a3e.cloudfunctions.net/bcPullShipments" `
  -Method POST `
  -Body $body `
  -ContentType "application/json"
```

---

## Current Configuration

**Firebase Functions Config (with placeholders):**
```
bc.oauth_authority = "https://login.microsoftonline.com/common"
bc.client_id = "PLACEHOLDER" ← UPDATE THIS
bc.client_secret = "PLACEHOLDER" ← UPDATE THIS
bc.redirect_uri = "https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback"
bc.scope = "https://api.businesscentral.dynamics.com/.default offline_access"
```

**⚠️ IMPORTANT:** The functions will NOT work until you replace the placeholders with real Azure AD credentials!

---

## Troubleshooting

### "Missing required configuration" error
**Fix:** Update Firebase config with real Azure AD credentials (see step 2 above)

### "AADSTS700016: Application not found"
**Fix:** Check that your Azure AD app Client ID is correct in Firebase config

### "CORS error" when testing
**Fix:** Make sure you're calling the deployed Firebase function URLs, not localhost

### Deployment fails
**Fix:** Make sure you're in the `functions/` directory and run `npm run build` first

---

## Files Created

✅ `functions/src/` - All TypeScript source files  
✅ `functions/lib/` - Compiled JavaScript (ready for deployment)  
✅ `functions/.env` - Environment template (for future migration)  
✅ `BC_DEPLOYMENT_GUIDE.md` - Complete deployment docs  
✅ `BC_INTEGRATION_README.md` - Technical documentation  

---

## Ready to Deploy?

**Checklist:**
- [ ] Azure AD multi-tenant app created
- [ ] Client ID and Secret copied
- [ ] Firebase config updated with real credentials
- [ ] Functions deployed
- [ ] OAuth flow tested
- [ ] Pull shipments tested

**Once complete, any customer can connect their Business Central instance to PODSafe!** 🎉
