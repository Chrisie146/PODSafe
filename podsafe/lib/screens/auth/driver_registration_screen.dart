import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/company_service.dart';
import '../driver/dashboard_screen.dart' as driver;
import 'pending_approval_screen.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyService = CompanyService();
  
  // Form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyCodeController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _vehicleInfoController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _companyCodeVerified = false;
  String? _companyName;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyCodeController.dispose();
    _licenseNumberController.dispose();
    _vehicleInfoController.dispose();
    super.dispose();
  }

  Future<void> _verifyCompanyCode() async {
    final companyCode = _companyCodeController.text.trim();
    if (companyCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter company code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await _companyService.verifyCompanyCode(companyCode);
      
      if (isValid) {
        final name = await _companyService.getCompanyName(companyCode);
        setState(() {
          _companyCodeVerified = true;
          _companyName = name;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Company verified: $name'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid company code'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _registerDriver() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_companyCodeVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify company code first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final companyCode = _companyCodeController.text.trim();
      
      // Get company settings
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyCode)
          .get();
      
      final companyData = companyDoc.data()!;
      final requiresApproval = companyData['settings']?['requireDriverApproval'] ?? true;
      final approvalStatus = requiresApproval ? 'pending' : 'approved';
      
      // Create driver Firebase Auth account
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final driverUid = userCredential.user!.uid;

      // Update display name
      await userCredential.user!.updateDisplayName(_fullNameController.text.trim());

      // Create driver user document
      await FirebaseFirestore.instance.collection('users').doc(driverUid).set({
        'id': driverUid,
        'email': _emailController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'displayName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'role': 'driver',
        'companyId': companyCode,
        'licenseNumber': _licenseNumberController.text.trim(),
        'vehicleInfo': _vehicleInfoController.text.trim(),
        'approvalStatus': approvalStatus,
        'isActive': approvalStatus == 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Navigate based on approval status
      if (approvalStatus == 'pending') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(companyName: _companyName ?? ''),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const driver.DashboardScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Registration'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(
                  Icons.local_shipping,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Join as a Driver',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Register with your company code',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Company Code Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _companyCodeVerified ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _companyCodeVerified ? Colors.green : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _companyCodeVerified ? Icons.check_circle : Icons.business,
                            color: _companyCodeVerified ? Colors.green : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _companyCodeVerified ? 'Company Verified' : 'Company Code',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _companyCodeVerified ? Colors.green : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _companyCodeController,
                        enabled: !_companyCodeVerified,
                        decoration: InputDecoration(
                          labelText: 'Company Code',
                          hintText: 'Enter code from your manager',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: _companyCodeVerified
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter company code';
                          }
                          return null;
                        },
                      ),
                      if (!_companyCodeVerified) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _verifyCompanyCode,
                          icon: const Icon(Icons.verified),
                          label: const Text('Verify Company Code'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                      if (_companyCodeVerified && _companyName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'You will join: $_companyName',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Personal Information
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Driver Details
                Text(
                  'Driver Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Driver License Number',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _vehicleInfoController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Information',
                    hintText: 'e.g., Toyota Corolla, White, ABC-1234',
                    prefixIcon: Icon(Icons.directions_car),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Password Section
                Text(
                  'Account Security',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Register Button
                FilledButton(
                  onPressed: (_isLoading || !_companyCodeVerified) ? null : _registerDriver,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Register as Driver',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // Back to Login
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
