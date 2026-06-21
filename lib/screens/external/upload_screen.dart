import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../models/external_delivery_token.dart';
import '../../models/delivery_model.dart';
import '../../services/external_upload_service.dart';
import '../../utils/theme.dart';

class ExternalUploadScreen extends StatefulWidget {
  final String token;

  const ExternalUploadScreen({super.key, required this.token});

  @override
  State<ExternalUploadScreen> createState() => _ExternalUploadScreenState();
}

class _ExternalUploadScreenState extends State<ExternalUploadScreen> {
  final ExternalUploadService _uploadService = ExternalUploadService();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  ExternalDeliveryToken? _tokenData;
  Delivery? _delivery;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  final List<XFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadTokenData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tokenData = await _uploadService.getToken(widget.token);
      if (tokenData == null) {
        setState(() {
          _errorMessage = 'Invalid or expired upload link';
          _isLoading = false;
        });
        return;
      }

      final delivery = await _uploadService.getDeliveryForToken(widget.token);
      
      setState(() {
        _tokenData = tokenData;
        _delivery = delivery;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading delivery information';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFiles.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting images: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitDocuments() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one document')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      bool success;
      
      if (kIsWeb) {
        // Web upload using bytes
        final List<Uint8List> filesBytes = [];
        final List<String> fileNames = [];
        
        for (var file in _selectedFiles) {
          final bytes = await file.readAsBytes();
          filesBytes.add(bytes);
          fileNames.add(file.name);
        }
        
        success = await _uploadService.uploadDocumentsWeb(
          token: widget.token,
          filesBytes: filesBytes,
          fileNames: fileNames,
          notes: _notesController.text.trim().isEmpty 
              ? null 
              : _notesController.text.trim(),
        );
      } else {
        // Mobile upload using File
        final List<File> files = _selectedFiles.map((xFile) => File(xFile.path)).toList();
        
        success = await _uploadService.uploadDocuments(
          token: widget.token,
          files: files,
          notes: _notesController.text.trim().isEmpty 
              ? null 
              : _notesController.text.trim(),
        );
      }

      if (success && mounted) {
        // Navigate to success screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExternalUploadSuccessScreen(
              orderNumber: _delivery?.invoiceNumber ?? 'N/A',
              customerName: _delivery?.customerName ?? 'N/A',
              fileCount: _selectedFiles.length,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload documents. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading delivery information...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'This link may have expired or been used already.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PODSafe Document Upload'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading documents...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery Information Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Delivery Information',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          
                          // Customer Information
                          Text(
                            'CUSTOMER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Name', _delivery?.customerName ?? 'N/A'),
                          const SizedBox(height: 8),
                          if (_delivery?.customerNumber != null)
                            _buildInfoRow('Customer #', _delivery!.customerNumber!),
                          if (_delivery?.customerNumber != null)
                            const SizedBox(height: 8),
                          _buildInfoRow('Address', _delivery?.customerAddress ?? 'N/A'),
                          if (_delivery?.customerPhone != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow('Phone', _delivery!.customerPhone!),
                          ],
                          
                          const SizedBox(height: 16),
                          const Divider(height: 24),
                          
                          // Order Information
                          Text(
                            'ORDER DETAILS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_delivery?.orderNumber != null) ...[
                            _buildInfoRow('Order Number', _delivery!.orderNumber!),
                            const SizedBox(height: 8),
                          ],
                          _buildInfoRow('Invoice Number', _delivery?.invoiceNumber ?? 'N/A'),
                          const SizedBox(height: 8),
                          if (_delivery?.invoiceDate != null) ...[
                            _buildInfoRow(
                              'Invoice Date',
                              '${_delivery!.invoiceDate!.day}/${_delivery!.invoiceDate!.month}/${_delivery!.invoiceDate!.year}',
                            ),
                            const SizedBox(height: 8),
                          ],
                          _buildInfoRow(
                            'Scheduled Date',
                            '${_delivery?.scheduledDate.day ?? ''}/${_delivery?.scheduledDate.month ?? ''}/${_delivery?.scheduledDate.year ?? ''}',
                          ),
                          
                          // Items List
                          if (_delivery?.items != null && _delivery!.items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 24),
                            Text(
                              'ITEMS (${_delivery!.items.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._delivery!.items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.description,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              'Qty: ${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                          
                          const SizedBox(height: 16),
                          const Divider(height: 24),
                          
                          // Transport Provider Information
                          Text(
                            'TRANSPORT PROVIDER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Provider', _tokenData?.providerName ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildInfoRow('Driver', _delivery?.thirdPartyDriverName ?? 'N/A'),
                          if (_delivery?.thirdPartyDriverPhone != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow('Driver Phone', _delivery!.thirdPartyDriverPhone!),
                          ],
                          if (_delivery?.thirdPartyVehicleInfo != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow('Vehicle', _delivery!.thirdPartyVehicleInfo!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload Section
                  Text(
                    'Upload Delivery Documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please upload proof of delivery (POD) and any other relevant documents.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Image Selection Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!kIsWeb)
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _pickMultipleImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose Files'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selected Files Preview
                  if (_selectedFiles.isNotEmpty) ...[
                    Text(
                      'Selected Files (${_selectedFiles.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: kIsWeb
                                  ? FutureBuilder<Uint8List>(
                                      future: _selectedFiles[index].readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        }
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_selectedFiles[index].path),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(24, 24),
                                ),
                                onPressed: () => _removeFile(index),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes Field
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes (Optional)',
                      hintText: 'Add any comments about the delivery...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedFiles.isEmpty ? null : _submitDocuments,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Submit Documents'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}

class ExternalUploadSuccessScreen extends StatelessWidget {
  final String orderNumber;
  final String customerName;
  final int fileCount;

  const ExternalUploadSuccessScreen({
    super.key,
    required this.orderNumber,
    required this.customerName,
    required this.fileCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Documents Uploaded Successfully',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for uploading the delivery documents. '
                'The customer has been notified.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow('Order Number', orderNumber),
                      const SizedBox(height: 8),
                      _buildInfoRow('Customer', customerName),
                      const SizedBox(height: 8),
                      _buildInfoRow('Files Uploaded', '$fileCount'),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Date',
                        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} '
                        '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'You can now close this page.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Text(value),
      ],
    );
  }
}
