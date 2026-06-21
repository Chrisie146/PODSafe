import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/claim_model.dart';
import '../../models/company_claim_settings.dart';
import '../../providers/auth_provider.dart';
import '../../services/claim_service.dart';
import '../../utils/theme.dart';

/// Desktop-optimized Claim Settings screen with multi-column layout
/// Features: Keyboard shortcuts, side navigation, live validation, presets
class ClaimSettingsDesktop extends StatefulWidget {
  const ClaimSettingsDesktop({super.key});

  @override
  State<ClaimSettingsDesktop> createState() => _ClaimSettingsDesktopState();
}

class _ClaimSettingsDesktopState extends State<ClaimSettingsDesktop> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  CompanyClaimSettings? _settings;
  final _claimService = ClaimService();
  String _activeSection = 'general';

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
    _loadSettings();
    // Add listeners to all controllers to track changes
    _addChangeListeners();
  }

  void _addChangeListeners() {
    _claimIdPrefixController.addListener(_markUnsaved);
    _claimIdStartNumberController.addListener(_markUnsaved);
    _minPhotosController.addListener(_markUnsaved);
    _maxPhotosController.addListener(_markUnsaved);
    _slaHoursController.addListener(_markUnsaved);
    _filingDeadlineController.addListener(_markUnsaved);
    _autoApproveAmountController.addListener(_markUnsaved);
    _fraudAmountController.addListener(_markUnsaved);
    _fraudFrequencyController.addListener(_markUnsaved);
    _recurringThresholdController.addListener(_markUnsaved);
  }

  void _markUnsaved() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  final FocusNode _focusNode = FocusNode();
  
  @override
  void dispose() {
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
    _focusNode.dispose();
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
        _autoApproveTypes = settings.autoApproveTypes != null
            ? Set.from(settings.autoApproveTypes!)
            : {};
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

        _claimIdPrefixController.text = settings.claimIdPrefix;
        _claimIdStartNumberController.text = settings.claimIdStartNumber.toString();
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
            settings.recurringClaimThreshold.toString();

        _isLoading = false;
        _hasUnsavedChanges = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        claimIdStartNumber:
            int.tryParse(_claimIdStartNumberController.text) ?? 1,
        updatedAt: DateTime.now(),
      );

      await _claimService.updateCompanySettings(updatedSettings);

      setState(() {
        _settings = updatedSettings;
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+S - Save
      if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
        if (_hasUnsavedChanges && !_isSaving) {
          _saveSettings();
          return KeyEventResult.handled;
        }
      }
      // Ctrl+1-6 - Switch sections
      else if (HardwareKeyboard.instance.isControlPressed) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.digit1:
            setState(() => _activeSection = 'general');
            return KeyEventResult.handled;
          case LogicalKeyboardKey.digit2:
            setState(() => _activeSection = 'types');
            return KeyEventResult.handled;
          case LogicalKeyboardKey.digit3:
            setState(() => _activeSection = 'workflow');
            return KeyEventResult.handled;
          case LogicalKeyboardKey.digit4:
            setState(() => _activeSection = 'requirements');
            return KeyEventResult.handled;
          case LogicalKeyboardKey.digit5:
            setState(() => _activeSection = 'automation');
            return KeyEventResult.handled;
          case LogicalKeyboardKey.digit6:
            setState(() => _activeSection = 'features');
            return KeyEventResult.handled;
        }
      }
      // Esc - Discard changes confirmation
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_hasUnsavedChanges) {
          _showDiscardDialog();
        } else {
          Navigator.pop(context);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }



  Future<bool?> _showDiscardDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              _saveSettings();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _showDiscardDialog() ?? false;
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildAppBar(),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Text('Claim Settings'),
          if (_hasUnsavedChanges) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Unsaved',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      actions: [
        // Keyboard hints
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 16),
              SizedBox(width: 8),
              Text(
                'Ctrl+S to save • Ctrl+1-6 to navigate • Esc to exit',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Discard button
        if (_hasUnsavedChanges)
          TextButton.icon(
            onPressed: _showDiscardDialog,
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text(
              'Discard',
              style: TextStyle(color: Colors.white),
            ),
          ),
        // Save button
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
          ElevatedButton.icon(
            onPressed: _hasUnsavedChanges ? _saveSettings : null,
            icon: const Icon(Icons.save),
            label: const Text('Save (Ctrl+S)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasUnsavedChanges ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              disabledForegroundColor: Colors.white70,
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        // Left sidebar navigation
        Container(
          width: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey[300]!)),
          ),
          child: _buildSideNav(),
        ),
        // Main content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildSideNav() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        _buildNavItem('general', 'General', Icons.settings, '1'),
        _buildNavItem('types', 'Claim Types', Icons.category, '2'),
        _buildNavItem('workflow', 'Workflow', Icons.account_tree, '3'),
        _buildNavItem('requirements', 'Requirements', Icons.rule, '4'),
        _buildNavItem('automation', 'Automation', Icons.auto_awesome, '5'),
        _buildNavItem('features', 'Features', Icons.star, '6'),
        const Divider(height: 32),
        // Quick actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              _buildQuickAction('Load Preset', Icons.download, _loadPresetDialog),
              _buildQuickAction('Reset to Defaults', Icons.restore, _resetToDefaults),
              _buildQuickAction('Export Settings', Icons.upload, _exportSettings),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(String section, String title, IconData icon, String shortcut) {
    final isActive = _activeSection == section;
    return InkWell(
      onTap: () => setState(() => _activeSection = section),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
          border: Border(
            left: BorderSide(
              color: isActive ? AppTheme.primaryColor : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppTheme.primaryColor : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppTheme.primaryColor : Colors.grey[700],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shortcut,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeSection) {
      case 'general':
        return _buildGeneralSection();
      case 'types':
        return _buildClaimTypesSection();
      case 'workflow':
        return _buildWorkflowSection();
      case 'requirements':
        return _buildRequirementsSection();
      case 'automation':
        return _buildAutomationSection();
      case 'features':
        return _buildFeaturesSection();
      default:
        return _buildGeneralSection();
    }
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('General Settings', Icons.settings),
        const SizedBox(height: 24),
        // Two-column layout for desktop
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    title: 'Claim ID Configuration',
                    children: [
                      TextField(
                        controller: _claimIdPrefixController,
                        decoration: const InputDecoration(
                          labelText: 'Claim ID Prefix',
                          hintText: 'e.g., CLM, CLAIM',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _markUnsaved(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _claimIdStartNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Starting Number',
                          hintText: 'e.g., 1, 1000',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _markUnsaved(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Example: ${_claimIdPrefixController.text.isEmpty ? 'CLM' : _claimIdPrefixController.text}-${_claimIdStartNumberController.text.isEmpty ? '0001' : _claimIdStartNumberController.text.padLeft(4, '0')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: 'Photo Requirements',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPhotosController,
                              decoration: const InputDecoration(
                                labelText: 'Min Photos',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _markUnsaved(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxPhotosController,
                              decoration: const InputDecoration(
                                labelText: 'Max Photos',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _markUnsaved(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Photos Mandatory'),
                        subtitle: const Text('Require photos for all claims'),
                        value: _photosMandatory,
                        onChanged: (value) {
                          setState(() => _photosMandatory = value);
                          _markUnsaved();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    title: 'SLA & Deadlines',
                    children: [
                      TextField(
                        controller: _slaHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Default SLA (hours)',
                          hintText: 'e.g., 24, 48',
                          border: OutlineInputBorder(),
                          helperText: 'Time to resolve a claim',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _markUnsaved(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _filingDeadlineController,
                        decoration: const InputDecoration(
                          labelText: 'Filing Deadline (days)',
                          hintText: 'e.g., 7, 30',
                          border: OutlineInputBorder(),
                          helperText: 'Days after delivery to file claim',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _markUnsaved(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: 'Signature Requirements',
                    children: [
                      SwitchListTile(
                        title: const Text('Customer Signature'),
                        subtitle: const Text('Require customer signature'),
                        value: _requireCustomerSignature,
                        onChanged: (value) {
                          setState(() => _requireCustomerSignature = value);
                          _markUnsaved();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Driver Signature'),
                        subtitle: const Text('Require driver signature'),
                        value: _requireDriverSignature,
                        onChanged: (value) {
                          setState(() => _requireDriverSignature = value);
                          _markUnsaved();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClaimTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Claim Types', Icons.category),
        const SizedBox(height: 8),
        Text(
          'Select which claim types are available for your organization',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        // Bulk actions
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedClaimTypes = Set.from(ClaimType.values);
                });
                _markUnsaved();
              },
              icon: const Icon(Icons.select_all, size: 18),
              label: const Text('Enable All'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedClaimTypes.clear();
                });
                _markUnsaved();
              },
              icon: const Icon(Icons.deselect, size: 18),
              label: const Text('Disable All'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Grid layout for claim types
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 3,
          ),
          itemCount: ClaimType.values.length,
          itemBuilder: (context, index) {
            final type = ClaimType.values[index];
            final isSelected = _selectedClaimTypes.contains(type);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedClaimTypes.remove(type);
                  } else {
                    _selectedClaimTypes.add(type);
                  }
                });
                _markUnsaved();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedClaimTypes.add(type);
                          } else {
                            _selectedClaimTypes.remove(type);
                          }
                        });
                        _markUnsaved();
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getClaimTypeName(type),
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryColor : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWorkflowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Workflow Configuration', Icons.account_tree),
        const SizedBox(height: 24),
        _buildCard(
          title: 'Workflow Preset',
          children: [
            Text(
              'Choose a predefined workflow for your claim process',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...ClaimWorkflowPreset.values.map((preset) {
              return RadioListTile<ClaimWorkflowPreset>(
                title: Text(_getWorkflowPresetName(preset)),
                subtitle: Text(_getWorkflowPresetDescription(preset)),
                value: preset,
                groupValue: _selectedWorkflowPreset,
                onChanged: (value) {
                  setState(() => _selectedWorkflowPreset = value!);
                  _markUnsaved();
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 24),
        // Workflow visualization
        _buildCard(
          title: 'Workflow Steps',
          children: [
            _buildWorkflowVisualization(),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkflowVisualization() {
    final steps = _getWorkflowSteps(_selectedWorkflowPreset);
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;
        return Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['description']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!isLast)
              Container(
                margin: const EdgeInsets.only(left: 19),
                width: 2,
                height: 30,
                color: AppTheme.primaryColor,
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRequirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Evidence Requirements', Icons.rule),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCard(
                title: 'Photo Requirements by Type',
                children: [
                  SwitchListTile(
                    title: const Text('Immediate Claims'),
                    subtitle: const Text('Photos required for immediate filing'),
                    value: _requirePhotoImmediate,
                    onChanged: (value) {
                      setState(() => _requirePhotoImmediate = value);
                      _markUnsaved();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Delayed Claims'),
                    subtitle: const Text('Photos required for delayed filing'),
                    value: _requirePhotoDelayed,
                    onChanged: (value) {
                      setState(() => _requirePhotoDelayed = value);
                      _markUnsaved();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildCard(
                title: 'Filing Permissions',
                children: [
                  SwitchListTile(
                    title: const Text('Driver Filing'),
                    subtitle: const Text('Allow drivers to file claims'),
                    value: _allowDriverFiling,
                    onChanged: (value) {
                      setState(() => _allowDriverFiling = value);
                      _markUnsaved();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Admin Filing'),
                    subtitle: const Text('Allow admins to file claims'),
                    value: _allowAdminFiling,
                    onChanged: (value) {
                      setState(() => _allowAdminFiling = value);
                      _markUnsaved();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Customer Portal'),
                    subtitle: const Text('Allow customers to file claims'),
                    value: _allowCustomerPortal,
                    onChanged: (value) {
                      setState(() => _allowCustomerPortal = value);
                      _markUnsaved();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutomationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Automation & AI', Icons.auto_awesome),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildCard(
                    title: 'Auto-Approval',
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Auto-Approval'),
                        subtitle: const Text(
                          'Automatically approve qualifying claims',
                        ),
                        value: _enableAutoApproval,
                        onChanged: (value) {
                          setState(() => _enableAutoApproval = value);
                          _markUnsaved();
                        },
                      ),
                      if (_enableAutoApproval) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _autoApproveAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Max Auto-Approve Amount (R)',
                            hintText: 'e.g., 100.00',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _markUnsaved(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Auto-approve for these types:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...ClaimType.values.map((type) {
                          return CheckboxListTile(
                            title: Text(_getClaimTypeName(type)),
                            value: _autoApproveTypes.contains(type),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _autoApproveTypes.add(type);
                                } else {
                                  _autoApproveTypes.remove(type);
                                }
                              });
                              _markUnsaved();
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: 'Notifications',
                    children: [
                      SwitchListTile(
                        title: const Text('Push Notifications'),
                        value: _enablePushNotifications,
                        onChanged: (value) {
                          setState(() => _enablePushNotifications = value);
                          _markUnsaved();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Email Notifications'),
                        value: _enableEmailNotifications,
                        onChanged: (value) {
                          setState(() => _enableEmailNotifications = value);
                          _markUnsaved();
                        },
                      ),
                      SwitchListTile(
                        title: const Text('SMS Notifications'),
                        value: _enableSMSNotifications,
                        onChanged: (value) {
                          setState(() => _enableSMSNotifications = value);
                          _markUnsaved();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  _buildCard(
                    title: 'Fraud Detection',
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Fraud Detection'),
                        subtitle: const Text('Flag suspicious claims'),
                        value: _enableFraudDetection,
                        onChanged: (value) {
                          setState(() => _enableFraudDetection = value);
                          _markUnsaved();
                        },
                      ),
                      if (_enableFraudDetection) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _fraudAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Threshold Amount (R)',
                            hintText: 'e.g., 500.00',
                            border: OutlineInputBorder(),
                            helperText: 'Flag claims above this amount',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _markUnsaved(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _fraudFrequencyController,
                          decoration: const InputDecoration(
                            labelText: 'Frequency Threshold',
                            hintText: 'e.g., 5',
                            border: OutlineInputBorder(),
                            helperText: 'Claims per month to flag',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _markUnsaved(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: 'Pattern Detection',
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Pattern Detection'),
                        subtitle: const Text('Detect recurring issues'),
                        value: _enablePatternDetection,
                        onChanged: (value) {
                          setState(() => _enablePatternDetection = value);
                          _markUnsaved();
                        },
                      ),
                      if (_enablePatternDetection) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _recurringThresholdController,
                          decoration: const InputDecoration(
                            labelText: 'Recurring Threshold',
                            hintText: 'e.g., 3',
                            border: OutlineInputBorder(),
                            helperText: 'Same customer/driver claims to flag',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _markUnsaved(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Additional Features', Icons.star),
        const SizedBox(height: 24),
        _buildCard(
          title: 'Collaboration Features',
          children: [
            SwitchListTile(
              title: const Text('Enable Comments'),
              subtitle: const Text('Allow comments on claims'),
              value: _enableComments,
              onChanged: (value) {
                setState(() => _enableComments = value);
                _markUnsaved();
              },
            ),
            SwitchListTile(
              title: const Text('Enable Internal Notes'),
              subtitle: const Text('Private notes for internal use'),
              value: _enableInternalNotes,
              onChanged: (value) {
                setState(() => _enableInternalNotes = value);
                _markUnsaved();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Helper methods
  String _getClaimTypeName(ClaimType type) {
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

  String _getWorkflowPresetName(ClaimWorkflowPreset preset) {
    switch (preset) {
      case ClaimWorkflowPreset.simple:
        return 'Simple';
      case ClaimWorkflowPreset.standard:
        return 'Standard';
      case ClaimWorkflowPreset.enterprise:
        return 'Enterprise';
      case ClaimWorkflowPreset.custom:
        return 'Custom';
    }
  }

  String _getWorkflowPresetDescription(ClaimWorkflowPreset preset) {
    switch (preset) {
      case ClaimWorkflowPreset.simple:
        return 'Submit → Approve/Reject (Best for small teams)';
      case ClaimWorkflowPreset.standard:
        return 'Submit → Review → Approve/Reject (Balanced workflow)';
      case ClaimWorkflowPreset.enterprise:
        return 'Submit → Review → Investigate → Approve/Reject (Detailed workflow)';
      case ClaimWorkflowPreset.custom:
        return 'Fully customized workflow';
    }
  }

  List<Map<String, String>> _getWorkflowSteps(ClaimWorkflowPreset preset) {
    switch (preset) {
      case ClaimWorkflowPreset.simple:
        return [
          {'title': 'Submitted', 'description': 'Claim filed by driver or admin'},
          {'title': 'Decision', 'description': 'Approve or reject claim'},
        ];
      case ClaimWorkflowPreset.standard:
        return [
          {'title': 'Submitted', 'description': 'Claim filed by driver or admin'},
          {'title': 'Pending Review', 'description': 'Waiting for admin review'},
          {'title': 'Decision', 'description': 'Approve or reject claim'},
        ];
      case ClaimWorkflowPreset.enterprise:
        return [
          {'title': 'Submitted', 'description': 'Claim filed by driver or admin'},
          {'title': 'Pending Review', 'description': 'Initial review by admin'},
          {'title': 'Investigating', 'description': 'Additional evidence collection'},
          {'title': 'Decision', 'description': 'Final approval or rejection'},
        ];
      case ClaimWorkflowPreset.custom:
        return [
          {'title': 'Custom', 'description': 'Your custom workflow steps'},
        ];
    }
  }

  void _loadPresetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Preset'),
        content: const Text('Preset loading coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'Are you sure you want to reset all settings to default values? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset logic here
              _loadSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _exportSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon!'),
      ),
    );
  }
}
