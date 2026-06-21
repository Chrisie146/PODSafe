import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart' as sig;
import '../../models/claim_model.dart';
import '../../models/delivery_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

/// Form for creating new claims without requiring evidence
/// Allows admin to quickly create claims and upload evidence later
class CreateClaimForm extends StatefulWidget {
  final VoidCallback? onClaimCreated;

  const CreateClaimForm({
    super.key,
    this.onClaimCreated,
  });

  @override
  State<CreateClaimForm> createState() => _CreateClaimFormState();
}

class _CreateClaimFormState extends State<CreateClaimForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _signaturePad = sig.SignatureController();
  final _imagePicker = ImagePicker();

  ClaimType? _selectedType;
  Delivery? _selectedDelivery;
  Set<int> _selectedItemIndices = {}; // Track selected items from delivery
  List<XFile> _selectedPhotos = [];
  // Normalized in-memory photo maps: { 'bytes': Uint8List, 'filename': String }
  List<Map<String, dynamic>> _selectedPhotoMaps = [];
  XFile? _selectedSignature;
  bool _takePhotosNow = false;
  bool _getSignatureNow = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Load deliveries when form opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final deliveryProvider = Provider.of<DeliveryProvider>(context, listen: false);
      
      if (authProvider.companyId != null) {
        print('[CreateClaimForm] Loading deliveries for company: ${authProvider.companyId}');
        deliveryProvider.loadCompanyDeliveries(authProvider.companyId!);
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _signaturePad.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxHeight: 1080,
        maxWidth: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        // Normalize to in-memory bytes immediately for cross-platform compatibility
        // (on web, File objects from dart:io are unsupported stubs)
        final tempMaps = <Map<String, dynamic>>[];
        for (final xf in pickedFiles) {
          try {
            final bytes = await xf.readAsBytes();
            tempMaps.add({'bytes': bytes, 'filename': xf.name});
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to read a selected photo: $e')),
            );
          }
        }

        setState(() {
          _selectedPhotos = pickedFiles;
          _selectedPhotoMaps = tempMaps;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking photos: $e')),
      );
    }
  }

  Future<void> _captureSignature() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capture Signature'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: sig.Signature(
            controller: _signaturePad,
            backgroundColor: Colors.grey[100]!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _signaturePad.clear();
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final signatureImage = await _signaturePad.toImage();
        if (signatureImage != null) {
          // Convert image to PNG bytes
          final pngBytes = await signatureImage.toByteData();
          if (pngBytes != null) {
            final bytes = pngBytes.buffer.asUint8List();
            
            if (bytes.isNotEmpty) {
              final tempDir = Directory.systemTemp;
              final signatureFile = File(
                '${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png',
              );
              await signatureFile.writeAsBytes(bytes);
              setState(() {
                _selectedSignature = XFile(signatureFile.path);
              });
            }
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving signature: $e')),
        );
      }
    }
  }

  Future<void> _createClaim() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a claim type')),
      );
      return;
    }

    if (_selectedDelivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final claimProvider = context.read<ClaimProvider>();

      final newClaim = Claim(
        id: '',
        companyId: authProvider.companyId!,
        type: _selectedType!,
        status: ClaimStatus.submitted,
        priority: ClaimPriority.medium,
        filingContext: ClaimFilingContext.afterDelivery,
        title: _getClaimTypeDisplayName(_selectedType!),
        description: _descriptionController.text,
        deliveryId: _selectedDelivery!.id,
        customerId: _selectedDelivery!.customerId ?? '',
        customerName: _selectedDelivery!.customerName,
        customerNumber: _selectedDelivery!.customerNumber,
        driverId: _selectedDelivery!.driverId,
        driverName: 'Driver',
        invoiceNumber: _selectedDelivery!.invoiceNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryDate: DateTime.now(),
        filedBy: authProvider.currentUser?.id ?? '',
        filedByName: authProvider.currentUser?.fullName ?? 'Admin',
        filedByRole: authProvider.currentUser?.role.toString().split('.').last ?? 'admin',
        affectedItems: _buildAffectedItemsList(),
        evidenceStatus: 'pending',
      );

      final claimId = await claimProvider.createClaimWithoutEvidence(newClaim);

      // Upload evidence if selected
      if (_takePhotosNow && _selectedPhotos.isNotEmpty) {
        // Pass normalized in-memory photo maps (bytes + filename) for cross-platform compatibility
        await claimProvider.uploadEvidenceToClaim(
          claimId,
          _selectedPhotoMaps,
          _getSignatureNow ? _selectedSignature : null,
          null,
        );
      } else if (_getSignatureNow && _selectedSignature != null) {
        await claimProvider.uploadEvidenceToClaim(
          claimId,
          null,
          _selectedSignature,
          null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim created successfully: $claimId'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _formKey.currentState!.reset();
        _descriptionController.clear();
        setState(() {
          _selectedType = null;
          _selectedDelivery = null;
          _selectedItemIndices = {};
          _selectedPhotos = [];
          _selectedSignature = null;
          _takePhotosNow = false;
          _getSignatureNow = false;
        });

        widget.onClaimCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating claim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  /// Build list of affected items from delivery
  List<Map<String, dynamic>> _buildAffectedItemsList() {
    if (_selectedDelivery == null || _selectedItemIndices.isEmpty) {
      return [];
    }
    
    final affected = <Map<String, dynamic>>[];
    for (var i in _selectedItemIndices) {
      if (i >= 0 && i < _selectedDelivery!.items.length) {
        final item = _selectedDelivery!.items[i];
        affected.add({
          'description': item.description,
          'quantity': item.quantity,
          'unit': item.unit,
        });
      }
    }
    return affected;
  }

  /// Build the affected items section UI
  Widget _buildAffectedItemsSection() {
    if (_selectedDelivery == null || _selectedDelivery!.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          'Select a delivery to see its items',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedDelivery!.items.length,
            itemBuilder: (context, index) {
              final item = _selectedDelivery!.items[index];
              final isSelected = _selectedItemIndices.contains(index);
              
              return Container(
                decoration: BoxDecoration(
                  border: index < _selectedDelivery!.items.length - 1
                      ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                      : null,
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedItemIndices.add(index);
                      } else {
                        _selectedItemIndices.remove(index);
                      }
                    });
                  },
                  title: Text(
                    item.description,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Qty: ${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              );
            },
          ),
          if (_selectedItemIndices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_selectedItemIndices.length} item(s) selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.add_circle, size: 28, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Claim',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a claim without evidence - upload photos and signatures later',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Claim Type
            Text(
              'Claim Type *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ClaimType>(
              value: _selectedType,
              onChanged: (value) {
                setState(() => _selectedType = value);
              },
              items: ClaimType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_getClaimTypeDisplayName(type)),
                      ))
                  .toList(),
              decoration: InputDecoration(
                hintText: 'Select claim type',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) =>
                  value == null ? 'Please select a claim type' : null,
            ),
            const SizedBox(height: 20),

            // Delivery Selection
            Text(
              'Delivery *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            _buildDeliverySearchField(),
            const SizedBox(height: 20),

            // Description
            Text(
              'Description *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe the issue or claim reason...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.description),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter a description' : null,
            ),
            const SizedBox(height: 20),

            // Affected Items
            Text(
              'Affected Items (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            _buildAffectedItemsSection(),
            const SizedBox(height: 24),

            // Evidence Section Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Evidence is optional now - you can upload it later',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Photos
            _buildEvidenceSection(
              title: 'Take Photos Now?',
              icon: Icons.camera_alt,
              value: _takePhotosNow,
              onChanged: (value) => setState(() => _takePhotosNow = value ?? false),
      child: _takePhotosNow
        ? _buildPhotosDisplay()
        : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Signature
            _buildEvidenceSection(
              title: 'Get Signature Now?',
              icon: Icons.edit,
              value: _getSignatureNow,
              onChanged: (value) =>
                  setState(() => _getSignatureNow = value ?? false),
              child: _getSignatureNow
                  ? _buildSignatureDisplay()
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCreating
                        ? null
                        : () {
                            _formKey.currentState!.reset();
                            _descriptionController.clear();
                            setState(() {
                              _selectedType = null;
                              _selectedDelivery = null;
                              _selectedItemIndices = {};
                              _selectedPhotos = [];
                              _selectedSignature = null;
                              _takePhotosNow = false;
                              _getSignatureNow = false;
                            });
                          },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isCreating ? null : _createClaim,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isCreating ? 'Creating...' : 'Create Claim'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySearchField() {
    return Consumer<DeliveryProvider>(
      builder: (context, deliveryProvider, _) {
        // Sort deliveries by ID for easier browsing
        final sortedDeliveries = deliveryProvider.deliveries.toList()
          ..sort((a, b) => b.id.compareTo(a.id)); // Most recent first

        // Debug: Check if we have deliveries
        print('Available deliveries: ${sortedDeliveries.length}');
        
        if (sortedDeliveries.isEmpty) {
          return TextFormField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Select Delivery',
              hintText: 'No deliveries available',
              prefixIcon: const Icon(Icons.local_shipping),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              helperText: 'Create a delivery first in Delivery Management',
            ),
            validator: (value) => 'Please create a delivery first',
          );
        }

        return DropdownButtonFormField<Delivery>(
          value: _selectedDelivery,
          decoration: InputDecoration(
            labelText: 'Select Delivery',
            hintText: 'Choose a delivery...',
            prefixIcon: const Icon(Icons.local_shipping),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            helperText: '${sortedDeliveries.length} deliveries available',
          ),
          isExpanded: true,
          items: sortedDeliveries.map((delivery) {
            return DropdownMenuItem<Delivery>(
              value: delivery,
              child: Text(
                '${delivery.id} - ${delivery.customerName} (${delivery.items.length} items)',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (Delivery? newValue) {
            print('Selected delivery: ${newValue?.id}');
            setState(() {
              _selectedDelivery = newValue;
            });
          },
          validator: (value) => value == null
              ? 'Please select a delivery'
              : null,
          menuMaxHeight: 400,
        );
      },
    );
  }

  Widget _buildEvidenceSection({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(title),
          secondary: Icon(icon),
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (value) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: child,
          ),
        ],
      ],
    );
  }

  Widget _buildPhotosDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedPhotoMaps.isEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Pick Photos'),
            ),
          )
        else
          Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  _selectedPhotoMaps.length,
                  (index) => Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Builder(builder: (context) {
                          final bytes = _selectedPhotoMaps[index]['bytes'] as Uint8List?;
                          if (bytes == null || bytes.isEmpty) {
                            return const Center(child: Icon(Icons.error));
                          }
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                          );
                        }),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPhotoMaps.removeAt(index);
                              // Keep _selectedPhotos in sync if possible
                              if (index < _selectedPhotos.length) {
                                _selectedPhotos.removeAt(index);
                              }
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add More Photos'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSignatureDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedSignature == null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _captureSignature,
              icon: const Icon(Icons.edit),
              label: const Text('Capture Signature'),
            ),
          )
        else
          Column(
            children: [
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FutureBuilder<Uint8List>(
                  future: _selectedSignature!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const Center(child: Icon(Icons.error));
                    }
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _selectedSignature = null);
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureSignature,
                      icon: const Icon(Icons.edit),
                      label: const Text('Re-capture'),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  String _getClaimTypeDisplayName(ClaimType type) {
    return {
          ClaimType.damaged: 'Damaged Goods',
          ClaimType.shortage: 'Short Delivered',
          ClaimType.shortWeight: 'Short Weight',
          ClaimType.missing: 'Missing Items',
          ClaimType.wrongItems: 'Wrong Items',
          ClaimType.returns: 'Returns',
          ClaimType.priceError: 'Price Error',
          ClaimType.lateDelivery: 'Late Delivery',
          ClaimType.didNotDeliver: 'Did Not Deliver',
          ClaimType.qualityIssue: 'Quality Issue',
          ClaimType.temperatureIssue: 'Temperature Issue',
          ClaimType.packagingIssue: 'Packaging Issue',
          ClaimType.expiryIssue: 'Expiry Issue',
          ClaimType.serviceIssue: 'Service Issue',
          ClaimType.other: 'Other',
        }[type] ??
        'Unknown';
  }
}
