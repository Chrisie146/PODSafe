import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/theme.dart';
import '../../services/file_upload_service.dart';
import '../../services/comprehensive_backup_service.dart';
import '../../services/onboarding_service.dart';
import 'abaserve_import_screen.dart';

/// Admin settings screen for configuring system preferences
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // Loading states
  bool _isLoadingDriverSettings = true;
  bool _isLoadingCompanyInfo = true;
  bool _isSaving = false;

  // Driver Settings State
  bool _gpsTrackingEnabled = true;
  String _gpsUpdateFrequency = '30'; // seconds
  bool _gpsPrivacyMode = false;
  bool _requireDeliveryPhotos = true;
  bool _requireSignaturePhotos = true;
  bool _requireLocationPhotos = false;
  bool _offlineModeEnabled = true;
  String _syncFrequency = '15'; // minutes
  bool _autoSyncOnNetwork = true;

  // Company Information State
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _companyPhoneController = TextEditingController();
  final TextEditingController _companyAddressController = TextEditingController();
  final TextEditingController _companyWebsiteController = TextEditingController();
  final TextEditingController _companyRegistrationController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _companyDescriptionController = TextEditingController();
  String? _companyLogoUrl;

  // Branding & Theme State
  Color _primaryColor = AppTheme.primaryColor;
  Color _accentColor = Colors.blue;
  Color _warningColor = Colors.orange;
  Color _successColor = Colors.green;
  String _appName = 'PODSafe';
  bool _useDarkMode = false;

  // User Registration State
  final TextEditingController _userEmailController = TextEditingController();
  final TextEditingController _userPasswordController = TextEditingController();
  final TextEditingController _userDisplayNameController = TextEditingController();
  String _userRole = 'user'; // default role
  bool _isRegisteringUser = false;

  // Notification Settings State
  bool _emailNotificationsEnabled = true;
  bool _smsNotificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _notifyOnDeliveryComplete = true;
  bool _notifyOnDeliveryFailed = true;
  bool _notifyOnNewClaim = true;
  bool _notifyAdminsOnIssues = true;

  // Security Settings State
  int _passwordMinLength = 8;
  bool _requireSpecialCharacters = true;
  int _sessionTimeoutMinutes = 30;
  bool _enableTwoFactorAuth = false;
  bool _logAllUserActions = true;

  // Role Permissions State
  final Map<String, Set<String>> _rolePermissions = {
    'admin': {
      'view_deliveries', 'create_deliveries', 'edit_deliveries', 'delete_deliveries',
      'view_drivers', 'manage_drivers', 'view_analytics', 'manage_settings',
      'view_chats', 'send_messages', 'manage_users', 'view_reports'
    },
    'manager': {
      'view_deliveries', 'create_deliveries', 'edit_deliveries',
      'view_drivers', 'view_analytics', 'view_chats', 'send_messages', 'view_reports'
    },
    'logistics': {
      'view_deliveries', 'create_deliveries', 'edit_deliveries',
      'view_drivers', 'view_analytics', 'view_chats', 'send_messages'
    },
    'accountant': {
      'view_deliveries', 'view_analytics', 'view_reports'
    },
    'filing_clerk': {
      'view_deliveries', 'edit_deliveries', 'view_reports'
    },
    'driver': {
      'view_deliveries', 'view_chats', 'send_messages'
    },
  };

  final List<String> _availablePermissions = [
    'view_deliveries', 'create_deliveries', 'edit_deliveries', 'delete_deliveries',
    'view_drivers', 'manage_drivers', 'view_analytics', 'manage_settings',
    'view_chats', 'send_messages', 'manage_users', 'view_reports'
  ];

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      await Future.wait([
        _loadDriverSettings(user.companyId),
        _loadCompanyInformation(user.companyId),
        _loadBrandingSettings(user.companyId),
      ]);
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _companyAddressController.dispose();
    _companyWebsiteController.dispose();
    _companyRegistrationController.dispose();
    _taxNumberController.dispose();
    _companyDescriptionController.dispose();
    _userEmailController.dispose();
    _userPasswordController.dispose();
    _userDisplayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverSettings(String companyId) async {
    try {
      setState(() => _isLoadingDriverSettings = true);

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('driver')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _gpsTrackingEnabled = data['gpsTrackingEnabled'] ?? true;
          _gpsUpdateFrequency = data['gpsUpdateFrequency'] ?? '30';
          _gpsPrivacyMode = data['gpsPrivacyMode'] ?? false;
          _requireDeliveryPhotos = data['requireDeliveryPhotos'] ?? true;
          _requireSignaturePhotos = data['requireSignaturePhotos'] ?? true;
          _requireLocationPhotos = data['requireLocationPhotos'] ?? false;
          _offlineModeEnabled = data['offlineModeEnabled'] ?? true;
          _syncFrequency = data['syncFrequency'] ?? '15';
          _autoSyncOnNetwork = data['autoSyncOnNetwork'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver settings: $e');
      // Keep default values on error
    } finally {
      setState(() => _isLoadingDriverSettings = false);
    }
  }

  Future<void> _loadCompanyInformation(String companyId) async {
    try {
      setState(() => _isLoadingCompanyInfo = true);

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _companyNameController.text = data['name'] ?? '';
          _companyEmailController.text = data['email'] ?? '';
          _companyPhoneController.text = data['phone'] ?? '';
          _companyAddressController.text = data['address'] ?? '';
          _companyWebsiteController.text = data['website'] ?? '';
          _companyRegistrationController.text = data['registrationNumber'] ?? '';
          _taxNumberController.text = data['taxNumber'] ?? '';
          _companyDescriptionController.text = data['description'] ?? '';
          _companyLogoUrl = data['logoUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error loading company information: $e');
      // Keep empty/default values on error
    } finally {
      setState(() => _isLoadingCompanyInfo = false);
    }
  }

  Future<void> _loadBrandingSettings(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('branding')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _appName = data['appName'] ?? 'PODSafe';
          
          // Parse colors from stored hex strings or integers
          if (data['primaryColor'] != null) {
            _primaryColor = Color(int.parse(data['primaryColor'] as String));
          }
          if (data['accentColor'] != null) {
            _accentColor = Color(int.parse(data['accentColor'] as String));
          }
          if (data['warningColor'] != null) {
            _warningColor = Color(int.parse(data['warningColor'] as String));
          }
          if (data['successColor'] != null) {
            _successColor = Color(int.parse(data['successColor'] as String));
          }
          
          _useDarkMode = data['useDarkMode'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading branding settings: $e');
      // Keep default values on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Branding Display Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withValues(alpha: 0.1),
                      _primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryColor.withValues(alpha: 0.2), width: 2),
                      ),
                      child: _companyLogoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _companyLogoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.business, size: 40, color: _primaryColor),
                              ),
                            )
                          : Icon(Icons.business, size: 40, color: _primaryColor),
                    ),
                    const SizedBox(width: 24),
                    // Company Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _companyNameController.text.isNotEmpty
                                ? _companyNameController.text
                                : 'Company Name',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _companyEmailController.text.isNotEmpty
                                ? _companyEmailController.text
                                : 'No email set',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _appName,
                            style: TextStyle(
                              fontSize: 14,
                              color: _primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Theme Color Preview
                    Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.palette, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Primary Color',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('Company Settings'),
            _buildCompanySettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('User Management'),
            _buildUserManagementSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Role Permissions'),
            _buildRolePermissionsSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Delivery Settings'),
            _buildDeliverySettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Notification Settings'),
            _buildNotificationSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Security Settings'),
            _buildSecuritySettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Integration Settings'),
            _buildIntegrationSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('System Settings'),
            _buildSystemSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Driver Settings'),
            _buildDriverSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Claim Settings'),
            _buildClaimSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Data & Backups'),
            _buildBackupSettings(),

            const SizedBox(height: 32),
            _buildSectionHeader('Debug & Testing'),
            _buildDebugSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildCompanySettings() {
    if (_isLoadingCompanyInfo) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.business,
              title: 'Company Information',
              subtitle: 'Update company name, logo, contact details',
              onTap: () => _showCompanyInformationDialog(),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.palette,
              title: 'Branding & Theme',
              subtitle: 'Customize app colors, logos, and branding',
              onTap: () => _showBrandingThemeDialog(),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.location_on,
              title: 'Business Address',
              subtitle: 'Update business location and service areas',
              onTap: () => _showCompanyInformationDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.person_add,
              title: 'Register New User',
              subtitle: 'Add a new user to the system',
              onTap: _showUserRegistrationDialog,
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.admin_panel_settings,
              title: 'Role Permissions',
              subtitle: 'Manage user roles and access permissions',
              onTap: _showRolePermissionsDialog,
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.security,
              title: 'Access Control',
              subtitle: 'Set up multi-factor authentication and access policies',
              onTap: () => _showComingSoon('Access Control'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePermissionsSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role-Based Access Control',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Configure what each user role can access and do in the system. Changes take effect immediately.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showRolePermissionsDialog,
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Manage Role Permissions'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.schedule,
              title: 'Delivery Time Windows',
              subtitle: 'Configure default delivery time slots and scheduling',
              onTap: () => _showComingSoon('Delivery Time Windows'),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.local_shipping,
              title: 'Delivery Status Workflow',
              subtitle: 'Customize delivery status options and transitions',
              onTap: () => _showComingSoon('Delivery Status Workflow'),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.route,
              title: 'Route Optimization',
              subtitle: 'Configure route planning and optimization settings',
              onTap: () => _showComingSoon('Route Optimization'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Channels',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Enable email alerts for important events'),
              value: _emailNotificationsEnabled,
              onChanged: (value) => setState(() => _emailNotificationsEnabled = value),
            ),
            SwitchListTile(
              title: const Text('SMS Notifications'),
              subtitle: const Text('Enable SMS alerts for urgent updates'),
              value: _smsNotificationsEnabled,
              onChanged: (value) => setState(() => _smsNotificationsEnabled = value),
            ),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Enable in-app push notifications'),
              value: _pushNotificationsEnabled,
              onChanged: (value) => setState(() => _pushNotificationsEnabled = value),
            ),
            const Divider(height: 24),
            const Text(
              'Event Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Delivery Completed'),
              subtitle: const Text('Notify on successful delivery'),
              value: _notifyOnDeliveryComplete,
              onChanged: (value) => setState(() => _notifyOnDeliveryComplete = value),
            ),
            SwitchListTile(
              title: const Text('Delivery Failed'),
              subtitle: const Text('Alert when delivery fails'),
              value: _notifyOnDeliveryFailed,
              onChanged: (value) => setState(() => _notifyOnDeliveryFailed = value),
            ),
            SwitchListTile(
              title: const Text('New Claim Received'),
              subtitle: const Text('Notify on new claim submissions'),
              value: _notifyOnNewClaim,
              onChanged: (value) => setState(() => _notifyOnNewClaim = value),
            ),
            SwitchListTile(
              title: const Text('Admin Issues'),
              subtitle: const Text('Alert admins on critical issues'),
              value: _notifyAdminsOnIssues,
              onChanged: (value) => setState(() => _notifyAdminsOnIssues = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Password Requirements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSliderSetting(
              'Minimum Password Length',
              _passwordMinLength.toDouble(),
              6,
              20,
              (value) => setState(() => _passwordMinLength = value.toInt()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Require Special Characters'),
              subtitle: const Text('Passwords must include !@#\$%^&*'),
              value: _requireSpecialCharacters,
              onChanged: (value) => setState(() => _requireSpecialCharacters = value),
            ),
            const Divider(height: 24),
            const Text(
              'Session & Access',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSliderSetting(
              'Session Timeout (minutes)',
              _sessionTimeoutMinutes.toDouble(),
              5,
              120,
              (value) => setState(() => _sessionTimeoutMinutes = value.toInt()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Two-Factor Authentication'),
              subtitle: const Text('Require 2FA for admin accounts'),
              value: _enableTwoFactorAuth,
              onChanged: (value) => setState(() => _enableTwoFactorAuth = value),
            ),
            SwitchListTile(
              title: const Text('Audit Logging'),
              subtitle: const Text('Log all user actions for compliance'),
              value: _logAllUserActions,
              onChanged: (value) => setState(() => _logAllUserActions = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(String title, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildIntegrationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.sync,
              title: 'ABAServe Integration',
              subtitle: 'Import deliveries from ABAServe ERP system',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AbaserveImportScreen()),
              ),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.business,
              title: 'Business Central Integration',
              subtitle: 'Configure Microsoft Dynamics 365 Business Central connection',
              onTap: () => Navigator.of(context).pushNamed('/admin/bc-settings'),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.cloud_upload,
              title: 'Third-party APIs',
              subtitle: 'Connect with external services and APIs',
              onTap: _showApiSettingsDialog,
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.webhook,
              title: 'Webhooks',
              subtitle: 'Configure webhooks for event notifications',
              onTap: _showWebhookSettingsDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.language,
              title: 'Language & Localization',
              subtitle: 'Set default language and regional preferences',
              onTap: () => _showComingSoon('Language & Localization'),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.schedule,
              title: 'Timezone Settings',
              subtitle: 'Configure system timezone and date formats',
              onTap: () => _showComingSoon('Timezone Settings'),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.backup,
              title: 'Data Backup',
              subtitle: 'Schedule automatic backups and retention policies',
              onTap: () => _showComingSoon('Data Backup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverSettings() {
    if (_isLoadingDriverSettings) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // GPS Tracking Section
            _buildSettingItemWithSwitch(
              icon: Icons.gps_fixed,
              title: 'GPS Tracking',
              subtitle: 'Enable real-time GPS tracking for drivers',
              value: _gpsTrackingEnabled,
              onChanged: (value) => setState(() => _gpsTrackingEnabled = value),
            ),
            if (_gpsTrackingEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(left: 56, right: 16, top: 8),
                child: Column(
                  children: [
                    _buildFrequencySelector(
                      label: 'Update Frequency',
                      value: _gpsUpdateFrequency,
                      options: ['15', '30', '60', '120'],
                      unit: 'seconds',
                      onChanged: (value) => setState(() => _gpsUpdateFrequency = value),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingItemWithSwitch(
                      icon: Icons.privacy_tip,
                      title: 'Privacy Mode',
                      subtitle: 'Limit GPS data collection when not on delivery',
                      value: _gpsPrivacyMode,
                      onChanged: (value) => setState(() => _gpsPrivacyMode = value),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(),

            // Photo Requirements Section
            _buildSettingItemWithSwitch(
              icon: Icons.camera_alt,
              title: 'Require Delivery Photos',
              subtitle: 'Drivers must capture photos for each delivery',
              value: _requireDeliveryPhotos,
              onChanged: (value) => setState(() => _requireDeliveryPhotos = value),
            ),
            const Divider(),
            _buildSettingItemWithSwitch(
              icon: Icons.edit,
              title: 'Require Signature Photos',
              subtitle: 'Capture photos of customer signatures',
              value: _requireSignaturePhotos,
              onChanged: (value) => setState(() => _requireSignaturePhotos = value),
            ),
            const Divider(),
            _buildSettingItemWithSwitch(
              icon: Icons.location_on,
              title: 'Require Location Photos',
              subtitle: 'Photos showing delivery location context',
              value: _requireLocationPhotos,
              onChanged: (value) => setState(() => _requireLocationPhotos = value),
            ),
            const Divider(),

            // Offline Mode Section
            _buildSettingItemWithSwitch(
              icon: Icons.offline_pin,
              title: 'Offline Mode',
              subtitle: 'Allow drivers to work without network coverage',
              value: _offlineModeEnabled,
              onChanged: (value) => setState(() => _offlineModeEnabled = value),
            ),
            if (_offlineModeEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(left: 56, right: 16, top: 8),
                child: Column(
                  children: [
                    _buildFrequencySelector(
                      label: 'Sync Frequency',
                      value: _syncFrequency,
                      options: ['5', '15', '30', '60'],
                      unit: 'minutes',
                      onChanged: (value) => setState(() => _syncFrequency = value),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingItemWithSwitch(
                      icon: Icons.sync,
                      title: 'Auto-sync on Network',
                      subtitle: 'Automatically sync data when network is available',
                      value: _autoSyncOnNetwork,
                      onChanged: (value) => setState(() => _autoSyncOnNetwork = value),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClaimSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.assignment,
              title: 'Claim Workflows',
              subtitle: 'Configure claim approval processes and requirements',
              onTap: () => _showComingSoon('Claim Workflows'),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.attach_file,
              title: 'Required Documentation',
              subtitle: 'Set documentation requirements for claims',
              onTap: () => _showComingSoon('Required Documentation'),
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.timeline,
              title: 'Claim Processing',
              subtitle: 'Configure claim processing timeframes and SLAs',
              onTap: () => _showComingSoon('Claim Processing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.cloud_download,
              title: 'Backup All Data',
              subtitle: 'Create a full backup of company data (manual)',
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Backup All Data'),
                    content: const Text('This will create a full backup of the company data and store it in configured storage. Continue?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _backupAllData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupAllData() async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Company ID not found'), backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Backing Up Data'),
          content: StatefulBuilder(
            builder: (context, setState) {
              String message = 'Initializing backup...';
              final messageNotifier = ValueNotifier<String>(message);

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await ComprehensiveBackupService.backupAllData(
                    companyId: companyId,
                    onProgress: (progressMessage) {
                      messageNotifier.value = progressMessage;
                    },
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Backup completed successfully!'),
                        backgroundColor: AppTheme.successColor,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Backup error: $e');
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              });

              return ValueListenableBuilder<String>(
                valueListenable: messageNotifier,
                builder: (context, message, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                    ],
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        ),
      );
    }
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSettingItemWithSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
    );
  }

  Widget _buildFrequencySelector({
    required String label,
    required String value,
    required List<String> options,
    required String unit,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: $value $unit',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        DropdownButton<String>(
          value: value,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text('$option $unit'),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          underline: Container(
            height: 1,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  void _showUserRegistrationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          title: const Text('Register New User'),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(minWidth: 400, maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _userEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userDisplayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _userRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'driver', child: Text('Driver')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _userRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isRegisteringUser
                  ? null
                  : () async {
                      await _registerUser();
                      if (!_isRegisteringUser) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isRegisteringUser
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogoUpload(BuildContext dialogContext) async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;
    if (companyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company ID not found')),
        );
      }
      return;
    }
    
    final imageFile = await FileUploadService.pickImage();
    if (imageFile != null && mounted) {
      // Show loading
      showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Uploading logo...'),
            ],
          ),
        ),
      );
      
      final logoUrl = await FileUploadService.uploadAppLogo(
        companyId: companyId,
        imageFile: imageFile,
      );
      
      if (logoUrl != null) {
        final themeProvider = context.read<ThemeProvider>();
        themeProvider.setAppLogoUrl(logoUrl);
        debugPrint('ThemeProvider updated with logo URL');
      }
      
      if (mounted) Navigator.of(dialogContext).pop(); // Close loading dialog
      
      debugPrint('Upload completed. logoUrl: $logoUrl, mounted: $mounted');
      
      if (logoUrl != null && mounted) {
        debugPrint('Logo uploaded successfully: $logoUrl');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo uploaded successfully! Click Save to keep changes.')),
          );
        }
      } else {
        debugPrint('Failed to upload logo - logoUrl: $logoUrl, mounted: $mounted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload logo')),
        );
      }
    }
  }

  void _showBrandingThemeDialog() {
    // Capture the screen's context before showing the dialog
    final screenContext = context;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Branding & Theme'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Name
              TextField(
                controller: TextEditingController(text: _appName),
                onChanged: (value) => setState(() => _appName = value),
                decoration: const InputDecoration(
                  labelText: 'App Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apps),
                ),
              ),
              const SizedBox(height: 16),

              // App Logo
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: context.watch<ThemeProvider>().appLogoUrl != null
                          ? ClipOval(child: Image.network(context.watch<ThemeProvider>().appLogoUrl!, fit: BoxFit.cover))
                          : const Icon(Icons.image, size: 40, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _handleLogoUpload(screenContext),
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload App Logo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Color Pickers
              const Text(
                'Theme Colors',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),

              // Primary Color
              _buildColorPickerRow(
                label: 'Primary Color',
                color: _primaryColor,
                onTap: () => _showColorPicker(
                  'Primary Color',
                  _primaryColor,
                  (color) => setState(() => _primaryColor = color),
                ),
              ),
              const SizedBox(height: 12),

              // Accent Color
              _buildColorPickerRow(
                label: 'Accent Color',
                color: _accentColor,
                onTap: () => _showColorPicker(
                  'Accent Color',
                  _accentColor,
                  (color) => setState(() => _accentColor = color),
                ),
              ),
              const SizedBox(height: 12),

              // Warning Color
              _buildColorPickerRow(
                label: 'Warning Color',
                color: _warningColor,
                onTap: () => _showColorPicker(
                  'Warning Color',
                  _warningColor,
                  (color) => setState(() => _warningColor = color),
                ),
              ),
              const SizedBox(height: 12),

              // Success Color
              _buildColorPickerRow(
                label: 'Success Color',
                color: _successColor,
                onTap: () => _showColorPicker(
                  'Success Color',
                  _successColor,
                  (color) => setState(() => _successColor = color),
                ),
              ),
              const SizedBox(height: 16),

              // Dark Mode Toggle
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                subtitle: const Text('Enable dark theme for the application'),
                value: _useDarkMode,
                onChanged: (value) => setState(() => _useDarkMode = value),
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final themeProvider = context.read<ThemeProvider>();
              await _saveSettings();
              // Update theme provider with new values
              themeProvider.setAppName(_appName);
              themeProvider.setAppLogoUrl(themeProvider.appLogoUrl);
              themeProvider.setPrimaryColor(_primaryColor);
              themeProvider.setAccentColor(_accentColor);
              themeProvider.setWarningColor(_warningColor);
              themeProvider.setSuccessColor(_successColor);
              themeProvider.setDarkMode(_useDarkMode);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerRow({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(
    String title,
    Color initialColor,
    Function(Color) onColorChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: initialColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
              child: Center(
                child: Text(
                  '#${initialColor.value.toRadixString(16).toUpperCase().padLeft(8, '0')}',
                  style: TextStyle(
                    color: initialColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Predefined Colors:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickColorButton(AppTheme.primaryColor, onColorChanged),
                _buildQuickColorButton(Colors.blue, onColorChanged),
                _buildQuickColorButton(Colors.green, onColorChanged),
                _buildQuickColorButton(Colors.red, onColorChanged),
                _buildQuickColorButton(Colors.orange, onColorChanged),
                _buildQuickColorButton(Colors.purple, onColorChanged),
                _buildQuickColorButton(Colors.teal, onColorChanged),
                _buildQuickColorButton(Colors.indigo, onColorChanged),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickColorButton(
    Color color,
    Function(Color) onColorChanged,
  ) {
    return GestureDetector(
      onTap: () {
        onColorChanged(color);
        Navigator.of(context).pop();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
      ),
    );
  }

  void _showCompanyInformationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Company Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Company Logo
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: _companyLogoUrl != null
                          ? ClipOval(child: Image.network(_companyLogoUrl!, fit: BoxFit.cover))
                          : const Icon(Icons.business, size: 40, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final authProvider = context.read<AuthProvider>();
                        final companyId = authProvider.currentUser?.companyId;
                        if (companyId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Company ID not found')),
                          );
                          return;
                        }
                        
                        final imageFile = await FileUploadService.pickImage();
                        if (imageFile != null && mounted) {
                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Uploading logo...'),
                                ],
                              ),
                            ),
                          );
                          
                          final logoUrl = await FileUploadService.uploadCompanyLogo(
                            companyId: companyId,
                            imageFile: imageFile,
                          );
                          
                          if (mounted) Navigator.of(context).pop(); // Close loading dialog
                          
                          if (logoUrl != null && mounted) {
                            setState(() => _companyLogoUrl = logoUrl);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logo uploaded successfully')),
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to upload logo')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload Logo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Company Name
              TextField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),

              // Contact Information
              TextField(
                controller: _companyEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _companyPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _companyAddressController,
                decoration: const InputDecoration(
                  labelText: 'Business Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                keyboardType: TextInputType.streetAddress,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),

              TextField(
                controller: _companyWebsiteController,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.web),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),

              // Business Details
              TextField(
                controller: _companyRegistrationController,
                decoration: const InputDecoration(
                  labelText: 'Company Registration Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _taxNumberController,
                decoration: const InputDecoration(
                  labelText: 'Tax Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _companyDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Company Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = context.read<AuthProvider>().currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
                return;
              }

              setState(() => _isSaving = true);
              try {
                await _saveCompanyInformation(user.companyId, user.id);
                if (mounted) {
                  setState(() => _isSaving = false);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company information updated successfully'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update company information: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCompanyInformation(String companyId, String userId) async {
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .update({
          'name': _companyNameController.text,
          'email': _companyEmailController.text,
          'phone': _companyPhoneController.text,
          'address': _companyAddressController.text,
          'website': _companyWebsiteController.text,
          'registrationNumber': _companyRegistrationController.text,
          'taxNumber': _taxNumberController.text,
          'description': _companyDescriptionController.text,
          'logoUrl': _companyLogoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userId,
        });
  }

  Future<void> _saveBrandingSettings(String companyId, String userId) async {
    final themeProvider = context.read<ThemeProvider>();
    debugPrint('Saving branding settings - appLogoUrl: ${themeProvider.appLogoUrl}');
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('branding')
        .set({
          'appName': _appName,
          'appLogoUrl': themeProvider.appLogoUrl,
          'primaryColor': _primaryColor.value.toString(),
          'accentColor': _accentColor.value.toString(),
          'warningColor': _warningColor.value.toString(),
          'successColor': _successColor.value.toString(),
          'useDarkMode': _useDarkMode,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userId,
        });
    debugPrint('Branding settings saved to Firestore');
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        debugPrint('Starting save for user: ${user.id}, company: ${user.companyId}');
        await Future.wait([
          _saveDriverSettings(user.companyId, user.id),
          _saveCompanyInformation(user.companyId, user.id),
          _saveBrandingSettings(user.companyId, user.id),
        ]);
      }

      debugPrint('All settings saved successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      if (mounted) {
        setState(() => _isSaving = false);
      }

      // Return true to indicate successful save and pop back
      if (mounted) {
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      debugPrint('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveDriverSettings(String companyId, String userId) async {
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('driver')
        .set({
          'gpsTrackingEnabled': _gpsTrackingEnabled,
          'gpsUpdateFrequency': _gpsUpdateFrequency,
          'gpsPrivacyMode': _gpsPrivacyMode,
          'requireDeliveryPhotos': _requireDeliveryPhotos,
          'requireSignaturePhotos': _requireSignaturePhotos,
          'requireLocationPhotos': _requireLocationPhotos,
          'offlineModeEnabled': _offlineModeEnabled,
          'syncFrequency': _syncFrequency,
          'autoSyncOnNetwork': _autoSyncOnNetwork,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userId,
        });
  }

  Future<void> _registerUser() async {
    final email = _userEmailController.text.trim();
    final password = _userPasswordController.text.trim();
    final displayName = _userDisplayNameController.text.trim();

    if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isRegisteringUser = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      if (companyId == null) {
        throw 'Company ID not found';
      }

      // Create user with Firebase Auth
      final userCredential = await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUser = userCredential.user;
      if (newUser == null) {
        throw 'Failed to create user';
      }

      // Create user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set({
        'id': newUser.uid,
        'email': email,
        'displayName': displayName,
        'role': _userRole,
        'companyId': companyId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // Clear form
      _userEmailController.clear();
      _userPasswordController.clear();
      _userDisplayNameController.clear();
      setState(() => _userRole = 'user');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User registered successfully: $email')),
      );
    } catch (e) {
      debugPrint('Error registering user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register user: $e')),
      );
    } finally {
      setState(() => _isRegisteringUser = false);
    }
  }

  void _showRolePermissionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              title: const Text('Role Permissions Management'),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                constraints: const BoxConstraints(minWidth: 600, maxWidth: 800),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configure permissions for each role. Check the boxes to grant access.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            // Permission matrix
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade300),
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1),
                                2: FlexColumnWidth(1),
                                3: FlexColumnWidth(1),
                                4: FlexColumnWidth(1),
                                5: FlexColumnWidth(1),
                                6: FlexColumnWidth(1),
                              },
                              children: [
                                // Header row
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade100),
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Permission', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Manager', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Logistics', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Accountant', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Filing Clerk', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                  ],
                                ),
                                // Permission rows
                                ..._availablePermissions.map((permission) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(_formatPermissionName(permission)),
                                      ),
                                      ...['admin', 'manager', 'logistics', 'accountant', 'filing_clerk', 'driver'].map((role) {
                                        return Center(
                                          child: Checkbox(
                                            value: _rolePermissions[role]?.contains(permission) ?? false,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  _rolePermissions[role]?.add(permission);
                                                } else {
                                                  _rolePermissions[role]?.remove(permission);
                                                }
                                              });
                                            },
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _saveRolePermissions();
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Role permissions updated successfully')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatPermissionName(String permission) {
    return permission.split('_').map((word) =>
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Future<void> _saveRolePermissions() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      if (companyId == null) {
        throw 'Company ID not found';
      }

      // Save role permissions to Firestore
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('role_permissions')
          .set({
            'permissions': _rolePermissions,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': authProvider.currentUser?.id,
          });
    } catch (e) {
      debugPrint('Error saving role permissions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save role permissions: $e')),
      );
    }
  }

  void _showApiSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          title: const Text('Third-party API Settings'),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(minWidth: 400, maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Configure connections to external APIs and services. This feature allows you to integrate with:\n\n'
                    '• Google Maps API\n'
                    '• SMS gateways\n'
                    '• Email services\n'
                    '• Payment processors\n'
                    '• Custom ERP systems\n\n'
                    'API configurations are stored securely and encrypted.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Coming Soon',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'API management interface will be available in the next update. '
                          'For now, API keys can be configured directly in the code or environment variables.',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showWebhookSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          title: const Text('Webhook Settings'),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(minWidth: 400, maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Configure webhooks to receive real-time notifications when events occur in PODSafe. '
                    'Supported events include:\n\n'
                    '• Delivery status changes\n'
                    '• New delivery assignments\n'
                    '• POD submissions\n'
                    '• Driver location updates\n'
                    '• System alerts\n\n'
                    'Webhooks can integrate with your existing systems for automated workflows.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.build, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Under Development',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Webhook configuration interface is currently being developed. '
                          'Basic webhook support is available through Firebase Cloud Functions.',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDebugSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.refresh,
              title: 'Reset Onboarding',
              subtitle: 'Reset onboarding status to test the onboarding flow',
              onTap: () async {
                await OnboardingService.resetOnboarding();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Onboarding reset! Restart the app to see onboarding again.')),
                  );
                }
              },
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.info,
              title: 'Onboarding Debug Info',
              subtitle: 'View current onboarding status and data',
              onTap: () async {
                final debugData = await OnboardingService.getDebugData();
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Onboarding Debug Info'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: debugData.entries.map((entry) {
                          return Text('${entry.key}: ${entry.value}');
                        }).toList(),
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
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature settings coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}