# 🎯 Phase 2 OCR Testing - Quick Start Guide

**Status:** DocumentIntakeScreen route is now accessible  
**How to Access:** Direct URL navigation OR add button to driver dashboard  
**Time to Complete Testing:** 15-20 minutes  

---

## 🚀 Step 1: Access the OCR Screen

### Option A: Direct Navigation (Web/Chrome)
If app is running on Chrome, navigate to:
```
http://localhost:5000/#/driver/document-intake
```

### Option B: Direct Navigation (Mobile/Android)
If you're testing on physical device or emulator, you can:
1. Open app dev menu (shake device or press 'D' in Android)
2. Find the navigation debugging option
3. Or add a test button to driver dashboard (see below)

### Option C: Add Test Button to Driver Dashboard
Look for the driver's main dashboard and add this button:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.pushNamed(context, '/driver/document-intake');
  },
  child: const Text('📸 Capture Invoice'),
),
```

---

## ✅ Test Sequence (15 minutes)

### Step 1: Screen Loads (2 min)
- [ ] Navigate to `/driver/document-intake`
- [ ] Screen loads without errors
- [ ] Title shows "Capture Invoice" or similar
- [ ] See step indicators (1, 2, 3, 4)

**Expected:** Clean screen with capture/upload UI

---

### Step 2: Image Capture (3 min)

**Test Camera:**
- [ ] Tap "Take Photo" button
- [ ] Camera opens (or grant permission if asked)
- [ ] Capture any image
- [ ] Image preview shows in form

**Test Gallery:**
- [ ] Tap "Choose Gallery" button  
- [ ] File picker opens
- [ ] Select any invoice/document image
- [ ] Image preview displays

**Expected:** Image preview visible, no errors

---

### Step 3: OCR Text Parsing (5 min)

**Copy This Sample Invoice Text:**
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

**In App:**
- [ ] Find text input field for "OCR Text" or "Paste Invoice"
- [ ] Paste the sample text above
- [ ] Tap "Parse" or "Extract" button
- [ ] Wait 1-2 seconds for parsing

**Expected:** 
- Loading indicator briefly shows
- Form transitions to review step
- No error messages

---

### Step 4: Review Extracted Fields (5 min)

**Look for these sections:**

**Primary Fields (most important - should be red/highlighted):**
- [ ] Invoice Number: `2024-001-0845`
- [ ] Date: `2024-10-21`
- [ ] Total Amount: `R 12,450.75`
- [ ] VAT: `R 1,641.66`

**Secondary Fields (should be orange/highlighted):**
- [ ] Supplier: `ABC Meat Suppliers`
- [ ] Customer: `Fresh Foods Ltd`
- [ ] Branch: `JNB-01`
- [ ] Vehicle: `TR 21-95 GP`
- [ ] Driver: `John Smith`

**Additional Fields (yellow/highlighted):**
- [ ] Received By: `M. Johnson`
- [ ] Quantity: `250 kg`
- [ ] Mass: `250.00 kg`
- [ ] Tax ID: `9876543210`

**Quality Indicators:**
- [ ] Confidence score shows (e.g., "92% Confident")
- [ ] Signature badge shows (probably gray = not detected)
- [ ] Stamp badge shows (probably gray = not detected)

**Expected:** All fields populated, quality badges visible

---

### Step 5: Edit Fields (2 min)

- [ ] Tap on any field (e.g., Invoice Number)
- [ ] Field becomes editable (text box appears)
- [ ] Change value (e.g., 0845 → 0846)
- [ ] Tap outside to save
- [ ] Field updates with new value

**Expected:** Edit works smoothly, no errors

---

### Step 6: Upload Document (3 min)

- [ ] Tap "Upload" or "Submit" button
- [ ] See loading indicator
- [ ] After 2-3 seconds, success message appears
- [ ] Success message shows POD ID or status

**Expected Output:**
```
✅ Document Saved Successfully!
POD ID: xyz123abc
Status: Pending
```

---

### Step 7: Test Again (New Document)

- [ ] Tap "Capture New Document" or similar button
- [ ] Form resets completely
- [ ] All fields clear
- [ ] Image preview clears
- [ ] Back to Step 1

**Expected:** Fresh form ready for next invoice

---

## 🎉 Success Criteria

If you checked all boxes above, **Phase 2 OCR is working!**

### ✅ All Working:
- Screen navigates correctly
- Image capture works
- OCR parsing extracts fields
- Fields display in preview
- Upload completes successfully
- Form resets

---

## ⚠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| **Route not found** | Rebuild app (`flutter clean` then `flutter run`) |
| **Image preview not showing** | Check camera permissions in app settings |
| **Fields not parsing** | Make sure text matches sample format |
| **Upload fails** | Check internet connection and Firebase rules |
| **Confidence score wrong** | This is normal - regex patterns aren't perfect |

---

## 📊 What Gets Tested

✅ **Phase 2 Functionality:**
- Image capture (camera/gallery)
- OCR text input
- Regex field extraction
- PodPreviewCard widget rendering
- Field editing capability
- Firebase upload

❌ **Not Tested Yet (Phase 3+):**
- Admin review dashboard
- Approval/rejection workflow
- PDF generation
- Auto-matching to delivery

---

## 🚀 Next Steps After Testing

If all tests pass:

1. **Option A:** Show to a trial customer
   - Have them capture real invoices
   - Gather feedback on UX

2. **Option B:** Move to Phase 3
   - Build admin dashboard for review
   - Create approval workflow
   - Implement status management

3. **Option C:** Add More Regex Patterns
   - Test with different invoice formats
   - Improve accuracy for your use cases

---

## 📝 Notes

- Sample invoice format is based on meat supplier format
- You may need to adjust regex patterns for your invoice types
- Confidence scores are estimates based on field detection
- In production, consider ML Kit for better accuracy

---

**Ready to test? Start with Step 1! 🎯**
