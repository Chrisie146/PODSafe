import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_button.dart';
import '../../providers/auth_provider.dart';
import '../../models/delivery_model.dart';
import '../../services/pod_token_service.dart';
import '../../services/ocr_parser.dart';
import '../../widgets/pod_qr_code.dart';

class PODCaptureScreen extends StatefulWidget {
  final Delivery delivery;
  
  const PODCaptureScreen({
    super.key,
    required this.delivery,
  });

  @override
  State<PODCaptureScreen> createState() => _PODCaptureScreenState();
}

class _PODCaptureScreenState extends State<PODCaptureScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  
  Uint8List? _signatureImage;
  XFile? _photoFile;
  XFile? _stampPhotoFile; // Optional stamp photo for corporate customers
  final List<XFile> _photoFiles = []; // allow multiple photos
  final List<XFile> _documentFiles = []; // Scanned documents (separate from photos)
  final List<Map<String, String>> _documentMetadata = []; // Document types
  final int _maxDocuments = 4; // Maximum documents allowed
  bool _isSubmitting = false;
  
  // 🆕 NEW: OCR state variables
  late TextRecognizer _textRecognizer;
  String? _ocrRawText;
  Map<String, dynamic>? _ocrFields;
  double? _ocrConfidence;
  bool _isExtractingOcr = false;

  @override
  void dispose() {
    _signatureController.dispose();
    _notesController.dispose();
    _receiverNameController.dispose();
    _textRecognizer.close();  // 🆕 NEW: Close recognizer
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 🆕 NEW: Initialize text recognizer for OCR
    _textRecognizer = TextRecognizer();
  }

  Future<void> _captureSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw your signature first'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      
      // Try to convert to raw image first, then encode manually
      final ui.Image? imageNullable = await _signatureController.toImage(
        width: 1000,
        height: 500,
      );
      
      if (imageNullable == null) {
        throw Exception('Failed to create signature image');
      }
      
      final ui.Image image = imageNullable;
      
      // Convert to PNG bytes manually
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Failed to encode signature');
      }
      
      final signature = byteData.buffer.asUint8List();
      
      if (signature.isEmpty) {
        throw Exception('Signature data is empty');
      }
      
      setState(() {
        _signatureImage = signature;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signature captured successfully! (${signature.length} bytes)'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture signature: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _photoFiles.add(photo);
          _photoFile = _photoFiles.first; // keep single reference for legacy UI
        });

        // 🆕 NEW: Extract OCR from the delivery proof photo
        await _extractOcrFromPhoto(File(photo.path));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured successfully!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _takeStampPhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _photoFiles.add(photo);
          _photoFile = _photoFiles.first; // keep single reference for legacy UI
        });

        // 🆕 NEW: Extract OCR from the first delivery proof photo
        await _extractOcrFromPhoto(File(photo.path));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured successfully!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture stamp photo: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // 📄 NEW: Scan document with auto-filter and document type selection
  Future<void> _scanDocument() async {
    // Check max documents limit
    if (_documentFiles.length >= _maxDocuments) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum $_maxDocuments documents allowed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    try {
      // Open document scanner with auto-filter mode
      final List<String> scannedPaths = await CunningDocumentScanner.getPictures(
        noOfPages: 1, // Scan one document at a time
        isGalleryImportAllowed: false, // Only allow camera scanning
      ) ?? [];

      if (scannedPaths.isEmpty) {
        return; // User cancelled
      }

      // Show document type selection dialog
      if (!mounted) return;
      final String? docType = await _showDocumentTypeDialog();
      
      if (docType == null) {
        return; // User cancelled type selection
      }

      // Convert to XFile and add to documents list
      final XFile scannedDoc = XFile(scannedPaths.first);
      
      setState(() {
        _documentFiles.add(scannedDoc);
        _documentMetadata.add({
          'type': docType,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      // Run OCR on scanned document (priority over photos)
      await _extractOcrFromPhoto(File(scannedDoc.path));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$docType scanned successfully! (${_documentFiles.length}/$_maxDocuments)'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scan document: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Show dialog to select document type
  Future<String?> _showDocumentTypeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Document Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('What type of document is this?'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                title: const Text('Invoice'),
                onTap: () => Navigator.pop(context, 'Invoice'),
              ),
              ListTile(
                leading: const Icon(Icons.description, color: AppTheme.primaryColor),
                title: const Text('Delivery Note'),
                onTap: () => Navigator.pop(context, 'Delivery Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<String?> _uploadToStorage(String path, dynamic data) async {
    try {
      
      // Validate data before upload
      if (data is Uint8List && data.isEmpty) {
        return null;
      }
      
      if (data is String) {
        final file = File(data);
        if (!await file.exists()) {
          return null;
        }
        final fileSize = await file.length();
        if (fileSize == 0) {
          return null;
        }
      }
      
      final ref = FirebaseStorage.instance.ref().child(path);
      
      // Determine content type based on file extension
      String contentType = 'image/jpeg'; // default
      if (path.endsWith('.png')) {
        contentType = 'image/png';
      } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }
      
      final metadata = SettableMetadata(
        contentType: contentType,
        cacheControl: 'public, max-age=31536000',
      );
      
      if (data is Uint8List) {
        final uploadTask = ref.putData(data, metadata);
        await uploadTask;
      } else if (data is String) {
        await ref.putFile(File(data), metadata);
      }
      
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submitPOD() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get current location
      final position = await _getCurrentLocation();

      // Upload signature
      String? signatureUrl;
      if (_signatureImage != null && _signatureImage!.isNotEmpty) {
        signatureUrl = await _uploadToStorage(
          'pods/${widget.delivery.id}/signature_${DateTime.now().millisecondsSinceEpoch}.png',
          _signatureImage!,
        );
        if (signatureUrl == null) {
          throw Exception('Failed to upload signature');
        }
      } else {
      }

      // Validation: Require at least 1 photo AND 1 document
      if (_photoFiles.isEmpty) {
        throw Exception('At least 1 photo is required');
      }
      if (_documentFiles.isEmpty) {
        throw Exception('At least 1 scanned document is required');
      }

      // Upload photos (support multiple). Keep first as legacy `photoUrl`.
      String? photoUrl;
      List<String> photoUrls = [];
      if (_photoFiles.isNotEmpty) {
        for (int i = 0; i < _photoFiles.length; i++) {
          final file = _photoFiles[i];
          final url = await _uploadToStorage(
            'pods/${widget.delivery.id}/photos/photo_$i${DateTime.now().millisecondsSinceEpoch}.jpg',
            file.path,
          );
          if (url != null) {
            photoUrls.add(url);
            photoUrl ??= url; // legacy single-photo field
          }
        }
        if (photoUrls.isEmpty) {
          throw Exception('Failed to upload photos');
        }
      }

      // Upload scanned documents (separate from photos)
      List<String> documentUrls = [];
      List<Map<String, String>> documentMetadata = [];
      if (_documentFiles.isNotEmpty) {
        for (int i = 0; i < _documentFiles.length; i++) {
          final file = _documentFiles[i];
          final metadata = _documentMetadata[i];
          final url = await _uploadToStorage(
            'pods/${widget.delivery.id}/documents/doc_$i${DateTime.now().millisecondsSinceEpoch}.jpg',
            file.path,
          );
          if (url != null) {
            documentUrls.add(url);
            documentMetadata.add(metadata);
          }
        }
        if (documentUrls.isEmpty) {
          throw Exception('Failed to upload documents');
        }
      }

      // Upload stamp photo (optional, for corporate customers)
      String? stampPhotoUrl;
      if (_stampPhotoFile != null) {
        stampPhotoUrl = await _uploadToStorage(
          'pods/${widget.delivery.id}/stamp_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          _stampPhotoFile!.path,
        );
      }

      // Create POD document with delivery information
      final podData = {
        'deliveryId': widget.delivery.id,
        'driverId': userId,
        'companyId': authProvider.companyId, // Add companyId for filtering
        'createdAt': FieldValue.serverTimestamp(), // Required by Firestore rules
        'timestamp': FieldValue.serverTimestamp(), // Keep for backward compatibility
  'signatureUrl': signatureUrl,
  'receiverName': _receiverNameController.text.trim(),
  'photoUrl': photoUrl, // legacy single-photo
  'photoUrls': photoUrls, // list of delivery photos
  'documentUrls': documentUrls, // 📄 NEW: scanned documents (separate from photos)
  'documentMetadata': documentMetadata, // 📄 NEW: document types and timestamps
  'stampPhotoUrl': stampPhotoUrl, // Optional stamp photo
        'notes': _notesController.text.trim(),
        // 🆕 NEW: OCR extracted data (prioritizes scanned documents)
        'ocrRawText': _ocrRawText,
        'ocrFields': _ocrFields,
        'ocrConfidence': _ocrConfidence,
        // Copy delivery information for easy access in POD viewer
        'customerName': widget.delivery.customerName,
        'customerNumber': widget.delivery.customerNumber,
        'orderNumber': widget.delivery.orderNumber,
        'invoiceNumber': widget.delivery.invoiceNumber,
        'customerAddress': widget.delivery.customerAddress,
        'location': position != null
            ? {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'accuracy': position.accuracy,
              }
            : null,
      };
      
      // Save POD to Firestore
      await FirebaseFirestore.instance
          .collection('pods')
          .doc(widget.delivery.id)
          .set(podData);

      // Update delivery status and link to POD
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.delivery.id)
          .update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'podId': widget.delivery.id, // Link delivery to POD for easy lookup
      });
      
      // Generate public access token for QR code (truly non-blocking with timeout)
      // Fire and forget - don't wait for it
      Future.microtask(() async {
        try {
          final PODTokenService tokenService = PODTokenService();
          await tokenService.createToken(widget.delivery.id, expiryDays: 90).timeout(
            const Duration(seconds: 10),
          );
        } catch (e) {
          // Don't fail the whole operation if token generation fails
        }
      });

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog with QR code option
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successColor, size: 32),
              SizedBox(width: 12),
              Text('Success!'),
            ],
          ),
          content: const Text('Proof of delivery has been submitted successfully.'),
          actions: [
            TextButton(
              onPressed: () async {
                // Fetch the token and show QR code
                try {
                  final token = await PODTokenService().getTokenByDeliveryId(widget.delivery.id);
                  if (token != null && mounted) {
                    await PODQRCodeDialog.show(context, token: token);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('QR code is being generated. Please try again in a moment.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to load QR code: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_2, size: 18),
                  SizedBox(width: 4),
                  Text('View QR Code'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Pop with success result so calling screen can refresh
                Navigator.of(context).pop(true); // Close POD screen with success result
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: AppTheme.errorColor, size: 32),
              SizedBox(width: 12),
              Text('Error'),
            ],
          ),
          content: Text('Failed to submit POD: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // 🆕 NEW: Extract text from photo using ML Kit
  Future<void> _extractOcrFromPhoto(File photoFile) async {
    try {
      setState(() => _isExtractingOcr = true);
      
      // Create input image
      final inputImage = InputImage.fromFile(photoFile);
      
      // Extract text using ML Kit (runs on device)
      final recognizedText = await _textRecognizer.processImage(inputImage);
      _ocrRawText = recognizedText.text;
      
      // Parse extracted text
      if (_ocrRawText != null && _ocrRawText!.isNotEmpty) {
        _parseOcrFields();
      }
      
      setState(() => _isExtractingOcr = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR extraction failed: $e'),
            backgroundColor: Colors.orange,  // Warning, not critical
          ),
        );
      }
      setState(() => _isExtractingOcr = false);
    }
  }

  // 🆕 NEW: Parse OCR text to extract structured fields
  void _parseOcrFields() {
    try {
      final parser = OcrParser();
      final ocrFields = parser.parseText(_ocrRawText ?? '');
      
      setState(() {
        _ocrFields = ocrFields.toJson();
        // Set confidence based on how many fields were extracted
        int filledFields = 0;
        if (ocrFields.invoiceNo != null) filledFields++;
        if (ocrFields.supplier != null) filledFields++;
        if (ocrFields.customer != null) filledFields++;
        if (ocrFields.totalIncl != null) filledFields++;
        if (ocrFields.driverName != null) filledFields++;
        
        // Confidence is 0.6 + (0.08 * filled fields), capped at 0.95
        _ocrConfidence = (0.6 + (0.08 * filledFields)).clamp(0.0, 0.95);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ OCR data extracted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Don't show error to user - OCR is optional
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get safe area insets for proper spacing
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture POD'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppTheme.paddingMedium,
            right: AppTheme.paddingMedium,
            top: AppTheme.paddingMedium,
            // Add bottom padding that accounts for navigation bar + extra space
            bottom: bottomPadding > 0 ? bottomPadding + 16 : 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions Card
              Card(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.infoColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete all steps to submit proof of delivery',
                          style: TextStyle(color: AppTheme.infoColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Signature Section
              _buildSignatureSection(),
              
              const SizedBox(height: 16),
              
              // Photo Section
              _buildPhotoSection(),
              
              const SizedBox(height: 16),
              
              // 📄 NEW: Document Scanning Section
              _buildDocumentSection(),
              
              const SizedBox(height: 16),
              
              // Stamp Photo Section (Optional)
              _buildStampPhotoSection(),
              
              const SizedBox(height: 16),
              
              // Notes Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.note_alt, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            '5. Additional Notes (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter any additional notes...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Submit Button
              CustomButton(
                text: 'Submit POD',
                onPressed: _canSubmit() ? _submitPOD : null,
                icon: Icons.check_circle,
                backgroundColor: AppTheme.successColor,
              ),
              
              if (!_canSubmit())
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  child: Text(
                    'Please capture both signature and photo to submit',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.draw,
                  color: _signatureImage != null ? AppTheme.successColor : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Customer Signature',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: ${widget.delivery.customerName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_signatureImage != null)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Receiver Name Field
            TextFormField(
              controller: _receiverNameController,
              decoration: InputDecoration(
                labelText: 'Receiver Name',
                hintText: 'Name of person signing/receiving delivery',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Receiver name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_signatureImage != null)
              Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.successColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _signatureImage!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _signatureImage = null;
                        _signatureController.clear();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear & Redo'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Signature(
                      controller: _signatureController,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _signatureController.clear();
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _captureSignature,
                        icon: const Icon(Icons.check),
                        label: const Text('Capture Signature'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: _photoFile != null ? AppTheme.successColor : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '2. Delivery Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_photoFile != null)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_photoFiles.isNotEmpty)
              Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.successColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_photoFiles.first.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Add Another Photo'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _photoFiles.clear();
                            _photoFile = null;
                          });
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _photoFiles[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(file.path),
                                width: 120,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _photoFiles.removeAt(index);
                                      _photoFile = _photoFiles.isNotEmpty ? _photoFiles.first : null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            // 🆕 NEW: OCR Extraction Status
            if (_photoFile != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _ocrFields != null && (_ocrFields as Map).isNotEmpty
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _ocrFields != null && (_ocrFields as Map).isNotEmpty
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.blue.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isExtractingOcr)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_ocrFields != null && (_ocrFields as Map).isNotEmpty)
                      const Icon(Icons.check_circle, color: Colors.green, size: 16)
                    else
                      const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isExtractingOcr
                                ? 'Extracting invoice data...'
                                : _ocrFields != null && (_ocrFields as Map).isNotEmpty
                                    ? 'Invoice data extracted (${_ocrConfidence != null ? ((_ocrConfidence ?? 0) * 100).toStringAsFixed(0) : '0'}% confidence)'
                                    : 'Ready to extract invoice data',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ocrFields != null && (_ocrFields as Map).isNotEmpty
                                  ? Colors.green[700]
                                  : Colors.blue[700],
                            ),
                          ),
                          if (_ocrFields != null && (_ocrFields as Map).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Fields: Invoice, Supplier, Customer, Total',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 📄 NEW: Build document scanning section
  Widget _buildDocumentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.document_scanner,
                  color: _documentFiles.isNotEmpty ? AppTheme.successColor : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Scanned Documents *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Scan Invoice or Delivery Note (Required)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_documentFiles.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_documentFiles.length}/$_maxDocuments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_documentFiles.isNotEmpty)
              Column(
                children: [
                  // Display first document as main preview
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.successColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_documentFiles.first.path),
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Document type label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.label, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          _documentMetadata.first['type'] ?? 'Document',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Document thumbnails gallery
                  if (_documentFiles.length > 1)
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _documentFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final file = _documentFiles[index];
                          final docType = _documentMetadata[index]['type'] ?? 'Doc';
                          return Stack(
                            children: [
                              Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(file.path),
                                      width: 100,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Text(
                                    docType,
                                    style: const TextStyle(fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _documentFiles.removeAt(index);
                                        _documentMetadata.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      if (_documentFiles.length < _maxDocuments)
                        TextButton.icon(
                          onPressed: _scanDocument,
                          icon: const Icon(Icons.document_scanner),
                          label: const Text('Scan Another'),
                        ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _documentFiles.clear();
                            _documentMetadata.clear();
                          });
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove All'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                ],
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor, width: 2, style: BorderStyle.solid),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.document_scanner,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _scanDocument,
                        icon: const Icon(Icons.document_scanner),
                        label: const Text('Scan Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Auto-detects edges & enhances quality',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStampPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: _stampPhotoFile != null ? AppTheme.successColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '4. Customer Stamp (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'For corporate customers like Checkers, Boxer, Pick n Pay',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_stampPhotoFile != null)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_stampPhotoFile != null)
              Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.successColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_stampPhotoFile!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _stampPhotoFile = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Remove'),
                      ),
                      TextButton.icon(
                        onPressed: _takeStampPhoto,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retake'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _takeStampPhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Stamp Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Skip if not applicable',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    return _signatureImage != null && 
           _photoFiles.isNotEmpty &&         // At least 1 photo required
           _documentFiles.isNotEmpty &&      // At least 1 document required
           _receiverNameController.text.trim().isNotEmpty && 
           !_isSubmitting;
  }
}