import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../driver/dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../developer/developer_dashboard_screen.dart';
import 'pending_approval_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> 
    with SingleTickerProviderStateMixin {
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isPasswordVisible = false;
  int _devTapCount = 0;
  final TextEditingController _devPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 100,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _devPinController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDevTap() {
    // Increment tap count; if tapped 5 times open PIN prompt
    _devTapCount += 1;
    if (_devTapCount >= 5) {
      _devTapCount = 0;
      _showDeveloperPinDialog();
    }
    // Reset counter after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      _devTapCount = 0;
    });
  }

  void _showDeveloperPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter developer PIN to continue'),
            const SizedBox(height: 12),
            TextField(
              controller: _devPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _devPinController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final pin = _devPinController.text.trim();
              // Use same PIN as developer screen
              if (pin == '1234') {
                _devPinController.clear();
                Navigator.of(context).pop();
                try {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DeveloperDashboardScreen(),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error opening developer dashboard: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid PIN'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Enter'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = context.read<AuthProvider>();
    
    bool success = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    
    if (success && mounted) {
      // Get user data to check role and approval status
      final userId = authProvider.currentUser?.id;
      if (userId == null) return;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final role = userData['role'];
      final approvalStatus = userData['approvalStatus'];
      final companyId = userData['companyId'];
      
      // Get company name if pending
      String? companyName;
      if (approvalStatus == 'pending' && companyId != null) {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        companyName = companyDoc.data()?['name'];
      }
      
      if (!mounted) return;
      
      // Route based on role and approval status
      if (role == 'driver') {
        // Drivers have special approval workflow
        if (approvalStatus == 'pending') {
          // Show pending approval screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PendingApprovalScreen(
                companyName: companyName ?? 'your company',
              ),
            ),
          );
        } else if (approvalStatus == 'approved') {
          // Navigate to driver dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else if (approvalStatus == 'rejected') {
          // Show rejection dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Registration Rejected'),
              content: const Text(
                'Your driver registration was rejected. Please contact your company administrator for more information.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    authProvider.signOut();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // No approval status (old data), just go to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        // All other roles (admin, manager, logistics, accountant, filing_clerk) go to Admin Dashboard
        // They will see different features based on their permissions
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: kDebugMode ? FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DeveloperDashboardScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.developer_mode),
      ) : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: child,
                ),
              );
            },
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Section (tap 5x to open developer PIN)
                    GestureDetector(
                      onTap: _handleDevTap,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [AppTheme.cardShadow],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 50,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Welcome Text
                    const Text(
                      'Welcome to PODSafe',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Login Form
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width > 600 ? 450 : double.infinity,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.paddingLarge),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                          boxShadow: const [AppTheme.cardShadow],
                        ),
                        child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email Field
                            CustomTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              hintText: 'Enter your email',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Password Field
                            CustomTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: !_isPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  _showForgotPasswordDialog();
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Login Button
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return CustomButton(
                                  text: 'Sign In',
                                  onPressed: authProvider.isLoading ? null : _handleLogin,
                                  isLoading: authProvider.isLoading,
                                );
                              },
                            ),
                            
                            // Error Message
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                if (authProvider.errorMessage != null) {
                                  return Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor.withValues(alpha: 26),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.errorColor.withValues(alpha: 77),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: AppTheme.errorColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authProvider.errorMessage!,
                                            style: const TextStyle(
                                              color: AppTheme.errorColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Registration Section
                    const Text(
                      'Don\'t have an account?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Registration Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.business_outlined, size: 20),
                        label: const Text('Create Company Account'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Footer Text
                    const Text(
                      'Secure. Reliable. Professional.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: emailController,
              label: 'Email Address',
              hintText: 'Enter your email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return ElevatedButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        if (emailController.text.isNotEmpty) {
                          bool success = await authProvider.sendPasswordResetEmail(
                            emailController.text.trim(),
                          );
                          
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent!'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        }
                      },
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Reset Link'),
              );
            },
          ),
        ],
      ),
    );
  }
}