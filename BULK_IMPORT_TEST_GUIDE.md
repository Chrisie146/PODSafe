# Bulk Import Testing Guide

## Quick Test Procedure

### 1. Download Template Test (30 seconds)
1. Open PODSafe as admin
2. Navigate to **Delivery Management**
3. Click **download icon (⬇️)** in app bar
4. Select **"Bulk Upload CSV"**
5. On Bulk Upload screen, click **"Download CSV Template"**
6. ✅ **Verify**: Template downloads with correct filename
7. Open template in Excel/text editor
8. ✅ **Verify**: Has header row with all required columns
9. ✅ **Verify**: Has 2 example rows with sample data

### 2. Basic Upload Test (2 minutes)
1. Use the downloaded template (with 2 example rows)
2. **Modify the data**:
   - Change `scheduledDate` to future date (e.g., 2025-03-15)
   - Change `driverEmail` to an actual driver email in your system
   - Change `invoiceNumber` to unique values (e.g., TEST-001, TEST-002)
3. Save the file as CSV
4. On Bulk Upload screen, click **"Choose CSV File"**
5. Select your modified CSV
6. ✅ **Verify**: File parses successfully
7. ✅ **Verify**: Shows "2 valid • 0 errors • 0 warnings"
8. ✅ **Verify**: Preview table shows both rows
9. ✅ **Verify**: "Import All" button is enabled
10. Click **"Import All"**
11. Click **"Import"** in confirmation dialog
12. ✅ **Verify**: Success dialog appears
13. ✅ **Verify**: Shows "Successfully imported 2 deliveries!"
14. Click **"OK"**
15. ✅ **Verify**: Returns to Delivery Management
16. ✅ **Verify**: New deliveries appear in "All" tab

### 3. Validation Error Test (2 minutes)
Create a CSV with intentional errors to test validation:

**test_errors.csv**:
```csv
customerName,customerAddress,customerPhone,invoiceNumber,scheduledDate,driverEmail,notes,item1_description,item1_quantity,item1_unit
,123 Main St,555-0100,INV-001,2025-02-15,driver@example.com,Missing name,Laptops,5,boxes
John Doe,,555-0200,INV-002,2025-02-16,,Missing address,Supplies,10,boxes
Jane Smith,456 Oak Ave,555-0300,,2025-02-17,,Missing invoice,Paper,20,boxes
Bob Wilson,789 Elm St,555-0400,INV-004,not-a-date,,Bad date,Pens,abc,boxes
Alice Johnson,321 Pine St,555-0500,INV-005,,,,Markers,15,boxes
```

1. Upload this CSV
2. ✅ **Verify**: Shows 5 errors total
3. ✅ **Verify**: Row 2 error: "Customer name is required"
4. ✅ **Verify**: Row 3 error: "Customer address is required"
5. ✅ **Verify**: Row 4 error: "Invoice number is required"
6. ✅ **Verify**: Row 5 error: "Invalid date format"
7. ✅ **Verify**: Row 6 error: "Scheduled date is required"
8. ✅ **Verify**: "Import All" button is DISABLED
9. Click **"Cancel"**
10. ✅ **Verify**: Returns to file picker prompt

### 4. Duplicate Invoice Test (1 minute)
**test_duplicates.csv**:
```csv
customerName,customerAddress,customerPhone,invoiceNumber,scheduledDate,driverEmail,notes,item1_description,item1_quantity,item1_unit
John Doe,123 Main St,555-0100,DUP-001,2025-02-15,driver@example.com,,Laptops,5,boxes
Jane Smith,456 Oak Ave,555-0200,DUP-001,2025-02-16,driver@example.com,,Supplies,10,boxes
```

1. Upload this CSV
2. ✅ **Verify**: Shows error about duplicate invoice
3. ✅ **Verify**: Error mentions both row numbers
4. ✅ **Verify**: "Import All" button is DISABLED

### 5. Warning Test (1 minute)
**test_warnings.csv**:
```csv
customerName,customerAddress,customerPhone,invoiceNumber,scheduledDate,driverEmail,notes
John Doe,123 Main St,555-0100,WARN-001,2024-01-01,driver@example.com,Past date - no items
```

1. Upload this CSV
2. ✅ **Verify**: Shows 2 warnings:
   - "Scheduled date is in the past"
   - "No items specified for this delivery"
3. ✅ **Verify**: Shows 1 valid delivery (warnings don't block)
4. ✅ **Verify**: "Import All" button is ENABLED
5. ✅ **Verify**: Can still import (warnings are non-critical)

### 6. Large Import Test (3 minutes)
Create a CSV with 50+ deliveries to test batch handling:

**Method**: 
1. Export existing deliveries using "Export All Deliveries"
2. Open exported CSV
3. Modify invoice numbers to make them unique
4. Change dates to future dates
5. Save as new file
6. Upload the file
7. ✅ **Verify**: All rows parse correctly
8. ✅ **Verify**: Preview table shows all deliveries
9. ✅ **Verify**: Import completes successfully
10. ✅ **Verify**: All deliveries created in database

### 7. Driver Assignment Test (2 minutes)
1. Get a valid driver email from your system
2. Create CSV with:
   - Row 1: Valid driver email
   - Row 2: Invalid driver email (e.g., "nonexistent@test.com")
   - Row 3: Empty driver email
3. Upload CSV
4. ✅ **Verify**: All 3 rows parse successfully (no errors)
5. ✅ **Verify**: Preview shows:
   - Row 1: Shows actual driver email
   - Row 2: Shows "Unassigned" (no error)
   - Row 3: Shows "Unassigned"
6. Import deliveries
7. Go to Delivery Management
8. ✅ **Verify**: 
   - Delivery 1: Assigned to correct driver
   - Delivery 2: Status shows unassigned
   - Delivery 3: Status shows unassigned

### 8. Multiple Items Test (2 minutes)
**test_items.csv**:
```csv
customerName,customerAddress,invoiceNumber,scheduledDate,item1_description,item1_quantity,item1_unit,item2_description,item2_quantity,item2_unit,item3_description,item3_quantity,item3_unit
John Doe,123 Main St,ITEM-001,2025-02-15,Laptops,5,boxes,Mice,10,units,Keyboards,8,units
```

1. Upload this CSV
2. ✅ **Verify**: Shows "3 items" in preview
3. Import delivery
4. View delivery details
5. ✅ **Verify**: All 3 items display correctly with quantities and units

### 9. Special Characters Test (1 minute)
**test_special.csv**:
```csv
customerName,customerAddress,invoiceNumber,scheduledDate,notes,item1_description,item1_quantity
"O'Brien, John Jr.",123 Main St #2B,INV-001,2025-02-15,"Handle with care, fragile!","Laptop (15"" screen)",2
```

1. Upload this CSV
2. ✅ **Verify**: Parses correctly
3. ✅ **Verify**: Special characters preserved
4. Import and verify data integrity

### 10. Help Dialog Test (30 seconds)
1. On Bulk Upload screen, click **help icon (?)** in app bar
2. ✅ **Verify**: Help dialog opens
3. ✅ **Verify**: Shows step-by-step instructions
4. ✅ **Verify**: Lists required fields
5. ✅ **Verify**: Lists optional fields
6. Click **"Close"**
7. ✅ **Verify**: Dialog closes

## Test Data Files

### Minimal Valid CSV
```csv
customerName,customerAddress,invoiceNumber,scheduledDate
John Doe,123 Main St,MIN-001,2025-02-15
```

### Complete Valid CSV
```csv
customerName,customerAddress,customerPhone,invoiceNumber,scheduledDate,driverEmail,notes,item1_description,item1_quantity,item1_unit
John Doe,123 Main St,555-0100,COMP-001,2025-02-15,driver@example.com,Fragile items,Laptops,5,boxes
```

### Maximum Items CSV
```csv
customerName,customerAddress,invoiceNumber,scheduledDate,item1_description,item1_quantity,item2_description,item2_quantity,item3_description,item3_quantity,item4_description,item4_quantity,item5_description,item5_quantity,item6_description,item6_quantity,item7_description,item7_quantity,item8_description,item8_quantity,item9_description,item9_quantity,item10_description,item10_quantity
John Doe,123 Main St,MAX-001,2025-02-15,Item1,1,Item2,2,Item3,3,Item4,4,Item5,5,Item6,6,Item7,7,Item8,8,Item9,9,Item10,10
```

## Common Issues & Solutions

### Issue: "Missing required column"
**Solution**: Ensure CSV has exact column names (case-sensitive):
- customerName
- customerAddress
- invoiceNumber
- scheduledDate

### Issue: "Invalid date format"
**Solution**: Use YYYY-MM-DD format exactly (e.g., 2025-02-15, not 2/15/2025)

### Issue: "Duplicate invoice number"
**Solution**: Make sure all invoice numbers are unique within the CSV

### Issue: Template downloads but shows numbers
**Solution**: This was fixed - ensure you have the latest version with UTF-8 encoding

### Issue: Import button disabled
**Solution**: Fix all errors shown in red error section. Warnings (orange) don't block import.

### Issue: Deliveries not appearing
**Solution**: 
1. Check you're viewing the correct company
2. Refresh Delivery Management screen
3. Check "All" tab, not just "Pending"

## Expected Results Summary

| Test | Expected Errors | Expected Warnings | Can Import? |
|------|-----------------|-------------------|-------------|
| Template (2 rows) | 0 | 0 | ✅ Yes |
| Error Test | 5 | 0 | ❌ No |
| Duplicate Test | 1 | 0 | ❌ No |
| Warning Test | 0 | 2 | ✅ Yes |
| Large Import (50+) | 0 | 0 | ✅ Yes |
| Driver Test | 0 | 0 | ✅ Yes |
| Multiple Items | 0 | 0 | ✅ Yes |
| Special Chars | 0 | 0 | ✅ Yes |

## Test Completion Checklist

- [ ] Download template test passed
- [ ] Basic upload test passed
- [ ] Validation error test passed
- [ ] Duplicate invoice test passed
- [ ] Warning test passed
- [ ] Large import test passed
- [ ] Driver assignment test passed
- [ ] Multiple items test passed
- [ ] Special characters test passed
- [ ] Help dialog test passed

---

**All tests should pass** ✅

**Estimated testing time**: 15-20 minutes for complete suite

**Quick smoke test**: Tests 1, 2, 6 only (5 minutes)
