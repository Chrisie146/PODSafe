import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../models/vehicle_model.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/vehicle_document_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  late Stream<List<Vehicle>> _vehiclesStream;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  bool _isImageUrl(String url) {
    try {
      // Parse the URL and check the path (ignores query params like ?alt=media&token=...)
      final path = Uri.parse(url).path.toLowerCase();
      return path.endsWith('.png') ||
          path.endsWith('.jpg') ||
          path.endsWith('.jpeg') ||
          path.endsWith('.gif') ||
          path.endsWith('.webp');
    } catch (_) {
      final lower = url.toLowerCase();
      return lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.gif') ||
          lower.contains('.webp');
    }
  }

  Future<void> _deleteDocument(Vehicle vehicle, String docUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Delete this document? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      if (companyId == null) throw Exception('No company ID');

      final docService = _getDocumentService();
      await docService.deleteByUrl(docUrl);

      // Remove URL from Firestore vehicle document
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('vehicles')
          .doc(vehicle.id)
          .update({'documents': FieldValue.arrayRemove([docUrl])});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting document: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (c, s) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            errorWidget: (c, s, e) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image))),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  VehicleDocumentService _getDocumentService() {
    try {
      return context.read<VehicleDocumentService>();
    } catch (_) {
      return VehicleDocumentService();
    }
  }

  void _setupStream() {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId != null) {
      _vehiclesStream = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('vehicles')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList());
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content:
            Text('Delete ${vehicle.registration}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = context.read<AuthProvider>();
        final companyId = authProvider.currentUser?.companyId;

        if (companyId != null) {
          await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('vehicles')
              .doc(vehicle.id)
              .delete();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vehicle deleted successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting vehicle: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateVehicleScreen(),
                ),
              );
              if (result == true && mounted) {
                setState(() {
                  _setupStream();
                });
              }
            },
            tooltip: 'Add Vehicle',
          ),
        ],
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: _vehiclesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final vehicles = snapshot.data ?? [];

          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No vehicles registered',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return _buildVehicleCard(vehicle);
            },
          );
        },
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _buildVehicleLeading(vehicle),
        title: Text(
          vehicle.registration,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vehicle.make != null || vehicle.model != null)
              Text('${vehicle.make ?? ''} ${vehicle.model ?? ''}'.trim()),
            if (vehicle.licensePlate != null)
              Text('Plate: ${vehicle.licensePlate}'),
            Text(
              'Deliveries: ${vehicle.totalDeliveries}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('Edit'),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateVehicleScreen(vehicle: vehicle),
                  ),
                );
                if (result == true && mounted) {
                  setState(() {
                    _setupStream();
                  });
                }
              },
            ),
            PopupMenuItem(
              child: const Text('Delete'),
              onTap: () => _deleteVehicle(vehicle),
            ),
          ],
        ),
        onTap: () {
          // Show vehicle details
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Vehicle Details - ${vehicle.registration}'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Make', vehicle.make),
                    _buildDetailRow('Model', vehicle.model),
                    _buildDetailRow('Color', vehicle.color),
                    _buildDetailRow('License Plate', vehicle.licensePlate),
                    _buildDetailRow(
                      'Status',
                      vehicle.status.toString().split('.').last.toUpperCase(),
                    ),
                    _buildDetailRow(
                      'Total Deliveries',
                      vehicle.totalDeliveries.toString(),
                    ),
                    if (vehicle.lastUsedAt != null)
                      _buildDetailRow(
                        'Last Used',
                        vehicle.lastUsedAt.toString().split('.')[0],
                      ),
                    if (vehicle.notes != null && vehicle.notes!.isNotEmpty)
                      _buildDetailRow('Notes', vehicle.notes),
                    if (vehicle.documents != null && vehicle.documents!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: vehicle.documents!.map((docUrl) {
                                final isImage = _isImageUrl(docUrl);
                                return Stack(
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: isImage
                                          ? Image.network(
                                              docUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) => Center(child: Icon(Icons.broken_image)),
                                            )
                                          : Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  docUrl.split('/').last,
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: InkWell(
                                        onTap: () => _deleteDocument(vehicle, docUrl),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Icon(Icons.delete, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleLeading(Vehicle vehicle) {
    // If vehicle has photos and the first one is an image, show thumbnail
    final docUrl = (vehicle.documents != null && vehicle.documents!.isNotEmpty) ? vehicle.documents!.first : null;
    if (docUrl != null && _isImageUrl(docUrl)) {
      return GestureDetector(
        onTap: () => _showImagePreview(docUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: docUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            placeholder: (c, s) => Container(
              width: 72,
              height: 72,
              color: Colors.grey[200],
              child: const Center(child: SizedBox(width:20,height:20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            errorWidget: (c, s, e) => Container(
              width: 72,
              height: 72,
              color: Colors.grey[100],
              child: const Icon(Icons.broken_image, size: 32),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: vehicle.status == VehicleStatus.active ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(
        Icons.directions_car,
        color: vehicle.status == VehicleStatus.active ? Colors.green : Colors.orange,
        size: 32,
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class CreateVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const CreateVehicleScreen({super.key, this.vehicle});

  @override
  State<CreateVehicleScreen> createState() => _CreateVehicleScreenState();
}

class _CreateVehicleScreenState extends State<CreateVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _registrationController;
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _colorController;
  late TextEditingController _licensePlateController;
  late TextEditingController _notesController;

  String _selectedStatus = 'active';
  bool _isLoading = false;
  List<PlatformFile> _selectedFiles = [];
  // Per-file upload state
  final Map<String, double> _uploadProgress = {}; // key: fileId -> progress 0..1
  final Map<String, String?> _uploadError = {}; // key: fileId -> error message
  final Map<String, String?> _uploadedUrl = {}; // key: fileId -> uploaded url

  @override
  void initState() {
    super.initState();
    _registrationController = TextEditingController(text: widget.vehicle?.registration ?? '');
    _makeController = TextEditingController(text: widget.vehicle?.make ?? '');
    _modelController = TextEditingController(text: widget.vehicle?.model ?? '');
    _colorController = TextEditingController(text: widget.vehicle?.color ?? '');
    _licensePlateController =
        TextEditingController(text: widget.vehicle?.licensePlate ?? '');
    _notesController = TextEditingController(text: widget.vehicle?.notes ?? '');
    _selectedStatus = widget.vehicle?.status.toString().split('.').last ?? 'active';
  }

  // Method for testing to set selected files
  void setSelectedFilesForTesting(List<PlatformFile> files) {
    debugPrint('setSelectedFilesForTesting called with ${files.length} files');
    setState(() {
      _selectedFiles = files;
      // initialize progress entries
      for (final pf in _selectedFiles) {
        final id = '${pf.name}_${pf.size}';
        _uploadProgress[id] = 0.0;
        _uploadError[id] = null;
        _uploadedUrl[id] = null;
      }
    });
  }

  // Method for testing to set uploaded URL
  void setUploadedUrlForTesting(String fileId, String url) {
    debugPrint('setUploadedUrlForTesting called with $fileId $url');
    setState(() {
      _uploadedUrl[fileId] = url;
    });
  }

  VehicleDocumentService _getDocumentService() {
    try {
      return context.read<VehicleDocumentService>();
    } catch (_) {
      return VehicleDocumentService();
    }
  }

  Future<void> _retryUpload(PlatformFile pf, {String? vehicleId}) async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;
    if (companyId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No company ID found')));
      return;
    }

    if (vehicleId == null && widget.vehicle == null) {
      // For new vehicles we need to save/create first to get an id
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save the vehicle before uploading files')));
      return;
    }

    final id = '${pf.name}_${pf.size}';
    setState(() {
      _uploadProgress[id] = 0.0;
      _uploadError[id] = null;
    });

    final docService = _getDocumentService();
    try {
      final vid = vehicleId ?? widget.vehicle!.id;
      final url = await docService.uploadFile(companyId: companyId, vehicleId: vid, file: pf, onProgress: (p) {
        setState(() => _uploadProgress[id] = p);
      });
      setState(() => _uploadedUrl[id] = url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File uploaded')));
    } catch (e) {
      setState(() => _uploadError[id] = e.toString());
    }
  }

  Future<void> _pickFiles() async {
    try {
      // Allow only image types and limit client-side to max 2 images
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      );
      if (result != null && result.files.isNotEmpty) {
        // Filter to image files just in case
        final images = result.files.where((pf) {
          final name = pf.name.toLowerCase();
          return name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.webp') || name.endsWith('.gif');
        }).toList();

        var toUse = images;
        if (images.length > 2) {
          toUse = images.sublist(0, 2);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only the first 2 images were selected (max 2).')));
        }

        setState(() {
          _selectedFiles = toUse;
          // initialize progress entries
          for (final pf in _selectedFiles) {
            final id = '${pf.name}_${pf.size}';
            _uploadProgress[id] = 0.0;
            _uploadError[id] = null;
            _uploadedUrl[id] = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null) {
        throw Exception('No company ID found');
      }

      final vehicleData = {
        'companyId': companyId,
        'registration': _registrationController.text.trim(),
        'make': _makeController.text.trim().isEmpty
            ? null
            : _makeController.text.trim(),
        'model': _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        'color': _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        'licensePlate': _licensePlateController.text.trim().isEmpty
            ? null
            : _licensePlateController.text.trim(),
        'status': _selectedStatus,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      if (widget.vehicle == null) {
        // Create new vehicle
        final createData = {
          ...vehicleData,
          'totalDeliveries': 0,
          'createdAt': FieldValue.serverTimestamp(),
        };
        final docRef = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('vehicles')
            .add(createData);

        // Upload selected photos (max 2) and update vehicle with document URLs
        if (_selectedFiles.isNotEmpty) {
          final List<String> uploadedUrls = [];
          final docService = _getDocumentService();
          final filesToUpload = _selectedFiles.take(2).toList();
          for (final pf in filesToUpload) {
            final id = '${pf.name}_${pf.size}';
            try {
              final url = await docService.uploadFile(
                companyId: companyId,
                vehicleId: docRef.id,
                file: pf,
                onProgress: (p) {
                  setState(() {
                    _uploadProgress[id] = p;
                  });
                },
              );
              uploadedUrls.add(url);
              setState(() {
                _uploadedUrl[id] = url;
              });
            } catch (e) {
              setState(() {
                _uploadError[id] = e.toString();
              });
              // continue with next file
            }
          }

          if (uploadedUrls.isNotEmpty) {
            await docRef.update({'documents': uploadedUrls});
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle created successfully')),
          );
          _selectedFiles.clear();
          setState(() {});
          Navigator.pop(context, true);
        }
      } else {
        // Update existing vehicle
        final updateData = {
          ...vehicleData,
          'lastUsedAt': widget.vehicle!.lastUsedAt != null
              ? Timestamp.fromDate(widget.vehicle!.lastUsedAt!)
              : null,
        };
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('vehicles')
            .doc(widget.vehicle!.id)
            .update(updateData);

        // If there are new selected photos, upload and append to existing documents
        if (_selectedFiles.isNotEmpty) {
          final existing = widget.vehicle?.documents ?? [];
          final List<String> uploadedUrls = [];
          final docService = _getDocumentService();
          final filesToUpload = _selectedFiles.take(2 - existing.length).toList();
          for (final pf in filesToUpload) {
            final id = '${pf.name}_${pf.size}';
            try {
              final url = await docService.uploadFile(
                companyId: companyId,
                vehicleId: widget.vehicle!.id,
                file: pf,
                onProgress: (p) {
                  setState(() {
                    _uploadProgress[id] = p;
                  });
                },
              );
              uploadedUrls.add(url);
              setState(() {
                _uploadedUrl[id] = url;
              });
            } catch (e) {
              setState(() {
                _uploadError[id] = e.toString();
              });
            }
          }

          if (uploadedUrls.isNotEmpty) {
            final merged = [...existing, ...uploadedUrls];
            await FirebaseFirestore.instance
                .collection('companies')
                .doc(companyId)
                .collection('vehicles')
                .doc(widget.vehicle!.id)
                .update({'documents': merged});
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle updated successfully')),
          );
          _selectedFiles.clear();
          setState(() {});
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vehicle: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _registrationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _licensePlateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _registrationController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Registration',
                      prefixIcon: Icon(Icons.directions_car),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vehicle registration is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _makeController,
                    decoration: const InputDecoration(
                      labelText: 'Make (Optional)',
                      hintText: 'e.g., Toyota',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model (Optional)',
                      hintText: 'e.g., Hilux',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Color (Optional)',
                      hintText: 'e.g., White',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licensePlateController,
                    decoration: const InputDecoration(
                      labelText: 'License Plate (Optional)',
                      hintText: 'e.g., ABC-1234',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['active', 'inactive', 'maintenance'].map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Any additional information',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Photos picker (limit to 2 images)
                  Text(
                    'Vehicle Photos (Optional, max 2${widget.vehicle != null ? ' - Currently has ${widget.vehicle!.documents?.length ?? 0}' : ''})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: (widget.vehicle != null && (widget.vehicle!.documents?.length ?? 0) >= 2) ? null : _pickFiles,
                        icon: const Icon(Icons.photo),
                        label: Text(widget.vehicle != null && (widget.vehicle!.documents?.length ?? 0) >= 2 ? 'Max Photos Reached' : 'Add Photos'),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedFiles.isNotEmpty)
                        Text('${_selectedFiles.length}/2 selected')
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedFiles.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _selectedFiles.map((pf) {
                              final isImage = pf.name.toLowerCase().endsWith('.png') || pf.name.toLowerCase().endsWith('.jpg') || pf.name.toLowerCase().endsWith('.jpeg') || pf.name.toLowerCase().endsWith('.webp') || pf.name.toLowerCase().endsWith('.gif');
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: isImage
                                            ? (pf.bytes != null
                                                ? Image.memory(pf.bytes!, fit: BoxFit.cover)
                                                : (pf.path != null ? Image.file(File(pf.path!), fit: BoxFit.cover) : const SizedBox.shrink()))
                                            : Center(child: Text(pf.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedFiles.remove(pf);
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // list view of names and per-file status
                        Column(
                          children: _selectedFiles.map((pf) {
                            final id = '${pf.name}_${pf.size}';
                            final prog = _uploadProgress[id] ?? 0.0;
                            final err = _uploadError[id];
                            final url = _uploadedUrl[id];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(pf.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${pf.size} bytes'),
                                  const SizedBox(height: 6),
                                  if (err != null)
                                    Row(
                                      children: [
                                        Expanded(child: Text('Error: $err', style: TextStyle(color: AppTheme.errorColor))),
                                        TextButton(
                                          onPressed: () => _retryUpload(pf, vehicleId: widget.vehicle?.id),
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  if (err == null && prog > 0 && prog < 1)
                                    LinearProgressIndicator(value: prog),
                                  if (url != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.remove(pf);
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveVehicle,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            widget.vehicle == null ? 'Create Vehicle' : 'Update Vehicle',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
