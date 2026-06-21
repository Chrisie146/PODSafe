import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_central_service.dart';
import '../../models/bc_config.dart';
import '../../utils/theme.dart';

/// Business Central Settings Screen
/// Allows admins to configure BC integration
class BCSettingsScreen extends StatefulWidget {
  const BCSettingsScreen({super.key});

  @override
  State<BCSettingsScreen> createState() => _BCSettingsScreenState();
}

class _BCSettingsScreenState extends State<BCSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bcService = BusinessCentralService();

  // Form controllers
  final _tenantIdController = TextEditingController();
  final _bcCompanyIdController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _bcApiUrlController = TextEditingController();

  bool _isEnabled = false;
  String _environment = 'production';
  int _syncIntervalMinutes = 15;
  bool _autoCreateDeliveries = false;
  bool _autoAttachPODs = true;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _obscureSecret = true;

  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _tenantIdController.dispose();
    _bcCompanyIdController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _bcApiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final config = await _bcService.getConfig(companyId);

      if (config != null && mounted) {
        setState(() {
          _isEnabled = config.isEnabled;
          _tenantIdController.text = config.tenantId ?? '';
          _bcCompanyIdController.text = config.bcCompanyId ?? '';
          _clientIdController.text = config.clientId ?? '';
          _bcApiUrlController.text = config.bcApiUrl ?? 'https://api.businesscentral.dynamics.com/v2.0';
          _environment = config.environment ?? 'production';
          _syncIntervalMinutes = config.syncIntervalMinutes;
          _autoCreateDeliveries = config.autoCreateDeliveries;
          _autoAttachPODs = config.autoAttachPODs;
        });
      } else {
        // Set defaults for new configuration
        _bcApiUrlController.text = 'https://api.businesscentral.dynamics.com/v2.0';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading configuration: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null) {
        throw Exception('Company ID not found');
      }

      final config = BCConfig(
        companyId: companyId,
        isEnabled: _isEnabled,
        tenantId: _tenantIdController.text.trim(),
        environment: _environment,
        bcCompanyId: _bcCompanyIdController.text.trim(),
        clientId: _clientIdController.text.trim(),
        bcApiUrl: _bcApiUrlController.text.trim(),
        syncIntervalMinutes: _syncIntervalMinutes,
        autoCreateDeliveries: _autoCreateDeliveries,
        autoAttachPODs: _autoAttachPODs,
      );

      await _bcService.saveConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_clientSecretController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client Secret is required to test connection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null) {
        throw Exception('Company ID not found');
      }

      final config = BCConfig(
        companyId: companyId,
        tenantId: _tenantIdController.text.trim(),
        environment: _environment,
        bcCompanyId: _bcCompanyIdController.text.trim(),
        clientId: _clientIdController.text.trim(),
        bcApiUrl: _bcApiUrlController.text.trim(),
      );

      // Save config to Firestore first (Cloud Function needs to read it)
      debugPrint('Saving BC config to Firestore before testing...');
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('integrations')
          .doc('businessCentral')
          .set(config.toFirestore());

      debugPrint('Testing connection with companyId: $companyId');
      final success = await _bcService.testConnection(
        config,
        _clientSecretController.text.trim(),
      );

      setState(() {
        _testSuccess = success;
        if (success) {
          _testResult = 'Connection successful! ✓\n\nYour Business Central credentials are valid and the API is accessible.';
        } else {
          _testResult = 'Connection failed ✗\n\nPlease check:\n• Tenant ID is correct\n• Client ID is correct\n• Client Secret is correct\n• BC API URL is correct\n• Azure AD app has BC API permissions';
        }
      });
    } catch (e) {
      debugPrint('BC connection test error: $e');
      setState(() {
        _testSuccess = false;
        _testResult = 'Error: ${e.toString()}\n\nPlease check the console for more details.';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Central Integration'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 26),
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 51),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.cloud_sync,
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
                                    'Microsoft Dynamics 365 Business Central',
                                    style: AppTextStyles.heading3,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sync sales orders, customers, and delivery status in real-time',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isEnabled,
                              onChanged: (value) {
                                setState(() => _isEnabled = value);
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Configuration Section
                    _buildSection(
                      'Connection Settings',
                      Icons.settings,
                      [
                        _buildTextField(
                          controller: _tenantIdController,
                          label: 'Azure AD Tenant ID',
                          hint: 'Your Azure Active Directory tenant ID',
                          icon: Icons.domain,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tenant ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _clientIdController,
                          label: 'Client ID (Application ID)',
                          hint: 'Azure AD application client ID',
                          icon: Icons.key,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Client ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _clientSecretController,
                          label: 'Client Secret',
                          hint: 'Azure AD application client secret',
                          icon: Icons.lock,
                          obscureText: _obscureSecret,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureSecret ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() => _obscureSecret = !_obscureSecret);
                            },
                          ),
                          helperText: 'Note: Client secret is not stored. Enter only when testing connection.',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bcCompanyIdController,
                          label: 'Business Central Company ID',
                          hint: 'BC company GUID',
                          icon: Icons.business,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Company ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bcApiUrlController,
                          label: 'BC API Base URL',
                          hint: 'https://api.businesscentral.dynamics.com/v2.0/{tenant-id}/{environment}',
                          icon: Icons.link,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'API URL is required';
                            }
                            if (!value.startsWith('http')) {
                              return 'Please enter a valid URL';
                            }
                            return null;
                          },
                          helperText: 'For trial: https://api.businesscentral.dynamics.com/v2.0/229fde23-1706-429c-8976-f70cf00cd16e/Sandbox',
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          value: _environment,
                          label: 'Environment',
                          icon: Icons.cloud,
                          items: const ['production', 'sandbox'],
                          onChanged: (value) {
                            setState(() => _environment = value!);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sync Settings
                    _buildSection(
                      'Sync Settings',
                      Icons.sync,
                      [
                        _buildDropdown(
                          value: _syncIntervalMinutes.toString(),
                          label: 'Sync Interval',
                          icon: Icons.timer,
                          items: const ['5', '10', '15', '30', '60'],
                          onChanged: (value) {
                            setState(() => _syncIntervalMinutes = int.parse(value!));
                          },
                          suffix: ' minutes',
                        ),
                        const SizedBox(height: 16),
                        _buildSwitchTile(
                          'Auto-create Deliveries from Sales Orders',
                          'Automatically create delivery tasks when new sales orders are detected',
                          _autoCreateDeliveries,
                          (value) {
                            setState(() => _autoCreateDeliveries = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchTile(
                          'Auto-attach PODs to Invoices',
                          'Automatically attach proof of delivery PDFs to BC invoices',
                          _autoAttachPODs,
                          (value) {
                            setState(() => _autoAttachPODs = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Test Connection Result
                    if (_testResult != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _testSuccess == true
                              ? Colors.green.withValues(alpha: 26)
                              : Colors.red.withValues(alpha: 26),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _testSuccess == true ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testSuccess == true ? Icons.check_circle : Icons.error,
                              color: _testSuccess == true ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _testResult!,
                                style: TextStyle(
                                  color: _testSuccess == true ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTesting || _isSaving ? null : _testConnection,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTesting || _isSaving ? null : _saveConfig,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.heading3.copyWith(
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        helperText: helperText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    String? suffix,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text('$item${suffix ?? ''}'),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    void Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
