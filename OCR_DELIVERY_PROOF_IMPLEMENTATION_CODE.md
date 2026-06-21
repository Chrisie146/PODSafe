# 🔧 OCR Delivery Proof - Implementation Code Guide

**Date:** October 21, 2025  
**Purpose:** Step-by-step code changes to implement OCR extraction and display

---

## 📋 Files to Modify

### 1️⃣ `pubspec.yaml` - Add ML Kit Dependency
### 2️⃣ `lib/models/pod_model.dart` - Add OCR fields
### 3️⃣ `lib/screens/driver/pod_capture_screen.dart` - Extract OCR
### 4️⃣ `lib/screens/admin/pod_details_screen.dart` - Display OCR

---

## Step 1: Add ML Kit Dependency

### File: `pubspec.yaml`

**Find the dependencies section and add:**

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # ... existing dependencies ...
  
  # NEW: Add this line for OCR text recognition
  google_mlkit_text_recognition: ^0.10.0
  
  # ... rest of dependencies ...
```

**Then run:**
```bash
flutter pub get
```

**What this adds:** On-device text recognition (no internet needed, no data sent to Google)

---

## Step 2: Update POD Model to Store OCR Data

### File: `lib/models/pod_model.dart`

**Location:** Around line 40 (in the PODRecord class)

```dart
// BEFORE (existing):
class PODRecord {
  final String id;
  final String companyId;
  final String driverId;
  final String deliveryId;
  final String customerName;
  final String invoiceNumber;
  final PODStatus status;
  final DateTime timestamp;
  final LocationData? location;
  final String? signedBy;
  final String? signatureUrl;
  final String? photoUrl;
  final String? pdfUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  PODRecord({
    required this.id,
    required this.companyId,
    // ... existing parameters ...
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
  });
```

**Change to:**

```dart
// AFTER (with OCR fields):
class PODRecord {
  final String id;
  final String companyId;
  final String driverId;
  final String deliveryId;
  final String customerName;
  final String invoiceNumber;
  final PODStatus status;
  final DateTime timestamp;
  final LocationData? location;
  final String? signedBy;
  final String? signatureUrl;
  final String? photoUrl;
  final String? pdfUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // 🆕 NEW: OCR extracted fields
  final String? ocrRawText;          // Full OCR text
  final Map<String, dynamic>? ocrFields;  // Parsed fields (invoiceNo, supplier, etc.)
  final double? ocrConfidence;       // Confidence score (0.0 - 1.0)
  
  PODRecord({
    required this.id,
    required this.companyId,
    // ... existing parameters ...
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    
    // 🆕 NEW: Add OCR parameters
    this.ocrRawText,
    this.ocrFields,
    this.ocrConfidence,
  });
```

**Update the `toFirestore()` method:**

```dart
// Find this method (around line 115):
Map<String, dynamic> toFirestore() {
  return {
    'companyId': companyId,
    'driverId': driverId,
    'deliveryId': deliveryId,
    'customerName': customerName,
    'invoiceNumber': invoiceNumber,
    'status': status.toString().split('.').last,
    'timestamp': Timestamp.fromDate(timestamp),
    'location': location?.toMap(),
    'signedBy': signedBy,
    'signatureUrl': signatureUrl,
    'photoUrl': photoUrl,
    'pdfUrl': pdfUrl,
    'metadata': metadata,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };
}

// Change to:
Map<String, dynamic> toFirestore() {
  return {
    'companyId': companyId,
    'driverId': driverId,
    'deliveryId': deliveryId,
    'customerName': customerName,
    'invoiceNumber': invoiceNumber,
    'status': status.toString().split('.').last,
    'timestamp': Timestamp.fromDate(timestamp),
    'location': location?.toMap(),
    'signedBy': signedBy,
    'signatureUrl': signatureUrl,
    'photoUrl': photoUrl,
    'pdfUrl': pdfUrl,
    'metadata': metadata,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    
    // 🆕 NEW: Add OCR fields
    'ocrRawText': ocrRawText,
    'ocrFields': ocrFields,
    'ocrConfidence': ocrConfidence,
  };
}
```

**Update the `fromFirestore()` method:**

```dart
// Find this method (around line 75):
factory PODRecord.fromFirestore(DocumentSnapshot doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  
  return PODRecord(
    id: doc.id,
    companyId: data['companyId'] ?? '',
    driverId: data['driverId'] ?? '',
    deliveryId: data['deliveryId'] ?? '',
    customerName: data['customerName'] ?? '',
    invoiceNumber: data['invoiceNumber'] ?? '',
    status: PODStatus.values.firstWhere(
      (e) => e.toString().split('.').last == data['status'],
      orElse: () => PODStatus.pending,
    ),
    timestamp: (data['timestamp'] as Timestamp).toDate(),
    location: data['location'] != null 
      ? LocationData.fromMap(data['location']) 
      : null,
    signedBy: data['signedBy'],
    signatureUrl: data['signatureUrl'],
    photoUrl: data['photoUrl'],
    pdfUrl: data['pdfUrl'],
    metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    createdAt: (data['createdAt'] as Timestamp).toDate(),
    updatedAt: data['updatedAt'] != null 
      ? (data['updatedAt'] as Timestamp).toDate() 
      : null,
  );
}

// Change to:
factory PODRecord.fromFirestore(DocumentSnapshot doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  
  return PODRecord(
    id: doc.id,
    companyId: data['companyId'] ?? '',
    driverId: data['driverId'] ?? '',
    deliveryId: data['deliveryId'] ?? '',
    customerName: data['customerName'] ?? '',
    invoiceNumber: data['invoiceNumber'] ?? '',
    status: PODStatus.values.firstWhere(
      (e) => e.toString().split('.').last == data['status'],
      orElse: () => PODStatus.pending,
    ),
    timestamp: (data['timestamp'] as Timestamp).toDate(),
    location: data['location'] != null 
      ? LocationData.fromMap(data['location']) 
      : null,
    signedBy: data['signedBy'],
    signatureUrl: data['signatureUrl'],
    photoUrl: data['photoUrl'],
    pdfUrl: data['pdfUrl'],
    metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    createdAt: (data['createdAt'] as Timestamp).toDate(),
    updatedAt: data['updatedAt'] != null 
      ? (data['updatedAt'] as Timestamp).toDate() 
      : null,
    
    // 🆕 NEW: Add OCR fields
    ocrRawText: data['ocrRawText'],
    ocrFields: data['ocrFields'] != null
      ? Map<String, dynamic>.from(data['ocrFields'])
      : null,
    ocrConfidence: (data['ocrConfidence'] as num?)?.toDouble(),
  );
}
```

**Update the `copyWith()` method:**

```dart
// Find this method (around line 135)
PODRecord copyWith({
  String? id,
  String? companyId,
  // ... other parameters ...
  DateTime? updatedAt,
}) {
  return PODRecord(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    // ... copy other fields ...
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

// Change to:
PODRecord copyWith({
  String? id,
  String? companyId,
  // ... other parameters ...
  DateTime? updatedAt,
  String? ocrRawText,           // 🆕 NEW
  Map<String, dynamic>? ocrFields,  // 🆕 NEW
  double? ocrConfidence,        // 🆕 NEW
}) {
  return PODRecord(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    // ... copy other fields ...
    updatedAt: updatedAt ?? this.updatedAt,
    
    // 🆕 NEW: Copy OCR fields
    ocrRawText: ocrRawText ?? this.ocrRawText,
    ocrFields: ocrFields ?? this.ocrFields,
    ocrConfidence: ocrConfidence ?? this.ocrConfidence,
  );
}
```

---

## Step 3: Extract OCR in Driver Capture Screen

### File: `lib/screens/driver/pod_capture_screen.dart`

**Add import at the top:**

```dart
// Find the existing imports section at the top (line 1-20)

// ADD THESE NEW IMPORTS:
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../services/ocr_parser.dart';  // Use existing parser
```

**Add to the class state variables (around line 50):**

```dart
class _PODCaptureScreenState extends State<PODCaptureScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  
  Uint8List? _signatureImage;
  XFile? _photoFile;
  XFile? _stampPhotoFile;
  bool _isSubmitting = false;
  
  // 🆕 NEW: Add OCR state variables
  late TextRecognizer _textRecognizer;
  String? _ocrRawText;
  Map<String, dynamic>? _ocrFields;
  double? _ocrConfidence;
  bool _isExtractingOcr = false;
```

**Add OCR initialization to initState (add after line 50-60):**

```dart
@override
void initState() {
  super.initState();
  // 🆕 NEW: Initialize text recognizer
  _textRecognizer = TextRecognizer();
}

@override
void dispose() {
  _signatureController.dispose();
  _notesController.dispose();
  _textRecognizer.close();  // 🆕 NEW: Close recognizer
  super.dispose();
}
```

**Add new method to extract OCR text (add before the build method):**

```dart
// 🆕 NEW: Extract text from photo using ML Kit
Future<void> _extractOcrFromPhoto() async {
  if (_photoFile == null) {
    print('❌ No photo file to extract OCR from');
    return;
  }

  try {
    setState(() => _isExtractingOcr = true);
    print('🔍 Starting OCR extraction from delivery proof photo...');
    
    // Create input image
    final inputImage = InputImage.fromFile(File(_photoFile!.path));
    
    // Extract text using ML Kit (runs on device)
    final recognizedText = await _textRecognizer.processImage(inputImage);
    _ocrRawText = recognizedText.text;
    
    print('✅ OCR extraction complete. Found ${_ocrRawText?.length ?? 0} characters');
    print('📄 OCR Text:\n${_ocrRawText ?? ""}');
    
    // Parse extracted text
    if (_ocrRawText != null && _ocrRawText!.isNotEmpty) {
      _parseOcrFields();
    }
    
    setState(() => _isExtractingOcr = false);
  } catch (e) {
    print('❌ OCR extraction error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OCR extraction failed: $e'),
        backgroundColor: Colors.orange,  // Warning, not critical
      ),
    );
    setState(() => _isExtractingOcr = false);
  }
}

// 🆕 NEW: Parse OCR text to extract structured fields
void _parseOcrFields() {
  try {
    final parser = OcrParser();
    final ocrFields = parser.parseText(_ocrRawText ?? '');
    
    print('📊 OCR Fields Parsed:');
    print('  Invoice: ${ocrFields.invoiceNo}');
    print('  Supplier: ${ocrFields.supplier}');
    print('  Customer: ${ocrFields.customer}');
    print('  Total: R${ocrFields.totalIncl}');
    
    setState(() {
      _ocrFields = ocrFields.toJson();
      _ocrConfidence = ocrFields.ocrConfident ? 0.85 : 0.65;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ OCR data extracted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('❌ OCR parsing error: $e');
    // Don't show error to user - OCR is optional
  }
}
```

**Update the photo capture method (find `_capturePhoto()` or similar, around line 150):**

```dart
// After capturing photo, add OCR extraction

Future<void> _capturePhoto() async {
  try {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    
    if (image != null) {
      setState(() => _photoFile = image);
      
      // 🆕 NEW: Extract OCR from the delivery proof photo
      await _extractOcrFromPhoto();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo captured')),
      );
    }
  } catch (e) {
    print('Error capturing photo: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to capture photo: $e')),
    );
  }
}
```

**Update the submit method (find `_submitPOD()`, around line 250-350):**

```dart
// In the _submitPOD method, update the metadata section:

// Find this code:
final metadata = <String, dynamic>{
  'notes': _notesController.text,
};

// Change to:
final metadata = <String, dynamic>{
  'notes': _notesController.text,
  
  // 🆕 NEW: Add OCR data to metadata
  if (_ocrRawText != null) 'ocrRawText': _ocrRawText,
  if (_ocrFields != null) 'ocrFields': _ocrFields,
  if (_ocrConfidence != null) 'ocrConfidence': _ocrConfidence,
};

print('📦 POD metadata includes OCR data: ${metadata.containsKey('ocrFields')}');
```

---

## Step 4: Display OCR Data in Admin Dashboard

### File: `lib/screens/admin/pod_details_screen.dart`

**Add import at top:**

```dart
import '../../models/ocr_fields_model.dart';  // For OcrFields type
```

**Find the build method and add OCR section (around line 300-400):**

```dart
// In the build method, find where existing POD details are displayed
// Add this section after signature and photo sections:

// Show OCR extracted data if available
if (widget.podData['ocrFields'] != null && 
    widget.podData['ocrFields'].isNotEmpty)
  Padding(
    padding: const EdgeInsets.all(16.0),
    child: _buildOcrDataSection(
      ocrFields: widget.podData['ocrFields'] as Map<String, dynamic>,
      confidence: (widget.podData['ocrConfidence'] as num?)?.toDouble() ?? 0.0,
    ),
  ),
```

**Add this new method to the class:**

```dart
// 🆕 NEW: Build OCR data display section
Widget _buildOcrDataSection({
  required Map<String, dynamic> ocrFields,
  required double confidence,
}) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: Colors.blue.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and confidence badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OCR Extracted Data',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              _buildConfidenceBadge(confidence),
            ],
          ),
          const SizedBox(height: 16),
          
          // Extracted fields in two columns
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildOcrFieldTile('Invoice #', ocrFields['invoiceNo']),
              _buildOcrFieldTile('Date', ocrFields['documentDate']),
              _buildOcrFieldTile('Supplier', ocrFields['supplier']),
              _buildOcrFieldTile('Customer', ocrFields['customer']),
              _buildOcrFieldTile('Branch', ocrFields['branch']),
              _buildOcrFieldTile('Site', ocrFields['site']),
              _buildOcrFieldTile('Total (Incl)', 
                ocrFields['totalIncl'] != null 
                  ? 'R${(ocrFields['totalIncl'] as num).toStringAsFixed(2)}'
                  : null
              ),
              _buildOcrFieldTile('Total (Excl)', 
                ocrFields['totalExcl'] != null 
                  ? 'R${(ocrFields['totalExcl'] as num).toStringAsFixed(2)}'
                  : null
              ),
              _buildOcrFieldTile('VAT Amount', 
                ocrFields['totalVat'] != null 
                  ? 'R${(ocrFields['totalVat'] as num).toStringAsFixed(2)}'
                  : null
              ),
              _buildOcrFieldTile('Vehicle', ocrFields['truckReg']),
              _buildOcrFieldTile('Driver', ocrFields['driverName']),
              _buildOcrFieldTile('Received By', ocrFields['receivedBy']),
              _buildOcrFieldTile('Mass (kg)', 
                ocrFields['totalMassKg']?.toString()
              ),
              _buildOcrFieldTile('Quantity', 
                ocrFields['totalQty']?.toString()
              ),
            ],
          ),
          
          // Optional: Show raw OCR text in expandable section
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text(
              'Raw OCR Text',
              style: TextStyle(color: Colors.blue.shade700),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: Text(
                  ocrFields['ocrRawText'] ?? '(No raw text available)',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// 🆕 NEW: Build a single OCR field tile
Widget _buildOcrFieldTile(String label, dynamic value) {
  final hasValue = value != null && value.toString().isNotEmpty;
  
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: hasValue ? Colors.white : Colors.grey.shade100,
      border: Border.all(
        color: hasValue ? Colors.blue.shade300 : Colors.grey.shade300,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasValue ? value.toString() : '—',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: hasValue ? Colors.black : Colors.grey.shade500,
            overflow: TextOverflow.ellipsis,
          ),
          maxLines: 2,
        ),
      ],
    ),
  );
}

// 🆕 NEW: Build confidence score badge
Widget _buildConfidenceBadge(double confidence) {
  final percentage = (confidence * 100).toInt();
  final color = confidence > 0.8
      ? Colors.green
      : confidence > 0.6
          ? Colors.orange
          : Colors.red;
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          confidence > 0.8 ? Icons.check_circle : Icons.info,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          '$percentage% Confidence',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
```

---

## 📋 Summary of Changes

### Total Lines Added/Modified: ~400 lines

| File | Change | Lines |
|------|--------|-------|
| `pubspec.yaml` | Add ML Kit dependency | +1 |
| `pod_model.dart` | Add OCR fields to model | +40 |
| `pod_capture_screen.dart` | Extract OCR from photo | +150 |
| `pod_details_screen.dart` | Display OCR data | +210 |
| **Total** | | **~400** |

---

## ✅ Testing Checklist

- [ ] Run `flutter pub get` successfully
- [ ] No compilation errors in pod_model.dart
- [ ] No compilation errors in pod_capture_screen.dart
- [ ] No compilation errors in pod_details_screen.dart
- [ ] Driver app runs without crashing
- [ ] Can capture POD with photo
- [ ] OCR extraction completes without errors
- [ ] Admin dashboard displays OCR data section
- [ ] Confidence badge shows correct percentage
- [ ] All extracted fields display correctly

---

## 🚀 Next: More Enhancements

After basic implementation, you could add:

1. **Edit OCR Fields** - Admin can correct extracted data
2. **Approval Workflow** - Admin approves OCR data
3. **Accuracy Tracking** - Track OCR accuracy over time
4. **Export OCR Data** - Include in PDF reports
5. **Reprocess Failed** - Retry OCR for low confidence extractions

But the basic implementation above will get you 80% there!
