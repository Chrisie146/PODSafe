import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

/// Self-service company registration screen
/// Allows new companies to sign up without needing developer access
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _companyNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
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

    setState(() => _isLoading = true);

    try {
      // Call Cloud Function to create company and admin user
      final callable = FirebaseFunctions.instance.httpsCallable('createCompanyWithAdmin');
      final result = await callable.call({
        'companyName': _companyNameController.text.trim(),
        'adminName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      final data = result.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;

      if (success) {
        if (mounted) {
          // Auto-login after successful signup
          final authProvider = context.read<AuthProvider>();
          await authProvider.signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Welcome to PODSafe!'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          // Navigation will be handled by auth state change
        }
      } else {
        throw Exception(data['error'] ?? 'Failed to create account');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo and Title
                        Icon(
                          Icons.verified_user,
                          size: 64,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Create Your Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start managing your deliveries today',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Company Name
                        CustomTextField(
                          controller: _companyNameController,
                          label: 'Company Name',
                          hintText: 'Enter your company name',
                          prefixIcon: Icons.business,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Company name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Full Name
                        CustomTextField(
                          controller: _fullNameController,
                          label: 'Your Full Name',
                          hintText: 'Enter your full name',
                          prefixIcon: Icons.person,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hintText: 'Enter your email',
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hintText: 'Create a password',
                          prefixIcon: Icons.lock,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hintText: 'Re-enter your password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
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

                        // Sign Up Button
                        CustomButton(
                          text: 'Create Account',
                          onPressed: _isLoading ? null : _signup,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Back to Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account?'),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Sign In'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
