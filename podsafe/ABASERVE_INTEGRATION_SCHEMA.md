# Abaserve ERP → PODSafe Integration Schema

Complete PostgreSQL database schema for integrating Abaserve ERP with PODSafe delivery tracking.

---

## TABLE 1: abaserve_orders

**Purpose:** Stores order headers exported from Abaserve.

### SQL Schema

```sql
CREATE TABLE abaserve_orders (
    order_id SERIAL PRIMARY KEY,
    company_id VARCHAR(20) NOT NULL,
    erp_order_no VARCHAR(50) NOT NULL UNIQUE,
    order_date DATE NOT NULL,
    customer_code VARCHAR(20) NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    ship_to_name VARCHAR(100),
    address1 VARCHAR(100) NOT NULL,
    address2 VARCHAR(100),
    city VARCHAR(50) NOT NULL,
    province VARCHAR(50),
    postal_code VARCHAR(10),
    contact_name VARCHAR(100),
    phone VARCHAR(30),
    requested_date DATE,
    delivery_window_from TIMESTAMP,
    delivery_window_to TIMESTAMP,
    notes TEXT,
    priority VARCHAR(10) DEFAULT 'NORMAL',
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_company_erp (company_id, erp_order_no),
    INDEX idx_customer (customer_code),
    INDEX idx_status (status),
    INDEX idx_order_date (order_date)
);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_abaserve_orders_updated_at BEFORE UPDATE
    ON abaserve_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### CSV Header

```csv
order_id,company_id,erp_order_no,order_date,customer_code,customer_name,ship_to_name,address1,address2,city,province,postal_code,contact_name,phone,requested_date,delivery_window_from,delivery_window_to,notes,priority,status,created_at,updated_at
```

### Sample Data

```csv
1,COMP001,SO-20498,2025-10-25,C-019,Acme Butchery,Acme Butchery - Main Branch,12 Main Rd,Block B Industrial Park,Cape Town,Western Cape,8001,John Smith,+27-21-555-0100,2025-10-26,2025-10-26 08:00:00,2025-10-26 12:00:00,Urgent delivery – client closes at 3pm,HIGH,OUT_FOR_DELIVERY,2025-10-25 09:15:23,2025-10-25 14:30:12
2,COMP001,SO-20499,2025-10-25,C-042,Fresh Meats Ltd,Fresh Meats - Warehouse 2,45 Industrial Ave,,Durban,KwaZulu-Natal,4001,Sarah Jones,+27-31-555-0200,2025-10-27,2025-10-27 07:00:00,2025-10-27 10:00:00,,NORMAL,PENDING,2025-10-25 10:22:45,2025-10-25 10:22:45
3,COMP001,SO-20500,2025-10-24,C-085,Premium Foods,Premium Foods Distribution,78 Commerce St,Unit 12,Johannesburg,Gauteng,2001,Mike Peterson,+27-11-555-0300,2025-10-25,2025-10-25 06:00:00,2025-10-25 09:00:00,Temperature sensitive - keep below 2°C,HIGH,DELIVERED,2025-10-24 15:30:00,2025-10-25 08:45:33
```

---

## TABLE 2: abaserve_order_lines

**Purpose:** Stores order line items linked to orders.

### SQL Schema

```sql
CREATE TABLE abaserve_order_lines (
    line_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    line_no INT NOT NULL,
    sku VARCHAR(50) NOT NULL,
    description VARCHAR(200) NOT NULL,
    quantity NUMERIC(10,2) NOT NULL,
    uom VARCHAR(10) NOT NULL,
    unit_price NUMERIC(10,2),
    tax_code VARCHAR(10),
    total_amount NUMERIC(12,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_order
        FOREIGN KEY(order_id) 
        REFERENCES abaserve_orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT uq_order_line UNIQUE(order_id, line_no),
    INDEX idx_sku (sku),
    INDEX idx_order_id (order_id)
);

CREATE TRIGGER update_abaserve_order_lines_updated_at BEFORE UPDATE
    ON abaserve_order_lines FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### CSV Header

```csv
line_id,order_id,line_no,sku,description,quantity,uom,unit_price,tax_code,total_amount,created_at,updated_at
```

### Sample Data

```csv
1,1,1,BEEF001,Beef Rump A Grade,40.00,KG,95.00,VAT15,3800.00,2025-10-25 09:15:23,2025-10-25 09:15:23
2,1,2,BEEF023,Beef Sirloin Premium,25.50,KG,145.00,VAT15,3697.50,2025-10-25 09:15:23,2025-10-25 09:15:23
3,1,3,LAMB012,Lamb Chops Fresh,18.00,KG,165.00,VAT15,2970.00,2025-10-25 09:15:23,2025-10-25 09:15:23
4,2,1,PORK008,Pork Loin Boneless,55.00,KG,85.00,VAT15,4675.00,2025-10-25 10:22:45,2025-10-25 10:22:45
5,2,2,CHICKEN05,Chicken Breast Fillet,120.00,KG,65.00,VAT15,7800.00,2025-10-25 10:22:45,2025-10-25 10:22:45
6,3,1,BEEF045,Beef Mince 80/20,200.00,KG,75.00,VAT15,15000.00,2025-10-24 15:30:00,2025-10-24 15:30:00
```

---

## TABLE 3: abaserve_customers

**Purpose:** Stores customer master data.

### SQL Schema

```sql
CREATE TABLE abaserve_customers (
    customer_code VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    vat_no VARCHAR(20),
    address1 VARCHAR(100),
    address2 VARCHAR(100),
    city VARCHAR(50),
    province VARCHAR(50),
    postal_code VARCHAR(10),
    contact_name VARCHAR(100),
    phone VARCHAR(30),
    email VARCHAR(100),
    account_terms VARCHAR(30),
    credit_limit NUMERIC(12,2),
    active_flag BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_customer_name (customer_name),
    INDEX idx_active (active_flag)
);

CREATE TRIGGER update_abaserve_customers_updated_at BEFORE UPDATE
    ON abaserve_customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### CSV Header

```csv
customer_code,customer_name,vat_no,address1,address2,city,province,postal_code,contact_name,phone,email,account_terms,credit_limit,active_flag,created_at,updated_at
```

### Sample Data

```csv
C-019,Acme Butchery,4123456789,12 Main Rd,Block B Industrial Park,Cape Town,Western Cape,8001,John Smith,+27-21-555-0100,john@acmebutchery.co.za,NET30,150000.00,true,2024-01-15 08:00:00,2025-10-20 11:30:00
C-042,Fresh Meats Ltd,4987654321,45 Industrial Ave,,Durban,KwaZulu-Natal,4001,Sarah Jones,+27-31-555-0200,sarah.j@freshmeats.co.za,NET45,250000.00,true,2024-03-22 10:15:00,2025-10-18 14:20:00
C-085,Premium Foods,4567891234,78 Commerce St,Unit 12,Johannesburg,Gauteng,2001,Mike Peterson,+27-11-555-0300,mike.p@premiumfoods.co.za,NET30,500000.00,true,2023-11-10 09:00:00,2025-10-22 16:45:00
```

---

## TABLE 4: abaserve_deliveries

**Purpose:** Stores delivery or trip information.

### SQL Schema

```sql
CREATE TABLE abaserve_deliveries (
    delivery_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    driver_id VARCHAR(20),
    vehicle_no VARCHAR(20),
    scheduled_date DATE NOT NULL,
    departure_time TIMESTAMP,
    arrival_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'SCHEDULED',
    remarks TEXT,
    gps_lat NUMERIC(10,6),
    gps_lng NUMERIC(10,6),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_delivery_order
        FOREIGN KEY(order_id) 
        REFERENCES abaserve_orders(order_id)
        ON DELETE CASCADE,
    INDEX idx_driver (driver_id),
    INDEX idx_vehicle (vehicle_no),
    INDEX idx_scheduled_date (scheduled_date),
    INDEX idx_status (status)
);

CREATE TRIGGER update_abaserve_deliveries_updated_at BEFORE UPDATE
    ON abaserve_deliveries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### CSV Header

```csv
delivery_id,order_id,driver_id,vehicle_no,scheduled_date,departure_time,arrival_time,status,remarks,gps_lat,gps_lng,created_at,updated_at
```

### Sample Data

```csv
1,1,DRV23,CF12345,2025-10-26,2025-10-26 07:45:00,2025-10-26 09:30:00,OUT_FOR_DELIVERY,Driver confirmed departure at 07:45,-33.925839,18.423218,2025-10-25 14:30:12,2025-10-26 07:45:33
2,2,DRV18,CF12346,2025-10-27,,,SCHEDULED,Assigned to morning route,-29.858680,31.021840,2025-10-25 10:22:45,2025-10-25 10:22:45
3,3,DRV12,CF12344,2025-10-25,2025-10-25 06:15:00,2025-10-25 08:20:00,DELIVERED,Delivered successfully - signed by Mike Peterson,-26.204103,28.047305,2025-10-24 15:30:00,2025-10-25 08:45:33
```

---

## TABLE 5: abaserve_pods

**Purpose:** Stores Proof-of-Delivery records captured by drivers.

### SQL Schema

```sql
CREATE TABLE abaserve_pods (
    pod_id SERIAL PRIMARY KEY,
    delivery_id INT NOT NULL,
    order_id INT NOT NULL,
    recipient_name VARCHAR(100) NOT NULL,
    signature_image_url TEXT,
    stamp_detected BOOLEAN DEFAULT false,
    photo_urls TEXT,
    pod_datetime TIMESTAMP NOT NULL,
    gps_lat NUMERIC(10,6),
    gps_lng NUMERIC(10,6),
    discrepancies TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pod_delivery
        FOREIGN KEY(delivery_id) 
        REFERENCES abaserve_deliveries(delivery_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_pod_order
        FOREIGN KEY(order_id) 
        REFERENCES abaserve_orders(order_id)
        ON DELETE CASCADE,
    INDEX idx_pod_delivery (delivery_id),
    INDEX idx_pod_order (order_id),
    INDEX idx_pod_datetime (pod_datetime)
);

CREATE TRIGGER update_abaserve_pods_updated_at BEFORE UPDATE
    ON abaserve_pods FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### CSV Header

```csv
pod_id,delivery_id,order_id,recipient_name,signature_image_url,stamp_detected,photo_urls,pod_datetime,gps_lat,gps_lng,discrepancies,created_at,updated_at
```

### Sample Data

```csv
1,3,3,Mike Peterson,https://storage.podsafe.com/signatures/pod_3_sig.png,true,"https://storage.podsafe.com/photos/pod_3_photo1.jpg,https://storage.podsafe.com/photos/pod_3_photo2.jpg",2025-10-25 08:20:15,-26.204103,28.047305,,2025-10-25 08:21:00,2025-10-25 08:21:00
2,1,1,John Smith,https://storage.podsafe.com/signatures/pod_1_sig.png,false,https://storage.podsafe.com/photos/pod_1_photo1.jpg,2025-10-26 09:30:22,-33.925839,18.423218,"Short 2.5kg on line item 2 - customer accepted partial delivery",2025-10-26 09:31:15,2025-10-26 09:31:15
```

---

## TABLE 6: abaserve_claims

**Purpose:** Stores claims created from POD discrepancies.

### SQL Schema

```sql
CREATE TABLE abaserve_claims (
    claim_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    delivery_id INT,
    claim_type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    photo_urls TEXT,
    pdf_urls TEXT,
    status VARCHAR(20) DEFAULT 'OPEN',
    created_by VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    CONSTRAINT fk_claim_order
        FOREIGN KEY(order_id) 
        REFERENCES abaserve_orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_claim_delivery
        FOREIGN KEY(delivery_id) 
        REFERENCES abaserve_deliveries(delivery_id)
        ON DELETE SET NULL,
    INDEX idx_claim_order (order_id),
    INDEX idx_claim_delivery (delivery_id),
    INDEX idx_claim_type (claim_type),
    INDEX idx_claim_status (status)
);
```

### CSV Header

```csv
claim_id,order_id,delivery_id,claim_type,description,photo_urls,pdf_urls,status,created_by,created_at,resolved_at
```

### Sample Data

```csv
1,1,1,SHORT_DELIVERY,"Short 2.5kg on Beef Sirloin Premium (SKU: BEEF023). Customer accepted partial delivery and signed POD. Credit note required.",https://storage.podsafe.com/claims/claim_1_photo1.jpg,https://storage.podsafe.com/claims/claim_1_report.pdf,OPEN,DRV23,2025-10-26 09:35:00,
2,3,3,DAMAGED_PACKAGING,"Two boxes of Beef Mince arrived with damaged outer packaging. Product integrity maintained (inner vacuum seal intact). Customer accepted delivery.",https://storage.podsafe.com/claims/claim_2_photo1.jpg,,RESOLVED,DRV12,2025-10-25 08:25:00,2025-10-25 14:30:00
```

---

## Relationship Diagram

```
abaserve_customers
    └─── customer_code
            ↓
    abaserve_orders (customer_code FK)
        ├─── order_id
        │       ↓
        │   abaserve_order_lines (order_id FK)
        │
        └─── order_id
                ↓
            abaserve_deliveries (order_id FK)
                ├─── delivery_id
                │       ↓
                │   abaserve_pods (delivery_id FK, order_id FK)
                │
                └─── delivery_id
                        ↓
                    abaserve_claims (delivery_id FK, order_id FK)
```

---

## Data Import Process

### 1. CSV Import Order
```
1. abaserve_customers (no dependencies)
2. abaserve_orders (references customers)
3. abaserve_order_lines (references orders)
4. abaserve_deliveries (references orders)
5. abaserve_pods (references deliveries & orders)
6. abaserve_claims (references orders & deliveries)
```

### 2. Key Constraints
- All foreign keys use `ON DELETE CASCADE` except claims.delivery_id (`ON DELETE SET NULL`)
- Unique constraint on `(order_id, line_no)` prevents duplicate lines
- `erp_order_no` must be unique per company to prevent duplicate imports

### 3. Indexing Strategy
- Primary keys: Auto-indexed
- Foreign keys: Indexed for join performance
- Status fields: Indexed for filtering
- Date fields: Indexed for range queries
- Customer/Driver lookups: Indexed

---

## PODSafe Integration Mapping

| Abaserve Table | PODSafe Collection | Sync Strategy |
|----------------|-------------------|---------------|
| abaserve_orders | deliveries | Import as deliveries with `source='Abaserve'` |
| abaserve_order_lines | deliveries.items[] | Nested array in delivery document |
| abaserve_customers | customers | Sync customer master data |
| abaserve_deliveries | deliveries | Update delivery status & driver assignments |
| abaserve_pods | pods | Driver-captured PODs sync back to SQL |
| abaserve_claims | claims | Claims generated from POD discrepancies |

---

## Additional Enhancements

### Traceability Fields (Food Safety)
Add to `abaserve_order_lines`:
```sql
ALTER TABLE abaserve_order_lines ADD COLUMN batch_id VARCHAR(50);
ALTER TABLE abaserve_order_lines ADD COLUMN carcass_id VARCHAR(50);
ALTER TABLE abaserve_order_lines ADD COLUMN lot_number VARCHAR(50);
ALTER TABLE abaserve_order_lines ADD COLUMN expiry_date DATE;
ALTER TABLE abaserve_order_lines ADD COLUMN storage_temp VARCHAR(20);
```

### Temperature Monitoring
Add to `abaserve_deliveries`:
```sql
ALTER TABLE abaserve_deliveries ADD COLUMN temp_zone VARCHAR(20);
ALTER TABLE abaserve_deliveries ADD COLUMN temp_min_recorded NUMERIC(5,2);
ALTER TABLE abaserve_deliveries ADD COLUMN temp_max_recorded NUMERIC(5,2);
ALTER TABLE abaserve_deliveries ADD COLUMN temp_violations INT DEFAULT 0;
```

### Route Optimization
Add to `abaserve_deliveries`:
```sql
ALTER TABLE abaserve_deliveries ADD COLUMN route_code VARCHAR(20);
ALTER TABLE abaserve_deliveries ADD COLUMN sequence_no INT;
ALTER TABLE abaserve_deliveries ADD COLUMN estimated_distance_km NUMERIC(8,2);
ALTER TABLE abaserve_deliveries ADD COLUMN actual_distance_km NUMERIC(8,2);
```

---

## Export Templates

### Bulk CSV Export (Orders with Lines)
```sql
SELECT 
    o.erp_order_no,
    o.customer_name,
    o.address1,
    o.city,
    o.requested_date,
    l.line_no,
    l.sku,
    l.description,
    l.quantity,
    l.uom
FROM abaserve_orders o
JOIN abaserve_order_lines l ON o.order_id = l.order_id
WHERE o.status = 'PENDING'
ORDER BY o.order_id, l.line_no;
```

### Daily Delivery Schedule
```sql
SELECT 
    d.delivery_id,
    o.erp_order_no,
    o.customer_name,
    d.driver_id,
    d.vehicle_no,
    d.scheduled_date,
    o.delivery_window_from,
    o.delivery_window_to,
    o.address1,
    o.city
FROM abaserve_deliveries d
JOIN abaserve_orders o ON d.order_id = o.order_id
WHERE d.scheduled_date = CURRENT_DATE
AND d.status IN ('SCHEDULED', 'OUT_FOR_DELIVERY')
ORDER BY d.driver_id, o.delivery_window_from;
```

---

## Notes

✅ **Versioning:** Use `updated_at` trigger to track last modification  
✅ **Audit Trail:** All tables have `created_at` and `updated_at`  
✅ **Data Integrity:** Foreign keys enforce referential integrity  
✅ **Performance:** Strategic indexes on frequently queried columns  
✅ **Scalability:** SERIAL primary keys support millions of records  
✅ **Traceability:** Batch/carcass tracking ready for food safety compliance  

**Next Steps:**
1. Create PostgreSQL database
2. Run CREATE TABLE scripts in order
3. Import customer master data
4. Set up scheduled CSV exports from Abaserve
5. Build import service in PODSafe to sync data
