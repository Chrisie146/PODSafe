import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../models/delivery_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/csv_export_service.dart';
import '../../services/delivery_export_service.dart';
import '../../widgets/pod_qr_code.dart';
import '../../services/pod_token_service.dart';
import 'create_delivery_screen.dart';
import 'delivery_details_screen.dart';
import 'bulk_upload_screen.dart';

// Column configuration model
class ColumnConfig {
  final String key;
  final String label;
  final bool visible;
  final int index;

  ColumnConfig({
    required this.key,
    required this.label,
    required this.visible,
    required this.index,
  });

  ColumnConfig copyWith({
    String? key,
    String? label,
    bool? visible,
    int? index,
  }) {
    return ColumnConfig(
      key: key ?? this.key,
      label: label ?? this.label,
      visible: visible ?? this.visible,
      index: index ?? this.index,
    );
  }
}

class DeliveryManagementDesktop extends StatefulWidget {
  const DeliveryManagementDesktop({super.key});

  @override
  State<DeliveryManagementDesktop> createState() => _DeliveryManagementDesktopState();
}

class _DeliveryManagementDesktopState extends State<DeliveryManagementDesktop> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  DeliveryStatus? _statusFilter;
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  bool? _thirdPartyFilter; // null = all, true = 3rd party only, false = internal only
  
  // Multi-select state
  bool _isMultiSelectMode = false;
  final Set<String> _selectedDeliveryIds = {};
  
  // Preview panel
  bool _showPreviewPanel = false;
  Delivery? _previewDelivery;
  
  // Filter sidebar
  bool _showFilters = true;
  
  // Statistics expansion
  bool _statsExpanded = true;
  
  // Sort state
  int? _sortColumnIndex;
  bool _sortAscending = true;
  
  // Statistics
  int _totalCount = 0;
  int _pendingCount = 0;
  int _inTransitCount = 0;
  int _deliveredCount = 0;

  // Scroll controllers for table
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _topScrollbarController = ScrollController();
  
  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();
  
  // Column order and visibility model
  late List<ColumnConfig> _columnOrder;

  void _initializeColumnOrder() {
    _columnOrder = [
      ColumnConfig(key: 'status', label: 'Status', visible: true, index: 0),
      ColumnConfig(key: 'orderNo', label: 'Order No', visible: true, index: 1),
      ColumnConfig(key: 'invoice', label: 'Invoice', visible: true, index: 2),
      ColumnConfig(key: 'customer', label: 'Customer', visible: true, index: 3),
      ColumnConfig(key: 'customerNumber', label: 'Customer #', visible: true, index: 4),
      ColumnConfig(key: 'address', label: 'Address', visible: true, index: 5),
      ColumnConfig(key: 'scheduledDate', label: 'Scheduled Date', visible: true, index: 6),
      ColumnConfig(key: 'items', label: 'Items', visible: true, index: 7),
      ColumnConfig(key: 'daysToDeliver', label: 'Days to Deliver', visible: true, index: 8),
      ColumnConfig(key: 'driver', label: 'Driver', visible: true, index: 9),
      ColumnConfig(key: 'vehicle', label: 'Vehicle', visible: true, index: 10),
      ColumnConfig(key: 'actions', label: 'Actions', visible: true, index: 11),
    ];
  }

  bool _isColumnVisible(String key) {
    final config = _columnOrder.firstWhere((c) => c.key == key, orElse: () => ColumnConfig(key: key, label: key, visible: false, index: -1));
    return config.visible;
  }

  void _reorderColumns(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _columnOrder.removeAt(oldIndex);
      _columnOrder.insert(newIndex, item);
      // Update indices
      for (int i = 0; i < _columnOrder.length; i++) {
        _columnOrder[i] = _columnOrder[i].copyWith(index: i);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeColumnOrder();
    // Sync top scrollbar with main horizontal scrollbar smoothly
    _horizontalScrollController.addListener(() {
      if (_topScrollbarController.hasClients &&
          (_topScrollbarController.offset - _horizontalScrollController.offset).abs() > 1.0) {
        _topScrollbarController.jumpTo(_horizontalScrollController.offset);
      }
    });
    _topScrollbarController.addListener(() {
      if (_horizontalScrollController.hasClients &&
          (_horizontalScrollController.offset - _topScrollbarController.offset).abs() > 1.0) {
        _horizontalScrollController.jumpTo(_topScrollbarController.offset);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _topScrollbarController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+F - Focus search
      if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        _searchController.clear();
        Future.delayed(const Duration(milliseconds: 100), () {
          FocusScope.of(context).requestFocus(FocusNode());
        });
        return KeyEventResult.handled;
      }
      // Ctrl+N - New delivery
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyN) {
        _createNewDelivery();
        return KeyEventResult.handled;
      }
      // Ctrl+A - Select all (in multi-select mode)
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        if (_isMultiSelectMode) {
          setState(() {
            // This will be filled when we have deliveries loaded
          });
          return KeyEventResult.handled;
        }
      }
      // Esc - Clear selection/search
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          if (_isMultiSelectMode) {
            _isMultiSelectMode = false;
            _selectedDeliveryIds.clear();
          } else if (_searchQuery.isNotEmpty) {
            _searchController.clear();
            _searchQuery = '';
          }
        });
        return KeyEventResult.handled;
      }
      // F5 - Refresh
      else if (event.logicalKey == LogicalKeyboardKey.f5) {
        setState(() {});
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _createNewDelivery() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateDeliveryScreen(),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Delivery Management'),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Desktop',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            // Multi-select toggle
            IconButton(
              icon: Icon(_isMultiSelectMode ? Icons.check_box : Icons.check_box_outline_blank),
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = !_isMultiSelectMode;
                  if (!_isMultiSelectMode) {
                    _selectedDeliveryIds.clear();
                  }
                });
              },
              tooltip: 'Multi-select mode',
            ),
            // Filter sidebar toggle
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              tooltip: _showFilters ? 'Hide filters' : 'Show filters',
            ),
            // Preview panel toggle
            IconButton(
              icon: Icon(_showPreviewPanel ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _showPreviewPanel = !_showPreviewPanel;
                  if (!_showPreviewPanel) {
                    _previewDelivery = null;
                  }
                });
              },
              tooltip: _showPreviewPanel ? 'Hide preview panel' : 'Show preview panel',
            ),
            // Export menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'template') {
                  _downloadTemplate();
                } else if (value == 'export') {
                  await _exportDeliveries();
                } else if (value == 'bulk_upload') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BulkUploadScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'bulk_upload',
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Bulk Upload CSV'),
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
                      Text('Download Template'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, size: 20),
                      SizedBox(width: 8),
                      Text('Export All'),
                    ],
                  ),
                ),
              ],
            ),
            // Refresh
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {});
              },
              tooltip: 'Refresh (F5)',
            ),
            // Column visibility & reorder
            IconButton(
              icon: const Icon(Icons.view_column),
              tooltip: 'Show/Hide & Reorder Columns',
              onPressed: () => _showColumnReorderDialog(),
            ),
            // New delivery
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _createNewDelivery,
                icon: const Icon(Icons.add),
                label: const Text('New Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            // Filter sidebar
            if (_showFilters) ...[
              _buildFilterSidebar(),
              VerticalDivider(width: 1, color: Colors.grey[300]),
            ],
            // Main content
            Expanded(
              child: Column(
                children: [
                  // Statistics cards
                  _buildStatisticsCards(),
                  
                  // Quick filter bar (simplified)
                  _buildQuickFilterBar(),
                  
                  // Bulk action bar (when multi-select active)
                  if (_isMultiSelectMode && _selectedDeliveryIds.isNotEmpty)
                    _buildBulkActionBar(),
                  
                  // Main content area
                  Expanded(
                    child: Row(
                      children: [
                        // Data table
                        Expanded(
                          flex: _showPreviewPanel ? 6 : 1,
                          child: _buildDataTable(),
                        ),
                        // Preview panel
                        if (_showPreviewPanel) ...[
                          VerticalDivider(width: 1, color: Colors.grey[300]),
                          Expanded(
                            flex: 4,
                            child: _buildPreviewPanel(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Keyboard shortcuts help
                  _buildKeyboardShortcutsBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Container(
      padding: _statsExpanded 
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[50],
      child: Column(
        children: [
          // Header with toggle
          Row(
            children: [
              const Text(
                'Delivery Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _statsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _statsExpanded = !_statsExpanded;
                  });
                },
                tooltip: _statsExpanded ? 'Collapse statistics' : 'Expand statistics',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Statistics content
          if (_statsExpanded)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Deliveries',
                    _totalCount.toString(),
                    Icons.local_shipping,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    _pendingCount.toString(),
                    Icons.schedule,
                    AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'In Transit',
                    _inTransitCount.toString(),
                    Icons.local_shipping,
                    AppTheme.infoColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Delivered',
                    _deliveredCount.toString(),
                    Icons.check_circle,
                    AppTheme.successColor,
                  ),
                ),
              ],
            )
          else
            // Compact view
            Row(
              children: [
                _buildCompactStat('Total', _totalCount.toString(), Colors.blue),
                const SizedBox(width: 16),
                _buildCompactStat('Pending', _pendingCount.toString(), AppTheme.warningColor),
                const SizedBox(width: 16),
                _buildCompactStat('In Transit', _inTransitCount.toString(), AppTheme.infoColor),
                const SizedBox(width: 16),
                _buildCompactStat('Delivered', _deliveredCount.toString(), AppTheme.successColor),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
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
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Status filter dropdown (quick access)
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<DeliveryStatus?>(
              value: _statusFilter,
              decoration: InputDecoration(
                labelText: 'Status',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Statuses')),
                ...DeliveryStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(_getStatusText(status)),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _statusFilter = value;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          // Clear all filters
          if (_searchQuery.isNotEmpty || _statusFilter != null || _startDateFilter != null || _thirdPartyFilter != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statusFilter = null;
                  _startDateFilter = null;
                  _endDateFilter = null;
                  _thirdPartyFilter = null;
                });
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSidebar() {
    return Container(
      width: 280,
      color: Colors.grey[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Search
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search customer, address, invoice...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 24),
            // Status Filter
            const Text(
              'Delivery Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusFilterButton(null, 'All Statuses'),
            _buildStatusFilterButton(DeliveryStatus.pending, 'Pending'),
            _buildStatusFilterButton(DeliveryStatus.inTransit, 'In Transit'),
            _buildStatusFilterButton(DeliveryStatus.delivered, 'Delivered'),
            const SizedBox(height: 24),
            // Date Range
            const Text(
              'Date Range',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildCustomDateRangePicker(),
            const SizedBox(height: 24),
            // Driver Filter
            const Text(
              'Driver Assignment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildDriverFilterButton(null, 'All Drivers'),
            _buildDriverFilterButton('unassigned', 'Unassigned'),
            // TODO: Add specific driver filters when we have driver data
            const SizedBox(height: 24),
            // Transport Type Filter
            const Text(
              'Transport Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildThirdPartyFilterButton(null, 'All Transport'),
            _buildThirdPartyFilterButton(true, '3rd Party Only'),
            _buildThirdPartyFilterButton(false, 'Internal Only'),
            const SizedBox(height: 24),
            // Quick Filters
            const Text(
              'Quick Filters',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildQuickFilterChip('High Priority', Icons.priority_high),
            _buildQuickFilterChip('Overdue', Icons.warning),
            _buildQuickFilterChip('Has Items', Icons.inventory),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterButton(DeliveryStatus? status, String label) {
    final isSelected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _statusFilter = status);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue[900] : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverFilterButton(String? driverId, String label) {
    // For now, just handle unassigned vs all
    final isSelected = (driverId == null && _statusFilter == null) || (driverId == 'unassigned' && _statusFilter == DeliveryStatus.pending);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // TODO: Implement driver filtering
          setState(() {});
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue[900] : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThirdPartyFilterButton(bool? isThirdParty, String label) {
    final isSelected = _thirdPartyFilter == isThirdParty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _thirdPartyFilter = isThirdParty);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue[900] : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateRangePicker() {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _startDateFilter != null && _endDateFilter != null
              ? DateTimeRange(start: _startDateFilter!, end: _endDateFilter!)
              : null,
        );
        if (picked != null) {
          setState(() {
            _startDateFilter = picked.start;
            _endDateFilter = picked.end;
          });
        }
      },
      icon: const Icon(Icons.date_range, size: 18),
      label: Text(
        _startDateFilter != null && _endDateFilter != null
            ? '${DateFormat('MMM d').format(_startDateFilter!)} - ${DateFormat('MMM d, y').format(_endDateFilter!)}'
            : 'Select Date Range',
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // TODO: Implement quick filters
          setState(() {});
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[100]!),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Text(
            '${_selectedDeliveryIds.length} deliveries selected',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue[900],
            ),
          ),
          const Spacer(),
          // Bulk assign driver
          ElevatedButton.icon(
            onPressed: () => _bulkAssignDriver(),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Assign Driver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          // Bulk update status
          ElevatedButton.icon(
            onPressed: () => _bulkUpdateStatus(),
            icon: const Icon(Icons.update, size: 18),
            label: const Text('Update Status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          // Bulk export
          OutlinedButton.icon(
            onPressed: () => _bulkExport(),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export Selected'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          // Clear selection
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedDeliveryIds.clear();
              });
            },
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getDeliveriesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          
          // Handle permission errors specifically
          if (error is FirebaseException && error.code == 'permission-denied') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Permission Issue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Security rules are still updating. Please try again in a moment.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          // Generic error
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No deliveries yet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('Create your first delivery to get started'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createNewDelivery,
                  icon: const Icon(Icons.add),
                  label: const Text('New Delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // Parse and filter deliveries
        var deliveries = snapshot.data!.docs
            .map((doc) => Delivery.fromFirestore(doc))
            .toList();

        // Update statistics from ALL deliveries (before filtering)
        final totalCount = deliveries.length;
        final pendingCount = deliveries.where((d) => d.status == DeliveryStatus.pending).length;
        final inTransitCount = deliveries.where((d) => d.status == DeliveryStatus.inTransit).length;
        final deliveredCount = deliveries.where((d) => d.status == DeliveryStatus.delivered).length;
        
        // Update state variables after build if changed
        if (_totalCount != totalCount || _pendingCount != pendingCount || 
            _inTransitCount != inTransitCount || _deliveredCount != deliveredCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _totalCount = totalCount;
                _pendingCount = pendingCount;
                _inTransitCount = inTransitCount;
                _deliveredCount = deliveredCount;
              });
            }
          });
        }

        // Apply filters for display
        deliveries = _applyFilters(deliveries);

        if (deliveries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 16),
                Text(
                  'No matching deliveries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('Try adjusting your filters'),
              ],
            ),
          );
        }

        // Sort deliveries
        deliveries = _sortDeliveries(deliveries);

        return Column(
          children: [
            // Top scrollbar (always visible)
            Container(
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Scrollbar(
                controller: _topScrollbarController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _topScrollbarController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: _calculateTableWidth(),
                    height: 1,
                  ),
                ),
              ),
            ),
            // Main table with Shift+Scroll support
            Expanded(
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    // Check if Shift key is pressed
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      // Convert vertical scroll to horizontal with smooth scrolling
                      final delta = pointerSignal.scrollDelta.dy * 2.0; // Increase sensitivity
                      final newOffset = (_horizontalScrollController.offset + delta).clamp(
                        0.0,
                        _horizontalScrollController.position.maxScrollExtent,
                      );
                      _horizontalScrollController.animateTo(
                        newOffset,
                        duration: const Duration(milliseconds: 50),
                        curve: Curves.easeOut,
                      );
                    }
                  }
                },
                child: Scrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    scrollDirection: Axis.vertical,
                    physics: const ClampingScrollPhysics(),
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: DataTable(
                          columnSpacing: 16,
                          horizontalMargin: 12,
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          showCheckboxColumn: _isMultiSelectMode,
                          columns: [
                  DataColumn(
                    label: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                  ),
                  DataColumn(
                    label: const Text('Order No', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                  ),
                  if (_isColumnVisible('invoice'))
                    DataColumn(
                      label: const Text('Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                      onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                    ),
                  DataColumn(
                    label: const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                  ),
                  if (_isColumnVisible('customerNumber'))
                    const DataColumn(
                      label: Text('Customer #', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  if (_isColumnVisible('address'))
                    const DataColumn(
                      label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  DataColumn(
                    label: const Text('Scheduled Date', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
                  ),
                  if (_isColumnVisible('items'))
                    const DataColumn(
                      label: Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  if (_isColumnVisible('daysToDeliver'))
                    const DataColumn(
                      label: Text('Days to Deliver', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  if (_isColumnVisible('driver'))
                    const DataColumn(
                      label: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  const DataColumn(
                    label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const DataColumn(
                    label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                rows: deliveries.map((delivery) {
                  final isSelected = _selectedDeliveryIds.contains(delivery.id);
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: _isMultiSelectMode
                        ? (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedDeliveryIds.add(delivery.id);
                              } else {
                                _selectedDeliveryIds.remove(delivery.id);
                              }
                            });
                          }
                        : null,
                    cells: [
                      DataCell(
                        _buildStatusChip(delivery.status),
                        onTap: () => _selectDeliveryForPreview(delivery),
                      ),
                      DataCell(
                        Text(delivery.orderNumber ?? '-'),
                        onTap: () => _selectDeliveryForPreview(delivery),
                      ),
                      if (_isColumnVisible('invoice'))
                        DataCell(
                          Text(
                            delivery.invoiceNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectDeliveryForPreview(delivery),
                        ),
                      DataCell(
                        Text(
                          delivery.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectDeliveryForPreview(delivery),
                      ),
                      if (_isColumnVisible('customerNumber'))
                        DataCell(
                          Text(
                            delivery.customerNumber ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectDeliveryForPreview(delivery),
                        ),
                      if (_isColumnVisible('address'))
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              delivery.customerAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onTap: () => _selectDeliveryForPreview(delivery),
                        ),
                      DataCell(
                        Text(
                          DateFormat('MMM d, y').format(delivery.scheduledDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectDeliveryForPreview(delivery),
                      ),
                      if (_isColumnVisible('items'))
                        DataCell(
                          Text('${delivery.items.length}'),
                          onTap: () => _selectDeliveryForPreview(delivery),
                        ),
                      if (_isColumnVisible('daysToDeliver'))
                        DataCell(
                          _buildDaysToDeliverCell(delivery),
                          onTap: () => _selectDeliveryForPreview(delivery),
                        ),
                      if (_isColumnVisible('driver'))
                      DataCell(
                        delivery.isThirdPartyTransport
                            ? SizedBox(
                                width: 140,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.orange[300]!),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.local_shipping,
                                            size: 12,
                                            color: Colors.orange[700],
                                          ),
                                          const SizedBox(width: 2),
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              delivery.thirdPartyProviderName ?? 'Third-Party',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : FutureBuilder<String>(
                                future: _getDriverName(delivery.driverId),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? 'Loading...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                        onTap: () => _selectDeliveryForPreview(delivery),
                      ),
                      DataCell(
                        Text(
                          delivery.vehicleUsed ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectDeliveryForPreview(delivery),
                      ),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18),
                                onPressed: () => _viewDeliveryDetails(delivery),
                                tooltip: 'View details',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editDelivery(delivery),
                                tooltip: 'Edit',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                              if (delivery.status == DeliveryStatus.delivered)
                                IconButton(
                                  icon: const Icon(Icons.qr_code_2, size: 18),
                                  onPressed: () => _viewQRCode(delivery),
                                  tooltip: 'View QR Code',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
                                onPressed: () => _deleteDelivery(delivery),
                                tooltip: 'Delete',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ), // DataTable
            ), // SingleChildScrollView (horizontal)
            ), // Scrollbar (horizontal)
          ), // SingleChildScrollView (vertical)
        ), // Scrollbar (vertical)
              ), // Listener
            ), // Expanded
          ], // Column children
        ); // Column
      },
    );
  }

  Widget _buildStatusChip(DeliveryStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            _getStatusText(status),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysToDeliverCell(Delivery delivery) {
    // Require invoice date to calculate anything
    if (delivery.invoiceDate == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    // Prefer the real deliveredAt timestamp, but fall back to createdAt
    final DateTime endDate = delivery.deliveredAt ?? delivery.createdAt;

    final daysTaken = endDate.difference(delivery.invoiceDate!).inDays;

    // Color code based on performance
    Color textColor = Colors.green; // Good
    if (daysTaken > 5) {
      textColor = Colors.red; // Late
    } else if (daysTaken > 3) {
      textColor = Colors.orange; // Warning
    }

    final bool estimated = delivery.deliveredAt == null;
    final displayText = estimated ? '$daysTaken days (est)' : '$daysTaken days';

    return Text(
      displayText,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }

  Widget _buildPreviewPanel() {
    if (_previewDelivery == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Select a delivery',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Click on any row to preview details',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final delivery = _previewDelivery!;

    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (delivery.orderNumber != null)
                        Text(
                          'Order: ${delivery.orderNumber}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      Text(
                        'Invoice: ${delivery.invoiceNumber}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(delivery.status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showPreviewPanel = false;
                      _previewDelivery = null;
                    });
                  },
                  tooltip: 'Close preview',
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer details
                  _buildPreviewSection(
                    'Customer Information',
                    Icons.person,
                    [
                      _buildPreviewRow('Name', delivery.customerName),
                      _buildPreviewRow('Address', delivery.customerAddress),
                      if (delivery.customerPhone != null)
                        _buildPreviewRow('Phone', delivery.customerPhone!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Delivery details
                  _buildPreviewSection(
                    'Delivery Details',
                    Icons.local_shipping,
                    [
                      _buildPreviewRow(
                        'Scheduled',
                        DateFormat('EEEE, MMM d, y').format(delivery.scheduledDate),
                      ),
                      _buildPreviewRow(
                        'Created',
                        DateFormat('MMM d, y h:mm a').format(delivery.createdAt),
                      ),
                      if (delivery.deliveredAt != null)
                        _buildPreviewRow(
                          'Delivered',
                          DateFormat('MMM d, y h:mm a').format(delivery.deliveredAt!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Driver info
                  _buildPreviewSection(
                    'Driver',
                    Icons.person_pin,
                    [
                      FutureBuilder<Map<String, String>>(
                        future: _getDriverInfo(delivery.driverId),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Column(
                              children: [
                                _buildPreviewRow('Name', snapshot.data!['name'] ?? 'Unknown'),
                                _buildPreviewRow('Email', snapshot.data!['email'] ?? 'N/A'),
                              ],
                            );
                          }
                          return const CircularProgressIndicator();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Third-Party Transport Section
                  if (delivery.isThirdPartyTransport) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Third-Party Transport',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildPreviewRow('Provider', delivery.thirdPartyProviderName ?? 'N/A'),
                          if (delivery.thirdPartyDriverName != null)
                            _buildPreviewRow('Driver', delivery.thirdPartyDriverName!),
                          if (delivery.uploadToken != null) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.link, color: Colors.blue[700], size: 16),
                                const SizedBox(width: 4),
                                const Text(
                                  'Upload Link',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              'podsafe.app/upload/${delivery.uploadToken}',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                          if (delivery.thirdPartyDocs != null && delivery.thirdPartyDocs!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Docs Uploaded (${delivery.thirdPartyDocs!.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 60,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: delivery.thirdPartyDocs!.length > 3 
                                    ? 3 
                                    : delivery.thirdPartyDocs!.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 4),
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        delivery.thirdPartyDocs![index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(Icons.image, size: 24, color: Colors.grey[400]);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (delivery.thirdPartyDocs!.length > 3) ...[
                              const SizedBox(height: 4),
                              Text(
                                '+${delivery.thirdPartyDocs!.length - 3} more',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Vehicle info (only for own fleet)
                    if (delivery.vehicleUsed != null && delivery.vehicleUsed!.isNotEmpty)
                      _buildPreviewSection(
                        'Vehicle Used',
                        Icons.directions_car,
                        [
                          _buildPreviewRow('Registration/ID', delivery.vehicleUsed!),
                        ],
                      )
                    else
                      _buildPreviewSection(
                        'Vehicle Used',
                        Icons.directions_car,
                        [
                          _buildPreviewRow('Registration/ID', 'Not assigned'),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                  // Items
                  _buildPreviewSection(
                    'Items (${delivery.items.length})',
                    Icons.inventory_2,
                    delivery.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.quantity}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
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
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    item.unit ?? '',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  if (delivery.notes != null && delivery.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPreviewSection(
                      'Notes',
                      Icons.note,
                      [
                        Text(
                          delivery.notes!,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _viewDeliveryDetails(delivery),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Full Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editDelivery(delivery),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardShortcutsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          _buildShortcutChip('Ctrl+N', 'New'),
          _buildShortcutChip('Ctrl+F', 'Search'),
          _buildShortcutChip('Ctrl+A', 'Select All'),
          _buildShortcutChip('Esc', 'Clear'),
          _buildShortcutChip('F5', 'Refresh'),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Text(
              key,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // Helper methods
  List<Delivery> _applyFilters(List<Delivery> deliveries) {
    var filtered = deliveries;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((delivery) {
        return delivery.customerName.toLowerCase().contains(_searchQuery) ||
            delivery.customerAddress.toLowerCase().contains(_searchQuery) ||
            delivery.invoiceNumber.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Status filter
    if (_statusFilter != null) {
      filtered = filtered.where((d) => d.status == _statusFilter).toList();
    }

    // Date range filter
    if (_startDateFilter != null && _endDateFilter != null) {
      filtered = filtered.where((d) {
        return d.scheduledDate.isAfter(_startDateFilter!.subtract(const Duration(days: 1))) &&
            d.scheduledDate.isBefore(_endDateFilter!.add(const Duration(days: 1)));
      }).toList();
    }

    // 3rd party transport filter
    if (_thirdPartyFilter != null) {
      filtered = filtered.where((d) => d.isThirdPartyTransport == _thirdPartyFilter).toList();
    }

    return filtered;
  }

  List<Delivery> _sortDeliveries(List<Delivery> deliveries) {
    if (_sortColumnIndex == null) return deliveries;

    deliveries.sort((a, b) {
      int result = 0;
      switch (_sortColumnIndex) {
        case 0: // Status
          result = a.status.index.compareTo(b.status.index);
          break;
        case 1: // Order No
          result = (a.orderNumber ?? '').compareTo(b.orderNumber ?? '');
          break;
        case 2: // Invoice
          result = a.invoiceNumber.compareTo(b.invoiceNumber);
          break;
        case 3: // Customer
          result = a.customerName.compareTo(b.customerName);
          break;
        case 6: // Scheduled Date
          result = a.scheduledDate.compareTo(b.scheduledDate);
          break;
      }
      return _sortAscending ? result : -result;
    });

    return deliveries;
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Stream<QuerySnapshot> _getDeliveriesStream() {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId == null || companyId.isEmpty) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .orderBy('scheduledDate', descending: true)
        .snapshots();
  }

  void _selectDeliveryForPreview(Delivery delivery) {
    setState(() {
      _previewDelivery = delivery;
      _showPreviewPanel = true;
    });
  }

  Future<void> _viewDeliveryDetails(Delivery delivery) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryDetailsScreen(delivery: delivery),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _viewQRCode(Delivery delivery) async {
    try {
      final token = await PODTokenService().getTokenByDeliveryId(delivery.id);
      if (token != null && mounted) {
        await PODQRCodeDialog.show(context, token: token);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code is being generated. Please try again in a moment.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load QR code: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _editDelivery(Delivery delivery) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateDeliveryScreen(delivery: delivery),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _deleteDelivery(Delivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery'),
        content: Text('Are you sure you want to delete delivery for ${delivery.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(delivery.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery deleted successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        setState(() {
          if (_previewDelivery?.id == delivery.id) {
            _previewDelivery = null;
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<String> _getDriverName(String driverId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();
      return doc.data()?['fullName'] ?? doc.data()?['displayName'] ?? doc.data()?['name'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<Map<String, String>> _getDriverInfo(String driverId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();
      return {
        'name': doc.data()?['fullName'] ?? doc.data()?['displayName'] ?? doc.data()?['name'] ?? 'Unknown',
        'email': doc.data()?['email'] ?? 'N/A',
      };
    } catch (e) {
      return {'name': 'Unknown', 'email': 'N/A'};
    }
  }

  // Bulk actions
  Future<void> _bulkAssignDriver() async {
    // Get list of active drivers
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId == null) return;

    final driversSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'driver')
        .where('isActive', isEqualTo: true)
        .get();

    final drivers = driversSnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc.data()['name'] as String})
        .toList();

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active drivers available')),
      );
      return;
    }

    // Show driver selection dialog
    final selectedDriver = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Driver'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return ListTile(
                title: Text(driver['name']!),
                onTap: () => Navigator.pop(context, driver),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedDriver != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final deliveryId in _selectedDeliveryIds) {
          final ref = FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);
          batch.update(ref, {'driverId': selectedDriver['id']});
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assigned ${_selectedDeliveryIds.length} deliveries to ${selectedDriver['name']}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        setState(() {
          _selectedDeliveryIds.clear();
          _isMultiSelectMode = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _bulkUpdateStatus() async {
    final selectedStatus = await showDialog<DeliveryStatus>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DeliveryStatus.values.map((status) {
            return ListTile(
              leading: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
              title: Text(_getStatusText(status)),
              onTap: () => Navigator.pop(context, status),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedStatus != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final deliveryId in _selectedDeliveryIds) {
          final ref = FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);
          batch.update(ref, {
            'status': selectedStatus.toString().split('.').last,
          });
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated ${_selectedDeliveryIds.length} deliveries to ${_getStatusText(selectedStatus)}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        setState(() {
          _selectedDeliveryIds.clear();
          _isMultiSelectMode = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _bulkExport() async {
    try {
      // Get selected deliveries
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where(FieldPath.documentId, whereIn: _selectedDeliveryIds.toList())
          .get();

      if (deliveriesSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No deliveries selected'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      // Fetch driver names
      final driverIds = deliveriesSnapshot.docs
          .map((doc) => doc.data()['driverId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      final driverNames = <String, String>{};
      for (var driverId in driverIds) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .get();

        if (driverDoc.exists) {
          final data = driverDoc.data();
          driverNames[driverId!] = data?['displayName'] ?? data?['fullName'] ?? 'Unknown';
        }
      }

      // Convert to export format
      final exportData = deliveriesSnapshot.docs.map((doc) {
        final data = doc.data();
        final driverId = data['driverId'] as String?;
        return {
          'id': doc.id,
          'trackingNumber': data['trackingNumber'] ?? 'N/A',
          'customerName': data['customerName'] ?? 'N/A',
          'customerPhone': data['customerPhone'] ?? 'N/A',
          'address': data['address'] ?? 'N/A',
          'scheduledDate': data['scheduledDate'],
          'status': data['status'] ?? 'pending',
          'driverName': driverId != null ? driverNames[driverId] ?? 'Unassigned' : 'Unassigned',
          'notes': data['notes'] ?? '',
          'createdAt': data['createdAt'],
          'completedAt': data['completedAt'],
        };
      }).toList();

      // Export using service
      CSVExportService.exportDeliveries(
        deliveries: exportData,
        filterStatus: 'selected',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported ${exportData.length} selected deliveries'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return AppTheme.warningColor;
      case DeliveryStatus.inTransit:
        return AppTheme.infoColor;
      case DeliveryStatus.delivered:
        return AppTheme.successColor;
      case DeliveryStatus.failed:
        return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Icons.schedule;
      case DeliveryStatus.inTransit:
        return Icons.local_shipping;
      case DeliveryStatus.delivered:
        return Icons.check_circle;
      case DeliveryStatus.failed:
        return Icons.error;
    }
  }

  String _getStatusText(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.inTransit:
        return 'In Transit';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.failed:
        return 'Failed';
    }
  }

  void _downloadTemplate() {
    try {
      DeliveryExportService.downloadTemplate();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template downloaded successfully!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download template: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _exportDeliveries() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null || companyId.isEmpty) {
        throw Exception('Company ID not found');
      }

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Preparing export...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Fetch deliveries
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .get();

      if (deliveriesSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No deliveries to export'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      // Fetch driver names for all deliveries
      final driverIds = deliveriesSnapshot.docs
          .map((doc) => doc.data()['driverId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      final driverNames = <String, String>{};
      for (var driverId in driverIds) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .get();

        if (driverDoc.exists) {
          final data = driverDoc.data();
          driverNames[driverId!] = data?['displayName'] ?? data?['fullName'] ?? 'Unknown';
        }
      }

      // Convert to export format
      final exportData = deliveriesSnapshot.docs.map((doc) {
        final data = doc.data();
        final driverId = data['driverId'] as String?;
        return {
          'id': doc.id,
          'trackingNumber': data['trackingNumber'] ?? 'N/A',
          'customerName': data['customerName'] ?? 'N/A',
          'customerPhone': data['customerPhone'] ?? 'N/A',
          'address': data['address'] ?? 'N/A',
          'scheduledDate': data['scheduledDate'],
          'status': data['status'] ?? 'pending',
          'driverName': driverId != null ? driverNames[driverId] ?? 'Unassigned' : 'Unassigned',
          'notes': data['notes'] ?? '',
          'createdAt': data['createdAt'],
          'completedAt': data['completedAt'],
        };
      }).toList();

      // Apply filters
      var filteredData = exportData;
      if (_statusFilter != null) {
        filteredData = filteredData.where((d) => 
          d['status'] == _statusFilter.toString().split('.').last
        ).toList();
      }
      if (_searchQuery.isNotEmpty) {
        filteredData = filteredData.where((d) {
          final customer = (d['customerName'] as String).toLowerCase();
          final tracking = (d['trackingNumber'] as String).toLowerCase();
          final address = (d['address'] as String).toLowerCase();
          return customer.contains(_searchQuery.toLowerCase()) ||
                 tracking.contains(_searchQuery.toLowerCase()) ||
                 address.contains(_searchQuery.toLowerCase());
        }).toList();
      }

      // Export using service
      CSVExportService.exportDeliveries(
        deliveries: filteredData,
        filterStatus: _statusFilter?.toString().split('.').last,
        filterDate: _startDateFilter != null ? 'filtered' : null,
      );

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported ${filteredData.length} deliveries to CSV'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showColumnReorderDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reorder & Show/Hide Columns'),
          content: SizedBox(
            width: 400,
            child: ReorderableListView.builder(
              itemCount: _columnOrder.length,
              onReorder: (oldIndex, newIndex) {
                _reorderColumns(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final column = _columnOrder[index];
                // Skip certain columns from being reordered
                if (['status', 'orderNo', 'customer', 'vehicle', 'actions'].contains(column.key)) {
                  return ListTile(
                    key: ValueKey(column.key),
                    title: Text(column.label),
                    enabled: false,
                    tileColor: Colors.grey[100],
                    trailing: const Icon(Icons.lock, size: 16, color: Colors.grey),
                  );
                }
                return ListTile(
                  key: ValueKey(column.key),
                  title: Text(column.label),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      column.visible ? Icons.check_box : Icons.check_box_outline_blank,
                    ),
                    onPressed: () {
                      setState(() {
                        _columnOrder[index] = column.copyWith(visible: !column.visible);
                      });
                    },
                  ),
                );
              },
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
    );
  }

  double _calculateTableWidth() {
    // Calculate approximate table width based on visible columns
    double width = 0;
    
    width += 150; // Status column
    width += 120; // Order No column
    if (_isColumnVisible('invoice')) width += 120; // Invoice
    width += 180; // Customer column
    if (_isColumnVisible('customerNumber')) width += 120; // Customer #
    if (_isColumnVisible('address')) width += 250; // Address
    width += 150; // Scheduled Date
    if (_isColumnVisible('items')) width += 80; // Items
    if (_isColumnVisible('daysToDeliver')) width += 150; // Days to Deliver
    if (_isColumnVisible('driver')) width += 150; // Driver
    width += 120; // Vehicle
    width += 180; // Actions
    
    return width;
  }
}
