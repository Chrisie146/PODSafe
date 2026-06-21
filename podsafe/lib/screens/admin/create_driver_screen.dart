import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../services/cloud_functions_service.dart';
import '../../providers/auth_provider.dart' as app_auth;

class CreateDriverScreen extends StatefulWidget {
  final String? driverId;
  final Map<String, dynamic>? driverData;

  const CreateDriverScreen({
    super.key,
    this.driverId,
    this.driverData,
  });

  @override
  State<CreateDriverScreen> createState() => _CreateDriverScreenState();
}

class _CreateDriverScreenState extends State<CreateDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _vehicleInfoController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    
    // If editing, populate fields
    if (widget.driverData != null) {
      _displayNameController.text = widget.driverData!['displayName'] ?? '';
      _emailController.text = widget.driverData!['email'] ?? '';
      _phoneController.text = widget.driverData!['phoneNumber'] ?? '';
      _licenseNumberController.text = widget.driverData!['licenseNumber'] ?? '';
      _vehicleInfoController.text = widget.driverData!['vehicleInfo'] ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licenseNumberController.dispose();
    _vehicleInfoController.dispose();
    super.dispose();
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Password required only for new drivers
    if (widget.driverId == null && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a password for the new driver'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.driverId == null) {
        // Create new driver with Firebase Auth
        await _createNewDriver();
      } else {
        // Update existing driver
        await _updateDriver();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.driverId == null
                  ? 'Driver created successfully!'
                  : 'Driver updated successfully!',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
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

  Future<void> _createNewDriver() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _displayNameController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final licenseNumber = _licenseNumberController.text.trim();
    final vehicleInfo = _vehicleInfoController.text.trim();
    
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final companyId = authProvider.companyId;
    
    if (companyId == null) {
      throw Exception('Company ID not found. Please log in again.');
    }
    
    try {
      debugPrint('🚀 Creating driver via Cloud Function...');
      
      // Call Cloud Function to create user (won't sign out admin)
      final cloudFunctions = CloudFunctionsService();
      final result = await cloudFunctions.createUser(
        email: email,
        password: password,
        name: name,
        role: 'driver',
        isActive: true,
      );
      
      final driverUid = result['uid'];
      debugPrint('✅ Driver Auth account created: $driverUid');
      
      // Update the Firestore document with additional driver-specific fields
      await FirebaseFirestore.instance
          .collection('users')
          .doc(driverUid)
          .update({
        'fullName': name,
        'displayName': name,
        'phoneNumber': phoneNumber.isEmpty ? null : phoneNumber,
        'licenseNumber': licenseNumber.isEmpty ? null : licenseNumber,
        'vehicleInfo': vehicleInfo.isEmpty ? null : vehicleInfo,
        'companyId': companyId,
        'approvalStatus': 'pending', // New drivers start as pending approval
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Driver profile updated with additional fields including approvalStatus=pending');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver created successfully: ${result['email']}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Return to previous screen
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      debugPrint('❌ Error creating driver: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create driver: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _updateDriver() async {
    final updateData = {
      'displayName': _displayNameController.text.trim(),
      'phoneNumber': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'licenseNumber': _licenseNumberController.text.trim().isEmpty
          ? null
          : _licenseNumberController.text.trim(),
      'vehicleInfo': _vehicleInfoController.text.trim().isEmpty
          ? null
          : _vehicleInfoController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.driverId!)
        .update(updateData);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.driverId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Driver' : 'Add New Driver'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          children: [
            // Info card
            if (!isEditing)
              Card(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.infoColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The driver will receive login credentials at the provided email.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.infoColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Personal Information Section
            const Text(
              'Personal Information',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter driver name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !isEditing, // Can't change email when editing
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter email address';
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
                labelText: 'Phone Number (Optional)',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // Account Information Section
            if (!isEditing) ...[
              const Text(
                'Account Information',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 12),
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
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (!isEditing && (value == null || value.trim().isEmpty)) {
                    return 'Please enter a password';
                  }
                  if (!isEditing && value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
            ],

            // Driver Details Section
            const Text(
              'Driver Details',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _licenseNumberController,
              decoration: const InputDecoration(
                labelText: 'License Number (Optional)',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleInfoController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Information (Optional)',
                hintText: 'e.g., White Ford Transit, Plate: ABC-1234',
                prefixIcon: Icon(Icons.local_shipping),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveDriver,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : Text(
                      isEditing ? 'Update Driver' : 'Create Driver',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
