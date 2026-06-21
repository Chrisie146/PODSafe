# Bulk Import - Customer Number & Order Number Added

## Issue
Bulk import CSV template was missing `customerNumber` and `orderNumber` fields, which are needed for customer linking and order tracking.

## Solution
Added both fields to the complete bulk import/export system.

## Changes Made

### 1. **Bulk Import Service** (`bulk_import_service.dart`)
- ✅ Added `customerNumber` field to `ParsedDelivery` class
- ✅ Extract `customerNumber` from CSV column
- ✅ Pass `customerNumber` to Delivery model
- ✅ `orderNumber` was already present, now confirmed working

### 2. **CSV Template** (`delivery_export_service.dart`)
- ✅ Added `customerNumber` column to header
- ✅ Added `orderNumber` column to header (moved to better position)
- ✅ Updated example data with sample values:
  - Example 1: `CUST001`, `ORD001`
  - Example 2: `CUST002`, `ORD002`

### 3. **CSV Export Function**
- ✅ Export `customerNumber` from deliveries
- ✅ Export `orderNumber` from deliveries
- ✅ Handle null values gracefully (empty string)

## Updated CSV Format

### Column Order
```csv
customerName,customerAddress,customerPhone,customerNumber,orderNumber,invoiceNumber,...
```

### Example Data
```csv
customerName,customerAddress,customerPhone,customerNumber,orderNumber,invoiceNumber,invoiceTotal,scheduledDate
John Smith,123 Main St,+1234567890,CUST001,ORD001,INV001,625.00,2025-10-20
Jane Doe,456 Oak Ave,+9876543210,CUST002,ORD002,INV002,1612.50,2025-10-21
```

## Field Details

### customerNumber (Optional)
- **Purpose**: Link delivery to customer record in database
- **Format**: Any string (e.g., `CUST001`, `C-12345`, etc.)
- **Use Case**: When using customer management feature
- **Example**: `CUST001`

### orderNumber (Optional)
- **Purpose**: Track order reference from your system
- **Format**: Any string (e.g., `ORD001`, `ORDER-2025-001`, etc.)
- **Use Case**: Link delivery to order in external system
- **Example**: `ORD001`

## Benefits

### Customer Linking
When you import deliveries with `customerNumber`:
- ✅ Automatically links to existing customer in database
- ✅ Can view all deliveries for a customer
- ✅ Customer details auto-populate
- ✅ Better reporting and analytics

### Order Tracking
When you import with `orderNumber`:
- ✅ Track which order the delivery belongs to
- ✅ Search deliveries by order number
- ✅ Link to external order management system
- ✅ Better traceability

## CSV Template Download

The updated template now includes all fields:

**Basic Fields**:
- `customerName` (required)
- `customerAddress` (required)
- `customerPhone` (optional)
- `customerNumber` (optional) ← **NEW**
- `orderNumber` (optional) ← **ADDED**
- `invoiceNumber` (required)

**Monetary Fields**:
- `invoiceTotal` (optional)
- `taxAmount` (optional)
- `discountAmount` (optional)

**Other Fields**:
- `scheduledDate` (required)
- `driverEmail` (optional)
- `notes` (optional)

**Item Fields** (for items 1-10):
- `item#_description`
- `item#_quantity`
- `item#_unit`
- `item#_unitPrice`
- `item#_totalPrice`

## Usage Examples

### Example 1: Simple Delivery with Customer Link
```csv
customerName,customerAddress,customerNumber,invoiceNumber,scheduledDate
Checkers Hyper,100 Store Rd Sandton,CUST-CHECKERS-001,INV2025001,2025-10-21
```

### Example 2: Delivery with Order Tracking
```csv
customerName,customerAddress,orderNumber,invoiceNumber,scheduledDate
Pick n Pay,200 Mall Rd,ORD-PNP-2025-001,INV2025002,2025-10-22
```

### Example 3: Complete Delivery
```csv
customerName,customerAddress,customerPhone,customerNumber,orderNumber,invoiceNumber,invoiceTotal,taxAmount,scheduledDate
Boxer Superstores,300 Plaza St,+27115551234,CUST-BOXER-001,ORD-2025-100,INV2025003,5420.00,813.00,2025-10-23
```

## Backwards Compatibility

### ✅ Old CSV Files
- Files without `customerNumber` column will work
- Files without `orderNumber` column will work
- Both fields are optional
- No import errors if missing

### ✅ Existing Deliveries
- Can export deliveries without customer/order numbers
- Columns will be empty (blank) if no value
- Can add values by editing CSV and re-importing

## Integration with Customer Management

When `customerNumber` is provided:
1. System looks up customer by `customerNumber` field
2. If found, links delivery to that customer record
3. Customer details (address, phone, etc.) can be auto-filled
4. View all deliveries per customer in customer management

## Testing

To test the new fields:
1. Download updated CSV template
2. Notice `customerNumber` and `orderNumber` columns
3. Fill in sample values (or leave blank)
4. Import CSV
5. Verify fields appear in delivery record

## Files Modified
- ✅ `lib/services/bulk_import_service.dart`
- ✅ `lib/services/delivery_export_service.dart`

---

**Status**: ✅ **COMPLETE**
**CSV Template**: Updated with customerNumber and orderNumber columns
**Impact**: Better customer linking and order tracking
**Breaking Changes**: NONE - fully backwards compatible
