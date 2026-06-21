import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../services/customer_import_service.dart';
import '../../services/csv_export_service.dart';
import '../../models/editable_customer.dart';
import '../../models/customer_model.dart';

class CustomerImportScreen extends StatefulWidget {
  const CustomerImportScreen({super.key});

  @override
  State<CustomerImportScreen> createState() => _CustomerImportScreenState();
}

class _CustomerImportScreenState extends State<CustomerImportScreen> {
  List<EditableCustomer>? _editableCustomers;
  List<ImportError> _fileErrors = [];
  bool _isLoading = false;
  bool _isImporting = false;
  String? _fileName;
  bool _isInitialized = false;
  Set<String> _existingNumbers = {};

  // Pagination
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  Future<void> _initializeProvider() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      
      if (companyId != null && companyId.isNotEmpty) {
        final customerProvider = context.read<CustomerProvider>();
        await customerProvider.initialize(companyId);
        if (mounted) {
          setState(() => _isInitialized = true);
          _loadExistingCustomerNumbers();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No company ID found. Please log in again.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _loadExistingCustomerNumbers() {
    try {
      final customerProvider = context.read<CustomerProvider>();
      final numbers = <String>{};
      for (var customer in customerProvider.customers) {
        numbers.add(customer.customerNumber);
      }
      setState(() {
        _existingNumbers = numbers;
      });
    } catch (e) {
      debugPrint('Error loading existing customer numbers: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isLoading = true;
        _fileName = result.files.first.name;
        _editableCustomers = null;
        _fileErrors = [];
      });

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw Exception('Could not read file');
      }

      final csvContent = utf8.decode(bytes);
      final parseResult = CustomerImportService.parseCsv(csvContent);

      // Convert to editable customers
      final editableList = parseResult.validCustomers
          .map((parsed) => EditableCustomer.fromParsed(parsed))
          .toList();

      // Validate all
      for (var customer in editableList) {
        customer.validate(
          existingNumbers: _existingNumbers.toList(),
          allCustomers: editableList,
        );
      }

      setState(() {
        _editableCustomers = editableList;
        _fileErrors = parseResult.errors;
        _isLoading = false;
        _currentPage = 0;
      });

      // Show summary
      if (!mounted) return;
      final validCount = editableList.where((c) => c.isValid).length;
      final errorCount = editableList.where((c) => c.hasErrors).length + parseResult.errors.length;
      final warningCount = editableList.fold<int>(0, (total, c) => total + c.warnings.length);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Parsed ${editableList.length} rows: $validCount valid, $errorCount errors, $warningCount warnings',
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _downloadTemplate() {
    try {
      final headers = [
        'Customer Number',
        'Customer Name',
        'Address',
        'Contact Person',
        'Phone',
        'Email',
        'Delivery Instructions',
        'Account Number',
        'Customer Type',
        'Tags',
        'Active',
      ];

      final rows = [
        [
          'BOX001',
          'Boxer Superstore',
          '123 Main Street, Cape Town, 8001',
          'John Smith',
          '+27 21 123 4567',
          'john@boxer.co.za',
          'Use loading dock at rear',
          'ACC-12345',
          'business',
          'retail, priority',
          'true',
        ],
        [
          'PICK001',
          'Pick n Pay Rondebosch',
          '456 Main Road, Rondebosch, 7700',
          'Jane Doe',
          '+27 21 987 6543',
          'jane@pnp.co.za',
          'Deliver before 8am',
          'ACC-67890',
          'business',
          'retail',
          'true',
        ],
      ];

      CSVExportService.exportToCSV(
        filename: 'customer_import_template',
        headers: headers,
        rows: rows,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Template downloaded successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      return Future.value();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading template: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return Future.value();
    }
  }

  void _revalidateAll() {
    if (_editableCustomers == null) return;

    setState(() {
      for (var customer in _editableCustomers!) {
        customer.validate(
          existingNumbers: _existingNumbers.toList(),
          allCustomers: _editableCustomers,
        );
      }
    });
  }

  void _toggleAllSelections(bool selected) {
    if (_editableCustomers == null) return;

    setState(() {
      for (var customer in _editableCustomers!) {
        if (!customer.isRemoved && customer.isValid) {
          customer.isSelected = selected;
        }
      }
    });
  }

  void _toggleRemoved(EditableCustomer customer) {
    setState(() {
      customer.isRemoved = !customer.isRemoved;
      if (customer.isRemoved) {
        customer.isSelected = false;
      }
      _revalidateAll();
    });
  }

  Future<void> _importCustomers() async {
    if (_editableCustomers == null) return;

    final selectedValid = _editableCustomers!
        .where((c) => c.isSelected && c.isValid && !c.isRemoved)
        .toList();

    if (selectedValid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid customers selected for import'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Text(
          'Import ${selectedValid.length} selected customers?\n\n'
          'This will create new customer records in the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isImporting = true;
    });

    try {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final authProvider = context.read<AuthProvider>();
      // ignore: use_build_context_synchronously
      final customerProvider = context.read<CustomerProvider>();
      
      final companyId = authProvider.currentUser?.companyId;
      if (companyId == null) throw Exception('Company not found');

      final parsedCustomers = selectedValid
          .map((c) => c.toCustomer(companyId: companyId))
          .toList();

      await customerProvider.importCustomers(
        parsedCustomers.map((c) => ParsedCustomer(
          rowNumber: 0,
          customerNumber: c.customerNumber,
          name: c.name,
          address: c.address,
          contactPerson: c.contactPerson,
          phone: c.phone,
          email: c.email,
          deliveryInstructions: c.deliveryInstructions,
          accountNumber: c.accountNumber,
          customerType: c.customerType,
          tags: c.tags,
          isActive: c.isActive,
        )).toList(),
        (_, __) {},
      );

      // Save count before clearing state
      final importedCount = selectedValid.length;

      setState(() {
        _isImporting = false;
        _editableCustomers = null;
        _fileName = null;
        _fileErrors = [];
      });

      if (!mounted) return;

      // Show success
      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Text(
            'Successfully imported $importedCount customers!',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing customers: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Customers'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_editableCustomers != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _revalidateAll,
              tooltip: 'Re-validate all',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(),
            tooltip: 'Help',
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading customers...'),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _editableCustomers == null
                  ? _buildUploadPrompt()
                  : _buildEditableTable(),
    );
  }

  Widget _buildUploadPrompt() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.upload_file,
                size: 100,
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Import Customers',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload a CSV file with your customer data. Review and edit before importing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Template'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Choose CSV File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Required Columns:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('• Customer Number - Unique identifier'),
                      const Text('• Customer Name - Full name'),
                      const Text('• Address - Complete address'),
                      const SizedBox(height: 16),
                      const Text(
                        'Optional: Contact Person, Phone, Email, Delivery Instructions, Account Number, Customer Type, Tags, Active',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableTable() {
    final customers = _editableCustomers!;
    final totalCount = customers.length;
    final selectedCount = customers.where((c) => c.isSelected && !c.isRemoved).length;
    final validCount = customers.where((c) => c.isValid && !c.isRemoved).length;
    final errorCount = customers.where((c) => c.hasErrors && !c.isRemoved).length + _fileErrors.length;
    final warningCount = customers.where((c) => !c.isRemoved).fold<int>(0, (total, c) => total + c.warnings.length);
    final removedCount = customers.where((c) => c.isRemoved).length;

    final activeCustomers = customers.where((c) => !c.isRemoved).toList();
    final totalPages = (activeCustomers.length / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, activeCustomers.length);
    final pageCustomers = activeCustomers.sublist(startIndex, endIndex);

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          color: errorCount > 0 ? Colors.red[50] : Colors.green[50],
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    errorCount > 0 ? Icons.warning : Icons.check_circle,
                    color: errorCount > 0 ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? 'CSV File',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$totalCount rows • $validCount valid • $errorCount errors • $warningCount warnings',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (removedCount > 0)
                          Text(
                            '$removedCount rows removed',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_upload, size: 16),
                    label: const Text('Choose New File'),
                  ),
                  const SizedBox(width: 8),
                  if (validCount > 0)
                    ElevatedButton.icon(
                      onPressed: _isImporting ? null : _importCustomers,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_isImporting
                          ? 'Importing...'
                          : 'Import Selected ($selectedCount)'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: selectedCount == validCount && validCount > 0,
                    tristate: selectedCount > 0 && selectedCount < validCount,
                    onChanged: validCount > 0
                        ? (value) => _toggleAllSelections(value ?? false)
                        : null,
                  ),
                  const Text('Select all valid rows'),
                ],
              ),
            ],
          ),
        ),

        // File-level errors
        if (_fileErrors.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.red[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'File Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                ..._fileErrors.map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $error', style: const TextStyle(color: Colors.red)),
                    )),
              ],
            ),
          ),
        ],

        // Editable table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1400,
              child: Column(
                children: [
                  Container(
                    color: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: const Row(
                      children: [
                        SizedBox(width: 40),
                        SizedBox(width: 50, child: Text('Row', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 120, child: Text('Cust. #', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 200, child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 130, child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 130, child: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 130, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: pageCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = pageCustomers[index];
                        return _buildEditableRow(customer);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Pagination
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
                const SizedBox(width: 16),
                Text('Showing ${startIndex + 1}-$endIndex of ${activeCustomers.length}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEditableRow(EditableCustomer customer) {
    final hasErrors = customer.hasErrors;
    final hasWarnings = customer.hasWarnings;
    final rowColor = hasErrors
        ? Colors.red[50]
        : hasWarnings
            ? Colors.orange[50]
            : customer.isEdited
                ? Colors.blue[50]
                : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: customer.isSelected,
              onChanged: customer.isValid
                  ? (value) {
                      setState(() {
                        customer.isSelected = value ?? false;
                      });
                    }
                  : null,
            ),
          ),

          SizedBox(
            width: 50,
            child: Row(
              children: [
                if (hasErrors)
                  const Icon(Icons.error, color: Colors.red, size: 16)
                else if (hasWarnings)
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text('#${customer.rowNumber}'),
              ],
            ),
          ),

          SizedBox(
            width: 120,
            child: _buildEditableCell(
              value: customer.customerNumber,
              onChanged: (value) {
                setState(() {
                  customer.customerNumber = value;
                  customer.isEdited = true;
                  _revalidateAll();
                });
              },
              hasError: customer.errors.any((e) => e.field == 'customerNumber'),
            ),
          ),

          SizedBox(
            width: 150,
            child: _buildEditableCell(
              value: customer.name,
              onChanged: (value) {
                setState(() {
                  customer.name = value;
                  customer.isEdited = true;
                  customer.validate(
                    existingNumbers: _existingNumbers.toList(),
                    allCustomers: _editableCustomers,
                  );
                });
              },
              hasError: customer.errors.any((e) => e.field == 'name'),
            ),
          ),

          SizedBox(
            width: 200,
            child: _buildEditableCell(
              value: customer.address,
              onChanged: (value) {
                setState(() {
                  customer.address = value;
                  customer.isEdited = true;
                  customer.validate(
                    existingNumbers: _existingNumbers.toList(),
                    allCustomers: _editableCustomers,
                  );
                });
              },
              hasError: customer.errors.any((e) => e.field == 'address'),
            ),
          ),

          SizedBox(
            width: 130,
            child: _buildEditableCell(
              value: customer.phone ?? '',
              onChanged: (value) {
                setState(() {
                  customer.phone = value.isEmpty ? null : value;
                  customer.isEdited = true;
                  customer.validate(
                    existingNumbers: _existingNumbers.toList(),
                    allCustomers: _editableCustomers,
                  );
                });
              },
            ),
          ),

          SizedBox(
            width: 150,
            child: _buildEditableCell(
              value: customer.email ?? '',
              onChanged: (value) {
                setState(() {
                  customer.email = value.isEmpty ? null : value;
                  customer.isEdited = true;
                  customer.validate(
                    existingNumbers: _existingNumbers.toList(),
                    allCustomers: _editableCustomers,
                  );
                });
              },
            ),
          ),

          SizedBox(
            width: 130,
            child: _buildEditableCell(
              value: customer.contactPerson ?? '',
              onChanged: (value) {
                setState(() {
                  customer.contactPerson = value.isEmpty ? null : value;
                  customer.isEdited = true;
                });
              },
            ),
          ),

          SizedBox(
            width: 130,
            child: DropdownButton<CustomerType>(
              value: customer.customerType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    customer.customerType = value;
                    customer.isEdited = true;
                  });
                }
              },
              items: CustomerType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      ))
                  .toList(),
              isExpanded: true,
              underline: Container(),
            ),
          ),

          SizedBox(
            width: 80,
            child: Row(
              children: [
                if (hasErrors || hasWarnings)
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    onPressed: () => _showErrorsDialog(customer),
                    tooltip: 'View errors/warnings',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _toggleRemoved(customer),
                  tooltip: 'Remove from import',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCell({
    required String value,
    required ValueChanged<String> onChanged,
    bool hasError = false,
  }) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey[300]!),
        ),
      ),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
    );
  }

  void _showErrorsDialog(EditableCustomer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Row #${customer.rowNumber} - Issues'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customer.errors.isNotEmpty) ...[
                const Text(
                  'Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                ...customer.errors.map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${error.message}', style: const TextStyle(color: Colors.red)),
                    )),
                const SizedBox(height: 16),
              ],
              if (customer.warnings.isNotEmpty) ...[
                const Text(
                  'Warnings:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                ...customer.warnings.map((warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${warning.message}', style: const TextStyle(color: Colors.orange)),
                    )),
              ],
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
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer Import Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to use customer import:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Download the CSV template'),
              Text('2. Fill in your customer data'),
              Text('3. Upload the CSV file'),
              Text('4. Review and edit data in the table'),
              Text('5. Select rows to import'),
              Text('6. Click "Import Selected"'),
              SizedBox(height: 16),
              Text(
                'Editing Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Click any cell to edit'),
              Text('• Select customer type from dropdown'),
              Text('• Red rows have errors (cannot import)'),
              Text('• Orange rows have warnings (can still import)'),
              Text('• Blue rows have been edited'),
              Text('• Use checkbox to select/deselect rows'),
              Text('• Click trash icon to remove from import'),
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
  }
}
