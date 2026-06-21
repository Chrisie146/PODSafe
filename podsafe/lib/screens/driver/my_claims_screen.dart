import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/claim_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import 'driver_claim_details_screen.dart';

/// Screen for drivers to view their filed claims
class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({super.key});

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  ClaimStatus? _selectedStatus;
  final _searchController = TextEditingController();

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

    // Load claims for this driver
    await claimProvider.loadClaimsForDriver(authProvider.currentUser!.id);
  }

  @override
  Widget build(BuildContext context) {
    final claimProvider = context.watch<ClaimProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Filter claims by driver
    final driverClaims = claimProvider.claims
        .where((claim) => claim.driverId == authProvider.currentUser?.id)
        .toList();

    // Apply status filter
    final filteredClaims = _selectedStatus == null
        ? driverClaims
        : driverClaims.where((claim) => claim.status == _selectedStatus).toList();

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    final searchedClaims = searchQuery.isEmpty
        ? filteredClaims
        : filteredClaims.where((claim) {
            return claim.id.toLowerCase().contains(searchQuery) ||
                claim.customerName.toLowerCase().contains(searchQuery) ||
                claim.description.toLowerCase().contains(searchQuery);
          }).toList();

    // Sort by date (newest first)
    searchedClaims.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Claims'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClaims,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSearchBar(),
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
          else if (searchedClaims.isEmpty)
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
                      _selectedStatus != null || searchQuery.isNotEmpty
                          ? 'No claims match your filters'
                          : 'No claims filed yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedStatus != null || searchQuery.isNotEmpty
                          ? 'Try adjusting your filters'
                          : 'File a claim from any delivery',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
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
                  itemCount: searchedClaims.length,
                  itemBuilder: (context, index) {
                    final claim = searchedClaims[index];
                    return _buildClaimCard(claim);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
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
            'Filter by Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('All', null),
                const SizedBox(width: 8),
                _buildStatusChip('Submitted', ClaimStatus.submitted),
                const SizedBox(width: 8),
                _buildStatusChip('Under Review', ClaimStatus.pendingReview),
                const SizedBox(width: 8),
                _buildStatusChip('Approved', ClaimStatus.approved),
                const SizedBox(width: 8),
                _buildStatusChip('Rejected', ClaimStatus.rejected),
                const SizedBox(width: 8),
                _buildStatusChip('Resolved', ClaimStatus.resolved),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, ClaimStatus? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by claim ID, customer, or description...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() {}); // Trigger rebuild on search
        },
      ),
    );
  }

  Widget _buildClaimCard(Claim claim) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverClaimDetailsScreen(claim: claim),
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
                        Text(
                          claim.invoiceNumber ?? claim.id,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
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
              _buildInfoRow(
                Icons.person_outline,
                'Customer',
                claim.customerName,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_today_outlined,
                'Filed',
                _formatDate(claim.createdAt),
              ),
              if (claim.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.description_outlined,
                  'Description',
                  claim.description,
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (claim.photoUrls.isNotEmpty) ...[
                    Icon(
                      Icons.photo_camera,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${claim.photoUrls.length} photo${claim.photoUrls.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (claim.customerSignatureUrl != null) ...[
                    Icon(
                      Icons.draw,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Signature',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (claim.affectedItems.isNotEmpty) ...[
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${claim.affectedItems.length} item${claim.affectedItems.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
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
