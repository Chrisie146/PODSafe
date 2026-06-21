import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/csv_export_service.dart';
import 'driver_details_screen.dart';
import 'create_driver_screen.dart';

class DriverManagementDesktop extends StatefulWidget {
  const DriverManagementDesktop({super.key});

  @override
  State<DriverManagementDesktop> createState() => _DriverManagementDesktopState();
}

class _DriverManagementDesktopState extends State<DriverManagementDesktop> {
  // Filter & Search
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, approved, pending, rejected
  String _sortBy = 'name'; // name, email, date, deliveries
  bool _sortAscending = true;
  
  // View State
  bool _showFilters = true;
  bool _showDetailPanel = false;
  Map<String, dynamic>? _selectedDriver;
  String? _selectedDriverId;
  
  // Multi-select
  bool _isMultiSelectMode = false;
  Set<String> _selectedDriverIds = {};
  
  // Statistics
  int _totalDrivers = 0;
  int _approvedDrivers = 0;
  int _pendingDrivers = 0;
  int _rejectedDrivers = 0;
  int _activeToday = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+F - Focus search
      if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
        return KeyEventResult.handled;
      }
      // Ctrl+A - Select all
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        if (_isMultiSelectMode) {
          // Will select all visible drivers
          setState(() {});
          return KeyEventResult.handled;
        }
      }
      // Esc - Clear selection
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _selectedDriverIds.clear();
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

  void _updateStatistics(List<QueryDocumentSnapshot> drivers) {
    _totalDrivers = drivers.length;
    _approvedDrivers = 0;
    _pendingDrivers = 0;
    _rejectedDrivers = 0;
    _activeToday = 0;
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    for (var doc in drivers) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['approvalStatus'] ?? 'approved';
      
      if (status == 'approved') {
        _approvedDrivers++;
      } else if (status == 'pending') _pendingDrivers++;
      else if (status == 'rejected') _rejectedDrivers++;
      
      // Check if driver was active today (has deliveries today)
      final lastActivity = (data['lastActivityAt'] as Timestamp?)?.toDate();
      if (lastActivity != null && lastActivity.isAfter(todayStart)) {
        _activeToday++;
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
              const Text('Driver Management'),
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
                    _selectedDriverIds.clear();
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
            // Add driver
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateDriverScreen(),
                  ),
                );
                if (result == true && mounted) {
                  setState(() {}); // Refresh list
                }
              },
              tooltip: 'Add Driver',
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
                  if (_isMultiSelectMode && _selectedDriverIds.isNotEmpty)
                    _buildBulkActionsBar(),
                  // Driver table
                  Expanded(
                    child: Row(
                      children: [
                        // Driver list/table
                        Expanded(
                          child: _buildDriverTable(),
                        ),
                        // Detail panel
                        if (_showDetailPanel && _selectedDriver != null) ...[
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
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search drivers...',
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
            // Status Filter
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusFilterChip('all', 'All Drivers'),
            const SizedBox(height: 8),
            _buildStatusFilterChip('approved', 'Approved'),
            const SizedBox(height: 8),
            _buildStatusFilterChip('pending', 'Pending'),
            const SizedBox(height: 8),
            _buildStatusFilterChip('rejected', 'Rejected'),
            const SizedBox(height: 24),
            // Sort Options
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildSortOption('name', 'Name'),
            const SizedBox(height: 8),
            _buildSortOption('email', 'Email'),
            const SizedBox(height: 8),
            _buildSortOption('date', 'Registration Date'),
            const SizedBox(height: 24),
            // Sort Direction
            SwitchListTile(
              title: const Text(
                'Ascending',
                style: TextStyle(fontSize: 14),
              ),
              value: _sortAscending,
              onChanged: (value) {
                setState(() => _sortAscending = value);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            // Clear Filters
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                    _statusFilter = 'all';
                    _sortBy = 'name';
                    _sortAscending = true;
                  });
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _statusFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
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
    );
  }

  Widget _buildSortOption(String value, String label) {
    final isSelected = _sortBy == value;
    return InkWell(
      onTap: () {
        setState(() => _sortBy = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
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
              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
          _buildStatCard(
            'Total Drivers',
            _totalDrivers.toString(),
            Icons.people,
            AppTheme.primaryColor,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Approved',
            _approvedDrivers.toString(),
            Icons.check_circle,
            AppTheme.successColor,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Pending',
            _pendingDrivers.toString(),
            Icons.hourglass_empty,
            AppTheme.warningColor,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Rejected',
            _rejectedDrivers.toString(),
            Icons.cancel,
            AppTheme.errorColor,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Active Today',
            _activeToday.toString(),
            Icons.local_shipping,
            Colors.blue,
          ),
          const Spacer(),
          // Export button
          ElevatedButton.icon(
            onPressed: _exportFilteredDrivers,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export to CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedDriverIds.length} driver(s) selected',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: OutlinedButton.icon(
              onPressed: _bulkApprove,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Approve'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.successColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: OutlinedButton.icon(
              onPressed: _bulkReject,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDriverIds.clear();
                  _isMultiSelectMode = false;
                });
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTable() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return const Center(
        child: Text('No company selected'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getDriversStream(companyId),
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
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No drivers found',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click + to add a new driver',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        var drivers = snapshot.data!.docs;
        _updateStatistics(drivers);
        
        // Apply filters
        drivers = _applyFilters(drivers);

        if (drivers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 16),
                Text(
                  'No matching drivers',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isMultiSelectMode)
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: _selectedDriverIds.length == drivers.length,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedDriverIds = drivers.map((d) => d.id).toSet();
                                } else {
                                  _selectedDriverIds.clear();
                                }
                              });
                            },
                          ),
                        ),
                      const SizedBox(
                        width: 60,
                        child: Text(
                          'Avatar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'NAME',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'EMAIL',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'PHONE',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'STATUS',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'REGISTERED',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 100,
                        child: Text(
                          'ACTIONS',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table rows
                ...drivers.map((doc) => _buildDriverRow(doc)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriverRow(QueryDocumentSnapshot doc) {
    final driverId = doc.id;
    final data = doc.data() as Map<String, dynamic>;
    final displayName = data['displayName'] ?? data['fullName'] ?? 'Unknown Driver';
    final email = data['email'] ?? 'No email';
    final phone = data['phoneNumber'] as String?;
    final approvalStatus = data['approvalStatus'] ?? 'approved';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    
    final isSelected = _selectedDriverIds.contains(driverId);
    final isCurrentSelection = _selectedDriverId == driverId;

    Color statusColor;
    IconData statusIcon;
    switch (approvalStatus) {
      case 'approved':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'rejected':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return InkWell(
      onTap: () {
        if (_isMultiSelectMode) {
          setState(() {
            if (isSelected) {
              _selectedDriverIds.remove(driverId);
            } else {
              _selectedDriverIds.add(driverId);
            }
          });
        } else {
          setState(() {
            _selectedDriver = data;
            _selectedDriverId = driverId;
            _showDetailPanel = true;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentSelection
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            if (_isMultiSelectMode)
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedDriverIds.add(driverId);
                      } else {
                        _selectedDriverIds.remove(driverId);
                      }
                    });
                  },
                ),
              ),
            SizedBox(
              width: 60,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.1),
                child: Text(
                  _getInitials(displayName),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                email,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                phone ?? '-',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        approvalStatus.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Text(
                createdAt != null ? _formatDate(createdAt) : '-',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            SizedBox(
              width: 100,
              child: Row(
                children: [
                  if (approvalStatus == 'pending') ...[
                    IconButton(
                      icon: const Icon(Icons.check, size: 20),
                      color: AppTheme.successColor,
                      onPressed: () => _approveDriver(driverId, displayName),
                      tooltip: 'Approve',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppTheme.errorColor,
                      onPressed: () => _rejectDriver(driverId, displayName),
                      tooltip: 'Reject',
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DriverDetailsScreen(
                              driverId: driverId,
                              driverData: data,
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          setState(() {});
                        }
                      },
                      tooltip: 'View Details',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (_selectedDriver == null) return const SizedBox.shrink();

    final displayName = _selectedDriver!['displayName'] ?? 
                        _selectedDriver!['fullName'] ?? 'Unknown Driver';
    final email = _selectedDriver!['email'] ?? 'No email';
    final phone = _selectedDriver!['phoneNumber'] as String?;
    final approvalStatus = _selectedDriver!['approvalStatus'] ?? 'approved';
    final licenseNumber = _selectedDriver!['licenseNumber'] as String?;
    final vehicleInfo = _selectedDriver!['vehicleInfo'] as String?;
    final createdAt = (_selectedDriver!['createdAt'] as Timestamp?)?.toDate();
    final isActive = _selectedDriver!['isActive'] ?? false;

    Color statusColor;
    IconData statusIcon;
    switch (approvalStatus) {
      case 'approved':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'rejected':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      width: 400,
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
                const Text(
                  'Driver Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _showDetailPanel = false;
                      _selectedDriver = null;
                      _selectedDriverId = null;
                    });
                  },
                  tooltip: 'Close',
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
                  // Avatar & Name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Text(
                            _getInitials(displayName),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                approvalStatus.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Contact Information
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.email, 'Email', email),
                  if (phone != null) _buildDetailRow(Icons.phone, 'Phone', phone),
                  const SizedBox(height: 24),
                  // Driver Information
                  const Text(
                    'Driver Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (licenseNumber != null)
                    _buildDetailRow(Icons.badge, 'License Number', licenseNumber),
                  if (vehicleInfo != null)
                    _buildDetailRow(Icons.directions_car, 'Vehicle', vehicleInfo),
                  _buildDetailRow(
                    Icons.toggle_on,
                    'Status',
                    isActive ? 'Active' : 'Inactive',
                  ),
                  if (createdAt != null)
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Registered',
                      DateFormat('MMM d, y').format(createdAt),
                    ),
                  const SizedBox(height: 24),
                  // Actions
                  if (approvalStatus == 'pending') ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _approveDriver(_selectedDriverId!, displayName),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve Driver'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectDriver(_selectedDriverId!, displayName),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject Driver'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverDetailsScreen(
                                driverId: _selectedDriverId!,
                                driverData: _selectedDriver!,
                              ),
                            ),
                          );
                          if (result == true && mounted) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View Full Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
          _buildShortcutChip('Ctrl+F', 'Search'),
          const SizedBox(width: 12),
          _buildShortcutChip('Ctrl+A', 'Select All'),
          const SizedBox(width: 12),
          _buildShortcutChip('Esc', 'Clear'),
          const SizedBox(width: 12),
          _buildShortcutChip('F5', 'Refresh'),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String key, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            key,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getDriversStream(String companyId) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Export filtered drivers to CSV
  Future<void> _exportFilteredDrivers() async {
    try {
      final companyId = context.read<app_auth.AuthProvider>().currentUser?.companyId;
      if (companyId == null) return;

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

      // Fetch all drivers and apply filters
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('companyId', isEqualTo: companyId)
          .get();

      var drivers = _applyFilters(snapshot.docs);

      // Convert to export format
      final exportData = drivers.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          'name': data['displayName'] ?? data['fullName'] ?? 'N/A',
          'email': data['email'] ?? 'N/A',
          'phone': data['phoneNumber'] ?? 'N/A',
          'approvalStatus': data['approvalStatus'] ?? 'pending',
          'createdAt': data['createdAt'],
          'lastActive': data['lastActive'],
          'totalDeliveries': data['totalDeliveries'] ?? 0,
          'approvedBy': data['approvedBy'] ?? 'N/A',
        };
      }).toList();

      // Export using service
      CSVExportService.exportDrivers(
        drivers: exportData,
        filterStatus: _statusFilter != 'all' ? _statusFilter : null,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported ${exportData.length} driver(s) to CSV'),
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
            content: Text('Error exporting drivers: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> drivers) {
    var filtered = drivers;

    // Status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['approvalStatus'] == _statusFilter;
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['displayName'] ?? data['fullName'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final phone = (data['phoneNumber'] ?? '').toString().toLowerCase();
        
        return name.contains(_searchQuery) || 
               email.contains(_searchQuery) || 
               phone.contains(_searchQuery);
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          final aName = (aData['displayName'] ?? aData['fullName'] ?? '').toString();
          final bName = (bData['displayName'] ?? bData['fullName'] ?? '').toString();
          comparison = aName.compareTo(bName);
          break;
        case 'email':
          final aEmail = (aData['email'] ?? '').toString();
          final bEmail = (bData['email'] ?? '').toString();
          comparison = aEmail.compareTo(bEmail);
          break;
        case 'date':
          final aDate = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bDate = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          comparison = aDate.compareTo(bDate);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  Future<void> _approveDriver(String driverId, String driverName) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance.collection('users').doc(driverId).update({
        'approvalStatus': 'approved',
        'isActive': true,
        'approvedBy': currentUser.uid,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('$driverName has been approved'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() {}); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving driver: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _rejectDriver(String driverId, String driverName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Driver'),
        content: Text('Are you sure you want to reject $driverName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance.collection('users').doc(driverId).update({
        'approvalStatus': 'rejected',
        'isActive': false,
        'approvedBy': currentUser.uid,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 12),
                Text('$driverName has been rejected'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() {}); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting driver: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _bulkApprove() async {
    final count = _selectedDriverIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Drivers'),
        content: Text('Are you sure you want to approve $count driver(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final driverId in _selectedDriverIds) {
        final ref = FirebaseFirestore.instance.collection('users').doc(driverId);
        batch.update(ref, {
          'approvalStatus': 'approved',
          'isActive': true,
          'approvedBy': currentUser.uid,
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count driver(s) approved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() {
          _selectedDriverIds.clear();
          _isMultiSelectMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving drivers: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _bulkReject() async {
    final count = _selectedDriverIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Drivers'),
        content: Text('Are you sure you want to reject $count driver(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final driverId in _selectedDriverIds) {
        final ref = FirebaseFirestore.instance.collection('users').doc(driverId);
        batch.update(ref, {
          'approvalStatus': 'rejected',
          'isActive': false,
          'approvedBy': currentUser.uid,
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count driver(s) rejected successfully'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        setState(() {
          _selectedDriverIds.clear();
          _isMultiSelectMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting drivers: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
