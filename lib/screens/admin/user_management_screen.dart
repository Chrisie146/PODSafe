import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/permission.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';
import '../../utils/theme.dart';
import '../../utils/error_handler.dart';

/// User Management Screen - Admin interface for managing users and roles
/// 
/// Features:
/// - List all users in company
/// - Create new users
/// - Edit user details and roles
/// - Activate/deactivate users
/// - Reset passwords
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';
  UserRole? _filterRole;
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final companyId = authProvider.currentUser?.companyId;
    
    if (companyId == null) {
      return const Scaffold(
        body: Center(child: Text('Error: No company ID')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Active filters chips
          if (_filterRole != null || _showInactive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_filterRole != null)
                    Chip(
                      label: Text(_getRoleDisplayName(_filterRole!)),
                      onDeleted: () {
                        setState(() {
                          _filterRole = null;
                        });
                      },
                    ),
                  if (_showInactive)
                    Chip(
                      label: const Text('Show Inactive'),
                      onDeleted: () {
                        setState(() {
                          _showInactive = false;
                        });
                      },
                    ),
                ],
              ),
            ),
          
          // User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildUserQuery(companyId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // Check if it's a permission error
                  if (ErrorHandler.isPermissionDenied(snapshot.error)) {
                    return ErrorHandler.buildPermissionDeniedWidget(
                      message: 'You don\'t have permission to view users. Only administrators can access user management.',
                    );
                  }
                  
                  // Other errors
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            ErrorHandler.getUserFriendlyMessage(snapshot.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var users = snapshot.data!.docs
                    .map((doc) => AppUser.fromFirestore(doc))
                    .where((user) => _matchesFilters(user))
                    .toList();
                
                users.sort((a, b) => a.fullName.compareTo(b.fullName));
                
                if (users.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No users found', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return _UserListTile(
                      user: users[index],
                      onTap: () => _showUserDetails(users[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
  
  Stream<QuerySnapshot> _buildUserQuery(String companyId) {
    var query = FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId);
    
    if (_filterRole != null) {
      query = query.where('role', isEqualTo: _filterRole.toString().split('.').last);
    }
    
    return query.snapshots();
  }
  
  bool _matchesFilters(AppUser user) {
    // Filter by active status
    if (!_showInactive && !user.isActive) {
      return false;
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      return user.fullName.toLowerCase().contains(searchLower) ||
             user.email.toLowerCase().contains(searchLower);
    }
    
    return true;
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Users'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole?>(
                value: _filterRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Roles')),
                  ...UserRole.values.map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(_getRoleDisplayName(role)),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterRole = value;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Show Inactive Users'),
                value: _showInactive,
                onChanged: (value) {
                  setState(() {
                    _showInactive = value ?? false;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {}); // Refresh main screen
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
  
  void _showUserDetails(AppUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _UserDetailsSheet(user: user),
    );
  }
  
  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => const _CreateUserDialog(),
    );
  }
  
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.logistics:
        return 'Logistics';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.filing_clerk:
        return 'Filing Clerk';
      case UserRole.driver:
        return 'Driver';
    }
  }
}

/// User List Tile
class _UserListTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  
  const _UserListTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: user.isActive ? AppTheme.primaryColor : Colors.grey,
        child: Text(
          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        user.fullName,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: user.isActive ? Colors.black : Colors.grey,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              _buildRoleBadge(user.role),
              if (!user.isActive)
                const Chip(
                  label: Text('Inactive', style: TextStyle(fontSize: 11)),
                  backgroundColor: Colors.grey,
                  visualDensity: VisualDensity.compact,
                  labelPadding: EdgeInsets.symmetric(horizontal: 4),
                ),
              if (user.role == UserRole.driver && user.approvalStatus != 'approved')
                Chip(
                  label: Text(
                    user.approvalStatus ?? 'Pending',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.orange,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
  
  Widget _buildRoleBadge(UserRole role) {
    Color color;
    switch (role) {
      case UserRole.admin:
        color = Colors.red;
        break;
      case UserRole.manager:
        color = Colors.blue;
        break;
      case UserRole.logistics:
        color = Colors.green;
        break;
      case UserRole.accountant:
        color = Colors.purple;
        break;
      case UserRole.filing_clerk:
        color = Colors.orange;
        break;
      case UserRole.driver:
        color = Colors.teal;
        break;
    }
    
    return Chip(
      label: Text(
        role.toString().split('.').last.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// User Details Sheet
class _UserDetailsSheet extends StatelessWidget {
  final AppUser user;
  
  const _UserDetailsSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollController,
          children: [
            Row(
              children: [
                const Text(
                  'User Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            
            _buildDetailRow('Full Name', user.fullName),
            _buildDetailRow('Email', user.email),
            _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided'),
            _buildDetailRow('Role', _getRoleDisplayName(user.role)),
            _buildDetailRow('Status', user.isActive ? 'Active' : 'Inactive'),
            _buildDetailRow('Company ID', user.companyId),
            
            if (user.role == UserRole.driver) ...[
              const Divider(),
              const Text(
                'Driver Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('License Number', user.licenseNumber ?? 'Not provided'),
              _buildDetailRow('Vehicle Info', user.vehicleInfo ?? 'Not provided'),
              _buildDetailRow('Approval Status', user.approvalStatus ?? 'Pending'),
            ],
            
            const SizedBox(height: 24),
            
            // Permissions display
            const Text(
              'Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PermissionService.getPermissionsForRole(user.role)
                  .map((permission) => Chip(
                    label: Text(permission.displayName, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ))
                  .toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showEditUserDialog(context, user);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _toggleUserStatus(context, user, authProvider),
              icon: Icon(user.isActive ? Icons.block : Icons.check_circle),
              label: Text(user.isActive ? 'Deactivate User' : 'Activate User'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _resetPassword(context, user, authProvider),
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reset Password'),
            ),
            if (user.role == UserRole.driver && user.approvalStatus != 'approved') ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _approveDriver(context, user, authProvider),
                icon: const Icon(Icons.check_circle),
                label: const Text('Approve Driver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.logistics:
        return 'Logistics';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.filing_clerk:
        return 'Filing Clerk';
      case UserRole.driver:
        return 'Driver';
    }
  }
  
  void _showEditUserDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(user: user),
    );
  }
  
  Future<void> _toggleUserStatus(
    BuildContext context,
    AppUser user,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.isActive ? 'Deactivate' : 'Activate'} User'),
        content: Text(
          'Are you sure you want to ${user.isActive ? 'deactivate' : 'activate'} ${user.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      try {
        await authProvider.toggleUserStatus(user.id, !user.isActive);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User ${user.isActive ? 'deactivated' : 'activated'} successfully'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.showErrorSnackBar(context, e);
        }
      }
    }
  }
  
  Future<void> _resetPassword(
    BuildContext context,
    AppUser user,
    AuthProvider authProvider,
  ) async {
    try {
      await authProvider.sendPasswordResetEmail(user.email);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${user.email}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }
  
  Future<void> _approveDriver(
    BuildContext context,
    AppUser user,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Driver'),
        content: Text('Are you sure you want to approve ${user.fullName} as a driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      try {
        final updatedUser = user.copyWith(
          approvalStatus: 'approved',
          approvedBy: authProvider.currentUser?.id,
          approvedAt: DateTime.now(),
        );
        
        await authProvider.updateUserAsAdmin(updatedUser);
        
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.fullName} has been approved as a driver'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.showErrorSnackBar(context, e);
        }
      }
    }
  }
}

/// Create User Dialog
class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.driver;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
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
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Initial Password',
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'User can change this after first login',
                ),
                obscureText: true,
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
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(_getRoleDisplayName(role)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
  
  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminEmail = authProvider.currentUser?.email;
    
    try {
      // Show dialog to get admin password for re-authentication
      String? adminPassword;
      
      if (mounted) {
        adminPassword = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _AdminPasswordDialog(adminEmail: adminEmail ?? ''),
        );
      }
      
      if (adminPassword == null) {
        // User cancelled
        setState(() => _isLoading = false);
        return;
      }
      
      final success = await authProvider.createUserAsAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        phoneNumber: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        adminEmail: adminEmail,
        adminPassword: adminPassword,
      );
      
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully! You have been re-authenticated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.logistics:
        return 'Logistics';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.filing_clerk:
        return 'Filing Clerk';
      case UserRole.driver:
        return 'Driver';
    }
  }
}

/// Edit User Dialog
class _EditUserDialog extends StatefulWidget {
  final AppUser user;
  
  const _EditUserDialog({required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late UserRole _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phoneNumber ?? '');
    _selectedRole = widget.user.role;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(_getRoleDisplayName(role)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
  
  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final updatedUser = widget.user.copyWith(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        role: _selectedRole,
      );
      
      await authProvider.updateUserAsAdmin(updatedUser);
      
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context); // Close details sheet too
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.logistics:
        return 'Logistics';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.filing_clerk:
        return 'Filing Clerk';
      case UserRole.driver:
        return 'Driver';
    }
  }
}

// Admin Password Dialog for re-authentication after creating user
class _AdminPasswordDialog extends StatefulWidget {
  final String adminEmail;
  
  const _AdminPasswordDialog({required this.adminEmail});

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Your Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To create a new user, please confirm your admin password:',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          Text(
            widget.adminEmail,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Your Admin Password',
              prefixIcon: const Icon(Icons.lock),
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
            autofocus: true,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Note: Creating a user will temporarily sign you out. You will be automatically re-authenticated.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  void _submit() {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }
    Navigator.pop(context, _passwordController.text);
  }
}
