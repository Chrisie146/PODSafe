import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_service.dart';
import '../../utils/theme.dart';
import '../admin/admin_dashboard_screen.dart';

/// Setup Wizard Screen
/// Guides new company admins through initial configuration
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  final List<SetupStep> _setupSteps = [
    SetupStep(
      title: 'Company Profile',
      description: 'Complete your company information',
      icon: Icons.business,
      content: const _CompanyProfileStep(),
    ),
    SetupStep(
      title: 'Team Setup',
      description: 'Invite your team members',
      icon: Icons.people,
      content: const _TeamSetupStep(),
    ),
    SetupStep(
      title: 'System Configuration',
      description: 'Configure delivery settings',
      icon: Icons.settings,
      content: const _SystemConfigStep(),
    ),
    SetupStep(
      title: 'Integration Setup',
      description: 'Connect your existing systems',
      icon: Icons.sync,
      content: const _IntegrationSetupStep(),
    ),
  ];

  void _nextStep() {
    if (_currentStep < _setupSteps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);

    try {
      // Mark setup as completed in shared preferences
      // (In a real app, you might want to store this in Firestore)
      // For now, we'll just navigate to the dashboard

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup completion failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _setupSteps[_currentStep];
    final progress = (_currentStep + 1) / _setupSteps.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Wizard'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _completeSetup,
            child: const Text('Skip Setup'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.primaryColor.withValues(alpha: 51),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of ${_setupSteps.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      currentStep.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ],
            ),
          ),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        currentStep.icon,
                        size: 32,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStep.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentStep.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  currentStep.content,
                ],
              ),
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _currentStep == _setupSteps.length - 1
                                ? 'Complete Setup'
                                : 'Next',
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
}

/// Setup Step Model
class SetupStep {
  final String title;
  final String description;
  final IconData icon;
  final Widget content;

  const SetupStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.content,
  });
}

/// Company Profile Setup Step
class _CompanyProfileStep extends StatefulWidget {
  const _CompanyProfileStep();

  @override
  State<_CompanyProfileStep> createState() => _CompanyProfileStepState();
}

class _CompanyProfileStepState extends State<_CompanyProfileStep> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId != null) {
      try {
        final company = await CompanyService().getCompany(companyId);
        if (company != null) {
          setState(() {
            _companyNameController.text = company.name;
            _companyEmailController.text = company.email;
            _companyPhoneController.text = company.phone;
            _companyAddressController.text = company.address;
          });
        }
      } catch (e) {
        debugPrint('Error loading company data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyEmailController,
            decoration: const InputDecoration(
              labelText: 'Company Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyPhoneController,
            decoration: const InputDecoration(
              labelText: 'Company Phone',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyAddressController,
            decoration: const InputDecoration(
              labelText: 'Company Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

/// Team Setup Step
class _TeamSetupStep extends StatelessWidget {
  const _TeamSetupStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Your Company Code',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final companyId = authProvider.currentUser?.companyId ?? 'Loading...';
                  return Text(
                    companyId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Share this code with your team members so they can register and join your company.',
                style: TextStyle(color: Colors.blue[900]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Next Steps:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          '1. Share the company code with your team',
          'Send the code above to managers, drivers, and other staff',
        ),
        _buildStepItem(
          '2. Team members register using the code',
          'They\'ll use the driver registration or you can add them manually',
        ),
        _buildStepItem(
          '3. Review and approve registrations',
          'Check the user management section to approve new team members',
        ),
      ],
    );
  }

  Widget _buildStepItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// System Configuration Step
class _SystemConfigStep extends StatelessWidget {
  const _SystemConfigStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configure your delivery system settings:',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        _buildConfigItem(
          'Delivery Settings',
          'Configure delivery time windows, photo requirements, and GPS tracking',
          Icons.schedule,
        ),
        _buildConfigItem(
          'Notification Settings',
          'Set up email alerts and notification preferences',
          Icons.notifications,
        ),
        _buildConfigItem(
          'Security Settings',
          'Configure password policies and access controls',
          Icons.security,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.green[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can change these settings anytime from the Admin Settings menu.',
                  style: TextStyle(color: Colors.green[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigItem(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
        ],
      ),
    );
  }
}

/// Integration Setup Step
class _IntegrationSetupStep extends StatelessWidget {
  const _IntegrationSetupStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connect PODSafe with your existing systems:',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        _buildIntegrationItem(
          'ABAServe Integration',
          'Import deliveries automatically from your ABAServe ERP system',
          Icons.sync,
          'Available now - upload CSV files or set up automated imports',
        ),
        _buildIntegrationItem(
          'Business Central',
          'Connect with Microsoft Dynamics 365 Business Central',
          Icons.business,
          'Configure API connection for real-time synchronization',
        ),
        _buildIntegrationItem(
          'Third-party APIs',
          'Connect SMS gateways, payment processors, and other services',
          Icons.api,
          'Coming soon - webhook support and API integrations',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: Colors.amber[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Integration setup can be done later from the Admin Settings > Integration Settings.',
                  style: TextStyle(color: Colors.amber[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntegrationItem(String title, String description, IconData icon, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}