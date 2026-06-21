# ✅ OCR Workflow Guide - Step by Step

**Issue:** Upload button showing error "Please enter OCR text"  
**Reason:** OCR text field is empty when clicking parse button  
**Solution:** Follow these steps carefully

---

## 🎯 Complete Workflow (5 minutes)

### Step 1: Open "Capture Invoice" Screen
- [ ] From driver dashboard, click "Capture Invoice" button
- [ ] Screen loads with "Step 1: Capture Image"

### Step 2: Upload/Capture Image
- [ ] Click **"Choose from Gallery"** or **"Take Photo"**
- [ ] Select any image
- [ ] Image preview appears
- [ ] Screen now shows "Step 2: Enter Invoice Details"

### Step 3: IMPORTANT - Paste Invoice Text
**This is where the error is happening!**

1. Find the text field labeled **"Enter Invoice Details"**
2. **Clear any existing text** (tap the field, select all, delete)
3. **Copy this exact text:**

```
INVOICE #2024-001-0845
Date: 2024-10-21
Total Incl: R 12,450.75
Total Excl: R 10,809.09
VAT (15%): R 1,641.66

Supplier: ABC Meat Suppliers
Customer: Fresh Foods Ltd
Branch Code: JNB-01
Site Code: SITE-002

Vehicle: TR 21-95 GP
Driver Name: John Smith
Received By: M. Johnson

Total Qty: 250 kg
Total Mass: 250.00 kg

Tax ID: 9876543210
```

4. **Paste into the text field**
5. Make sure you can see the text in the field
6. **Click the "✓ Parse" button** (green button below the text field)

### Step 4: Wait for Parsing
- [ ] Loading indicator appears
- [ ] After 1-2 seconds, fields appear in preview
- [ ] Should show all extracted values

### Step 5: Upload
- [ ] Click the green **"Upload Invoice"** button
- [ ] Wait for upload to complete
- [ ] Success message should appear

---

## ❌ If You Still See Error "Please enter OCR text..."

**This means:**
- The text field is empty when you click "Parse"
- The pasted text didn't actually go into the field

**Fix:**
1. **Don't click anything** - go back to Step 1
2. **Reload the page** (refresh browser or restart app)
3. **Try again carefully** - make sure text actually appears in the field

---

## ✅ Visual Checklist

| Step | What You Should See | Status |
|------|---------------------|--------|
| 1 | "Capture Image" section with 2 buttons | [ ] |
| 2 | Image preview after uploading | [ ] |
| 3 | Text field with invoice details visible | [ ] |
| 4 | Click green "Parse" button | [ ] |
| 5 | Fields extract and show in preview | [ ] |
| 6 | Green "Upload Invoice" button appears | [ ] |
| 7 | Click upload | [ ] |
| 8 | Success message shows | [ ] |

---

## 🆘 Still Not Working?

Try these in order:

1. **Clear Text Field**
   - Tap in the text field
   - Select all (Ctrl+A)
   - Delete
   - Paste the sample text again

2. **Use Simpler Text**
   - Try typing manually instead of pasting
   - Just type: `INVOICE #123` to test

3. **Refresh App**
   - Close the modal
   - Go back to dashboard
   - Click "Capture Invoice" again

4. **Hard Reset**
   - Close and reopen the app
   - Start from Step 1

---

## 📋 Key Fields to Test

When parsing works, you should see these extracted:

| Field | Value |
|-------|-------|
| Invoice Number | 2024-001-0845 |
| Date | 2024-10-21 |
| Total Amount | R 12,450.75 |
| Supplier | ABC Meat Suppliers |
| Vehicle | TR 21-95 GP |
| Driver | John Smith |

---

**The issue is likely just that the text field appears empty when you click parse. Double-check the text actually appears in the field before clicking the green "Parse" button!**
