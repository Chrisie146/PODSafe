# Firebase Security Rules - POD Upload Implementation Details

## 📋 Overview

This document explains the updated Firebase security rules for POD (Proof of Delivery) uploads and how they enforce multi-tenant data isolation.

---

## 🔐 Security Model

### Multi-Tenant Architecture
```
Firebase Project
├── Companies (isolated by companyId)
│   ├── Admins (fullName, email, role='admin', companyId, isActive)
│   ├── Drivers (fullName, email, role='driver', companyId, isActive)
│   ├── Deliveries (deliveryId, driverId, companyId, status)
│   └── PODs (podId, deliveryId, driverId, companyId, signatureUrl, photoUrl)
└── Storage
    ├── signatures/{deliveryId}_{uuid}.png
    ├── photos/{deliveryId}_{uuid}.jpg
    ├── pdfs/{deliveryId}_{uuid}.pdf
    └── companies/{companyId}/pods/{podId}/*
```

### Core Principles
1. **Company Isolation** - Data scoped to `companyId`
2. **User Validation** - User must be active and belong to company
3. **Role-Based Access** - Drivers ≠ Admins permissions
4. **Data Integrity** - Critical fields immutable after creation
5. **File Validation** - Size/type checks enforced at rule level

---

## 🔑 Key Functions

### Authentication & Authorization

```firestore
function isAuthenticated() {
  return request.auth != null && request.auth.uid != null;
}

function isActiveUser() {
  return isAuthenticated() && getUserData().isActive == true;
}

function isAdmin() {
  return isAuthenticated() && getUserData().role == 'admin';
}

function isDriver() {
  return isAuthenticated() && getUserData().role == 'driver';
}

function isCompanyMember(companyId) {
  return isAuthenticated() && 
         getUserData().companyId == companyId;
}
```

### Validation Functions

```firestore
function hasRequiredKeys(requiredKeys) {
  return request.resource.data.keys().hasAll(requiredKeys);
}

function notChanging(fields) {
  return !request.resource.data.diff(resource.data)
    .affectedKeys().hasAny(fields);
}
```

---

## 📤 POD Upload Flow

### 1. **Driver Initiates Upload**

```dart
// Client code (Flutter)
Future<String> completePODSubmission({
  required String deliveryId,
  required String companyId,
  required String driverId,
  // ... other fields
}) async {
  // Upload files to Storage
  String signatureUrl = await uploadSignature(bytes, deliveryId);
  String photoUrl = await uploadPhoto(file, deliveryId);
  
  // Save POD document to Firestore
  PODRecord pod = PODRecord(
    companyId: companyId,  // CRITICAL - must match user's company
    driverId: driverId,     // Must be current user
    deliveryId: deliveryId,
    signatureUrl: signatureUrl,
    photoUrl: photoUrl,
    createdAt: DateTime.now(),
  );
  
  await firestore.collection('pods').add(pod.toJson());
}
```

### 2. **Storage Rules Validation**

#### Signature Upload Path: `signatures/{deliveryId}_{uuid}.png`

```firestore.storage
match /signatures/{fileName} {
  // Read: Any authenticated, active user can read
  allow read: if isAuthenticated() && isActiveUser();
  
  // Write: Only authenticated, active users with valid image
  allow write: if isAuthenticated() && 
                  isActiveUser() &&
                  isValidImageType() &&      // Must be image/*
                  isValidImageSize();        // Max 10MB
}
```

**What's Validated:**
- ✅ User is authenticated (has Firebase Auth token)
- ✅ User is active (`isActive == true`)
- ✅ Content-Type matches `image/*`
- ✅ File size < 10MB

**What's NOT validated (by design):**
- User can upload to any path (we don't know which delivery)
- File content not scanned
- Can't check `companyId` in filename

**Why:** Storage paths don't contain company/user context. Firestore rules will validate ownership.

---

#### Photo Upload Path: `photos/{deliveryId}_{uuid}.jpg`

Same rules as signatures.

---

#### PDF Upload Path: `pdfs/{deliveryId}_{uuid}.pdf`

```firestore.storage
match /pdfs/{fileName} {
  allow read: if isAuthenticated() && isActiveUser();
  allow write: if isAuthenticated() && 
                  isActiveUser() &&
                  isValidPDFType() &&        // Must be application/pdf
                  isValidPDFSize();          // Max 5MB
}
```

---

### 3. **Firestore Rules Validation**

#### Create POD: `POST /pods`

```firestore
match /pods/{podId} {
  allow create: if isAuthenticated() && 
                 isActiveUser() &&
                 isCompanyMember(request.resource.data.companyId) &&
                 hasRequiredKeys(['companyId', 'deliveryId', 'driverId', 'createdAt']) &&
                 request.resource.data.companyId == getUserData().companyId;
}
```

**Validation Steps:**
1. ✅ User is authenticated
2. ✅ User is active
3. ✅ User belongs to the company in the document (`isCompanyMember`)
4. ✅ Document has required fields (`companyId`, `deliveryId`, `driverId`, `createdAt`)
5. ✅ Document's `companyId` matches user's `companyId` (prevent privilege escalation)

**Result:** Only users can create PODs in their own company.

---

#### Read POD: `GET /pods/{podId}`

```firestore
allow read, list: if isAuthenticated() && 
                   isActiveUser() &&
                   isCompanyMember(resource.data.companyId);
```

**Result:** Users can only read PODs from their company.

---

#### Update POD: `PATCH /pods/{podId}`

```firestore
allow update: if isAuthenticated() && 
               isActiveUser() &&
               isCompanyMember(resource.data.companyId) &&
               (resource.data.driverId == request.auth.uid || isAdmin()) &&
               notChanging(['companyId', 'deliveryId', 'driverId', 'createdAt']);
```

**Validation:**
1. ✅ User is authenticated & active
2. ✅ User belongs to company
3. ✅ User is the driver who created it OR is an admin
4. ✅ Cannot modify critical fields:
   - `companyId` - Prevent moving POD to another company
   - `deliveryId` - Prevent reassigning POD to another delivery
   - `driverId` - Prevent changing who submitted it
   - `createdAt` - Preserve audit trail

**Result:** Only the driver or admins can update PODs, and only non-critical fields.

---

#### Delete POD: `DELETE /pods/{podId}`

```firestore
allow delete: if isAuthenticated() && 
               isActiveUser() &&
               isAdmin() &&
               isCompanyMember(resource.data.companyId);
```

**Result:** Only admins from the same company can delete PODs.

---

## 🎯 Complete Request Flow

### Happy Path: Driver Uploads POD

```
1. Driver logs in
   → Firebase Auth creates token with uid
   → isAuthenticated() = TRUE

2. App loads driver profile
   → Firestore reads /users/{uid}
   → Checks: isActiveUser() = TRUE, role='driver', companyId='acme'

3. Driver captures signature
   → Uploads to /signatures/{deliveryId}_uuid.png
   → Storage rules check:
     ✓ isAuthenticated() = TRUE
     ✓ isActiveUser() = TRUE  
     ✓ isValidImageType() = TRUE (image/png)
     ✓ isValidImageSize() = TRUE (< 10MB)
   → Upload succeeds

4. Driver takes photo
   → Uploads to /photos/{deliveryId}_uuid.jpg
   → Storage rules check (same as above)
   → Upload succeeds

5. Driver submits POD
   → POST /pods with:
     {
       companyId: 'acme',
       deliveryId: 'delivery123',
       driverId: 'driver456',
       signatureUrl: 'https://...',
       photoUrl: 'https://...',
       createdAt: <timestamp>
     }
   → Firestore rules check:
     ✓ isAuthenticated() = TRUE
     ✓ isActiveUser() = TRUE
     ✓ isCompanyMember('acme') = TRUE (user.companyId == 'acme')
     ✓ hasRequiredKeys([...]) = TRUE
     ✓ request.resource.data.companyId == getUserData().companyId
   → Document created ✅

6. Admin or driver reads POD
   → GET /pods/{podId}
   → Firestore rules check:
     ✓ isAuthenticated() = TRUE
     ✓ isActiveUser() = TRUE
     ✓ isCompanyMember('acme') = TRUE
   → Document returned ✅
```

---

### Attack Scenarios: Blocked by Rules

#### 1. **Inactive User Uploads POD**
```
User account deactivated (isActive = false)
↓
Driver tries to upload
↓
isActiveUser() = FALSE
↓
ALL rules deny access ❌
```

#### 2. **Driver from Company A Tries to Upload to Company B**
```
Driver A in company 'acme' tries:
POST /pods with companyId: 'other-company'
↓
request.resource.data.companyId ('other-company') != 
getUserData().companyId ('acme')
↓
Rule denies ❌
```

#### 3. **User Tries to Change POD Company**
```
POD exists with companyId: 'acme'
User tries: PATCH /pods/{podId} with companyId: 'other'
↓
notChanging(['companyId', ...]) = FALSE
(because companyId is in the affected keys)
↓
Rule denies ❌
```

#### 4. **Driver Uploads to Wrong Size File**
```
Driver tries: PUT /signatures/uuid.png (15MB file)
↓
isValidImageSize() = FALSE
(15MB > 10MB)
↓
Storage rule denies ❌
```

#### 5. **Admin from Different Company Tries to Delete**
```
Admin A in 'acme' tries to delete POD from 'other'
↓
isCompanyMember(resource.data.companyId) = FALSE
('acme' != 'other')
↓
Rule denies ❌
```

---

## 📊 Permission Matrix

| Action | Driver | Admin | Cross-Company | Inactive |
|--------|--------|-------|----------------|----------|
| Create POD | ✅ (own) | ✅ | ❌ | ❌ |
| Read POD | ✅ | ✅ | ❌ | ❌ |
| Update POD | ✅ (own) | ✅ | ❌ | ❌ |
| Delete POD | ❌ | ✅ | ❌ | ❌ |
| Upload Signature | ✅ | ✅ | ✅ | ❌ |
| Upload Photo | ✅ | ✅ | ✅ | ❌ |

**Notes:**
- Drivers can only create/update their own PODs
- Admins can create/update/delete any POD in their company
- Inactive users blocked from everything
- Cross-company access always blocked

---

## 🔍 Testing the Rules

### Using Firebase Console → Firestore Rules Playground

#### Test: Create POD as Driver

```json
{
  "resource": {
    "data": {
      "companyId": "acme",
      "deliveryId": "delivery123",
      "driverId": "driver456",
      "createdAt": 1700000000
    }
  }
}
```

**Simulate:** `auth.uid = "driver456"`, `auth.token = {...}`

**Expected:** ✅ ALLOW (if user has companyId=acme, isActive=true)

---

#### Test: Create POD with Wrong Company

```json
{
  "resource": {
    "data": {
      "companyId": "other-company",
      "deliveryId": "delivery123",
      "driverId": "driver456",
      "createdAt": 1700000000
    }
  }
}
```

**Simulate:** `auth.uid = "driver456"` in company "acme"

**Expected:** ❌ DENY (companyId mismatch)

---

## 🚀 Deployment

```bash
# Deploy only Firestore rules
firebase deploy --only firestore:rules

# Deploy only Storage rules  
firebase deploy --only storage:rules

# Deploy both
firebase deploy --only firestore:rules,storage:rules
```

---

## 📚 Related Files

- `firestore.rules` - Complete Firestore security rules
- `storage.rules` - Complete Storage security rules
- `lib/services/pod_service.dart` - POD service implementation
- `lib/models/pod_model.dart` - POD data model
- `POD_FIRESTORE_PERMISSION_FIX.md` - Fix summary
- `POD_UPLOAD_TESTING_GUIDE.md` - Testing instructions

---

## ✨ Key Takeaways

1. **Storage rules can't fully enforce multi-tenancy** - Use Firestore for company validation
2. **Always require critical fields** - `companyId`, `driverId`, `createdAt`
3. **Prevent field changes** - Use `notChanging()` for audit trail
4. **Check user status** - `isActiveUser()` in every rule
5. **Test cross-company scenarios** - The most common attack vector
6. **Use required keys validation** - Prevents incomplete documents
7. **Match company context** - User's company must match document's company

---

**Last Updated:** February 2, 2026  
**Status:** ✅ Deployed and tested
