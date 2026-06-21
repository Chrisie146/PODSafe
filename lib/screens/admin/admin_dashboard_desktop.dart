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
import 'customer_creation_screen.dart';
import 'admin_settings_screen.dart';

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

  // Header dropdown menu builder
  Widget _buildHeaderDropdown({
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
          _buildHeaderDropdown(
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
          _buildHeaderDropdown(
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
          _buildHeaderDropdown(
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
          _buildHeaderDropdown(
            label: 'Import',
            icon: Icons.upload_file,
            items: [
              _DropdownMenuItem(
                icon: Icons.person_add,
                label: 'Create Customers',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerCreationScreen(),
                  ),
                ),
              ),
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
          _buildHeaderDropdown(
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
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          
          // Logout
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
                  // Combined Company & Welcome Card (Full Width)
                  _buildCombinedCompanyWelcomeCard(authProvider, themeProvider),
                  
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
                  
                  // Recent Deliveries (Full Width)
                  _buildRecentDeliveriesSection(),
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
                  _loadDashboardData();
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
                              _showHelpDialog();
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.lightbulb, color: Color(0xFFFF9800)),
                            title: const Text('Quick Tips'),
                            subtitle: const Text('Helpful usage tips'),
                            onTap: () {
                              Navigator.pop(context);
                              _showQuickTipsDialog();
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.contact_support, color: Color(0xFF9C27B0)),
                            title: const Text('Support'),
                            subtitle: const Text('Contact information'),
                            onTap: () {
                              Navigator.pop(context);
                              _showSupportDialog();
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

  Widget _buildCombinedCompanyWelcomeCard(AuthProvider authProvider, ThemeProvider themeProvider) {
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
                        // Prefer company.logoUrl if set, otherwise fall back to branded app logo
                        child: (company.logoUrl ?? appLogoUrl) != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  company.logoUrl ?? appLogoUrl!,
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

                            // Address (full) - allow 2 lines
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    company.address.isNotEmpty ? company.address : '—',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 2,
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
                                  flex: 1,
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
                            const SizedBox(height: 8),
                            // Extra info row: Phone, Plan, Member Since
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  company.phone.isNotEmpty ? company.phone : '—',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(width: 12),
                                if (company.plan.toLowerCase() != 'free') ...[
                                  Icon(Icons.workspace_premium, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    company.plan.toUpperCase(),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                ],
                                const SizedBox(width: 12),
                                // Subtle active indicator (dot only on desktop, tooltip on hover)
                                Tooltip(
                                  message: company.isActive ? 'Active' : 'Inactive',
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: company.isActive ? primaryColor : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('MMM d, yyyy').format(company.createdAt),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                if (company.lastBackupDate != null) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.backup, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(company.lastBackupDate!),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                ],
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
                            const SizedBox(height: 8),
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
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            _buildStatCard(
              title: 'Pending',
              value: _pendingDeliveries.toString(),
              subtitle: 'Awaiting pickup',
              icon: Icons.pending_actions,
              color: AppTheme.warningColor,
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            _buildStatCard(
              title: 'In Transit',
              value: _inTransitDeliveries.toString(),
              subtitle: 'On the road',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.infoColor,
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            _buildStatCard(
              title: 'Completed',
              value: _completedDeliveries.toString(),
              subtitle: 'Delivered today',
              icon: Icons.check_circle,
              color: AppTheme.successColor,
              width: cardWidth,
              onTap: () => Navigator.pushNamed(context, '/admin/deliveries'),
            ),
            _buildStatCard(
              title: 'Active Drivers',
              value: _activeDrivers.toString(),
              subtitle: '$_totalDrivers total drivers',
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
            _buildStatCard(
              title: 'Pending Approvals',
              value: _pendingApprovals.toString(),
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
            _buildStatCard(
              title: 'Claims',
              value: _pendingClaims.toString(),
              subtitle: '$_totalClaims total claims',
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
            _buildStatCard(
              title: 'PODs Today',
              value: _totalPODs.toString(),
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

  Widget _buildStatCard({
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
                  final error = snapshot.error;
                  
                  // Handle permission errors specifically
                  if (error is FirebaseException && error.code == 'permission-denied') {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.lock_outline, size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 16),
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
                            'Security rules are still updating. Please refresh in a moment.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // Generic error
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                        const SizedBox(height: 12),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
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

  void _showHelpDialog() {
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

  void _showQuickTipsDialog() {
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

  void _showSupportDialog() {
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

  void _showLogoutDialog() {
    final stateContext = context;
    showDialog(
      context: stateContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final authProvider = stateContext.read<AuthProvider>();
              await authProvider.signOut();
              if (!stateContext.mounted) return;
              Navigator.pushReplacementNamed(stateContext, '/login');
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
}

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
