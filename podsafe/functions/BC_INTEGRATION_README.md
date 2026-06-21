# Business Central Multi-Tenant OAuth Integration

Production-ready integration between PODSafe and Microsoft Dynamics 365 Business Central using multi-tenant OAuth 2.0.

## Features

✅ **Multi-Tenant Architecture** - Single Azure app, any customer can connect  
✅ **Automatic Token Refresh** - Handles expired tokens transparently  
✅ **Retry Logic** - Exponential backoff on 429/5xx errors  
✅ **Idempotent Sync** - Uses etag to avoid duplicate updates  
✅ **Type-Safe** - Full TypeScript coverage  
✅ **Scalable** - Cloud Functions auto-scale per customer  

## Quick Start

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure Environment

Set Firebase Functions configuration:

```bash
firebase functions:config:set \
  bc.oauth_authority="https://login.microsoftonline.com/common" \
  bc.client_id="YOUR_AZURE_APP_CLIENT_ID" \
  bc.client_secret="YOUR_AZURE_APP_SECRET" \
  bc.redirect_uri="https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback" \
  bc.scope="https://api.businesscentral.dynamics.com/.default offline_access"
```

### 3. Build TypeScript

```bash
npm run build
```

### 4. Deploy to Firebase

```bash
npm run deploy
```

Or deploy individual functions:

```bash
firebase deploy --only functions:bcOAuthRedirect
firebase deploy --only functions:bcOAuthCallback
firebase deploy --only functions:bcPullShipments
firebase deploy --only functions:bcPushPod
```

### 5. Test Locally

```bash
npm run serve
```

Then open: `http://localhost:5001/podsafe-92a3e/us-central1/bcOAuthRedirect?companyId=TEST_COMPANY_ID`

## Azure AD App Setup

### 1. Create Multi-Tenant App

1. Azure Portal → Azure Active Directory → App registrations → **New registration**
2. Name: `PODSafe BC Integration`
3. Supported account types: **Accounts in any organizational directory (Multi-tenant)**
4. Redirect URI (Web): `https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback`
5. Click **Register**

### 2. Add API Permissions

1. Go to **API permissions**
2. Click **Add a permission**
3. Select **Dynamics 365 Business Central**
4. Choose **Delegated permissions**:
   - ✅ `Financials.ReadWrite.All`
   - ✅ `user_impersonation`
5. Click **Add permissions**

**Note**: No admin consent needed! Users consent when they connect.

### 3. Generate Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Description: `PODSafe Production`
4. Expires: 24 months
5. Click **Add**
6. **Copy the VALUE** (not the ID) immediately - you can't see it again!

### 4. Note the Client ID

1. Go to **Overview**
2. Copy **Application (client) ID**

## API Endpoints

### OAuth Flow

#### Initiate Connection
```
GET /bcOAuthRedirect?companyId={companyId}&redirectTo={url}
```

**Parameters:**
- `companyId` (required): PODSafe company ID
- `redirectTo` (optional): URL to redirect after successful connection

**Response:** Redirects to Microsoft login

#### OAuth Callback
```
GET /bcOAuthCallback?code={code}&state={state}
```

Automatically called by Microsoft after user grants consent.

**Response:** HTML success page or error page

### Data Sync

#### Pull Shipments
```
POST /bcPullShipments
Content-Type: application/json

{
  "companyId": "podsafe-company-id",
  "since": "2025-10-01T00:00:00Z",  // Optional
  "limit": 100                       // Optional, default 100
}
```

**Response:**
```json
{
  "success": true,
  "created": 5,
  "updated": 3,
  "skipped": 2,
  "errors": []
}
```

#### Push POD
```
POST /bcPushPod
Content-Type: application/json

{
  "companyId": "podsafe-company-id",
  "sourceId": "bc-shipment-guid",
  "status": "DELIVERED",
  "pod": {
    "completedAt": "2025-10-26T14:30:00Z",
    "gpsLat": 47.6062,
    "gpsLng": -122.3321,
    "note": "Delivered to reception",
    "signature": "base64-encoded-signature"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "POD data pushed successfully"
}
```

#### Health Check
```
GET /bcHealth
```

**Response:**
```json
{
  "status": "healthy",
  "service": "PODSafe Business Central Integration",
  "version": "1.0.0",
  "timestamp": "2025-10-26T10:00:00Z"
}
```

## Scheduled Functions

### Daily Pull (Disabled by Default)

The `bcScheduledPull` function runs daily at 2 AM UTC to pull shipments for all connected companies.

**Enable:**
1. Deploy the function
2. Firebase Console → Functions → bcScheduledPull
3. Click "Enable"

**Disable:**
```bash
firebase functions:delete bcScheduledPull
```

## Automatic POD Push

The `bcAutoPushPod` Firestore trigger automatically pushes POD data when a delivery status changes to:
- `DELIVERED`
- `FAILED`
- `PARTIAL`

**Trigger:** `deliveries/{deliveryId}` document update

## Development

### Build

```bash
npm run build
```

### Watch Mode

```bash
npm run build:watch
```

### Run Tests

```bash
npm test
```

### Run Emulators

```bash
npm run serve
```

Access:
- Functions: http://localhost:5001/podsafe-92a3e/us-central1/
- Firestore UI: http://localhost:4000/firestore

## Firestore Schema

### Integration Config
`companies/{companyId}/integrations/businessCentral`

```typescript
{
  tenantId: string;           // Azure AD tenant ID
  environment: 'Production' | 'Sandbox';
  companyId: string;          // BC company GUID
  companyName: string;
  connectedAt: Timestamp;
  connectedBy: string;        // User ID
  status: 'connected' | 'disconnected' | 'error';
  tokenSecretId: string;      // Reference to _secrets doc
  lastSyncAt?: Timestamp;
  lastError?: string;
}
```

### Delivery Document
`deliveries/{deliveryId}`

```typescript
{
  companyId: string;
  source: 'BusinessCentral';
  sourceId: string;           // BC shipment GUID
  orderNumber: string;
  customer: { id?, name };
  address: { line1, line2?, city, postalCode?, country? };
  scheduledDate: string;      // ISO
  status: DeliveryStatus;
  driverId?: string;
  items: DeliveryItem[];
  sync: {
    source: 'BusinessCentral';
    version?: string;         // @odata.etag
    lastPullAt?: Timestamp;
    lastPushAt?: Timestamp;
    lastPushError?: string;
  };
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### Token Vault
`_secrets/{secretId}`

```typescript
{
  type: 'bc_refresh_token';
  companyId: string;
  value: string;              // Refresh token (TODO: encrypt)
  createdAt: Timestamp;
}
```

## Security

### Current Implementation
✅ Multi-tenant OAuth (users consent per organization)  
✅ Refresh tokens stored separately from main Firestore  
✅ Access tokens cached in memory  
✅ No secrets in logs or responses  
✅ HTTPS-only endpoints  

### Production Improvements Needed
⚠️ Migrate TokenVault to Google Secret Manager  
⚠️ Add Firebase Auth verification on endpoints  
⚠️ Encrypt refresh tokens at rest  
⚠️ Implement rate limiting  
⚠️ Add audit logging  
⚠️ Set up monitoring/alerts  

## Customization

### BC Custom Fields

The push functionality assumes custom fields exist in BC:
- `PODSafe_Status`
- `PODSafe_CompletedAt`
- `PODSafe_DeliveryNote`
- `PODSafe_GPSLatitude`
- `PODSafe_GPSLongitude`
- `PODSafe_SignatureData`

**To customize:**
1. Edit `functions/src/integrations/businessCentral/push.ts`
2. Update `buildBcPodPayload()` function
3. Match your BC table extension field names

### Status Mapping

**To customize status mappings:**
1. Edit `functions/src/util/statusMap.ts`
2. Update `mapBcStatusToPodsafe()` and `mapPodsafeStatusToBc()`

## Troubleshooting

### "BC integration not configured"

**Cause:** Company hasn't connected to BC yet

**Solution:** User must click "Connect to Business Central" in admin UI

### "Failed to refresh access token"

**Cause:** Refresh token expired or revoked

**Solution:** User must reconnect by going through OAuth flow again

### "Document has been modified"

**Cause:** Etag conflict (BC document was updated by another process)

**Solution:** Automatic retry with latest etag (handled by code)

### "No Business Central companies found"

**Cause:** User's BC tenant has no companies, or permissions not granted

**Solution:**
1. Verify user has BC license
2. Check API permissions in Azure AD app
3. Ensure user consented to permissions

## Monitoring

### Cloud Functions Logs

```bash
firebase functions:log
```

Or view in Firebase Console: Functions → Logs

### Key Metrics to Monitor

- OAuth callback success rate
- Pull sync success rate
- Push POD success rate  
- Token refresh failures
- API error rates (429, 5xx)

## Cost Optimization

### Cloud Functions
- Free tier: 2M invocations/month
- Typical usage: ~10K/month per customer
- Cost: ~$0 for small deployments

### Firestore
- Free tier: 50K reads, 20K writes/day
- Deliveries collection grows over time
- Consider TTL policies for old deliveries

### Secret Manager (Future)
- $0.06 per secret version per month
- ~$0.06/customer/month for refresh token storage

## Support

**Documentation:**
- Full implementation: `BC_MULTITENANT_OAUTH_SUMMARY.md`
- Testing guide: `BC_TESTING_GUIDE.md`
- Cloud Functions guide: `BC_CLOUD_FUNCTIONS_COMPLETE.md`

**Issues:**
- Check Firebase Console logs
- Review BC API errors in responses
- Verify Azure AD app configuration

## License

Proprietary - PODSafe Internal Use Only
