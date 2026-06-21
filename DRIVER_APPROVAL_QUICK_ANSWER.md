# Driver Approval - Quick Answer

## Q: "Who needs to approve new drivers?"

## A: **An ADMIN user needs to approve new drivers.**

---

## Approval Workflow

```
ADMIN creates driver
    ↓
Driver has: approvalStatus = "pending"
    ↓
ADMIN goes to Driver Management → Pending tab
    ↓
ADMIN clicks on driver and chooses:
    - ✅ Approve Driver  OR  ❌ Reject Driver
    ↓
Driver status changes
    ↓
If APPROVED:  Driver can log in and use app
If REJECTED:  Driver cannot log in
```

---

## Key Facts

✅ **Who can approve?** Only ADMINS  
✅ **Auto-approved?** NO - manual approval required  
✅ **When created?** New drivers start as "pending"  
✅ **Where to approve?** Driver Management → Pending tab  
✅ **Can rejected drivers reapply?** Admin can re-approve or delete  

---

## Changes Made Today

1. ✅ **Cloud Function updated** - Now sets `approvalStatus: 'pending'` for drivers
2. ✅ **Create Driver screen updated** - Explicitly sets approval status
3. ✅ **Cloud Function redeployed** - Changes are live

---

## Testing

After hot reload (`r`):

1. Create a test driver
2. Driver appears in "Pending" tab
3. Attempt driver login → Gets blocked (not approved)
4. Admin approves driver
5. Driver can now log in ✅

---

**See:** `DRIVER_APPROVAL_WORKFLOW.md` for complete details
