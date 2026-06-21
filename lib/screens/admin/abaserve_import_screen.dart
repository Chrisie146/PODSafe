import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../../services/bulk_import_service.dart';
import '../../services/csv_export_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../models/editable_delivery.dart';
import '../../models/delivery_model.dart';

class AbaserveImportScreen extends StatefulWidget {
  const AbaserveImportScreen({super.key});

  @override
  State<AbaserveImportScreen> createState() => _AbaserveImportScreenState();
}

class _AbaserveImportScreenState extends State<AbaserveImportScreen> {
  List<EditableDelivery>? _editableDeliveries;
  List<ValidationError> _fileErrors = [];
  bool _isLoading = false;
  bool _isImporting = false;
  String? _fileName;
  Map<String, String> _driverEmailToId = {};
  bool _driversLoaded = false;
  Set<String> _existingInvoices = {};

  // Pagination
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _loadExistingInvoices();
  }

  Future<void> _loadDrivers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;
      if (companyId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .where('role', isEqualTo: 'driver')
          .get();

      final emailToId = <String, String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String?;
        if (email != null) {
          emailToId[email.toLowerCase()] = doc.id;
        }
      }

      setState(() {
        _driverEmailToId = emailToId;
        _driversLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }
  }

  Future<void> _loadExistingInvoices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;
      if (companyId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId)
          .get();

      final invoices = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final invoiceNumber = data['invoiceNumber'] as String?;
        if (invoiceNumber != null) {
          invoices.add(invoiceNumber);
        }
      }

      setState(() {
        _existingInvoices = invoices;
      });
    } catch (e) {
      debugPrint('Error loading invoices: $e');
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
        _editableDeliveries = null;
        _fileErrors = [];
      });

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw Exception('Could not read file');
      }

      final csvContent = utf8.decode(bytes);
      final parseResult = BulkImportService.parseCsv(csvContent);

      // Convert to editable deliveries
      final editableList = parseResult.validDeliveries
          .map((parsed) => EditableDelivery.fromParsed(parsed))
          .toList();

      // Validate all
      for (var delivery in editableList) {
        delivery.validate(
          existingInvoices: _existingInvoices.toList(),
          allDeliveries: editableList,
        );
      }

      setState(() {
        _editableDeliveries = editableList;
        _fileErrors = parseResult.errors;
        _isLoading = false;
        _currentPage = 0;
      });

      // Show summary
      if (!mounted) return;
      final validCount = editableList.where((d) => d.isValid).length;
      final errorCount = editableList.where((d) => d.hasErrors).length + parseResult.errors.length;
      final warningCount = editableList.fold<int>(0, (total, d) => total + d.warnings.length);

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
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
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
            content: Text('✓ Template downloaded successfully'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading template: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _revalidateAll() {
    if (_editableDeliveries == null) return;

    setState(() {
      for (var delivery in _editableDeliveries!) {
        delivery.validate(
          existingInvoices: _existingInvoices.toList(),
          allDeliveries: _editableDeliveries,
        );
      }
    });
  }

  void _toggleAllSelections(bool selected) {
    if (_editableDeliveries == null) return;

    setState(() {
      for (var delivery in _editableDeliveries!) {
        if (!delivery.isRemoved && delivery.isValid) {
          delivery.isSelected = selected;
        }
      }
    });
  }

  void _toggleRemoved(EditableDelivery delivery) {
    setState(() {
      delivery.isRemoved = !delivery.isRemoved;
      if (delivery.isRemoved) {
        delivery.isSelected = false;
      }
      _revalidateAll();
    });
  }

  Future<void> _importDeliveries() async {
    if (_editableDeliveries == null) return;

    final selectedValid = _editableDeliveries!
        .where((d) => d.isSelected && d.isValid && !d.isRemoved)
        .toList();

    if (selectedValid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid deliveries selected for import'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm import
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Text(
          'Import ${selectedValid.length} selected deliveries from ABServe?\n\n'
          'This will create new delivery records in the database.',
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      if (!mounted) return;
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;
      if (companyId == null) throw Exception('Company not found');

      // Prepare batch writes (Firestore max 500 per batch)
      final batches = <WriteBatch>[];
      var currentBatch = FirebaseFirestore.instance.batch();
      var operationCount = 0;

      for (var editable in selectedValid) {
        // Resolve driver ID
        String driverId = 'unassigned';
        if (editable.driverEmail != null && _driversLoaded) {
          final foundId = _driverEmailToId[editable.driverEmail!.toLowerCase()];
          if (foundId != null) {
            driverId = foundId;
          }
        }

        // Convert to Delivery
        final delivery = editable.toDelivery(
          companyId: companyId,
          driverId: driverId,
        );

        // Add to batch
        final docRef = FirebaseFirestore.instance.collection('deliveries').doc();
        currentBatch.set(docRef, delivery.toFirestore());
        operationCount++;

        // Start new batch if needed
        if (operationCount >= 500) {
          batches.add(currentBatch);
          currentBatch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      // Add final batch
      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      // Commit all batches
      for (var batch in batches) {
        await batch.commit();
      }

      // Save count before clearing state
      final importedCount = selectedValid.length;

      setState(() {
        _isImporting = false;
        _editableDeliveries = null;
        _fileName = null;
        _fileErrors = [];
      });

      if (!mounted) return;

      // Show success
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Text(
            'Successfully imported $importedCount deliveries from ABServe!',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to delivery management
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing deliveries: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from ABServe'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          if (_editableDeliveries != null) ...[
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _editableDeliveries == null
              ? _buildUploadPrompt()
              : _buildEditableTable(),
    );
  }

  Widget _buildUploadPrompt() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Import from ABServe',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload a CSV file exported from your ABServe ERP system',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Required CSV Columns:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• customerName, customerAddress, invoiceNumber, scheduledDate'),
                  Text('• Date format: YYYY-MM-DD (e.g., 2025-10-17)'),
                  Text('• Optional: customerPhone, driverEmail, notes'),
                  Text('• Up to 10 items per delivery'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableTable() {
    final deliveries = _editableDeliveries!;
    final totalCount = deliveries.length;
    final selectedCount = deliveries.where((d) => d.isSelected && !d.isRemoved).length;
    final validCount = deliveries.where((d) => d.isValid && !d.isRemoved).length;
    final errorCount = deliveries.where((d) => d.hasErrors && !d.isRemoved).length + _fileErrors.length;
    final warningCount = deliveries.where((d) => !d.isRemoved).fold<int>(0, (total, d) => total + d.warnings.length);
    final removedCount = deliveries.where((d) => d.isRemoved).length;

    // Paginated data
    final activeDeliveries = deliveries.where((d) => !d.isRemoved).toList();
    final totalPages = (activeDeliveries.length / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, activeDeliveries.length);
    final pageDeliveries = activeDeliveries.sublist(startIndex, endIndex);

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
                    color: errorCount > 0 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? 'ABServe CSV File',
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
                      onPressed: _isImporting ? null : _importDeliveries,
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
              width: 1600,
              child: Column(
                children: [
                  // Table header
                  Container(
                    color: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: const Row(
                      children: [
                        SizedBox(width: 40),
                        SizedBox(width: 50, child: Text('Row', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 200, child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 120, child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 120, child: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 120, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('Driver Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('Items', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  // Table rows
                  Expanded(
                    child: ListView.builder(
                      itemCount: pageDeliveries.length,
                      itemBuilder: (context, index) {
                        final delivery = pageDeliveries[index];
                        return _buildEditableRow(delivery);
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
                Text('Showing ${startIndex + 1}-$endIndex of ${activeDeliveries.length}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEditableRow(EditableDelivery delivery) {
    final hasErrors = delivery.hasErrors;
    final hasWarnings = delivery.hasWarnings;
    final rowColor = hasErrors
        ? Colors.red[50]
        : hasWarnings
            ? Colors.orange[50]
            : delivery.isEdited
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
              value: delivery.isSelected,
              onChanged: delivery.isValid
                  ? (value) {
                      setState(() {
                        delivery.isSelected = value ?? false;
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
                Text('#${delivery.rowNumber}'),
              ],
            ),
          ),

          SizedBox(
            width: 150,
            child: _buildEditableCell(
              value: delivery.customerName,
              onChanged: (value) {
                setState(() {
                  delivery.customerName = value;
                  delivery.isEdited = true;
                  delivery.validate(
                    existingInvoices: _existingInvoices.toList(),
                    allDeliveries: _editableDeliveries,
                  );
                });
              },
              hasError: delivery.errors.any((e) => e.field == 'customerName'),
            ),
          ),

          SizedBox(
            width: 200,
            child: _buildEditableCell(
              value: delivery.customerAddress,
              onChanged: (value) {
                setState(() {
                  delivery.customerAddress = value;
                  delivery.isEdited = true;
                  delivery.validate(
                    existingInvoices: _existingInvoices.toList(),
                    allDeliveries: _editableDeliveries,
                  );
                });
              },
              hasError: delivery.errors.any((e) => e.field == 'customerAddress'),
            ),
          ),

          SizedBox(
            width: 120,
            child: _buildEditableCell(
              value: delivery.customerPhone ?? '',
              onChanged: (value) {
                setState(() {
                  delivery.customerPhone = value.isEmpty ? null : value;
                  delivery.isEdited = true;
                  delivery.validate(
                    existingInvoices: _existingInvoices.toList(),
                    allDeliveries: _editableDeliveries,
                  );
                });
              },
            ),
          ),

          SizedBox(
            width: 120,
            child: _buildEditableCell(
              value: delivery.invoiceNumber,
              onChanged: (value) {
                setState(() {
                  delivery.invoiceNumber = value;
                  delivery.isEdited = true;
                  _revalidateAll();
                });
              },
              hasError: delivery.errors.any((e) => e.field == 'invoiceNumber'),
            ),
          ),

          SizedBox(
            width: 120,
            child: _buildDateCell(delivery),
          ),

          SizedBox(
            width: 150,
            child: _buildEditableCell(
              value: delivery.driverEmail ?? '',
              onChanged: (value) {
                setState(() {
                  delivery.driverEmail = value.isEmpty ? null : value;
                  delivery.isEdited = true;
                  delivery.validate(
                    existingInvoices: _existingInvoices.toList(),
                    allDeliveries: _editableDeliveries,
                  );
                });
              },
            ),
          ),

          SizedBox(
            width: 100,
            child: TextButton(
              onPressed: () => _showItemsEditor(delivery),
              child: Text('${delivery.items.length} items'),
            ),
          ),

          SizedBox(
            width: 150,
            child: _buildEditableCell(
              value: delivery.notes ?? '',
              onChanged: (value) {
                setState(() {
                  delivery.notes = value.isEmpty ? null : value;
                  delivery.isEdited = true;
                });
              },
            ),
          ),

          SizedBox(
            width: 80,
            child: Row(
              children: [
                if (hasErrors || hasWarnings)
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    onPressed: () => _showErrorsDialog(delivery),
                    tooltip: 'View errors/warnings',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _toggleRemoved(delivery),
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

  Widget _buildDateCell(EditableDelivery delivery) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: delivery.scheduledDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          setState(() {
            delivery.scheduledDate = date;
            delivery.isEdited = true;
            delivery.validate(
              existingInvoices: _existingInvoices.toList(),
              allDeliveries: _editableDeliveries,
            );
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('yyyy-MM-dd').format(delivery.scheduledDate),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }

  void _showItemsEditor(EditableDelivery delivery) {
    showDialog(
      context: context,
      builder: (context) => _ItemsEditorDialog(
        delivery: delivery,
        onSave: (items) {
          setState(() {
            delivery.items = items;
            delivery.isEdited = true;
            delivery.validate(
              existingInvoices: _existingInvoices.toList(),
              allDeliveries: _editableDeliveries,
            );
          });
        },
      ),
    );
  }

  void _showErrorsDialog(EditableDelivery delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Row #${delivery.rowNumber} - Issues'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (delivery.errors.isNotEmpty) ...[
                const Text(
                  'Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                ...delivery.errors.map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${error.message}', style: const TextStyle(color: Colors.red)),
                    )),
                const SizedBox(height: 16),
              ],
              if (delivery.warnings.isNotEmpty) ...[
                const Text(
                  'Warnings:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                ...delivery.warnings.map((warning) => Padding(
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
        title: const Text('ABServe Import Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to use ABServe import:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Export CSV from your ABServe system'),
              Text('2. Upload the CSV file'),
              Text('3. Review and edit data in the table'),
              Text('4. Select rows to import'),
              Text('5. Click "Import Selected"'),
              SizedBox(height: 16),
              Text(
                'Editing Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Click any cell to edit'),
              Text('• Click date to open calendar'),
              Text('• Click items count to edit line items'),
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

// Items editor dialog
class _ItemsEditorDialog extends StatefulWidget {
  final EditableDelivery delivery;
  final ValueChanged<List<DeliveryItem>> onSave;

  const _ItemsEditorDialog({
    required this.delivery,
    required this.onSave,
  });

  @override
  State<_ItemsEditorDialog> createState() => _ItemsEditorDialogState();
}

class _ItemsEditorDialogState extends State<_ItemsEditorDialog> {
  late List<_EditableItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.delivery.items
        .map((item) => _EditableItem(
              description: item.description,
              quantity: item.quantity,
              unit: item.unit ?? 'pcs',
            ))
        .toList();
  }

  void _addItem() {
    setState(() {
      _items.add(_EditableItem(
        description: '',
        quantity: 1,
        unit: 'pcs',
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Items - Row #${widget.delivery.rowNumber}'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: item.description,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                isDense: true,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _items[index] = _EditableItem(
                                    description: value,
                                    quantity: item.quantity,
                                    unit: item.unit,
                                  );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: item.quantity.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _items[index] = _EditableItem(
                                    description: item.description,
                                    quantity: double.tryParse(value) ?? 1,
                                    unit: item.unit,
                                  );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: item.unit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                isDense: true,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _items[index] = _EditableItem(
                                    description: item.description,
                                    quantity: item.quantity,
                                    unit: value,
                                  );
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
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
            final deliveryItems = _items
                .map((item) => DeliveryItem(
                      description: item.description,
                      quantity: item.quantity,
                      unit: item.unit,
                    ))
                .toList();
            widget.onSave(deliveryItems);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Helper class for editable items (DeliveryItem is immutable)
class _EditableItem {
  String description;
  double quantity;
  String unit;

  _EditableItem({
    required this.description,
    required this.quantity,
    required this.unit,
  });
}
