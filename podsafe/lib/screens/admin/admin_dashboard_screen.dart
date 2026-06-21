import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../utils/datetime_helper.dart';
import '../../utils/error_handler.dart';
import '../../providers/auth_provider.dart';
import '../../models/company_model.dart';
import 'claims_dashboard_screen.dart';
import 'claim_settings_screen.dart';
import 'admin_dashboard_desktop.dart';
import 'user_management_screen.dart';
import 'vehicle_management_screen.dart';
import 'admin_settings_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use desktop layout for wider screens
        if (constraints.maxWidth > 1200) {
          return const AdminDashboardDesktop();
        }
        // Use mobile layout for narrower screens
        return const AdminDashboardMobile();
      },
    );
  }
}

class AdminDashboardMobile extends StatefulWidget {
  const AdminDashboardMobile({super.key});

  @override
  State<AdminDashboardMobile> createState() => _AdminDashboardMobileState();
}

class _AdminDashboardMobileState extends State<AdminDashboardMobile> {
  int _totalDeliveries = 0;
  int _pendingDeliveries = 0;
  int _completedDeliveries = 0;
  int _activeDrivers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);

      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      final currentUserId = authProvider.currentUser?.id;
      final currentUserRole = authProvider.currentUser?.role;
      final currentUserIsActive = authProvider.currentUser?.isActive;
      // Debug: Print current user info
      debugPrint('AdminDashboardMobile - auth uid: $currentUserId, role: $currentUserRole, isActive: $currentUserIsActive, companyId: $companyId');

      // Try to read the user's Firestore document to verify the stored profile and permissions
      try {
        if (currentUserId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
          debugPrint('AdminDashboardMobile - userDoc data: ${userDoc.data()}');
        }
      } catch (e) {
        debugPrint('AdminDashboardMobile - error reading user doc: $e');
        if (e is FirebaseException && e.code == 'permission-denied') {
          if (mounted) {
            ErrorHandler.showErrorSnackBar(context, 'Permission denied reading your user profile. Check Firestore rules and ensure your user document exists and has isActive=true and role="admin".');
          }
          setState(() => _isLoading = false);
          return;
        }
      }
      
      if (companyId == null || companyId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Get today's date range in South African timezone
      final now = getSouthAfricanTime();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      debugPrint('📅 Querying deliveries for date range:');
      debugPrint('   Start: $startOfDay');
      debugPrint('   End: $endOfDay');
      debugPrint('   CompanyId: $companyId');

      // Get all deliveries for this company
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      // Count deliveries by status
      int total = deliveriesSnapshot.docs.length;
      int pending = 0;
      int completed = 0;

      for (var doc in deliveriesSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'delivered') {
          completed++;
        } else {
          pending++;
        }
      }
      // Get active drivers for this company
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('companyId', isEqualTo: companyId)
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      debugPrint('👥 Active drivers: ${driversSnapshot.docs.length}');

      setState(() {
        _totalDeliveries = total;
        _pendingDeliveries = pending;
        _completedDeliveries = completed;
        _activeDrivers = driversSnapshot.docs.length;
        _isLoading = false;
      });
      
      debugPrint('✅ Dashboard data loaded: Total=$total, Pending=$pending, Completed=$completed, Drivers=${driversSnapshot.docs.length}');
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
      
      // Show user-friendly error message
      if (mounted) {
        // If permission denied, give actionable guidance
        if (e is FirebaseException && e.code == 'permission-denied') {
          ErrorHandler.showErrorSnackBar(context, 'Permission denied: check your Firestore security rules and that your user document has isActive=true and correct companyId/role.');
        } else {
          ErrorHandler.showErrorSnackBar(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(authProvider),
                    const SizedBox(height: 12),
                    
                    const SizedBox(height: 16),
                    
                    // Company Info Section
                    _buildCompanyInfoCard(authProvider),
                    
                    const SizedBox(height: 24),
                    
                    // Stats Cards
                    _buildStatsCards(),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    _buildQuickActions(),
                    
                    const SizedBox(height: 24),
                    
                    // Recent Deliveries
                    _buildRecentDeliveries(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection(AuthProvider authProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                size: 32,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${authProvider.currentUser?.fullName ?? 'Admin'}!',
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, y').format(getSouthAfricanTime()),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfoCard(AuthProvider authProvider) {
    final companyId = authProvider.currentUser?.companyId;
    
    if (companyId == null || companyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  const Text('Loading company info...'),
                ],
              ),
            ),
          );
        }

        if (!snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final company = Company.fromFirestore(snapshot.data!);

        return Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: company.logoUrl != null && company.logoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                company.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, size: 28, color: AppTheme.primaryColor),
                              ),
                            )
                          : const Icon(
                              Icons.business,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: AppTextStyles.heading3.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          if (company.registrationNumber != null && company.registrationNumber!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reg: ${company.registrationNumber}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.email, size: 12, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  company.email,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Address row
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  company.address.isNotEmpty ? company.address : '—',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 12, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                company.phone.isNotEmpty ? company.phone : '—',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(width: 12),
                              if (company.plan.toLowerCase() != 'free') ...[
                                Icon(Icons.workspace_premium, size: 12, color: AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(company.plan.toUpperCase(), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                              const SizedBox(width: 12),
                              Semantics(
                                label: 'Company status: ${company.isActive ? 'Active' : 'Inactive'}',
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: company.isActive ? AppTheme.primaryColor : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(company.isActive ? 'Active' : 'Inactive', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.calendar_today, size: 12, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(DateFormat('MMM d, yyyy').format(company.createdAt), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Share this code with drivers so they can register and join your company.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminSettingsScreen(),
                          ),
                        );
                        if ((result == true || result == null) && mounted) {
                          // refresh if settings changed
                          setState(() {});
                        }
                      },
                      child: const Text('Manage Company'),
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

  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Overview',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid
            final isWide = constraints.maxWidth > 600;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard(
                  title: 'Total Deliveries',
                  value: _totalDeliveries.toString(),
                  icon: Icons.local_shipping,
                  color: AppTheme.primaryColor,
                  width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                ),
                _buildStatCard(
                  title: 'Active Drivers',
                  value: _activeDrivers.toString(),
                  icon: Icons.person,
                  color: AppTheme.infoColor,
                  width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                ),
                _buildStatCard(
                  title: 'Pending',
                  value: _pendingDeliveries.toString(),
                  icon: Icons.pending_actions,
                  color: AppTheme.warningColor,
                  width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                ),
                _buildStatCard(
                  title: 'Completed',
                  value: _completedDeliveries.toString(),
                  icon: Icons.check_circle,
                  color: AppTheme.successColor,
                  width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive button width based on screen size
            final availableWidth = constraints.maxWidth;
            final spacing = 12.0;
            
            // Determine number of columns (2 for mobile, 3 for small tablets)
            int columns = 2;
            if (availableWidth > 600) {
              columns = 3;
            }
            if (availableWidth > 900) {
              columns = 4;
            }
            
            // Calculate button width to fit perfectly in grid
            final buttonWidth = (availableWidth - (spacing * (columns - 1))) / columns;
            
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _buildActionButton(
                  title: 'New Delivery',
                  icon: Icons.add_box,
                  color: AppTheme.primaryColor,
                  width: buttonWidth,
                  onTap: () {
                    Navigator.pushNamed(context, '/admin/deliveries/create');
                  },
                ),
                _buildActionButton(
                  title: 'View Deliveries',
                  icon: Icons.list_alt,
                  color: AppTheme.infoColor,
                  width: buttonWidth,
                  onTap: () {
                    Navigator.pushNamed(context, '/admin/deliveries');
                  },
                ),
                _buildActionButton(
                  title: 'View PODs',
                  icon: Icons.receipt_long,
                  color: AppTheme.successColor,
                  width: buttonWidth,
                  onTap: () {
                    Navigator.pushNamed(context, '/admin/pods');
                  },
                ),
                _buildActionButton(
                  title: 'Manage Drivers',
                  icon: Icons.people,
                  color: AppTheme.warningColor,
                  width: buttonWidth,
                  onTap: () {
                    Navigator.pushNamed(context, '/admin/drivers');
                  },
                ),
                _buildActionButton(
                  title: 'Vehicle Management',
                  icon: Icons.directions_car,
                  color: const Color(0xFF00BCD4), // Cyan color
                  width: buttonWidth,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehicleManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  title: 'User Management',
                  icon: Icons.admin_panel_settings,
                  color: const Color(0xFF673AB7), // Deep Purple color
                  width: buttonWidth,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  title: 'Claims Management',
                  icon: Icons.report_problem,
                  color: const Color(0xFFFF5722), // Deep Orange color
                  width: buttonWidth,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ClaimsDashboardScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  title: 'Claim Settings',
                  icon: Icons.settings,
                  color: const Color(0xFFE65100), // Dark Orange color
                  width: buttonWidth,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ClaimSettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  title: 'View Analytics & Reports',
                  icon: Icons.analytics,
                  color: const Color(0xFF9C27B0), // Purple color
                  width: buttonWidth,
                  onTap: () {
                    Navigator.pushNamed(context, '/admin/analytics');
                  },
                ),
                _buildActionButton(
                  title: 'Reports',
                  icon: Icons.table_chart,
                  color: const Color(0xFF00BCD4), // Cyan color
                  width: buttonWidth,
                  onTap: () {
                    Navigator.pushNamed(context, '/admin/reports');
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDeliveries() {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId == null || companyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Deliveries',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('deliveries')
              .where('companyId', isEqualTo: companyId)
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              
              // Handle permission errors specifically
              if (error is FirebaseException && error.code == 'permission-denied') {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'Permission Issue',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Security rules are still updating.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
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
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No deliveries yet',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status'] as String?)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(data['status'] as String?),
                        color: _getStatusColor(data['status'] as String?),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      data['customerName'] ?? 'Unknown Customer',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order: ${data['orderNumber'] ?? '-'} | Invoice: ${data['invoiceNumber'] ?? '-'}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Customer #: ${data['customerNumber'] ?? '-'}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            data['customerAddress'] ?? 'No address',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatStatus(data['status'] as String?),
                          style: TextStyle(
                            color: _getStatusColor(data['status'] as String?),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        if (data['scheduledDate'] != null)
                          Text(
                            DateFormat('MMM d').format(
                              (data['scheduledDate'] as Timestamp).toDate(),
                            ),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/admin/deliveries',
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'delivered':
        return AppTheme.successColor;
      case 'in_transit':
      case 'arrived':
        return AppTheme.infoColor;
      case 'assigned':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'in_transit':
        return Icons.local_shipping;
      case 'arrived':
        return Icons.location_on;
      case 'assigned':
        return Icons.assignment;
      default:
        return Icons.help_outline;
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    return status.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PODSafe Help'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to PODSafe!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'PODSafe helps you manage deliveries and proof-of-delivery documents professionally.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'Quick Actions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Tap "New Delivery" to create deliveries'),
              Text('• Use "View Deliveries" to manage existing ones'),
              Text('• Check "Claims" for issues'),
              Text('• Access "Analytics" for reports'),
              SizedBox(height: 16),
              Text(
                'Need more help? Check the user guide or contact support.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}