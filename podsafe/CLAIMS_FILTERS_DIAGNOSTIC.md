# Claims Advanced Filters - Diagnostic Guide

## Debugging Filter Issues

Debug logging has been added to help diagnose filter problems. When you test the filters, check the console/debug output for these messages:

### What to Look For

#### 1. Filter Rejection Debug Messages

When a claim is filtered OUT, you'll see messages like:
```
[DEBUG] Customer number filter REJECTED: customerNumber=BOX001, customerAccountNumber=null, query=acme
[DEBUG] Customer name filter REJECTED: customerName=ABC Corp, query=xyz
[DEBUG] Invoice number filter REJECTED: invoiceNumber=INV-2024-001, query=2025
[DEBUG] Order number filter REJECTED
```

#### 2. Order Number Filter Debug

For order number filtering, you'll see detailed debug info:
```
[DEBUG] Order filter check: query=ORD-12345, deliveryId=deliv_abc123, metadataOrderNumber=ORD-12345, deliveryMatch=false, metadataMatch=true
```

This shows:
- `query`: What user typed
- `deliveryId`: The claim's delivery ID
- `metadataOrderNumber`: Order number stored in claim metadata
- `deliveryMatch`: Whether deliveryId contains the query
- `metadataMatch`: Whether metadata order number contains the query

#### 3. Final Filter Count

```
[DEBUG] Filtered claims: 5 out of 25
```

Shows how many claims passed all filters vs total claims.

---

## Troubleshooting Steps

### Issue: Customer Number Filter Returns Nothing

**Check These Debug Messages:**

1. **Does the claim have the right customer number?**
   ```
   [DEBUG] Customer number filter REJECTED: customerNumber=BOX001, customerAccountNumber=null, query=box
   ```
   - customerNumber should match your search query
   - Check if it's NULL (meaning field not populated in claim)

2. **Is the search case-sensitive?**
   - Searches are case-INSENSITIVE (converted to lowercase)
   - "BOX001" should match "box" query

3. **Is there no customer number in the claim?**
   - Check if `customerNumber` is NULL
   - If NULL, try `customerAccountNumber` field instead
   - Or check what value is actually stored in Firestore

---

### Issue: Order Number Filter Returns Nothing

**Check These Debug Messages:**

1. **Which field matched/didn't match?**
   ```
   [DEBUG] Order filter check: 
     query=ORD-123
     deliveryId=deliv_abc
     metadataOrderNumber=ORD-12345
     deliveryMatch=false
     metadataMatch=true
   ```
   - If `deliveryMatch=true`: Query matched the deliveryId
   - If `metadataMatch=true`: Query matched the stored order number
   - If both are false: Claim will be filtered out

2. **Is metadata order number populated?**
   - If `metadataOrderNumber=null`: Order number wasn't stored when claim was created
   - Only NEW claims created after the fix will have this
   - OLD claims won't have metadata order number

3. **Does deliveryId contain the order number?**
   - If `deliveryId=deliv_abc` and query is `abc`: Will match
   - Searches for substring match, not exact match

---

## Data Quality Checks

### For New Claims (Created After Filter Implementation)

These claims should have:
```
metadata: {
  'orderNumber': 'ORD-12345'  // or the delivery ID if no order number
}
```

### For Old Claims (Created Before Filter Implementation)

These claims will NOT have metadata, but filtering still works via:
- `deliveryId` for order number search
- `customerNumber` and `customerAccountNumber` for customer number search

---

## Console Output Example

**Scenario: User types "BOX" in Customer # field**

```
[DEBUG] Order filter check: query=box, deliveryId=deliv_123, metadataOrderNumber=ORD-5678, deliveryMatch=false, metadataMatch=false
[DEBUG] Filtered claims: 3 out of 10
```

This means:
- User searched for "box" (lowercase)
- 3 claims have a customer number containing "box"
- 7 claims were filtered out

---

## Common Issues and Solutions

| Issue | Debug Message | Solution |
|-------|---------------|----------|
| No results when searching customer # | `customerNumber=null` | Check if field is populated in Firestore claim document |
| No results for order number | `metadataOrderNumber=null` | Old claim - no metadata. Filter uses deliveryId instead |
| Filter seems to work on some claims | Different messages for each claim | Check data quality - some claims may not have the field |
| All claims filtered out | Multiple REJECTED messages | One filter is too restrictive - clear other filters |

---

## How to Read the Debug Output

### Step 1: Run the app with Flutter in debug mode
```bash
flutter run -d chrome
```

### Step 2: Open browser's Developer Console (F12)
Look in the "Console" tab

### Step 3: Filter claims in the dashboard
Type in a filter field and watch for debug messages

### Step 4: Examine the messages

**If you see:**
```
[DEBUG] Customer number filter REJECTED
```
→ That filter rejected this claim

**If you DON'T see that message for a claim:**
→ That claim passed this filter

**If you see:**
```
[DEBUG] Filtered claims: 0 out of 25
```
→ No claims matched ALL active filters

---

## Removing Debug Output (Production)

When ready for production, remove the `print()` statements from `claim_provider.dart` lines ~300-345 in the `_applyFilters()` method.

Or use a flag:
```dart
const bool _enableFilterDebug = false;  // Set to false in production

if (_enableFilterDebug) {
  print('[DEBUG] Order filter check: ...');
}
```

---

## Quick Test Cases

### Test 1: Customer Number Filter
1. Open console (F12)
2. Type "BOX" in Customer # field
3. Should see either:
   - `[DEBUG] Filtered claims: X out of Y` (success)
   - `[DEBUG] Customer number filter REJECTED` (this claim doesn't match)

### Test 2: Order Number Filter
1. Open console (F12)
2. Type an order number in Order # field
3. Should see:
   - `[DEBUG] Order filter check: query=YOUR_QUERY, metadataOrderNumber=..., deliveryMatch=..., metadataMatch=...`
   - `[DEBUG] Filtered claims: X out of Y`

### Test 3: Multiple Filters
1. Set Customer # to "BOX"
2. Set Order # to "ORD"
3. Should see both filter checks
4. Final result should show claims matching BOTH filters

---

## Next Steps

1. **Test the filters with debug console open**
2. **Share console output** if filters still don't work correctly
3. **Verify data in Firestore** for test claims
4. **Check if old vs new claims** work differently

This debug output will help identify exactly what's happening with your filters!
