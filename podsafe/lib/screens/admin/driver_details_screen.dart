import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import 'create_driver_screen.dart';

class DriverDetailsScreen extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const DriverDetailsScreen({
    super.key,
    required this.driverId,
    required this.driverData,
  });

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  int _totalDeliveries = 0;
  int _completedDeliveries = 0;
  int _activeDeliveries = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadDriverStats();
  }

  Future<void> _loadDriverStats() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      
      if (companyId == null || companyId.isEmpty) {
        setState(() => _isLoadingStats = false);
        return;
      }

      debugPrint('📊 Loading stats for driver ${widget.driverId} in company $companyId');
      
      // Get all deliveries for this driver in this company
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('driverId', isEqualTo: widget.driverId)
          .where('companyId', isEqualTo: companyId)
          .get();

      debugPrint('📊 Found ${deliveriesSnapshot.docs.length} deliveries for driver');

      int total = deliveriesSnapshot.docs.length;
      int completed = 0;
      int active = 0;

      for (var doc in deliveriesSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'delivered') {
          completed++;
        } else if (status == 'inTransit') {
          active++;
        }
      }

      debugPrint('📊 Stats: Total=$total, Active=$active, Completed=$completed');

      setState(() {
        _totalDeliveries = total;
        _completedDeliveries = completed;
        _activeDeliveries = active;
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading driver stats: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _toggleDriverStatus() async {
    final currentStatus = widget.driverData['isActive'] ?? false;
    final newStatus = !currentStatus;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus ? 'Activate Driver' : 'Deactivate Driver'),
        content: Text(
          newStatus
              ? 'Are you sure you want to activate this driver? They will be able to receive new deliveries.'
              : 'Are you sure you want to deactivate this driver? They will no longer receive new deliveries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppTheme.successColor : AppTheme.warningColor,
            ),
            child: Text(newStatus ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.driverId)
            .update({
          'isActive': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus
                    ? 'Driver activated successfully'
                    : 'Driver deactivated successfully',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context, true);
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
  }

  Future<void> _deleteDriver() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: const Text(
          'Are you sure you want to delete this driver? This action cannot be undone. All their delivery history will be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.driverId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver deleted successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting driver: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _approveDriver() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Driver'),
        content: const Text(
          'Are you sure you want to approve this driver? They will be able to receive deliveries immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.successColor),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.driverId)
            .update({'approvalStatus': 'approved'});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver approved successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context, true);
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
  }

  Future<void> _rejectDriver() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Driver'),
        content: const Text(
          'Are you sure you want to reject this driver? They will not be able to receive deliveries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.driverId)
            .update({'approvalStatus': 'rejected'});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver rejected'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
          Navigator.pop(context, true);
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
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.driverData['displayName'] ?? 'Unknown Driver';
    final email = widget.driverData['email'] ?? 'No email';
    final phone = widget.driverData['phoneNumber'] as String?;
    final licenseNumber = widget.driverData['licenseNumber'] as String?;
    final vehicleInfo = widget.driverData['vehicleInfo'] as String?;
    final isActive = widget.driverData['isActive'] ?? false;
    final createdAt = widget.driverData['createdAt'] as Timestamp?;
    final approvalStatus = widget.driverData['approvalStatus'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDriverStats,
            tooltip: 'Refresh Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateDriverScreen(
                    driverId: widget.driverId,
                    driverData: widget.driverData,
                  ),
                ),
              );
              if (result == true && mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle_status') {
                _toggleDriverStatus();
              } else if (value == 'approve') {
                _approveDriver();
              } else if (value == 'reject') {
                _rejectDriver();
              } else if (value == 'delete') {
                _deleteDriver();
              }
            },
            itemBuilder: (context) => [
              if (approvalStatus == 'pending') ...[
                PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 20, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      const Text('Approve Driver'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      const Icon(Icons.cancel, size: 20, color: AppTheme.errorColor),
                      const SizedBox(width: 8),
                      const Text('Reject Driver'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'toggle_status',
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      size: 20,
                      color: isActive ? AppTheme.warningColor : AppTheme.successColor,
                    ),
                    const SizedBox(width: 8),
                    Text(isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('Delete Driver'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDriverStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Driver Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: isActive
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : Colors.grey.shade300,
                      child: Text(
                        _getInitials(displayName),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppTheme.successColor : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.successColor : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (approvalStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getApprovalStatusColor(approvalStatus),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _getApprovalStatusText(approvalStatus),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Statistics
            const Text(
              'Performance Statistics',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            _isLoadingStats
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          _totalDeliveries.toString(),
                          Icons.local_shipping,
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Active',
                          _activeDeliveries.toString(),
                          Icons.pending_actions,
                          AppTheme.infoColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Completed',
                          _completedDeliveries.toString(),
                          Icons.check_circle,
                          AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 20),

            // Contact Information
            const Text(
              'Contact Information',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildInfoRow('Email', email, Icons.email),
              if (phone != null) _buildInfoRow('Phone', phone, Icons.phone),
            ]),
            const SizedBox(height: 20),

            // Driver Information
            if (licenseNumber != null || vehicleInfo != null) ...[
              const Text(
                'Driver Information',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 12),
              _buildInfoCard([
                if (licenseNumber != null)
                  _buildInfoRow('License Number', licenseNumber, Icons.badge),
                if (vehicleInfo != null)
                  _buildInfoRow('Vehicle', vehicleInfo, Icons.local_shipping),
              ]),
              const SizedBox(height: 20),
            ],

            // Account Information
            const Text(
              'Account Information',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildInfoRow('Driver ID', widget.driverId.substring(0, 12), Icons.fingerprint),
              if (createdAt != null)
                _buildInfoRow(
                  'Joined',
                  DateFormat('MMMM d, y').format(createdAt.toDate()),
                  Icons.calendar_today,
                ),
            ]),
            const SizedBox(height: 20),

            // Recent Deliveries
            const Text(
              'Recent Deliveries',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            _buildRecentDeliveries(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
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
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDeliveries() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveries')
          .where('driverId', isEqualTo: widget.driverId)
          .orderBy('scheduledDate', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading deliveries: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No deliveries assigned yet',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final customerName = data['customerName'] ?? 'Unknown';
            final status = data['status'] ?? 'pending';
            final scheduledDate = (data['scheduledDate'] as Timestamp?)?.toDate();
            final orderNumber = data['orderNumber'] as String?;
            
            // Debug logging
            print('📦 Delivery for driver ${widget.driverId}: customer=$customerName, orderNumber=$orderNumber');

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                ),
                title: Text(orderNumber != null ? '$orderNumber - $customerName' : customerName),
                subtitle: scheduledDate != null
                    ? Text(DateFormat('MMM d, y').format(scheduledDate))
                    : null,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'inTransit':
        return AppTheme.infoColor;
      case 'delivered':
        return AppTheme.successColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'inTransit':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'inTransit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  Color _getApprovalStatusColor(String? approvalStatus) {
    switch (approvalStatus) {
      case 'approved':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'rejected':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _getApprovalStatusText(String? approvalStatus) {
    switch (approvalStatus) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending Approval';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }
}
