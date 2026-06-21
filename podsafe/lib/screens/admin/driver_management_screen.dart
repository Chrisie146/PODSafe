import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart' as app_auth;
import 'create_driver_screen.dart';
import 'driver_details_screen.dart';
import 'driver_management_desktop.dart';

class DriverManagementScreen extends StatelessWidget {
  const DriverManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use desktop layout for wider screens
        if (constraints.maxWidth > 1000) {
          return const DriverManagementDesktop();
        }
        // Use mobile layout for narrower screens
        return const DriverManagementMobile();
      },
    );
  }
}

class DriverManagementMobile extends StatefulWidget {
  const DriverManagementMobile({super.key});

  @override
  State<DriverManagementMobile> createState() => _DriverManagementMobileState();
}

class _DriverManagementMobileState extends State<DriverManagementMobile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Driver Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.check_circle_outline),
              text: 'Approved',
            ),
            Tab(
              icon: Icon(Icons.hourglass_empty),
              text: 'Pending',
            ),
            Tab(
              icon: Icon(Icons.cancel_outlined),
              text: 'Rejected',
            ),
          ],
        ),
        actions: [
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
                hintText: 'Search by name or email...',
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
          // Driver list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDriverList('approved'),
                _buildDriverList('pending'),
                _buildDriverList('rejected'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateDriverScreen(),
            ),
          );
          if (result == true) {
            setState(() {}); // Refresh list
          }
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Driver'),
      ),
    );
  }

  Widget _buildDriverList(String approvalStatus) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getDriversStream(approvalStatus),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
                Text('Error: ${snapshot.error}'),
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
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  approvalStatus == 'approved'
                      ? 'No approved drivers'
                      : approvalStatus == 'pending'
                          ? 'No pending approvals'
                          : 'No rejected drivers',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap + to add a new driver',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter by search query
        var drivers = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['displayName'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        if (drivers.isEmpty) {
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

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driverDoc = drivers[index];
            final driverData = driverDoc.data() as Map<String, dynamic>;
            return _buildDriverCard(driverDoc.id, driverData);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getDriversStream(String approvalStatus) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final companyId = authProvider.companyId;
    
    if (companyId == null) {
      print('⚠️ No companyId found for admin');
      // Return empty stream
      return const Stream.empty();
    }
    
    print('📋 Loading drivers for company: $companyId, status: $approvalStatus');
    
    // Query drivers by company and approval status
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('companyId', isEqualTo: companyId)
        .where('approvalStatus', isEqualTo: approvalStatus)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildDriverCard(String driverId, Map<String, dynamic> driverData) {
    final displayName = driverData['displayName'] ?? driverData['fullName'] ?? 'Unknown Driver';
    final email = driverData['email'] ?? 'No email';
    final phone = driverData['phoneNumber'] as String?;
    final approvalStatus = driverData['approvalStatus'] ?? 'approved';
    final licenseNumber = driverData['licenseNumber'] as String?;
    final vehicleInfo = driverData['vehicleInfo'] as String?;
    final createdAt = driverData['createdAt'] as Timestamp?;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverDetailsScreen(
                    driverId: driverId,
                    driverData: driverData,
                  ),
                ),
              );
              if (result == true) {
                setState(() {}); // Refresh if changes were made
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Text(
                      _getInitials(displayName),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Driver info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusIcon,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    approvalStatus.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (phone != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (licenseNumber != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'License: $licenseNumber',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (vehicleInfo != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_car_outlined,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  vehicleInfo,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Registered: ${_formatDate(createdAt.toDate())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Approval actions for pending drivers
          if (approvalStatus == 'pending')
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectDriver(driverId, displayName),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approveDriver(driverId, displayName),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
      return '${date.day}/${date.month}/${date.year}';
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
