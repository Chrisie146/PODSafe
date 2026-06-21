import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_model.dart';
import '../../models/claim_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/claim_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/delivery_map_widget.dart';
import 'delivery_list_screen.dart';
import 'pod_capture_screen.dart';
import 'delivery_details_screen.dart';
import 'my_claims_screen.dart';
import 'driver_claim_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> 
    with WidgetsBindingObserver {
  bool _isRefreshing = false;
  bool _showMapView = false; // Toggle between list and map view
  bool _showDeliveriesAsList = false; // Toggle between card and list view for deliveries
  ClaimStatus? _selectedStatus;
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when the app comes back to foreground
      print('📱 App resumed - refreshing dashboard');
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() {
      _isRefreshing = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        final driverId = authProvider.currentUser!.id;
        print('👤 Driver logged in: $driverId');
        print('📧 Driver email: ${authProvider.currentUser!.email}');
        print('🏢 Driver companyId: ${authProvider.currentUser!.companyId}');

  final deliveryProvider = context.read<DeliveryProvider>();
  // Load the driver's deliveries so the dashboard has data immediately on login.
  // Previously we only called loadTodaysDeliveries which filtered out results
  // and could leave the provider empty until the "View Deliveries" screen
  // initialized the full stream. Loading all driver deliveries ensures the
  // dashboard shows pending items right away.
  await deliveryProvider.loadDriverDeliveries(driverId);

  // Load claims for the driver
  final claimProvider = context.read<ClaimProvider>();
  if (claimProvider.companyId == null) {
    await claimProvider.initialize(authProvider.companyId!);
  }
  await claimProvider.loadClaimsForDriver(driverId);
      } else {
        print('⚠️ No current user found in auth provider');
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PODSafe Driver',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome, ${authProvider.currentUser?.fullName ?? 'Driver'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                Navigator.pushNamed(context, '/driver/chat');
              },
              tooltip: 'Chat with Admin',
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showLogoutDialog(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.logout),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Deliveries'),
              Tab(text: 'Claims'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDeliveriesTab(),
            _buildClaimsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      strokeWidth: 3,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // View Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(_showDeliveriesAsList ? Icons.view_module : Icons.view_list),
                      onPressed: () {
                        setState(() {
                          _showDeliveriesAsList = !_showDeliveriesAsList;
                        });
                      },
                      tooltip: _showDeliveriesAsList ? 'Switch to card view' : 'Switch to list view',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Conditional content based on view mode
                if (_showDeliveriesAsList)
                  _buildDeliveriesListView()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Priority: Pending Deliveries Section (Most Important)
                      _buildPendingDeliveriesSection(),

                      const SizedBox(height: 20),

                      // Quick Stats Card
                      _buildQuickStatsCard(),

                      const SizedBox(height: 20),

                      // Completed Deliveries Section (Collapsible)
                      _buildCompletedDeliveriesSection(),

                      // Add extra space at bottom for better scrolling
                      const SizedBox(height: 100),
                    ],
                  ),
                ],
            ),
          ),
          if (_isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Refreshing deliveries...',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClaimsTab() {
    return Consumer2<ClaimProvider, AuthProvider>(
      builder: (context, claimProvider, authProvider, child) {
        final driverClaims = claimProvider.claims
            .where((claim) => claim.driverId == authProvider.currentUser?.id)
            .toList();

        // Sort by date (newest first)
        driverClaims.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Column(
          children: [
            if (claimProvider.isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (claimProvider.error != null)
              Expanded(
                child: Center(
                  child: Text(
                    'Error: ${claimProvider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else
              Expanded(
                child: driverClaims.isEmpty
                    ? const Center(child: Text('No claims found'))
                    : ListView.builder(
                        itemCount: driverClaims.length,
                        itemBuilder: (context, index) {
                          final claim = driverClaims[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(claim.customerName),
                              subtitle: Text(
                                '${claim.description}\n${DateFormat('MMM dd, yyyy').format(claim.createdAt)}',
                              ),
                              trailing: Text(
                                claim.status.toString().split('.').last,
                                style: TextStyle(
                                  color: _getClaimStatusColor(claim.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DriverClaimDetailsScreen(claim: claim),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }

  Color _getClaimStatusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
        return Colors.blue;
      case ClaimStatus.pendingReview:
        return Colors.orange;
      case ClaimStatus.approved:
        return Colors.green;
      case ClaimStatus.rejected:
        return Colors.red;
      case ClaimStatus.resolved:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDeliveriesListView() {
    return Consumer<DeliveryProvider>(
      builder: (context, deliveryProvider, child) {
        final allDeliveries = deliveryProvider.deliveries;

        // Sort: pending first, then by created date descending
        allDeliveries.sort((a, b) {
          final aPending = a.status != DeliveryStatus.delivered;
          final bPending = b.status != DeliveryStatus.delivered;
          if (aPending != bPending) {
            return aPending ? -1 : 1; // Pending first
          }
          return b.createdAt.compareTo(a.createdAt); // Newest first
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allDeliveries.length,
          itemBuilder: (context, index) {
            final delivery = allDeliveries[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  _getStatusIcon(delivery.status),
                  color: _getStatusColor(delivery.status),
                ),
                title: Text(
                  delivery.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(delivery.customerAddress),
                    Text(
                      'Due: ${DateFormat('MMM dd, HH:mm').format(delivery.scheduledDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Text(
                  delivery.status.toString().split('.').last,
                  style: TextStyle(
                    color: _getStatusColor(delivery.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DeliveryDetailsScreen(delivery: delivery),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStatsCard() {
    return Consumer<DeliveryProvider>(
      builder: (context, deliveryProvider, child) {
        final allDeliveries = deliveryProvider.deliveries;
        final completed = allDeliveries.where((d) => 
            d.status.toString().split('.').last == 'delivered').length;
        final pending = allDeliveries.length - completed;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Progress',
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Deliveries',
                        allDeliveries.length.toString(),
                        Icons.local_shipping,
                        AppTheme.infoColor,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Completed',
                        completed.toString(),
                        Icons.check_circle,
                        AppTheme.successColor,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Pending',
                        pending.toString(),
                        Icons.pending,
                        AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Priority Section: Pending Deliveries
  Widget _buildPendingDeliveriesSection() {
    return Consumer<DeliveryProvider>(
      builder: (context, deliveryProvider, child) {
        if (deliveryProvider.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Filter pending deliveries (not delivered, not failed) - TEMPORARILY SHOW ALL PENDING
        final pendingDeliveries = deliveryProvider.deliveries
            .where((d) => 
                d.status != DeliveryStatus.delivered && 
                d.status != DeliveryStatus.failed)
            .toList();

        // Debug logging
        print('📊 Total deliveries: ${deliveryProvider.deliveries.length}');
        print('📊 Pending deliveries: ${pendingDeliveries.length}');
        for (var d in deliveryProvider.deliveries) {
          print('  - ${d.customerName}: ${d.status} (${d.status == DeliveryStatus.delivered ? "delivered" : "not delivered"})');
        }

        if (pendingDeliveries.isEmpty) {
          return Card(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All Caught Up! 🎉',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No pending deliveries at the moment',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${pendingDeliveries.length} PENDING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Deliveries',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                // Map/List Toggle Button
                Tooltip(
                  message: _showMapView ? 'Switch to list view' : 'Switch to map view',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: !_showMapView ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() => _showMapView = false);
                            },
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Icon(
                                Icons.list,
                                color: !_showMapView ? Colors.white : AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: _showMapView ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() => _showMapView = true);
                            },
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Icon(
                                Icons.map,
                                color: _showMapView ? Colors.white : AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to start your deliveries',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Show map or list based on toggle
            if (_showMapView)
              SizedBox(
                height: 400,
                child: DeliveryMapWidget(
                  deliveries: pendingDeliveries,
                  onDeliveryTap: (delivery) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DeliveryDetailsScreen(delivery: delivery),
                      ),
                    );
                  },
                ),
              )
            else
              ...pendingDeliveries.asMap().entries.map((entry) {
                final index = entry.key;
                final delivery = entry.value;
                final isNext = index == 0;
                return _buildPendingDeliveryCard(delivery, isNext);
              }),
          ],
        );
      },
    );
  }

  Widget _buildPendingDeliveryCard(delivery, bool isNext) {
    final statusColor = _getStatusColor(delivery.status);

    return Dismissible(
      key: Key('delivery-${delivery.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - Start delivery (Capture POD)
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PODCaptureScreen(delivery: delivery),
            ),
          );
          return false; // Don't dismiss the card
        } else if (direction == DismissDirection.endToStart) {
          // Swipe left - Show options
          _showDeliveryOptions(context, delivery);
          return false; // Don't dismiss the card
        }
        return false;
      },
      background: _buildSwipeBackground(isStartToEnd: true),
      secondaryBackground: _buildSwipeBackground(isStartToEnd: false),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isNext ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isNext
              ? const BorderSide(color: AppTheme.primaryColor, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DeliveryDetailsScreen(delivery: delivery),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with priority indicator and customer name
                Row(
                  children: [
                    if (isNext) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'NEXT UP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        delivery.customerName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(delivery.status),
                            color: statusColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(delivery.status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Address section with icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          delivery.customerAddress,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Delivery details row - wrapped in scroll view to prevent overflow
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (delivery.orderNumber != null) ...[
                        _buildDetailChip(
                          icon: Icons.numbers,
                          label: 'Order: ${delivery.orderNumber}',
                          color: AppTheme.infoColor,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildDetailChip(
                        icon: Icons.receipt,
                        label: 'INV: ${delivery.invoiceNumber}',
                        color: AppTheme.primaryColor,
                      ),
                      if (delivery.items.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildDetailChip(
                          icon: Icons.inventory_2,
                          label: '${delivery.items.length} items',
                          color: AppTheme.successColor,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Enhanced CTA button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PODCaptureScreen(delivery: delivery),
                        ),
                      );
                    },
                    icon: Icon(
                      isNext ? Icons.play_arrow : Icons.arrow_forward,
                      size: 24,
                    ),
                    label: Text(
                      isNext ? 'START DELIVERY' : 'BEGIN DELIVERY',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNext ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      elevation: isNext ? 6 : 3,
                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }  // Completed Deliveries Section (Collapsible)
  Widget _buildCompletedDeliveriesSection() {
    return Consumer<DeliveryProvider>(
      builder: (context, deliveryProvider, child) {
        final completedDeliveries = deliveryProvider.deliveries
            .where((d) => d.status == DeliveryStatus.delivered)
            .toList();

        if (completedDeliveries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Completed (${completedDeliveries.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DeliveryListScreen(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...completedDeliveries.take(3).map((delivery) => 
              _buildCompletedDeliveryCard(delivery)
            ),
            if (completedDeliveries.length > 3)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DeliveryListScreen(),
                    ),
                  );
                },
                child: Text('View ${completedDeliveries.length - 3} more completed deliveries'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCompletedDeliveryCard(delivery) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
          child: const Icon(
            Icons.check_circle,
            color: AppTheme.successColor,
            size: 20,
          ),
        ),
        title: Text(
          delivery.customerName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        subtitle: Text(
          'INV: ${delivery.invoiceNumber} • ${_formatDate(delivery.scheduledDate)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DeliveryDetailsScreen(delivery: delivery),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildQuickActionsSection() {
    return Consumer<DeliveryProvider>(
      builder: (context, deliveryProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'View Deliveries',
                    icon: Icons.list_alt,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DeliveryListScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'My Claims',
                    icon: Icons.receipt_long,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MyClaimsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(status) {
    switch (status.toString().split('.').last) {
      case 'delivered':
        return AppTheme.successColor;
      case 'inTransit':
        return AppTheme.infoColor;
      case 'pending':
        return AppTheme.warningColor;
      default:
        return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon(status) {
    switch (status.toString().split('.').last) {
      case 'delivered':
        return Icons.check_circle;
      case 'inTransit':
        return Icons.local_shipping;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.error;
    }
  }

  String _getStatusText(status) {
    switch (status.toString().split('.').last) {
      case 'delivered':
        return 'Delivered';
      case 'inTransit':
        return 'In Transit';
      case 'pending':
        return 'Pending';
      default:
        return 'Failed';
    }
  }

  Widget _buildSwipeBackground({required bool isStartToEnd}) {
    return Container(
      alignment: isStartToEnd ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isStartToEnd ? AppTheme.primaryColor : AppTheme.warningColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStartToEnd ? Icons.play_arrow : Icons.more_horiz,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            isStartToEnd ? 'START' : 'OPTIONS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeliveryOptions(BuildContext context, delivery) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              delivery.customerName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              delivery.customerAddress,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionButton(
              icon: Icons.play_arrow,
              label: 'Start Delivery',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PODCaptureScreen(delivery: delivery),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              icon: Icons.info,
              label: 'View Details',
              color: AppTheme.infoColor,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DeliveryDetailsScreen(delivery: delivery),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              icon: Icons.navigation,
              label: 'Get Directions',
              color: AppTheme.successColor,
              onTap: () {
                Navigator.of(context).pop();
                _launchNavigation(delivery.customerAddress);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              icon: Icons.phone,
              label: 'Call Customer',
              color: AppTheme.warningColor,
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement phone call
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Call feature coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _launchNavigation(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web if external app fails
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open navigation: $e')),
        );
      }
    }
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await context.read<AuthProvider>().signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}