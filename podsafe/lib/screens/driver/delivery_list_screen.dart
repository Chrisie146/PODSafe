import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../models/delivery_model.dart';
import '../../widgets/pod_qr_code.dart';
import '../../services/pod_token_service.dart';
import 'delivery_details_screen.dart';
import 'pod_capture_screen.dart';
import 'package:intl/intl.dart';

class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Load deliveries when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeliveries();
    });
  }

  void _loadDeliveries() {
    final authProvider = context.read<app_auth.AuthProvider>();
    final deliveryProvider = context.read<DeliveryProvider>();
    
    if (authProvider.currentUser != null) {
      print('📋 Loading all deliveries for driver: ${authProvider.currentUser!.id}');
      deliveryProvider.loadDriverDeliveries(authProvider.currentUser!.id);
    } else {
      print('⚠️ No current user found when loading delivery list');
    }
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
        title: const Text('All Deliveries'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All', icon: Icon(Icons.list)),
            Tab(text: 'Pending', icon: Icon(Icons.pending)),
            Tab(text: 'In Transit', icon: Icon(Icons.local_shipping)),
            Tab(text: 'Delivered', icon: Icon(Icons.check_circle)),
          ],
        ),
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
                hintText: 'Search by customer or address...',
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
    );
  }

  Widget _buildDeliveryList(DeliveryStatus? status) {
    return Consumer<DeliveryProvider>(
      builder: (context, deliveryProvider, child) {
        print('📊 Building delivery list - Status filter: $status');
        print('📊 Total deliveries in provider: ${deliveryProvider.deliveries.length}');
        print('📊 Is loading: ${deliveryProvider.isLoading}');
        
        if (deliveryProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var deliveries = deliveryProvider.deliveries;
        print('📊 Starting with ${deliveries.length} deliveries');

        // Filter by status
        if (status != null) {
          deliveries = deliveries.where((d) => d.status == status).toList();
          print('📊 After status filter: ${deliveries.length} deliveries');
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          deliveries = deliveries.where((d) {
            return d.customerName.toLowerCase().contains(_searchQuery) ||
                d.customerAddress.toLowerCase().contains(_searchQuery) ||
                d.invoiceNumber.toLowerCase().contains(_searchQuery);
          }).toList();
          print('📊 After search filter: ${deliveries.length} deliveries');
        }

        if (deliveries.isEmpty) {
          print('⚠️ No deliveries to display');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == null
                      ? Icons.inbox
                      : _getStatusIcon(status),
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No matching deliveries'
                      : status == null
                          ? 'No deliveries yet'
                          : 'No ${_getStatusText(status).toLowerCase()} deliveries',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        print('✅ Displaying ${deliveries.length} deliveries');
        return RefreshIndicator(
          onRefresh: () async {
            final authProvider = context.read<app_auth.AuthProvider>();
            if (authProvider.currentUser != null) {
              await deliveryProvider.loadDriverDeliveries(authProvider.currentUser!.id);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index];
              return _buildDeliveryCard(delivery);
            },
          ),
        );
      },
    );
  }

  Widget _buildDeliveryCard(Delivery delivery) {
    final statusColor = _getStatusColor(delivery.status);
    final statusIcon = _getStatusIcon(delivery.status);

    return Dismissible(
      key: Key('mobile-delivery-${delivery.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - Start delivery
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PODCaptureScreen(delivery: delivery),
            ),
          );
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Swipe left - Show options
          _showDeliveryOptions(context, delivery);
          return false;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('START', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.warningColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('OPTIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.more_horiz, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeliveryDetailsScreen(delivery: delivery),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with status and customer name
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.customerName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'INV: ${delivery.invoiceNumber}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(delivery.status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Address section
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          delivery.customerAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Meta info row
                Row(
                  children: [
                    if (delivery.orderNumber != null) ...[
                      _buildMobileDetailChip(Icons.numbers, 'Order: ${delivery.orderNumber}', AppTheme.infoColor),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _buildMobileDetailChip(Icons.calendar_today, DateFormat('MMM d').format(delivery.scheduledDate), AppTheme.successColor),
                    ),
                    if (delivery.status == DeliveryStatus.delivered) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              try {
                                final token = await PODTokenService().getTokenByDeliveryId(delivery.id);
                                if (token != null && mounted) {
                                  await PODQRCodeDialog.show(context, token: token);
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('QR code not available yet. Please try again in a moment.'),
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
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.qr_code_2, color: AppTheme.primaryColor, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PODCaptureScreen(delivery: delivery),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      delivery.status == DeliveryStatus.pending ? 'START NOW' : 'CONTINUE',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
  }

  Widget _buildMobileDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeliveryOptions(BuildContext context, Delivery delivery) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              delivery.customerName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              delivery.customerAddress,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _buildMobileOptionButton(
              icon: Icons.play_arrow,
              label: 'Start Delivery',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PODCaptureScreen(delivery: delivery),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildMobileOptionButton(
              icon: Icons.info,
              label: 'View Details',
              color: AppTheme.infoColor,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeliveryDetailsScreen(delivery: delivery),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildMobileOptionButton(
              icon: Icons.navigation,
              label: 'Get Directions',
              color: AppTheme.successColor,
              onTap: () {
                Navigator.of(context).pop();
                _launchNavigation(delivery.customerAddress);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.delivered:
        return AppTheme.successColor;
      case DeliveryStatus.inTransit:
        return AppTheme.infoColor;
      case DeliveryStatus.pending:
        return AppTheme.warningColor;
      default:
        return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.delivered:
        return Icons.check_circle;
      case DeliveryStatus.inTransit:
        return Icons.local_shipping;
      case DeliveryStatus.pending:
        return Icons.pending;
      default:
        return Icons.error;
    }
  }

  String _getStatusText(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.inTransit:
        return 'In Transit';
      case DeliveryStatus.pending:
        return 'Pending';
      default:
        return 'Unknown';
    }
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
}