# Bulk CSV Import - Quick Reference

## 🚀 How to Use (Admin)

### Import Deliveries (3 Easy Steps)

1. **Get to Bulk Upload**
   - Open Delivery Management
   - Click download icon (⬇️)
   - Select "Bulk Upload CSV"

2. **Prepare Your CSV**
   - Option A: Click "Download CSV Template" → Fill in Excel
   - Option B: Use existing CSV file

3. **Upload & Import**
   - Click "Choose CSV File"
   - Review validation results
   - Fix any errors if needed
   - Click "Import All"
   - Done! ✅

---

## 📋 CSV Format

### Required Columns (Must Have)
```
customerName
customerAddress
invoiceNumber
scheduledDate
```

### Optional Columns (Nice to Have)
```
customerPhone
driverEmail
notes
item1_description, item1_quantity, item1_unit
item2_description, item2_quantity, item2_unit
... up to item10
```

### Date Format
**Must be**: `YYYY-MM-DD`  
**Example**: `2025-02-15`  
**NOT**: `2/15/2025` or `15-Feb-2025` ❌

---

## ✅ Validation Checklist

Your CSV will be checked for:
- [ ] All required columns present
- [ ] Customer name filled in
- [ ] Customer address filled in
- [ ] Invoice number filled in (and unique)
- [ ] Date in YYYY-MM-DD format
- [ ] Item quantities are numbers > 0

---

## ❌ Common Errors

| Error | Fix |
|-------|-----|
| Missing required column | Check spelling: customerName, customerAddress, invoiceNumber, scheduledDate |
| Invalid date format | Use YYYY-MM-DD (e.g., 2025-02-15) |
| Duplicate invoice | Make sure all invoice numbers are different |
| Quantity not a number | Item quantities must be numbers like 5, 10, 20 |

---

## 💡 Tips

### Starting Fresh?
1. Download template
2. See 2 example rows
3. Delete examples, add your data
4. Upload

### Have Existing Data?
1. Export your deliveries
2. Modify the CSV
3. Change invoice numbers (make unique!)
4. Re-import

### Large Import?
- CSV supports 100s of deliveries
- Import happens in batches (fast!)
- Takes ~10 seconds for 1,000 deliveries

### Driver Assignment
- Add `driverEmail` column
- Use driver's email from your system
- System auto-assigns if email matches
- Leaves unassigned if no match (no error)

---

## 🎯 Example CSV

### Minimal (Required Only)
```csv
customerName,customerAddress,invoiceNumber,scheduledDate
John Doe,123 Main St,INV-001,2025-02-15
Jane Smith,456 Oak Ave,INV-002,2025-02-16
```

### Complete (With Items)
```csv
customerName,customerAddress,customerPhone,invoiceNumber,scheduledDate,driverEmail,notes,item1_description,item1_quantity,item1_unit
John Doe,123 Main St,555-0100,INV-001,2025-02-15,driver@company.com,Fragile,Laptops,5,boxes
Jane Smith,456 Oak Ave,555-0200,INV-002,2025-02-16,,Rush delivery,Supplies,10,boxes
```

---

## 🔍 Troubleshooting

### "Import All" button is disabled?
→ Fix all red errors first (warnings are OK)

### Deliveries not showing up?
→ Refresh Delivery Management screen

### Wrong driver assigned?
→ Check driver email matches exactly (case doesn't matter)

### Need to undo import?
→ Delete deliveries individually in Delivery Management

### CSV shows weird characters?
→ Save as CSV UTF-8 in Excel

---

## 📊 Time Savings

| Deliveries | Manual Entry | Bulk Import | Time Saved |
|------------|--------------|-------------|------------|
| 10 | 20 minutes | 3 minutes | 85% |
| 50 | 100 minutes | 5 minutes | 95% |
| 100 | 200 minutes | 7 minutes | 96% |

---

## 🆘 Need Help?

### In-App Help
- Click **?** icon on Bulk Upload screen
- Shows step-by-step guide

### Test It First
- Use template with 2 example rows
- Import and verify they appear
- Then import your real data

### Contact Support
- Have your CSV file ready
- Screenshot of any error messages
- We'll help you fix it!

---

## ✨ Pro Tips

1. **Start Small** - Test with 5-10 deliveries first
2. **Use Template** - Easiest way to get format right
3. **Check Dates** - Most common error is date format
4. **Unique Invoices** - System checks for duplicates
5. **Save Often** - Save Excel file as CSV before each upload
6. **Keep Original** - Don't delete source data until verified

---

## 🎓 Training Checklist

For new admins:
- [ ] Understand CSV format (required vs optional)
- [ ] Know date format (YYYY-MM-DD)
- [ ] Practice with template (2 example rows)
- [ ] Learn to read error messages
- [ ] Try export → modify → import workflow
- [ ] Understand driver auto-assignment
- [ ] Know how to verify imported deliveries

---

**Questions?** See full documentation in `BULK_IMPORT_COMPLETE.md`

**Testing?** See test guide in `BULK_IMPORT_TEST_GUIDE.md`
