import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

class AdminDashboardDesktop extends StatefulWidget {
  const AdminDashboardDesktop({super.key});

  @override
  State<AdminDashboardDesktop> createState() => _AdminDashboardDesktopState();
}

class _AdminDashboardDesktopState extends State<AdminDashboardDesktop> {
  // Today's stats
  int totalDeliveries = 0;
  int pendingDeliveries = 0;
  int inTransitDeliveries = 0;
  int completedDeliveries = 0;
  int activeDrivers = 0;
  int totalDrivers = 0;
  int pendingApprovals = 0;
  int totalClaims = 0;
  int pendingClaims = 0;
  int totalPODs = 0;
  
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  // Header dropdown menu builder
  Widget buildHeaderDropdown({
    required String label,
    required IconData icon,
    required List<_DropdownMenuItem> items,
  }) {
    return PopupMenuButton<VoidCallback>(
      offset: const Offset(0, 50),
      tooltip: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Colors.white,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => items
          .map((item) => PopupMenuItem<VoidCallback>(
                value: item.onTap,
                child: Row(
                  children: [
                    Icon(item.icon, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Text(item.label),
                  ],
                ),
              ))
          .toList(),
      onSelected: (callback) => callback(),
    );
  }

  Future<void> loadDashboardData() async {
    try {
      if (mounted) setState(() => isLoading = true);

      final authProvider = context.read<AuthProvider>();
      final themeProvider = context.read<ThemeProvider>();
      final companyId = authProvider.currentUser?.companyId;
      
      if (companyId == null || companyId.isEmpty) {
        if (mounted) setState(() => isLoading = false);
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
            if (mounted) setState(() => isLoading = false);
            return;
          }
        }
      // Get today's date range in South African timezone
      final now = getSouthAfricanTime();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

        // Build queries for dashboard - run them concurrently to reduce round trips
        final deliveriesQuery = FirebaseFirestore.instance
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay));

        final driversQuery = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('companyId', isEqualTo: companyId);

        final claimsQuery = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('claims');

        final podsQuery = FirebaseFirestore.instance
          .collection('pods')
          .where('companyId', isEqualTo: companyId) // IMPORTANT: scope pods by company
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));

        // Run queries in parallel
        final results = await Future.wait([
        deliveriesQuery.get(),
        driversQuery.get(),
        claimsQuery.get(),
        podsQuery.get(),
        ]);

        final deliveriesSnapshot = results[0] as QuerySnapshot;
        final allDriversSnapshot = results[1] as QuerySnapshot;
        final claimsSnapshot = results[2] as QuerySnapshot;
        final podsSnapshot = results[3] as QuerySnapshot;

      // Count deliveries by status using helper
      final deliveryMaps = deliveriesSnapshot.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
      final deliveryCounts = calculateDeliveryCounts(deliveryMaps);
      int total = deliveryCounts['total'] ?? 0;
      int pending = deliveryCounts['pending'] ?? 0;
      int inTransit = deliveryCounts['inTransit'] ?? 0;
      int completed = deliveryCounts['delivered'] ?? 0;

        // Drivers snapshot already retrieved via driversQuery in the Future.wait results
        final driverMaps = allDriversSnapshot.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
        final driverCounts = calculateDriverApprovalCounts(driverMaps);
      int activeDriversCount = driverCounts['approved'] ?? 0;
      int pendingApprovalsCount = driverCounts['pending'] ?? 0;

        // claimsSnapshot already retrieved above from results
        int totalClaimsCount = claimsSnapshot.docs.length;
      int pendingClaimsCount = 0;
      
      for (var doc in claimsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final status = data?['status'] as String?;
        if (status == 'open' || status == 'pending') {
          pendingClaimsCount++;
        }
      }

        // PODs count already retrieved from podsQuery above

      if (mounted) {
        setState(() {
          totalDeliveries = total;
          pendingDeliveries = pending;
          inTransitDeliveries = inTransit;
          completedDeliveries = completed;
          activeDrivers = activeDriversCount;
          totalDrivers = allDriversSnapshot.docs.length;
          pendingApprovals = pendingApprovalsCount;
          totalClaims = totalClaimsCount;
          pendingClaims = pendingClaimsCount;
          totalPODs = podsSnapshot.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Analytics & Reports',
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Logo if available
            if (themeProvider.appLogoUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: Image.network(
                      themeProvider.appLogoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image, size: 24, color: Colors.white),
                    ),
                  ),
                ),
              ),
            const Text(
              'Admin Dashboard',
              style: TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Desktop',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Deliveries Dropdown
          buildHeaderDropdown(
            label: 'Deliveries',
            icon: Icons.local_shipping,
            items: [
              _DropdownMenuItem(
                icon: Icons.add_box,
                label: 'New Delivery',
                onTap: () => Navigator.pushNamed(context, '/admin/deliveries/create'),
              ),
              _DropdownMenuItem(
                icon: Icons.list_alt,
                label: 'View Deliveries',
                onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          
          // Management Dropdown
          buildHeaderDropdown(
            label: 'Management',
            icon: Icons.admin_panel_settings,
            items: [
              _DropdownMenuItem(
                icon: Icons.people,
                label: 'Drivers',
                onTap: () => Navigator.pushNamed(context, '/admin/drivers'),
              ),
              _DropdownMenuItem(
                icon: Icons.directions_car,
                label: 'Vehicles',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VehicleManagementDesktop(),
                  ),
                ),
              ),
              _DropdownMenuItem(
                icon: Icons.person,
                label: 'Users',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                ),
              ),
              _DropdownMenuItem(
                icon: Icons.inventory_2,
                label: 'Items',
                onTap: () => Navigator.pushNamed(context, '/admin/catalog'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          
          // Claims Dropdown
          buildHeaderDropdown(
            label: 'Claims',
            icon: Icons.report_problem,
            items: [
              _DropdownMenuItem(
                icon: Icons.dashboard,
                label: 'Claims Dashboard',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClaimsDashboardScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          
          // Import Dropdown
          buildHeaderDropdown(
            label: 'Import',
            icon: Icons.upload_file,
            items: [
              _DropdownMenuItem(
                icon: Icons.people_alt,
                label: 'Import Customers',
                onTap: () => Navigator.pushNamed(context, '/admin/customers/import'),
              ),
              _DropdownMenuItem(
                icon: Icons.file_download,
                label: 'Import from Abaserve',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AbaserveImportScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          
          // Documents Dropdown
          buildHeaderDropdown(
            label: 'Documents',
            icon: Icons.receipt_long,
            items: [
              _DropdownMenuItem(
                icon: Icons.receipt,
                label: 'View PODs',
                onTap: () => Navigator.pushNamed(context, '/admin/pods'),
              ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Chat
          Tooltip(
            message: 'Chat',
            child: IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => Navigator.pushNamed(context, '/admin/chat'),
              tooltip: 'Open Chat',
            ),
          ),
          
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadDashboardData,
            tooltip: 'Refresh',
          ),
          
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => showLogoutDialog(),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Combined Company & Welcome Card (Full Width)
                  buildCombinedCompanyWelcomeCard(authProvider, themeProvider),
                  
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
                  buildStatsGrid(),
                  
                  const SizedBox(height: 32),
                  
                  // Recent Deliveries (Full Width)
                  buildRecentDeliveriesSection(),
                ],
              ),
            ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: themeProvider.primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.analytics,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Analytics & Reports',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Insights and data visualization',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Color(0xFF9C27B0)),
              title: const Text('Analytics Dashboard'),
              subtitle: const Text('View comprehensive analytics'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/analytics');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.map, color: Color(0xFF2196F3)),
              title: const Text('Live Tracking'),
              subtitle: const Text('View live delivery tracking'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/live-tracking');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFF607D8B)),
              title: const Text('Settings'),
              subtitle: const Text('Configure application settings'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSettingsScreen(),
                  ),
                );
                // Refresh dashboard data when returning from settings
                if ((result == true || result == null) && mounted) {
                  loadDashboardData();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFF4CAF50)),
              title: const Text('Help & Support'),
              subtitle: const Text('User guide and assistance'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Help & Support'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.book, color: Color(0xFF2196F3)),
                            title: const Text('User Guide'),
                            subtitle: const Text('Complete PODSafe documentation'),
                            onTap: () {
                              Navigator.pop(context);
                              showHelpDialog();
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.lightbulb, color: Color(0xFFFF9800)),
                            title: const Text('Quick Tips'),
                            subtitle: const Text('Helpful usage tips'),
                            onTap: () {
                              Navigator.pop(context);
                              showQuickTipsDialog();
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.contact_support, color: Color(0xFF9C27B0)),
                            title: const Text('Support'),
                            subtitle: const Text('Contact information'),
                            onTap: () {
                              Navigator.pop(context);
                              showSupportDialog();
                            },
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCombinedCompanyWelcomeCard(AuthProvider authProvider, ThemeProvider themeProvider) {
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
            elevation: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: CircularProgressIndicator(),
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
        
        return Card(
          elevation: 3,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Company Section (Left)
                Expanded(
                  flex: 3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Company Logo
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: appLogoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  appLogoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint('Logo load error: $error');
                                    return Container(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.business,
                                        color: primaryColor,
                                        size: 30,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                color: primaryColor.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.business,
                                  color: primaryColor,
                                  size: 30,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Company Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Company Name
                            Text(
                              company.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            
                            // Registration Number (if available)
                            if (company.registrationNumber != null && company.registrationNumber!.isNotEmpty)
                              Text(
                                'Reg: ${company.registrationNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            
                            const SizedBox(height: 4),
                            
                            // Contact Info (Compact)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    company.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.email,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    company.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Container(
                  height: 60,
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                ),
                
                // Admin Welcome Section (Right)
                Expanded(
                  flex: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Welcome back, ${authProvider.currentUser?.fullName ?? 'Admin'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now()),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 72) / 4; // 4 columns with spacing
        
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            buildStatCard(
              title: 'Total Deliveries',
              value: totalDeliveries.toString(),
              subtitle: 'Scheduled today',
              icon: Icons.local_shipping,
              color: AppTheme.primaryColor,
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            buildStatCard(
              title: 'Pending',
              value: pendingDeliveries.toString(),
              subtitle: 'Awaiting pickup',
              icon: Icons.pending_actions,
              color: AppTheme.warningColor,
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            buildStatCard(
              title: 'In Transit',
              value: inTransitDeliveries.toString(),
              subtitle: 'On the road',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.infoColor,
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            buildStatCard(
              title: 'Completed',
              value: completedDeliveries.toString(),
              subtitle: 'Delivered today',
              icon: Icons.check_circle,
              color: AppTheme.successColor,
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            buildStatCard(
              title: 'Active Drivers',
              value: activeDrivers.toString(),
              subtitle: '$totalDrivers total drivers',
              icon: Icons.person,
              color: const Color(0xFF2196F3),
              width: cardWidth,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              ),
            ),
            buildStatCard(
              title: 'Pending Approvals',
              value: pendingApprovals.toString(),
              subtitle: 'Driver applications',
              icon: Icons.person_add,
              color: const Color(0xFFFF9800),
              width: cardWidth,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              ),
            ),
            buildStatCard(
              title: 'Claims',
              value: pendingClaims.toString(),
              subtitle: '$totalClaims total claims',
              icon: Icons.report_problem,
              color: const Color(0xFFFF5722),
              width: cardWidth,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClaimsDashboardScreen(),
                ),
              ),
            ),
            buildStatCard(
              title: 'PODs Today',
              value: totalPODs.toString(),
              subtitle: 'Proof of delivery',
              icon: Icons.receipt_long,
              color: const Color(0xFF9C27B0),
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/pods'),
            ),
          ],
        );
      },
    );
  }

  Widget buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
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
      ),
    );
  }

  Widget buildRecentDeliveriesSection() {
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
                          onPressed: () => Navigator.pushNamed(context, '/admin/deliveries/create'),
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

  void showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PODSafe User Guide'),
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
                'PODSafe is a comprehensive proof-of-delivery solution that helps you manage deliveries, track PODs, and handle claims professionally.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'Key Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Create and manage deliveries'),
              Text('• Import deliveries from ABASERVE'),
              Text('• Track delivery status in real-time'),
              Text('• View and download POD documents'),
              Text('• Manage drivers and vehicles'),
              Text('• Handle claims for damaged/missing items'),
              Text('• Generate reports and analytics'),
              SizedBox(height: 16),
              Text(
                'For detailed instructions, please refer to the complete user guide.',
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
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Open the full user guide
              const url = 'file:///C:/Users/christopherm/PODSafe/podsafe/PODSAFE_USER_GUIDE.md';
              try {
                await launchUrl(Uri.parse(url));
              } catch (e) {
                // Fallback: show a message if file can't be opened
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User guide available at: PODSAFE_USER_GUIDE.md in project root'),
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text('View Full Guide'),
          ),
        ],
      ),
    );
  }

  void showQuickTipsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Tips'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🚀 Getting Started',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Use the "New Delivery" button to create deliveries'),
              Text('• Import from ABASERVE for bulk operations'),
              Text('• Monitor delivery status in the dashboard'),
              SizedBox(height: 16),
              Text(
                '📊 Dashboard Overview',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Green = Completed deliveries'),
              Text('• Blue = In transit'),
              Text('• Orange = Pending assignments'),
              Text('• Red = Issues requiring attention'),
              SizedBox(height: 16),
              Text(
                '💡 Pro Tips',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Use filters to find specific deliveries'),
              Text('• Export data regularly for backups'),
              Text('• Check claims daily to resolve issues quickly'),
              Text('• Use the chat feature for driver communication'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support & Resources'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need help? Here are your support options:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '📧 Email Support',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('support@podsafe.com'),
              SizedBox(height: 12),
              Text(
                '📱 Documentation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Complete User Guide'),
              Text('• Feature-specific guides'),
              Text('• Troubleshooting FAQ'),
              SizedBox(height: 12),
              Text(
                '🔧 Common Issues',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Check your internet connection'),
              Text('• Ensure GPS is enabled for drivers'),
              Text('• Verify ABASERVE integration settings'),
              SizedBox(height: 12),
              Text(
                'For urgent issues, please contact support directly.',
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
          ElevatedButton(
            onPressed: () {
              // TODO: Implement email support
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support contact feature coming soon!'),
                ),
              );
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  void showLogoutDialog() {
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

  // End of State class
}

// Utility helpers exported at file scope so we can unit test them
Map<String, int> calculateDeliveryCounts(List<Map<String, dynamic>> docs) {
  int pending = 0;
  int inTransit = 0;
  int delivered = 0;
  for (var d in docs) {
    final status = (d['status'] as String?) ?? 'pending';
    if (status == 'delivered') {
      delivered++;
    } else if (status == 'inTransit') inTransit++;
    else pending++;
  }
  return {
    'total': docs.length,
    'pending': pending,
    'inTransit': inTransit,
    'delivered': delivered,
  };
}

Map<String, int> calculateDriverApprovalCounts(List<Map<String, dynamic>> docs) {
  int approved = 0;
  int pending = 0;
  for (var d in docs) {
    final approval = (d['approvalStatus'] as String?) ?? 'pending';
    if (approval == 'approved') {
      approved++;
    } else if (approval == 'pending') pending++;
  }
  return {'approved': approved, 'pending': pending};
}

  // Backup functionality moved to Settings screen

// Helper class for dropdown menu items
class _DropdownMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _DropdownMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
