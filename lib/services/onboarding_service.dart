import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding Service
/// Manages user onboarding state and provides guided experiences
class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingStepKey = 'onboarding_step';
  static const String _userRoleKey = 'user_role';

  /// Check if user has completed onboarding
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }

  /// Get current onboarding step
  static Future<int> getCurrentStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_onboardingStepKey) ?? 0;
  }

  /// Set current onboarding step
  static Future<void> setCurrentStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_onboardingStepKey, step);
  }

  /// Set user role for role-specific onboarding
  static Future<void> setUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, role);
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Reset onboarding (for testing or re-onboarding)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompletedKey);
    await prefs.remove(_onboardingStepKey);
    await prefs.remove(_userRoleKey);
  }

  /// Debug: Get all onboarding data
  static Future<Map<String, dynamic>> getDebugData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'onboarding_completed': prefs.getBool(_onboardingCompletedKey) ?? false,
      'onboarding_step': prefs.getInt(_onboardingStepKey) ?? 0,
      'user_role': prefs.getString(_userRoleKey) ?? 'unknown',
    };
  }
}

/// Onboarding Step Model
class OnboardingStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Widget? content;
  final VoidCallback? onComplete;
  final bool required;

  const OnboardingStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.content,
    this.onComplete,
    this.required = true,
  });
}

/// Onboarding Flow Configuration
class OnboardingFlow {
  static List<OnboardingStep> getStepsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return _getAdminOnboardingSteps();
      case 'manager':
        return _getManagerOnboardingSteps();
      case 'logistics':
        return _getLogisticsOnboardingSteps();
      case 'driver':
        return _getDriverOnboardingSteps();
      default:
        return _getDefaultOnboardingSteps();
    }
  }

  static List<OnboardingStep> _getAdminOnboardingSteps() {
    return [
      OnboardingStep(
        id: 'welcome',
        title: 'Welcome to PODSafe!',
        description: 'Let\'s get you set up with the essential features for managing your delivery operations.',
        icon: Icons.waving_hand,
      ),
      OnboardingStep(
        id: 'company_setup',
        title: 'Complete Your Company Profile',
        description: 'Add your company logo, contact details, and basic settings to personalize PODSafe.',
        icon: Icons.business,
      ),
      OnboardingStep(
        id: 'user_management',
        title: 'Set Up Your Team',
        description: 'Register managers, logistics coordinators, and other team members.',
        icon: Icons.people,
      ),
      OnboardingStep(
        id: 'integrations',
        title: 'Connect Your Systems',
        description: 'Import deliveries from ABAServe or connect Business Central for seamless operations.',
        icon: Icons.sync,
      ),
      OnboardingStep(
        id: 'first_delivery',
        title: 'Create Your First Delivery',
        description: 'Add a delivery and assign it to a driver to see PODSafe in action.',
        icon: Icons.local_shipping,
      ),
      OnboardingStep(
        id: 'dashboard_tour',
        title: 'Explore Your Dashboard',
        description: 'Learn about the analytics, reports, and management tools available.',
        icon: Icons.dashboard,
      ),
    ];
  }

  static List<OnboardingStep> _getManagerOnboardingSteps() {
    return [
      OnboardingStep(
        id: 'welcome',
        title: 'Welcome to PODSafe!',
        description: 'As a manager, you have access to delivery oversight and team coordination features.',
        icon: Icons.waving_hand,
      ),
      OnboardingStep(
        id: 'delivery_management',
        title: 'Manage Deliveries',
        description: 'View, create, and track deliveries across your team.',
        icon: Icons.local_shipping,
      ),
      OnboardingStep(
        id: 'team_overview',
        title: 'Monitor Your Team',
        description: 'Track driver performance and delivery status in real-time.',
        icon: Icons.people,
      ),
      OnboardingStep(
        id: 'reports',
        title: 'Access Reports',
        description: 'Generate delivery reports and performance analytics.',
        icon: Icons.analytics,
      ),
    ];
  }

  static List<OnboardingStep> _getLogisticsOnboardingSteps() {
    return [
      OnboardingStep(
        id: 'welcome',
        title: 'Welcome to PODSafe!',
        description: 'Focus on delivery coordination and route optimization.',
        icon: Icons.waving_hand,
      ),
      OnboardingStep(
        id: 'delivery_operations',
        title: 'Delivery Operations',
        description: 'Create deliveries, assign drivers, and track progress.',
        icon: Icons.local_shipping,
      ),
      OnboardingStep(
        id: 'live_tracking',
        title: 'Live Tracking',
        description: 'Monitor driver locations and delivery status in real-time.',
        icon: Icons.location_on,
      ),
      OnboardingStep(
        id: 'communication',
        title: 'Team Communication',
        description: 'Use the chat system to coordinate with drivers.',
        icon: Icons.chat,
      ),
    ];
  }

  static List<OnboardingStep> _getDriverOnboardingSteps() {
    return [
      OnboardingStep(
        id: 'welcome',
        title: 'Welcome to PODSafe!',
        description: 'Start delivering with PODSafe\'s mobile-friendly interface.',
        icon: Icons.waving_hand,
      ),
      OnboardingStep(
        id: 'driver_app',
        title: 'Your Driver Dashboard',
        description: 'View your assigned deliveries and track your progress.',
        icon: Icons.drive_eta,
      ),
      OnboardingStep(
        id: 'pod_process',
        title: 'POD Collection',
        description: 'Learn how to capture proof of delivery with photos and signatures.',
        icon: Icons.camera,
      ),
      OnboardingStep(
        id: 'communication',
        title: 'Stay Connected',
        description: 'Use the chat feature to communicate with your team.',
        icon: Icons.chat,
      ),
    ];
  }

  static List<OnboardingStep> _getDefaultOnboardingSteps() {
    return [
      OnboardingStep(
        id: 'welcome',
        title: 'Welcome to PODSafe!',
        description: 'Get started with your delivery management system.',
        icon: Icons.waving_hand,
      ),
    ];
  }
}