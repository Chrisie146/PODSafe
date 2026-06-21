import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/editable_customer.dart';
import '../../models/customer_model.dart';

class CustomerCreationScreen extends StatefulWidget {
  const CustomerCreationScreen({super.key});

  @override
  State<CustomerCreationScreen> createState() => _CustomerCreationScreenState();
}

class _CustomerCreationScreenState extends State<CustomerCreationScreen> {
  List<EditableCustomer>? _editableCustomers;
  bool _isCreating = false;
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
          _initializeEmptyTable();
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

  void _initializeEmptyTable() {
    setState(() {
      _editableCustomers = [
        _createBlankCustomer(1),
        _createBlankCustomer(2),
        _createBlankCustomer(3),
      ];
    });
  }

  EditableCustomer _createBlankCustomer(int rowNumber) {
    final customer = EditableCustomer(
      rowNumber: rowNumber,
      customerNumber: '',
      name: '',
      address: '',
      contactPerson: null,
      phone: null,
      email: null,
      deliveryInstructions: null,
      accountNumber: null,
      customerType: CustomerType.business,
      tags: [],
      isActive: true,
      isSelected: false,
      isRemoved: false,
      isEdited: false,
      errors: [],
      warnings: [],
    );
    return customer;
  }

  void _addRow() {
    if (_editableCustomers == null) return;

    final maxRow = _editableCustomers!.fold<int>(
      0,
      (max, c) => c.rowNumber > max ? c.rowNumber : max,
    );

    setState(() {
      _editableCustomers!.add(_createBlankCustomer(maxRow + 1));
      _currentPage = (_editableCustomers!.length / _rowsPerPage).ceil() - 1;
    });
  }

  void _addMultipleRows(int count) {
    if (_editableCustomers == null) return;

    final maxRow = _editableCustomers!.fold<int>(
      0,
      (max, c) => c.rowNumber > max ? c.rowNumber : max,
    );

    setState(() {
      for (int i = 0; i < count; i++) {
        _editableCustomers!.add(_createBlankCustomer(maxRow + i + 1));
      }
      _currentPage = (_editableCustomers!.length / _rowsPerPage).ceil() - 1;
    });
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text == null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text in clipboard'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Parse tab-separated or comma-separated values
      final lines = clipboardData!.text!.split('\n');
      final rows = <List<String>>[];

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        // Try tab-separated first, then comma
        final parts = line.contains('\t')
            ? line.split('\t')
            : line.split(',');
        rows.add(parts.map((p) => p.trim()).toList());
      }

      if (rows.isEmpty) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data found in clipboard'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Map columns: Customer Number, Name, Address, Contact Person, Phone, Email
      final maxRow = _editableCustomers!.fold<int>(
        0,
        (max, c) => c.rowNumber > max ? c.rowNumber : max,
      );

      final newCustomers = <EditableCustomer>[];
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final customer = EditableCustomer(
          rowNumber: maxRow + i + 1,
          customerNumber: row.isNotEmpty ? row[0] : '',
          name: row.length > 1 ? row[1] : '',
          address: row.length > 2 ? row[2] : '',
          contactPerson: row.length > 3 && row[3].isNotEmpty ? row[3] : null,
          phone: row.length > 4 && row[4].isNotEmpty ? row[4] : null,
          email: row.length > 5 && row[5].isNotEmpty ? row[5] : null,
          deliveryInstructions: null,
          accountNumber: null,
          customerType: CustomerType.business,
          tags: [],
          isActive: true,
          isSelected: false,
          isRemoved: false,
          isEdited: false,
          errors: [],
          warnings: [],
        );
        newCustomers.add(customer);
      }

      setState(() {
        _editableCustomers!.addAll(newCustomers);
        _currentPage = (_editableCustomers!.length / _rowsPerPage).ceil() - 1;
      });

      _revalidateAll();

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Pasted ${newCustomers.length} rows from clipboard'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error pasting data: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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

  void _removeRow(EditableCustomer customer) {
    if (_editableCustomers == null) return;

    setState(() {
      _editableCustomers!.removeWhere((c) => c.rowNumber == customer.rowNumber);
      _revalidateAll();
    });
  }

  Future<void> _createCustomers() async {
    if (_editableCustomers == null) return;

    final selectedValid = _editableCustomers!
        .where((c) => c.isSelected && c.isValid && !c.isRemoved)
        .toList();

    if (selectedValid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid customers selected for creation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Creation'),
        content: Text(
          'Create ${selectedValid.length} new customers?\n\n'
          'This will add new customer records to the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ignore: use_build_context_synchronously
    final authProvider = context.read<AuthProvider>();
    // ignore: use_build_context_synchronously
    final customerProvider = context.read<CustomerProvider>();
    
    final companyId = authProvider.currentUser?.companyId;
    if (companyId == null) throw Exception('Company not found');

    setState(() {
      _isCreating = true;
    });

    try {
      if (!mounted) return;

      final customersToCreate = selectedValid
          .map((c) => c.toCustomer(companyId: companyId))
          .toList();

      // Add to provider (which will handle Firestore writes)
      await customerProvider.createCustomers(customersToCreate);

      // Reload existing numbers
      _loadExistingCustomerNumbers();

      // Save count before clearing state
      final createdCount = selectedValid.length;

      setState(() {
        _isCreating = false;
        _editableCustomers = [
          _createBlankCustomer(1),
          _createBlankCustomer(2),
          _createBlankCustomer(3),
        ];
        _currentPage = 0;
      });

      if (!mounted) return;

      // Show success
      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Creation Complete'),
          content: Text(
            'Successfully created $createdCount customers!',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating customers: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Customers'),
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
          : _editableCustomers == null
              ? const Center(child: CircularProgressIndicator())
              : _buildEditableTable(),
    );
  }

  Widget _buildEditableTable() {
    final customers = _editableCustomers!;
    final totalCount = customers.length;
    final selectedCount = customers.where((c) => c.isSelected && !c.isRemoved).length;
    final validCount = customers.where((c) => c.isValid && !c.isRemoved).length;
    final errorCount = customers.where((c) => c.hasErrors && !c.isRemoved).length;
    final warningCount = customers.where((c) => !c.isRemoved).fold<int>(0, (total, c) => total + c.warnings.length);

    final totalPages = (totalCount / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalCount);
    final pageCustomers = customers.sublist(startIndex, endIndex);

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
                        const Text(
                          'New Customers',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$totalCount rows • $validCount valid • $errorCount errors • $warningCount warnings',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text('Add Rows', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      PopupMenuItem<String>(
                        child: const Text('Add 1 Row'),
                        onTap: () => _addRow(),
                      ),
                      PopupMenuItem<String>(
                        child: const Text('Add 5 Rows'),
                        onTap: () => _addMultipleRows(5),
                      ),
                      PopupMenuItem<String>(
                        child: const Text('Add 10 Rows'),
                        onTap: () => _addMultipleRows(10),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        child: const Text('Paste from Clipboard'),
                        onTap: () => _pasteFromClipboard(),
                      ),
                    ],
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Rows'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (validCount > 0)
                    ElevatedButton.icon(
                      onPressed: _isCreating ? null : _createCustomers,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isCreating
                          ? 'Creating...'
                          : 'Create Selected ($selectedCount)'),
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
                Text('Showing ${startIndex + 1}-$endIndex of $totalCount'),
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
                  onPressed: () => _removeRow(customer),
                  tooltip: 'Delete row',
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
        title: const Text('Customer Creation Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to create customers:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Add rows manually or paste from clipboard'),
              Text('2. Fill in customer data in the table'),
              Text('3. Review validation results'),
              Text('4. Select rows to create'),
              Text('5. Click "Create Selected"'),
              SizedBox(height: 16),
              Text(
                'Quick Entry:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Click "Add Rows" to add blank rows'),
              Text('• Paste multi-row data: [Cust #][Tab][Name][Tab][Address]...'),
              SizedBox(height: 16),
              Text(
                'Visual Indicators:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Red rows have errors (cannot create)'),
              Text('• Orange rows have warnings (can still create)'),
              Text('• Blue rows have been edited'),
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
