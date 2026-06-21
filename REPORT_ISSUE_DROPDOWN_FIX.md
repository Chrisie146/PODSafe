# Report Issue Screen - Dropdown Duplicate Fix

**Date**: October 28, 2025  
**Issue**: Dropdown error: "There should be exactly one item with [DropdownButton]'s value: ClaimType.missing"  
**Cause**: Duplicate `ClaimType` values in `enabledTypes` list  
**Status**: ✅ FIXED

---

## Problem

When opening the ReportIssueScreen, a Flutter assertion error occurred:

```
There should be exactly one item with [DropdownButton]'s value: ClaimType.missing.
Either zero or 2 or more [DropdownMenuItem]s were detected with the same value
```

### Root Cause
The `enabledTypes` list from `ClaimProvider.getEnabledClaimTypes()` contained **duplicate `ClaimType` values**. When the dropdown tried to match `_selectedType` to a dropdown item, it found 2 or more items with the same value, causing the assertion to fail.

---

## Solution

Changed the dropdown item mapping to remove duplicates using `.toSet()`:

**BEFORE** (buggy):
```dart
items: enabledTypes.map((type) {
  return DropdownMenuItem(
    value: type,
    child: Text(_getClaimTypeDisplay(type)),
  );
}).toList(),
```

**AFTER** (fixed):
```dart
items: enabledTypes.toSet().map((type) {
  return DropdownMenuItem(
    value: type,
    child: Text(_getClaimTypeDisplay(type)),
  );
}).toList(),
```

### How It Works
- `enabledTypes.toSet()` converts the List to a Set
- Sets automatically remove duplicate values
- `.map()` and `.toList()` convert back to a list of unique DropdownMenuItems
- Result: Each `ClaimType` value appears **exactly once** in the dropdown

---

## Files Modified

| File | Change | Status |
|------|--------|--------|
| `lib/screens/driver/report_issue_screen.dart` | Line 149: Added `.toSet()` to remove dropdown duplicates | ✅ Complete |

---

## Testing

1. Navigate to a delivery
2. Click "Report Issue" button
3. Dropdown should display all claim types without error
4. No assertion error should appear
5. Selecting any claim type should work normally

---

## Compilation

✅ No errors  
ℹ️ 14 info warnings (expected - print statements and BuildContext usage)

---

## Root Cause Analysis

The issue likely originated from:
1. Database containing duplicate enabled claim types
2. Settings not deduplicating the list on load
3. Dropdown requiring unique values

**Prevention**: Consider adding `.toSet().toList()` in `ClaimProvider.getEnabledClaimTypes()` to prevent this at the source, but the current fix is sufficient.

---

**Status**: Ready for testing! 🚀
