# OCR Data Inspection Tool

## Quick Methods to Check Extracted OCR Data

### Method 1: Firebase Console (Recommended - Live Data) 🔥

**Navigate to:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your PODSafe project
3. Go to **Firestore Database**
4. Click on **pods** collection
5. Select any POD document that has been recently submitted

**Look for these fields:**
```
pods/
  └── {deliveryId}/
      ├── ocrRawText: "Invoice #123456\nSupplier: ABC Corp\n..."
      ├── ocrFields: {
      │   ├── invoiceNo: "123456"
      │   ├── supplier: "ABC Corp"
      │   ├── customer: "John Doe"
      │   ├── totalIncl: "500.00"
      │   └── driverName: "Driver Name"
      ├── ocrConfidence: 0.92
      └── timestamp: October 21, 2025...
```

**✅ If you see these fields → OCR extraction worked!**

---

### Method 2: Flutter Console Logs 📱

**When submitting a POD, look in the Flutter console/terminal for:**

```
🔍 Starting OCR extraction from delivery proof photo...
✅ OCR extraction complete. Found 1250 characters
📄 OCR Text:
Invoice #123456
Supplier: ABC Corp
Customer: John Doe
Total: R500.00
Driver: James Johnson

📊 OCR Fields Parsed:
  Invoice: 123456
  Supplier: ABC Corp
  Customer: John Doe
  Total: R500.00

✅ OCR data extracted successfully

🆕 OCR Data being saved:
  - Raw Text: 1250 characters
  - Fields: {invoiceNo: 123456, supplier: ABC Corp, ...}
  - Confidence: 0.92
```

**How to see logs:**
1. Open VS Code terminal where Flutter is running
2. Scroll up in terminal output
3. Search for "OCR" or "🔍"

---

### Method 3: Admin Dashboard (Visual Check) 📊

**In the PODSafe Admin App:**

1. **Navigate to POD List**
   - Go to Admin Dashboard
   - View list of delivered PODs

2. **Click on any POD card** to open details

3. **Scroll down** to find the **"📊 OCR Extracted Data"** section

4. **You'll see:**
   - Confidence badge (0-100% with progress bar)
   - Color: Green (✓ high confidence), Orange (! medium), Red (⚠ low)
   - Grid of 4 fields: Invoice, Supplier, Customer, Total
   - Driver Name field
   - Fields will show the extracted values or "Not extracted"

**Example Display:**
```
📊 OCR Extracted Data
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Extraction Confidence
████████░░ 92%

┌─────────────────┬─────────────────┐
│ 📄 Invoice      │ 🏢 Supplier     │
│ INV-2024-001234 │ ACME Suppliers  │
├─────────────────┼─────────────────┤
│ 👤 Customer     │ 💰 Total (Incl) │
│ John Smith      │ R1,250.50       │
└─────────────────┴─────────────────┘

👨‍💼 Driver Name: James Johnson

[Review & Edit Extracted Data]
```

---

### Method 4: Firestore Query (Advanced) 🔍

**Run this in Firebase Console → Firestore → Web → Create Query:**

```javascript
// Get all PODs with OCR data
db.collection('pods')
  .where('ocrFields', '!=', null)
  .get()
  .then(snapshot => {
    snapshot.forEach(doc => {
      console.log('POD:', doc.id);
      console.log('OCR Fields:', doc.data().ocrFields);
      console.log('Confidence:', doc.data().ocrConfidence);
    });
  });
```

---

## What Each OCR Field Means

| Field | Example | Extracted From |
|-------|---------|-----------------|
| **invoiceNo** | INV-2024-001234 | Invoice header/number |
| **supplier** | ACME Suppliers Inc | Company/Supplier name |
| **customer** | John Smith | Customer/Recipient name |
| **totalIncl** | 1250.50 | Total amount with tax |
| **driverName** | James Johnson | Driver signature area/notes |
| **ocrRawText** | Full text of image | All visible text |
| **ocrConfidence** | 0.92 (92%) | Extraction reliability score |

---

## Troubleshooting: What if Data is Missing?

### Scenario 1: `ocrFields` is null or empty
**Possible causes:**
- Photo was too blurry/low quality
- Text in image was too small
- Invoice format not recognized by parser
- ML Kit couldn't extract text

**Solution:**
1. Check `ocrRawText` - if it's also empty, ML Kit didn't extract anything
2. Retake photo with:
   - Better lighting
   - Steady camera angle
   - Invoice/receipt centered in frame
   - Text clearly visible

### Scenario 2: `ocrConfidence` is very low (< 0.65)
**Possible causes:**
- Few fields were successfully extracted
- Text might be partially hidden/damaged

**Solution:**
1. Admin should manually verify the fields
2. Retake photo if data is critical
3. Manually enter data in POD notes

### Scenario 3: Fields show "Not extracted"
**Possible causes:**
- Specific field text not found in image
- Field name format different than expected
- Text quality too low for that field

**Solution:**
1. Check `ocrRawText` to see what was actually found
2. Manually enter the missing field
3. Leave as-is (app doesn't require it)

---

## Live Testing Steps

### Step 1: Take a Test Photo
1. Open Driver App
2. Go to Capture POD
3. **Take a photo of:** Invoice/receipt with clear text
4. **Wait for:** "Invoice data extracted (X% confidence)" message
5. **Note the:** Confidence % shown

### Step 2: Check Flutter Logs
1. Look at terminal/console where Flutter is running
2. Copy the `📊 OCR Fields Parsed:` section
3. Note which fields were found

### Step 3: Submit POD
1. Complete signature and other fields
2. Click **"Submit POD"**
3. Wait for success message

### Step 4: Verify in Firebase
1. Open [Firebase Console](https://console.firebase.google.com)
2. Go to Firestore → pods collection
3. Find the new POD by deliveryId
4. Check the `ocrFields` object
5. **Compare** with what Flutter logs showed

### Step 5: Verify in Admin App
1. Open Admin Dashboard
2. Find the POD you just submitted
3. Click to open details
4. Scroll to "OCR Extracted Data" section
5. Verify all fields display correctly

---

## Example Data Extracted

### Real Example 1: Receipt
```
OCR Raw Text:
"ACME Hardware Store
Invoice #HR-2024-5678
Date: Oct 21, 2024
Customer: John Smith
Items:
- Nails 2kg       R25.00
- Wood Board      R145.00
- Screws Box      R18.50
Subtotal: R188.50
Tax (15%):R28.28
TOTAL: R216.78"

OCR Fields Parsed:
- invoiceNo: "HR-2024-5678"
- supplier: "ACME Hardware Store"
- customer: "John Smith"
- totalIncl: "216.78"
- ocrConfidence: 0.92 (92%)
```

### Real Example 2: Low Confidence
```
OCR Raw Text:
"[Blurry image with partial text]
Invoice #12***56
ACME ~~Something~~ Corp
[Hard to read]"

OCR Fields Parsed:
- invoiceNo: "1256"  (partial match)
- supplier: "ACME"   (partial)
- customer: null     (not found)
- totalIncl: null    (not found)
- ocrConfidence: 0.60 (60% - Low!)
```

---

## Database Query Recipes

### Get all PODs with successful OCR
```javascript
db.collection('pods')
  .where('ocrConfidence', '>=', 0.80)
  .orderBy('ocrConfidence', 'desc')
  .get()
```

### Get PODs with low confidence OCR
```javascript
db.collection('pods')
  .where('ocrConfidence', '<', 0.65)
  .orderBy('timestamp', 'desc')
  .limit(10)
```

### Get all PODs submitted today
```javascript
const today = new Date();
today.setHours(0, 0, 0, 0);

db.collection('pods')
  .where('timestamp', '>=', today)
  .orderBy('timestamp', 'desc')
  .get()
```

---

## Summary

✅ **To see OCR data extracted:**
1. **Easiest:** Open Firebase Console → pods collection → any POD → scroll down
2. **Live:** Check Flutter console logs for "📊 OCR Fields Parsed:"
3. **Visual:** Open Admin App → POD details → scroll to "OCR Extracted Data"

✅ **Look for these fields:**
- `ocrRawText` - Full extracted text
- `ocrFields` - {invoiceNo, supplier, customer, totalIncl, driverName}
- `ocrConfidence` - Confidence score (0.6 to 0.95)

✅ **If they exist → OCR extraction worked!**

---

**Last Updated:** October 21, 2025
**Status:** Ready to inspect OCR data 🔍
