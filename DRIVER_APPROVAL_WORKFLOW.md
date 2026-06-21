# Driver Approval Workflow

**Updated:** October 21, 2025 - ✅ **UI Implementation Complete**  
**Cloud Function:** ✅ Redeployed with approvalStatus fix

---

## Implementation Status

### Phase 1: Core Approval System ✅ Complete
- New drivers created with `approvalStatus: 'pending'`
- Cloud function updated to set initial status
- Firestore rules allow status updates

### Phase 2: Driver Management UI ✅ Complete
- Driver management screen shows pending drivers in separate tab
- Driver details can be viewed for any driver
- Quick action buttons to manage driver activity

### Phase 3: Approval Workflow UI ✅ Complete (Today)
- **Approve Driver** button in driver details menu (pending drivers only)
- **Reject Driver** button in driver details menu (pending drivers only)
- Status badge shows current approval status with color coding
- Confirmation dialogs prevent accidental actions
- Success/error notifications after approval/rejection

---

## Approval Process Overview

When a new driver is created, they go through an approval workflow:

```
Create New Driver
       ↓
approvalStatus: "pending" ← Cloud function sets this
       ↓
Admin views Driver Details
       ↓
Admin clicks Menu → "Approve Driver" or "Reject Driver"
       ↓
Confirmation Dialog appears
       ↓
approvalStatus: "approved" OR "rejected"
       ↓
✅ Can receive deliveries    OR    ❌ Cannot receive deliveries
```

---

## Who Needs to Approve?

**Answer:** An **ADMIN** user needs to approve new drivers.

### Approval Levels

| User Role | Can Create Drivers? | Can Approve Drivers? | Auto-Approved? |
|-----------|-------------------|-------------------|----------------|
| **Admin** | ✅ YES | ✅ YES | ❌ NO - must manually approve via UI |
| **Manager** | ❌ NO | ❌ NO | N/A |
| **Driver** | ❌ NO | ❌ NO | N/A |

---

## Workflow Steps

### Step 1: Create Driver (Admin)
```
1. Admin goes to Manage Users
2. Clicks "Create Driver" button
3. Fills in details:
   - Display Name
   - Email
   - Phone Number (optional)
   - License Number (optional)
4. Clicks "Add Driver"
5. Cloud function executes:
   - Creates user document
   - Sets approvalStatus: 'pending'
   - Sets isActive: false
```

### Step 2: New Driver Appears as "Pending"
```
1. Navigate to Manage Drivers screen
2. Click "Pending" tab
3. See newly created driver in list
4. Shows name, email, and "Pending" status
```

### Step 3: Admin Reviews Driver (NEW - Today)
```
1. Click on pending driver in list
2. Driver Details screen opens
3. See:
   - Driver name with "Pending Approval" badge
   - Contact information
   - License number
   - Account creation date
   - Performance statistics (0 deliveries initially)
4. Click three-dot menu button
```

### Step 4: Approve or Reject (NEW - Today)
```
APPROVE PATH:
1. Click menu → "Approve Driver"
2. Confirmation dialog: "Are you sure you want to approve this driver? 
   They will be able to receive deliveries immediately."
3. Click "Approve" button
4. Success notification: "Driver approved successfully"
5. Screen closes and returns to driver list
6. Driver now shows in "Approved" tab
7. Driver can now be assigned deliveries

REJECT PATH:
1. Click menu → "Reject Driver"
2. Confirmation dialog: "Are you sure you want to reject this driver?
   They will not be able to receive deliveries."
3. Click "Reject" button
4. Warning notification: "Driver rejected"
5. Screen closes and returns to driver list
6. Driver now shows in "Rejected" tab
7. Driver cannot be assigned deliveries
```

---

## Status Badges (UI Indicators)

### Driver Activity Status (Left Badge)
- **Active** (Green) - Driver can receive deliveries
- **Inactive** (Gray) - Driver temporarily disabled

### Approval Status (Right Badge - NEW)
- **Approved** (Green) - Passed approval, ready for delivery assignment
- **Pending Approval** (Orange) - Awaiting admin approval
- **Rejected** (Red) - Approval denied, cannot receive deliveries

### Both Badges Display Together
```
Example: Active Driver, Pending Approval
┌─────────────────────────────┐
│         John Smith          │
│  [Active]  [Pending Approval]  │
└─────────────────────────────┘

Example: Inactive Driver, Approved
┌─────────────────────────────┐
│         Jane Doe            │
│  [Inactive]  [Approved]     │
└─────────────────────────────┘
```

---

## Menu Options by Status

### When approvalStatus = "pending"
```
✓ Approve Driver    ← NEW
✓ Reject Driver     ← NEW
─────────────────
✓ Activate          (or Deactivate if already active)
✓ Delete Driver
```

### When approvalStatus = "approved" or "rejected"
```
(No approval options)
─────────────────
✓ Activate          (or Deactivate)
✓ Delete Driver
```

---

## Delivery Creation Integration

### Driver Selection in "Create Delivery"
```
When creating a delivery:
1. Select Recipient (Customer)
2. Select Driver dropdown
3. Dropdown shows ONLY:
   ✅ approvalStatus: 'approved'
   ✅ approvalStatus: null (for legacy drivers)
   ❌ NOT 'pending' drivers
   ❌ NOT 'rejected' drivers
```

This ensures:
- Only approved drivers can be assigned deliveries
- Pending drivers must be approved first
- Rejected drivers are permanently excluded

---

## Database Fields
   - Password
   - Phone (optional)
   - License Number (optional)
   - Vehicle Info (optional)
4. Clicks "Save Driver"
5. ✅ Driver created with approvalStatus: "pending"
```

### Step 2: Review Pending Drivers (Admin)
```
1. Admin navigates to Driver Management
2. Clicks "Pending" tab
3. Sees list of drivers waiting for approval
4. Each driver shows:
   - Name
   - Email
   - Phone
   - License Number
   - Status: "Pending"
```

### Step 3: Approve or Reject (Admin)
```
1. Admin clicks on a pending driver
2. Opens Driver Details screen
3. Sees "Approval Status: Pending"
4. Clicks either:
   - "✅ Approve Driver" button
   - "❌ Reject Driver" button
5. Driver status updates
```

### Step 4: Driver Access
```
If APPROVED:
├─ ✅ Driver can log in to the app
├─ ✅ Driver can see assigned deliveries
├─ ✅ Driver can complete deliveries
└─ ✅ Driver can capture PODs

If REJECTED:
├─ ❌ Driver cannot log in
├─ ❌ Authentication will fail
└─ ⚠️ Admin must approve or delete driver
```

---

## Driver Management Tabs

### Tab 1: Approved ✅
- Drivers with `approvalStatus: 'approved'`
- These drivers can use the app
- Admin can view details, edit, or deactivate

### Tab 2: Pending ⏳
- Drivers with `approvalStatus: 'pending'`
- These drivers cannot use the app yet
- Admin must approve or reject
- Admin can view application details

### Tab 3: Rejected ❌
- Drivers with `approvalStatus: 'rejected'`
- These drivers cannot use the app
- Admin can re-approve or delete

---

## Database Fields

New drivers are created with:

```json
{
  "uid": "firebase-auth-uid",
  "email": "driver@example.com",
  "name": "John Doe",
  "role": "driver",
  "companyId": "company-id",
  "isActive": true,
  "approvalStatus": "pending",
  "createdAt": "2025-10-20T12:00:00Z",
  "createdBy": "admin-uid",
  "phoneNumber": "555-1234",
  "licenseNumber": "DL123456",
  "vehicleInfo": "Vehicle details..."
}
```

Key points:
- ✅ `approvalStatus: 'pending'` - Set automatically for drivers
- ✅ `isActive: true` - Driver account is active but waiting approval
- ✅ `createdBy` - Tracks which admin created the driver
- ✅ `companyId` - Assigned to creator's company automatically

---

## Firestore Query

The app queries drivers by approval status:

```dart
// Get approved drivers
FirebaseFirestore.instance
    .collection('users')
    .where('role', isEqualTo: 'driver')
    .where('approvalStatus', isEqualTo: 'approved')
    .get()

// Get pending drivers
FirebaseFirestore.instance
    .collection('users')
    .where('role', isEqualTo: 'driver')
    .where('approvalStatus', isEqualTo: 'pending')
    .get()
```

---

## Security Rules

Drivers cannot log in if not approved. The app validates:

```dart
// Before allowing driver to access app
if (user.approvalStatus != 'approved') {
  // Block access
  throw Exception('Driver not approved yet');
}
```

---

## Approval Process - Visual Flow

```
ADMIN CREATES DRIVER
    │
    ├─→ Cloud Function called
    ├─→ Firebase Auth user created
    ├─→ Firestore document created with:
    │   ├─ approvalStatus: "pending"
    │   ├─ isActive: true
    │   └─ companyId: admin's company
    │
    ├─→ ✅ Success message shown
    ├─→ Admin stays logged in
    └─→ Driver appears in "Pending" tab
    
DRIVER ATTEMPTS TO LOG IN
    │
    ├─→ Enters email/password
    ├─→ Firebase Auth: ✅ Authentication successful
    ├─→ Firestore query: Is approvalStatus = 'approved'?
    │   │
    │   ├─ NO (pending/rejected)
    │   │   └─→ ❌ Access denied
    │   │   └─→ Show: "Driver account pending approval"
    │   │
    │   └─ YES (approved)
    │       └─→ ✅ App loads
    │       └─→ Driver can see deliveries
    │
ADMIN APPROVES DRIVER
    │
    ├─→ Goes to Driver Management
    ├─→ Clicks "Pending" tab
    ├─→ Opens driver details
    ├─→ Clicks "Approve Driver"
    ├─→ Updates Firestore: approvalStatus = "approved"
    │
    ├─→ ✅ Driver notification sent (optional)
    ├─→ ✅ Driver can now log in
    └─→ Driver moved to "Approved" tab

ADMIN REJECTS DRIVER
    │
    ├─→ Goes to Driver Management
    ├─→ Clicks "Pending" tab
    ├─→ Opens driver details
    ├─→ Clicks "Reject Driver"
    ├─→ Updates Firestore: approvalStatus = "rejected"
    │
    ├─→ ✅ Driver rejection reason sent (optional)
    ├─→ ❌ Driver cannot log in
    └─→ Driver moved to "Rejected" tab
```

---

## API/UI Components

### Create Driver Screen
- **Who can access:** Admin only
- **Action:** Creates new driver with `approvalStatus: 'pending'`
- **Result:** Success message, driver added to pending list

### Driver Management Screen
- **Who can access:** Admin only
- **Tabs:**
  - ✅ Approved (active drivers)
  - ⏳ Pending (waiting for approval)
  - ❌ Rejected (denied access)

### Driver Details Screen
- **Who can access:** Admin only
- **Shows:** Driver info, approval status
- **Actions:** Approve, Reject, Edit, Deactivate

### Driver Login
- **Who can access:** Approved drivers
- **Validation:** Check `approvalStatus === 'approved'`
- **If not approved:** Show error and prevent access

---

## Key Points

✅ **New drivers start as "pending"**
- Automatically set by Cloud Function
- Cannot use app until approved

✅ **Only admins can approve drivers**
- Manager and driver roles cannot approve
- Approval is in Driver Management screen

✅ **No automatic approval**
- Drivers are never auto-approved
- Admin must manually review and approve

✅ **Admin stays logged in**
- Cloud Function uses Admin SDK
- No session interference

✅ **Driver companyId is set automatically**
- New drivers assigned to admin's company
- Can't create cross-company drivers

---

## Testing the Workflow

### Step 1: Create a test driver
```
1. Log in as admin
2. Go to Driver Management
3. Click "Add Driver"
4. Fill form (test@example.com, test123456, etc.)
5. Click "Save Driver"
6. ✅ See success message
```

### Step 2: Verify driver is pending
```
1. Click "Pending" tab
2. Should see newly created driver
3. Status should show "Pending"
4. Driver NOT in "Approved" tab
```

### Step 3: Attempt driver login
```
1. Open new browser/incognito
2. Try to log in as driver
3. ✅ Auth succeeds (email/password valid)
4. ❌ App denies access (not approved)
5. Message: "Driver account pending approval"
```

### Step 4: Approve the driver
```
1. Back in admin account
2. Click on pending driver
3. Click "Approve Driver" button
4. ✅ Driver status changes to "Approved"
5. Driver moves to "Approved" tab
```

### Step 5: Retry driver login
```
1. In driver browser
2. Try login again
3. ✅ Auth succeeds
4. ✅ App loads (approved now!)
5. Driver can see dashboard
```

---

## Status Summary

✅ **Cloud Function updated** - Sets approvalStatus: 'pending' for drivers  
✅ **Frontend updated** - Sets approvalStatus: 'pending' when creating drivers  
✅ **Approval system exists** - Driver Management has Approved/Pending/Rejected tabs  
✅ **Security implemented** - Drivers can't use app until approved  

**Ready to test!** 🎉
