# CSV Export Features - Quick Test Guide 🧪

## How to Test

### 1. Download Template

**Steps:**
1. Run the app on **web** (`flutter run -d chrome`)
2. Login as **admin**
3. Go to **Delivery Management** (sidebar menu)
4. Look at top-right corner of app bar
5. Click the **download icon** (⬇️)
6. Select **"Download Template"**

**Expected Result:**
- ✅ Success message appears
- ✅ File downloads: `podsafe_delivery_template_20251017.csv`
- ✅ Open file - see headers and 2 example rows

---

### 2. Export All Deliveries

**Prerequisites:** Have at least 1 delivery in the system

**Steps:**
1. Ensure you're logged in as **admin** with deliveries
2. Go to **Delivery Management**
3. Click the **download icon** (⬇️)
4. Select **"Export All Deliveries"**
5. Wait for loading message

**Expected Result:**
- ✅ Loading message: "Preparing export..."
- ✅ Success message: "Exported X deliveries successfully!"
- ✅ File downloads: `podsafe_deliveries_20251017_HHMMSS.csv`
- ✅ Open file - see all your deliveries with:
  - Customer names
  - Addresses
  - Invoice numbers
  - Scheduled dates
  - Driver emails
  - Items

---

### 3. Verify Export Content

**Open the exported CSV and check:**

✅ **Headers match template:**
```
customerName,customerAddress,customerPhone,invoiceNumber,scheduledDate,driverEmail,notes,item1_description,item1_quantity,item1_unit,item2_description,item2_quantity,item2_unit,item3_description,item3_quantity,item3_unit
```

✅ **Data is correct:**
- Customer names match your deliveries
- Dates in YYYY-MM-DD format (e.g., 2025-10-17)
- Driver emails are populated
- Items are listed

✅ **Special characters handled:**
- Commas in addresses are properly escaped
- Quotes work correctly

---

### 4. Test Edge Cases

#### A. Export with No Deliveries
1. Use a new company account with 0 deliveries
2. Try to export
3. **Expected:** Warning message "No deliveries to export"

#### B. Export with Many Items
1. Create delivery with 3+ items
2. Export
3. **Check:** First 3 items exported, others omitted (current limitation)

#### C. Export with Empty Fields
1. Create delivery with no phone, no notes
2. Export
3. **Check:** Empty columns in CSV (no errors)

---

## 🎯 What to Look For

### ✅ Success Indicators:
- Files download automatically in browser
- Filenames include dates/timestamps
- CSV opens in Excel without errors
- All data is readable and correct
- Driver emails are populated correctly
- No data corruption or encoding issues

### ❌ Potential Issues:
- Files don't download (check browser popup blocker)
- CSV format is broken (check for quote escaping)
- Driver emails missing (check Firestore user data)
- Special characters display incorrectly
- Excel shows encoding errors

---

## 📝 Sample Template Content

When you download the template, you should see:

```csv
customerName,customerAddress,customerPhone,invoiceNumber,scheduledDate,driverEmail,notes,item1_description,item1_quantity,item1_unit,item2_description,item2_quantity,item2_unit,item3_description,item3_quantity,item3_unit
John Smith,123 Main Street City State 12345,+1234567890,INV001,2025-10-17,john@driver.com,Handle with care,Box of Parts,5,boxes,,,,,
Jane Doe,456 Oak Avenue Town State 67890,+9876543210,INV002,2025-10-18,john@driver.com,,Laptop,1,unit,Mouse,2,units,Keyboard,1,unit
```

---

## 🐛 Troubleshooting

### Issue: File doesn't download
**Solution:** 
- Check browser popup blocker
- Try different browser
- Check browser console for errors

### Issue: "Company ID not found" error
**Solution:**
- Make sure you're logged in as admin
- Check admin user has companyId field in Firestore

### Issue: No deliveries exported
**Solution:**
- Verify deliveries exist in Firestore
- Check deliveries have correct companyId
- Look at browser console for Firestore errors

### Issue: Driver emails are blank
**Solution:**
- Check drivers exist in users collection
- Verify drivers have email field
- Look at console logs for driver fetch errors

---

## 🚀 Next Steps After Testing

Once both features work:

1. ✅ Test on different browsers (Chrome, Firefox, Edge)
2. ✅ Test with large datasets (50+ deliveries)
3. ✅ Share with a test user for feedback
4. 📋 Document any issues found
5. 🔄 Move to **Phase 2: Bulk CSV Import**

---

## Quick Command Reference

```bash
# Run on web
flutter run -d chrome

# Hot reload after changes
r

# Check for errors
flutter analyze

# View logs
# (Already visible in VS Code terminal)
```

---

**Ready to test!** Open the app and try both features. Let me know what you see! 🎯

