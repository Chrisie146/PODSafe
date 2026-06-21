# Delayed Evidence Submission Feature - Design Document

## Overview

**Scenario**: A claim is filed without evidence initially, then evidence (photos, signatures, documents) can be uploaded later by either the driver or admin.

### Current Workflow (What We're Changing From)
```
Driver files claim → Adds evidence immediately → Submits claim → Done
```

### New Workflow (What We're Building)
```
Admin creates claim (no evidence needed) 
    ↓
Claim stored in database with status: "Pending Evidence"
    ↓
Driver/Admin uploads evidence when available (photos, signatures, etc.)
    ↓
Claim status updates to: "Evidence Received" or "Complete"
```

---

## Architecture Overview

### 1. **Claim Model Updates Needed**

Current flow assumes evidence is submitted with the claim. We need to support:
- Creating claims WITHOUT evidence
- Adding evidence AFTER claim creation
- Tracking evidence submission status

**Potential new field in Claim model**:
```dart
// Track if evidence is required and if it's been submitted
bool requiresEvidence;           // true = evidence can still be added
bool evidenceSubmitted;          // true = evidence has been uploaded
DateTime? evidenceDeadline;      // Optional deadline for evidence
String evidenceStatus;           // 'pending', 'received', 'complete'
```

### 2. **UI Components Needed**

#### A. **Admin Claim Creation Screen** (New or Modified)
- Fields: Type, Description, Affected Items, Attached Delivery, etc.
- Evidence: OPTIONAL (not required to submit)
- Button: "Create Claim" → Stores with evidence status = "pending"

#### B. **Evidence Upload Screen** (New)
- Shows list of claims needing evidence
- Click a claim → Upload evidence
- Supports: Photos, Signatures, Documents
- Upload to Firebase Storage → Link to claim

#### C. **Dashboard Updates**
- Filter to show "Claims Pending Evidence"
- Quick action: "Upload Evidence"
- Show evidence submission status on each claim

### 3. **Database Structure**

```
companies/{companyId}/claims/{claimId}
├── status: "pending" (existing)
├── evidenceStatus: "pending" | "received" | "complete" (NEW)
├── photoUrls: []
├── customerSignatureUrl: null
├── driverSignatureUrl: null
└── createdAt: timestamp

// Later, when driver uploads:
companies/{companyId}/claims/{claimId}
├── photoUrls: ["gs://...", "gs://..."]
├── customerSignatureUrl: "gs://..."
├── driverSignatureUrl: "gs://..."
├── evidenceStatus: "received"
└── evidenceUpdatedAt: timestamp (NEW)
```

### 4. **Backend Service Updates**

**ClaimService** needs new methods:
```dart
// 1. Create claim without evidence
Future<String> createClaimWithoutEvidence(Claim claim)

// 2. Upload evidence to existing claim
Future<void> uploadEvidenceToClaimId(
  String companyId, 
  String claimId,
  List<File> photos,
  File? signature
)

// 3. Get claims pending evidence
Future<List<Claim>> getClaimsPendingEvidence(String companyId)

// 4. Update evidence status
Future<void> updateEvidenceStatus(
  String companyId,
  String claimId,
  String status  // 'received', 'complete'
)
```

### 5. **Claim Provider Updates**

New getters/methods:
```dart
// Get claims that need evidence
List<Claim> get claimsPendingEvidence => 
  _allClaims.where((c) => c.evidenceStatus == 'pending').toList();

// Count pending evidence
int get pendingEvidenceCount => claimsPendingEvidence.length;

// Upload evidence method
Future<void> uploadEvidenceToClaim(
  String claimId,
  List<File> photos,
  File? signature
)
```

---

## Implementation Steps

### Phase 1: Core Support (Minimal)
1. ✅ Ensure Claim model can be created without evidence
2. ✅ ClaimService method to create claim without evidence
3. ✅ Store claim with `evidenceStatus: 'pending'`
4. ✅ Dashboard shows which claims need evidence

### Phase 2: Evidence Upload UI (Medium)
1. New "Upload Evidence" screen
2. Select claim from list
3. Upload photos, signatures
4. Update claim in database

### Phase 3: Full Integration (Complete)
1. Admin dashboard filter for "Pending Evidence"
2. Bulk evidence upload
3. Evidence submission notifications
4. Evidence audit trail

---

## Questions to Clarify

1. **Who uploads evidence?**
   - Driver? (via driver app)
   - Admin? (via admin dashboard)
   - Both?

2. **Evidence requirement**
   - Is evidence REQUIRED after a certain time?
   - Deadline for evidence submission?
   - What happens if evidence isn't submitted?

3. **Evidence types**
   - Photos only?
   - Signatures?
   - Documents (PDFs, etc.)?
   - All of the above?

4. **Claim status flow**
   - Can a claim be "approved" without evidence?
   - Does evidence update change claim status?
   - Notification when evidence is uploaded?

5. **Integration with existing screens**
   - Keep current Report Issue screen as-is?
   - Add "Create Claim" admin screen separately?
   - Modify Report Issue to have "submit now, add evidence later" option?

---

## Current System Capabilities

**Good News**: The current system already supports much of this!

### What Already Works
✅ Claims can be created with empty evidence arrays
✅ Firebase Storage can host new evidence
✅ Claim model has photoUrls, signatures fields
✅ Dashboard can display claims
✅ Can query and filter claims

### What Needs Development
⏳ Admin claim creation UI (without evidence requirement)
⏳ Evidence upload screen
⏳ Evidence status tracking
⏳ Backend methods for evidence-only updates
⏳ Dashboard filters for "Pending Evidence"

---

## Suggested Approach

**Start with the simplest implementation**:

1. **Admin creates claim via dashboard**
   - New button: "Create Claim" (not from delivery)
   - Minimal fields: Type, Description, Delivery, Delivery Date
   - Evidence: Optional checkboxes (Photos, Signature, etc.)
   - Submit: Creates claim with empty evidence arrays

2. **Evidence Upload**
   - New screen in admin dashboard: "Upload Evidence"
   - List of claims → Click to upload photos/signatures
   - Updates existing claim record with new evidence

3. **Status Tracking**
   - Simple approach: Check if evidence arrays are empty
   - Empty = "Pending Evidence"
   - Not empty = "Has Evidence"

4. **Dashboard Updates**
   - Filter: "Show claims pending evidence"
   - Sort: Claims oldest first (most urgent)
   - Action: "Upload Evidence" link

---

## Data Flow Example

```
1. Admin clicks "New Claim"
   ↓
2. Form: Type=Damaged, Delivery=D-123, Description="Broken box"
   ↓
3. Evidence section: (all optional)
   ☐ Take photos
   ☐ Get signature
   ↓
4. Click "Create Claim"
   ↓
5. Claim saved:
   {
     id: "C-456",
     type: "Damaged",
     description: "Broken box",
     photoUrls: [],
     customerSignatureUrl: null,
     driverSignatureUrl: null,
     status: "submitted",
     evidenceStatus: "pending",
     createdAt: now
   }
   ↓
6. Later, driver sees "Claims Pending Evidence"
   ↓
7. Driver clicks "Upload Evidence for C-456"
   ↓
8. Takes photos, gets signature
   ↓
9. Click "Upload"
   ↓
10. Claim updated:
    {
      ...same as above...
      photoUrls: ["gs://...", "gs://..."],
      customerSignatureUrl: "gs://...",
      evidenceStatus: "received",
      evidenceUpdatedAt: now
    }
```

---

## Files to Modify/Create

### New Files
```
lib/screens/admin/create_claim_screen.dart          (NEW)
lib/screens/admin/upload_evidence_screen.dart       (NEW)
```

### Modified Files
```
lib/models/claim_model.dart                         (Add evidenceStatus fields)
lib/services/claim_service.dart                     (Add evidence upload methods)
lib/providers/claim_provider.dart                   (Add evidence queries)
lib/screens/admin/claims_dashboard_desktop.dart     (Add evidence filters/links)
```

---

## Summary

**What we're building**:
- Admin creates claims without requiring evidence upfront
- Evidence can be uploaded later (asynchronously)
- Dashboard shows which claims need evidence
- Simple status tracking for evidence submission

**Key principle**: Separate the claim creation from evidence collection phases.

Would you like me to:
1. Start with admin claim creation screen?
2. Build the evidence upload screen?
3. Add evidence status tracking to the model?
4. All of the above?

Let me know which part you'd like to tackle first! 🚀
