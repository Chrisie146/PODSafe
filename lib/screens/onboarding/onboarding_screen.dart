import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/onboarding_service.dart';
import '../../utils/theme.dart';
import '../../models/user_model.dart';
import '../admin/admin_dashboard_screen.dart';
import '../driver/dashboard_screen.dart';

/// Onboarding Screen
/// Guides new users through initial setup and feature introduction
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late List<OnboardingStep> _steps;
  int _currentStepIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeOnboarding();
  }

  Future<void> _initializeOnboarding() async {
    final authProvider = context.read<AuthProvider>();
    final userRoleEnum = authProvider.currentUser?.role ?? UserRole.driver;
    final userRole = userRoleEnum.name; // Get the enum name (e.g., 'admin', 'manager')

    debugPrint('🎭 Initializing onboarding for role: $userRole (from enum: $userRoleEnum)');

    // Set user role for onboarding
    await OnboardingService.setUserRole(userRole);

    // Get onboarding steps for this role
    _steps = OnboardingFlow.getStepsForRole(userRole);
    
    debugPrint('📋 Loaded ${_steps.length} onboarding steps for role: $userRole');
    for (int i = 0; i < _steps.length; i++) {
      debugPrint('  Step ${i + 1}: ${_steps[i].title}');
    }

    // Get current step from storage
    final savedStep = await OnboardingService.getCurrentStep();
    debugPrint('💾 Saved step from storage: $savedStep');
    
    if (savedStep < _steps.length) {
      _currentStepIndex = savedStep;
    }
    
    debugPrint('🎯 Starting at step: $_currentStepIndex (of ${_steps.length - 1} max)');

    setState(() => _isLoading = false);
  }

  Future<void> _nextStep() async {
    debugPrint('➡️ Next step called: currentStepIndex=$_currentStepIndex, stepsLength=${_steps.length}');
    
    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
      await OnboardingService.setCurrentStep(_currentStepIndex);
      debugPrint('📈 Advanced to step: $_currentStepIndex');
    } else {
      // Complete onboarding
      debugPrint('✅ Completing onboarding');
      await OnboardingService.completeOnboarding();
      _navigateToMainApp();
    }
  }

  Future<void> _skipOnboarding() async {
    await OnboardingService.completeOnboarding();
    _navigateToMainApp();
  }

  void _navigateToMainApp() {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.isDriver) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final currentStep = _steps[_currentStepIndex];
    final progress = (_currentStepIndex + 1) / _steps.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step ${_currentStepIndex + 1} of ${_steps.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: _skipOnboarding,
                          child: const Text(
                            'Skip',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 51),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 51),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          currentStep.icon,
                          size: 64,
                          color: AppTheme.primaryColor,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        currentStep.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        currentStep.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 48),

                      // Custom content if provided
                      if (currentStep.content != null) ...[
                        Expanded(
                          child: currentStep.content!,
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Action buttons
                      Row(
                        children: [
                          if (_currentStepIndex > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _currentStepIndex--);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: AppTheme.primaryColor),
                                ),
                                child: const Text('Back'),
                              ),
                            ),
                          if (_currentStepIndex > 0) const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                (() {
                                  final isLastStep = _currentStepIndex == _steps.length - 1;
                                  debugPrint('🔘 Button text check: currentStepIndex=$_currentStepIndex, stepsLength=${_steps.length}, isLastStep=$isLastStep');
                                  return isLastStep ? 'Get Started' : 'Next';
                                })(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}