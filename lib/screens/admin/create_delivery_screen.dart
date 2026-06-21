import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../../utils/theme.dart';
import '../../models/delivery_model.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/customer_autocomplete.dart';
import '../../services/notification_service.dart';
import '../../services/external_upload_service.dart';
import '../../utils/vehicle_utils.dart';
import '../../services/csv_export_service.dart';
import 'bulk_upload_screen.dart';

class CreateDeliveryScreen extends StatefulWidget {
  final Delivery? delivery; // For editing existing delivery

  const CreateDeliveryScreen({super.key, this.delivery});

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _orderNumberController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _scheduledDate = DateTime.now();
  DateTime? _invoiceDate;
  String? _selectedDriverId;
  String? _selectedVehicle;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, String>> _availableVehicles = [];
  List<DeliveryItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingDrivers = true;
  bool _isLoadingVehicles = true;
  StreamSubscription<QuerySnapshot>? _vehicleSubscription;
  
  // Customer selection
  Customer? _selectedCustomer;
  String? _selectedCustomerId;
  String? _selectedCustomerNumber;
  
  // Third-party transport
  bool _isThirdPartyTransport = false;
  final _thirdPartyProviderController = TextEditingController();
  final _thirdPartyDriverController = TextEditingController();
  final _thirdPartyPhoneController = TextEditingController();
  final _thirdPartyVehicleController = TextEditingController();

  // Wizard state
  int _currentStep = 0;

  // Table mode state
  bool _isTableMode = false; // Single-entry wizard is default
  final List<Map<String, dynamic>> _tableDeliveries = [];

  // Rapid Entry state
  bool _isRapidEntry = false;
  bool _isCreatingRapidBatch = false;
  final List<Map<String, dynamic>> _rapidQueue = [];
  DateTime _rapidDate = DateTime.now();
  Customer? _rapidSelectedCustomer;
  List<Map<String, dynamic>> _rapidCurrentItems = [{'description': '', 'quantity': 1}];
  final _rapidCustomerNameController = TextEditingController();
  final _rapidCustomerAddressController = TextEditingController();
  final _rapidInvoiceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Defer driver loading until after frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDrivers();
    });
    _initializeCustomerProvider();
    
    // If editing, populate fields
    if (widget.delivery != null) {
      _customerNameController.text = widget.delivery!.customerName;
      _customerAddressController.text = widget.delivery!.customerAddress;
      _customerPhoneController.text = widget.delivery!.customerPhone ?? '';
      _orderNumberController.text = widget.delivery!.orderNumber ?? '';
      _invoiceNumberController.text = widget.delivery!.invoiceNumber;
      _notesController.text = widget.delivery!.notes ?? '';
      _scheduledDate = widget.delivery!.scheduledDate;
      _invoiceDate = widget.delivery!.invoiceDate;
      _selectedDriverId = widget.delivery!.driverId;
      _selectedVehicle = widget.delivery!.vehicleUsed;
      _selectedCustomerNumber = widget.delivery!.customerNumber;
      _items = List.from(widget.delivery!.items);
      
      // Load vehicles for the existing driver using a live subscription
      if (_selectedDriverId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _subscribeToVehiclesForDriver(_selectedDriverId!);
        });
      }
      
      // Load customer if available (will be implemented in delivery model update)
      // For now, keep manual entry for backwards compatibility
    }

    // Initialize table mode data
    // TODO: Implement table mode initialization
  }

  Future<void> _initializeCustomerProvider() async {
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final authProvider = context.read<AuthProvider>();
        final companyId = authProvider.currentUser?.companyId;
        
        if (companyId != null && companyId.isNotEmpty) {
          final customerProvider = context.read<CustomerProvider>();
          if (customerProvider.customers.isEmpty) {
            await customerProvider.initialize(companyId);
          }
          
          // Initialize catalog provider
          final catalogProvider = context.read<CatalogProvider>();
          if (!catalogProvider.hasItems) {
            await catalogProvider.initialize(companyId);
          }
        }
      } catch (e) {
        debugPrint('Error initializing providers: $e');
      }
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerPhoneController.dispose();
    _orderNumberController.dispose();
    _invoiceNumberController.dispose();
    _notesController.dispose();
    _rapidCustomerNameController.dispose();
    _rapidCustomerAddressController.dispose();
    _rapidInvoiceController.dispose();
    _vehicleSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null || companyId.isEmpty) {
        debugPrint('âŒ Company ID is null or empty');
        return;
      }

      debugPrint('ðŸš— Loading drivers for company: $companyId');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('companyId', isEqualTo: companyId)
          .get();

      debugPrint('ðŸ“‹ Found ${snapshot.docs.length} total driver records');

      setState(() {
        _drivers = snapshot.docs
            .where((doc) {
              try {
                final data = doc.data();
                final approvalStatus = data['approvalStatus'] as String?;
                final passes = approvalStatus == 'approved' || 
                       approvalStatus == 'pending' || 
                       approvalStatus == null;
                if (!passes) {
                  debugPrint('  âŒ Filtering out driver (${data['displayName']}) with status: $approvalStatus');
                }
                return passes;
              } catch (e) {
                debugPrint('  âš ï¸ Error checking approval status for driver: $e');
                return true; // Include drivers with missing fields
              }
            })
            .map((doc) {
              try {
                final data = doc.data();
                debugPrint('  âœ… Added driver: ${data['displayName']}');
                return {
                  'id': doc.id,
                  'name': data['displayName'] ?? 'Unknown Driver',
                  'vehicleInfo': data['vehicleInfo'] ?? 'No vehicle info',
                };
              } catch (e) {
                debugPrint('  âš ï¸ Error mapping driver data: $e');
                return {
                  'id': doc.id,
                  'name': 'Unknown Driver',
                  'vehicleInfo': 'No vehicle info',
                };
              }
            })
            .toList();
        _isLoadingDrivers = false;
        debugPrint('âœ… Driver loading complete. Total selectable drivers: ${_drivers.length}');
      });
    } catch (e) {
      debugPrint('âŒ Error loading drivers: $e');
      setState(() => _isLoadingDrivers = false);
    }
  }

  Future<void> _loadVehiclesForDriver(String driverId) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null) {
        debugPrint('âŒ No company ID found');
        return;
      }

      // Get all active vehicles for the company
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('vehicles')
          .where('status', isEqualTo: 'active')
          .get();

      final vehicles = <Map<String, String>>[];
      for (var doc in snapshot.docs) {
        final registration = doc['registration'] as String?;
        final make = doc['make'] as String?;
        final model = doc['model'] as String?;
        if (registration != null && registration.isNotEmpty) {
          vehicles.add({'id': doc.id, 'registration': normalizeRegistration(registration), 'make': make ?? '', 'model': model ?? ''});
        }
      }

      debugPrint('âœ… Found ${vehicles.length} active vehicles for company $companyId');

      setState(() {
        _availableVehicles = vehicles;
        // Auto-select first vehicle if available
        _selectedVehicle = vehicles.isNotEmpty ? vehicles.first['registration'] : null;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      debugPrint('âŒ Error loading vehicles: $e');
      setState(() => _isLoadingVehicles = false);
    }
  }

  /// Subscribe to vehicles for the company and update available vehicles live
  void _subscribeToVehiclesForDriver(String driverId) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      if (companyId == null) {
        debugPrint('âŒ No company ID found for subscription');
        return;
      }

      // Cancel existing subscription
      await _vehicleSubscription?.cancel();
      // Load a one-time snapshot immediately to reduce perceived latency
      await _loadVehiclesForDriver(driverId);
      setState(() {
        _isLoadingVehicles = true;
      });

      _vehicleSubscription = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('vehicles')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen((snapshot) {
        final vehicles = <Map<String, String>>[];
        for (var doc in snapshot.docs) {
          final registration = doc.data()['registration'] as String?;
          final make = doc.data()['make'] as String?;
          final model = doc.data()['model'] as String?;
          if (registration != null && registration.isNotEmpty) vehicles.add({'id': doc.id, 'registration': normalizeRegistration(registration), 'make': make ?? '', 'model': model ?? ''});
        }

        debugPrint('ðŸ”” Vehicle snapshot updated: ${vehicles.length} vehicles');

        setState(() {
          _availableVehicles = vehicles;
          // Preserve existing selected vehicle if still present; otherwise choose the first available
          if (_selectedVehicle == null || !_availableVehicles.any((v) => v['registration'] == _selectedVehicle)) {
            _selectedVehicle = vehicles.isNotEmpty ? vehicles.first['registration'] : null;
          }
          _isLoadingVehicles = false;
        });
      }, onError: (e) {
        debugPrint('âŒ Error in vehicle subscription: $e');
        setState(() => _isLoadingVehicles = false);
      });
    } catch (e) {
      debugPrint('âŒ Error subscribing to vehicles: $e');
      setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate based on transport type
    if (!_isThirdPartyTransport && _selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a driver'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null || companyId.isEmpty) {
        throw Exception('No company ID found. Please log in again.');
      }

      final deliveryData = {
        'companyId': companyId,
        'driverId': _isThirdPartyTransport ? 'third-party' : _selectedDriverId!,
        'customerName': _customerNameController.text.trim(),
        'customerAddress': _customerAddressController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim().isEmpty
            ? null
            : _customerPhoneController.text.trim(),
        // Customer linking (optional for backwards compatibility)
        'customerId': _selectedCustomerId,
        'customerNumber': _selectedCustomerNumber,
        'orderNumber': _orderNumberController.text.trim().isEmpty
            ? null
            : _orderNumberController.text.trim(),
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'invoiceDate': _invoiceDate != null 
            ? Timestamp.fromDate(_invoiceDate!) 
            : null,
        'items': _items.map((item) => item.toMap()).toList(),
        'vehicleUsed': _isThirdPartyTransport ? null : (_selectedVehicle == null ? null : normalizeRegistration(_selectedVehicle!)),
        'isThirdPartyTransport': _isThirdPartyTransport,
        'thirdPartyProviderName': _isThirdPartyTransport 
            ? _thirdPartyProviderController.text.trim() 
            : null,
        'thirdPartyDriverName': _isThirdPartyTransport 
            ? _thirdPartyDriverController.text.trim().isEmpty 
                ? null 
                : _thirdPartyDriverController.text.trim()
            : null,
        'thirdPartyDriverPhone': _isThirdPartyTransport 
            ? _thirdPartyPhoneController.text.trim().isEmpty 
                ? null 
                : _thirdPartyPhoneController.text.trim()
            : null,
        'thirdPartyVehicleInfo': _isThirdPartyTransport 
            ? _thirdPartyVehicleController.text.trim().isEmpty 
                ? null 
                : _thirdPartyVehicleController.text.trim()
            : null,
        'status': DeliveryStatus.pending.toString().split('.').last,
        'scheduledDate': Timestamp.fromDate(_scheduledDate),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      DocumentReference? deliveryRef;
      String? uploadToken;
      
      if (widget.delivery == null) {
        // Create new delivery
        deliveryData['createdAt'] = FieldValue.serverTimestamp();
        deliveryRef = await FirebaseFirestore.instance.collection('deliveries').add(deliveryData);
        
        // Generate upload token for third-party deliveries
        if (_isThirdPartyTransport) {
          final ExternalUploadService uploadService = ExternalUploadService();
          final tokenData = await uploadService.createUploadToken(
            deliveryId: deliveryRef.id,
            companyId: companyId,
            providerName: _thirdPartyProviderController.text.trim(),
            providerContact: _thirdPartyPhoneController.text.trim().isEmpty 
                ? null 
                : _thirdPartyPhoneController.text.trim(),
            expiryDays: 14, // Token expires in 14 days
          );
          uploadToken = tokenData.id;
        }
        
        // ðŸ”” Send notification to own driver (if not third-party)
        if (!_isThirdPartyTransport && _selectedDriverId != null) {
          final formattedDate = DateFormat('MMM dd, yyyy').format(_scheduledDate);
          final itemCount = _items.length;
          
          await NotificationService().sendToUser(
            userId: _selectedDriverId!,
            title: 'ðŸšš New Delivery Assignment',
            body: 'Delivery to ${_customerNameController.text.trim()} scheduled for $formattedDate',
            data: {
              'type': 'delivery_assigned',
              'deliveryId': deliveryRef.id,
              'customerName': _customerNameController.text.trim(),
              'customerAddress': _customerAddressController.text.trim(),
              'itemCount': itemCount.toString(),
              'scheduledDate': _scheduledDate.toIso8601String(),
              'priority': 'high',
            },
          );
        }
      } else {
        // Update existing delivery
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(widget.delivery!.id)
            .update(deliveryData);
      }

      if (mounted) {
        // Show upload link dialog for third-party deliveries
        if (_isThirdPartyTransport && uploadToken != null && widget.delivery == null) {
          _showUploadLinkDialog(uploadToken);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.delivery == null
                    ? 'Delivery created successfully!'
                    : 'Delivery updated successfully!',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  void _showUploadLinkDialog(String token) {
    final ExternalUploadService uploadService = ExternalUploadService();
    final uploadLink = uploadService.generateUploadLink(token);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.link, color: AppTheme.successColor),
            SizedBox(width: 8),
            Text('Upload Link Generated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery created successfully! Share this link with the transport provider to upload POD documents:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                uploadLink,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Provider: ${_thirdPartyProviderController.text.trim()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Valid for: 14 days',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              // Copy to clipboard
              // TODO: Add clipboard functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Close delivery screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showDeliveryInstructions(String instructions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: AppTheme.infoColor),
            SizedBox(width: 8),
            Text('Delivery Instructions'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Special instructions for this customer:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.infoColor.withValues(alpha: 77)),
              ),
              child: Text(
                instructions,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    _showItemDialog(null, null);
  }

  void _editItem(int index) {
    _showItemDialog(_items[index], index);
  }

  void _showItemDialog(DeliveryItem? existingItem, int? editIndex) {
    final descriptionController = TextEditingController(text: existingItem?.description ?? '');
    final quantityController = TextEditingController(
      text: existingItem != null ? existingItem.quantity.toString() : '1',
    );
    final unitController = TextEditingController(text: existingItem?.unit ?? '');
    final unitPriceController = TextEditingController(
      text: existingItem?.unitPrice != null ? existingItem!.unitPrice!.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingItem == null ? 'Add Item' : 'Edit Item'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descriptionController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'Product or item description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'e.g., box, kg',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: unitPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price (Optional)',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    prefixText: 'R ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final description = descriptionController.text.trim();
              final quantity = double.tryParse(quantityController.text.trim()) ?? 1;
              final unit = unitController.text.trim().isEmpty ? null : unitController.text.trim();
              final unitPrice = unitPriceController.text.trim().isEmpty
                  ? null
                  : double.tryParse(unitPriceController.text.trim());

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter item description')),
                );
                return;
              }

              final item = DeliveryItem(
                description: description,
                quantity: quantity,
                unit: unit,
                unitPrice: unitPrice,
                totalPrice: unitPrice != null ? quantity * unitPrice : null,
              );

              setState(() {
                if (editIndex != null) {
                  _items[editIndex] = item;
                } else {
                  _items.add(item);
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(existingItem == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_customerNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a customer name'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      if (_customerAddressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a delivery address'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one item'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }


  void _downloadTemplate() async {
    try {
      // Load ABASERVE-specific template
      final csvContent = await rootBundle.loadString('assets/abaserve_import_template.csv');
      
      // Parse CSV content into headers and rows using proper CSV parser
      final csvData = const CsvToListConverter().convert(csvContent);
      if (csvData.isEmpty) {
        throw Exception('Template file is empty');
      }

      final headers = csvData[0].map((e) => e.toString()).toList();
      final rows = csvData.skip(1).map((row) => row.map((e) => e.toString()).toList()).toList();

      // Download the CSV file
      await CSVExportService.exportToCSV(
        filename: 'abaserve_import_template',
        headers: headers,
        rows: rows,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('âœ“ ABASERVE template downloaded successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToBulkUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BulkUploadScreen(),
      ),
    );
  }  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.delivery == null ? 'Create Delivery' : 'Edit Delivery'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'template') {
                _downloadTemplate();
              } else if (value == 'bulk_upload') {
                _navigateToBulkUpload();
              } else if (value == 'table_mode') {
                setState(() {
                  _isTableMode = !_isTableMode;
                  _isRapidEntry = false;
                });
              } else if (value == 'rapid_entry') {
                setState(() {
                  _isRapidEntry = !_isRapidEntry;
                  _isTableMode = false;
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rapid_entry',
                child: Row(
                  children: [
                    Icon(_isRapidEntry ? Icons.list : Icons.bolt, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text(_isRapidEntry ? 'Switch to Single Entry' : 'Rapid Entry Mode',
                        style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'table_mode',
                child: Row(
                  children: [
                    Icon(_isTableMode ? Icons.list : Icons.table_chart, size: 20),
                    const SizedBox(width: 8),
                    Text(_isTableMode ? 'Switch to Single Entry' : 'Bulk Table Entry'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'bulk_upload',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Bulk Import CSV'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'template',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 8),
                    Text('Download CSV Template'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoadingDrivers
          ? const Center(child: CircularProgressIndicator())
          : _isRapidEntry
              ? _buildRapidEntry()
              : _isTableMode
                  ? _buildTableMode()
                  : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildStepIndicator(),
                      Expanded(
                        child: IndexedStack(
                          index: _currentStep,
                          children: [
                            _buildStep1(),
                            _buildStep2(),
                            _buildStep3(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // â”€â”€ Step indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      child: Row(
        children: [
          _buildStepChip(0, 'Customer'),
          Expanded(
            child: Divider(
              color: _currentStep > 0 ? AppTheme.primaryColor : Colors.grey[300],
              thickness: 2,
              indent: 8,
              endIndent: 8,
            ),
          ),
          _buildStepChip(1, 'Items'),
          Expanded(
            child: Divider(
              color: _currentStep > 1 ? AppTheme.primaryColor : Colors.grey[300],
              thickness: 2,
              indent: 8,
              endIndent: 8,
            ),
          ),
          _buildStepChip(2, 'Schedule'),
        ],
      ),
    );
  }

  Widget _buildStepChip(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    final color = isCompleted
        ? AppTheme.successColor
        : (isActive ? AppTheme.primaryColor : Colors.grey[400]!);

    return GestureDetector(
      onTap: () {
        // Tap on a completed step to go back to it
        if (step < _currentStep) setState(() => _currentStep = step);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Step 1: Customer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        const Text('Who are we delivering to?', style: AppTextStyles.heading3),
        const SizedBox(height: 16),
        CustomerAutocomplete(
          initialCustomer: _selectedCustomer,
          onCustomerSelected: (customer) {
            setState(() {
              _selectedCustomer = customer;
              if (customer != null) {
                _customerNameController.text = customer.name;
                _customerAddressController.text = customer.address;
                _customerPhoneController.text = customer.phone ?? '';
                _selectedCustomerId = customer.id;
                _selectedCustomerNumber = customer.customerNumber;
                if (customer.deliveryInstructions != null &&
                    customer.deliveryInstructions!.isNotEmpty) {
                  _showDeliveryInstructions(customer.deliveryInstructions!);
                }
              } else {
                _selectedCustomerId = null;
              }
            });
          },
          labelText: 'Search Customer',
          hintText: 'Search by name or customer number...',
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _customerNameController,
          decoration: InputDecoration(
            labelText: 'Customer Name *',
            prefixIcon: const Icon(Icons.person),
            border: const OutlineInputBorder(),
            helperText: _selectedCustomer != null
                ? 'From: ${_selectedCustomer!.customerNumber}'
                : 'Or type a name manually',
            helperStyle: TextStyle(
              color: _selectedCustomer != null
                  ? AppTheme.successColor
                  : AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _customerAddressController,
          decoration: const InputDecoration(
            labelText: 'Delivery Address *',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Delivery address is required' : null,
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: const Text(
            'Contact Details (Optional)',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          tilePadding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _customerPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next: Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // â”€â”€ Step 2: Items â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStep2() {
    return Column(
      children: [
        if (_customerNameController.text.isNotEmpty)
          Container(
            width: double.infinity,
            color: AppTheme.primaryColor.withValues(alpha: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Delivering to: ${_customerNameController.text}',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('What are we delivering?', style: AppTextStyles.heading3),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_items.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'No items added yet',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "Add Item" to add products to this delivery',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final qtyDisplay = item.quantity % 1 == 0
                      ? item.quantity.toInt().toString()
                      : item.quantity.toStringAsFixed(2);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 26),
                        child: Text(
                          qtyDisplay,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(item.description),
                      subtitle: (item.unit != null || item.unitPrice != null)
                          ? Text([
                              if (item.unit != null) item.unit!,
                              if (item.unitPrice != null)
                                'R${item.unitPrice!.toStringAsFixed(2)} each',
                            ].join(' Â· '))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editItem(index),
                            tooltip: 'Edit item',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: AppTheme.errorColor),
                            onPressed: () => _deleteItem(index),
                            tooltip: 'Remove item',
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.paddingMedium, 8, AppTheme.paddingMedium, AppTheme.paddingMedium),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              const Spacer(),
              if (_items.isNotEmpty)
                Text(
                  '${_items.length} item${_items.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next: Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // â”€â”€ Step 3: Schedule & Transport â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStep3() {
    return Column(
      children: [
        if (_customerNameController.text.isNotEmpty)
          Container(
            width: double.infinity,
            color: AppTheme.primaryColor.withValues(alpha: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${_customerNameController.text}  Â·  ${_items.length} item${_items.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            children: [
              const Text('When & How?', style: AppTextStyles.heading3),
              const SizedBox(height: 16),

              // Invoice Number
              TextFormField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(
                  labelText: 'Invoice Number *',
                  prefixIcon: Icon(Icons.receipt),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Invoice number is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Scheduled Date
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 1)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _scheduledDate = date);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Scheduled Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('EEEE, MMMM d, y').format(_scheduledDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Transport Method
              const Text(
                'Transport Method',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('Own Fleet'),
                      subtitle: const Text(
                          'Assign to your driver and vehicle'),
                      value: false,
                      groupValue: _isThirdPartyTransport,
                      onChanged: (v) => setState(() {
                        _isThirdPartyTransport = v!;
                        if (_isThirdPartyTransport) {
                          _selectedDriverId = null;
                          _selectedVehicle = null;
                        }
                      }),
                    ),
                    RadioListTile<bool>(
                      title: const Text('Third-Party Transport'),
                      subtitle:
                          const Text('External transport company'),
                      value: true,
                      groupValue: _isThirdPartyTransport,
                      onChanged: (v) => setState(() {
                        _isThirdPartyTransport = v!;
                        if (_isThirdPartyTransport) {
                          _selectedDriverId = null;
                          _selectedVehicle = null;
                        }
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Own Fleet section
              if (!_isThirdPartyTransport) ...[
                DropdownButtonFormField<String>(
                  value: _drivers.any((d) => d['id'] == _selectedDriverId)
                      ? _selectedDriverId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Assign Driver *',
                    prefixIcon: Icon(Icons.local_shipping),
                    border: OutlineInputBorder(),
                  ),
                  items: _drivers
                      .map((driver) => DropdownMenuItem<String>(
                            value: driver['id'] as String,
                            child: Text(driver['name'] as String),
                          ))
                      .toList(),
                  onChanged: (value) async {
                    setState(() {
                      _selectedDriverId = value;
                      _selectedVehicle = null;
                    });
                    if (value != null) {
                      await _vehicleSubscription?.cancel();
                      _subscribeToVehiclesForDriver(value);
                    } else {
                      await _vehicleSubscription?.cancel();
                      setState(() => _availableVehicles = []);
                    }
                  },
                  validator: (v) =>
                      !_isThirdPartyTransport && v == null
                          ? 'Please select a driver'
                          : null,
                ),
                const SizedBox(height: 12),
                if (_selectedDriverId != null)
                  _isLoadingVehicles
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Loading vehicles...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : _availableVehicles.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No active vehicles available',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _availableVehicles.any((v) =>
                                            v['registration'] ==
                                            _selectedVehicle)
                                        ? _selectedVehicle
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Vehicle',
                                      prefixIcon: Icon(Icons.directions_car),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _availableVehicles
                                        .map((vehicle) {
                                      final reg =
                                          vehicle['registration'] ?? '';
                                      final make =
                                          (vehicle['make'] ?? '').trim();
                                      final model =
                                          (vehicle['model'] ?? '').trim();
                                      final details = (make.isEmpty &&
                                              model.isEmpty)
                                          ? ''
                                          : ' Â· ${[make, model].where((s) => s.isNotEmpty).join(' ')}';
                                      return DropdownMenuItem<String>(
                                        value: reg,
                                        child: Text('$reg$details'),
                                      );
                                    }).toList(),
                                    onChanged: (v) =>
                                        setState(() => _selectedVehicle = v),
                                    validator: (v) =>
                                        _selectedDriverId != null && v == null
                                            ? 'Please select a vehicle'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  tooltip: 'Refresh vehicles',
                                  onPressed: () async {
                                    if (_selectedDriverId != null) {
                                      await _vehicleSubscription?.cancel();
                                      _subscribeToVehiclesForDriver(
                                          _selectedDriverId!);
                                    }
                                  },
                                ),
                              ],
                            ),
              ],

              // Third-Party section
              if (_isThirdPartyTransport) ...[
                Card(
                  elevation: 2,
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_shipping,
                                color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Third-Party Transport Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _thirdPartyProviderController,
                          decoration: const InputDecoration(
                            labelText: 'Provider Name *',
                            hintText: 'e.g., HFR Transport',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) =>
                              _isThirdPartyTransport &&
                                      (v == null || v.isEmpty)
                                  ? 'Provider name is required'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _thirdPartyDriverController,
                          decoration: const InputDecoration(
                            labelText: 'Driver Name (Optional)',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _thirdPartyPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Driver Phone (Optional)',
                            hintText: '+27 123 456 789',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _thirdPartyVehicleController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Info (Optional)',
                            hintText: 'Registration or description',
                            prefixIcon: Icon(Icons.directions_car),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue[700], size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'An upload link will be generated for this provider to submit POD documents.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Additional details (collapsed)
              ExpansionTile(
                title: const Text(
                  'Additional Details (Optional)',
                  style: TextStyle(
                      fontSize: 14, color: AppTheme.textSecondary),
                ),
                tilePadding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _orderNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Order Number',
                      prefixIcon: Icon(Icons.shopping_cart),
                      border: OutlineInputBorder(),
                      helperText: 'Customer order or PO number',
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate ?? DateTime.now(),
                        firstDate:
                            DateTime(DateTime.now().year - 5),
                        lastDate: DateTime.now(),
                      );
                      if (date != null)
                        setState(() => _invoiceDate = date);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Invoice Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: const OutlineInputBorder(),
                        suffixIcon: _invoiceDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _invoiceDate = null),
                              )
                            : null,
                      ),
                      child: Text(
                        _invoiceDate != null
                            ? DateFormat('EEEE, MMMM d, y')
                                .format(_invoiceDate!)
                            : 'Select invoice date',
                        style: TextStyle(
                          color: _invoiceDate != null
                              ? Colors.black
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 24),

              // Create / Update button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveDelivery,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      )
                    : Text(
                        widget.delivery == null
                            ? 'Create Delivery'
                            : 'Update Delivery',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.paddingMedium, 8, AppTheme.paddingMedium, AppTheme.paddingMedium),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Rapid Entry Mode ─────────────────────────────────────────────────────

  Widget _buildRapidEntry() {
    return Column(
      children: [
        _buildRapidHeader(),
        Expanded(
          child: _rapidQueue.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No deliveries queued yet',
                          style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Fill in the form below and tap Queue Delivery',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : _buildRapidQueue(),
        ),
        _buildRapidAddPanel(),
      ],
    );
  }

  Widget _buildRapidHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.orange[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: Colors.orange[700], size: 18),
              const SizedBox(width: 6),
              Text('Rapid Entry — set once, apply to all',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                      fontSize: 13)),
              const Spacer(),
              if (_rapidQueue.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _isCreatingRapidBatch ? null : _createRapidBatch,
                  icon: _isCreatingRapidBatch
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload, size: 18),
                  label: Text('Create All (${_rapidQueue.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _drivers.any((d) => d['id'] == _selectedDriverId)
                      ? _selectedDriverId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Driver',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _drivers
                      .map((d) => DropdownMenuItem<String>(
                            value: d['id'] as String,
                            child: Text(d['name'] as String),
                          ))
                      .toList(),
                  onChanged: (value) async {
                    setState(() {
                      _selectedDriverId = value;
                      _selectedVehicle = null;
                    });
                    if (value != null) {
                      await _vehicleSubscription?.cancel();
                      _subscribeToVehiclesForDriver(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _rapidDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _rapidDate = date);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Scheduled Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(_rapidDate)),
                  ),
                ),
              ),
              if (_selectedDriverId != null && _availableVehicles.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _availableVehicles.any((v) => v['registration'] == _selectedVehicle)
                        ? _selectedVehicle
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle',
                      prefixIcon: Icon(Icons.directions_car),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _availableVehicles.map((v) {
                      final reg = v['registration'] ?? '';
                      final make = (v['make'] ?? '').trim();
                      final model = (v['model'] ?? '').trim();
                      final label = [reg, if (make.isNotEmpty || model.isNotEmpty) '$make $model'.trim()]
                          .join(' • ');
                      return DropdownMenuItem<String>(
                        value: reg,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedVehicle = value),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRapidQueue() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _rapidQueue.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final entry = _rapidQueue[i];
        final items = entry['items'] as List<Map<String, dynamic>>;
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryColor,
            child: Text('${i + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          title: Text(entry['customerName'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${entry['invoiceNumber']}  •  ${items.length} item${items.length == 1 ? '' : 's'}'),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.red[400],
            tooltip: 'Remove',
            onPressed: () => _removeFromRapidQueue(i),
          ),
        );
      },
    );
  }

  Widget _buildRapidAddPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Delivery',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 13)),
          const SizedBox(height: 10),
          // Customer + Invoice row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: CustomerAutocomplete(
                  initialCustomer: _rapidSelectedCustomer,
                  onCustomerSelected: (customer) {
                    setState(() {
                      _rapidSelectedCustomer = customer;
                      if (customer != null) {
                        _rapidCustomerNameController.text = customer.name;
                        _rapidCustomerAddressController.text = customer.address;
                      }
                    });
                  },
                  labelText: 'Customer',
                  hintText: 'Search or type name...',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _rapidInvoiceController,
                  decoration: const InputDecoration(
                    labelText: 'Invoice #',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Customer name + address (editable override)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rapidCustomerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rapidCustomerAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Address',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Items
          ...List.generate(_rapidCurrentItems.length, (idx) {
            final item = _rapidCurrentItems[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      initialValue: item['description'] as String,
                      decoration: InputDecoration(
                        labelText: 'Item ${idx + 1} description',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => _rapidCurrentItems[idx]['description'] = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      initialValue: item['quantity'].toString(),
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _rapidCurrentItems[idx]['quantity'] = double.tryParse(v) ?? 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: Colors.red[400],
                    tooltip: 'Remove item',
                    onPressed: _rapidCurrentItems.length > 1
                        ? () => setState(() => _rapidCurrentItems.removeAt(idx))
                        : null,
                  ),
                ],
              ),
            );
          }),
          // Actions row
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(
                    () => _rapidCurrentItems.add({'description': '', 'quantity': 1.0})),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addToRapidQueue,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Queue Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addToRapidQueue() {
    final name = _rapidCustomerNameController.text.trim();
    final address = _rapidCustomerAddressController.text.trim();
    final invoice = _rapidInvoiceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a customer name'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (invoice.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter an invoice number'),
            backgroundColor: Colors.red),
      );
      return;
    }
    final validItems = _rapidCurrentItems
        .where((item) => (item['description'] as String).trim().isNotEmpty)
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one item description'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _rapidQueue.add({
        'customerName': name,
        'customerAddress': address,
        'customerId': _rapidSelectedCustomer?.id,
        'customerNumber': _rapidSelectedCustomer?.customerNumber,
        'invoiceNumber': invoice,
        'items': List<Map<String, dynamic>>.from(validItems),
      });
      // Reset quick-add form
      _rapidSelectedCustomer = null;
      _rapidCustomerNameController.clear();
      _rapidCustomerAddressController.clear();
      _rapidInvoiceController.clear();
      _rapidCurrentItems = [{'description': '', 'quantity': 1.0}];
    });
  }

  void _removeFromRapidQueue(int index) {
    setState(() => _rapidQueue.removeAt(index));
  }

  Future<void> _createRapidBatch() async {
    if (_rapidQueue.isEmpty) return;

    if (_selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a driver in the header above'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCreatingRapidBatch = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser!.companyId;

      // Firestore batch supports up to 500 writes; split if needed
      const batchSize = 450;
      final chunks = <List<Map<String, dynamic>>>[];
      for (var i = 0; i < _rapidQueue.length; i += batchSize) {
        chunks.add(_rapidQueue.sublist(
            i, i + batchSize > _rapidQueue.length ? _rapidQueue.length : i + batchSize));
      }

      for (final chunk in chunks) {
        final batch = FirebaseFirestore.instance.batch();
        for (final entry in chunk) {
          final deliveryItems = (entry['items'] as List<Map<String, dynamic>>)
              .map((i) => DeliveryItem(
                    description: i['description'] as String,
                    quantity: (i['quantity'] as num).toDouble(),
                  ))
              .toList();

          final delivery = Delivery(
            id: '',
            companyId: companyId,
            driverId: _selectedDriverId!,
            customerId: entry['customerId'] as String?,
            customerNumber: entry['customerNumber'] as String?,
            customerName: entry['customerName'] as String,
            customerAddress: (entry['customerAddress'] as String?) ?? '',
            invoiceNumber: entry['invoiceNumber'] as String,
            items: deliveryItems,
            status: DeliveryStatus.pending,
            scheduledDate: _rapidDate,
            createdAt: DateTime.now(),
            vehicleUsed: _selectedVehicle,
          );

          final docRef = FirebaseFirestore.instance.collection('deliveries').doc();
          batch.set(docRef, delivery.toFirestore());
        }
        await batch.commit();
      }

      if (mounted) {
        final count = _rapidQueue.length;
        setState(() {
          _rapidQueue.clear();
          _rapidCurrentItems = [{'description': '', 'quantity': 1.0}];
          _isCreatingRapidBatch = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $count ${count == 1 ? 'delivery' : 'deliveries'} created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingRapidBatch = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating deliveries: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildTableMode() {
    return Column(
      children: [
        // Table controls
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          color: Colors.grey[100],
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _addDeliveryRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_tableDeliveries.length} deliveries',
                style: AppTextStyles.bodyMedium,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _tableDeliveries.isNotEmpty ? _createBulkDeliveries : null,
                icon: const Icon(Icons.save),
                label: const Text('Create All Deliveries'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // DataTable with core fields
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Invoice #', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Scheduled', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                ],
                rows: _tableDeliveries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final delivery = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(
                        _buildCustomerCell(index, delivery),
                      ),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            delivery['deliveryAddress'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            initialValue: delivery['invoiceNumber'] ?? '',
                            style: AppTextStyles.bodySmall,
                            decoration: const InputDecoration(
                              hintText: 'Invoice #',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (value) {
                              delivery['invoiceNumber'] = value;
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: delivery['scheduledDate'] ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  delivery['scheduledDate'] = date;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                delivery['scheduledDate'] != null
                                    ? DateFormat('MMM dd, yyyy').format(delivery['scheduledDate'] as DateTime)
                                    : 'Select date',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: delivery['scheduledDate'] != null ? Colors.black : Colors.grey[500],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: Text(
                            '${(delivery['items'] as List<DeliveryItem>?)?.length ?? 0} items',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ),
                      DataCell(
                        TextButton.icon(
                          onPressed: () => _showDeliveryDetailsDialog(index, delivery),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit', style: AppTextStyles.bodySmall),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _removeDeliveryRow(index),
                          tooltip: 'Remove delivery',
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCell(int index, Map<String, dynamic> delivery) {
    final customer = delivery['customer'] as Customer?;
    
    return SizedBox(
      width: 200,
      child: GestureDetector(
        onTap: () => _showCustomerPickerDialog(index, delivery),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  customer?.name ?? 'Select customer...',
                  style: TextStyle(
                    color: customer != null ? Colors.black : Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerPickerDialog(int deliveryIndex, Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Customer'),
        content: SizedBox(
          width: double.maxFinite,
          child: CustomerAutocomplete(
            initialCustomer: delivery['customer'],
            onCustomerSelected: (customer) {
              setState(() {
                delivery['customer'] = customer;
                delivery['customerId'] = customer?.id;
                if (customer != null) {
                  delivery['deliveryAddress'] = customer.address;
                  delivery['contactName'] = customer.contactPerson ?? customer.name;
                  delivery['contactPhone'] = customer.phone ?? '';
                }
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _addDeliveryRow() {
    setState(() {
      _tableDeliveries.add({
        'customer': null,
        'customerId': null,
        'deliveryAddress': '',
        'contactName': '',
        'contactPhone': '',
        'invoiceNumber': '',
        'invoiceDate': null,
        'orderNumber': null,
        'scheduledDate': DateTime.now(),
        'items': <DeliveryItem>[],
        'notes': null,
        'selectedDriverId': null,
        'selectedVehicle': null,
      });
    });
  }

  void _removeDeliveryRow(int index) {
    setState(() {
      _tableDeliveries.removeAt(index);
    });
  }

  void _showDeliveryDetailsDialog(int index, Map<String, dynamic> delivery) {
    // Local vehicles list for this dialog instance
    List<Map<String, String>> dialogVehicles = [];
    bool isLoadingDialogVehicles = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Function to load vehicles for the selected driver in this dialog
          Future<void> loadVehiclesForDialogDriver(String driverId) async {
            try {
              setState(() => isLoadingDialogVehicles = true);
              
              final authProvider = this.context.read<AuthProvider>();
              final companyId = authProvider.currentUser?.companyId;

              if (companyId == null) {
                debugPrint('âŒ No company ID found');
                setState(() => isLoadingDialogVehicles = false);
                return;
              }

              final snapshot = await FirebaseFirestore.instance
                  .collection('companies')
                  .doc(companyId)
                  .collection('vehicles')
                  .where('status', isEqualTo: 'active')
                  .get();

              final vehicles = <Map<String, String>>[];
              for (var doc in snapshot.docs) {
                final registration = doc['registration'] as String?;
                final make = doc['make'] as String?;
                final model = doc['model'] as String?;
                if (registration != null && registration.isNotEmpty) {
                  vehicles.add({
                    'id': doc.id,
                    'registration': normalizeRegistration(registration),
                    'make': make ?? '',
                    'model': model ?? ''
                  });
                }
              }

              debugPrint('ðŸ“¦ Dialog loaded ${vehicles.length} vehicles for driver $driverId');

              setState(() {
                dialogVehicles = vehicles;
                isLoadingDialogVehicles = false;
              });
            } catch (e) {
              debugPrint('âŒ Error loading vehicles in dialog: $e');
              setState(() => isLoadingDialogVehicles = false);
            }
          }
          
          return AlertDialog(
            title: Text('Delivery ${index + 1} - Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Order Number
                const Text('Order Number (Optional)', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: delivery['orderNumber'] ?? '',
                  decoration: const InputDecoration(
                    hintText: 'Customer PO or order number',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    delivery['orderNumber'] = value.trim().isEmpty ? null : value.trim();
                  },
                ),
                const SizedBox(height: 16),

                // Invoice Date
                const Text('Invoice Date (Optional)', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: delivery['invoiceDate'] ?? DateTime.now(),
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        delivery['invoiceDate'] = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          delivery['invoiceDate'] != null
                              ? DateFormat('MMM dd, yyyy').format(delivery['invoiceDate'] as DateTime)
                              : 'Select date',
                        ),
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Delivery Notes
                const Text('Notes', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: delivery['notes'] ?? '',
                  decoration: const InputDecoration(
                    hintText: 'Special delivery instructions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    delivery['notes'] = value.trim().isEmpty ? null : value.trim();
                  },
                ),
                const SizedBox(height: 16),

                // Driver Assignment
                const Text('Driver Assignment (Optional)', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: delivery['selectedDriverId'],
                  decoration: const InputDecoration(
                    hintText: 'Select driver',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No driver'),
                    ),
                    ..._drivers.map((driver) {
                      return DropdownMenuItem<String>(
                        value: driver['id'] as String,
                        child: Text(driver['name'] as String),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      delivery['selectedDriverId'] = value;
                      delivery['selectedVehicle'] = null; // Reset vehicle
                      // Load vehicles for the selected driver
                      if (value != null) {
                        loadVehiclesForDialogDriver(value);
                      } else {
                        dialogVehicles = [];
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Vehicle Selection
                if (delivery['selectedDriverId'] != null) ...[
                  const Text('Vehicle (Optional)', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 8),
                  if (isLoadingDialogVehicles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Loading vehicles...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else if (dialogVehicles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No active vehicles available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: delivery['selectedVehicle'],
                      decoration: const InputDecoration(
                        hintText: 'Select vehicle',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No vehicle'),
                        ),
                        ...dialogVehicles.map((vehicle) {
                          final reg = vehicle['registration'] ?? '';
                          final make = (vehicle['make'] ?? '').trim();
                          final model = (vehicle['model'] ?? '').trim();
                          final details = (make.isEmpty && model.isEmpty) ? '' : ' â€¢ ${[make, model].where((s) => s.isNotEmpty).join(' ')}';
                          return DropdownMenuItem<String>(
                            value: reg,
                            child: Text('$reg$details'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          delivery['selectedVehicle'] = value;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                ],

                // Items Management
                const Text('Items', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(delivery['items'] as List<DeliveryItem>?)?.length ?? 0} items',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      _buildItemsList(index, delivery),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showAddItemDialog(index, delivery, setState);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
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
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemsList(int deliveryIndex, Map<String, dynamic> delivery) {
    final items = delivery['items'] as List<DeliveryItem>;
    
    if (items.isEmpty) {
      return Text(
        'No items added yet',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      );
    }

    return Column(
      children: items.asMap().entries.map((entry) {
        final itemIndex = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                      ),
                      Text(
                        '${item.quantity} ${item.unit ?? ''}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: () {
                    (delivery['items'] as List<DeliveryItem>).removeAt(itemIndex);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAddItemDialog(int deliveryIndex, Map<String, dynamic> delivery, StateSetter setState) {
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final unitController = TextEditingController();
    final unitPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Item description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'e.g., box',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: unitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Unit Price (Optional)',
                  hintText: 'R 0.00',
                  border: OutlineInputBorder(),
                  prefixText: 'R ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final description = descriptionController.text.trim();
              final quantity = double.tryParse(quantityController.text) ?? 1;
              final unit = unitController.text.trim().isEmpty ? null : unitController.text.trim();
              final unitPrice = unitPriceController.text.trim().isEmpty ? null : double.tryParse(unitPriceController.text.trim());

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter item description')),
                );
                return;
              }

              final item = DeliveryItem(
                description: description,
                quantity: quantity,
                unit: unit,
                unitPrice: unitPrice,
                totalPrice: unitPrice != null ? quantity * unitPrice : null,
              );

              setState(() {
                (delivery['items'] as List<DeliveryItem>).add(item);
              });

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBulkDeliveries() async {
    if (_tableDeliveries.isEmpty) return;

    // Validate all deliveries
    final errors = <String>[];
    for (var i = 0; i < _tableDeliveries.length; i++) {
      final delivery = _tableDeliveries[i];
      if (delivery['customer'] == null) {
        errors.add('Delivery ${i + 1}: Customer is required');
      }
      if ((delivery['deliveryAddress'] as String?) == null || 
          (delivery['deliveryAddress'] as String).isEmpty) {
        errors.add('Delivery ${i + 1}: Address is required');
      }
      if ((delivery['items'] as List<DeliveryItem>?)?.isEmpty ?? true) {
        errors.add('Delivery ${i + 1}: At least one item is required');
      }
    }

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Errors'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: errors.map((error) => Text('â€¢ $error')).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating deliveries...'),
          ],
        ),
      ),
    );

    try {
      final authProvider = context.read<AuthProvider>();

      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      for (final tableDelivery in _tableDeliveries) {
        final customer = tableDelivery['customer'] as Customer;
        final items = tableDelivery['items'] as List<DeliveryItem>;
        
        final delivery = Delivery(
          id: '', // Will be generated
          companyId: authProvider.currentUser!.companyId,
          customerId: tableDelivery['customerId'] as String?,
          customerNumber: customer.customerNumber,
          driverId: (tableDelivery['selectedDriverId'] as String?) ?? '', // Use assigned driver or empty
          customerName: customer.name,
          customerAddress: tableDelivery['deliveryAddress'] as String,
          customerPhone: tableDelivery['contactPhone'] as String?,
          orderNumber: tableDelivery['orderNumber'] as String?, // Use order number from dialog
          invoiceNumber: tableDelivery['invoiceNumber'] as String? ?? 'INV-${DateTime.now().millisecondsSinceEpoch}', // Use invoice number from table or generate
          invoiceDate: tableDelivery['invoiceDate'] as DateTime? ?? now, // Use invoice date or current date
          items: items,
          status: DeliveryStatus.pending,
          scheduledDate: tableDelivery['scheduledDate'] as DateTime? ?? now,
          createdAt: now,
          notes: tableDelivery['notes'] as String?,
        );

        final docRef = FirebaseFirestore.instance.collection('deliveries').doc();
        batch.set(docRef, delivery.toFirestore());
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created ${_tableDeliveries.length} deliveries'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset table and switch back to single mode
        setState(() {
          _tableDeliveries.clear();
          _isTableMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create deliveries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
