# QR Code System - End-to-End Testing Guide

**Test Date:** October 19, 2025  
**Status:** Ready for Testing  
**Estimated Time:** 20-30 minutes

---

## 🎯 Testing Objectives

1. ✅ Verify token generation on POD capture
2. ✅ Verify QR code display in driver UI
3. ✅ Verify QR code scanning and URL opening
4. ✅ Verify public POD view displays correctly
5. ✅ Verify token validation and security
6. ✅ Verify error handling

---

## 🛠️ Prerequisites

### Required Setup
- [ ] Flutter app running (`flutter run -d chrome` or device)
- [ ] Firebase project configured (podsafe-92a3e)
- [ ] Firestore rules deployed ✅
- [ ] Test driver account created
- [ ] Mobile device with camera (for QR scanning)

### Test Data Needed
- [ ] Test company registered
- [ ] Test driver registered and approved
- [ ] At least one test customer
- [ ] At least one test delivery created

---

## 📋 Test Plan

### Phase 1: Token Generation (5 min)

#### Test 1.1: Create Test Delivery
```
✅ Steps:
1. Log in as admin
2. Navigate to Deliveries → Create Delivery
3. Fill in:
   - Customer: Test Customer
   - Order #: TEST-001
   - Invoice #: INV-001
   - Delivery address
   - Scheduled date: Today
4. Assign to test driver
5. Save delivery

✅ Expected Result:
- Delivery created successfully
- Status: Pending
- Assigned to driver

🔍 Verify:
- Delivery visible in admin dashboard
- Delivery visible in driver dashboard
```

#### Test 1.2: Capture POD
```
✅ Steps:
1. Log in as driver
2. Open test delivery
3. Click "Start Delivery" → Status changes to "In Transit"
4. Click "Capture Proof of Delivery"
5. Take photo (or upload test image)
6. Draw signature
7. Add delivery notes (optional)
8. Click "Submit POD"

✅ Expected Result:
- Loading dialog appears
- Success dialog displays
- "View QR Code" button visible

🔍 Verify in Firebase Console:
1. Open Firestore Database
2. Check 'pods' collection:
   - New POD document created
   - Contains: photoUrl, signatureUrl, timestamp, customerName, etc.
3. Check 'pod_tokens' collection:
   - New token document created
   - deliveryId matches test delivery
   - token is 32 characters
   - isActive = true
   - expiresAt is ~90 days in future
   - accessCount = 0

📊 Success Criteria:
✅ POD document exists with all fields
✅ Token document exists with correct deliveryId
✅ Token is active and not expired
✅ Delivery status = 'delivered'
```

---

### Phase 2: QR Code Display (5 min)

#### Test 2.1: View QR from Success Dialog
```
✅ Steps:
1. After POD submission, click "View QR Code" button
2. Observe QR code dialog

✅ Expected Result:
- Dialog opens with QR code
- Title: "POD QR Code"
- QR code displays clearly
- URL shown below QR: https://podsafe.app/pod/[deliveryId]?token=[token]
- "Copy URL" button visible
- "Download" button visible
- Token expires date shown

🔍 Verify:
- Click "Copy URL" → URL copied to clipboard
- Paste URL → Verify format: /pod/[id]?token=[32chars]
- Click "Download" → PNG file downloads
- PNG file contains QR code (can scan it)
```

#### Test 2.2: View QR from Delivery Details
```
✅ Steps:
1. Close QR dialog and success dialog
2. Navigate back to driver dashboard
3. Find delivered test delivery
4. Click to open delivery details
5. Scroll down to action buttons
6. Click "View QR Code" button

✅ Expected Result:
- QR code dialog opens
- Same QR code as before
- All buttons work

📊 Success Criteria:
✅ "View QR Code" button visible for delivered deliveries
✅ Button NOT visible for pending/in-transit deliveries
✅ QR code matches original
```

#### Test 2.3: View QR from Delivery List
```
✅ Steps:
1. Go back to driver dashboard
2. Click "Delivered" tab
3. Find test delivery in list
4. Look for QR code icon next to status badge
5. Click QR icon

✅ Expected Result:
- QR code dialog opens instantly
- Same QR code displayed
- No need to open full delivery details

📊 Success Criteria:
✅ QR icon visible on delivered deliveries only
✅ QR icon NOT visible on other tabs (Pending, In Transit)
✅ One-tap access to QR code
```

---

### Phase 3: QR Code Scanning (5 min)

#### Test 3.1: Scan with Mobile Device
```
✅ Steps:
1. Open mobile camera app (or QR scanner app)
2. Point camera at QR code on screen
3. Wait for QR code to be recognized
4. Tap notification/link to open URL

✅ Expected Result:
- Camera recognizes QR code
- URL notification appears
- Tapping opens URL in browser

🔍 Verify URL:
- URL format: https://podsafe.app/pod/[deliveryId]?token=[token]
- deliveryId matches test delivery
- token is 32 characters
```

#### Test 3.2: Manual URL Access (Web Testing)
```
✅ Steps:
1. Copy QR URL from app
2. Open new browser tab
3. Paste URL (modify for local testing):
   - Change: https://podsafe.app → http://localhost:5000/#
   - Final URL: http://localhost:5000/#/pod/[deliveryId]?token=[token]
4. Press Enter

✅ Expected Result:
- Page loads
- Shows loading indicator
- Then displays public POD view

⚠️ Note: For web testing, use local URL format with hash routing
```

---

### Phase 4: Public POD View (10 min)

#### Test 4.1: Valid Token - View POD
```
✅ Steps:
1. Access public POD URL (from QR scan or manual entry)
2. Observe page loading

✅ Expected Display:
- Loading spinner appears briefly
- Page transitions to POD view
- Header shows: "Proof of Delivery"
- Green "DELIVERED" status badge with checkmark
- Delivery Information card:
  ✓ Delivery ID
  ✓ Customer name
  ✓ Order number
  ✓ Invoice number
  ✓ Delivery address
- Delivery Photo section:
  ✓ Full-size photo displays
  ✓ Photo is clear and correct
- Signature section:
  ✓ Signature displays
  ✓ Signature is correct
- Location Details section:
  ✓ Latitude shown
  ✓ Longitude shown
  ✓ Accuracy shown (in meters)
- Delivery Notes (if added):
  ✓ Notes display correctly
- Download button:
  ✓ Button visible (may not work yet - future feature)

📊 Success Criteria:
✅ All delivery information displays correctly
✅ Customer name matches test data
✅ Photo displays correctly
✅ Signature displays correctly
✅ GPS coordinates shown
✅ UI is responsive and looks good
✅ No error messages
```

#### Test 4.2: Invalid Token - Access Denied
```
✅ Steps:
1. Copy valid QR URL
2. Modify token parameter:
   - Change last few characters
   - Example: ...token=abc123xyz → ...token=abc123BAD
3. Access modified URL

✅ Expected Result:
- Page loads
- Shows loading briefly
- Displays error view:
  - Red error icon
  - "Access Denied" heading
  - "Invalid or expired access token" message
  - No POD data visible

📊 Success Criteria:
✅ Invalid token rejected
✅ Error message displayed
✅ No sensitive data leaked
✅ User-friendly error message
```

#### Test 4.3: Expired Token (Manual Test)
```
⚠️ Note: Token expiration is 90 days by default, so natural expiration testing isn't practical.

Option 1: Modify Token Manually in Firestore
1. Open Firebase Console → Firestore
2. Find token document in 'pod_tokens'
3. Update 'expiresAt' field to past date
4. Try accessing POD URL

Option 2: Deactivate Token via Service
1. In driver app, call: PODTokenService().deactivateToken(token)
2. Try accessing POD URL

✅ Expected Result:
- Access denied error
- "Expired or inactive token" message

📊 Success Criteria:
✅ Expired tokens rejected
✅ Inactive tokens rejected
✅ Clear error message
```

#### Test 4.4: Missing Token Parameter
```
✅ Steps:
1. Copy POD URL
2. Remove ?token=... parameter
3. Access URL: /pod/[deliveryId]

✅ Expected Result:
- Route doesn't match
- Falls back to unknown route handler
- Redirects to splash screen or shows 404

📊 Success Criteria:
✅ Missing token handled gracefully
✅ No app crash
✅ User redirected to safe page
```

---

### Phase 5: Token Validation & Security (5 min)

#### Test 5.1: Access Count Tracking
```
✅ Steps:
1. Access public POD URL (valid token)
2. Refresh page 2-3 times
3. Check Firestore 'pod_tokens' collection
4. Find token document
5. Check 'accessCount' field

✅ Expected Result:
- accessCount increases with each view
- lastAccessedAt timestamp updates

📊 Success Criteria:
✅ Access count tracked
✅ Timestamp updated on each access
✅ Useful for analytics
```

#### Test 5.2: Cross-Delivery Token Security
```
✅ Steps:
1. Create second test delivery
2. Capture POD for second delivery
3. Get token for second delivery
4. Try using second delivery's token with first delivery's ID:
   - URL: /pod/[delivery1-id]?token=[delivery2-token]
5. Access URL

✅ Expected Result:
- Token validation fails
- Error: "Invalid token for this delivery"
- Access denied

📊 Success Criteria:
✅ Token must match specific deliveryId
✅ Can't use token from different delivery
✅ Security enforced at Firestore level
```

#### Test 5.3: Firestore Rules Validation
```
✅ Steps:
1. Open Firebase Console → Firestore
2. Go to Rules tab
3. Click "Rules Playground"
4. Test scenarios:

Scenario A: Read pod_tokens (public)
- Operation: get
- Path: /pod_tokens/[any-token]
- Auth: None
- Result: ✅ Allowed

Scenario B: Write pod_tokens (public)
- Operation: create
- Path: /pod_tokens/new-token
- Auth: None
- Result: ❌ Denied

Scenario C: Read POD with valid token
- Operation: get
- Path: /pods/[pod-id]
- Auth: None
- Result: ✅ Allowed (permissive - validation in app)

Scenario D: Write POD (public)
- Operation: create
- Path: /pods/new-pod
- Auth: None
- Result: ❌ Denied

📊 Success Criteria:
✅ Public can read tokens
✅ Public cannot create tokens
✅ Public can read PODs (token validated in app)
✅ Public cannot write PODs
```

---

### Phase 6: Error Handling & Edge Cases (5 min)

#### Test 6.1: Network Offline
```
✅ Steps:
1. Access valid POD URL
2. Wait for page to load
3. Turn off network/WiFi
4. Refresh page

✅ Expected Result:
- Error message displayed
- "Failed to load POD data"
- Friendly error UI

📊 Success Criteria:
✅ Graceful offline handling
✅ User-friendly error message
✅ No app crash
```

#### Test 6.2: Non-Existent Delivery
```
✅ Steps:
1. Create valid token URL
2. Modify deliveryId to non-existent ID:
   - Example: /pod/FAKE-DELIVERY-ID?token=[valid-token]
3. Access URL

✅ Expected Result:
- Page loads
- Token validation fails (wrong delivery)
- Error: "Delivery not found" or "Invalid token"

📊 Success Criteria:
✅ Non-existent deliveries handled
✅ Clear error message
✅ No data leakage
```

#### Test 6.3: Very Long Token
```
✅ Steps:
1. Create URL with excessively long token
2. Access URL

✅ Expected Result:
- URL parses correctly (or fails gracefully)
- Token validation fails
- Error displayed

📊 Success Criteria:
✅ No buffer overflow or crash
✅ Graceful handling of malformed tokens
```

---

## 📊 Test Results Template

### Test Execution Summary

**Date:** _______________  
**Tester:** _______________  
**Environment:** Development / Staging / Production

| Test Case | Status | Notes |
|-----------|--------|-------|
| 1.1 Create Test Delivery | ⬜ Pass / ❌ Fail | |
| 1.2 Capture POD | ⬜ Pass / ❌ Fail | |
| 2.1 View QR from Success Dialog | ⬜ Pass / ❌ Fail | |
| 2.2 View QR from Delivery Details | ⬜ Pass / ❌ Fail | |
| 2.3 View QR from Delivery List | ⬜ Pass / ❌ Fail | |
| 3.1 Scan with Mobile Device | ⬜ Pass / ❌ Fail | |
| 3.2 Manual URL Access | ⬜ Pass / ❌ Fail | |
| 4.1 Valid Token - View POD | ⬜ Pass / ❌ Fail | |
| 4.2 Invalid Token - Access Denied | ⬜ Pass / ❌ Fail | |
| 4.3 Expired Token | ⬜ Pass / ❌ Fail | |
| 4.4 Missing Token Parameter | ⬜ Pass / ❌ Fail | |
| 5.1 Access Count Tracking | ⬜ Pass / ❌ Fail | |
| 5.2 Cross-Delivery Token Security | ⬜ Pass / ❌ Fail | |
| 5.3 Firestore Rules Validation | ⬜ Pass / ❌ Fail | |
| 6.1 Network Offline | ⬜ Pass / ❌ Fail | |
| 6.2 Non-Existent Delivery | ⬜ Pass / ❌ Fail | |
| 6.3 Very Long Token | ⬜ Pass / ❌ Fail | |

**Overall Status:** ✅ All Pass / ⚠️ Some Failures / ❌ Major Issues

**Critical Bugs Found:** _______________

**Non-Critical Issues:** _______________

---

## 🚀 Quick Test Command

For rapid testing in development:

```bash
# Run app in Chrome
flutter run -d chrome --web-port=5000

# Then navigate to (replace with actual IDs):
http://localhost:5000/#/pod/YOUR-DELIVERY-ID?token=YOUR-TOKEN-HERE
```

---

## 📸 Screenshots to Capture

1. ✅ POD capture success dialog with "View QR Code" button
2. ✅ QR code dialog showing code and URL
3. ✅ QR code icon on delivered delivery in list
4. ✅ Mobile device scanning QR code
5. ✅ Public POD view with all information displayed
6. ✅ Error view for invalid token
7. ✅ Firestore pod_tokens collection showing generated token
8. ✅ Firestore pods collection showing captured POD data

---

## ✅ Sign-Off

**Tested By:** _______________  
**Date:** _______________  
**Signature:** _______________

**Approved for Production:** ⬜ Yes / ⬜ No / ⬜ With Changes

**Notes:** _______________________________________________

---

**Status:** 📋 READY FOR TESTING  
**Estimated Time:** 20-30 minutes  
**Next Action:** Begin Phase 1 - Token Generation

