# Claims Filters - Troubleshooting Quick Guide

## The Most Common Issue: Field Names Don't Match

### Problem
Claims in Firestore might have the data stored under different field names than we're checking in the filter.

### Solution Check List

#### ✅ Verify Customer Number Fields in Firestore

1. Open Firebase Console → your project
2. Go to Firestore Database → companies → [your-company] → claims
3. Click on a claim document
4. Look for these fields:
   - `customerNumber`
   - `customerAccountNumber`
   - `customerName`

**If you see the data under a DIFFERENT name**, we need to update the filter logic.

#### ✅ Verify Invoice Number Field

In the same claim document, look for:
- `invoiceNumber`

**If it's named something else like** `invoice_number` **or** `invoiceNum`, we need to update the filter.

#### ✅ Verify Order Number Storage

1. Look at a **NEWLY CREATED** claim (created AFTER we added the fix)
2. In the claim document, look for field:
   - `metadata` → `orderNumber`

**If it's not there**, the metadata wasn't stored when the claim was created.

---

## Quick Fixes (If Needed)

### If Customer Number is Stored as `customerAccountNumber` Only

**Current code checks**:
```dart
claim.customerNumber?.toLowerCase()... ||
claim.customerAccountNumber?.toLowerCase()...
```

**If customerNumber is always null**, no problem! The OR will still match on customerAccountNumber.

**But if it's stored under a COMPLETELY DIFFERENT NAME**, we need to add it:

```dart
// In claim_provider.dart, around line 302-308, CHANGE THIS:
final matches = (claim.customerNumber?.toLowerCase().contains(query) ?? false) ||
                (claim.customerAccountNumber?.toLowerCase().contains(query) ?? false);

// TO THIS (if field is named differently):
final matches = (claim.customerNumber?.toLowerCase().contains(query) ?? false) ||
                (claim.customerAccountNumber?.toLowerCase().contains(query) ?? false) ||
                (claim.metadata['customerNumber']?.toLowerCase().contains(query) ?? false);  // Add this line
```

### If Claim Fields Are Named With Underscores

**If Firestore has**: `customer_number` (not `customerNumber`)

The problem is that our Claim model is expecting `customerNumber`.

Check `lib/models/claim_model.dart` line 318 and verify it matches what's in Firestore.

### If Metadata Isn't Stored for Order Number

**For OLD claims**: No metadata, so order filter will only work on deliveryId
**For NEW claims**: Should have metadata

If NEW claims still don't have metadata, check `lib/screens/driver/report_issue_screen.dart` line 769 was added correctly.

---

## The REAL Issue (My Theory)

Looking at the code, I believe the actual problem might be:

### When creating a claim in `report_issue_screen.dart`:

We have:
```dart
customerNumber: widget.delivery.customerNumber,
```

This is pulling from the **Delivery** object. If the **Delivery** doesn't have `customerNumber` populated, then the **Claim** won't either!

**Check**: In the Delivery model (`lib/models/delivery_model.dart`), does it have a `customerNumber` field?

Line 51 shows it does:
```dart
final String? customerNumber;    // For quick lookup and reporting
```

**So if your deliveries don't have customer numbers**, the claims won't either!

### Solution:
**Check in Firestore if your Delivery documents have the `customerNumber` field populated.**

Go to: `companies → [your-company] → deliveries → [any-delivery]`

Look for `customerNumber` field. If it's empty/missing, that's why the filter isn't working!

---

## Step-by-Step Debugging

### Step 1: Check Data Quality

```
1. Open Firebase Console
2. Go to your deliveries collection
3. Pick a delivery
4. Is customerNumber populated? YES/NO
5. Is orderNumber populated? YES/NO
```

### Step 2: Check Claim Creation

```
1. Go to Claims collection
2. Pick a claim created AFTER the fix
3. Check the metadata field
4. Does it have orderNumber? YES/NO
```

### Step 3: Run App with Debug Output

```
1. flutter run -d chrome
2. Open Claims Dashboard
3. Open browser console (F12)
4. Type "BOX" in Customer # filter
5. Look for [DEBUG] messages
6. Share what you see
```

### Step 4: Analyze Debug Output

Look for messages like:
```
[DEBUG] Customer number filter REJECTED: customerNumber=null, customerAccountNumber=null, query=box
```

This shows the fields are EMPTY, not that the filter logic is wrong!

---

## If the Problem is "No Matching Data"

### Most Likely Cause: Missing Source Data

Your claims don't have the fields populated because:

1. **Deliveries don't have customer numbers** → Claims inherit null → Filter can't match
2. **Claims were created with bad data** → Fields not set when claim created
3. **Firestore schema changed** → Field names don't match

### Solution:

**Ensure data exists in your test deliveries/claims**:

1. In Firebase Firestore:
   - Edit a Delivery document
   - Add `customerNumber` field (e.g., "BOX001")
   - Add `orderNumber` field (e.g., "ORD-2024-001")
   - Save

2. Create a new claim using that delivery
3. Try filtering again

---

## If Filter Seems to Work But Returns Wrong Results

### Check: Is it using OLD filters or NEW filters?

The code has TWO places where filtering could happen:

**1. In Provider (our new code):**
- File: `lib/providers/claim_provider.dart`
- Method: `_applyFilters()`
- Applies: All active filters (status, type, customer #, order #, etc.)

**2. In Dashboard (old code for export):**
- File: `lib/screens/admin/claims_dashboard_desktop.dart`
- Method: `_exportClaimsAsPDF()` and `_exportClaimsAsCSV()`
- Applies: Only status, type, search filters (doesn't use new filters!)

**The main table uses Provider filters (correct!)** ✅

But if you export to PDF/CSV, it might use old filters and not include your advanced filters!

---

## How to Verify Filters Are Running

### Test 1: Clear Filters Button

1. Set Customer # to "BOX"
2. Click "Clear Advanced Filters"
3. All claims should reappear
4. If they don't, filters aren't connected

### Test 2: Multiple Filters

1. Set Customer # to "BOX"
2. Set Invoice # to "INV"
3. Only claims matching BOTH should show
4. If claims show that don't match both, logic error

### Test 3: Invalid Search

1. Set Customer # to "XYZABC123" (nonsense)
2. Zero claims should show
3. If claims still show, filter isn't working

---

## Summary: Most Likely Problems (In Order)

| # | Problem | Likelihood | Fix |
|---|---------|------------|-----|
| 1 | Claims don't have customer number in source data | 70% | Add data to deliveries in Firestore |
| 2 | Field names don't match (e.g., `customer_number` vs `customerNumber`) | 15% | Check model, update filter logic |
| 3 | Filter logic error (inverted OR/AND) | 10% | Review debug output, fix logic |
| 4 | UI not connected to provider | 3% | Check onChanged callback firing |
| 5 | Provider not notifying listeners | 2% | Check notifyListeners() is called |

**My Recommendation**: Start with **#1 - Check your source data quality**!

---

**Next**: Run the debug version, share console output, and we'll pinpoint the exact issue! 🚀
