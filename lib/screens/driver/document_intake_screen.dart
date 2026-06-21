import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pod_controller.dart';
import '../../widgets/pod_preview_card.dart';

/// Driver UI for capturing and processing invoice documents (Phase 2 - Document Intake)
/// This is separate from the traditional POD signature capture
class DocumentIntakeScreen extends StatefulWidget {
  final String companyId;
  final String driverId;
  final String? deliveryId; // Optional: can link to specific delivery

  const DocumentIntakeScreen({
    super.key,
    required this.companyId,
    required this.driverId,
    this.deliveryId,
  });

  @override
  State<DocumentIntakeScreen> createState() => _DocumentIntakeScreenState();
}

class _DocumentIntakeScreenState extends State<DocumentIntakeScreen> {
  late PodController _podController;
  final TextEditingController _ocrTextController = TextEditingController();
  bool _showOcrInput = false;
  bool _showManualInput = false;

  @override
  void initState() {
    super.initState();
    // Use the PodController from Provider instead of creating a new one
    _podController = context.read<PodController>();
  }

  @override
  void dispose() {
    _ocrTextController.dispose();
    super.dispose();
  }

  /// Capture image from camera
  Future<void> _captureFromCamera() async {
    try {
      await _podController.captureFromCamera();
      if (mounted && _podController.capturedImage != null) {
        _showOcrInput = true;
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      await _podController.pickFromGallery();
      if (mounted && _podController.capturedImage != null) {
        _showOcrInput = true;
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  /// Parse OCR text from manual input
  Future<void> _parseOcrText() async {
    final text = _ocrTextController.text.trim();
    if (text.isEmpty) {
      _showError('Please enter OCR text or paste invoice details');
      return;
    }

    try {
      await _podController.parseOcrText(text);
      setState(() {
        _showOcrInput = false;
        _showManualInput = false;
      });
    } catch (e) {
      _showError('Failed to parse text: $e');
    }
  }

  /// Upload POD document
  Future<void> _uploadPod() async {
    if (_podController.ocrFields == null) {
      _showError('Please capture and parse document first');
      return;
    }

    try {
      await _podController.uploadPod(
        companyId: widget.companyId,
        driverId: widget.driverId,
      );

      if (mounted && _podController.state == PodState.success) {
        _showSuccess(
          'Invoice captured successfully!\n'
          'POD ID: ${_podController.podDocumentId}',
        );

        // Reset form
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _podController.reset();
            _ocrTextController.clear();
            _showOcrInput = false;
            _showManualInput = false;
            setState(() {});
          }
        });
      }
    } catch (e) {
      _showError('Upload failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PodController>.value(
      value: _podController,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Capture Invoice'),
          elevation: 0,
          backgroundColor: Colors.blue.shade800,
        ),
        body: Consumer<PodController>(
          builder: (context, controller, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator
                  if (controller.isLoading)
                    LinearProgressIndicator(
                      value: controller.state == PodState.uploading ? null : 0.5,
                    ),
                  const SizedBox(height: 16),

                  // Step 1: Capture Image
                  _buildCaptureSection(controller),
                  const SizedBox(height: 24),

                  // Step 2: OCR Input (Conditional)
                  if (_showOcrInput) ...[
                    _buildOcrInputSection(controller),
                    const SizedBox(height: 24),
                  ],

                  // Step 3: Manual Input (Conditional)
                  if (_showManualInput) ...[
                    _buildManualInputSection(controller),
                    const SizedBox(height: 24),
                  ],

                  // Step 4: Preview Card (Show if OCR parsed)
                  if (controller.ocrFields != null) ...[
                    PodPreviewCard(
                      fields: controller.ocrFields!,
                      flags: controller.detectionFlags,
                      onEdit: () {
                        setState(() {
                          _showManualInput = true;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error message display
                  if ((controller.errorMessage ?? '').isNotEmpty)
                    _buildErrorBox(controller.errorMessage ?? ''),

                  // Action buttons
                  if (controller.ocrFields == null)
                    _buildCaptureButtons(controller)
                  else
                    _buildUploadButtons(controller),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Step 1: Capture section with camera/gallery buttons
  Widget _buildCaptureSection(PodController controller) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Capture Invoice Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Take a photo of the invoice or delivery note for processing',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (controller.capturedImage != null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: Image.network(controller.capturedImage!.path).image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Photo captured ✓',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Step 2: OCR input section (manual text entry)
  Widget _buildOcrInputSection(PodController controller) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Enter Invoice Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Paste the invoice text or manually enter key details below:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ocrTextController,
              maxLines: 8,
              minLines: 4,
              decoration: InputDecoration(
                hintText: '''Invoice Number: INV400098
Total Amount: R101,972.94
Tax: R13,300.82
Date: 06/10/2024
Supplier: Meat Traders
Customer: Boxer Superstores
Branch: X319
Vehicle: KFM 567 CC
Driver: Uuyo''',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              enabled: !controller.isLoading,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: controller.isLoading ? null : _parseOcrText,
              icon: const Icon(Icons.check),
              label: const Text('Parse Invoice Details'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 3: Manual input section (for editing parsed fields)
  Widget _buildManualInputSection(PodController controller) {
    if (controller.ocrFields == null) return const SizedBox.shrink();

    final fields = controller.ocrFields!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      '3',
                      style: TextStyle(
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Review & Edit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Review extracted information. Tap to edit any field:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildEditableField(
              'Invoice Number',
              fields.invoiceNo ?? '',
              Icons.receipt,
            ),
            _buildEditableField(
              'Total Amount (ZAR)',
              fields.totalIncl?.toStringAsFixed(2) ?? '',
              Icons.attach_money,
            ),
            _buildEditableField(
              'Supplier',
              fields.supplier ?? '',
              Icons.business,
            ),
            _buildEditableField(
              'Customer',
              fields.customer ?? '',
              Icons.person,
            ),
            _buildEditableField(
              'Vehicle Registration',
              fields.truckReg ?? '',
              Icons.directions_car,
            ),
            _buildEditableField(
              'Driver Name',
              fields.driverName ?? '',
              Icons.badge,
            ),
          ],
        ),
      ),
    );
  }

  /// Editable field widget
  Widget _buildEditableField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value.isNotEmpty ? value : '(Not detected)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: value.isNotEmpty ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit, size: 16, color: Colors.blue),
        ],
      ),
    );
  }

  /// Error display box
  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  /// Capture buttons (for initial capture)
  Widget _buildCaptureButtons(PodController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: controller.isLoading ? null : _captureFromCamera,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Photo'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: controller.isLoading ? null : _pickFromGallery,
          icon: const Icon(Icons.photo_library),
          label: const Text('Choose from Gallery'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  /// Upload buttons (for after OCR parsing)
  Widget _buildUploadButtons(PodController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: controller.isLoading ? null : _uploadPod,
          icon: const Icon(Icons.cloud_upload),
          label: Text(
            controller.isLoading ? 'Uploading...' : 'Upload Invoice',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: controller.isLoading
              ? null
              : () {
                  controller.reset();
                  _ocrTextController.clear();
                  setState(() {
                    _showOcrInput = false;
                    _showManualInput = false;
                  });
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Start Over'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
