import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../admin/admin_dashboard_screen.dart';

class InviteRegistrationScreen extends StatefulWidget {
  const InviteRegistrationScreen({super.key});

  @override
  State<InviteRegistrationScreen> createState() => _InviteRegistrationScreenState();
}

class _InviteRegistrationScreenState extends State<InviteRegistrationScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _companyName;
  String? _inviteCodeDocId;

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
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an invite code'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim().toUpperCase();

      // Call Cloud Function to verify code
      final callable = FirebaseFunctions.instance.httpsCallable('verifyCompanyCode');
      final result = await callable.call({'code': code});
      
      final data = result.data as Map<String, dynamic>;
      
      if (data['valid'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or expired invite code'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      setState(() {
        _companyName = data['companyName'];
        _inviteCodeDocId = data['codeId'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code validated for $_companyName'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error validating code: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_companyName == null || _inviteCodeDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please validate your invite code first'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();

    try {
      // Call Cloud Function to handle the entire registration
      final callable = FirebaseFunctions.instance.httpsCallable('registerWithInviteCode');
      final result = await callable.call({
        'codeId': _inviteCodeDocId!,
        'companyName': _companyName!,
        'adminEmail': _emailController.text.trim(),
        'adminPassword': _passwordController.text,
        'adminName': _nameController.text.trim(),
      });

      if (mounted && result.data['success'] == true) {
        // Sign in the newly created user
        final signInSuccess = await authProvider.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (signInSuccess && mounted) {
          // Navigate to admin dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    // Logo Section
                    Container(
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

                    const SizedBox(height: 32),

                    // Welcome Text
                    const Text(
                      'Join Your Company',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Enter your invite code to get started',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Registration Form
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
                              // Invite Code Field
                              CustomTextField(
                                controller: _codeController,
                                label: 'Company Invite Code',
                                hintText: 'Enter your invite code',
                                prefixIcon: Icons.vpn_key,
                              ),

                              const SizedBox(height: 16),

                              // Validate Code Button
                              if (_companyName == null)
                                CustomButton(
                                  text: 'Validate Code',
                                  onPressed: _isLoading ? null : _validateCode,
                                  isLoading: _isLoading,
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withValues(alpha: 26),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.successColor.withValues(alpha: 77),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppTheme.successColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Validated for: $_companyName',
                                          style: const TextStyle(
                                            color: AppTheme.successColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (_companyName != null) ...[
                                const SizedBox(height: 24),

                                // Name Field
                                CustomTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  hintText: 'Enter your full name',
                                  prefixIcon: Icons.person,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                // Email Field
                                CustomTextField(
                                  controller: _emailController,
                                  label: 'Email Address',
                                  hintText: 'Enter your email',
                                  prefixIcon: Icons.email,
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
                                  hintText: 'Create a password',
                                  prefixIcon: Icons.lock,
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
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                // Confirm Password Field
                                CustomTextField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  hintText: 'Confirm your password',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: !_isConfirmPasswordVisible,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Register Button
                                Consumer<AuthProvider>(
                                  builder: (context, authProvider, child) {
                                    return CustomButton(
                                      text: 'Create Account',
                                      onPressed: (authProvider.isLoading || _isLoading) ? null : _register,
                                      isLoading: authProvider.isLoading || _isLoading,
                                    );
                                  },
                                ),
                              ],

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

                    // Back to Login
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
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
}