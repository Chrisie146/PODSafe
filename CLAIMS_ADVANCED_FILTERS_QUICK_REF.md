# Claims Advanced Filters - Quick Reference Guide

## What's New?

Added 4 new text-based filters to the Claims Dashboard:

| Filter | Searches | Example |
|--------|----------|---------|
| **Customer #** | Customer account number | `BOX001`, `ACME999` |
| **Customer Name** | Customer business name | `ABC Corp`, `XYZ Ltd` |
| **Invoice #** | Invoice number | `INV-2024-001` |
| **Order #** | Delivery/Order ID | `ORD-12345` |

## Where to Find Them

In `lib/screens/admin/claims_dashboard_desktop.dart`:
- **Advanced filter text fields** appear in a new row below the primary filter bar
- **Icons**: Numbers, Person, Description, Local Shipping
- **Width**: Each field is 180px with proper spacing

## How They Work

1. **Type in a field** → Filter updates automatically
2. **Click "X" button** → Clear that specific filter
3. **Click "Clear Advanced Filters"** → Clear all 4 filters at once
4. **Combine with other filters** → Works with Status, Type, Date Range, Search

## Key Implementation Details

### Backend (claim_provider.dart)
```dart
// New fields
String? _customerNumberFilter;
String? _customerNameFilter;
String? _invoiceNumberFilter;
String? _orderNumberFilter;

// Setters (called by UI)
setCustomerNumberFilter(String? value)
setCustomerNameFilter(String? value)
setInvoiceNumberFilter(String? value)
setOrderNumberFilter(String? value)

// Filter logic in _applyFilters()
// All searches are case-insensitive substring matches
```

### Frontend (claims_dashboard_desktop.dart)
```dart
// New controllers for text fields
_customerNumberController
_customerNameController
_invoiceNumberController
_orderNumberController

// Helper method to build filter fields
_buildAdvancedFilterField()

// Method to clear all advanced filters
_clearAdvancedFilters()
```

## Filter Combinations

**All filters use AND logic** - A claim must match ALL active filters to appear.

Example:
- Status = "Pending" AND
- Customer Name = "ABC" AND
- Invoice # = "INV-2024" 
- → Only pending claims from "ABC Corp" with invoice starting with "INV-2024"

## UI Elements

### Advanced Filter Row
```
[Customer #] [Customer Name] [Invoice #] [Order #]  [Clear Advanced Filters]
```

Each field has:
- Icon (for visual identification)
- Placeholder text (field label)
- "X" button (clear individual field)
- Focused border color (app theme color)

### Visibility
- "Clear Advanced Filters" button only shows when at least one field has text
- Styled in red for distinction from other buttons

## Testing Features

To verify the implementation works:

1. **Type in Customer # field** → Claims filtered by customer account number
2. **Type in Customer Name field** → Claims filtered by customer name
3. **Type in Invoice # field** → Claims filtered by invoice number
4. **Type in Order # field** → Claims filtered by delivery/order ID
5. **Type in multiple fields** → Only claims matching ALL filters shown
6. **Click "X" button** → That filter field cleared, list updates
7. **Click "Clear Advanced Filters"** → All 4 fields cleared at once
8. **Combine with Status dropdown** → Both filters work together
9. **Export filtered results** → PDF/CSV includes only filtered claims
10. **Multi-select with filters** → Multi-select works on filtered list

## Data Model Reference

These filters map to Claim model fields:

```dart
class Claim {
  String? customerAccountNumber;  // Used by "Customer #" filter
  String customerName;             // Used by "Customer Name" filter
  String? invoiceNumber;           // Used by "Invoice #" filter
  String deliveryId;               // Used by "Order #" filter
}
```

## Code Patterns Used

### Pattern 1: Filter setter in provider
```dart
void setCustomerNumberFilter(String? customerNumber) {
  _customerNumberFilter = customerNumber;
  _applyFilters();
}
```

### Pattern 2: Filter check in _applyFilters()
```dart
if (_customerNumberFilter != null && _customerNumberFilter!.isNotEmpty) {
  final query = _customerNumberFilter!.toLowerCase();
  if (!(claim.customerAccountNumber?.toLowerCase().contains(query) ?? false)) {
    return false;
  }
}
```

### Pattern 3: UI integration
```dart
_buildAdvancedFilterField(
  controller: _customerNumberController,
  label: 'Customer #',
  icon: Icons.numbers,
  onChanged: (value) {
    context.read<ClaimProvider>().setCustomerNumberFilter(value.isEmpty ? null : value);
  },
)
```

## Files Changed

| File | Changes |
|------|---------|
| `lib/providers/claim_provider.dart` | +4 fields, +4 getters, +4 setters, updated clearFilters(), enhanced _applyFilters() |
| `lib/screens/admin/claims_dashboard_desktop.dart` | +4 controllers, updated dispose(), refactored _buildFilterBar(), +2 new methods |

## Performance

- ✅ Real-time filtering (instant updates)
- ✅ Substring matching (efficient searches)
- ✅ No network calls (all local filtering)
- ✅ Memory safe (controllers properly disposed)
- ✅ No compilation errors

## Known Limitations

- Filters are case-insensitive only for ASCII characters
- Substring matching (not full-text search with stemming)
- No wildcard support (* or ?)
- Order # filter searches deliveryId directly (not order numbers from delivery document)

## Future Ideas

- [ ] Auto-complete suggestions as user types
- [ ] Save filter presets
- [ ] Filter history
- [ ] Export filtered results to PDF/CSV
- [ ] Regex pattern support for advanced users
- [ ] Numeric range filters

---

**Implementation Status**: ✅ Complete
**Compilation Status**: ✅ 0 Errors
**Production Ready**: ✅ Yes
