# POD Document Intake Module - Implementation Guide

## Overview

The POD Document Intake Module enables drivers and admins to scan, capture, and process Proof-of-Delivery documents with intelligent OCR-based field extraction and automated delivery matching.

## Features Implemented

### 1. **OCR Text Extraction & Parsing** (`ocr_parser.dart`)
- Extracts invoice number (INV400098, INVOICE#400098)
- Extracts supplier and customer names
- Extracts financial data (Total Excl, VAT, Total Incl)
- Extracts delivery details (Branch, Site, Date, Driver, Vehicle)
- Extracts recipient information (Received by)
- Validates totals and dates
- Generates confidence scores and warnings

### 2. **POD Document Models** (`ocr_fields_model.dart`)
- `OcrFields`: Extracted structured data from OCR
- `DetectionFlags`: Quality metrics and feature detection
- `PodDocument`: Complete POD record for Firestore storage

### 3. **POD Repository** (`pod_repository.dart`)
- Upload images to Firebase Storage
- Save POD documents to Firestore
- Auto-match PODs to existing deliveries
- Link PODs to deliveries
- Query PODs by driver, status, and other criteria
- Update POD status and notes

### 4. **POD Controller** (`pod_controller.dart`)
- State management for capture → parse → upload workflow
- Image capture from camera or gallery
- OCR text parsing
- Upload orchestration
- Error handling and notifications

## Data Model

### OcrFields
```dart
OcrFields(
  supplier: 'Meat Traders (Queenstown) (Pty) Ltd',
  customer: 'Boxer Superstores (Pty) Ltd',
  invoiceNo: 'INV400098',
  documentDate: DateTime(2024, 10, 6),
  branch: 'X319',
  site: 'Cleary Park',
  totalExcl: 88672.12,
  totalVat: 13300.82,
  totalIncl: 101972.94,
  totalMassKg: 1869.00,
  totalQty: 25,
  truckReg: 'KFM 567 CC',
  driverName: 'Uuyo',
  receivedBy: 'John Doe',
)
```

### DetectionFlags
```dart
DetectionFlags(
  hasSignature: true,
  hasStamp: true,
  ocrConfident: true,
  warnings: [],
  ocrConfidenceScore: 0.85,
)
```

### PodDocument
```dart
PodDocument(
  id: 'pod_12345',
  companyId: 'company_001',
  type: 'invoice',
  storagePath: 'gs://bucket/pods/...',
  capturedAt: DateTime.now(),
  capturedByUid: 'driver_uid',
  fields: ocrFields,
  flags: detectionFlags,
  matchedDeliveryId: 'delivery_12345',
  status: 'Pending Verification',
  createdAt: DateTime.now(),
)
```

## Firestore Structure

```
companies/
  {companyId}/
    pods/
      {podId}: PodDocument
        - companyId
        - type (invoice, delivery_note, unknown)
        - storagePath (gs://bucket/...)
        - capturedAt
        - capturedByUid
        - fields (OcrFields)
        - flags (DetectionFlags)
        - matchedDeliveryId (optional)
        - status (Pending, Needs Review, Verified, Pending Verification)
        - createdAt
        - updatedAt
        - notes
```

## Integration Points

### 1. **With Delivery Model**
- Auto-match PODs to deliveries by invoiceNo + branch + date
- Link POD ID to delivery
- Update delivery status when POD verified

### 2. **With PDF Generation**
- Include captured POD images in PDF reports
- Display extracted OCR fields in PDF
- Show verification status

### 3. **With Admin Dashboard**
- New "Document Review" tab
- Filter PODs by status (Pending, Needs Review, Verified)
- Admin approval workflow
- Download POD images and OCR data

## Usage Workflow

### Driver: Capture POD
```dart
// 1. Initialize controller
final controller = PodController(
  repository: PodRepository(),
  ocrParser: OcrParser(),
);

// 2. Capture image (camera or gallery)
await controller.captureFromCamera();

// 3. Get OCR text from ML Kit or Vision API
final ocrText = await ocrService.recognizeText(image);

// 4. Parse OCR text
await controller.parseOcrText(ocrText);

// 5. Review extracted data
print(controller.ocrFields);
print(controller.detectionFlags);

// 6. Upload POD
await controller.uploadPod(
  companyId: 'company_001',
  driverId: 'driver_uid',
);

// 7. Handle success
if (controller.state == PodState.success) {
  print('POD ID: ${controller.podDocumentId}');
}
```

### Admin: Review POD
```dart
// Get PODs needing review
final pods = await repository.getPodsByStatus(
  companyId,
  'Needs Review',
);

// Update POD status
await repository.updatePodStatus(
  companyId,
  podId,
  'Verified',
  notes: 'Approved by admin',
);

// Link to delivery if needed
await repository.linkPodToDelivery(
  companyId,
  podId,
  deliveryId,
);
```

## OCR Parsing Rules

### Invoice Number
Patterns: INV400098, INVOICE#400098, INV-400098
Regex: `INV\s*#?\s*([A-Z0-9]{3,12})`

### Customer/Supplier
Looks for company names after "FROM", "SUPPLIED BY", "DELIVERED TO"

### Totals
Patterns: "Total Due R101,972.94", "Total Inc 101972.94"
Formats: `R 101 972.94`, `101,972.94`, `R45974.35`

### Branch/Site
Patterns: "Branch X319", "Store 1250", "CLEARY PARK"
Regex: `\b([X]\d{3}|1[0-2]\d{2})\b`

### Vehicle Registration
Patterns: "KFM 567 CC", "ABC123XY"
Regex: `\b([A-Z]{2,3}\s?\d{2,3}\s?[A-Z]{2})\b`

### Date
Formats: dd/MM/yyyy, yyyy-MM-dd, dd-MM-yyyy

## Status Workflow

```
Pending
├── Needs Review (missing critical fields or low confidence)
├── Pending Verification (auto-matched to delivery)
└── Verified (admin approved)
    └── Rejected (admin rejected with notes)
```

## Validation & Warnings

- ✓ Invoice number found
- ✓ Total amount found
- ✓ Document date found and valid
- ✓ Totals match (Excl + VAT = Incl, within ±R2.00)
- ✓ Document date within ±365 days
- ✓ Signature detected
- ✓ Stamp detected

## Firebase Storage Path
`pods/{companyId}/{uid}/{yyyy}/{MM}/{uuid}.jpg`

Example: `pods/company_001/driver_123/2024/10/a1b2c3d4.jpg`

## Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /companies/{companyId} {
      match /pods/{podId} {
        // Drivers can create their own PODs
        allow create: if request.auth != null 
          && request.resource.data.capturedByUid == request.auth.uid;
        
        // Drivers can read their own PODs
        allow read: if request.auth != null 
          && (resource.data.capturedByUid == request.auth.uid 
          || userHasRole(companyId, 'admin'));
        
        // Admin/Manager can update and delete
        allow update, delete: if userHasRole(companyId, 'admin');
      }
    }
  }
  
  function userHasRole(companyId, role) {
    return get(/databases/$(database)/documents/companies/$(companyId)/users/$(request.auth.uid)).data.role == role;
  }
}
```

## Error Handling

All methods in `PodController` handle errors and set appropriate state:
- `PodState.error` for failures
- `errorMessage` contains user-friendly error description
- OCR parsing continues even if some fields fail to extract

## Next Steps for Implementation

1. **Create POD Capture Screen** (`pod_capture_screen.dart`)
   - Camera/gallery picker UI
   - OCR text input field
   - Preview extracted fields
   - Upload button

2. **Create POD Review Widget** (`pod_preview_card.dart`)
   - Display extracted OCR fields
   - Show confidence scores
   - Display warnings
   - Expandable OCR text view

3. **Integrate with Admin Dashboard**
   - "Document Review" tab
   - POD status management
   - Admin approval workflow
   - PDF report generation with POD data

4. **Add ML Kit Integration** (Optional)
   - Add `google_mlkit_text_recognition` package
   - Replace manual OCR with ML Kit
   - Improve accuracy and confidence scoring

5. **Create Tests** (`ocr_parser_test.dart`)
   - Test OCR parsing with sample invoice text
   - Test field extraction accuracy
   - Test warning generation

## Testing Sample OCR Text

```
MEAT TRADERS (QUEENSTOWN) (PTY) LTD
TAX INVOICE

Invoice No: INV400098
Date: 06/10/2024
Branch: X319 - CLEARY PARK

TO:
BOXER SUPERSTORES (PTY) LTD

VAT Number: 4240206294

Items:
- Beef Cuts: 25 boxes, 1869.00 kg
- Total Qty: 25
- Total Excl: R88,672.12
- Total VAT (15%): R13,300.82
- Total Due: R101,972.94

Truck Reg: KFM 567 CC
Driver: Uuyo

Received By: _______________
Signature: _______________
Stamp:
```

This sample should parse correctly and extract all major fields.
