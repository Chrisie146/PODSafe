import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../utils/datetime_helper.dart';
import '../../utils/error_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/company_model.dart';
import 'claims_dashboard_screen.dart';
import 'user_management_screen.dart';
import 'vehicle_management_desktop.dart';
import 'abaserve_import_screen.dart';
import 'admin_settings_screen.dart';

// ============================================================================
// BACKUP FILE - CREATED BEFORE HEADER QUICK ACTIONS REDESIGN
// Date: November 12, 2025
// Purpose: Backup before moving quick actions to header dropdown menus
// Original layout: Quick Actions sidebar + Recent Deliveries
// New layout: Header dropdowns + Analytics sidebar
// ============================================================================

class AdminDashboardDesktop extends StatefulWidget {
  const AdminDashboardDesktop({super.key});

  @override
  State<AdminDashboardDesktop> createState() => _AdminDashboardDesktopState();
}

class _AdminDashboardDesktopState extends State<AdminDashboardDesktop> {
  // Today's stats
  int _totalDeliveries = 0;
  int _pendingDeliveries = 0;
  int _inTransitDeliveries = 0;
  int _completedDeliveries = 0;
  int _activeDrivers = 0;
  int _totalDrivers = 0;
  int _pendingApprovals = 0;
  int _totalClaims = 0;
  int _pendingClaims = 0;
  int _totalPODs = 0;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final authProvider = context.read<AuthProvider>();
      final themeProvider = context.read<ThemeProvider>();
      final companyId = authProvider.currentUser?.companyId;
      
      if (companyId == null || companyId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Load branding settings without notifying during build phase
      await themeProvider.loadBrandingSettings(companyId, notifyOnComplete: false);
      debugPrint('Loaded branding settings - Logo URL: ${themeProvider.appLogoUrl}');
      // Now notify listeners that data is ready
      themeProvider.notifyLoadingComplete();

        final currentUserId = authProvider.currentUser?.id;
        final currentUserRole = authProvider.currentUser?.role;
        final currentUserIsActive = authProvider.currentUser?.isActive;
        debugPrint('AdminDashboardDesktop - auth uid: $currentUserId, role: $currentUserRole, isActive: $currentUserIsActive, companyId: $companyId');

        // Verify Firestore user document exists and is readable
        try {
          if (currentUserId != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
            debugPrint('AdminDashboardDesktop - userDoc data: ${userDoc.data()}');
          }
        } catch (e) {
          debugPrint('AdminDashboardDesktop - error reading user doc: $e');
          if (e is FirebaseException && e.code == 'permission-denied') {
            if (mounted) {
              ErrorHandler.showErrorSnackBar(context, 'Permission denied reading your user profile. Check Firestore rules and ensure your user document exists and has isActive=true and role="admin".');
            }
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }
      // Get today's date range in South African timezone
      final now = getSouthAfricanTime();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get all deliveries for today
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      // Count deliveries by status
      int total = deliveriesSnapshot.docs.length;
      int pending = 0;
      int inTransit = 0;
      int completed = 0;

      for (var doc in deliveriesSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'delivered') {
          completed++;
        } else if (status == 'inTransit') {
          inTransit++;
        } else {
          pending++;
        }
      }

      // Get all drivers
      final allDriversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('companyId', isEqualTo: companyId)
          .get();

      // Count approved vs pending drivers
      int activeDriversCount = 0;
      int pendingApprovalsCount = 0;
      
      for (var doc in allDriversSnapshot.docs) {
        final approvalStatus = doc.data()['approvalStatus'] as String?;
        if (approvalStatus == 'approved') {
          activeDriversCount++;
        } else if (approvalStatus == 'pending') {
          pendingApprovalsCount++;
        }
      }

      // Get claims count
      final claimsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .get();
      
      int totalClaimsCount = claimsSnapshot.docs.length;
      int pendingClaimsCount = 0;
      
      for (var doc in claimsSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'open' || status == 'pending') {
          pendingClaimsCount++;
        }
      }

      // Get PODs count (today)
      final podsSnapshot = await FirebaseFirestore.instance
          .collection('pods')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      if (mounted) {
        setState(() {
          _totalDeliveries = total;
          _pendingDeliveries = pending;
          _inTransitDeliveries = inTransit;
          _completedDeliveries = completed;
          _activeDrivers = activeDriversCount;
          _totalDrivers = allDriversSnapshot.docs.length;
          _pendingApprovals = pendingApprovalsCount;
          _totalClaims = totalClaimsCount;
          _pendingClaims = pendingClaimsCount;
          _totalPODs = podsSnapshot.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // App Logo if available
            if (themeProvider.appLogoUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    themeProvider.appLogoUrl!,
                    height: 32,
                    width: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image, size: 32, color: Colors.white),
                  ),
                ),
              ),
            const Text('Admin Dashboard'),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Desktop',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Tooltip(
            message: 'Live Tracking',
            child: IconButton(
              icon: const Icon(Icons.map),
              onPressed: () => Navigator.pushNamed(context, '/admin/live-tracking'),
              tooltip: 'Live Tracking Map',
            ),
          ),
          Tooltip(
            message: 'Chat',
            child: IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => Navigator.pushNamed(context, '/admin/chat'),
              tooltip: 'Open Chat',
            ),
          ),
          Tooltip(
            message: 'Settings',
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSettingsScreen(),
                  ),
                );
                // Refresh dashboard data when returning from settings
                if ((result == true || result == null) && mounted) {
                  _loadDashboardData();
                }
              },
            ),
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
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section & Company Info (Side by side)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildWelcomeCard(authProvider),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildCompanyInfoCard(authProvider, themeProvider),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats Grid (4 columns)
                  const Text(
                    'Today\'s Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  
                  const SizedBox(height: 32),
                  
                  // Keyboard Shortcuts Bar
                  // _buildKeyboardShortcutsBar(),
                  
                  const SizedBox(height: 32),
                  
                  // Quick Actions & Recent Activity (Side by side)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildQuickActionsSection(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: _buildRecentDeliveriesSection(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(AuthProvider authProvider) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 36,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authProvider.currentUser?.fullName ?? 'Admin',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfoCard(AuthProvider authProvider, ThemeProvider themeProvider) {
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
              padding: const EdgeInsets.all(24),
              child: Row(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Loading company info...'),
                ],
              ),
            ),
          );
        }

        if (!snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final company = Company.fromFirestore(snapshot.data!);
        
        // Watch ThemeProvider to rebuild when logo changes
        final appLogoUrl = context.watch<ThemeProvider>().appLogoUrl;
        final primaryColor = context.watch<ThemeProvider>().primaryColor;
        
        debugPrint('Building company info card - appLogoUrl: $appLogoUrl');

        return Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Display app logo if available, otherwise show business icon
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: appLogoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                appLogoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Logo load error: $error');
                                  return Icon(Icons.image, color: primaryColor, size: 32);
                                },
                              ),
                            )
                          : Icon(
                              Icons.business,
                              color: primaryColor,
                              size: 32,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            company.email,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                // Backup Status
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_download,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Last Backup:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        company.lastBackupDate != null
                            ? 'on ${DateFormat('MMM d, yyyy at HH:mm').format(company.lastBackupDate!)}'
                            : 'Never',
                        style: TextStyle(
                          fontSize: 13,
                          color: company.lastBackupDate != null
                              ? Colors.green[600]
                              : Colors.orange[600],
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 72) / 4; // 4 columns with spacing
        
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildStatCard(
              title: 'Total Deliveries',
              value: _totalDeliveries.toString(),
              subtitle: 'Scheduled today',
              icon: Icons.local_shipping,
              color: AppTheme.primaryColor,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Pending',
              value: _pendingDeliveries.toString(),
              subtitle: 'Awaiting pickup',
              icon: Icons.pending_actions,
              color: AppTheme.warningColor,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'In Transit',
              value: _inTransitDeliveries.toString(),
              subtitle: 'On the road',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.infoColor,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Completed',
              value: _completedDeliveries.toString(),
              subtitle: 'Delivered today',
              icon: Icons.check_circle,
              color: AppTheme.successColor,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Active Drivers',
              value: _activeDrivers.toString(),
              subtitle: '$_totalDrivers total drivers',
              icon: Icons.person,
              color: const Color(0xFF2196F3),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Pending Approvals',
              value: _pendingApprovals.toString(),
              subtitle: 'Driver applications',
              icon: Icons.person_add,
              color: const Color(0xFFFF9800),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Claims',
              value: _pendingClaims.toString(),
              subtitle: '$_totalClaims total claims',
              icon: Icons.report_problem,
              color: const Color(0xFFFF5722),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'PODs Today',
              value: _totalPODs.toString(),
              subtitle: 'Proof of delivery',
              icon: Icons.receipt_long,
              color: const Color(0xFF9C27B0),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
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
        child: Stack(
          children: [
            // Gradient background overlay (hidden by default)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [color, color.withValues(alpha: 0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              title: 'New Delivery',
              icon: Icons.add_box,
              color: AppTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'View Deliveries',
              icon: Icons.list_alt,
              color: AppTheme.infoColor,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Manage Drivers',
              icon: Icons.people,
              color: const Color(0xFFFF9800),
              onTap: () => Navigator.pushNamed(context, '/admin/drivers'),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Vehicle Management',
              icon: Icons.directions_car,
              color: const Color(0xFF00BCD4),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VehicleManagementDesktop(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'User Management',
              icon: Icons.admin_panel_settings,
              color: const Color(0xFF673AB7), // Deep Purple
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Import Customers',
              icon: Icons.upload_file,
              color: const Color(0xFF00BCD4),
              onTap: () => Navigator.pushNamed(context, '/admin/customers/import'),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Import from Abaserve',
              icon: Icons.file_download,
              color: const Color(0xFF4CAF50),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AbaserveImportScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Item Catalog',
              icon: Icons.inventory_2,
              color: const Color(0xFF9C27B0), // Purple
              onTap: () => Navigator.pushNamed(context, '/admin/catalog'),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'View PODs',
              icon: Icons.receipt_long,
              color: AppTheme.successColor,
              onTap: () => Navigator.pushNamed(context, '/admin/pods'),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Claims Management',
              icon: Icons.report_problem,
              color: const Color(0xFFFF5722),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClaimsDashboardScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              title: 'Analytics & Reports',
              icon: Icons.analytics,
              color: const Color(0xFF9C27B0),
              onTap: () => Navigator.pushNamed(context, '/admin/analytics'),
            ),
            const SizedBox(height: 12),
            // Reports - Hidden for now, will implement later
            // _buildActionButton(
            //   title: 'Reports',
            //   icon: Icons.table_chart,
            //   color: const Color(0xFF00BCD4),
            //   onTap: () => Navigator.pushNamed(context, '/admin/reports'),
            // ),
            // const SizedBox(height: 12),
            // Business Central Integration - Hidden
            // _buildActionButton(
            //   title: 'Business Central Integration',
            //   icon: Icons.cloud_sync,
            //   color: const Color(0xFF4CAF50),
            //   onTap: () => Navigator.pushNamed(context, '/admin/bc-settings'),
            // ),
            // Backup moved to Settings screen - remove from dashboard
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDeliveriesSection() {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId == null || companyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Deliveries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/admin/deliveries'),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deliveries')
                  .where('companyId', isEqualTo: companyId)
                  .orderBy('createdAt', descending: true)
                  .limit(8)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                        const SizedBox(height: 12),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No deliveries yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/admin/deliveries'),
                          child: const Text('Create your first delivery'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final status = data['status'] as String? ?? 'pending';
                    final customerName = data['customerName'] as String? ?? 'Unknown';
                    final address = data['customerAddress'] as String? ?? 'No address';
                    final scheduledDate = (data['scheduledDate'] as Timestamp?)?.toDate();
                    
                    Color statusColor;
                    IconData statusIcon;
                    switch (status) {
                      case 'delivered':
                        statusColor = AppTheme.successColor;
                        statusIcon = Icons.check_circle;
                        break;
                      case 'inTransit':
                        statusColor = AppTheme.infoColor;
                        statusIcon = Icons.local_shipping;
                        break;
                      default:
                        statusColor = AppTheme.warningColor;
                        statusIcon = Icons.pending;
                    }
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 24),
                      ),
                      title: Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Order: ${data['orderNumber'] ?? '-'} | Invoice: ${data['invoiceNumber'] ?? '-'}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Customer #: ${data['customerNumber'] ?? '-'}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (scheduledDate != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(scheduledDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        // Navigate to delivery details
                        Navigator.pushNamed(
                          context,
                          '/admin/delivery-details',
                          arguments: doc.id,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
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
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Backup functionality moved to Settings screen

  /* Unused - commenting out to prevent warnings
  Widget _buildKeyboardShortcutsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.keyboard, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            'Keyboard shortcuts:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 24),
          _buildShortcutChip('Ctrl+F', 'Search'),
          const SizedBox(width: 12),
          _buildShortcutChip('Ctrl+A', 'Select All'),
          const SizedBox(width: 12),
          _buildShortcutChip('F5', 'Refresh'),
          const SizedBox(width: 12),
          _buildShortcutChip('Esc', 'Clear'),
          const Spacer(),
          Tooltip(
            message: 'More shortcuts available',
            child: Icon(Icons.info, size: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String shortcut, String action) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            action,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  */
}
