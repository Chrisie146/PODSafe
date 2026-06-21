# Azure AD Multi-Tenant App Setup - Step by Step

## Current Step: Redirect URI Configuration

Based on your screenshot, you're creating the app registration. Here's what to do:

### Step 1: Redirect URI (You are here! ✅)

1. **Select platform**: Click **Web** (from the dropdown or the Web option)
2. **Enter Redirect URI**: 
   ```
   https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback
   ```
3. Click **Register** button at the bottom

---

### Step 2: Copy Application (Client) ID

After clicking Register, you'll see the app overview page:

1. On the **Overview** page, you'll see **Application (client) ID**
2. **Copy this value** - it looks like: `12345678-1234-1234-1234-123456789abc`
3. **Save it somewhere safe** (Notepad, etc.) - you'll need it soon

📝 **Write it here temporarily:**
```
Client ID: _________________________________
```

---

### Step 3: Create Client Secret

1. In the left menu, click **Certificates & secrets**
2. Click **+ New client secret**
3. In the panel that opens:
   - **Description**: `PODSafe Integration Secret`
   - **Expires**: Select **24 months** (recommended)
4. Click **Add**
5. **⚠️ CRITICAL**: The secret **Value** will appear - **COPY IT NOW!**
   - You can NEVER see this value again after you navigate away
   - It looks like: `abc123XYZ~._def456-GHI789`

📝 **Write it here temporarily:**
```
Client Secret: _________________________________
```

---

### Step 4: Configure API Permissions

1. In the left menu, click **API permissions**
2. Click **+ Add a permission**
3. In the panel that opens:
   - Scroll down and select **Dynamics 365 Business Central**
   - Click **Delegated permissions** (NOT Application permissions)
   - Check these boxes:
     - ✅ **Financials.ReadWrite.All**
     - ✅ **user_impersonation**
   - Click **Add permissions** at the bottom

4. You'll see the permissions added. You should see:
   ```
   API / Permission name                    Type        Status
   Dynamics 365 Business Central           
   - Financials.ReadWrite.All              Delegated   Not granted
   - user_impersonation                    Delegated   Not granted
   ```

5. **Note**: "Not granted" is OK for multi-tenant apps. Users will grant consent when they connect.

---

### Step 5: Verify Multi-Tenant Configuration

1. In the left menu, click **Authentication**
2. Under **Supported account types**, verify it says:
   ```
   ✅ Accounts in any organizational directory (Any Azure AD directory - Multitenant)
   ```
3. Under **Redirect URIs**, verify you see:
   ```
   Web: https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback
   ```

---

### Step 6: Update Firebase Configuration

Now that you have your Client ID and Secret, update Firebase:

**Open PowerShell in the functions directory and run:**

```powershell
firebase functions:config:set `
  bc.client_id="PASTE_YOUR_CLIENT_ID_HERE" `
  bc.client_secret="PASTE_YOUR_SECRET_HERE"
```

**Example (with fake values):**
```powershell
firebase functions:config:set `
  bc.client_id="12345678-1234-1234-1234-123456789abc" `
  bc.client_secret="abc123XYZ~._def456-GHI789"
```

**Verify the configuration:**
```powershell
firebase functions:config:get
```

You should see:
```json
{
  "bc": {
    "oauth_authority": "https://login.microsoftonline.com/common",
    "client_id": "YOUR_REAL_CLIENT_ID",
    "client_secret": "YOUR_REAL_SECRET",
    "redirect_uri": "https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback",
    "scope": "https://api.businesscentral.dynamics.com/.default offline_access"
  }
}
```

---

### Step 7: Deploy to Firebase

**Still in the functions directory, run:**

```powershell
npm run deploy
```

This will:
1. Build TypeScript (`npm run build`)
2. Deploy all Cloud Functions to Firebase

**Expected output:**
```
✔  functions[bcOAuthRedirect(us-central1)] Successful create operation.
✔  functions[bcOAuthCallback(us-central1)] Successful create operation.
✔  functions[bcPullShipments(us-central1)] Successful create operation.
✔  functions[bcPushPod(us-central1)] Successful create operation.
✔  functions[bcScheduledPull(us-central1)] Successful create operation.
✔  functions[bcAutoPushPod(us-central1)] Successful create operation.
✔  functions[bcHealth(us-central1)] Successful create operation.
```

---

### Step 8: Test OAuth Connection

1. **Create a test company ID** in Firestore (or use existing):
   - Collection: `companies`
   - Document ID: `TEST_COMPANY`

2. **Open in your browser:**
   ```
   https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthRedirect?companyId=TEST_COMPANY
   ```

3. **You should see:**
   - Microsoft login page
   - Sign in with your Business Central account
   - Consent screen asking for permissions
   - Success page showing discovered BC companies

4. **Check Firestore:**
   - Navigate to: `companies/TEST_COMPANY/integrations/businessCentral`
   - You should see a document with:
     ```
     {
       "bcEnvironment": "...",
       "bcCompanyId": "...",
       "connectedAt": "...",
       "isActive": true
     }
     ```

---

### Step 9: Test Data Pull

**In PowerShell, test pulling shipments:**

```powershell
$body = @{
    companyId = "TEST_COMPANY"
    limit = 10
} | ConvertTo-Json

Invoke-WebRequest `
  -Uri "https://us-central1-podsafe-92a3e.cloudfunctions.net/bcPullShipments" `
  -Method POST `
  -Body $body `
  -ContentType "application/json"
```

**Expected response:**
```json
{
  "success": true,
  "created": 5,
  "updated": 0,
  "skipped": 0,
  "errors": []
}
```

---

## Quick Reference

### Your Azure AD App Credentials

**After completing Steps 1-4, fill this in:**

```
Application (client) ID: _________________________________

Client Secret: _________________________________

Tenant: common (multi-tenant)

Redirect URI: https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback

API Permissions:
  ✅ Dynamics 365 Business Central - Financials.ReadWrite.All (Delegated)
  ✅ Dynamics 365 Business Central - user_impersonation (Delegated)
```

### Firebase Commands Checklist

```powershell
# 1. Set configuration (replace with real values)
firebase functions:config:set bc.client_id="..." bc.client_secret="..."

# 2. Verify configuration
firebase functions:config:get

# 3. Deploy functions
npm run deploy

# 4. View logs (after testing)
firebase functions:log
```

---

## Troubleshooting

### "Invalid redirect URI" error during login
- **Fix**: Go back to Azure AD → Authentication → Add the exact URL

### "AADSTS700016: Application not found"
- **Fix**: Check the Client ID is correct in Firebase config

### "Permissions not granted" error
- **Fix**: For multi-tenant, users grant consent during login - this is normal

### Can't see Client Secret
- **Fix**: Create a new secret (Certificates & secrets → New client secret)

---

## Next Steps After Successful Test

1. ✅ Update Admin Dashboard in Flutter app to add "Connect to Business Central" button
2. ✅ Style the OAuth callback success page
3. ✅ Add error handling for failed connections
4. ✅ Configure scheduled pull (daily sync)
5. ✅ Test with real Business Central data
6. ✅ Set up monitoring/alerts

---

**You're currently at Step 1. Complete the redirect URI form and click Register!** 🚀
