# Delayed Evidence Submission - Quick Reference

## What We're Building

Claims workflow where:
1. **Admin creates claim** without evidence required
2. **Claim is stored** immediately 
3. **Evidence uploaded later** by driver/admin when available
4. **Status tracked** to show which claims need evidence

---

## Simple Implementation Plan

### Step 1: Update Claim Model
Add evidence tracking fields:
```dart
String evidenceStatus;    // 'pending', 'received', 'complete'
DateTime? evidenceUpdatedAt;
```

### Step 2: Create Admin Claim Screen
Screen where admin can:
- Type: Damaged, Shortage, etc.
- Description: What happened
- Delivery: Which delivery
- Evidence: OPTIONAL (checkbox to add later)
- Button: "Create Claim"

### Step 3: Create Evidence Upload Screen
Screen where driver/admin can:
- See list: "Claims Pending Evidence"
- Click claim: Opens upload form
- Upload: Photos, signatures, documents
- Button: "Submit Evidence"

### Step 4: Dashboard Updates
- New section: "Claims Pending Evidence" with count
- Quick link: "Upload Evidence"
- Filter to show only pending

### Step 5: Database Methods
ClaimService needs:
- `createClaimMinimal()` - Create without evidence
- `uploadEvidenceToClaim()` - Add evidence later
- `getClaimsPendingEvidence()` - Show pending list

---

## Example Flow

```
Admin Dashboard
    ↓ Click "New Claim"
    ↓
Create Claim Form
    Type: Damaged
    Description: Box arrived damaged
    Delivery: D-123
    Evidence: □ (unchecked - not required)
    ↓ Click "Create"
    ↓
Claim Created! ID: C-456
Status: Pending Evidence
    ↓ (Later...)
Driver App
    ↓ See "Upload Evidence" section
    ↓ See "Claim C-456 - Pending Evidence"
    ↓ Click to upload
    ↓
Upload Evidence Form
    Take photos → 3 photos captured
    Get signature → Signature captured
    ↓ Click "Submit Evidence"
    ↓
Evidence uploaded to Claim C-456
Status changed: Now "Has Evidence"
```

---

## Database Schema

```dart
// Claim document in Firestore
{
  id: "C-456",
  type: "damaged",
  description: "Box arrived damaged",
  status: "submitted",
  
  // NEW FIELDS for evidence tracking
  evidenceStatus: "pending",        // pending, received, complete
  evidenceUpdatedAt: null,          // When evidence was uploaded
  evidenceRequiredBy: null,         // Optional deadline
  
  // Evidence fields (can be empty initially)
  photoUrls: [],
  customerSignatureUrl: null,
  driverSignatureUrl: null,
  attachmentUrls: [],
  
  // Metadata
  createdAt: timestamp,
  updatedAt: timestamp,
  deliveryId: "D-123",
  customerId: "CUST-001",
  driverId: "DRV-01"
}
```

---

## Key Differences from Current Flow

### Current (Driver Submits)
```
Driver App
  → Opens Report Issue
  → Adds photos, signature, description
  → Clicks Submit
  → Claim created with evidence
```

### New (Admin Creates, Evidence Later)
```
Admin Dashboard
  → New Claim Form
  → Minimal info (type, description)
  → Click Create (evidence NOT required)
  → Claim stored immediately
  
Later...

Driver/Admin
  → See "Claims Pending Evidence"
  → Upload evidence to claim
  → Evidence linked to existing claim
```

---

## Implementation Complexity

| Component | Complexity | Time | Priority |
|-----------|------------|------|----------|
| Update Claim Model | ⭐ Low | 30min | High |
| Admin Claim Creation | ⭐⭐ Medium | 2hrs | High |
| Evidence Upload Screen | ⭐⭐ Medium | 2hrs | High |
| Dashboard Integration | ⭐ Low | 1hr | Medium |
| Backend Methods | ⭐ Low | 1hr | High |
| **Total** | | **~6 hrs** | |

---

## Next Steps - What Should I Build?

Choose what you want first:

### Option A: Start with Model/Backend
- Update Claim model to track evidence status
- Add backend methods to ClaimService
- Foundation for everything else

### Option B: Start with Admin Screen
- Admin can create claims without evidence
- Can submit basic claim info immediately
- Evidence upload comes later

### Option C: Start with Evidence Upload
- Screen to upload evidence to existing claims
- Assume claims already exist
- Focus on evidence submission flow

### Recommendation
**Start with Option A + B**: Update model, then build admin claim creation. Then add evidence upload. This gives a complete workflow.

---

## Questions for You

1. **Who creates claims?**
   - Admin only?
   - Driver can also create?
   - Both?

2. **Evidence requirement**
   - Can claims be APPROVED without evidence?
   - Is there a deadline for evidence?
   - What if evidence never arrives?

3. **Access level**
   - Can driver upload evidence to any claim?
   - Or only their own delivery claims?

4. **Evidence types**
   - Photos only?
   - Signatures?
   - PDF documents?
   - All?

5. **Notifications**
   - Notify driver when claim created?
   - Notify admin when evidence uploaded?

---

## Status

📋 **Design**: Complete
🔨 **Implementation**: Ready to start
⏳ **Timeline**: 6 hours for full feature
✅ **Complexity**: Medium (straightforward extension of current system)

Ready to build! Let me know which component to start with! 🚀
