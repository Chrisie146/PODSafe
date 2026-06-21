import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/claim_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../services/bulk_claims_pdf_service.dart';
import 'claim_details_screen.dart';
import 'create_claim_form.dart';
import 'upload_evidence_form.dart';

/// Desktop-optimized Claims Dashboard with master-detail layout
/// Features: Side-by-side view, keyboard shortcuts, data table, bulk actions
class ClaimsDashboardDesktop extends StatefulWidget {
  const ClaimsDashboardDesktop({super.key});

  @override
  State<ClaimsDashboardDesktop> createState() => _ClaimsDashboardDesktopState();
}

class _ClaimsDashboardDesktopState extends State<ClaimsDashboardDesktop> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  
  // Advanced filter controllers
  final _customerNumberController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _orderNumberController = TextEditingController();
  
  ClaimStatus? _selectedStatus;
  ClaimType? _selectedType;
  DateTimeRange? _dateRange;
  final String _sortBy = 'date';
  final bool _sortAscending = false;
  
  // Column visibility toggles
  final bool _showClaimId = true;
  final bool _showType = true;
  final bool _showStatus = true;
  final bool _showCustomer = true;
  final bool _showDriver = true;
  final bool _showAmount = true;
  final bool _showDate = true;
  final bool _showActions = true;
  
  Claim? _selectedClaim;
  final Set<String> _selectedClaimIds = {};
  bool _isMultiSelectMode = false;

  // Filter sidebar & statistics state
  bool _showFilterSidebar = true;
  bool _statsExpanded = true;
  int _totalClaims = 0;
  int _submittedClaims = 0;
  int _pendingClaims = 0;
  int _approvedClaims = 0;
  int _rejectedClaims = 0;
  double _totalAmountClaimed = 0;
  double _averageClaimValue = 0;

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClaims();
    });
  }

  Future<void> _loadClaims() async {
    final authProvider = context.read<AuthProvider>();
    final claimProvider = context.read<ClaimProvider>();

    // Initialize provider if needed
    if (claimProvider.companyId == null) {
      await claimProvider.initialize(authProvider.companyId!);
    }

    // Debug: Log company ID
    print('[ClaimsDashboardDesktop] Loading claims for companyId: ${authProvider.companyId}');

    // Load all company claims (no driver filter for admin)
    await claimProvider.loadAllClaims();
    
    // Update statistics
    _updateStatistics(claimProvider);
  }

  void _updateStatistics(ClaimProvider provider) {
    setState(() {
      final claims = provider.allClaims;
      _totalClaims = claims.length;
      _submittedClaims = claims.where((c) => c.status == ClaimStatus.submitted).length;
      _pendingClaims = claims.where((c) => c.status == ClaimStatus.pendingReview).length;
      _approvedClaims = claims.where((c) => c.status == ClaimStatus.approved).length;
      _rejectedClaims = claims.where((c) => c.status == ClaimStatus.rejected).length;
      
      _totalAmountClaimed = claims.fold(0.0, (sum, c) => sum + (c.claimAmount ?? 0.0));
      _averageClaimValue = _totalClaims > 0 ? _totalAmountClaimed / _totalClaims : 0;
    });
  }

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _customerNumberController.dispose();
    _customerNameController.dispose();
    _invoiceNumberController.dispose();
    _orderNumberController.dispose();
    _keyboardFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Helper function to format currency amounts with comma separators
  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_ZA');
    return formatter.format(amount);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+F - Focus search
      if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        _searchFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      // Esc - Clear selection / Exit multi-select
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _selectedClaimIds.clear();
          _isMultiSelectMode = false;
          _selectedClaim = null;
        });
        return KeyEventResult.handled;
      }
      // Ctrl+A - Select all visible claims
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        final provider = context.read<ClaimProvider>();
        setState(() {
          _isMultiSelectMode = true;
          _selectedClaimIds.addAll(provider.claims.map((c) => c.id));
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Claims Management'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            if (_selectedClaimIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Chip(
                  label: Text(
                    '${_selectedClaimIds.length} selected',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.white24,
                  deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
                  onDeleted: () {
                    setState(() {
                      _selectedClaimIds.clear();
                      _isMultiSelectMode = false;
                    });
                  },
                ),
              ),
            if (_selectedClaimIds.length > 1) ...[
              IconButton(
                icon: const Icon(Icons.check_circle),
                tooltip: 'Bulk Approve',
                onPressed: _bulkApprove,
              ),
              IconButton(
                icon: const Icon(Icons.cancel),
                tooltip: 'Bulk Reject',
                onPressed: _bulkReject,
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: Icon(_showFilterSidebar ? Icons.filter_list : Icons.filter_list_off),
              tooltip: _showFilterSidebar ? 'Hide Filters' : 'Show Filters',
              onPressed: () {
                setState(() {
                  _showFilterSidebar = !_showFilterSidebar;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh (F5)',
              onPressed: () {
                context.read<ClaimProvider>().loadAllClaims();
              },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export claims',
              onPressed: _showExportDialog,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Tab bar
            Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All Claims'),
                  Tab(text: 'Create Claim'),
                  Tab(text: 'Upload Evidence'),
                ],
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: All Claims (existing table)
                  _buildAllClaimsTab(),
                  // Tab 2: Create Claim
                  const CreateClaimForm(),
                  // Tab 3: Upload Evidence
                  const UploadEvidenceForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllClaimsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final showDetailPanel = screenWidth > 1200 && _selectedClaim != null;

    return Row(
      children: [
        // Left filter sidebar
        if (_showFilterSidebar) ...[
          _buildFilterSidebar(),
          VerticalDivider(width: 1, color: Colors.grey[300]),
        ],
        // Main content area
        Expanded(
          flex: showDetailPanel ? 2 : 3,
          child: Column(
            children: [
              _buildCompactTopBar(),
              Expanded(child: _buildClaimsTable()),
              _buildKeyboardShortcutsBar(),
            ],
          ),
        ),
        // Detail panel (conditionally shown)
        if (showDetailPanel)
          Container(
            width: 480,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Colors.grey[300]!),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: _buildDetailPanel(),
          ),
      ],
    );
  }

  Widget _buildCompactTopBar() {
    return Consumer<ClaimProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              // Compact search
              Expanded(
                flex: 2,
                child: SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search claims... (Ctrl+F)',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearchQuery('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      provider.setSearchQuery(value);
                    },
                  ),
                ),
              ),
              const Spacer(),
              // Export button
              _buildExportButton(provider),
            ],
          ),
        );
      },
    );
  }


  Widget _buildExportButton(ClaimProvider provider) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Export filtered claims to CSV',
        child: GestureDetector(
          onTap: () {
            _exportToCSV(provider.claims);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(
                  'Export CSV',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exportToCSV(List<Claim> claims) {
    if (claims.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No claims to export'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Build CSV content
    StringBuffer csv = StringBuffer();
    
    // Header row with conditional columns
    List<String> headers = [];
    if (_showClaimId) headers.add('Claim ID');
    headers.add('Customer #');
    headers.add('Order #');
    if (_showType) headers.add('Type');
    if (_showStatus) headers.add('Status');
    if (_showCustomer) headers.add('Customer Name');
    if (_showDriver) headers.add('Driver');
    if (_showAmount) headers.add('Amount');
    if (_showDate) headers.add('Date');

    csv.writeln(headers.map((h) => '"$h"').join(','));

    // Data rows
    for (var claim in claims) {
      List<String> row = [];
      if (_showClaimId) row.add(claim.invoiceNumber ?? claim.id);
      row.add(claim.customerAccountNumber ?? '');
      row.add(''); // Order number - would need to fetch from delivery
      if (_showType) row.add(claim.type.name);
      if (_showStatus) row.add(_getStatusDisplayName(claim.status));
      if (_showCustomer) row.add(claim.customerName);
      if (_showDriver) row.add(claim.driverName);
      if (_showAmount) row.add((claim.claimAmount ?? 0).toString());
      if (_showDate) row.add(DateFormat('yyyy-MM-dd').format(claim.createdAt));

      csv.writeln(row.map((r) => '"$r"').join(','));
    }

    // In a real web app, you'd download the file
    // For now, copy to clipboard and show message
    _copyToClipboard(csv.toString());
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${claims.length} claims to CSV (copied to clipboard)'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Close',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Widget _buildKeyboardShortcutsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Keyboard Shortcuts: ',
              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 16),
            _buildKeyboardShortcutChip('Ctrl+F', 'Search'),
            _buildKeyboardShortcutChip('Ctrl+A', 'Select All'),
            _buildKeyboardShortcutChip('Esc', 'Clear Selection'),
            _buildKeyboardShortcutChip('F5', 'Refresh'),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardShortcutChip(String key, String action) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              key,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            action,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsTable() {
    return Consumer<ClaimProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Get claims and apply local sorting
        var claims = List<Claim>.from(provider.claims);
        
        // Apply local sorting
        if (_sortBy == 'date') {
          claims.sort((a, b) => _sortAscending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt));
        } else if (_sortBy == 'amount') {
          claims.sort((a, b) => _sortAscending
              ? (a.claimAmount ?? 0).compareTo(b.claimAmount ?? 0)
              : (b.claimAmount ?? 0).compareTo(a.claimAmount ?? 0));
        } else if (_sortBy == 'status') {
          claims.sort((a, b) => _sortAscending
              ? a.status.toString().compareTo(b.status.toString())
              : b.status.toString().compareTo(a.status.toString()));
        }

        if (claims.isEmpty) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              showCheckboxColumn: _isMultiSelectMode,
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: <DataColumn>[
                if (_showClaimId)
                  const DataColumn(label: Text('INV #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Cust #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataColumn(label: Text('Order #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showType)
                  const DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showStatus)
                  const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showCustomer)
                  const DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showDriver)
                  const DataColumn(label: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showAmount)
                  const DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showDate)
                  const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                if (_showActions)
                  const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: claims.map((claim) {
                final isSelected = _selectedClaimIds.contains(claim.id);
                final isHighlighted = _selectedClaim?.id == claim.id;

                return DataRow(
                  selected: isSelected || isHighlighted,
                  onSelectChanged: _isMultiSelectMode
                      ? (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedClaimIds.add(claim.id);
                            } else {
                              _selectedClaimIds.remove(claim.id);
                            }
                          });
                        }
                      : (selected) {
                          setState(() {
                            _selectedClaim = claim;
                          });
                        },
                  cells: <DataCell>[
                    if (_showClaimId)
                      DataCell(
                        Text(
                          claim.invoiceNumber ?? claim.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    DataCell(
                      FutureBuilder<String?>(
                        future: _getCustomerNumber(claim.deliveryId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('...', style: TextStyle(fontSize: 13));
                          }
                          return Text(
                            snapshot.data ?? (claim.customerAccountNumber ?? 'N/A'),
                            style: const TextStyle(fontSize: 13),
                          );
                        },
                      ),
                    ),
                    DataCell(
                      FutureBuilder<String?>(
                        future: _getOrderNumber(claim.deliveryId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('...', style: TextStyle(fontSize: 13));
                          }
                          return Text(
                            snapshot.data ?? '-',
                            style: const TextStyle(fontSize: 13),
                          );
                        },
                      ),
                    ),
                    if (_showType)
                      DataCell(_buildTypeChip(claim.type)),
                    if (_showStatus)
                      DataCell(_buildEditableStatusCell(claim)),
                    if (_showCustomer)
                      DataCell(
                        Text(
                          claim.customerName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_showDriver)
                      DataCell(
                        Text(
                          claim.driverName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_showAmount)
                      DataCell(
                        Text(
                          'R${_formatCurrency(claim.claimAmount ?? 0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_showDate)
                      DataCell(
                        Text(
                          DateFormat('MMM d, yyyy').format(claim.createdAt),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    if (_showActions)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 18),
                            tooltip: 'View Details',
                            onPressed: () {
                              setState(() {
                                _selectedClaim = claim;
                              });
                            },
                          ),
                          // Context Menu (always available)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            tooltip: 'More Options',
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility, size: 18),
                                    SizedBox(width: 8),
                                    Text('View Details'),
                                  ],
                                ),
                              ),
                              if (claim.status == ClaimStatus.pendingReview ||
                                  claim.status == ClaimStatus.submitted)
                                const PopupMenuDivider(),
                              if (claim.status == ClaimStatus.pendingReview ||
                                  claim.status == ClaimStatus.submitted)
                                const PopupMenuItem(
                                  value: 'approve',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                                      SizedBox(width: 8),
                                      Text('Approve'),
                                    ],
                                  ),
                                ),
                              if (claim.status == ClaimStatus.pendingReview ||
                                  claim.status == ClaimStatus.submitted)
                                const PopupMenuItem(
                                  value: 'reject',
                                  child: Row(
                                    children: [
                                      Icon(Icons.cancel, color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Reject'),
                                    ],
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'status',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Status'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy-id',
                                child: Row(
                                  children: [
                                    Icon(Icons.content_copy, size: 18),
                                    SizedBox(width: 8),
                                    Text('Copy Claim ID'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'view':
                                  setState(() {
                                    _selectedClaim = claim;
                                  });
                                  break;
                                case 'approve':
                                  _quickApprove(claim);
                                  break;
                                case 'reject':
                                  _quickReject(claim);
                                  break;
                                case 'status':
                                  _showStatusEditDialog(claim);
                                  break;
                                case 'copy-id':
                                  Clipboard.setData(ClipboardData(text: claim.id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Claim ID copied to clipboard'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  break;
                              }
                            },
                          ),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPanel() {
    // Find the current claim from the provider to ensure we have the latest data
    final provider = Provider.of<ClaimProvider>(context);
    final currentClaim = _selectedClaim != null
        ? provider.claims.firstWhere(
            (claim) => claim.id == _selectedClaim!.id,
            orElse: () => _selectedClaim!,
          )
        : null;

    if (currentClaim == null) return const SizedBox();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusColor(currentClaim.status).withOpacity(0.1),
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentClaim.id,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusBadge(currentClaim.status),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedClaim = null;
                  });
                },
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
                _buildDetailSection('Claim Information', [
                  _buildDetailRow('Type', _getClaimTypeDisplayName(currentClaim.type)),
                  _buildDetailRow('Priority', currentClaim.priority.name.toUpperCase()),
                  _buildDetailRow('Amount', 'R${_formatCurrency(currentClaim.claimAmount ?? 0)}'),
                  _buildDetailRow('Date', DateFormat('MMM d, yyyy h:mm a').format(currentClaim.createdAt)),
                ]),
                const SizedBox(height: 16),
                _buildDetailSection('Customer & Delivery', [
                  _buildDetailRow('Customer', currentClaim.customerName),
                  if (currentClaim.customerAccountNumber != null)
                    _buildDetailRow('Customer ID', currentClaim.customerAccountNumber!),
                  _buildDetailRow('Driver', currentClaim.driverName),
                  _buildDetailRow('Delivery ID', currentClaim.deliveryId),
                  if (currentClaim.invoiceNumber != null)
                    _buildDetailRow('Invoice', currentClaim.invoiceNumber!),
                ]),
                const SizedBox(height: 16),
                _buildDetailSection('Description', [
                  Text(
                    currentClaim.description,
                    style: const TextStyle(fontSize: 14),
                  ),
                ]),
                const SizedBox(height: 16),
                if (currentClaim.photoUrls.isNotEmpty)
                  _buildDetailSection('Evidence', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: currentClaim.photoUrls.take(4).map((url) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (currentClaim.photoUrls.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${currentClaim.photoUrls.length - 4} more photos',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                  ]),
                const SizedBox(height: 24),
                // Action buttons
                if (currentClaim.status == ClaimStatus.pendingReview ||
                    currentClaim.status == ClaimStatus.submitted)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _quickApprove(currentClaim),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _quickReject(currentClaim),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openDetailsWindow(currentClaim),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Full Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
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

  Widget _buildTypeChip(ClaimType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Text(
        _getClaimTypeDisplayName(type),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  // Get order number from delivery
  Future<String?> _getOrderNumber(String deliveryId) async {
    if (deliveryId.isEmpty) return null;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(deliveryId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        print('Delivery data for $deliveryId: orderNumber=${data?['orderNumber']}, customerNumber=${data?['customerNumber']}');
        return data?['orderNumber'] as String?;
      }
      print('Delivery not found: $deliveryId');
      return null;
    } catch (e) {
      print('Error fetching order number: $e');
      return null;
    }
  }

  // Get customer number from delivery
  Future<String?> _getCustomerNumber(String deliveryId) async {
    if (deliveryId.isEmpty) return null;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(deliveryId)
          .get();
      
      if (doc.exists) {
        return doc.data()?['customerNumber'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildEditableStatusCell(Claim claim) {
    return GestureDetector(
      onTap: () {
        _showStatusEditDialog(claim);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: 'Click to change status',
          child: _buildStatusBadge(claim.status),
        ),
      ),
    );
  }

  void _showStatusEditDialog(Claim claim) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Claim Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Claim: ${claim.invoiceNumber ?? claim.id}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('Select new status:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: ClaimStatus.values.map((status) {
                      return RadioListTile<ClaimStatus>(
                        value: status,
                        groupValue: claim.status,
                        onChanged: (newStatus) {
                          Navigator.pop(context);
                          _updateClaimStatus(claim.id, newStatus!);
                        },
                        title: Text(_getStatusDisplayName(status)),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateClaimStatus(String claimId, ClaimStatus newStatus) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      final userName = authProvider.currentUser?.fullName ?? 'Admin';
      
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final claimProvider = context.read<ClaimProvider>();
      await claimProvider.updateClaimStatus(
        claimId: claimId,
        newStatus: newStatus,
        userId: userId,
        userName: userName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${_getStatusDisplayName(newStatus)}'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
    }
  }

  Widget _buildStatusBadge(ClaimStatus status) {
    final color = _getStatusColor(status);
    final displayName = _getStatusDisplayName(status);
    final isPending = status.name.contains('pending');
    
    return MouseRegion(
      cursor: SystemMouseCursors.help,
      child: Tooltip(
        message: 'Status: $displayName',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(isPending ? 0.8 : 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPending)
                // Animated pulse for pending status
                SizedBox(
                  width: 8,
                  height: 8,
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Static icon for non-pending statuses
                _buildStatusIcon(status, color),
              const SizedBox(width: 6),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ClaimStatus status, Color color) {
    IconData iconData;
    switch (status) {
      case ClaimStatus.approved:
      case ClaimStatus.resolved:
        iconData = Icons.check_circle;
      case ClaimStatus.rejected:
      case ClaimStatus.cancelled:
        iconData = Icons.cancel;
      case ClaimStatus.investigating:
        iconData = Icons.search;
      case ClaimStatus.processing:
        iconData = Icons.hourglass_bottom;
      default:
        iconData = Icons.info;
    }
    return Icon(iconData, size: 10, color: color);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No claims found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // Actions
  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      context.read<ClaimProvider>().setDateRangeFilter(picked.start, picked.end);
    }
  }

  void _quickApprove(Claim claim) async {
    final notes = await _showQuickNotesDialog('Approve Claim', 'Optional approval notes:');
    if (notes == null) return;

    final provider = context.read<ClaimProvider>();
    final authProvider = context.read<AuthProvider>();
    
    final success = await provider.updateClaimStatus(
      claimId: claim.id,
      newStatus: ClaimStatus.approved,
      userId: authProvider.currentUser!.id,
      userName: authProvider.currentUser!.fullName,
      notes: notes.isEmpty ? null : notes,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Claim approved' : 'Failed to approve claim'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success && _selectedClaim?.id == claim.id) {
        setState(() => _selectedClaim = null);
      }
    }
  }

  void _quickReject(Claim claim) async {
    final reason = await _showQuickNotesDialog('Reject Claim', 'Reason for rejection (required):', required: true);
    if (reason == null) return;

    final provider = context.read<ClaimProvider>();
    final authProvider = context.read<AuthProvider>();
    
    final success = await provider.updateClaimStatus(
      claimId: claim.id,
      newStatus: ClaimStatus.rejected,
      userId: authProvider.currentUser!.id,
      userName: authProvider.currentUser!.fullName,
      notes: reason,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Claim rejected' : 'Failed to reject claim'),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
      if (success && _selectedClaim?.id == claim.id) {
        setState(() => _selectedClaim = null);
      }
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Claims'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export as PDF Reports'),
              subtitle: const Text('Professional formatted PDF with full details'),
              onTap: () {
                Navigator.pop(context);
                _exportClaimsAsPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export as CSV'),
              subtitle: const Text('Spreadsheet format for analysis'),
              onTap: () {
                Navigator.pop(context);
                _exportClaimsAsCSV();
              },
            ),
          ],
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

  Future<void> _exportClaimsAsPDF() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final claimProvider = context.read<ClaimProvider>();

      // Get company logo
      String? companyLogoUrl;
      try {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(authProvider.companyId!)
            .get();
        if (companyDoc.exists) {
          companyLogoUrl = companyDoc.data()?['logoUrl'] as String?;
        }
      } catch (e) {
        debugPrint('Could not fetch company logo: $e');
      }

      // Get selected or all claims
      List<String> claimIds;
      if (_selectedClaimIds.isNotEmpty) {
        claimIds = _selectedClaimIds.toList();
      } else {
        // Get filtered claims
        var claims = claimProvider.claims;

        if (_selectedStatus != null) {
          claims = claims.where((c) => c.status == _selectedStatus).toList();
        }
        if (_selectedType != null) {
          claims = claims.where((c) => c.type == _selectedType).toList();
        }
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          claims = claims.where((c) {
            return c.driverName.toLowerCase().contains(query) ||
                   c.description.toLowerCase().contains(query) ||
                   c.id.toLowerCase().contains(query);
          }).toList();
        }
        if (_dateRange != null) {
          claims = claims.where((c) {
            return c.createdAt.isAfter(_dateRange!.start) &&
                   c.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        claimIds = claims.map((c) => c.id).toList();
      }

      if (claimIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No claims to export'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Generating ${claimIds.length} claim PDFs...'),
              ],
            ),
          ),
        );
      }

      // Export PDFs
      await BulkClaimsPdfService.downloadClaimsAsZip(
        claimIds: claimIds,
        companyId: authProvider.companyId!,
        onProgress: (progress) {
          debugPrint('PDF export progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
        companyLogoUrl: companyLogoUrl,
      );

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported ${claimIds.length} claims to PDF'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting claims: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _exportClaimsAsCSV() async {
    try {
      final authProvider = context.read<AuthProvider>();

      // Get selected or all claims
      List<String> claimIds;
      if (_selectedClaimIds.isNotEmpty) {
        claimIds = _selectedClaimIds.toList();
      } else {
        // Get filtered claims (same logic as PDF)
        var claims = context.read<ClaimProvider>().claims;

        if (_selectedStatus != null) {
          claims = claims.where((c) => c.status == _selectedStatus).toList();
        }
        if (_selectedType != null) {
          claims = claims.where((c) => c.type == _selectedType).toList();
        }
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          claims = claims.where((c) {
            return c.driverName.toLowerCase().contains(query) ||
                   c.description.toLowerCase().contains(query) ||
                   c.id.toLowerCase().contains(query);
          }).toList();
        }
        if (_dateRange != null) {
          claims = claims.where((c) {
            return c.createdAt.isAfter(_dateRange!.start) &&
                   c.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        claimIds = claims.map((c) => c.id).toList();
      }

      if (claimIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No claims to export'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Exporting ${claimIds.length} claims...'),
              ],
            ),
          ),
        );
      }

      // Export CSV
      await BulkClaimsPdfService.exportClaimsAsCSV(
        claimIds: claimIds,
        companyId: authProvider.companyId!,
        onProgress: (progress) {
          debugPrint('CSV export progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported ${claimIds.length} claims to CSV'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting claims: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _bulkApprove() async {
    final notes = await _showQuickNotesDialog('Bulk Approve', 'Notes for ${_selectedClaimIds.length} claims:');
    if (notes == null) return;

    final provider = context.read<ClaimProvider>();
    final authProvider = context.read<AuthProvider>();
    int successCount = 0;

    for (final claimId in _selectedClaimIds) {
      final success = await provider.updateClaimStatus(
        claimId: claimId,
        newStatus: ClaimStatus.approved,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.fullName,
        notes: notes.isEmpty ? null : notes,
      );
      if (success) successCount++;
    }

    if (mounted) {
      setState(() {
        _selectedClaimIds.clear();
        _isMultiSelectMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved $successCount of ${_selectedClaimIds.length} claims'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _bulkReject() async {
    final reason = await _showQuickNotesDialog('Bulk Reject', 'Reason for rejecting ${_selectedClaimIds.length} claims:', required: true);
    if (reason == null) return;

    final provider = context.read<ClaimProvider>();
    final authProvider = context.read<AuthProvider>();
    int successCount = 0;

    for (final claimId in _selectedClaimIds) {
      final success = await provider.updateClaimStatus(
        claimId: claimId,
        newStatus: ClaimStatus.rejected,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.fullName,
        notes: reason,
      );
      if (success) successCount++;
    }

    if (mounted) {
      setState(() {
        _selectedClaimIds.clear();
        _isMultiSelectMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejected $successCount of ${_selectedClaimIds.length} claims'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<String?> _showQuickNotesDialog(String title, String hint, {bool required = false}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This field is required')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _openDetailsWindow(Claim claim) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClaimDetailsScreen(claim: claim),
      ),
    );
  }

  Widget _buildFilterSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_selectedStatus != null || _selectedType != null || _dateRange != null ||
                    _customerNumberController.text.isNotEmpty || _customerNameController.text.isNotEmpty ||
                    _invoiceNumberController.text.isNotEmpty || _orderNumberController.text.isNotEmpty)
                  Tooltip(
                    message: 'Clear all filters',
                    child: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _selectedStatus = null;
                          _selectedType = null;
                          _dateRange = null;
                          _customerNumberController.clear();
                          _customerNameController.clear();
                          _invoiceNumberController.clear();
                          _orderNumberController.clear();
                          _searchController.clear();
                        });
                        context.read<ClaimProvider>()
                          ..setStatusFilter(null)
                          ..setTypeFilter(null)
                          ..setDateRangeFilter(null, null)
                          ..setCustomerNumberFilter(null)
                          ..setCustomerNameFilter(null)
                          ..setInvoiceNumberFilter(null)
                          ..setOrderNumberFilter(null)
                          ..setSearchQuery('');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
          // Filter content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search claims...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      context.read<ClaimProvider>().setSearchQuery(value);
                    },
                  ),
                  const SizedBox(height: 24),
                  // Status filter
                  Text(
                    'Status',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusFilterChip(null, 'All'),
                      const SizedBox(height: 6),
                      _buildStatusFilterChip(ClaimStatus.submitted, 'Submitted'),
                      const SizedBox(height: 6),
                      _buildStatusFilterChip(ClaimStatus.pendingReview, 'Pending Review'),
                      const SizedBox(height: 6),
                      _buildStatusFilterChip(ClaimStatus.approved, 'Approved'),
                      const SizedBox(height: 6),
                      _buildStatusFilterChip(ClaimStatus.rejected, 'Rejected'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Claim Type filter
                  Text(
                    'Claim Type',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ClaimType?>(
                    value: _selectedType,
                    items: [
                      DropdownMenuItem<ClaimType?>(
                        value: null,
                        child: const Text('All Types'),
                      ),
                      ...ClaimType.values.map((type) {
                        return DropdownMenuItem<ClaimType?>(
                          value: type,
                          child: Text(_getClaimTypeDisplayName(type)),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedType = value);
                      context.read<ClaimProvider>().setTypeFilter(value);
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date Range filter
                  Text(
                    'Date Range',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showDateRangePicker,
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      _dateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                  if (_dateRange != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _dateRange = null);
                        context.read<ClaimProvider>().setDateRangeFilter(null, null);
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Date'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Advanced Filters
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Advanced Filters',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  // Customer Number
                  TextField(
                    controller: _customerNumberController,
                    decoration: InputDecoration(
                      hintText: 'Customer Number',
                      prefixIcon: const Icon(Icons.numbers, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      context.read<ClaimProvider>().setCustomerNumberFilter(value.isEmpty ? null : value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Customer Name
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      hintText: 'Customer Name',
                      prefixIcon: const Icon(Icons.person, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      context.read<ClaimProvider>().setCustomerNameFilter(value.isEmpty ? null : value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Invoice Number
                  TextField(
                    controller: _invoiceNumberController,
                    decoration: InputDecoration(
                      hintText: 'Invoice Number',
                      prefixIcon: const Icon(Icons.description, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      context.read<ClaimProvider>().setInvoiceNumberFilter(value.isEmpty ? null : value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Order Number
                  TextField(
                    controller: _orderNumberController,
                    decoration: InputDecoration(
                      hintText: 'Order Number',
                      prefixIcon: const Icon(Icons.local_shipping, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      context.read<ClaimProvider>().setOrderNumberFilter(value.isEmpty ? null : value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Clear Advanced Filters
                  if (_customerNumberController.text.isNotEmpty ||
                      _customerNameController.text.isNotEmpty ||
                      _invoiceNumberController.text.isNotEmpty ||
                      _orderNumberController.text.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _customerNumberController.clear();
                          _customerNameController.clear();
                          _invoiceNumberController.clear();
                          _orderNumberController.clear();
                        });
                        context.read<ClaimProvider>()
                          ..setCustomerNumberFilter(null)
                          ..setCustomerNameFilter(null)
                          ..setInvoiceNumberFilter(null)
                          ..setOrderNumberFilter(null);
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Advanced Filters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Statistics Overview
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.analytics, size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Overview',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(_statsExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                        onPressed: () => setState(() => _statsExpanded = !_statsExpanded),
                        tooltip: _statsExpanded ? 'Collapse' : 'Expand',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_statsExpanded) ...[
                    _buildSidebarStatCard('Total Claims', _totalClaims.toString(), Icons.receipt, Colors.blue),
                    const SizedBox(height: 8),
                    _buildSidebarStatCard('Submitted', _submittedClaims.toString(), Icons.send, Colors.purple),
                    const SizedBox(height: 8),
                    _buildSidebarStatCard('Pending Review', _pendingClaims.toString(), Icons.hourglass_bottom, Colors.orange),
                    const SizedBox(height: 8),
                    _buildSidebarStatCard('Approved', _approvedClaims.toString(), Icons.check_circle, Colors.green),
                    const SizedBox(height: 8),
                    _buildSidebarStatCard('Rejected', _rejectedClaims.toString(), Icons.cancel, Colors.red),
                    const SizedBox(height: 8),
                    _buildSidebarStatCard(
                      'Total Amount',
                      _formatCurrency(_totalAmountClaimed),
                      Icons.attach_money,
                      Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarStatCard(
                      'Avg Claim',
                      _formatCurrency(_averageClaimValue),
                      Icons.trending_up,
                      Colors.teal,
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

  Widget _buildSidebarStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildStatusFilterChip(ClaimStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    return SizedBox(
      width: double.infinity,
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        backgroundColor: Colors.grey[50],
        selectedColor: _getStatusColor(status ?? ClaimStatus.approved),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? _getStatusColor(status ?? ClaimStatus.approved) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        onSelected: (selected) {
          setState(() => _selectedStatus = selected ? status : null);
          context.read<ClaimProvider>().setStatusFilter(selected ? status : null);
        },
      ),
    );
  }

  // Helper methods
  String _getClaimTypeDisplayName(ClaimType type) {
    switch (type) {
      case ClaimType.damaged:
        return 'Damaged';
      case ClaimType.shortage:
        return 'Shortage';
      case ClaimType.shortWeight:
        return 'Short Weight';
      case ClaimType.missing:
        return 'Missing';
      case ClaimType.wrongItems:
        return 'Wrong Items';
      case ClaimType.returns:
        return 'Returns';
      case ClaimType.priceError:
        return 'Price Error';
      case ClaimType.lateDelivery:
        return 'Late';
      case ClaimType.didNotDeliver:
        return 'Not Delivered';
      case ClaimType.qualityIssue:
        return 'Quality';
      case ClaimType.temperatureIssue:
        return 'Temperature';
      case ClaimType.packagingIssue:
        return 'Packaging';
      case ClaimType.expiryIssue:
        return 'Expiry';
      case ClaimType.serviceIssue:
        return 'Service';
      case ClaimType.other:
        return 'Other';
    }
  }

  String _getStatusDisplayName(ClaimStatus status) {
    return status.name.toUpperCase().replaceAll('_', ' ');
  }

  Color _getStatusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
      case ClaimStatus.pendingReview:
        return Colors.orange;
      case ClaimStatus.approved:
      case ClaimStatus.resolved:
        return Colors.green;
      case ClaimStatus.rejected:
      case ClaimStatus.cancelled:
        return Colors.red;
      case ClaimStatus.investigating:
        return Colors.purple;
      case ClaimStatus.processing:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
