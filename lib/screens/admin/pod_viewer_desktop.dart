import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/bulk_pod_download_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/location_map_widget.dart';
import '../../utils/migrate_pod_data.dart';

class PODViewerDesktop extends StatefulWidget {
  const PODViewerDesktop({super.key});

  @override
  State<PODViewerDesktop> createState() => _PODViewerDesktopState();
}

class _PODViewerDesktopState extends State<PODViewerDesktop> {
  String _selectedFilter = 'all'; // all, today, week, month, custom
  String _searchQuery = '';
  String _viewMode = 'grid'; // grid, list, gallery
  bool _showFilters = true;
  bool _showDetailPanel = false;
  Map<String, dynamic>? _selectedPOD;
  
  // Date range for custom filter
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Multi-select mode
  bool _isMultiSelectMode = false;
  final Set<String> _selectedPODIds = {};
  
  // Sort
  String _sortBy = 'date'; // date, delivery, customer
  bool _sortAscending = false;
  
  // Stats
  int _totalCount = 0;
  int _todayCount = 0;
  int _withSignature = 0;
  int _withPhoto = 0;
  
  final FocusNode _focusNode = FocusNode();
  
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+F - Focus search
      if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        // Focus search field
        return KeyEventResult.handled;
      }
      // Ctrl+G - Switch to grid view
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyG) {
        setState(() => _viewMode = 'grid');
        return KeyEventResult.handled;
      }
      // Ctrl+L - Switch to list view
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyL) {
        setState(() => _viewMode = 'list');
        return KeyEventResult.handled;
      }
      // Ctrl+A - Select all
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        if (_isMultiSelectMode) {
          // Select all visible PODs
          _selectAllVisiblePODs();
          return KeyEventResult.handled;
        }
      }
      // Esc - Clear selection
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _selectedPODIds.clear();
          _isMultiSelectMode = false;
          _showDetailPanel = false;
        });
        return KeyEventResult.handled;
      }
      // F5 - Refresh
      else if (event.logicalKey == LogicalKeyboardKey.f5) {
        setState(() {}); // Triggers rebuild
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _updateStatistics(List<QueryDocumentSnapshot> pods) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    _totalCount = pods.length;
    _todayCount = 0;
    _withSignature = 0;
    _withPhoto = 0;
    
    for (var doc in pods) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      
      if (timestamp != null && timestamp.isAfter(today)) {
        _todayCount++;
      }
      
      if (data['signatureUrl'] != null) {
        _withSignature++;
      }
      
      if (data['photoUrl'] != null) {
        _withPhoto++;
      }
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
              const Text('POD Viewer'),
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
            // View mode toggles
            IconButton(
              icon: Icon(_viewMode == 'grid' ? Icons.grid_view : Icons.view_list),
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == 'grid' ? 'list' : 'grid';
                });
              },
              tooltip: 'Toggle view (Ctrl+G/L)',
            ),
            // Multi-select
            IconButton(
              icon: Icon(_isMultiSelectMode ? Icons.check_box : Icons.check_box_outline_blank),
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = !_isMultiSelectMode;
                  if (!_isMultiSelectMode) {
                    _selectedPODIds.clear();
                  }
                });
              },
              tooltip: 'Multi-select',
            ),
            // Toggle filters
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
              onPressed: () {
                setState(() => _showFilters = !_showFilters);
              },
              tooltip: 'Toggle filters',
            ),
            // Export
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showExportDialog,
              tooltip: 'Export',
            ),
            // Migration tool (debug)
            IconButton(
              icon: const Icon(Icons.build),
              onPressed: _runPODMigration,
              tooltip: 'Migrate POD Data',
            ),
            // Refresh
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {}); // Refresh data
              },
              tooltip: 'Refresh (F5)',
            ),
            const SizedBox(width: 8),
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
                  // Statistics bar
                  _buildStatisticsBar(),
                  Divider(height: 1, color: Colors.grey[300]),
                  // Bulk actions bar (if multi-select active)
                  if (_isMultiSelectMode && _selectedPODIds.isNotEmpty)
                    _buildBulkActionsBar(),
                  // POD content
                  Expanded(
                    child: Row(
                      children: [
                        // POD grid/list
                        Expanded(
                          child: _buildPODContent(),
                        ),
                        // Detail panel
                        if (_showDetailPanel && _selectedPOD != null) ...[
                          VerticalDivider(width: 1, color: Colors.grey[300]),
                          _buildDetailPanel(),
                        ],
                      ],
                    ),
                  ),
                  // Keyboard shortcuts bar
                  _buildKeyboardShortcutsBar(),
                ],
              ),
            ),
          ],
        ),
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
              decoration: const InputDecoration(
                hintText: 'Search deliveries...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
            const SizedBox(height: 24),
            // Time Period
            const Text(
              'Time Period',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildFilterButton('All Time', 'all'),
            _buildFilterButton('Today', 'today'),
            _buildFilterButton('This Week', 'week'),
            _buildFilterButton('This Month', 'month'),
            _buildFilterButton('Custom Range', 'custom'),
            if (_selectedFilter == 'custom') ...[
              const SizedBox(height: 16),
              _buildCustomDateRangePicker(),
            ],
            const SizedBox(height: 24),
            // Sort
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildSortButton('Date Submitted', 'date'),
            _buildSortButton('Delivery ID', 'delivery'),
            _buildSortButton('Customer Name', 'customer'),
            const SizedBox(height: 16),
            // Sort direction
            SwitchListTile(
              title: const Text('Ascending', style: TextStyle(fontSize: 13)),
              value: _sortAscending,
              onChanged: (value) {
                setState(() => _sortAscending = value);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            // Quick filters
            const Text(
              'Quick Filters',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildQuickFilterChip('Has Signature', Icons.draw),
            _buildQuickFilterChip('Has Photo', Icons.photo_camera),
            _buildQuickFilterChip('Has GPS', Icons.location_on),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = value;
            if (value != 'custom') {
              _startDate = null;
              _endDate = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateRangePicker() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: _startDate != null && _endDate != null
                  ? DateTimeRange(start: _startDate!, end: _endDate!)
                  : null,
            );
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
              });
            }
          },
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(
            _startDate != null && _endDate != null
                ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}'
                : 'Select Date Range',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (_startDate != null && _endDate != null)
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
            },
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _sortBy = value);
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

  Widget _buildQuickFilterChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Toggle quick filter
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

  Widget _buildStatisticsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total PODs',
              _totalCount.toString(),
              Icons.receipt_long,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Today',
              _todayCount.toString(),
              Icons.today,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'With Signature',
              _withSignature.toString(),
              Icons.draw,
              Colors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'With Photo',
              _withPhoto.toString(),
              Icons.photo_camera,
              Colors.orange,
            ),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_selectedPODIds.length} selected',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blue[900],
                  fontSize: 14,
                ),
              ),
              Text(
                'Ctrl+A to select all • Esc to clear',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Select All button
          TextButton.icon(
            onPressed: _selectAllVisiblePODs,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Select All'),
          ),
          const SizedBox(width: 8),
          // Deselect All button
          TextButton.icon(
            onPressed: () {
              setState(() => _selectedPODIds.clear());
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Deselect All'),
          ),
          const Spacer(),
          // Export options
          ElevatedButton.icon(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedPODIds.clear();
                _isMultiSelectMode = false;
              });
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildPODContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPODsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No PODs yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('Proof of deliveries will appear here'),
              ],
            ),
          );
        }

        final pods = snapshot.data!.docs;
        _updateStatistics(pods);

        // Apply filters
        final filteredPods = _applyFilters(pods);

        if (filteredPods.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No PODs match your filters'),
              ],
            ),
          );
        }

        return _viewMode == 'grid'
            ? _buildGridView(filteredPods)
            : _buildListView(filteredPods);
      },
    );
  }

  Stream<QuerySnapshot> _getPODsStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyId = authProvider.companyId;

    if (companyId == null) {
      // Return empty stream if no company ID
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('pods')
        .where('companyId', isEqualTo: companyId);

    // Apply date filters
    if (_selectedFilter != 'all') {
      final now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate;

      if (_selectedFilter == 'custom' && _startDate != null && _endDate != null) {
        startDate = _startDate;
        endDate = _endDate;
      } else {
        switch (_selectedFilter) {
          case 'today':
            startDate = DateTime(now.year, now.month, now.day);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            break;
          case 'week':
            startDate = now.subtract(const Duration(days: 7));
            endDate = now;
            break;
          case 'month':
            startDate = DateTime(now.year, now.month, 1);
            endDate = now;
            break;
        }
      }

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      
      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }
    }

    // Apply sorting
    query = query.orderBy('timestamp', descending: !_sortAscending);

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> pods) {
    if (_searchQuery.isEmpty) return pods;

    return pods.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final deliveryId = (data['deliveryId'] as String? ?? '').toLowerCase();
      final customerName = (data['customerName'] as String? ?? '').toLowerCase();
      final invoiceNumber = (data['invoiceNumber'] as String? ?? '').toLowerCase();
      
      return deliveryId.contains(_searchQuery) ||
             customerName.contains(_searchQuery) ||
             invoiceNumber.contains(_searchQuery);
    }).toList();
  }

  Widget _buildGridView(List<QueryDocumentSnapshot> pods) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: pods.length,
      itemBuilder: (context, index) {
        final pod = pods[index];
        final data = pod.data() as Map<String, dynamic>;
        return _buildPODGridCard(pod.id, data);
      },
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot> pods) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: pods.length,
      itemBuilder: (context, index) {
        final pod = pods[index];
        final data = pod.data() as Map<String, dynamic>;
        return _buildPODListCard(pod.id, data);
      },
    );
  }

  Widget _buildPODGridCard(String podId, Map<String, dynamic> data) {
    final isSelected = _selectedPODIds.contains(podId);
    final photoUrl = data['photoUrl'] as String?;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return InkWell(
      onTap: () {
        if (_isMultiSelectMode) {
          setState(() {
            if (isSelected) {
              _selectedPODIds.remove(podId);
            } else {
              _selectedPODIds.add(podId);
            }
          });
        } else {
          setState(() {
            _selectedPOD = data;
            _showDetailPanel = true;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[300]! : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            Stack(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: photoUrl != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: FirebaseStorageImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Center(
                          child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
                        ),
                ),
                if (_isMultiSelectMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPODIds.add(podId);
                            } else {
                              _selectedPODIds.remove(podId);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                // Status badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Delivered',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery #${(data['deliveryId'] as String? ?? '').substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['customerName'] as String? ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                  // Details chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (data['customerNumber'] != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cust',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  data['customerNumber'].toString(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (data['invoiceNumber'] != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inv',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  data['invoiceNumber'].toString(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (data['orderNumber'] != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  data['orderNumber'].toString(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          timestamp != null
                              ? DateFormat('MMM d, h:mm a').format(timestamp)
                              : 'Unknown',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Features
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      _buildFeatureIcon(
                        Icons.draw,
                        data['signatureUrl'] != null,
                      ),
                      _buildFeatureIcon(
                        Icons.photo_camera,
                        data['photoUrl'] != null,
                      ),
                      if (data['stampPhotoUrl'] != null)
                        _buildFeatureIcon(
                          Icons.receipt_long,
                          data['stampPhotoUrl'] != null,
                        ),
                      _buildFeatureIcon(
                        Icons.location_on,
                        data['location'] != null,
                      ),
                    ],
                  ),
                ],
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPODListCard(String podId, Map<String, dynamic> data) {
    final isSelected = _selectedPODIds.contains(podId);
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (_isMultiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedPODIds.remove(podId);
              } else {
                _selectedPODIds.add(podId);
              }
            });
          } else {
            setState(() {
              _selectedPOD = data;
              _showDetailPanel = true;
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.blue[300]! : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Checkbox
              if (_isMultiSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedPODIds.add(podId);
                      } else {
                        _selectedPODIds.remove(podId);
                      }
                    });
                  },
                ),
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery #${(data['deliveryId'] as String? ?? '').substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['customerName'] as String? ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Details row with customer, invoice, order
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (data['customerNumber'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'C: ${data['customerNumber']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (data['invoiceNumber'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'I: ${data['invoiceNumber']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (data['orderNumber'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'O: ${data['orderNumber']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildFeatureBadge(Icons.draw, data['signatureUrl'] != null),
                        _buildFeatureBadge(Icons.photo_camera, data['photoUrl'] != null),
                        if (data['stampPhotoUrl'] != null)
                          _buildFeatureBadge(Icons.receipt_long, data['stampPhotoUrl'] != null),
                        _buildFeatureBadge(Icons.location_on, data['location'] != null),
                      ],
                    ),
                  ],
                ),
              ),
              // Timestamp
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timestamp != null
                        ? DateFormat('MMM d, y').format(timestamp)
                        : 'Unknown',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    timestamp != null
                        ? DateFormat('h:mm a').format(timestamp)
                        : '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, bool hasFeature) {
    return Icon(
      icon,
      size: 16,
      color: hasFeature ? AppTheme.successColor : Colors.grey[300],
    );
  }

  Widget _buildFeatureBadge(IconData icon, bool hasFeature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasFeature ? AppTheme.successColor.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        size: 14,
        color: hasFeature ? AppTheme.successColor : Colors.grey[400],
      ),
    );
  }

  /// Select all visible PODs based on current filters
  void _selectAllVisiblePODs() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;

      if (companyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company ID not found'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Get all PODs matching current filters
      Query query = FirebaseFirestore.instance
          .collection('pods')
          .where('companyId', isEqualTo: companyId);

      // Apply date filters if set
      if (_selectedFilter != 'all') {
        final now = DateTime.now();
        DateTime? startDate;
        DateTime? endDate;

        if (_selectedFilter == 'custom' && _startDate != null && _endDate != null) {
          startDate = _startDate;
          endDate = _endDate;
        } else {
          switch (_selectedFilter) {
            case 'today':
              startDate = DateTime(now.year, now.month, now.day);
              endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
              break;
            case 'week':
              startDate = now.subtract(const Duration(days: 7));
              endDate = now;
              break;
            case 'month':
              startDate = DateTime(now.year, now.month, 1);
              endDate = now;
              break;
          }
        }

        if (startDate != null) {
          query = query.where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          );
        }

        if (endDate != null) {
          query = query.where(
            'timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          );
        }
      }

      final snapshot = await query.get();
      final allPODIds = snapshot.docs.map((doc) => doc.id).toList();

      setState(() {
        _selectedPODIds.addAll(allPODIds);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Selected ${allPODIds.length} POD${allPODIds.length == 1 ? '' : 's'}'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error selecting all PODs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildDetailPanel() {
    if (_selectedPOD == null) return const SizedBox.shrink();

    final data = _selectedPOD!;
    final photoUrl = data['photoUrl'] as String?;
    final stampPhotoUrl = data['stampPhotoUrl'] as String?; // Customer stamp photo
    final signatureUrl = data['signatureUrl'] as String?;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final location = data['location'] as Map<String, dynamic>?;

    return Container(
      width: 400,
      color: Colors.grey[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'POD Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _showDetailPanel = false);
                  },
                  tooltip: 'Close panel',
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Photo
            if (photoUrl != null) ...[
              const Text(
                'Delivery Photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FirebaseStorageImage(
                  imageUrl: photoUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Stamp Photo (Optional - for corporate customers)
            if (stampPhotoUrl != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: AppTheme.infoColor,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Customer Stamp',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Corporate Store Receipt',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.infoColor.withOpacity(0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FirebaseStorageImage(
                    imageUrl: stampPhotoUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 📄 NEW: Scanned Documents Section
            if (data['documentUrls'] != null && (data['documentUrls'] as List).isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.document_scanner,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Scanned Documents',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate((data['documentUrls'] as List).length, (index) {
                final List<String> documentUrls = List<String>.from(data['documentUrls'] as List);
                final List<Map<String, String>> documentMetadata = data['documentMetadata'] != null
                    ? (data['documentMetadata'] as List).map((e) => Map<String, String>.from(e)).toList()
                    : [];
                final docType = index < documentMetadata.length 
                    ? documentMetadata[index]['type'] ?? 'Document'
                    : 'Document';
                    
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0) const SizedBox(height: 12),
                    // Document type label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        docType,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FirebaseStorageImage(
                          imageUrl: documentUrls[index],
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 20),
            ],
            
            // Signature
            if (signatureUrl != null) ...[
              const Text(
                'Customer Signature',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FirebaseStorageImage(
                    imageUrl: signatureUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Details
            _buildDetailRow('Delivery ID', data['deliveryId'] ?? 'Unknown'),
            _buildDetailRow('Customer', data['customerName'] ?? 'Unknown'),
            _buildDetailRow('Receiver', data['receiverName'] ?? 'Not specified'),
            _buildDetailRow('Customer #', data['customerNumber'] ?? 'N/A'),
            _buildDetailRow('Order #', data['orderNumber'] ?? 'N/A'),
            _buildDetailRow('Invoice #', data['invoiceNumber'] ?? 'N/A'),
            if (timestamp != null)
              _buildDetailRow(
                'Completed',
                DateFormat('MMM d, y • h:mm a').format(timestamp),
              ),
            if (location != null) ...[
              const SizedBox(height: 12),
              const Text(
                'GPS Location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lat: ${location['latitude']?.toStringAsFixed(6) ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    Text(
                      'Lng: ${location['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    if (location['accuracy'] != null)
                      Text(
                        'Accuracy: ${location['accuracy']}m',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LocationMapWidget(
                latitude: location['latitude'] ?? 0.0,
                longitude: location['longitude'] ?? 0.0,
                accuracy: location['accuracy'] as double?,
                address: location['address'] as String?,
                height: 200,
                showAccuracyCircle: true,
              ),
            ],
            if (data['notes'] != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  data['notes'] as String,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // View full details in dialog
                  _showFullPODDialog();
                },
                icon: const Icon(Icons.open_in_full),
                label: const Text('View Full Details'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
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
          _buildShortcutChip('Ctrl+G', 'Grid View'),
          _buildShortcutChip('Ctrl+L', 'List View'),
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

  Future<void> _showExportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export PODs'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info about what will be exported
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Exporting ${_isMultiSelectMode ? _selectedPODIds.length : _totalCount} POD${_isMultiSelectMode && _selectedPODIds.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              
              // CSV Export
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Export to CSV'),
                subtitle: const Text('Data summary of all PODs'),
                onTap: () {
                  Navigator.pop(context);
                  _bulkExportPODsAsCSV();
                },
              ),
              
              // Bulk PDF Download
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Download as PDFs (ZIP)'),
                subtitle: const Text('Complete POD reports with all details'),
                onTap: () {
                  Navigator.pop(context);
                  _bulkDownloadPODsAsZip();
                },
              ),
              
              // Bulk Images Download
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Download Images (ZIP)'),
                subtitle: const Text('Photos & signatures'),
                onTap: () {
                  Navigator.pop(context);
                  _bulkDownloadPODImages();
                },
              ),
            ],
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
  }

  Future<void> _bulkExportPODsAsCSV() async {
    try {
      // Get company ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;

      if (companyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company ID not found'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Get PODs to export (selected or filtered)
      List<String> podIds;
      if (_isMultiSelectMode && _selectedPODIds.isNotEmpty) {
        podIds = _selectedPODIds.toList();
      } else {
        // Export all filtered PODs
        final snapshot = await FirebaseFirestore.instance
            .collection('pods')
            .where('companyId', isEqualTo: companyId)
            .get();
        
        if (snapshot.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No PODs to export'),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          }
          return;
        }
        
        podIds = snapshot.docs.map((doc) => doc.id).toList();
      }

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Exporting PODs to CSV...'),
                  const SizedBox(height: 8),
                  Text(
                    'Processing...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Export using bulk service
      await BulkPODDownloadService.exportPODsAsCSV(
        podIds: podIds,
        companyId: companyId,
        onProgress: (progress) {
          debugPrint('Export progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported ${podIds.length} PODs to CSV'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PODs: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      debugPrint('❌ Error in _bulkExportPODsAsCSV: $e');
    }
  }

  Future<void> _bulkDownloadPODsAsZip() async {
    try {
      // Get company ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;

      if (companyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company ID not found'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Get PODs to download (selected or filtered)
      List<String> podIds;
      if (_isMultiSelectMode && _selectedPODIds.isNotEmpty) {
        podIds = _selectedPODIds.toList();
      } else {
        // Download all filtered PODs
        final snapshot = await FirebaseFirestore.instance
            .collection('pods')
            .where('companyId', isEqualTo: companyId)
            .get();
        
        if (snapshot.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No PODs to download'),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          }
          return;
        }
        
        podIds = snapshot.docs.map((doc) => doc.id).toList();
      }

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Generating POD PDFs...'),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: ValueNotifier(0.0),
                    builder: (context, progress, _) {
                      return Text(
                        '${(progress * 100).toStringAsFixed(0)}% complete',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Download using bulk service
      await BulkPODDownloadService.downloadPODsAsZip(
        podIds: podIds,
        companyId: companyId,
        onProgress: (progress) {
          debugPrint('Download progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Downloaded ${podIds.length} POD reports as PDF'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PODs: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      debugPrint('❌ Error in _bulkDownloadPODsAsZip: $e');
    }
  }

  Future<void> _bulkDownloadPODImages() async {
    try {
      // Get company ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;

      if (companyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company ID not found'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Get PODs to download (selected or filtered)
      List<String> podIds;
      if (_isMultiSelectMode && _selectedPODIds.isNotEmpty) {
        podIds = _selectedPODIds.toList();
      } else {
        // Download images for all filtered PODs
        final snapshot = await FirebaseFirestore.instance
            .collection('pods')
            .where('companyId', isEqualTo: companyId)
            .get();
        
        if (snapshot.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No PODs to download'),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          }
          return;
        }
        
        podIds = snapshot.docs.map((doc) => doc.id).toList();
      }

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Downloading POD images...'),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: ValueNotifier(0.0),
                    builder: (context, progress, _) {
                      return Text(
                        '${(progress * 100).toStringAsFixed(0)}% complete',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Download images using bulk service
      await BulkPODDownloadService.downloadPODImagesAsZip(
        podIds: podIds,
        companyId: companyId,
        onProgress: (progress) {
          debugPrint('Image download progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Downloaded images from ${podIds.length} PODs'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading images: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      debugPrint('❌ Error in _bulkDownloadPODImages: $e');
    }
  }

  void _showFullPODDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Full POD Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Delivery Photo
                      if (_selectedPOD!['photoUrl'] != null) ...[
                        const Text(
                          'Delivery Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FirebaseStorageImage(
                              imageUrl: _selectedPOD!['photoUrl'],
                              height: 350,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Customer Stamp (Optional)
                      if (_selectedPOD!['stampPhotoUrl'] != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 18,
                              color: AppTheme.infoColor,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Customer Stamp',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Corporate Store Receipt Stamp',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor.withOpacity(0.05),
                            border: Border.all(
                              color: AppTheme.infoColor.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FirebaseStorageImage(
                              imageUrl: _selectedPOD!['stampPhotoUrl'],
                              height: 350,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Customer Signature
                      if (_selectedPOD!['signatureUrl'] != null) ...[
                        const Text(
                          'Customer Signature',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FirebaseStorageImage(
                            imageUrl: _selectedPOD!['signatureUrl'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // POD Details
                      const Text(
                        'Delivery Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDetailRow('Delivery ID', _selectedPOD!['deliveryId'] ?? 'N/A'),
                      _buildDialogDetailRow('Customer', _selectedPOD!['customerName'] ?? 'N/A'),
                      _buildDialogDetailRow('Receiver', _selectedPOD!['receiverName'] ?? 'Not specified'),
                      _buildDialogDetailRow('Customer #', _selectedPOD!['customerNumber'] ?? 'N/A'),
                      _buildDialogDetailRow('Order #', _selectedPOD!['orderNumber'] ?? 'N/A'),
                      _buildDialogDetailRow('Invoice #', _selectedPOD!['invoiceNumber'] ?? 'N/A'),
                      if (_selectedPOD!['timestamp'] != null)
                        _buildDialogDetailRow(
                          'Completed',
                          DateFormat('EEEE, MMMM d, y • h:mm a').format(
                            (_selectedPOD!['timestamp'] as Timestamp).toDate(),
                          ),
                        ),
                      if (_selectedPOD!['notes'] != null && (_selectedPOD!['notes'] as String).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Delivery Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(_selectedPOD!['notes']),
                        ),
                      ],
                      if (_selectedPOD!['location'] != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'GPS Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDialogDetailRow(
                          'Latitude',
                          _selectedPOD!['location']['latitude']?.toString() ?? 'N/A',
                        ),
                        _buildDialogDetailRow(
                          'Longitude',
                          _selectedPOD!['location']['longitude']?.toString() ?? 'N/A',
                        ),
                        _buildDialogDetailRow(
                          'Accuracy',
                          '${_selectedPOD!['location']['accuracy']?.toStringAsFixed(1) ?? 'N/A'} meters',
                        ),
                        const SizedBox(height: 12),
                        LocationMapWidget(
                          latitude: _selectedPOD!['location']['latitude'] ?? 0.0,
                          longitude: _selectedPOD!['location']['longitude'] ?? 0.0,
                          accuracy: _selectedPOD!['location']['accuracy'] as double?,
                          address: _selectedPOD!['location']['address'] as String?,
                          height: 300,
                          showAccuracyCircle: true,
                        ),
                      ],
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

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runPODMigration() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migrate POD Data'),
        content: const Text(
          'This will update all existing POD documents with delivery information '
          '(customer name, invoice number, etc.).\n\n'
          'This is safe to run multiple times and will skip PODs that already have the data.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Migrate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
            Text('Migrating POD data...'),
          ],
        ),
      ),
    );

    try {
      // Run migration
      await migratePODData();

      if (!mounted) return;

      // Close progress dialog
      Navigator.pop(context);

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Migration Complete'),
          content: const Text(
            'POD data has been successfully updated.\n\n'
            'Check the console for detailed migration results.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {}); // Refresh the list
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Close progress dialog
      Navigator.pop(context);

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Migration Failed'),
          content: Text(
            'An error occurred during migration:\n\n$e',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
