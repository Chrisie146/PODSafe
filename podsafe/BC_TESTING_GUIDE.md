# Business Central Integration - Testing Guide

## Quick Start

### 1. Prerequisites

Before testing BC integration, you need:

**Azure AD App Registration:**
- Tenant ID (GUID from Azure AD)
- Client ID (Application/Client ID)
- Client Secret (Generate in Azure AD → Certificates & Secrets)
- API Permissions: `Dynamics 365 Business Central` → `API.ReadWrite.All`

**Business Central Instance:**
- BC API URL (e.g., `https://api.businesscentral.dynamics.com/v2.0/<tenant-id>/<environment>`)
- Environment name (e.g., `production` or `sandbox`)

### 2. Testing on Web (Chrome)

```bash
flutter run -d chrome
```

**Steps:**
1. Login as admin user
2. Navigate to **Admin Dashboard**
3. Click **"BC Integration"** button
4. Fill in the form:
   - **Tenant ID**: Your Azure AD tenant ID
   - **Environment**: `production` or `sandbox`
   - **BC Company ID**: Leave blank for now (optional)
   - **Client ID**: Your Azure app client ID
   - **Client Secret**: Your Azure app client secret
   - **BC API URL**: Full BC API endpoint
5. Click **"Test Connection"**
6. Wait for result (15-30 seconds)

**Expected Success:**
```
✓ Connection successful!

Your Business Central credentials are valid and the API is accessible.
```

**Expected on Failure:**
```
✗ Connection failed

Please check:
• Tenant ID is correct
• Client ID is correct  
• Client Secret is correct
• BC API URL is correct
• Azure AD app has BC API permissions
```

### 3. Common Errors

#### Error: `INTERNAL`
**Cause:** Missing or invalid BC configuration in Firestore

**Solution:** Make sure you filled in all required fields:
- Tenant ID
- Client ID
- Client Secret
- BC API URL

The configuration is now automatically saved to Firestore when you click "Test Connection".

#### Error: `invalid_client`
**Cause:** Incorrect Client ID or Client Secret

**Solution:**
1. Go to Azure Portal → Azure Active Directory → App Registrations
2. Find your app
3. Copy the **Application (client) ID** exactly
4. Generate a new Client Secret in **Certificates & secrets**
5. Copy the secret **value** (not the secret ID)

#### Error: `unauthorized_client`
**Cause:** Azure AD app doesn't have permission to access BC API

**Solution:**
1. Azure Portal → App Registrations → Your App
2. Click **API permissions**
3. Click **Add a permission**
4. Select **Dynamics 365 Business Central**
5. Select **Delegated permissions** → `API.ReadWrite.All`
6. Click **Grant admin consent**

#### Error: `Resource not found`
**Cause:** Incorrect BC API URL or Environment

**Solution:**
- Verify the BC API URL format:
  - **SaaS:** `https://api.businesscentral.dynamics.com/v2.0`
  - **On-Premises:** `https://your-server:port/BC/api/v2.0`
- Check environment name matches exactly (case-sensitive)

### 4. Checking Firestore

**Config Location:**
```
companies/{companyId}/integrations/businessCentral
```

**Expected Document:**
```json
{
  "tenantId": "abc-123-def-456",
  "environment": "production",
  "clientId": "client-id-here",
  "bcApiUrl": "https://api.businesscentral.dynamics.com/v2.0",
  "isEnabled": false,
  "syncIntervalMinutes": 15,
  "autoCreateDeliveries": false,
  "autoAttachPODs": true,
  "updatedAt": "2025-10-26T..."
}
```

**Note:** `clientSecret` is **never** stored in Firestore for security reasons.

### 5. Checking Cloud Function Logs

**Firebase Console:**
https://console.firebase.google.com/project/podsafe-92a3e/functions

**Functions to Monitor:**
- `bcAuthenticate` - OAuth to Microsoft
- `bcApiCall` - API requests to BC
- `bcTestConnection` - Connection test

**Via CLI:**
```bash
firebase functions:log
```

**Expected Log Output (Success):**
```
BC Test Connection - companyId: qvQjSLKxgDl3dz51sLDA
Step 1: Authenticating...
Step 2: Authentication successful, testing API access...
Step 3: API call successful, found 3 companies
```

**Expected Log Output (Failure):**
```
BC Test Connection - companyId: qvQjSLKxgDl3dz51sLDA
Step 1: Authenticating...
BC Authentication Error: { error: 'invalid_client', error_description: '...' }
Connection Test Error: Auth failed: ...
```

### 6. Testing Flow

The test connection flow:

```
User clicks "Test Connection"
    ↓
Flutter validates form
    ↓
Flutter saves config to Firestore
    ↓
Flutter calls bcTestConnection Cloud Function
    ↓
Cloud Function reads config from Firestore
    ↓
Cloud Function calls bcAuthenticate
    ↓
bcAuthenticate requests OAuth token from Microsoft
    ↓
Microsoft validates credentials
    ↓
Microsoft returns access token
    ↓
bcTestConnection calls bcApiCall
    ↓
bcApiCall fetches companies list from BC API
    ↓
Returns success + company count to Flutter
    ↓
Flutter displays result to user
```

### 7. Security Notes

✅ **Client Secret Protection:**
- Never stored in Firestore
- Only passed directly to Cloud Functions
- Cloud Functions run server-side (secure)
- Not exposed to browser JavaScript

✅ **Access Token Handling:**
- Tokens cached in Flutter Secure Storage
- Expire after 1 hour
- Automatically refreshed when needed
- Not persisted to Firestore

✅ **CORS Bypass:**
- Direct OAuth from browser = CORS error ❌
- Cloud Functions OAuth = No CORS ✅
- Works on all platforms (web, desktop, mobile)

### 8. Sample Configuration

**For Testing (Sandbox):**
```
Tenant ID: 12345678-1234-1234-1234-123456789012
Environment: sandbox
Client ID: 87654321-4321-4321-4321-210987654321
Client Secret: abc~123~xyz~456~def
BC API URL: https://api.businesscentral.dynamics.com/v2.0
```

**For Production:**
```
Tenant ID: [Your Azure AD Tenant ID]
Environment: production
Client ID: [Your Azure App Client ID]
Client Secret: [Your Azure App Secret Value]
BC API URL: https://api.businesscentral.dynamics.com/v2.0
```

### 9. Troubleshooting Checklist

Before asking for help, verify:

- [ ] You have a valid Azure AD app registration
- [ ] App has Dynamics 365 Business Central API permissions
- [ ] Admin consent granted for API permissions
- [ ] Client secret is not expired (check Azure Portal)
- [ ] Tenant ID is a valid GUID format
- [ ] BC API URL ends with `/v2.0` (no trailing slash)
- [ ] Environment name matches exactly (case-sensitive)
- [ ] You're logged in as an admin user
- [ ] CompanyId exists in Firestore
- [ ] Firestore rules allow access to integrations collection
- [ ] Cloud Functions deployed successfully
- [ ] Internet connection stable

### 10. Next Steps After Successful Test

Once connection test passes:

1. **Save Configuration**
   - Click "Save Configuration" button
   - Enable integration toggle

2. **Sync Customers** (Phase 2)
   - Navigate to customer sync section
   - Click "Sync Now"
   - Review imported customers

3. **Import Sales Orders** (Phase 3)
   - Set up order import schedule
   - Configure field mappings
   - Test manual import

4. **Enable Real-Time Updates** (Phase 4)
   - Delivery status → BC updates
   - Proof of delivery → BC attachments
   - Driver info → BC fields

---

**Need Help?**
- Check Firebase Console logs
- Review BC_CLOUD_FUNCTIONS_COMPLETE.md
- Verify Azure AD app configuration
- Test credentials in Postman first

**Last Updated:** October 26, 2025
**Status:** Cloud Functions deployed and ready
