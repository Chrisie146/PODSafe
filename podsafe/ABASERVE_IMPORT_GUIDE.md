# Abaserve Import Guide for PODSafe

## 📋 Overview

This guide explains how to export deliveries from your Abaserve ERP system and import them into PODSafe for driver dispatch and proof-of-delivery tracking.

---

## 🎯 Quick Start

### Step 1: Export from Abaserve

1. Log into your Abaserve system
2. Navigate to **Deliveries** > **Scheduled Deliveries**
3. Filter deliveries by date (e.g., tomorrow's deliveries)
4. Click **"Export to CSV"** button
5. Save the CSV file to your computer

### Step 2: Import to PODSafe

1. Log into PODSafe Admin Dashboard
2. Click **"Import from Abaserve"** button
3. Click **"Upload CSV File"**
4. Select your exported CSV file
5. Review validation results
6. Click **"Import Deliveries"** to complete

---

## 📊 CSV Format Requirements

### Required Columns

Your Abaserve CSV export must include these columns:

| Column Name | Description | Example |
|-------------|-------------|---------|
| `customerName` | Customer or business name | `Acme Butchery` |
| `customerAddress` | Full delivery address | `12 Main Rd, Cape Town, 8001` |
| `invoiceNumber` | Invoice or delivery note number | `INV-003248` |
| `scheduledDate` | Delivery date (YYYY-MM-DD format) | `2025-10-26` |
| `driverEmail` | Driver's PODSafe email address | `driver1@company.com` |
| `item1_description` | First product name/SKU | `Beef Rump A Grade (BEEF001)` |
| `item1_quantity` | Quantity for first item | `40` |
| `item1_unit` | Unit of measure | `KG`, `EA`, `BOX` |

### Optional Columns

| Column Name | Description | Example |
|-------------|-------------|---------|
| `customerPhone` | Contact phone number | `+27-21-555-0100` |
| `customerNumber` | Customer account code | `C-019` |
| `orderNumber` | Sales order number | `SO-20498` |
| `invoiceDate` | Invoice date (YYYY-MM-DD) | `2025-10-25` |
| `vehicleReg` | Vehicle registration | `CF12345` |
| `notes` | Special delivery instructions | `Urgent - client closes at 3pm` |
| `item1_unitPrice` | Price per unit (optional) | `95.00` |

### Multiple Items

You can include up to **10 items** per delivery:
- `item1_description`, `item1_quantity`, `item1_unit`, `item1_unitPrice`
- `item2_description`, `item2_quantity`, `item2_unit`, `item2_unitPrice`
- ... up to `item10`

Leave unused item columns empty.

---

## 📝 Sample CSV Template

```csv
customerName,customerAddress,customerPhone,customerNumber,orderNumber,invoiceNumber,invoiceDate,scheduledDate,driverEmail,vehicleReg,notes,item1_description,item1_quantity,item1_unit,item1_unitPrice,item2_description,item2_quantity,item2_unit,item2_unitPrice
Acme Butchery,"12 Main Rd, Cape Town, 8001",+27-21-555-0100,C-019,SO-20498,INV-003248,2025-10-25,2025-10-26,driver1@company.com,CF12345,Urgent delivery,Beef Rump A (BEEF001),40,KG,95.00,Beef Sirloin (BEEF023),25.5,KG,145.00
Fresh Meats Ltd,"45 Industrial Ave, Durban",+27-31-555-0200,C-042,SO-20499,INV-003249,2025-10-25,2025-10-27,driver2@company.com,CF12346,,Pork Loin (PORK008),55,KG,85.00,,,
```

---

## ⚙️ Abaserve Export Configuration

### Recommended SQL Query for Export

If you have database access, use this query to generate the CSV:

```sql
SELECT 
    c.customer_name AS customerName,
    CONCAT(o.address1, ', ', o.city, ', ', o.postal_code) AS customerAddress,
    c.phone AS customerPhone,
    c.customer_code AS customerNumber,
    o.erp_order_no AS orderNumber,
    o.invoice_number AS invoiceNumber,
    DATE_FORMAT(o.invoice_date, '%Y-%m-%d') AS invoiceDate,
    DATE_FORMAT(d.scheduled_date, '%Y-%m-%d') AS scheduledDate,
    dr.email AS driverEmail,
    v.registration AS vehicleReg,
    o.notes,
    -- Item 1
    MAX(CASE WHEN l.line_no = 1 THEN CONCAT(l.description, ' (', l.sku, ')') END) AS item1_description,
    MAX(CASE WHEN l.line_no = 1 THEN l.quantity END) AS item1_quantity,
    MAX(CASE WHEN l.line_no = 1 THEN l.uom END) AS item1_unit,
    MAX(CASE WHEN l.line_no = 1 THEN l.unit_price END) AS item1_unitPrice,
    -- Item 2
    MAX(CASE WHEN l.line_no = 2 THEN CONCAT(l.description, ' (', l.sku, ')') END) AS item2_description,
    MAX(CASE WHEN l.line_no = 2 THEN l.quantity END) AS item2_quantity,
    MAX(CASE WHEN l.line_no = 2 THEN l.uom END) AS item2_unit,
    MAX(CASE WHEN l.line_no = 2 THEN l.unit_price END) AS item2_unitPrice,
    -- Item 3
    MAX(CASE WHEN l.line_no = 3 THEN CONCAT(l.description, ' (', l.sku, ')') END) AS item3_description,
    MAX(CASE WHEN l.line_no = 3 THEN l.quantity END) AS item3_quantity,
    MAX(CASE WHEN l.line_no = 3 THEN l.uom END) AS item3_unit,
    MAX(CASE WHEN l.line_no = 3 THEN l.unit_price END) AS item3_unitPrice
FROM abaserve_deliveries d
JOIN abaserve_orders o ON d.order_id = o.order_id
JOIN abaserve_customers c ON o.customer_code = c.customer_code
JOIN abaserve_order_lines l ON o.order_id = l.order_id
LEFT JOIN drivers dr ON d.driver_id = dr.driver_code
LEFT JOIN vehicles v ON d.vehicle_no = v.registration
WHERE d.scheduled_date = CURDATE() + INTERVAL 1 DAY  -- Tomorrow's deliveries
AND d.status = 'SCHEDULED'
GROUP BY d.delivery_id
ORDER BY d.delivery_id;
```

### Alternative: Manual Export Steps

If you don't have database access:

1. **In Abaserve UI:**
   - Go to Reports > Delivery Schedule
   - Select date range
   - Choose "Export to Excel/CSV" option
   - Save file

2. **Format the CSV:**
   - Open in Excel/Google Sheets
   - Rename columns to match PODSafe format (see table above)
   - Ensure driver emails match PODSafe user accounts
   - Save as CSV

---

## ✅ Validation & Error Handling

### Common Validation Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Driver email not found" | Driver doesn't exist in PODSafe | Add driver to PODSafe first, or use correct email |
| "Missing required field: customerName" | Column is empty or missing | Fill in customer name |
| "Invalid date format" | Date not in YYYY-MM-DD format | Change to `2025-10-26` format |
| "No items found" | Missing item columns | Add at least `item1_description`, `item1_quantity`, `item1_unit` |
| "Invoice number already exists" | Duplicate invoice | Check for duplicate rows in CSV |

### Before Importing

PODSafe validates your CSV and shows:
- ✅ **Valid Deliveries:** Number of deliveries that will be imported
- ❌ **Errors:** Critical issues that prevent import
- ⚠️ **Warnings:** Non-critical issues (import continues)

**Fix all errors before importing!**

---

## 🔄 Daily Workflow

### Recommended Process

**Every Day at 5:00 PM (day before delivery):**

1. Export tomorrow's deliveries from Abaserve
2. Import CSV into PODSafe
3. Verify all deliveries loaded correctly
4. Drivers receive notifications automatically
5. Drivers can view deliveries in mobile app

**Next Morning:**

1. Drivers start deliveries
2. Capture POD (photos + signature) at each stop
3. Admin monitors progress in real-time
4. Completed deliveries sync back to Abaserve (optional)

---

## 🚀 Advanced Features

### Batch Processing

Import multiple days at once:
- Include deliveries for different dates in one CSV
- PODSafe groups them by scheduled date automatically

### Driver Auto-Assignment

If driver email is in CSV, PODSafe assigns automatically.  
If missing, admin can manually assign later.

### Vehicle Tracking

Including `vehicleReg` enables:
- Vehicle usage analytics
- Delivery count per vehicle
- Maintenance scheduling insights

---

## 🛠️ Troubleshooting

### Import Failed

**Problem:** "Error reading file"  
**Solution:** Ensure file is valid CSV format (not Excel .xlsx)

**Problem:** "No deliveries found"  
**Solution:** Check CSV has data rows (not just headers)

### Driver Not Receiving Deliveries

**Problem:** Driver can't see imported deliveries  
**Solution:**
1. Verify driver email in CSV matches PODSafe account
2. Check driver has "Driver" role in PODSafe
3. Ensure scheduled date is today or future date

### Duplicate Deliveries

**Problem:** Same delivery imported twice  
**Solution:** Invoice numbers must be unique. PODSafe will flag duplicates.

---

## 📞 Support

Need help?
- **Email:** support@podsafe.com
- **Documentation:** [Full User Guide](./USER_GUIDE.md)
- **Video Tutorial:** [YouTube Link]

---

## 🎯 Quick Reference

### Minimum Required CSV

```csv
customerName,customerAddress,invoiceNumber,scheduledDate,driverEmail,item1_description,item1_quantity,item1_unit
Acme Butchery,"12 Main Rd, Cape Town",INV-001,2025-10-26,driver@company.com,Beef Rump,40,KG
```

### Full Featured CSV

```csv
customerName,customerAddress,customerPhone,customerNumber,orderNumber,invoiceNumber,invoiceDate,scheduledDate,driverEmail,vehicleReg,notes,item1_description,item1_quantity,item1_unit,item1_unitPrice,item2_description,item2_quantity,item2_unit,item2_unitPrice
Acme Butchery,"12 Main Rd, Cape Town, 8001",+27-21-555-0100,C-019,SO-20498,INV-003248,2025-10-25,2025-10-26,driver1@company.com,CF12345,Urgent delivery – client closes at 3pm,Beef Rump A Grade (BEEF001),40,KG,95.00,Beef Sirloin Premium (BEEF023),25.5,KG,145.00
```

---

**Ready to import!** 🚀

Download the template from PODSafe admin dashboard and start importing your Abaserve deliveries today.
