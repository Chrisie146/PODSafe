# Business Central Integration - Deployment Guide

## Prerequisites

1. ✅ Azure AD Multi-Tenant App created
2. ✅ API permissions configured (Financials.ReadWrite.All)
3. ✅ Client ID and Secret obtained
4. ✅ Node.js 18+ installed
5. ✅ Firebase CLI installed (`npm install -g firebase-tools`)

## Step 1: Install Dependencies

```bash
cd functions
npm install
```

## Step 2: Build TypeScript

```bash
npm run build
```

**Output:** Compiled JavaScript in `functions/lib/` directory

## Step 3: Configure Environment Variables

Set Firebase Functions configuration with your Azure AD app credentials:

```bash
firebase functions:config:set \
  bc.oauth_authority="https://login.microsoftonline.com/common" \
  bc.client_id="YOUR_AZURE_APP_CLIENT_ID" \
  bc.client_secret="YOUR_AZURE_APP_SECRET" \
  bc.redirect_uri="https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback" \
  bc.scope="https://api.businesscentral.dynamics.com/.default offline_access"
```

**Important:** Replace `YOUR_AZURE_APP_CLIENT_ID` and `YOUR_AZURE_APP_SECRET` with actual values!

**Verify configuration:**
```bash
firebase functions:config:get
```

## Step 4: Deploy Functions

### Deploy All BC Functions

```bash
npm run deploy
```

### Or Deploy Individually

```bash
# OAuth endpoints (required for connection)
firebase deploy --only functions:bcOAuthRedirect
firebase deploy --only functions:bcOAuthCallback

# Data sync endpoints
firebase deploy --only functions:bcPullShipments
firebase deploy --only functions:bcPushPod

# Optional: Scheduled pull
firebase deploy --only functions:bcScheduledPull

# Optional: Auto-push trigger
firebase deploy --only functions:bcAutoPushPod

# Health check
firebase deploy --only functions:bcHealth
```

## Step 5: Test the Integration

### Test OAuth Flow

1. Get a test company ID from Firestore
2. Open in browser:
   ```
   https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthRedirect?companyId=TEST_COMPANY_ID
   ```
3. Sign in with Microsoft account that has BC access
4. Grant permissions
5. Should see success page
6. Check Firestore: `companies/{companyId}/integrations/businessCentral` should exist

### Test Pull Shipments

```bash
curl -X POST https://us-central1-podsafe-92a3e.cloudfunctions.net/bcPullShipments \
  -H "Content-Type: application/json" \
  -d '{
    "companyId": "TEST_COMPANY_ID",
    "since": "2025-10-01T00:00:00Z",
    "limit": 10
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "created": 5,
  "updated": 0,
  "skipped": 0,
  "errors": []
}
```

### Test Push POD

```bash
curl -X POST https://us-central1-podsafe-92a3e.cloudfunctions.net/bcPushPod \
  -H "Content-Type: application/json" \
  -d '{
    "companyId": "TEST_COMPANY_ID",
    "sourceId": "BC_SHIPMENT_GUID",
    "status": "DELIVERED",
    "pod": {
      "completedAt": "2025-10-26T14:30:00Z",
      "gpsLat": 47.6062,
      "gpsLng": -122.3321,
      "note": "Delivered to reception"
    }
  }'
```

### Test Health Check

```bash
curl https://us-central1-podsafe-92a3e.cloudfunctions.net/bcHealth
```

## Step 6: Monitor Deployment

### View Logs

```bash
firebase functions:log
```

**Or in Firebase Console:**
- Go to Functions tab
- Click on a function name
- View Logs tab

### Check Function Status

```bash
firebase functions:list
```

**Should show:**
- ✅ bcOAuthRedirect
- ✅ bcOAuthCallback
- ✅ bcPullShipments
- ✅ bcPushPod
- ✅ bcScheduledPull
- ✅ bcAutoPushPod
- ✅ bcHealth

## Troubleshooting

### "Cannot find module './lib/index'"

**Cause:** TypeScript not compiled

**Solution:**
```bash
cd functions
npm run build
```

### "Missing required configuration"

**Cause:** Environment variables not set

**Solution:**
```bash
firebase functions:config:set bc.client_id="..." bc.client_secret="..."
```

### "CORS error" when calling functions

**Cause:** Browser blocking cross-origin requests

**Solution:** The functions include CORS headers. If still blocked, ensure you're calling the correct deployed URLs (not localhost).

### Build errors

**Check TypeScript compilation:**
```bash
cd functions
npm run build
```

**Fix import errors:** Ensure all paths use relative imports (`../` syntax)

## Rollback

### Rollback All Functions

```bash
firebase functions:delete bcOAuthRedirect bcOAuthCallback bcPullShipments bcPushPod bcScheduledPull bcAutoPushPod bcHealth
```

### Rollback Single Function

```bash
firebase functions:delete bcOAuthRedirect
```

## Next Steps

1. ✅ Functions deployed
2. ⏳ Test OAuth connection with real BC account
3. ⏳ Update Admin UI with "Connect to BC" button
4. ⏳ Configure scheduled pull (if needed)
5. ⏳ Set up monitoring/alerts
6. ⏳ Migrate to Secret Manager (production)

## Production Checklist

Before going live:

- [ ] Azure AD app verified by Microsoft
- [ ] Client secret expiration set (24 months)
- [ ] Firebase Functions upgraded to Blaze plan (if needed)
- [ ] Monitoring/alerts configured
- [ ] Error handling tested
- [ ] Token refresh tested (wait 1 hour, test API call)
- [ ] Multiple customer connections tested
- [ ] Scheduled pull enabled and tested
- [ ] Auto-push trigger tested
- [ ] Backup strategy defined
- [ ] Security audit completed
- [ ] Documentation updated

## Support

**Documentation:**
- Main README: `functions/BC_INTEGRATION_README.md`
- Summary: `BC_MULTITENANT_OAUTH_SUMMARY.md`
- Testing: `BC_TESTING_GUIDE.md`

**Logs:**
```bash
firebase functions:log --only bcOAuthCallback
firebase functions:log --only bcPullShipments
```

**Firebase Console:**
https://console.firebase.google.com/project/podsafe-92a3e/functions

---

**Last Updated:** October 26, 2025  
**Version:** 1.0.0 - Multi-Tenant OAuth Integration
