# Driver Claim Filing - Testing Guide

## Quick Test Plan (15 minutes)

### Prerequisites
- ✅ App running on Chrome/Windows
- ✅ Logged in as a driver account
- ✅ Have at least one delivery assigned

---

## Test 1: File Claim at Delivery Site (Immediate) - 5 min

### Steps:
1. **Navigate to Active Deliveries**
   - Go to Driver Dashboard
   - Click on "Active Deliveries" or similar

2. **Select a Delivery**
   - Click on any pending delivery
   - View delivery details

3. **Open Report Issue Screen**
   - Look for "Report Issue" button
   - Click to open claim filing screen

4. **Verify Screen Loads**
   - ✅ Delivery info displayed (customer, address, invoice)
   - ✅ "At Delivery Site" indicator shown
   - ✅ Claim type dropdown populated
   - ✅ Form is interactive

5. **Fill Claim Form**
   - Select claim type: **"Damaged Goods"**
   - Enter description: **"Box was crushed during delivery"**
   - Check affected items: Select 1-2 items from list

6. **Add Evidence** (Optional for now - web camera may not work)
   - Skip photo capture for web testing
   - Skip signature for web testing

7. **Submit Claim**
   - Click "Submit Claim" button
   - Wait for success message
   - Verify navigation back or success dialog

8. **Verify in Firestore**
   - Open Firebase Console
   - Navigate to Firestore Database
   - Look in `companies/{companyId}/claims/` collection
   - Find newly created claim
   - Verify data:
     - ✅ Claim ID format: CLM-2025-0001
     - ✅ Type: damaged
     - ✅ Status: submitted
     - ✅ Description matches
     - ✅ Delivery ID set
     - ✅ Driver ID set
     - ✅ Customer name set
     - ✅ Affected items array populated
     - ✅ Status history created
     - ✅ Timestamps present

---

## Test 2: Custom Fields Display - 3 min

### Steps:
1. **Check Company Settings**
   - Open Firestore Console
   - Navigate to `companies/{companyId}/settings/claims`
   - Check if custom fields are defined for "damaged" claim type

2. **If No Custom Fields**
   - Add a test custom field:
   ```json
   {
     "customFieldsByType": {
       "damaged": [
         {
           "id": "damage_severity",
           "label": "Damage Severity",
           "type": "dropdown",
           "required": true,
           "options": ["Minor", "Moderate", "Severe", "Total Loss"]
         }
       ]
     }
   }
   ```

3. **Refresh App**
   - Reload the claim filing screen
   - Verify custom field appears after claim type selection
   - Test dropdown selection

---

## Test 3: Validation Testing - 3 min

### Test Required Fields
1. **Empty Form Submission**
   - Don't select claim type
   - Click Submit
   - ✅ Verify error message: "Please select claim type"

2. **Empty Description**
   - Select claim type
   - Leave description empty
   - Click Submit
   - ✅ Verify error message about description

3. **No Affected Items**
   - Select claim type
   - Add description
   - Don't check any items
   - Click Submit
   - ✅ Should allow (affected items are optional)

---

## Test 4: Different Claim Types - 4 min

### Test Multiple Types
1. **Shortage**
   - Select "Short Delivered"
   - Description: "Received 8 boxes instead of 10"
   - Affected items: Select some items
   - Submit
   - ✅ Verify claim created with type: shortage

2. **Late Delivery**
   - Select "Late Delivery"
   - Description: "Delivery was 2 hours late"
   - Submit
   - ✅ Verify claim created with type: lateDelivery

3. **Price Error**
   - Select "Price Error"
   - Description: "Invoice amount incorrect"
   - Submit
   - ✅ Verify claim created with type: priceError

---

## Expected Results

### Screen Behavior
- ✅ No console errors
- ✅ Smooth form interactions
- ✅ Proper loading states during submission
- ✅ Success message on completion
- ✅ Proper navigation after submit

### Data in Firestore
- ✅ Claim document created in correct collection
- ✅ Claim ID auto-generated and unique
- ✅ All required fields populated
- ✅ Status set to "submitted"
- ✅ Status history initialized
- ✅ Timestamps accurate
- ✅ Company isolation working (companyId correct)

---

## Known Limitations (Web Testing)

### Camera/Photo Features
- **Issue**: Web browsers may require permissions for camera access
- **Workaround**: Test photo features on mobile/desktop app
- **Impact**: Photo upload testing deferred

### Signature Capture
- **Issue**: Signature pad should work on web but needs mouse/touch
- **Workaround**: Draw simple signature with mouse
- **Impact**: Can test basic functionality

### GPS Location
- **Issue**: Web browsers require HTTPS for geolocation
- **Workaround**: May get permission prompt or error
- **Impact**: GPS may not capture (acceptable for initial test)

---

## Success Criteria

### Must Have ✅
- [x] Screen loads without errors
- [ ] Can select claim type
- [ ] Can enter description
- [ ] Can select affected items
- [ ] Can submit claim
- [ ] Claim appears in Firestore
- [ ] Claim ID generated correctly

### Nice to Have 🔄
- [ ] Photo upload works
- [ ] Signature capture works
- [ ] GPS location captured
- [ ] Custom fields display
- [ ] Evidence quality score calculated

---

## Troubleshooting

### If Screen Doesn't Load
**Check**:
- Console for errors
- Provider initialization (ClaimProvider registered?)
- Company settings exist in Firestore

**Fix**:
- Refresh app
- Check authentication state
- Verify company has claim settings

### If Submit Fails
**Check**:
- Console error messages
- Network tab for Firebase requests
- Firestore security rules

**Fix**:
- Verify user has write permissions
- Check required fields validation
- Test with simpler data first

### If Claim Not in Firestore
**Check**:
- Correct collection path
- Company ID in path
- Security rules allow write

**Fix**:
- Manually check collection path
- Verify companyId from auth
- Test Firestore rules

---

## Test Results Template

### Test Session: [Date/Time]
**Tester**: [Your Name]  
**Platform**: Chrome/Windows/Mobile  
**Build**: Debug/Release  

#### Test 1: Basic Claim Filing
- [ ] PASS / [ ] FAIL
- **Notes**: 

#### Test 2: Custom Fields
- [ ] PASS / [ ] FAIL
- **Notes**: 

#### Test 3: Validation
- [ ] PASS / [ ] FAIL
- **Notes**: 

#### Test 4: Multiple Types
- [ ] PASS / [ ] FAIL
- **Notes**: 

#### Overall Result
- [ ] Ready for next screen (Driver My Claims)
- [ ] Needs fixes (list below)
- [ ] Major issues (block next development)

**Issues Found**:
1. 
2. 
3. 

**Next Steps**:
- 

---

## After Testing

### If All Tests Pass ✅
**Next Steps**:
1. Update todo list: Mark "Fix Driver Report Issue Screen" as COMPLETED
2. Start building "Driver My Claims Screen"
3. Add navigation link to Report Issue screen

### If Tests Fail ❌
**Next Steps**:
1. Document errors in detail
2. Review error logs
3. Fix issues
4. Re-test
5. Repeat until passing

---

## Quick Firestore Check

### Firebase Console Path
```
Firestore Database > Data

companies/
  └── {companyId}/
       └── claims/
            └── {claimId}  ← Look here!
```

### Expected Document Structure
```json
{
  "id": "CLM-2025-0001",
  "companyId": "abc123",
  "type": "damaged",
  "status": "submitted",
  "priority": "medium",
  "title": "Damaged Goods",
  "description": "Box was crushed during delivery",
  "deliveryId": "delivery123",
  "customerId": "INV-001",
  "customerName": "John's Bakery",
  "driverId": "driver123",
  "driverName": "Jane Driver",
  "filedBy": "driver123",
  "filedByName": "Jane Driver",
  "filedByRole": "driver",
  "affectedItems": [
    {
      "description": "Fresh Bread",
      "quantity": 10,
      "unit": "loaves"
    }
  ],
  "statusHistory": [
    {
      "status": "submitted",
      "timestamp": "2025-10-17T...",
      "userId": "driver123",
      "userName": "Jane Driver",
      "notes": "Claim filed"
    }
  ],
  "createdAt": "2025-10-17T...",
  "updatedAt": "2025-10-17T...",
  ...
}
```

---

## Time Estimate

- **Setup**: 2 minutes
- **Test Execution**: 15 minutes
- **Firestore Verification**: 3 minutes
- **Documentation**: 5 minutes

**Total**: ~25 minutes

---

## Notes

- This is initial functionality testing
- Full E2E testing will come later
- Focus on happy path first
- Edge cases can wait
- Photo/signature testing better on mobile

---

## Contact

If issues found, document in:
- `CLAIMS_TESTING_ISSUES.md` (create if needed)
- Or add to conversation for immediate fix
