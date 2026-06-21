# Claims Filters - Customer Number & Order Number Hidden

## What Changed

The **Customer #** and **Order #** filters have been hidden from the UI for now while we investigate the issues.

### Hidden Filters
- ❌ **Customer #** filter - Commented out in `_buildFilterBar()`
- ✅ **Customer Name** filter - Still visible and active
- ✅ **Invoice #** filter - Still visible and active
- ❌ **Order #** filter - Commented out in `_buildFilterBar()`

### Visible Filters
The dashboard now shows only:
1. **Status** (dropdown)
2. **Type** (dropdown)
3. **Date Range** (date picker)
4. **Customer Name** (text input)
5. **Invoice #** (text input)

### Backend Status
✅ All backend filter logic is still in place and working
✅ The provider still has all 4 filter fields, getters, setters, and filter logic
✅ The code can be easily re-enabled later

---

## How to Re-Enable Later

When the filters are working correctly, re-enable them by uncommenting the code:

### In `lib/screens/admin/claims_dashboard_desktop.dart`

**Line ~520-530**: Uncomment Customer # filter
```dart
// Change from:
// _buildAdvancedFilterField(
//   controller: _customerNumberController,
//   ...

// Back to:
_buildAdvancedFilterField(
  controller: _customerNumberController,
  ...
```

**Line ~540-550**: Uncomment Order # filter
```dart
// Change from:
// _buildAdvancedFilterField(
//   controller: _orderNumberController,
//   ...

// Back to:
_buildAdvancedFilterField(
  controller: _orderNumberController,
  ...
```

**Line ~560**: Update Clear button visibility check
```dart
// Change from:
if (_customerNameController.text.isNotEmpty ||
    _invoiceNumberController.text.isNotEmpty)

// Back to:
if (_customerNumberController.text.isNotEmpty ||
    _customerNameController.text.isNotEmpty ||
    _invoiceNumberController.text.isNotEmpty ||
    _orderNumberController.text.isNotEmpty)
```

---

## Files Modified

✅ `lib/screens/admin/claims_dashboard_desktop.dart`
- Commented out Customer # filter UI
- Commented out Order # filter UI
- Updated Clear button visibility check

---

## Backend Code Still Available

All the filter infrastructure is still in place:

**`lib/providers/claim_provider.dart`**
- `_customerNumberFilter` field (line ~26)
- `_orderNumberFilter` field (line ~28)
- `setCustomerNumberFilter()` method (line ~230)
- `setOrderNumberFilter()` method (line ~245)
- Filter logic in `_applyFilters()` (lines ~302-310, ~327-344)

**`lib/screens/driver/report_issue_screen.dart`**
- Order number stored in metadata when creating claims (line ~769)

This code remains untouched and can be re-enabled whenever needed.

---

## Current Visible Filters

### 1. **Customer Name** (Text Input)
- Searches: `claim.customerName`
- Works by: Substring match (case-insensitive)
- Example: Type "ABC" to find "ABC Corp"

### 2. **Invoice #** (Text Input)
- Searches: `claim.invoiceNumber`
- Works by: Substring match (case-insensitive)
- Example: Type "INV-2024" to find "INV-2024-001"

### 3. **Status** (Dropdown)
- Filters by: Exact status match
- Options: Submitted, Pending Review, Approved, etc.

### 4. **Type** (Dropdown)
- Filters by: Exact claim type match
- Options: Damaged, Shortage, Missing, Wrong Items, etc.

### 5. **Date Range** (Date Picker)
- Filters by: Claims between start and end date
- Inclusive range

---

## Debug Output

Debug logging is still active in the backend. When you use the visible filters, you'll see console output showing:
- Which claims matched which filters
- Final filtered count

To disable debug output for production, remove the `print('[DEBUG]...` statements from `lib/providers/claim_provider.dart` lines ~300-345.

---

## Status

✅ **Compilation**: 0 errors
✅ **UI**: Clean and simple with 5 active filters
✅ **Backend**: All functionality preserved for later re-enablement
✅ **Data**: No data loss or changes

**Ready to test**: Yes, run `flutter run -d chrome`

---

## Why We Did This

The Customer # and Order # filters had issues:
1. Data quality concerns (fields might not be populated in source deliveries)
2. Metadata storage might not work as expected
3. Required more investigation and debugging

By hiding them temporarily, we:
- Allow you to use the dashboard with working filters
- Keep all the code intact for later debugging
- Don't lose any functionality or data
- Can focus on the core filtering features that are working

---

## Next Steps When Ready

1. Debug the Customer # and Order # filters
2. Verify data in Firestore (check if fields are populated)
3. Re-enable the filters with working logic
4. Test thoroughly before re-releasing

---

**Status**: ✅ COMPLETE AND READY TO USE
**Hidden Filters**: 2 (Customer #, Order #)
**Active Filters**: 5 (Status, Type, Date Range, Customer Name, Invoice #)
**Backend Code**: 100% preserved for later re-enablement
