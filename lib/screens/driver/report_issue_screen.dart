import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../../models/claim_model.dart';
import '../../models/company_claim_settings.dart';
import '../../models/delivery_model.dart';
import '../../models/pod_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/claim_service.dart';

/// Screen for drivers to report issues/claims at delivery site
class ReportIssueScreen extends StatefulWidget {
  final Delivery delivery;
  final PODRecord? pod;
  final bool isAtDeliverySite; // true = immediate, false = delayed

  const ReportIssueScreen({
    super.key,
    required this.delivery,
    this.pod,
    this.isAtDeliverySite = true,
  });

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _claimService = ClaimService();
  final _imagePicker = ImagePicker();
  
  // Form fields
  ClaimType? _selectedType;
  final _descriptionController = TextEditingController();
  final List<File> _photos = [];
  final List<String> _photoUrls = [];
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  
  // Custom fields values
  final Map<String, dynamic> _customFieldValues = {};
  
  // Affected items
  final List<Map<String, dynamic>> _affectedItems = [];
  
  // Loading
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _signatureController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final claimProvider = context.watch<ClaimProvider>();
    final enabledTypes = claimProvider.getEnabledClaimTypes();
    final settings = claimProvider.settings;
    
    // Get safe area insets for proper spacing
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAtDeliverySite ? 'Report Issue' : 'File Claim'),
        backgroundColor: Colors.orange,
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting claim...'),
                ],
              ),
            )
          : SafeArea(
              bottom: true,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    // Add bottom padding that accounts for navigation bar + extra space
                    bottom: bottomPadding > 0 ? bottomPadding + 16 : 80,
                  ),
                  children: [
                  // Context indicator
                  if (widget.isAtDeliverySite)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Filing at delivery site - evidence will be stronger',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Delivery info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Customer', widget.delivery.customerName),
                          _buildInfoRow('Address', widget.delivery.customerAddress),
                          _buildInfoRow('Invoice', widget.delivery.invoiceNumber),
                          _buildInfoRow(
                            'Delivery Date',
                            _formatDate(widget.delivery.scheduledDate),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Claim type selection
                  DropdownButtonFormField<ClaimType>(
                    decoration: const InputDecoration(
                      labelText: 'Issue Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning_amber),
                    ),
                    value: _selectedType,
                    items: enabledTypes.toSet().map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getClaimTypeDisplay(type)),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null) return 'Please select an issue type';
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value;
                        _customFieldValues.clear(); // Reset custom fields
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Custom fields (dynamic based on claim type)
                  if (_selectedType != null)
                    ..._buildCustomFields(
                      claimProvider.getCustomFieldsForType(_selectedType!),
                    ),
                  
                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Describe the issue in detail...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please describe the issue';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Affected items
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Affected Items',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...widget.delivery.items.map((item) {
                            final isAffected = _affectedItems.any(
                              (ai) => ai['description'] == item.description,
                            );
                            return CheckboxListTile(
                              dense: true,
                              title: Text(item.description),
                              subtitle: Text('Qty: ${item.quantity} ${item.unit}'),
                              value: isAffected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _affectedItems.add({
                                      'description': item.description,
                                      'quantity': item.quantity,
                                      'unit': item.unit,
                                    });
                                  } else {
                                    _affectedItems.removeWhere(
                                      (ai) => ai['description'] == item.description,
                                    );
                                  }
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Photos
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Photos',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (settings?.photosMandatory == true)
                                const Text(
                                  ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              const Spacer(),
                              Text(
                                '${_photos.length}/${settings?.maxPhotosAllowed ?? 10}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          if (settings?.minPhotosRequired != null &&
                              settings!.minPhotosRequired > 0)
                            Text(
                              'Minimum ${settings.minPhotosRequired} photo(s) required',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          const SizedBox(height: 12),
                          
                          // Photo grid
                          if (_photos.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _photos.asMap().entries.map((entry) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        entry.value,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _photos.removeAt(entry.key);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          
                          const SizedBox(height: 12),
                          
                          // Add photo buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _canAddMorePhotos()
                                      ? () => _takePhoto(ImageSource.camera)
                                      : null,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Take Photo'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _canAddMorePhotos()
                                      ? () => _takePhoto(ImageSource.gallery)
                                      : null,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Gallery'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Customer signature (if at delivery site)
                  if (widget.isAtDeliverySite &&
                      (settings?.requireCustomerSignature ?? false))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer Acknowledgment *',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Customer signature acknowledging the issue',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Signature(
                                controller: _signatureController,
                                height: 150,
                                backgroundColor: Colors.grey.shade50,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    _signatureController.clear();
                                  },
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Clear'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Submit button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitClaim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text(
                        'Submit Claim',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
  
  List<Widget> _buildCustomFields(List<CustomFieldDefinition> fields) {
    return fields.map((field) {
      switch (field.type) {
        case CustomFieldType.text:
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextFormField(
              decoration: InputDecoration(
                labelText: field.label + (field.required ? ' *' : ''),
                hintText: field.placeholder,
                helperText: field.helpText,
                border: const OutlineInputBorder(),
              ),
              maxLength: field.maxLength,
              validator: (value) {
                if (field.required && (value == null || value.isEmpty)) {
                  return 'This field is required';
                }
                if (field.validationRegex != null && value != null) {
                  final regex = RegExp(field.validationRegex!);
                  if (!regex.hasMatch(value)) {
                    return field.errorMessage ?? 'Invalid format';
                  }
                }
                return null;
              },
              onChanged: (value) {
                _customFieldValues[field.id] = value;
              },
            ),
          );
        
        case CustomFieldType.number:
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextFormField(
              decoration: InputDecoration(
                labelText: field.label + (field.required ? ' *' : ''),
                hintText: field.placeholder,
                helperText: field.helpText,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (field.required && (value == null || value.isEmpty)) {
                  return 'This field is required';
                }
                if (value != null && value.isNotEmpty) {
                  final number = double.tryParse(value);
                  if (number == null) return 'Must be a valid number';
                  if (field.minValue != null && number < field.minValue!) {
                    return 'Minimum value is ${field.minValue}';
                  }
                  if (field.maxValue != null && number > field.maxValue!) {
                    return 'Maximum value is ${field.maxValue}';
                  }
                }
                return null;
              },
              onChanged: (value) {
                _customFieldValues[field.id] = double.tryParse(value);
              },
            ),
          );
        
        case CustomFieldType.dropdown:
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: field.label + (field.required ? ' *' : ''),
                helperText: field.helpText,
                border: const OutlineInputBorder(),
              ),
              items: field.dropdownOptions?.map((option) {
                return DropdownMenuItem(value: option, child: Text(option));
              }).toList(),
              validator: (value) {
                if (field.required && value == null) {
                  return 'Please select an option';
                }
                return null;
              },
              onChanged: (value) {
                _customFieldValues[field.id] = value;
              },
            ),
          );
        
        case CustomFieldType.checkbox:
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CheckboxListTile(
              dense: true,
              title: Text(field.label + (field.required ? ' *' : '')),
              subtitle: field.helpText != null ? Text(field.helpText!) : null,
              value: _customFieldValues[field.id] ?? false,
              onChanged: (value) {
                setState(() {
                  _customFieldValues[field.id] = value;
                });
              },
            ),
          );
        
        default:
          return const SizedBox.shrink();
      }
    }).toList();
  }
  
  bool _canAddMorePhotos() {
    final settings = context.read<ClaimProvider>().settings;
    final maxPhotos = settings?.maxPhotosAllowed ?? 10;
    return _photos.length < maxPhotos;
  }
  
  Future<void> _takePhoto(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _photos.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    }
  }
  
  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = context.read<AuthProvider>();
    final claimProvider = context.read<ClaimProvider>();
    final settings = claimProvider.settings;
    
    // Initialize provider if needed
    if (claimProvider.companyId == null) {
      await claimProvider.initialize(authProvider.companyId!);
    }
    
    // Validate photos
    if (settings?.photosMandatory == true && _photos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one photo is required')),
        );
      }
      return;
    }
    
    if (settings?.minPhotosRequired != null &&
        _photos.length < settings!.minPhotosRequired) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('At least ${settings.minPhotosRequired} photos required'),
          ),
        );
      }
      return;
    }
    
    // Validate signature
    if (widget.isAtDeliverySite &&
        settings?.requireCustomerSignature == true &&
        _signatureController.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer signature is required')),
        );
      }
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Generate claim ID
      final claimId = await _claimService.generateClaimId(authProvider.companyId!);
      
      // Upload photos
      for (int i = 0; i < _photos.length; i++) {
        final url = await _claimService.uploadPhoto(
          companyId: authProvider.companyId!,
          claimId: claimId,
          photoFile: _photos[i],
          fileName: 'photo_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        _photoUrls.add(url);
      }
      
      // Upload signature if present
      String? signatureUrl;
      if (widget.isAtDeliverySite && _signatureController.isNotEmpty) {
        final signatureData = await _signatureController.toPngBytes();
        if (signatureData != null) {
          // Save signature to temp file
          final tempDir = Directory.systemTemp;
          final signatureFile = File('${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
          await signatureFile.writeAsBytes(signatureData);
          
          signatureUrl = await _claimService.uploadSignature(
            companyId: authProvider.companyId!,
            claimId: claimId,
            signatureFile: signatureFile,
            signatureType: 'customer',
          );
        }
      }
      
      // Get GPS location
      final gpsLocation = await _claimService.getCurrentLocation();
      
      // Get workflow for this claim type
      final workflow = claimProvider.getWorkflowForType(_selectedType!);
      final approvalChain = workflow.map((role) {
        return ApprovalLevel(
          role: role.role,
          slaHours: role.slaHours,
        );
      }).toList();
      
      // Create custom fields list
      final customFields = claimProvider
          .getCustomFieldsForType(_selectedType!)
          .map((field) {
        return CustomField(
          id: field.id,
          label: field.label,
          type: field.type,
          required: field.required,
          value: _customFieldValues[field.id],
        );
      }).toList();
      
      // Calculate evidence quality score
      final evidenceScore = _claimService.calculateEvidenceQualityScore(
        Claim(
          id: claimId,
          companyId: authProvider.companyId!,
          type: _selectedType!,
          status: ClaimStatus.submitted,
          priority: ClaimPriority.medium,
          filingContext: widget.isAtDeliverySite
              ? ClaimFilingContext.atDeliverySite
              : ClaimFilingContext.afterDelivery,
          title: _getClaimTypeDisplay(_selectedType!),
          description: _descriptionController.text,
          deliveryId: widget.delivery.id,
          podId: widget.pod?.id,
          customerId: widget.delivery.invoiceNumber, // Using invoice number as customer identifier
          customerName: widget.delivery.customerName,
          customerNumber: widget.delivery.customerNumber,
          driverId: authProvider.currentUser!.id,
          driverName: authProvider.currentUser!.fullName,
          invoiceNumber: widget.delivery.invoiceNumber,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deliveryDate: widget.delivery.scheduledDate,
          filedBy: authProvider.currentUser!.id,
          filedByName: authProvider.currentUser!.fullName,
          filedByRole: 'driver',
          photoUrls: _photoUrls,
          customerSignatureUrl: signatureUrl,
          gpsLocation: gpsLocation,
          approvalChain: approvalChain,
          filedAtDelivery: widget.isAtDeliverySite ? DateTime.now() : null,
          customerAcknowledged: signatureUrl != null,
          affectedItems: _affectedItems,
          customFields: customFields,
        ),
      );
      
      // Create claim
      final claim = Claim(
        id: claimId,
        companyId: authProvider.companyId!,
        type: _selectedType!,
        status: ClaimStatus.submitted,
        priority: ClaimPriority.medium,
        filingContext: widget.isAtDeliverySite
            ? ClaimFilingContext.atDeliverySite
            : ClaimFilingContext.afterDelivery,
        title: _getClaimTypeDisplay(_selectedType!),
        description: _descriptionController.text,
        deliveryId: widget.delivery.id,
        podId: widget.pod?.id,
        customerId: widget.delivery.invoiceNumber, // Using invoice number as customer identifier
        customerName: widget.delivery.customerName,
        customerNumber: widget.delivery.customerNumber,
        driverId: authProvider.currentUser!.id,
        driverName: authProvider.currentUser!.fullName,
        invoiceNumber: widget.delivery.invoiceNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryDate: widget.delivery.scheduledDate,
        filedBy: authProvider.currentUser!.id,
        filedByName: authProvider.currentUser!.fullName,
        filedByRole: 'driver',
        photoUrls: _photoUrls,
        customerSignatureUrl: signatureUrl,
        gpsLocation: gpsLocation,
        approvalChain: approvalChain,
        filedAtDelivery: widget.isAtDeliverySite ? DateTime.now() : null,
        customerAcknowledged: signatureUrl != null,
        affectedItems: _affectedItems,
        customFields: customFields,
        evidenceQualityScore: evidenceScore,
        hasAllRequiredEvidence: _photoUrls.length >= (settings?.minPhotosRequired ?? 0),
        metadata: {
          // Store order number for filtering
          'orderNumber': widget.delivery.orderNumber ?? widget.delivery.id,
        },
        statusHistory: [
          StatusHistoryEntry(
            status: ClaimStatus.submitted,
            timestamp: DateTime.now(),
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.fullName,
            notes: 'Claim filed',
          ),
        ],
      );
      
      // Save to Firestore
      final savedClaimId = await claimProvider.createClaim(claim);
      
      if (savedClaimId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim $claimId submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        // Show error from provider if available
        final errorMsg = claimProvider.error ?? 'Failed to submit claim';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
  
  String _getClaimTypeDisplay(ClaimType type) {
    switch (type) {
      case ClaimType.damaged:
        return 'Damaged Goods';
      case ClaimType.shortage:
        return 'Short Delivered';
      case ClaimType.shortWeight:
        return 'Short Weight';
      case ClaimType.missing:
        return 'Missing Items';
      case ClaimType.wrongItems:
        return 'Wrong Items';
      case ClaimType.returns:
        return 'Returns';
      case ClaimType.priceError:
        return 'Price Error';
      case ClaimType.lateDelivery:
        return 'Late Delivery';
      case ClaimType.didNotDeliver:
        return 'Did Not Deliver';
      case ClaimType.qualityIssue:
        return 'Quality Issue';
      case ClaimType.temperatureIssue:
        return 'Temperature Issue';
      case ClaimType.packagingIssue:
        return 'Packaging Issue';
      case ClaimType.expiryIssue:
        return 'Expiry Issue';
      case ClaimType.serviceIssue:
        return 'Service Issue';
      case ClaimType.other:
        return 'Other';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
