# Initialize Company Claims Settings - Quick Setup

## Status
✅ Firestore rules deployed successfully  
⏳ Company settings document needs to be created

---

## The Issue

The ClaimProvider tries to load company settings from:
```
companies/{companyId}/settings/claims
```

But this document doesn't exist yet, causing the claim ID generation to fail.

---

## Solution: Create Settings Document

### Option 1: Via Firebase Console (5 minutes)

#### Step 1: Get Your Company ID
From the app logs, your company ID is:
```
jE4WKflrexPV6DDBhxEj
```

#### Step 2: Open Firestore Database
1. Go to: https://console.firebase.google.com/project/podsafe-92a3e/firestore
2. Navigate to: `companies` collection
3. Click on your company document: `jE4WKflrexPV6DDBhxEj`

#### Step 3: Create settings Subcollection
1. Click "Start collection" button (or "+" next to Collections)
2. Collection ID: `settings`
3. Document ID: `claims`
4. Click "Add document"

#### Step 4: Add Settings Fields
Add these fields (click "Add field" for each):

```json
{
  "companyId": "jE4WKflrexPV6DDBhxEj",
  "claimIdPrefix": "CLM",
  "claimIdStartNumber": 1,
  "enabledClaimTypes": [
    "damaged",
    "shortage",
    "shortWeight",
    "missing",
    "wrongItems",
    "returns",
    "priceError",
    "lateDelivery",
    "qualityIssue",
    "temperatureIssue",
    "packagingIssue",
    "other"
  ],
  "workflowPreset": "standard",
  "minPhotosRequired": 0,
  "maxPhotosAllowed": 10,
  "photosMandatory": false,
  "requireCustomerSignature": false,
  "requireGPSLocation": true,
  "enableAutoApproval": false,
  "enableFraudDetection": true,
  "enablePatternDetection": true,
  "createdAt": [Firebase Timestamp - use "Add field" > "timestamp"],
  "updatedAt": [Firebase Timestamp - use "Add field" > "timestamp"]
}
```

**Field Types**:
- `companyId`: string
- `claimIdPrefix`: string
- `claimIdStartNumber`: number
- `enabledClaimTypes`: array (of strings)
- `workflowPreset`: string
- `minPhotosRequired`: number
- `maxPhotosAllowed`: number
- `photosMandatory`: boolean
- `requireCustomerSignature`: boolean
- `requireGPSLocation`: boolean
- `enableAutoApproval`: boolean
- `enableFraudDetection`: boolean
- `enablePatternDetection`: boolean
- `createdAt`: timestamp
- `updatedAt`: timestamp

#### Step 5: Save
Click "Save" button

---

### Option 2: Minimal Settings (Quick Test)

If you just want to test, create a document with minimal fields:

**Collection**: `companies/{companyId}/settings`  
**Document ID**: `claims`

```json
{
  "companyId": "jE4WKflrexPV6DDBhxEj",
  "claimIdPrefix": "CLM",
  "claimIdStartNumber": 1,
  "enabledClaimTypes": ["damaged", "shortage", "lateDelivery", "other"],
  "workflowPreset": "simple"
}
```

This is enough for basic testing. The app will use default values for missing fields.

---

### Option 3: Copy Default Settings

The `CompanyClaimSettings` class has default values. Here's a complete default setup:

**Path**: `companies/jE4WKflrexPV6DDBhxEj/settings/claims`

```json
{
  "companyId": "jE4WKflrexPV6DDBhxEj",
  "claimIdPrefix": "CLM",
  "claimIdStartNumber": 1,
  "enabledClaimTypes": [
    "damaged",
    "shortage",
    "shortWeight",
    "missing",
    "wrongItems",
    "returns",
    "priceError",
    "lateDelivery",
    "didNotDeliver",
    "qualityIssue",
    "temperatureIssue",
    "packagingIssue",
    "expiryIssue",
    "serviceIssue",
    "other"
  ],
  "workflowPreset": "standard",
  "minPhotosRequired": 1,
  "maxPhotosAllowed": 10,
  "photosMandatory": true,
  "requireCustomerSignature": false,
  "requireGPSLocation": true,
  "requireDeliveryId": true,
  "requireInvoiceNumber": true,
  "requireCustomerInfo": true,
  "allowAnonymousClaims": false,
  "enableAutoApproval": false,
  "autoApproveUnderAmount": null,
  "autoApproveTypes": [],
  "enableFraudDetection": true,
  "fraudThresholdAmount": 5000,
  "fraudThresholdFrequency": 5,
  "enablePatternDetection": true,
  "recurringClaimThreshold": 3,
  "requiresERPSync": false,
  "erpSystem": null,
  "notifyDriverOnStatusChange": true,
  "notifyAdminOnNewClaim": true,
  "createdAt": "2025-10-17T00:00:00Z",
  "updatedAt": "2025-10-17T00:00:00Z"
}
```

---

## Verification

### After Creating Settings Document

1. **Hot Restart App**: Press `R` in terminal
2. **Navigate to Delivery**: Click on any delivery
3. **Click "Report Issue"**: The button should now work
4. **Check Console**: Should see claim types loaded
5. **Submit Claim**: Should generate claim ID successfully

### Expected Console Output (Success):
```
I/flutter: ClaimProvider initialized
I/flutter: Loading claim settings for company: jE4WKflrexPV6DDBhxEj
I/flutter: Claim settings loaded: 12 enabled types
I/flutter: Generating claim ID for company: jE4WKflrexPV6DDBhxEj
I/flutter: Claim ID generated: CLM-2025-0001
I/flutter: Claim created successfully
```

### If Still Failing:
1. **Check document path**: `companies/jE4WKflrexPV6DDBhxEj/settings/claims`
2. **Verify companyId field**: Must match exactly
3. **Check field types**: Ensure arrays, numbers, booleans are correct
4. **Wait 30 seconds**: Firebase cache might need to update
5. **Clear app data**: Sometimes helps with cached rules

---

## Understanding the Structure

### Firestore Hierarchy:
```
companies/
  └── jE4WKflrexPV6DDBhxEj/           (Your company document)
       ├── settings/                   (Subcollection)
       │    └── claims                 (Settings document)
       ├── claims/                     (Subcollection - will be created automatically)
       │    └── CLM-2025-0001          (Claim documents)
       └── claimCounters/              (Subcollection - created automatically)
            └── 2025                    (Counter document)
```

### Security Rules Applied:
- ✅ `companies/{companyId}/settings/claims` → Readable by all company members
- ✅ `companies/{companyId}/claims/{claimId}` → Read/write by company members
- ✅ `companies/{companyId}/claimCounters/{year}` → Read/write for auto-increment

---

## Quick Copy-Paste (Minimal)

**For fastest setup, copy this to create the settings document:**

**Collection Path**: `companies/jE4WKflrexPV6DDBhxEj/settings`  
**Document ID**: `claims`

**Fields**:
```
companyId: "jE4WKflrexPV6DDBhxEj"
claimIdPrefix: "CLM"
claimIdStartNumber: 1
enabledClaimTypes: ["damaged","shortage","lateDelivery","other"]
workflowPreset: "simple"
```

That's it! 5 fields, then save.

---

## After Setup Complete

Once settings are created, you can:

1. ✅ **File Claims**: Report Issue button will work
2. ✅ **Generate Claim IDs**: CLM-2025-0001, CLM-2025-0002, etc.
3. ✅ **Test Workflows**: Claims will follow configured workflow
4. ✅ **Test Custom Fields**: If you add them to settings
5. ✅ **Test Different Types**: Only enabled types will show

---

## Next Actions

1. **Now**: Create settings document in Firebase Console
2. **Then**: Restart app and test claim filing
3. **After**: Build "Driver My Claims" screen to view filed claims
4. **Future**: Build admin screens to review and approve claims

---

## Troubleshooting

### "Document not found" error
- Verify path: `companies/jE4WKflrexPV6DDBhxEj/settings/claims`
- Check collection name: `settings` (not `setting`)
- Check document ID: `claims` (not `claim`)

### "Permission denied" still showing
- Wait 1-2 minutes after deploying rules
- Clear app cache/data
- Restart app completely

### "Invalid claim type" error
- Check `enabledClaimTypes` is an array
- Check array contains valid claim types
- Match exact strings from ClaimType enum

---

## Success!

Once you see:
```
I/flutter: Claim ID generated: CLM-2025-0001
I/flutter: Claim created successfully
```

You're ready to proceed with the rest of the claims system! 🎉

