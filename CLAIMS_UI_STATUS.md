# Claims System - UI Screens Status

## ✅ Completed Backend (100%)

### Models
- ✅ claim_model.dart (800 lines)
- ✅ company_claim_settings.dart (400 lines)

### Services  
- ✅ claim_service.dart (600 lines)

### Providers
- ✅ claim_provider.dart (400 lines)

**Total Backend: ~2,200 lines of production code**

---

## ⏳ UI Screens - In Progress

### Driver Screens

#### 1. Report Issue Screen (STARTED - needs fixes)
**File**: `lib/screens/driver/report_issue_screen.dart`
**Status**: 90% complete, has compilation errors to fix

**Issues to Fix**:
1. `Delivery Item` uses `description` not `name`
2. `Delivery` doesn't have `customerId` field  
3. `AuthProvider` has `currentUser` not `user`
4. `AuthProvider` has `companyId` not `company.id`
5. `CustomFieldDefinition` type not imported correctly

**Features Implemented**:
- ✅ Dynamic claim type selection (based on company config)
- ✅ Custom fields rendering (text, number, dropdown, checkbox)
- ✅ Photo capture (camera + gallery)
- ✅ Photo limit enforcement  
- ✅ Customer signature capture
- ✅ Affected items checklist
- ✅ GPS auto-capture
- ✅ Evidence quality validation
- ✅ Submit to Firestore

**Once Fixed, Will Support**:
- Immediate claims (at delivery site with customer signature)
- Delayed claims (filed later without signature)
- Company-specific claim types
- Company-specific custom fields
- Photo requirements per company
- Signature requirements per company

---

#### 2. Driver My Claims Screen (TODO)
**File**: `lib/screens/driver/my_claims_screen.dart`
**Status**: Not started

**Features Needed**:
- List driver's filed claims
- Filter by status
- View claim details
- Add driver response (for delayed claims where driver already left)
- Upload additional evidence
- View approval status

---

### Admin Screens

#### 3. Admin Claims Dashboard (TODO)
**File**: `lib/screens/admin/claims_dashboard_screen.dart`
**Status**: Not started

**Features Needed**:
- List all company claims
- Filter by:
  - Status (pending, investigating, approved, etc.)
  - Type (damaged, shortage, etc.)
  - Driver
  - Customer
  - Date range
- Search by claim ID, invoice, customer name
- Quick stats:
  - Total claims
  - Pending action
  - Overdue (SLA breached)
  - Total claim amount
- Click claim to open details
- Badge indicators for pending action

---

#### 4. Claim Details & Review Screen (TODO)
**File**: `lib/screens/admin/claim_details_screen.dart`
**Status**: Not started

**Features Needed**:
- View all claim information
- View photos (gallery/lightbox)
- View signatures
- View GPS location on map
- View custom fields
- View affected items
- View status history (audit trail)
- Comments section
  - Add comments
  - Internal notes (not visible to driver)
  - External comments (visible to driver)
- Approval workflow UI
  - Approve button (if at current user's approval level)
  - Reject button
  - Request info button
  - Digital signature capture (if required)
  - Add investigation notes
- Resolution form
  - Select resolution type (credit, debit driver, refund, etc.)
  - Enter credit note number
  - Enter debit note number
  - Resolution notes
- Close claim button

---

#### 5. Admin Claim Settings Screen (TODO)
**File**: `lib/screens/admin/claim_settings_screen.dart`  
**Status**: Not started

**Features Needed**:
- Enable/disable claim types (checkboxes)
- Select workflow preset (simple/standard/enterprise/custom)
- Configure workflow (if custom selected)
  - Add approval levels
  - Set role for each level
  - Set SLA hours per level
  - Require signature per level
- Photo requirements
  - Minimum photos
  - Maximum photos
  - Mandatory toggle
  - Required for immediate claims
  - Required for delayed claims
- Signature requirements
  - Customer signature toggle
  - Driver signature toggle
- Time limits
  - Claim filing deadline (days)
  - SLA hours per approval level
- Auto-approval rules
  - Enable toggle
  - Amount threshold
  - Auto-approve claim types
- Custom fields builder
  - Select claim type
  - Add custom field
  - Field type (text, number, dropdown, checkbox, photo, signature)
  - Required toggle
  - Validation rules
- Notification settings
  - Push notifications toggle
  - Email notifications toggle
  - SMS notifications toggle
- Fraud detection
  - Enable toggle
  - Amount threshold
  - Frequency threshold (claims per month)
- Pattern detection
  - Enable toggle
  - Recurring threshold (same issue X times)
- ERP integration
  - Enable toggle
  - ERP system selection
  - API configuration
- Save button

---

## 🔧 Quick Fixes Needed for Report Issue Screen

### Fix #1: Update DeliveryItem References
```dart
// OLD
item.name
// NEW  
item.description
```

### Fix #2: Add Customer ID to Delivery
Delivery doesn't have customerId. We need to either:
- Option A: Add customerId to Delivery model
- Option B: Use delivery.id as customerId temporarily
- Option C: Let admin assign customerId during claim review

### Fix #3: Update AuthProvider References
```dart
// OLD
authProvider.company!.id
authProvider.user!.uid

// NEW
authProvider.companyId!
authProvider.currentUser!.uid
```

### Fix #4: Import CustomFieldDefinition
```dart
import '../../models/company_claim_settings.dart';
```

---

## 📊 Progress Overview

### Backend: 100% ✅
- All models complete
- All services complete
- All providers complete
- ~2,200 lines of code

### UI Screens: 18% ⏳
- Driver Report Issue: 90% (needs fixes)
- Driver My Claims: 0%
- Admin Dashboard: 0%
- Admin Claim Details: 0%
- Admin Settings: 0%

### Estimated Remaining Work:
- Fix Report Issue Screen: 1 hour
- Build Driver My Claims: 3-4 hours
- Build Admin Dashboard: 4-6 hours
- Build Admin Claim Details: 6-8 hours
- Build Admin Settings: 4-6 hours
- **Total**: 18-25 hours of UI development

---

## 🎯 Next Steps

### Immediate (Fix Report Issue Screen):
1. Check if Delivery model has customerId
   - If not, add it to Delivery model
2. Fix all DeliveryItem.name → DeliveryItem.description
3. Fix all authProvider.user → authProvider.currentUser
4. Fix all authProvider.company.id → authProvider.companyId
5. Add missing import for CustomFieldDefinition
6. Test compilation

### Short Term (Complete Driver Screens):
1. Build Driver My Claims Screen
2. Test driver workflow end-to-end
3. Add navigation from delivery details

### Medium Term (Complete Admin Screens):
1. Build Admin Claims Dashboard
2. Build Admin Claim Details Screen
3. Test approval workflow
4. Test resolution workflow

### Long Term (Admin Configuration):
1. Build Admin Claim Settings Screen
2. Test company configuration
3. Test different workflow presets
4. Test custom fields

---

## 💡 Recommendations

### Priority 1: Fix Report Issue Screen
This is the core driver experience. Get this working first so drivers can file claims.

### Priority 2: Build Claim Details Screen (Admin)
Admins need to review and approve claims. This is the second most critical screen.

### Priority 3: Build Claims Dashboard (Admin)
Admins need to see all claims and filter them. This provides overview.

### Priority 4: Build Driver My Claims
Drivers need to see their claim status and add responses.

### Priority 5: Build Settings Screen
This enables company configuration and customization.

---

## 🚀 When Complete, You'll Have:

✅ **Universal claims system** that works for any delivery business
✅ **Configurable workflows** (simple → enterprise)
✅ **Custom fields** per claim type per company
✅ **Multi-level approval chains** with SLA tracking
✅ **Evidence quality scoring** (photos, GPS, signatures)
✅ **Fraud detection** and pattern recognition
✅ **Complete audit trail** for legal compliance
✅ **Real-time updates** via Firestore
✅ **Analytics** and reporting
✅ **Zero code changes** for customization

**This is a professional-grade SaaS claims management system!** 🎉
