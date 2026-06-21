# POD Download & PDF Feature - Visual Architecture

## 🎯 Feature Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         POD DETAILS SCREEN                          │
│                                                                     │
│  [POD Information]                 [Download Button ⬇️]             │
│  • Customer Name                         ↓                         │
│  • Address                      Shows Download Dialog                │
│  • Phone                                 ↓                         │
│  • Delivery Time           ┌─────────────────────────────────┐     │
│  • GPS Location            │   DOWNLOAD OPTIONS              │     │
│  • Delivery Photo          ├─────────────────────────────────┤     │
│  • Signature               │                                 │     │
│  • Stamp Photo             │ 📄 PDF Report (NEW!)            │ ─┐  │
│  • Notes                   │    + Company Logo               │  │  │
│                            │    + Branding                   │  │  │
│                            │ ─────────────────────────────── │  │  │
│                            │ ⬇️ All Images / Individual      │  │  │
│                            │ 🖼️ Signature / Photo / Stamp   │ ─┤  │
│                            │                                 │  │  │
│                            └─────────────────────────────────┘  │  │
│                                        │                        │  │
│                            Option 1    │    Option 2            │  │
│                                        ↓                        ↓  │
│                        ┌───────────────────────┐    ┌──────────────┐
│                        │  IMAGE DOWNLOADS      │    │  PDF REPORT  │
│                        ├───────────────────────┤    ├──────────────┤
│                        │ • Signature.jpg       │    │ • Header with│
│                        │ • Photo.jpg           │    │   logo       │
│                        │ • Stamp.jpg           │    │ • All details│
│                        │ • [All files]         │    │ • All images │
│                        └───────────────────────┘    │ • Notes      │
│                                                     │ • Footer     │
│                                                     │ [1 PDF file] │
│                                                     └──────────────┘
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    POD DETAILS SCREEN                           │
│  (lib/screens/admin/pod_details_screen.dart)                   │
│                                                                 │
│  • _loadCompanyInfo()       [NEW: Fetch company info]          │
│  • _showDownloadOptions()   [Enhanced with PDF option]         │
│  • _downloadPODReport()     [NEW: Generate PDF]                │
│  • _downloadSingleImage()   [Unchanged]                        │
│  • _downloadAllImages()     [Unchanged]                        │
└────────┬──────────────────────────────────────────────────────┘
         │
         ├─────────────────────────────────────────────┐
         │                                             │
         ↓                                             ↓
    ┌─────────────────────────┐          ┌──────────────────────────┐
    │ POD IMAGE DOWNLOAD      │          │ POD PDF GENERATOR        │
    │ SERVICE (Existing)      │          │ SERVICE (NEW)            │
    ├─────────────────────────┤          ├──────────────────────────┤
    │                         │          │                          │
    │ • downloadImage()       │          │ • downloadPODReportPDF() │
    │   - Fetch image bytes   │          │   - Fetch company info   │
    │   - Detect MIME type    │          │   - Fetch all images     │
    │   - Create blob         │          │   - Build PDF with logo  │
    │   - Trigger download    │          │   - Generate PDF bytes   │
    │                         │          │   - Download PDF         │
    │ • downloadMultiple()    │          │                          │
    │   - Batch downloads     │          │ • _buildPDFHeaderWithB() │
    │   - Error handling      │          │   - Display logo         │
    │                         │          │   - Show company name    │
    │ • generateFilename()    │          │   - Format header        │
    │   - Sanitize names      │          │                          │
    │   - Add timestamp       │          │ • _buildPDFSection()     │
    │                         │          │   - Consistent styling   │
    │ • createDownloadLink()  │          │                          │
    │   - Add alt=media       │          │ • _fetchImageBytes()     │
    │                         │          │   - Download from URL    │
    └────────┬────────────────┘          │   - Error handling       │
             │                           │                          │
             │                           └──────────┬───────────────┘
             │                                      │
             └──────────────────────────┬───────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
                    ↓                                       ↓
            ┌─────────────────┐                  ┌──────────────────┐
            │ Firebase        │                  │ Firestore        │
            │ Storage         │                  │ Database         │
            ├─────────────────┤                  ├──────────────────┤
            │                 │                  │                  │
            │ • Images        │                  │ • Companies      │
            │   - Signature   │                  │   - Logo URL     │
            │   - Photo       │                  │   - Name         │
            │   - Stamp       │                  │   - Settings     │
            │                 │                  │                  │
            └─────────────────┘                  └──────────────────┘
```

---

## 📊 Data Flow for PDF Generation

```
User clicks Download → Opens Dialog
         ↓
User selects "Download as PDF Report"
         ↓
_downloadPODReport() called
         ↓
Collect POD data:
├─ Get signatureUrl, photoUrl, stampPhotoUrl
├─ Get timestamp, location, notes
├─ Get delivery info (customerName, address, phone)
└─ Get company name and logoUrl
         ↓
PODPdfGeneratorService.downloadPODReportPDF({...})
         ↓
Parallel image fetching:
├─ Fetch signature image bytes
├─ Fetch delivery photo bytes
├─ Fetch stamp photo bytes
└─ Fetch company logo bytes
         ↓
Create PDF Document (A4 size)
         ↓
Build PDF Page:
├─ Add header with logo & company name
├─ Add delivery information section
├─ Add timestamp section
├─ Add location section
├─ Add delivery photo (if available)
├─ Add signature (if available)
├─ Add stamp photo (if available)
├─ Add notes (if available)
└─ Add footer with document ID
         ↓
Generate PDF bytes
         ↓
Create Blob with MIME type "application/pdf"
         ↓
Create ObjectUrl from Blob
         ↓
Create AnchorElement with download attribute
         ↓
Trigger click to download
         ↓
Revoke ObjectUrl to free memory
         ↓
Show success notification to user
```

---

## 🔄 Company Branding Data Flow

```
                    POD Details Screen Load
                            ↓
                  _loadCompanyInfo() called
                            ↓
        Get User's Company ID from AuthProvider
                            ↓
  Firestore Query: db.collection('companies').doc(companyId)
                            ↓
           Document Retrieved from Firestore
                            ↓
        ┌─────────────────────────────────────┐
        │ Company Document Contents:          │
        ├─────────────────────────────────────┤
        │ {                                   │
        │   id: "comp_123",                   │
        │   name: "ACME Logistics",           │
        │   logoUrl: "gs://bucket/acme.jpg",  │
        │   address: "123 Main St, CT",       │
        │   email: "info@acme.com",           │
        │   phone: "+1 555-0123",             │
        │   settings: {...}                   │
        │ }                                   │
        └─────────────────────────────────────┘
                            ↓
              Extract and store:
              └─ _companyName = "ACME Logistics"
              └─ _companyLogoUrl = "gs://bucket/acme.jpg"
                            ↓
              When PDF Download Requested:
              └─ Pass company name and logo URL
                to PDF generator service
                            ↓
              PDF Generator:
              ├─ Fetches logo image bytes
              ├─ Displays logo (80x80px)
              ├─ Shows company name in header
              └─ Creates professional header
```

---

## 📱 Download Dialog Decision Tree

```
                    Download Button Clicked
                            │
                 Does POD have images?
                        │        │
                       YES      NO
                        │        │
                        ↓        ↓
                   Show      Show "No images
                   Dialog    available" message
                        │
            ┌───────────┴───────────┐
            │                       │
      User selects?          User clicks
            │                Cancel/Close
            │
    ┌───────┴──────────┐
    │                  │
    PDF Option?   Individual?
    │                  │
    ↓                  ↓
Generate PDF      Show submenu:
    ↓              ├─ All images
Download PDF      ├─ Signature
    ↓              ├─ Photo
Success!          └─ Stamp
                      ↓
                  Download selected
                      ↓
                   Success!
```

---

## 🎨 PDF Page Layout

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│ ┌─ 20mm Margin ─────────────────────────────────────┐  │
│ │                                                    │  │
│ │  [LOGO]    Company Name                          │  │
│ │  80x80px   PROOF OF DELIVERY REPORT              │  │
│ │            Official Delivery Documentation        │  │
│ │                                                    │  │
│ │  ──── Blue Divider (2pt) ────                    │  │
│ │                                                    │  │
│ │  POD ID: ABC-123        Generated: Oct 21, 2025  │  │
│ │                                                    │  │
│ │  DELIVERY INFORMATION                             │  │
│ │  ├─ Customer Name: John Smith                    │  │
│ │  ├─ Address: 123 Main St...                      │  │
│ │  └─ Phone: +1 555-0123                           │  │
│ │                                                    │  │
│ │  DELIVERY TIME                                    │  │
│ │  └─ Completed At: Mon, Oct 21, 2025 • 2:30 PM   │  │
│ │                                                    │  │
│ │  GPS LOCATION                                     │  │
│ │  ├─ Latitude: -33.9249                           │  │
│ │  ├─ Longitude: 18.4241                           │  │
│ │  └─ Accuracy: 8.5 meters                         │  │
│ │                                                    │  │
│ │  DELIVERY PHOTO                                   │  │
│ │  ┌─────────────────────────────────────┐         │  │
│ │  │  [Image - Package Photo]            │         │  │
│ │  │  400px × 300px                      │         │  │
│ │  └─────────────────────────────────────┘         │  │
│ │                                                    │  │
│ │  CUSTOMER SIGNATURE                               │  │
│ │  ┌─────────────────────────────────────┐         │  │
│ │  │  [Image - Signature]                │         │  │
│ │  │  300px × 150px                      │         │  │
│ │  └─────────────────────────────────────┘         │  │
│ │                                                    │  │
│ │  DELIVERY NOTES                                   │  │
│ │  ┌────────────────────────────────────┐          │  │
│ │  │ Package left on porch. Customer    │          │  │
│ │  │ approved contactless delivery.     │          │  │
│ │  └────────────────────────────────────┘          │  │
│ │                                                    │  │
│ │  ──── Divider ────                               │  │
│ │  This is an official Proof of Delivery document. │  │
│ │  Document ID: ABC-123                            │  │
│ │                                                    │  │
│ └────────────────────────────────────────────────────┘  │
│                                                         │
└──────────────────────────────────────────────────────────┘
```

---

## 🔗 Component Interaction Diagram

```
┌──────────────────────┐
│ AuthProvider         │
│ (Current User)       │
├──────────────────────┤
│ • currentUser.id     │
│ • currentUser.email  │
│ • currentUser.role   │
│ • currentUser.       │
│   companyId ────────┐
└──────────────────────┘ │
                        │
                        ↓
         ┌──────────────────────────┐
         │ POD Details Screen       │
         ├──────────────────────────┤
         │ • _delivery              │
         │ • _companyName           │
         │ • _companyLogoUrl        │
         └─────┬────────────────────┘
               │
       ┌───────┴──────────┐
       │                  │
       ↓                  ↓
┌──────────────────┐ ┌──────────────────┐
│ Firestore        │ │ Firebase Storage │
│ Collections:     │ │                  │
│                  │ │ • Logos          │
│ • users          │ │ • POD images     │
│ • companies      │ │ • Photos         │
│ • deliveries     │ │ • Signatures     │
│ • pods           │ │ • Stamps         │
└──────────────────┘ └──────────────────┘
       ↑                      ↑
       │                      │
       └──────────┬───────────┘
                  │
      ┌───────────┴───────────┐
      │                       │
      ↓                       ↓
┌─────────────────┐  ┌──────────────────┐
│ ImageDownload   │  │ PDFGenerator     │
│ Service         │  │ Service          │
├─────────────────┤  ├──────────────────┤
│ • downloadImage │  │ • buildPDF()     │
│ • fetchBytes    │  │ • fetchImages    │
│ • downloadBlob  │  │ • embedImages    │
│                 │  │ • addBranding    │
└─────────────────┘  └──────────────────┘
      │                      │
      └──────────┬───────────┘
                 │
                 ↓
         ┌───────────────┐
         │ Browser       │
         ├───────────────┤
         │ • Downloads   │
         │ • PDF files   │
         │ • Images      │
         └───────────────┘
```

---

## 📋 File Dependencies Map

```
pod_details_screen.dart
    ├─ imports theme.dart
    ├─ imports delivery_model.dart
    ├─ imports firebase_storage_image.dart
    ├─ imports location_map_widget.dart
    ├─ imports pod_image_download_service.dart ←─┐
    ├─ imports pod_pdf_generator_service.dart  ←─┤─── NEW
    ├─ imports auth_provider.dart              ←─┤
    └─ imports provider/provider.dart          ←─┘
         │
         ├─→ pod_image_download_service.dart
         │       ├─ imports url_launcher
         │       ├─ imports http
         │       ├─ imports dart:html
         │       └─ imports flutter/foundation
         │
         └─→ pod_pdf_generator_service.dart (NEW)
                 ├─ imports pdf/pdf
                 ├─ imports pdf/widgets
                 ├─ imports http
                 ├─ imports dart:html
                 ├─ imports dart:typed_data
                 ├─ imports cloud_firestore
                 └─ imports intl
```

---

## ✅ State Management Flow

```
Initial State:
┌────────────────────────────┐
│ _PODDetailsScreenState      │
├────────────────────────────┤
│ • _delivery = null         │
│ • _isLoadingDelivery = true│
│ • _companyName = null      │
│ • _companyLogoUrl = null   │
└────────────────────────────┘
         ↓
    initState()
    ├─ _loadDeliveryDetails()
    └─ _loadCompanyInfo()
         ↓
Data Loaded State:
┌────────────────────────────┐
│ _PODDetailsScreenState      │
├────────────────────────────┤
│ • _delivery = Delivery(...)│
│ • _isLoadingDelivery = false
│ • _companyName = "ACME"    │
│ • _companyLogoUrl = "url"  │
└────────────────────────────┘
         ↓
Build triggered with full data
         ↓
User clicks download button
         ↓
Dialog shows with company branding
```

---

**Last Updated:** October 21, 2025  
**Version:** 1.0  
**Status:** ✅ Production Ready
