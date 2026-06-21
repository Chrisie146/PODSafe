import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../utils/error_handler.dart';
import '../../models/delivery_model.dart';
import '../../models/permission.dart';
import '../../providers/auth_provider.dart';
import '../../services/delivery_export_service.dart';
import '../../widgets/permission_guard.dart';
import 'create_delivery_screen.dart';
import 'delivery_details_screen.dart';
import 'bulk_upload_screen.dart';
import 'delivery_management_desktop.dart';

class DeliveryManagementScreen extends StatelessWidget {
  const DeliveryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1000) {
          return const DeliveryManagementDesktop();
        }
        return const DeliveryManagementMobile();
      },
    );
  }
}

class DeliveryManagementMobile extends StatefulWidget {
  const DeliveryManagementMobile({super.key});

  @override
  State<DeliveryManagementMobile> createState() => _DeliveryManagementMobileState();
}

class _DeliveryManagementMobileState extends State<DeliveryManagementMobile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          // Export menu - wrap with permission guard
          PermissionBuilder(
            anyPermissions: [Permission.deliveriesManage, Permission.financeExport],
            builder: (context, hasAccess) {
              if (!hasAccess) return const SizedBox.shrink();
              
              return PopupMenuButton<String>(
                icon: const Icon(Icons.download),
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
                        Text('Bulk Upload CSV', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        Text('Export All Deliveries'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by customer name, address, or invoice...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Delivery list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeliveryList(null),
                _buildDeliveryList(DeliveryStatus.pending),
                _buildDeliveryList(DeliveryStatus.inTransit),
                _buildDeliveryList(DeliveryStatus.delivered),
              ],
            ),
          ),
        ],
      ),
      // Wrap FAB with permission guard - only show to users who can manage deliveries
      floatingActionButton: PermissionGuard(
        permission: Permission.deliveriesManage,
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateDeliveryScreen(),
              ),
            );
            if (result == true) {
              setState(() {}); // Refresh list
            }
          },
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Icons.add),
          label: const Text('New Delivery'),
        ),
      ),
    );
  }

  Widget _buildDeliveryList(DeliveryStatus? status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getDeliveriesStream(status),
      builder: (context, snapshot) {
        print('📊 StreamBuilder state: ${snapshot.connectionState}');
        print('📊 Has error: ${snapshot.hasError}');
        print('📊 Has data: ${snapshot.hasData}');
        if (snapshot.hasData) {
          print('📊 Document count: ${snapshot.data!.docs.length}');
        }

        if (snapshot.hasError) {
          print('❌ Error loading deliveries: ${snapshot.error}');
          
          // Check if it's a permission error
          if (ErrorHandler.isPermissionDenied(snapshot.error)) {
            return ErrorHandler.buildPermissionDeniedWidget(
              message: 'You don\'t have permission to view deliveries. Please contact your administrator if you need access.',
            );
          }
          
          // Other errors
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    ErrorHandler.getUserFriendlyMessage(snapshot.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
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
                Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  status == null
                      ? 'No deliveries yet'
                      : 'No ${_getStatusText(status).toLowerCase()} deliveries',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap + to create a new delivery',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter by search query
        var deliveries = snapshot.data!.docs.map((doc) {
          return Delivery.fromFirestore(doc);
        }).toList();

        if (_searchQuery.isNotEmpty) {
          deliveries = deliveries.where((delivery) {
            return delivery.customerName.toLowerCase().contains(_searchQuery) ||
                delivery.customerAddress.toLowerCase().contains(_searchQuery) ||
                delivery.invoiceNumber.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (deliveries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  'No matching deliveries',
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

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          itemCount: deliveries.length,
          itemBuilder: (context, index) {
            final delivery = deliveries[index];
            return _buildDeliveryCard(delivery);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getDeliveriesStream(DeliveryStatus? status) {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    print('📦 Loading deliveries for companyId: $companyId');

    if (companyId == null || companyId.isEmpty) {
      print('❌ No company ID found - returning empty stream');
      // Return empty stream if no company
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .orderBy('scheduledDate', descending: true);

    if (status != null) {
      final statusString = status.toString().split('.').last;
      print('🔍 Filtering by status: $statusString');
      query = query.where('status', isEqualTo: statusString);
    }

    print('✅ Query created successfully');
    return query.snapshots();
  }

  Widget _buildDeliveryCard(Delivery delivery) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryDetailsScreen(delivery: delivery),
            ),
          );
          if (result == true) {
            setState(() {}); // Refresh if changes were made
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(delivery.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(delivery.status),
                      color: _getStatusColor(delivery.status),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.customerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (delivery.customerNumber != null)
                          Text(
                            'Customer #: ${delivery.customerNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        if (delivery.orderNumber != null)
                          Text(
                            'Order: ${delivery.orderNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        Text(
                          'Invoice: ${delivery.invoiceNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(delivery.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(delivery.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      delivery.customerAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEEE, MMM d, y').format(delivery.scheduledDate),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (delivery.items.isNotEmpty) ...[
                    const Icon(
                      Icons.inventory_2,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${delivery.items.length} item${delivery.items.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (delivery.vehicleUsed != null && delivery.vehicleUsed!.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.directions_car,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Vehicle: ${delivery.vehicleUsed}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
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

  // Download CSV template
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

  // Export all deliveries to CSV
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
                SizedBox(width: 16),
                Text('Preparing export...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get all deliveries for company
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .get();

      final deliveries = deliveriesSnapshot.docs
          .map((doc) => Delivery.fromFirestore(doc))
          .toList();

      if (deliveries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No deliveries to export'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      // Get driver emails
      final driverIds = deliveries.map((d) => d.driverId).toSet();
      final driverEmails = <String, String>{};

      for (var driverId in driverIds) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .get();
        
        if (driverDoc.exists) {
          driverEmails[driverId] = driverDoc.data()?['email'] ?? '';
        }
      }

      // Export to CSV
      await DeliveryExportService.downloadDeliveryExport(deliveries, driverEmails);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${deliveries.length} deliveries successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
