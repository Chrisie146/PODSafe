import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../services/onboarding_service.dart';
import 'auth/login_screen.dart';
import 'driver/dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));
    
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check if this is a public route FIRST, before initializing auth
    final initialUri = Uri.base;
    final path = initialUri.fragment.isNotEmpty 
        ? initialUri.fragment.split('?')[0]
        : initialUri.path;
    
    final isPublicRoute = path.startsWith('/pod/') || path.startsWith('/upload/');
    
    if (isPublicRoute) {
      debugPrint('🌐 Public route detected early: $path - skipping splash');
      // For public routes, skip splash and navigate immediately
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(path);
      }
      return;
    }
    
    // Initialize auth provider (only for non-public routes)
    context.read<AuthProvider>().initialize();
    
    // Start animations
    _animationController.forward();
    
    // Wait for animations to complete
    await Future.delayed(const Duration(seconds: 3));
    
    // Navigate based on auth state
    if (mounted) {
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    final authProvider = context.read<AuthProvider>();
    
    // Check if this is a public URL (POD view or upload)
    final initialUri = Uri.base;
    final path = initialUri.fragment.isNotEmpty 
        ? initialUri.fragment.split('?')[0]  // Extract path from hash
        : initialUri.path;
    
    // If this is a public POD URL or upload URL, don't redirect - let the routing handle it
    if (path.startsWith('/pod/') || path.startsWith('/upload/')) {
      debugPrint('🌐 Public route detected: $path - skipping auth redirect');
      // Don't navigate anywhere - stay on current route
      return;
    }
    
    if (authProvider.isLoggedIn) {
      // Check if user needs onboarding
      _checkOnboardingAndNavigate();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _checkOnboardingAndNavigate() async {
    final authProvider = context.read<AuthProvider>();
    
    debugPrint('🔍 Checking onboarding status...');
    debugPrint('👤 User logged in: ${authProvider.isLoggedIn}');
    debugPrint('🎭 User role: ${authProvider.currentUser?.role}');
    
    // Get debug data
    final debugData = await OnboardingService.getDebugData();
    debugPrint('📊 Onboarding debug data: $debugData');
    
    // Check if onboarding is completed
    final onboardingCompleted = await OnboardingService.isOnboardingCompleted();
    
    debugPrint('✅ Onboarding completed: $onboardingCompleted');
    
    if (!onboardingCompleted) {
      debugPrint('🚀 Showing onboarding screen');
      // Show onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      debugPrint('📊 Routing to dashboard based on role');
      // Route based on user role
      if (authProvider.isDriver) {
        debugPrint('🚛 Going to driver dashboard');
        // Drivers go to Driver Dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        debugPrint('👔 Going to admin dashboard');
        // Admin, Manager, Logistics, Accountant, Filing Clerk all go to Admin Dashboard
        // They will see different features based on their permissions
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Animation
              AnimatedBuilder(
                animation: _logoAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoAnimation.value,
                    child: Opacity(
                      opacity: _logoAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
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
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 60,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // App Name Animation
              AnimatedBuilder(
                animation: _textAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _textAnimation.value)),
                    child: Opacity(
                      opacity: _textAnimation.value,
                      child: Column(
                        children: [
                          const Text(
                            'PODSafe',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Proof of Delivery Solution',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 48),
                          
                          // Loading indicator
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 204),
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
          ),
        ),
      ),
    );
  }
}