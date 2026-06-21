import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/claim_model.dart';
import '../../models/company_claim_settings.dart';
import '../../providers/auth_provider.dart';
import '../../services/claim_service.dart';
import '../../utils/theme.dart';
import 'claim_settings_desktop.dart';

/// Responsive admin screen for configuring company claim settings
/// Automatically switches between mobile and desktop layouts based on screen width
class ClaimSettingsScreen extends StatelessWidget {
  const ClaimSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Switch to desktop layout for wide screens (> 900px)
        if (constraints.maxWidth > 900) {
          return const ClaimSettingsDesktop();
        }
        // Use mobile layout for narrow screens
        return const ClaimSettingsMobile();
      },
    );
  }
}

/// Mobile-optimized layout for claim settings
/// Allows customization of claim types, workflows, requirements, and automation rules
class ClaimSettingsMobile extends StatefulWidget {
  const ClaimSettingsMobile({super.key});

  @override
  State<ClaimSettingsMobile> createState() => _ClaimSettingsMobileState();
}

class _ClaimSettingsMobileState extends State<ClaimSettingsMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  CompanyClaimSettings? _settings;
  final _claimService = ClaimService();

  // Form controllers
  final _claimIdPrefixController = TextEditingController();
  final _claimIdStartNumberController = TextEditingController();
  final _minPhotosController = TextEditingController();
  final _maxPhotosController = TextEditingController();
  final _slaHoursController = TextEditingController();
  final _filingDeadlineController = TextEditingController();
  final _autoApproveAmountController = TextEditingController();
  final _fraudAmountController = TextEditingController();
  final _fraudFrequencyController = TextEditingController();
  final _recurringThresholdController = TextEditingController();

  // State variables
  Set<ClaimType> _selectedClaimTypes = {};
  ClaimWorkflowPreset _selectedWorkflowPreset = ClaimWorkflowPreset.standard;
  bool _photosMandatory = true;
  bool _requirePhotoImmediate = true;
  bool _requirePhotoDelayed = false;
  bool _requireCustomerSignature = false;
  bool _requireDriverSignature = false;
  bool _enableAutoApproval = false;
  Set<ClaimType> _autoApproveTypes = {};
  bool _enablePushNotifications = true;
  bool _enableEmailNotifications = false;
  bool _enableSMSNotifications = false;
  bool _enableFraudDetection = false;
  bool _enablePatternDetection = true;
  bool _allowDriverFiling = true;
  bool _allowAdminFiling = true;
  bool _allowCustomerPortal = false;
  bool _enableComments = true;
  bool _enableInternalNotes = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _claimIdPrefixController.dispose();
    _claimIdStartNumberController.dispose();
    _minPhotosController.dispose();
    _maxPhotosController.dispose();
    _slaHoursController.dispose();
    _filingDeadlineController.dispose();
    _autoApproveAmountController.dispose();
    _fraudAmountController.dispose();
    _fraudFrequencyController.dispose();
    _recurringThresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null) {
        throw Exception('No company ID found');
      }

      final settings = await _claimService.getCompanySettings(companyId);

      setState(() {
        _settings = settings;
        _selectedClaimTypes = Set.from(settings.enabledClaimTypes);
        _selectedWorkflowPreset = settings.workflowPreset;
        _photosMandatory = settings.photosMandatory;
        _requirePhotoImmediate = settings.requirePhotoForImmediate;
        _requirePhotoDelayed = settings.requirePhotoForDelayed;
        _requireCustomerSignature = settings.requireCustomerSignature;
        _requireDriverSignature = settings.requireDriverSignature;
        _enableAutoApproval = settings.enableAutoApproval;
        _autoApproveTypes = Set.from(settings.autoApproveTypes ?? []);
        _enablePushNotifications = settings.enablePushNotifications;
        _enableEmailNotifications = settings.enableEmailNotifications;
        _enableSMSNotifications = settings.enableSMSNotifications;
        _enableFraudDetection = settings.enableFraudDetection;
        _enablePatternDetection = settings.enablePatternDetection;
        _allowDriverFiling = settings.allowDriverFiling;
        _allowAdminFiling = settings.allowAdminFiling;
        _allowCustomerPortal = settings.allowCustomerPortal;
        _enableComments = settings.enableComments;
        _enableInternalNotes = settings.enableInternalNotes;

        // Set text controllers
        _claimIdPrefixController.text = settings.claimIdPrefix;
        _claimIdStartNumberController.text =
            settings.claimIdStartNumber.toString();
        _minPhotosController.text = settings.minPhotosRequired.toString();
        _maxPhotosController.text = settings.maxPhotosAllowed.toString();
        _slaHoursController.text = settings.defaultSlaHours.toString();
        _filingDeadlineController.text =
            settings.claimFilingDeadlineDays?.toString() ?? '';
        _autoApproveAmountController.text =
            settings.autoApproveUnderAmount?.toString() ?? '';
        _fraudAmountController.text =
            settings.fraudThresholdAmount?.toString() ?? '';
        _fraudFrequencyController.text =
            settings.fraudThresholdFrequency?.toString() ?? '';
        _recurringThresholdController.text =
            settings.recurringClaimThreshold?.toString() ?? '3';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    setState(() => _isSaving = true);

    try {
      final updatedSettings = _settings!.copyWith(
        enabledClaimTypes: _selectedClaimTypes.toList(),
        workflowPreset: _selectedWorkflowPreset,
        photosMandatory: _photosMandatory,
        requirePhotoForImmediate: _requirePhotoImmediate,
        requirePhotoForDelayed: _requirePhotoDelayed,
        requireCustomerSignature: _requireCustomerSignature,
        requireDriverSignature: _requireDriverSignature,
        minPhotosRequired: int.tryParse(_minPhotosController.text) ?? 1,
        maxPhotosAllowed: int.tryParse(_maxPhotosController.text) ?? 10,
        defaultSlaHours: int.tryParse(_slaHoursController.text) ?? 24,
        claimFilingDeadlineDays: _filingDeadlineController.text.isNotEmpty
            ? int.tryParse(_filingDeadlineController.text)
            : null,
        enableAutoApproval: _enableAutoApproval,
        autoApproveUnderAmount: _autoApproveAmountController.text.isNotEmpty
            ? double.tryParse(_autoApproveAmountController.text)
            : null,
        autoApproveTypes:
            _autoApproveTypes.isNotEmpty ? _autoApproveTypes.toList() : null,
        enablePushNotifications: _enablePushNotifications,
        enableEmailNotifications: _enableEmailNotifications,
        enableSMSNotifications: _enableSMSNotifications,
        enableFraudDetection: _enableFraudDetection,
        fraudThresholdAmount: _fraudAmountController.text.isNotEmpty
            ? double.tryParse(_fraudAmountController.text)
            : null,
        fraudThresholdFrequency: _fraudFrequencyController.text.isNotEmpty
            ? int.tryParse(_fraudFrequencyController.text)
            : null,
        enablePatternDetection: _enablePatternDetection,
        recurringClaimThreshold: _recurringThresholdController.text.isNotEmpty
            ? int.tryParse(_recurringThresholdController.text)
            : 3,
        allowDriverFiling: _allowDriverFiling,
        allowAdminFiling: _allowAdminFiling,
        allowCustomerPortal: _allowCustomerPortal,
        enableComments: _enableComments,
        enableInternalNotes: _enableInternalNotes,
        claimIdPrefix: _claimIdPrefixController.text.isNotEmpty
            ? _claimIdPrefixController.text
            : 'CLM',
        claimIdStartNumber: int.tryParse(_claimIdStartNumberController.text) ?? 1,
        updatedAt: DateTime.now(),
      );

      await _claimService.updateCompanySettings(updatedSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'General', icon: Icon(Icons.settings, size: 20)),
            Tab(text: 'Claim Types', icon: Icon(Icons.category, size: 20)),
            Tab(text: 'Workflow', icon: Icon(Icons.account_tree, size: 20)),
            Tab(text: 'Requirements', icon: Icon(Icons.rule, size: 20)),
            Tab(text: 'Automation', icon: Icon(Icons.auto_awesome, size: 20)),
            Tab(text: 'Features', icon: Icon(Icons.star, size: 20)),
          ],
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildClaimTypesTab(),
                _buildWorkflowTab(),
                _buildRequirementsTab(),
                _buildAutomationTab(),
                _buildFeaturesTab(),
              ],
            ),
    );
  }

  // Tab 1: General Settings
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Claim ID Configuration',
            Icons.tag,
            'Customize how claim IDs are generated',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _claimIdPrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Claim ID Prefix',
                      hintText: 'CLM',
                      helperText: 'Prefix for claim IDs (e.g., CLM, CLAIM, ISS)',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _claimIdStartNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Starting Number',
                      hintText: '1',
                      helperText: 'First claim number (e.g., CLM-0001)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Preview: ${_claimIdPrefixController.text.isNotEmpty ? _claimIdPrefixController.text : 'CLM'}-${(_claimIdStartNumberController.text.isNotEmpty ? int.tryParse(_claimIdStartNumberController.text) ?? 1 : 1).toString().padLeft(4, '0')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Time Limits',
            Icons.timer,
            'Configure deadlines and SLAs',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _slaHoursController,
                    decoration: const InputDecoration(
                      labelText: 'Default SLA (hours)',
                      hintText: '24',
                      helperText: 'Default time to respond to claims',
                      border: OutlineInputBorder(),
                      suffixText: 'hours',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _filingDeadlineController,
                    decoration: const InputDecoration(
                      labelText: 'Filing Deadline (days)',
                      hintText: 'Leave empty for no deadline',
                      helperText:
                          'Max days after delivery to file claim (optional)',
                      border: OutlineInputBorder(),
                      suffixText: 'days',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: Claim Types
  Widget _buildClaimTypesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Enabled Claim Types',
            Icons.checklist,
            'Select which claim types drivers can submit',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: ${_selectedClaimTypes.length} of ${ClaimType.values.length}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ClaimType.values.map((type) {
                      final isSelected = _selectedClaimTypes.contains(type);
                      return FilterChip(
                        label: Text(_getClaimTypeDisplayName(type)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedClaimTypes.add(type);
                            } else {
                              _selectedClaimTypes.remove(type);
                            }
                          });
                        },
                        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.primaryColor,
                        avatar: isSelected
                            ? const Icon(Icons.check_circle, size: 18)
                            : const Icon(Icons.circle_outlined, size: 18),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedClaimTypes = Set.from(ClaimType.values);
                          });
                        },
                        icon: const Icon(Icons.select_all),
                        label: const Text('Select All'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedClaimTypes.clear();
                          });
                        },
                        icon: const Icon(Icons.deselect),
                        label: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Drivers can only file claims for enabled types. At least one type must be selected.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[900],
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

  // Tab 3: Workflow
  Widget _buildWorkflowTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Approval Workflow',
            Icons.account_tree,
            'Configure how claims are reviewed and approved',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Workflow Preset',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...ClaimWorkflowPreset.values.map((preset) {
                    return RadioListTile<ClaimWorkflowPreset>(
                      title: Text(preset.displayName),
                      subtitle: Text(_getWorkflowDescription(preset)),
                      value: preset,
                      groupValue: _selectedWorkflowPreset,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedWorkflowPreset = value);
                        }
                      },
                      activeColor: AppTheme.primaryColor,
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedWorkflowPreset != ClaimWorkflowPreset.custom)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Workflow Levels',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._selectedWorkflowPreset
                        .getDefaultWorkflow()
                        .asMap()
                        .entries
                        .map((entry) {
                      final index = entry.key;
                      final role = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    role.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'SLA: ${role.slaHours} hours',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green[600],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          if (_selectedWorkflowPreset == ClaimWorkflowPreset.custom)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.construction, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Custom Workflow Builder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Custom workflow configuration will be available in a future update',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Tab 4: Requirements
  Widget _buildRequirementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Photo Requirements',
            Icons.photo_camera,
            'Configure photo evidence requirements',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Photos Mandatory'),
                    subtitle: const Text('Require at least one photo'),
                    value: _photosMandatory,
                    onChanged: (value) {
                      setState(() => _photosMandatory = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Require Photo for Immediate Claims'),
                    subtitle: const Text('Filed at delivery site'),
                    value: _requirePhotoImmediate,
                    onChanged: (value) {
                      setState(() => _requirePhotoImmediate = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Require Photo for Delayed Claims'),
                    subtitle: const Text('Filed after delivery'),
                    value: _requirePhotoDelayed,
                    onChanged: (value) {
                      setState(() => _requirePhotoDelayed = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: _minPhotosController,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Photos Required',
                      hintText: '1',
                      border: OutlineInputBorder(),
                      suffixText: 'photos',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _maxPhotosController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Photos Allowed',
                      hintText: '10',
                      border: OutlineInputBorder(),
                      suffixText: 'photos',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Signature Requirements',
            Icons.draw,
            'Configure signature requirements',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Require Customer Signature'),
                    subtitle: const Text('Customer must sign claim form'),
                    value: _requireCustomerSignature,
                    onChanged: (value) {
                      setState(() => _requireCustomerSignature = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Require Driver Signature'),
                    subtitle: const Text('Driver must sign claim form'),
                    value: _requireDriverSignature,
                    onChanged: (value) {
                      setState(() => _requireDriverSignature = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 5: Automation
  Widget _buildAutomationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Auto-Approval Rules',
            Icons.auto_awesome,
            'Automatically approve claims meeting criteria',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Auto-Approval'),
                    subtitle: const Text('Automatically approve eligible claims'),
                    value: _enableAutoApproval,
                    onChanged: (value) {
                      setState(() => _enableAutoApproval = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  if (_enableAutoApproval) ...[
                    const Divider(height: 32),
                    TextField(
                      controller: _autoApproveAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Auto-Approve Under Amount',
                        hintText: 'Leave empty for no limit',
                        helperText:
                            'Claims below this amount will be auto-approved',
                        border: OutlineInputBorder(),
                        prefixText: 'R',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Auto-Approve Claim Types:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedClaimTypes.map((type) {
                        final isSelected = _autoApproveTypes.contains(type);
                        return FilterChip(
                          label: Text(_getClaimTypeDisplayName(type)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _autoApproveTypes.add(type);
                              } else {
                                _autoApproveTypes.remove(type);
                              }
                            });
                          },
                          selectedColor: Colors.green[100],
                          checkmarkColor: Colors.green[700],
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Fraud Detection',
            Icons.security,
            'Detect potentially fraudulent claims',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Fraud Detection'),
                    subtitle: const Text('Flag suspicious claim patterns'),
                    value: _enableFraudDetection,
                    onChanged: (value) {
                      setState(() => _enableFraudDetection = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  if (_enableFraudDetection) ...[
                    const Divider(height: 32),
                    TextField(
                      controller: _fraudAmountController,
                      decoration: const InputDecoration(
                        labelText: 'High-Value Threshold',
                        hintText: 'e.g., 1000',
                        helperText: 'Flag claims above this amount',
                        border: OutlineInputBorder(),
                        prefixText: 'R',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fraudFrequencyController,
                      decoration: const InputDecoration(
                        labelText: 'Frequency Threshold',
                        hintText: 'e.g., 5',
                        helperText: 'Flag if driver files X claims per month',
                        border: OutlineInputBorder(),
                        suffixText: 'claims/month',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Pattern Detection',
            Icons.pattern,
            'Identify recurring claim patterns',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Pattern Detection'),
                    subtitle: const Text('Detect recurring issues'),
                    value: _enablePatternDetection,
                    onChanged: (value) {
                      setState(() => _enablePatternDetection = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  if (_enablePatternDetection) ...[
                    const Divider(height: 32),
                    TextField(
                      controller: _recurringThresholdController,
                      decoration: const InputDecoration(
                        labelText: 'Recurring Claim Threshold',
                        hintText: '3',
                        helperText:
                            'Same issue X times = pattern (notify management)',
                        border: OutlineInputBorder(),
                        suffixText: 'occurrences',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 6: Features
  Widget _buildFeaturesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Filing Permissions',
            Icons.person_add,
            'Control who can file claims',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Allow Driver Filing'),
                    subtitle: const Text('Drivers can file claims via mobile app'),
                    value: _allowDriverFiling,
                    onChanged: (value) {
                      setState(() => _allowDriverFiling = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Allow Admin Filing'),
                    subtitle: const Text('Admins can file claims on behalf of drivers'),
                    value: _allowAdminFiling,
                    onChanged: (value) {
                      setState(() => _allowAdminFiling = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Customer Portal'),
                    subtitle: const Text('Customers can view/file claims (coming soon)'),
                    value: _allowCustomerPortal,
                    onChanged: null, // Disabled for now
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Communication Features',
            Icons.chat,
            'Enable collaboration features',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Comments'),
                    subtitle: const Text('Users can add comments to claims'),
                    value: _enableComments,
                    onChanged: (value) {
                      setState(() => _enableComments = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Enable Internal Notes'),
                    subtitle: const Text('Admin-only internal notes'),
                    value: _enableInternalNotes,
                    onChanged: (value) {
                      setState(() => _enableInternalNotes = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Notifications',
            Icons.notifications,
            'Configure notification channels',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('In-app notifications'),
                    value: _enablePushNotifications,
                    onChanged: (value) {
                      setState(() => _enablePushNotifications = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Send email updates'),
                    value: _enableEmailNotifications,
                    onChanged: (value) {
                      setState(() => _enableEmailNotifications = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('SMS Notifications'),
                    subtitle: const Text('Send SMS alerts (additional charges apply)'),
                    value: _enableSMSNotifications,
                    onChanged: (value) {
                      setState(() => _enableSMSNotifications = value);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getClaimTypeDisplayName(ClaimType type) {
    switch (type) {
      case ClaimType.damaged:
        return 'Damaged Goods';
      case ClaimType.shortage:
        return 'Shortage';
      case ClaimType.shortWeight:
        return 'Short Weight';
      case ClaimType.missing:
        return 'Missing Items';
      case ClaimType.wrongItems:
        return 'Wrong Items';
      case ClaimType.returns:
        return 'Returns';
      case ClaimType.priceError:
        return 'Price Error';
      case ClaimType.lateDelivery:
        return 'Late Delivery';
      case ClaimType.didNotDeliver:
        return 'Did Not Deliver';
      case ClaimType.qualityIssue:
        return 'Quality Issue';
      case ClaimType.temperatureIssue:
        return 'Temperature Issue';
      case ClaimType.packagingIssue:
        return 'Packaging Issue';
      case ClaimType.expiryIssue:
        return 'Expiry Issue';
      case ClaimType.serviceIssue:
        return 'Service Issue';
      case ClaimType.other:
        return 'Other';
    }
  }

  String _getWorkflowDescription(ClaimWorkflowPreset preset) {
    switch (preset) {
      case ClaimWorkflowPreset.simple:
        return 'Direct admin approval (fastest)';
      case ClaimWorkflowPreset.standard:
        return 'Manager → Admin (recommended)';
      case ClaimWorkflowPreset.enterprise:
        return 'Manager → Approver → Processor → Reviewer';
      case ClaimWorkflowPreset.custom:
        return 'Build your own workflow';
    }
  }
}
