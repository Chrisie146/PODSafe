# Claims System - Design Proposal

## Overview
A comprehensive claims management system for handling delivery issues, damages, disputes, and refunds in PODSafe.

---

## 🎯 What is a Claim?

A **claim** is a formal record of an issue with a delivery that requires investigation and resolution:

- **Damaged goods** - Items arrived broken or damaged
- **Missing items** - Partial delivery (some items not received)
- **Wrong items** - Incorrect products delivered
- **Late delivery** - Delivery beyond agreed timeframe
- **Service issues** - Poor driver behavior, unprofessional conduct
- **Delivery failure** - Could not complete delivery
- **Other** - Custom issue types

---

## 📊 Current System Analysis

### What You Have Now:
```
✅ Deliveries (pending → inTransit → delivered/failed)
✅ POD Records (signature, photo, GPS, timestamp)
✅ Driver tracking
✅ Multi-company (SaaS)
✅ Status updates
```

### What's Missing for Claims:
```
❌ Issue reporting mechanism
❌ Evidence collection (photos, notes)
❌ Claim status tracking
❌ Resolution workflow
❌ Financial tracking (refunds, compensation)
❌ Communication thread
❌ Analytics on claim patterns
```

---

## 🗂️ Proposed Data Model

### Claim Model
```dart
enum ClaimType {
  damaged,        // Goods damaged in transit
  missing,        // Items missing from delivery
  wrongItems,     // Incorrect items delivered
  lateDelivery,   // Delivery beyond SLA
  serviceIssue,   // Driver behavior, professionalism
  failed,         // Could not complete delivery
  other,          // Custom issues
}

enum ClaimStatus {
  pending,        // Just filed, awaiting review
  investigating,  // Admin reviewing evidence
  approved,       // Claim accepted
  rejected,       // Claim denied
  resolved,       // Completed (refund issued, etc.)
  closed,         // Closed without action
}

enum ClaimPriority {
  low,           // Minor issues
  medium,        // Standard claims
  high,          // Urgent, high-value
  critical,      // Major issues requiring immediate attention
}

class Claim {
  final String id;
  final String companyId;
  final String deliveryId;
  final String? podId;
  
  // Who filed the claim?
  final String filedBy;          // userId (admin, driver, or customer)
  final String filedByRole;      // 'admin', 'driver', 'customer'
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  
  // Delivery info
  final String invoiceNumber;
  final String driverId;
  final String driverName;
  
  // Claim details
  final ClaimType type;
  final ClaimStatus status;
  final ClaimPriority priority;
  final String subject;          // Brief title
  final String description;      // Detailed explanation
  final List<String> affectedItems; // Which items in delivery
  
  // Evidence
  final List<String> photoUrls;  // Firebase Storage URLs
  final List<String> documentUrls; // PDF, receipts, etc.
  
  // Resolution
  final String? resolution;      // How it was resolved
  final String? resolvedBy;      // Admin userId
  final DateTime? resolvedAt;
  final double? refundAmount;    // If money involved
  final String? refundStatus;    // 'pending', 'processed'
  
  // Communication
  final List<ClaimComment> comments; // Discussion thread
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;
}

class ClaimComment {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String message;
  final List<String> attachments; // Photo URLs
  final DateTime timestamp;
  final bool isInternal; // Admin-only notes
}
```

---

## 🎨 User Interface Design

### 1. Claims Dashboard (Admin)
**Location**: Admin Dashboard → New "Claims" tab

```
┌─────────────────────────────────────────────┐
│  Claims Management                      [+] │
├─────────────────────────────────────────────┤
│  📊 Overview                                │
│  ├─ 12 Pending Review                      │
│  ├─ 5 Investigating                        │
│  ├─ 23 Resolved This Month                 │
│  └─ $1,250 Total Refunds                   │
├─────────────────────────────────────────────┤
│  Tabs: [All] [Pending] [Investigating]     │
│        [Approved] [Resolved] [Rejected]    │
├─────────────────────────────────────────────┤
│  🔴 #CLM-001 | Damaged Goods | 2 hours ago │
│     Invoice: INV-1234 | Customer: John Doe │
│     🚨 High Priority                       │
├─────────────────────────────────────────────┤
│  🟡 #CLM-002 | Missing Items | 1 day ago   │
│     Invoice: INV-1235 | Customer: Jane     │
│     ⚠️ Medium Priority                     │
└─────────────────────────────────────────────┘
```

### 2. File Claim Screen (Multiple Entry Points)
**Who can file?**
- ✅ Admins (on behalf of customer)
- ✅ Drivers (report issues during delivery)
- ❓ Customers (optional - customer portal)

**Entry Points**:
1. Delivery Details → "File Claim" button
2. POD Viewer → "Report Issue" button
3. Claims Dashboard → "+ New Claim" button

```
┌─────────────────────────────────────────────┐
│  File New Claim                         [X] │
├─────────────────────────────────────────────┤
│  Delivery: #INV-1234                        │
│  Customer: John Doe                         │
│  Driver: Mike Wilson                        │
├─────────────────────────────────────────────┤
│  Claim Type: [Damaged Goods ▼]             │
│  Priority:   [High ▼]                       │
│  Subject:    [Box crushed during delivery]  │
│                                             │
│  Description:                               │
│  ┌─────────────────────────────────────┐   │
│  │ Customer reports the box was        │   │
│  │ severely crushed. Contents damaged. │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Affected Items:                            │
│  ☑ Laptop (Qty: 2)                         │
│  ☐ Mouse (Qty: 5)                          │
│                                             │
│  Evidence:                                  │
│  📷 [Upload Photos]                         │
│  📎 [Upload Documents]                      │
│                                             │
│  [Cancel]           [Submit Claim]          │
└─────────────────────────────────────────────┘
```

### 3. Claim Details Screen
```
┌─────────────────────────────────────────────┐
│  Claim #CLM-001                    [Edit]   │
│  🔴 High Priority | 🟡 Investigating        │
├─────────────────────────────────────────────┤
│  📦 Delivery Information                    │
│  Invoice: INV-1234                          │
│  Customer: John Doe (+1234567890)           │
│  Driver: Mike Wilson                        │
│  Delivered: Oct 15, 2025 2:30 PM            │
│  POD: [View POD →]                          │
├─────────────────────────────────────────────┤
│  ⚠️ Claim Details                           │
│  Type: Damaged Goods                        │
│  Filed by: Admin (Sarah) on Oct 16, 2025   │
│  Subject: Box crushed during delivery       │
│  Description: Customer reports...           │
│                                             │
│  Affected Items:                            │
│  • Laptop (Qty: 2) - $2,000 value           │
├─────────────────────────────────────────────┤
│  📸 Evidence (3 photos)                     │
│  [Photo 1] [Photo 2] [Photo 3]              │
├─────────────────────────────────────────────┤
│  💬 Comments & Updates (5)                  │
│  ┌─────────────────────────────────────┐   │
│  │ Sarah (Admin) - 2 hours ago         │   │
│  │ Contacted customer for details...   │   │
│  └─────────────────────────────────────┘   │
│  [Add Comment]                              │
├─────────────────────────────────────────────┤
│  ✅ Resolution                               │
│  Status: [Investigating ▼]                  │
│  Refund Amount: [$500]                      │
│  Resolution Notes: [___]                    │
│                                             │
│  [Approve Claim] [Reject Claim] [Resolve]  │
└─────────────────────────────────────────────┘
```

---

## 🔄 Claim Workflow

### Standard Flow:
```
1. FILED (Pending)
   ↓
2. REVIEW (Admin investigates)
   ↓
3. DECISION
   ├─→ APPROVED → RESOLVE (refund, replacement)
   ├─→ REJECTED → CLOSED (with reason)
   └─→ MORE INFO NEEDED → Back to Review

4. RESOLVED
   └─→ CLOSED
```

### Example Scenarios:

#### Scenario A: Damaged Goods
```
1. Driver delivers box (POD captured)
2. Customer calls: "Box is damaged!"
3. Admin logs into PODSafe
4. Goes to Delivery #INV-1234
5. Clicks "File Claim"
6. Selects "Damaged Goods"
7. Uploads photos from customer
8. Submits claim
9. Status: Pending
10. Admin reviews POD (box looked fine in photo)
11. Admin changes status to "Investigating"
12. Admin contacts driver for explanation
13. Driver uploads damage photo from delivery truck
14. Admin approves claim
15. Admin enters refund amount
16. Changes status to "Resolved"
17. Customer notified
```

#### Scenario B: Missing Items
```
1. Delivery shows 5 items in manifest
2. Customer received only 3 items
3. Customer reports missing items
4. Admin files claim
5. Reviews POD signature
6. Checks driver notes
7. Investigates warehouse records
8. Finds 2 items never loaded
9. Approves claim
10. Arranges re-delivery
11. Marks as resolved
```

---

## 🔗 Integration Points

### 1. Delivery Management Screen
**Add**:
- Claims count badge on delivery cards
- "File Claim" button on delivery details
- Claims tab showing related claims

### 2. POD Viewer
**Add**:
- "Report Issue" button
- Link to related claim (if exists)
- Visual indicator if claim filed

### 3. Driver App
**Add**:
- "Report Issue" during/after delivery
- Upload evidence immediately
- View claims filed against their deliveries

### 4. Analytics Dashboard
**Add Charts**:
- Claims by type (pie chart)
- Claims trend over time (line chart)
- Resolution time (bar chart)
- Refund amounts (bar chart)
- Claims by driver (table)
- Claims by customer (table)

---

## 💾 Database Structure

### Firestore Collections:

```
/companies/{companyId}/claims/{claimId}
  - id, type, status, priority
  - deliveryId, podId, invoiceNumber
  - filedBy, filedByRole
  - customerName, customerEmail, customerPhone
  - driverId, driverName
  - subject, description
  - affectedItems[]
  - photoUrls[], documentUrls[]
  - resolution, resolvedBy, resolvedAt
  - refundAmount, refundStatus
  - createdAt, updatedAt
  - metadata{}

/companies/{companyId}/claims/{claimId}/comments/{commentId}
  - id, userId, userName, userRole
  - message, attachments[]
  - timestamp, isInternal
```

### Storage Structure:
```
/companies/{companyId}/claims/{claimId}/
  ├─ photos/
  │  ├─ damage_1.jpg
  │  └─ damage_2.jpg
  └─ documents/
     └─ receipt.pdf
```

---

## 📱 Features by Priority

### Phase 1: Core Claims (MVP)
- ✅ File claim from delivery details
- ✅ Claim types: damaged, missing, wrong items
- ✅ Upload photos as evidence
- ✅ Status tracking (pending, investigating, resolved)
- ✅ Claims list dashboard
- ✅ Claim details screen
- ✅ Basic comments/notes

**Time estimate**: 2-3 days

### Phase 2: Enhanced Features
- ✅ Driver claim filing
- ✅ Priority levels
- ✅ Email notifications
- ✅ Refund amount tracking
- ✅ Advanced filtering/search
- ✅ Claim analytics

**Time estimate**: 2-3 days

### Phase 3: Advanced Features
- ✅ Customer portal (file claims directly)
- ✅ Auto-claim detection (late deliveries)
- ✅ Claim templates
- ✅ Bulk claim processing
- ✅ Integration with accounting systems
- ✅ SLA tracking

**Time estimate**: 3-5 days

---

## 🎨 UI/UX Considerations

### Design Principles:
1. **Easy to file** - Minimal clicks to report issue
2. **Evidence-first** - Photos are critical
3. **Clear status** - Always know where claim stands
4. **Fast resolution** - Streamlined workflow
5. **Transparent** - All parties can see updates

### Color Coding:
- 🔴 **High Priority** - Red
- 🟡 **Medium Priority** - Orange
- 🟢 **Low Priority** - Green
- ⚫ **Critical** - Black/Dark Red

### Status Colors:
- 🟡 **Pending** - Yellow
- 🔵 **Investigating** - Blue
- 🟢 **Approved** - Green
- 🔴 **Rejected** - Red
- ⚫ **Resolved** - Gray
- ⚪ **Closed** - Light Gray

---

## 📊 Reporting & Analytics

### Key Metrics:
1. **Total claims** (by period)
2. **Claims by type** (pie chart)
3. **Average resolution time**
4. **Approval rate** (%)
5. **Total refunds issued**
6. **Claims per driver** (identify problem drivers)
7. **Claims per customer** (identify problem customers)
8. **Claims by day of week** (identify patterns)

### Reports:
- Monthly claims summary
- Driver performance (claims against them)
- Customer satisfaction (claims filed)
- Financial impact (refunds, replacements)

---

## 🔒 Security & Permissions

### Who Can Do What?

| Action | Admin | Driver | Customer |
|--------|-------|--------|----------|
| File claim | ✅ | ✅ | ✅ (optional) |
| View all claims | ✅ | ❌ | ❌ |
| View own claims | ✅ | ✅ | ✅ |
| Update status | ✅ | ❌ | ❌ |
| Add comments | ✅ | ✅ | ✅ |
| See internal notes | ✅ | ❌ | ❌ |
| Approve/reject | ✅ | ❌ | ❌ |
| Issue refunds | ✅ | ❌ | ❌ |
| Delete claims | ✅ | ❌ | ❌ |
| Analytics | ✅ | ❌ | ❌ |

---

## 💡 Smart Features (Future)

### 1. Auto-Claim Detection
```dart
// Automatically flag potential issues
- Late delivery (> 24 hours past scheduled)
- POD missing photo
- No signature captured
- GPS location mismatch
- Multiple failed attempts
```

### 2. Claim Patterns
```dart
// Alert admin to trends
- Same driver has 5+ claims this month
- Same customer files claims frequently
- Same delivery route has issues
- Damage claims spike on Mondays
```

### 3. Smart Suggestions
```dart
// AI-assisted resolution
- "Similar claims were resolved with $X refund"
- "This driver has 10 similar claims"
- "Customer has filed 0 claims in 2 years (reliable)"
```

---

## 🚀 Implementation Plan

### Step 1: Data Model
- Create `claim_model.dart`
- Create `claim_comment_model.dart`
- Add enums (ClaimType, ClaimStatus, ClaimPriority)

### Step 2: Services
- Create `claim_service.dart` (Firestore CRUD)
- Add claim storage methods to existing storage service
- Create `claim_provider.dart` (state management)

### Step 3: UI Screens
- Claims dashboard screen (list all)
- File claim screen (form)
- Claim details screen (view/edit)
- Add "File Claim" buttons to existing screens

### Step 4: Integration
- Add claims tab to admin dashboard
- Add claim indicators to delivery cards
- Link POD viewer to claims
- Update driver app with claim filing

### Step 5: Testing
- File claim from delivery
- Upload photos
- Add comments
- Change status
- Verify permissions
- Test refund tracking

---

## ❓ Questions for You

Before I start implementing, let's discuss:

1. **Priority**: Which phase do you want first? (Phase 1 MVP recommended)

2. **Who files claims?**
   - Admins only? (simplest)
   - Admins + Drivers? (recommended)
   - Admins + Drivers + Customers? (requires customer portal)

3. **Refund handling**:
   - Just track the amount? (simple)
   - Integrate with payment system? (complex)
   - Generate refund requests for manual processing? (middle ground)

4. **Notifications**:
   - Email notifications when claim filed/updated?
   - In-app notifications only?
   - SMS for critical claims?

5. **Evidence requirements**:
   - Must have photo to file claim?
   - Allow claims without evidence?

6. **Claim numbering**:
   - Auto-generate (CLM-001, CLM-002)?
   - Use custom format?

7. **Integration with existing failed deliveries**:
   - Auto-create claim when delivery marked as failed?
   - Keep separate?

---

## 📝 My Recommendation

### Start with Phase 1 (MVP):
```
✅ Admin-only claim filing
✅ Basic types: damaged, missing, wrong items, other
✅ Photo upload (required)
✅ Status: pending → investigating → approved/rejected → resolved
✅ Simple comments
✅ Claims dashboard
✅ Link from delivery details
✅ Refund amount tracking (no automation)
```

### Benefits:
- ✅ Quick to implement (2-3 days)
- ✅ Covers 80% of use cases
- ✅ Foundation for future enhancements
- ✅ Can gather feedback before Phase 2

### What do you think?

---

**Ready to proceed?** Let me know:
1. Which phase to start with
2. Any specific requirements
3. Questions/concerns about the design
4. Changes you'd like to make

Then I'll start building! 🚀
