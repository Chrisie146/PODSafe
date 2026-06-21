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
  String _statusMessage = 'Starting up…';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
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
    
    // Start animations
    _animationController.forward();

    if (mounted) setState(() => _statusMessage = 'Signing you in…');

    // Initialize auth provider (only for non-public routes)
    context.read<AuthProvider>().initialize();

    // Keep a short, snappy minimum so the brand shows without feeling slow.
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) setState(() => _statusMessage = 'Loading your workspace…');

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

    if (!mounted) return;

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
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Stack(
          children: [
            // Centered brand block
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoAnimation.value.clamp(0.0, 1.0),
                        child: Opacity(
                          opacity: _logoAnimation.value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: 58,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App name + tagline
                  AnimatedBuilder(
                    animation: _textAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 24 * (1 - _textAnimation.value)),
                        child: Opacity(
                          opacity: _textAnimation.value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        const Text(
                          'PODSafe',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Proof of Delivery, Secured',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom progress + status + version
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Column(
                children: [
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.20),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '© ${DateTime.now().year} PODSafe',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}