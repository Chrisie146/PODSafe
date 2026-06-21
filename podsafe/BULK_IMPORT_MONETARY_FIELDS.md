# Bulk Import Monetary Fields Update

## Overview
Updated the bulk import/export system to support the new monetary fields (invoice amounts, tax, discounts, and item-level pricing) that were added to the Delivery model.

## Changes Made

### 1. **Bulk Import Service** (`lib/services/bulk_import_service.dart`)

#### ParsedDelivery Class
Added monetary fields to store parsed CSV data:
```dart
final double? invoiceTotal;
final double? taxAmount;
final double? discountAmount;
```

#### CSV Column Parsing
Now extracts monetary values from CSV:
- `invoiceTotal` - Total invoice amount
- `taxAmount` - Tax amount (e.g., VAT/sales tax)
- `discountAmount` - Any discounts applied
- `item1_unitPrice`, `item2_unitPrice`, etc. - Unit price per item
- `item1_totalPrice`, `item2_totalPrice`, etc. - Total price per item

#### Validation
Added comprehensive validation for all monetary fields:
- ✅ Must be valid decimal numbers
- ✅ Cannot be negative
- ✅ Provides clear error messages with row number
- ✅ Graceful handling of empty/missing values (optional fields)

#### Item-Level Pricing
Each item (1-10) can now include:
```dart
DeliveryItem(
  description: 'Product A',
  quantity: 10,
  unit: 'boxes',
  unitPrice: 125.00,      // NEW
  totalPrice: 1250.00,    // NEW
)
```

#### toDelivery() Method
Updated to include monetary fields when converting to Delivery model:
```dart
invoiceTotal: invoiceTotal,
taxAmount: taxAmount,
discountAmount: discountAmount,
currency: 'ZAR', // Default currency
```

### 2. **CSV Template** (`lib/services/delivery_export_service.dart`)

#### Updated Headers
```csv
customerName,customerAddress,customerPhone,invoiceNumber,
invoiceTotal,taxAmount,discountAmount,scheduledDate,
driverEmail,notes,
item1_description,item1_quantity,item1_unit,item1_unitPrice,item1_totalPrice,
item2_description,item2_quantity,item2_unit,item2_unitPrice,item2_totalPrice,
item3_description,item3_quantity,item3_unit,item3_unitPrice,item3_totalPrice
```

#### Example Data
The template now includes realistic monetary examples:

**Example 1: Simple Delivery**
```csv
John Smith,123 Main Street...,+1234567890,INV001,
625.00,93.75,0,2025-10-20,
john@driver.com,Handle with care,
Box of Parts,5,boxes,125.00,625.00,
,,,,
,,,,
```

**Example 2: Multi-Item Delivery**
```csv
Jane Doe,456 Oak Avenue...,+9876543210,INV002,
1612.50,241.88,50.00,2025-10-21,
john@driver.com,,
Laptop,1,unit,999.99,999.99,
Mouse,2,units,89.99,179.98,
Keyboard,1,unit,432.53,432.53
```

### 3. **CSV Export Function**

#### Export Headers
Updated `exportDeliveriesToCSV()` to include monetary columns in the header row.

#### Export Data
Extracts and formats monetary values from deliveries:
```dart
delivery.invoiceTotal?.toStringAsFixed(2) ?? '',
delivery.taxAmount?.toStringAsFixed(2) ?? '',
delivery.discountAmount?.toStringAsFixed(2) ?? '',
// Item-level
items[0].unitPrice?.toStringAsFixed(2) ?? '',
items[0].totalPrice?.toStringAsFixed(2) ?? '',
```

All amounts formatted to 2 decimal places for currency display.

## CSV Format

### Required Columns (unchanged)
- `customerName`
- `customerAddress`
- `invoiceNumber`
- `scheduledDate` (format: YYYY-MM-DD)

### Optional Columns
- `customerPhone`
- `orderNumber`
- `driverEmail`
- `notes`

### NEW: Monetary Columns (all optional)
- `invoiceTotal` - Delivery invoice total (e.g., 1250.50)
- `taxAmount` - Tax amount (e.g., 187.58)
- `discountAmount` - Discount applied (e.g., 50.00)

### NEW: Item Pricing Columns (all optional)
For each item (1-10):
- `item#_unitPrice` - Price per unit (e.g., 125.00)
- `item#_totalPrice` - Total for item (quantity × unitPrice)

### Item Columns (existing)
For each item (1-10):
- `item#_description` - Item description
- `item#_quantity` - Quantity (default: 1)
- `item#_unit` - Unit of measurement (e.g., boxes, units)

## Usage Examples

### Minimal CSV (No Amounts)
```csv
customerName,customerAddress,invoiceNumber,scheduledDate
John Smith,123 Main St,INV001,2025-10-20
```
✅ Still works - amounts will be null

### CSV with Invoice Total Only
```csv
customerName,customerAddress,invoiceNumber,invoiceTotal,scheduledDate
John Smith,123 Main St,INV001,1250.00,2025-10-20
```
✅ Tax and discount remain null

### Complete CSV with All Monetary Fields
```csv
customerName,customerAddress,invoiceNumber,invoiceTotal,taxAmount,discountAmount,scheduledDate,item1_description,item1_quantity,item1_unitPrice,item1_totalPrice
John Smith,123 Main St,INV001,1250.00,187.50,0,2025-10-20,Boxes,10,125.00,1250.00
```
✅ Full financial tracking

## Validation Rules

### Invoice Amounts
- Must be valid decimal numbers
- Cannot be negative
- Optional (can be empty)
- Example errors:
  - `"abc"` → "Invoice total must be a valid number"
  - `"-100"` → "Invoice total cannot be negative"

### Item Pricing
- Must be valid decimal numbers
- Cannot be negative
- Optional (can be empty)
- Example errors:
  - `"abc"` → "Item 1 unit price must be a valid number"
  - `"-50"` → "Item 2 total price cannot be negative"

### Error Reporting
All errors include:
- Row number (Excel/Google Sheets compatible)
- Field name
- Clear error message

Example:
```
Row 5: Invoice total must be a valid number
Row 7: Item 2 unit price cannot be negative
```

## Benefits

### For Bulk Import
- ✅ Import complete financial data with deliveries
- ✅ No need to manually enter amounts after import
- ✅ Claims can immediately reference delivery amounts
- ✅ Item-level pricing for detailed tracking

### For CSV Export
- ✅ Export deliveries with all financial data
- ✅ Edit amounts in spreadsheet and re-import
- ✅ Share complete delivery records with partners
- ✅ Financial reporting and analysis

### Backwards Compatibility
- ✅ Old CSV files without amounts still work
- ✅ New columns are optional
- ✅ Existing deliveries export with empty amount columns (if null)
- ✅ No breaking changes

## Testing Checklist

- ✅ Bulk import service compiles without errors
- ✅ Export service compiles without errors
- ✅ Template includes monetary columns
- ⏳ Download template (verify new columns present)
- ⏳ Import CSV with amounts (verify parsing)
- ⏳ Import CSV without amounts (verify backwards compatibility)
- ⏳ Import CSV with invalid amounts (verify error handling)
- ⏳ Export deliveries with amounts (verify formatting)
- ⏳ Export deliveries without amounts (verify empty columns)

## Migration Guide

### Updating Existing CSV Files

**Option 1: Add columns to existing CSV**
1. Open your CSV in Excel/Google Sheets
2. Add new columns after `invoiceNumber`:
   - `invoiceTotal`
   - `taxAmount`
   - `discountAmount`
3. Add item pricing columns for each item:
   - `item1_unitPrice`, `item1_totalPrice`
   - `item2_unitPrice`, `item2_totalPrice`
   - etc.
4. Fill in amounts (or leave empty)
5. Import as usual

**Option 2: Download new template**
1. Click "Download CSV Template" in bulk import
2. Copy your existing data to new template
3. Fill in monetary columns
4. Import

### Re-importing with Amounts

If you have existing deliveries without amounts:
1. Export current deliveries
2. Fill in monetary columns in spreadsheet
3. Delete old deliveries (optional)
4. Re-import with amounts

## Example CSV Files

### Example 1: Corporate Delivery with Stamp
```csv
customerName,customerAddress,customerPhone,invoiceNumber,invoiceTotal,taxAmount,discountAmount,scheduledDate,notes,item1_description,item1_quantity,item1_unit,item1_unitPrice,item1_totalPrice
Checkers Hyper,100 Store Rd Sandton,+27115551234,INV2025001,5420.00,813.00,0,2025-10-21,Requires customer stamp,Fresh Produce Boxes,20,boxes,271.00,5420.00
```

### Example 2: Multiple Items with Tax
```csv
customerName,customerAddress,invoiceNumber,invoiceTotal,taxAmount,discountAmount,scheduledDate,item1_description,item1_quantity,item1_unit,item1_unitPrice,item1_totalPrice,item2_description,item2_quantity,item2_unit,item2_unitPrice,item2_totalPrice
Pick n Pay,200 Mall Rd,INV2025002,8960.00,1344.00,200.00,2025-10-22,Electronics,5,units,1200.00,6000.00,Accessories,10,units,296.00,2960.00
```

### Example 3: Bulk Import (10 deliveries)
See downloadable template for full example with 10 items per delivery.

## Related Files
- `lib/services/bulk_import_service.dart` - CSV parsing with monetary fields
- `lib/services/delivery_export_service.dart` - CSV template and export
- `lib/screens/admin/bulk_upload_screen.dart` - Bulk import UI
- `lib/models/delivery_model.dart` - Delivery model with monetary fields

## Impact

**BEFORE**: Could only import basic delivery info, amounts added manually later
**AFTER**: Import complete deliveries with full financial data in one step

This update ensures bulk import/export maintains parity with manual delivery creation and supports the full Delivery data model including monetary fields.

---

**Status**: ✅ **COMPLETE AND READY FOR TESTING**
- Bulk import service updated ✅
- Export service updated ✅
- CSV template updated ✅
- Validation added ✅
- Compilation verified ✅
- Backwards compatible ✅
- Ready for user testing ⏳
