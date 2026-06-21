# 🔧 Azure AD Configuration - Troubleshooting

## Error: "Application with identifier was not found in the directory"

This means Azure AD doesn't recognize your app. Let's fix it.

### ✅ Checklist - Verify Your Azure AD App

**Go to:** https://portal.azure.com → Azure Active Directory → App registrations

1. **Find your app:**
   - Search for "PODSafe BC Integration" (or whatever you named it)
   - Click on it

2. **On the Overview page, verify:**

   - ✅ **Application (client) ID:** Should be `1ca87a00-5e75-4e5c-90ba-6c264a5471f3`
   - ✅ **Supported account types:** Must say "Accounts in any organizational directory (Any Azure AD directory - Multitenant)"
     - If it says "Only this organization" → You created it wrong!
     - Fix: Go to **Settings → Properties** and check "Multitenant"

3. **Check Redirect URI:**
   - Go to **Authentication** section
   - Under "Redirect URIs" for Web platform
   - Should have EXACTLY: `https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback`
   - If missing, add it now

4. **Check API Permissions:**
   - Go to **API permissions**
   - Should show:
     - ✅ Dynamics 365 Business Central - Financials.ReadWrite.All (Delegated)
     - ✅ Dynamics 365 Business Central - user_impersonation (Delegated)

---

### 🔴 Most Likely Issue: App Not Multi-Tenant

**If your app says "Accounts in this organizational directory only":**

1. Click **Properties** (in left menu)
2. Scroll to **Multitenant** setting
3. Toggle it **ON** ✅
4. Click **Save**

This is the most common cause!

---

### 📝 Option: Create New Multi-Tenant App (If Above Doesn't Work)

If the app is messed up, create a fresh one:

1. **Azure Portal → App registrations → New registration**
2. **Name:** PODSafe BC Integration (v2)
3. **Supported account types:** ✅✅✅ Click "Accounts in any organizational directory (Any Azure AD directory - Multitenant)"
4. **Redirect URI - Platform:** Web
5. **Redirect URI - URL:** `https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback`
6. Click **Register**

7. **Copy the new Application (client) ID**

8. **Certificates & secrets → New client secret**
   - Description: PODSafe Integration Secret
   - Expires: 24 months
   - Click Add
   - COPY THE VALUE

9. **API permissions → Add permission → Dynamics 365 Business Central**
   - Delegated: Financials.ReadWrite.All, user_impersonation

10. **Update Firebase config:**
    ```powershell
    firebase functions:config:set `
      bc.client_id="NEW_CLIENT_ID_HERE" `
      bc.client_secret="NEW_SECRET_HERE"
    ```

11. **Redeploy:**
    ```powershell
    npm run deploy
    ```

12. **Test again**

---

## Quick Verification Command

To verify your current config is set correctly:

```powershell
firebase functions:config:get
```

Should show `"client_id": "1ca87a00-5e75-4e5c-90ba-6c264a5471f3"`

---

## After Fixing

Once fixed, try again:
```
https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthRedirect?companyId=TEST_BC_COMPANY
```

You should see Microsoft login (not an error).

---

**The issue is 99% likely that your app isn't set to Multitenant. Check that first!**
