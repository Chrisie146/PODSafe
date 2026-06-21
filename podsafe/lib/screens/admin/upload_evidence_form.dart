import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../../models/claim_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/auth_provider.dart';

class UploadEvidenceForm extends StatefulWidget {
  const UploadEvidenceForm({super.key});

  @override
  State<UploadEvidenceForm> createState() => _UploadEvidenceFormState();
}

class _UploadEvidenceFormState extends State<UploadEvidenceForm> {
  late SignatureController _signaturePad;
  // Normalized in-memory photo maps: { 'bytes': Uint8List, 'filename': String }
  final List<Map<String, dynamic>> _selectedPhotoMaps = [];
  Map<String, dynamic>? _selectedSignature;
  Claim? _selectedClaim;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _signaturePad = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      onDrawStart: () {},
      onDrawEnd: () {},
    );
    
    // Initialize ClaimProvider with company ID (only if not already initialized)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final claimProvider = Provider.of<ClaimProvider>(context, listen: false);
      
      if (authProvider.companyId != null && claimProvider.companyId != authProvider.companyId) {
        await claimProvider.initialize(authProvider.companyId!);
        // No need for setState - ClaimProvider.loadSettings() calls notifyListeners()
      }
    });
  }

  @override
  void dispose() {
    _signaturePad.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFiles.isNotEmpty) {
        // Normalize to in-memory bytes for cross-platform compatibility
        final tempMaps = <Map<String, dynamic>>[];
        for (final xf in pickedFiles) {
          try {
            final bytes = await xf.readAsBytes();
            if (bytes.isNotEmpty && tempMaps.length + _selectedPhotoMaps.length < 5) {
              tempMaps.add({'bytes': bytes, 'filename': xf.name});
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to read selected photo: $e')),
            );
          }
        }

        setState(() {
          _selectedPhotoMaps.addAll(tempMaps);
        });
      }
    } catch (e) {
      if (!mounted) return;
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
          child: Signature(
            controller: _signaturePad,
            backgroundColor: Colors.grey[200]!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _signaturePad.clear();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
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
          final pngBytes = await signatureImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final bytes = pngBytes?.buffer.asUint8List();

          if (bytes != null && bytes.isNotEmpty) {
            setState(() {
              _selectedSignature = {
                'bytes': bytes,
                'filename': 'signature_${DateTime.now().millisecondsSinceEpoch}.png'
              };
            });
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving signature: $e')),
        );
      }
    }
  }

  /// Build image widget from bytes
  Widget _buildPhotoImageFromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
    );
  }

  /// Build signature image widget from bytes
  Widget _buildSignatureImageFromBytes(Uint8List bytes, double height, double width) {
    if (bytes.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
    return Image.memory(
      bytes,
      height: height,
      width: width,
      fit: BoxFit.contain,
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotoMaps.removeAt(index);
    });
  }

  void _removeSignature() {
    setState(() {
      _selectedSignature = null;
    });
  }

  Future<void> _uploadEvidence() async {
    if (_selectedClaim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a claim')),
      );
      return;
    }

    if (_selectedPhotoMaps.isEmpty && _selectedSignature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add photos or signature')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final claimProvider = context.read<ClaimProvider>();

      await claimProvider.uploadEvidenceToClaim(
        _selectedClaim!.id,
        _selectedPhotoMaps.isNotEmpty ? _selectedPhotoMaps : null,
        _selectedSignature,
        null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evidence uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form
      setState(() {
        _selectedClaim = null;
        _selectedPhotoMaps.clear();
        _selectedSignature = null;
        _isUploading = false;
      });
      _signaturePad.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading evidence: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't listen to ClaimProvider changes to avoid recreating StreamBuilder
    final claimProvider = Provider.of<ClaimProvider>(context, listen: false);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Upload Evidence to Claims',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Select a claim pending evidence and upload photos or signature',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // Pending Claims List
          Text(
            'Claims Pending Evidence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildPendingClaimsDropdown(claimProvider),
          const SizedBox(height: 24),

          // Selected Claim Info
          if (_selectedClaim != null) ...[
            _buildClaimInfoCard(),
            const SizedBox(height: 24),
          ],

          // Photos Section
          Text(
            'Photos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildPhotosSection(),
          const SizedBox(height: 24),

          // Signature Section
          Text(
            'Signature',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildSignatureSection(),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isUploading
                    ? null
                    : () {
                        setState(() {
                          _selectedClaim = null;
                          _selectedPhotoMaps.clear();
                          _selectedSignature = null;
                        });
                        _signaturePad.clear();
                      },
                child: const Text('Clear'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isUploading ? null : _uploadEvidence,
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upload Evidence'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingClaimsDropdown(ClaimProvider provider) {
    // Don't show stream until provider is initialized
    if (provider.companyId == null) {
      return DropdownButtonFormField<Claim>(
        items: const [],
        onChanged: null,
        decoration: InputDecoration(
          labelText: 'Claims Pending Evidence',
          hintText: 'Initializing...',
          prefixIcon: const Icon(Icons.assignment),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          helperText: 'Loading...',
        ),
      );
    }

    print('[_buildPendingClaimsDropdown] Building StreamBuilder');
    final stream = provider.getClaimsPendingEvidenceStream();
    
    return StreamBuilder<List<Claim>>(
      stream: stream,
      builder: (context, snapshot) {
        final pendingClaims = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        
        if (snapshot.hasError) {
          return DropdownButtonFormField<Claim>(
            items: const [],
            onChanged: null,
            decoration: InputDecoration(
              labelText: 'Claims Pending Evidence',
              hintText: 'Error loading claims',
              prefixIcon: const Icon(Icons.assignment),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: 'Failed to load claims',
            ),
          );
        }

        // Show loading state
        if (isLoading && pendingClaims.isEmpty) {
          return DropdownButtonFormField<Claim>(
            items: const [],
            onChanged: null,
            decoration: InputDecoration(
              labelText: 'Claims Pending Evidence',
              hintText: 'Loading claims...',
              prefixIcon: const Icon(Icons.assignment),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              helperText: 'Loading...',
            ),
          );
        }

        // Show empty state only if we have data and it's empty
        if (pendingClaims.isEmpty && snapshot.hasData && !isLoading) {
          return DropdownButtonFormField<Claim>(
            items: const [],
            onChanged: null,
            decoration: InputDecoration(
              labelText: 'Claims Pending Evidence',
              hintText: 'No claims pending evidence',
              prefixIcon: const Icon(Icons.assignment),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              helperText: 'All claims have evidence or create a claim first',
            ),
            validator: (value) => 'No claims available',
          );
        }

        // Show dropdown with claims
        return DropdownButtonFormField<Claim>(
          value: _selectedClaim,
          isExpanded: true,
          items: pendingClaims.map((claim) {
            return DropdownMenuItem(
              value: claim,
              child: Text(
                '${claim.id} - ${claim.customerName} (${claim.type})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (claim) {
            setState(() => _selectedClaim = claim);
          },
          decoration: InputDecoration(
            labelText: 'Claims Pending Evidence',
            hintText: 'Select a claim to upload evidence',
            prefixIcon: const Icon(Icons.assignment),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            helperText: '${pendingClaims.length} claim${pendingClaims.length != 1 ? 's' : ''} pending evidence',
          ),
          validator: (value) =>
              value == null ? 'Please select a claim' : null,
        );
      },
    );
  }

  Widget _buildClaimInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Claim Details',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Chip(
                  label: const Text('Pending Evidence'),
                  backgroundColor: Colors.orange[100],
                  labelStyle: TextStyle(color: Colors.orange[900]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Claim ID', _selectedClaim!.id),
            _buildInfoRow('Customer', _selectedClaim!.customerName),
            _buildInfoRow('Type', _getClaimTypeDisplayName(_selectedClaim!.type)),
            _buildInfoRow('Description', _selectedClaim!.description),
            _buildInfoRow(
              'Filing Date',
              _dateFormatter(_selectedClaim!.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      children: [
        if (_selectedPhotoMaps.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Column(
              children: [
                Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'No photos selected',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Photos'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Up to 5 photos (JPEG/PNG)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedPhotoMaps.length,
                itemBuilder: (context, index) {
                  final bytes = _selectedPhotoMaps[index]['bytes'] as Uint8List?;
                  return Stack(
                    children: [
                      if (bytes != null) _buildPhotoImageFromBytes(bytes) else Container(),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _removePhoto(index),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_selectedPhotoMaps.length < 5)
                FilledButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add),
                  label: Text('Add More Photos (${5 - _selectedPhotoMaps.length} left)'),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Column(
      children: [
        if (_selectedSignature == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Column(
              children: [
                Icon(Icons.edit_note, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'No signature captured',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _captureSignature,
                  icon: const Icon(Icons.draw),
                  label: const Text('Capture Signature'),
                ),
              ],
            ),
          )
        else
          Stack(
            children: [
              if ((_selectedSignature?['bytes'] as Uint8List?) != null)
                _buildSignatureImageFromBytes(
                  _selectedSignature!['bytes'] as Uint8List,
                  200,
                  double.infinity,
                )
              else
                Container(height: 200),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _removeSignature,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (_selectedSignature != null)
          FilledButton.icon(
            onPressed: _captureSignature,
            icon: const Icon(Icons.refresh),
            label: const Text('Recapture Signature'),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _dateFormatter(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getClaimTypeDisplayName(ClaimType type) {
    final typeString = type.toString().split('.').last;
    return typeString
        .replaceAllMapped(
          RegExp(r'_'),
          (match) => ' ',
        )
        .replaceAllMapped(
          RegExp(r'\b\w'),
          (match) => match.group(0)?.toUpperCase() ?? '',
        );
  }
}
