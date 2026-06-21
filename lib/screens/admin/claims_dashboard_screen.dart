import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/claim_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import 'claim_details_screen.dart';
import 'claims_dashboard_desktop.dart';

/// Responsive Admin screen to view and manage all company claims
/// Automatically switches between mobile and desktop layouts
class ClaimsDashboardScreen extends StatelessWidget {
  const ClaimsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use desktop layout for screens wider than 900px
        if (constraints.maxWidth > 900) {
          return const ClaimsDashboardDesktop();
        }
        // Use mobile layout for smaller screens
        return const ClaimsDashboardMobile();
      },
    );
  }
}

/// Mobile/Tablet version of Claims Dashboard
class ClaimsDashboardMobile extends StatefulWidget {
  const ClaimsDashboardMobile({super.key});

  @override
  State<ClaimsDashboardMobile> createState() => _ClaimsDashboardMobileState();
}

class _ClaimsDashboardMobileState extends State<ClaimsDashboardMobile> {
  ClaimStatus? _selectedStatus;
  ClaimType? _selectedType;
  String? _selectedDriverId;
  DateTimeRange? _dateRange;
  final _searchController = TextEditingController();
  String _sortBy = 'date'; // date, status, type, amount

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClaims();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClaims() async {
    final authProvider = context.read<AuthProvider>();
    final claimProvider = context.read<ClaimProvider>();

    // Initialize provider if needed
    if (claimProvider.companyId == null) {
      await claimProvider.initialize(authProvider.companyId!);
    }

    // Load all company claims (no driver filter for admin)
    await claimProvider.loadAllClaims();
  }

  @override
  Widget build(BuildContext context) {
    final claimProvider = context.watch<ClaimProvider>();

    // Apply filters
    var filteredClaims = claimProvider.claims;

    // Status filter
    if (_selectedStatus != null) {
      filteredClaims = filteredClaims
          .where((claim) => claim.status == _selectedStatus)
          .toList();
    }

    // Type filter
    if (_selectedType != null) {
      filteredClaims = filteredClaims
          .where((claim) => claim.type == _selectedType)
          .toList();
    }

    // Driver filter
    if (_selectedDriverId != null) {
      filteredClaims = filteredClaims
          .where((claim) => claim.driverId == _selectedDriverId)
          .toList();
    }

    // Date range filter
    if (_dateRange != null) {
      filteredClaims = filteredClaims.where((claim) {
        return claim.createdAt.isAfter(_dateRange!.start) &&
            claim.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredClaims = filteredClaims.where((claim) {
        return claim.id.toLowerCase().contains(searchQuery) ||
            claim.customerName.toLowerCase().contains(searchQuery) ||
            claim.description.toLowerCase().contains(searchQuery) ||
            claim.invoiceNumber?.toLowerCase().contains(searchQuery) == true;
      }).toList();
    }

    // Sort
    filteredClaims = List.from(filteredClaims);
    switch (_sortBy) {
      case 'date':
        filteredClaims.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'status':
        filteredClaims.sort((a, b) => a.status.name.compareTo(b.status.name));
        break;
      case 'type':
        filteredClaims.sort((a, b) => a.type.name.compareTo(b.type.name));
        break;
      case 'amount':
        filteredClaims.sort((a, b) => 
            (b.claimAmount ?? 0).compareTo(a.claimAmount ?? 0));
        break;
    }

    // Calculate statistics
    final stats = _calculateStats(claimProvider.claims);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claims Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClaims,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to claim settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Claim Settings - Coming Soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          _buildStatisticsSection(stats),

          // Filters Section
          _buildFiltersSection(),

          // Search and Sort
          _buildSearchAndSort(),

          // Claims List
          if (claimProvider.isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (claimProvider.error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      claimProvider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadClaims,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredClaims.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _hasActiveFilters()
                          ? 'No claims match your filters'
                          : 'No claims filed yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_hasActiveFilters()) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: const Text('Clear Filters'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadClaims,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredClaims.length,
                  itemBuilder: (context, index) {
                    final claim = filteredClaims[index];
                    return _buildClaimCard(claim);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  stats['total'].toString(),
                  Icons.receipt_long,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  stats['pending'].toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Approved',
                  stats['approved'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Rejected',
                  stats['rejected'].toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters())
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Status',
                  _selectedStatus?.name ?? 'All',
                  _selectedStatus != null,
                  () => _showStatusFilterDialog(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Type',
                  _selectedType != null ? _getClaimTypeDisplay(_selectedType!) : 'All',
                  _selectedType != null,
                  () => _showTypeFilterDialog(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Date Range',
                  _dateRange != null
                      ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
                      : 'All Time',
                  _dateRange != null,
                  () => _showDateRangeDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by claim ID, customer, invoice...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {}); // Trigger rebuild on search
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: _sortBy == 'date' ? AppTheme.primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Date',
                      style: TextStyle(
                        color: _sortBy == 'date' ? AppTheme.primaryColor : null,
                        fontWeight: _sortBy == 'date' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag,
                      size: 16,
                      color: _sortBy == 'status' ? AppTheme.primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status',
                      style: TextStyle(
                        color: _sortBy == 'status' ? AppTheme.primaryColor : null,
                        fontWeight: _sortBy == 'status' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'type',
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 16,
                      color: _sortBy == 'type' ? AppTheme.primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Type',
                      style: TextStyle(
                        color: _sortBy == 'type' ? AppTheme.primaryColor : null,
                        fontWeight: _sortBy == 'type' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: _sortBy == 'amount' ? AppTheme.primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Amount',
                      style: TextStyle(
                        color: _sortBy == 'amount' ? AppTheme.primaryColor : null,
                        fontWeight: _sortBy == 'amount' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Claim claim) {
    final isOverdue = _isClaimOverdue(claim);
    final needsAction = _claimNeedsAction(claim);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClaimDetailsScreen(claim: claim),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              claim.invoiceNumber ?? claim.id,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            if (needsAction) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTION NEEDED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            if (isOverdue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getClaimTypeDisplay(claim.type),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(claim.status),
                ],
              ),
              const SizedBox(height: 12),
              // Traceability row - Invoice No, Customer No, Order No
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.receipt_outlined,
                      'INV',
                      claim.invoiceNumber ?? 'N/A',
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<String?>(
                      future: _getCustomerNumber(claim.deliveryId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildInfoRow(Icons.tag, 'Cust #', '...');
                        }
                        return _buildInfoRow(
                          Icons.tag,
                          'Cust #',
                          snapshot.data ?? (claim.customerAccountNumber ?? 'N/A'),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<String?>(
                      future: _getOrderNumber(claim.deliveryId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildInfoRow(Icons.numbers, 'Order #', '...');
                        }
                        return _buildInfoRow(
                          Icons.numbers,
                          'Order #',
                          snapshot.data ?? '-',
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.person_outline,
                'Customer',
                claim.customerName,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.local_shipping_outlined,
                'Driver',
                claim.driverName,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.calendar_today_outlined,
                'Filed',
                _formatDate(claim.createdAt),
              ),
              if (claim.claimAmount != null) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  Icons.attach_money,
                  'Amount',
                  'R${claim.claimAmount!.toStringAsFixed(2)}',
                ),
              ],
              if (claim.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  claim.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (claim.photoUrls.isNotEmpty) ...[
                    Icon(
                      Icons.photo_camera,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${claim.photoUrls.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (claim.customerSignatureUrl != null) ...[
                    Icon(
                      Icons.draw,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (claim.affectedItems.isNotEmpty) ...[
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${claim.affectedItems.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ClaimStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case ClaimStatus.draft:
        backgroundColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        label = 'Draft';
        break;
      case ClaimStatus.submitted:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        label = 'Submitted';
        break;
      case ClaimStatus.pendingReview:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        label = 'Pending Review';
        break;
      case ClaimStatus.investigating:
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[900]!;
        label = 'Investigating';
        break;
      case ClaimStatus.pendingDriverResponse:
        backgroundColor = Colors.amber[100]!;
        textColor = Colors.amber[900]!;
        label = 'Needs Response';
        break;
      case ClaimStatus.driverResponded:
        backgroundColor = Colors.teal[100]!;
        textColor = Colors.teal[900]!;
        label = 'Responded';
        break;
      case ClaimStatus.pendingApproval:
      case ClaimStatus.pendingSecondApproval:
      case ClaimStatus.pendingProcessing:
      case ClaimStatus.processing:
      case ClaimStatus.pendingFinalReview:
        backgroundColor = Colors.indigo[100]!;
        textColor = Colors.indigo[900]!;
        label = 'In Progress';
        break;
      case ClaimStatus.approved:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        label = 'Approved';
        break;
      case ClaimStatus.rejected:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        label = 'Rejected';
        break;
      case ClaimStatus.resolved:
        backgroundColor = Colors.teal[100]!;
        textColor = Colors.teal[900]!;
        label = 'Resolved';
        break;
      case ClaimStatus.closed:
        backgroundColor = Colors.grey[400]!;
        textColor = Colors.grey[900]!;
        label = 'Closed';
        break;
      case ClaimStatus.cancelled:
        backgroundColor = Colors.grey[300]!;
        textColor = Colors.grey[700]!;
        label = 'Cancelled';
        break;
      case ClaimStatus.disputed:
        backgroundColor = Colors.deepOrange[100]!;
        textColor = Colors.deepOrange[900]!;
        label = 'Disputed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateStats(List<Claim> claims) {
    return {
      'total': claims.length,
      'pending': claims.where((c) =>
          c.status == ClaimStatus.submitted ||
          c.status == ClaimStatus.pendingReview ||
          c.status == ClaimStatus.pendingApproval).length,
      'approved': claims.where((c) => c.status == ClaimStatus.approved).length,
      'rejected': claims.where((c) => c.status == ClaimStatus.rejected).length,
    };
  }

  bool _hasActiveFilters() {
    return _selectedStatus != null ||
        _selectedType != null ||
        _selectedDriverId != null ||
        _dateRange != null;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedType = null;
      _selectedDriverId = null;
      _dateRange = null;
      _searchController.clear();
    });
  }

  bool _isClaimOverdue(Claim claim) {
    // Simple logic: claims older than 7 days that aren't resolved/closed
    if (claim.status == ClaimStatus.resolved ||
        claim.status == ClaimStatus.closed ||
        claim.status == ClaimStatus.cancelled) {
      return false;
    }
    final daysSinceCreated = DateTime.now().difference(claim.createdAt).inDays;
    return daysSinceCreated > 7;
  }

  bool _claimNeedsAction(Claim claim) {
    return claim.status == ClaimStatus.pendingReview ||
        claim.status == ClaimStatus.pendingApproval ||
        claim.status == ClaimStatus.pendingSecondApproval;
  }

  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Statuses'),
                leading: Radio<ClaimStatus?>(
                  value: null,
                  groupValue: _selectedStatus,
                  onChanged: (value) {
                    setState(() => _selectedStatus = value);
                    Navigator.pop(context);
                  },
                ),
                onTap: () {
                  setState(() => _selectedStatus = null);
                  Navigator.pop(context);
                },
              ),
              ...ClaimStatus.values.map((status) {
                return ListTile(
                  title: Text(status.name),
                  leading: Radio<ClaimStatus?>(
                    value: status,
                    groupValue: _selectedStatus,
                    onChanged: (value) {
                      setState(() => _selectedStatus = value);
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setState(() => _selectedStatus = status);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showTypeFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Types'),
                leading: Radio<ClaimType?>(
                  value: null,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() => _selectedType = value);
                    Navigator.pop(context);
                  },
                ),
                onTap: () {
                  setState(() => _selectedType = null);
                  Navigator.pop(context);
                },
              ),
              ...ClaimType.values.map((type) {
                return ListTile(
                  title: Text(_getClaimTypeDisplay(type)),
                  leading: Radio<ClaimType?>(
                    value: type,
                    groupValue: _selectedType,
                    onChanged: (value) {
                      setState(() => _selectedType = value);
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setState(() => _selectedType = type);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDateRangeDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  String _getClaimTypeDisplay(ClaimType type) {
    switch (type) {
      case ClaimType.damaged:
        return 'Damaged Goods';
      case ClaimType.shortage:
        return 'Short Delivered';
      case ClaimType.shortWeight:
        return 'Short Weight';
      case ClaimType.missing:
        return 'Missing Items';
      case ClaimType.wrongItems:
        return 'Wrong Items';
      case ClaimType.returns:
        return 'Returns';
      case ClaimType.priceError:
        return 'Price Error';
      case ClaimType.lateDelivery:
        return 'Late Delivery';
      case ClaimType.didNotDeliver:
        return 'Did Not Deliver';
      case ClaimType.qualityIssue:
        return 'Quality Issue';
      case ClaimType.temperatureIssue:
        return 'Temperature Issue';
      case ClaimType.packagingIssue:
        return 'Packaging Issue';
      case ClaimType.expiryIssue:
        return 'Expiry Issue';
      case ClaimType.serviceIssue:
        return 'Service Issue';
      case ClaimType.other:
        return 'Other';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
