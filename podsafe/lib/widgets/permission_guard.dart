import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/permission.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';

/// PermissionGuard - Wraps widgets/routes to show only if user has permission
/// 
/// This widget checks if the current user has the required permission(s)
/// and either shows the child widget or a fallback/error message.
/// 
/// Example usage:
/// ```dart
/// PermissionGuard(
///   permission: Permission.deliveriesManage,
///   child: CreateDeliveryButton(),
///   fallback: SizedBox.shrink(), // Hide if no permission
/// )
/// ```
class PermissionGuard extends StatelessWidget {
  final Permission? permission;
  final List<Permission>? anyPermissions;
  final List<Permission>? allPermissions;
  final UserRole? role;
  final List<UserRole>? anyRoles;
  final Widget child;
  final Widget? fallback;
  final bool showFallback;
  
  const PermissionGuard({
    super.key,
    this.permission,
    this.anyPermissions,
    this.allPermissions,
    this.role,
    this.anyRoles,
    required this.child,
    this.fallback,
    this.showFallback = true,
  }) : assert(
    permission != null || 
    anyPermissions != null || 
    allPermissions != null ||
    role != null ||
    anyRoles != null,
    'Must provide at least one permission or role check'
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    
    bool hasAccess = _checkAccess(user);
    
    if (hasAccess) {
      return child;
    }
    
    if (showFallback && fallback != null) {
      return fallback!;
    }
    
    return const SizedBox.shrink();
  }
  
  bool _checkAccess(AppUser? user) {
    // Check single permission
    if (permission != null) {
      return PermissionService.hasPermission(user, permission!);
    }
    
    // Check any of multiple permissions
    if (anyPermissions != null) {
      return PermissionService.hasAnyPermission(user, anyPermissions!);
    }
    
    // Check all permissions
    if (allPermissions != null) {
      return PermissionService.hasAllPermissions(user, allPermissions!);
    }
    
    // Check single role
    if (role != null) {
      return PermissionService.hasRole(user, role!);
    }
    
    // Check any of multiple roles
    if (anyRoles != null) {
      return PermissionService.hasAnyRole(user, anyRoles!);
    }
    
    return false;
  }
}

/// PermissionBuilder - Builder pattern for conditional rendering based on permissions
/// 
/// Provides the permission check result to the builder function,
/// allowing for more complex UI logic.
/// 
/// Example usage:
/// ```dart
/// PermissionBuilder(
///   permission: Permission.deliveriesManage,
///   builder: (context, hasPermission) {
///     return ElevatedButton(
///       onPressed: hasPermission ? _createDelivery : null,
///       child: Text('Create Delivery'),
///     );
///   },
/// )
/// ```
class PermissionBuilder extends StatelessWidget {
  final Permission? permission;
  final List<Permission>? anyPermissions;
  final UserRole? role;
  final List<UserRole>? anyRoles;
  final Widget Function(BuildContext context, bool hasAccess) builder;
  
  const PermissionBuilder({
    super.key,
    this.permission,
    this.anyPermissions,
    this.role,
    this.anyRoles,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    
    bool hasAccess = false;
    
    if (permission != null) {
      hasAccess = PermissionService.hasPermission(user, permission!);
    } else if (anyPermissions != null) {
      hasAccess = PermissionService.hasAnyPermission(user, anyPermissions!);
    } else if (role != null) {
      hasAccess = PermissionService.hasRole(user, role!);
    } else if (anyRoles != null) {
      hasAccess = PermissionService.hasAnyRole(user, anyRoles!);
    }
    
    return builder(context, hasAccess);
  }
}

/// RoleBasedButton - Shows/enables button based on permissions
/// 
/// Automatically disables button if user doesn't have required permission
/// 
/// Example usage:
/// ```dart
/// RoleBasedButton(
///   permission: Permission.deliveriesManage,
///   onPressed: _createDelivery,
///   child: Text('Create Delivery'),
/// )
/// ```
class RoleBasedButton extends StatelessWidget {
  final Permission? permission;
  final List<Permission>? anyPermissions;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  
  const RoleBasedButton({
    super.key,
    this.permission,
    this.anyPermissions,
    required this.onPressed,
    required this.child,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return PermissionBuilder(
      permission: permission,
      anyPermissions: anyPermissions,
      builder: (context, hasAccess) {
        return ElevatedButton(
          onPressed: hasAccess ? onPressed : null,
          style: style,
          child: child,
        );
      },
    );
  }
}

/// PermissionRoute - Route wrapper that checks permissions before navigation
/// 
/// Use this to protect entire screens/routes
/// 
/// Example usage:
/// ```dart
/// Navigator.push(
///   context,
///   PermissionRoute(
///     permission: Permission.usersManage,
///     builder: (context) => UserManagementScreen(),
///     fallbackRoute: (context) => UnauthorizedScreen(),
///   ),
/// )
/// ```
class PermissionRoute<T> extends MaterialPageRoute<T> {
  final Permission? permission;
  final List<Permission>? anyPermissions;
  final UserRole? role;
  final List<UserRole>? anyRoles;
  final WidgetBuilder fallbackRoute;
  
  PermissionRoute({
    required super.builder,
    this.permission,
    this.anyPermissions,
    this.role,
    this.anyRoles,
    WidgetBuilder? fallbackRoute,
    super.settings,
  }) : fallbackRoute = fallbackRoute ?? _defaultFallback;
  
  static Widget _defaultFallback(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unauthorized'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'You don\'t have permission to access this page',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget buildContent(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    bool hasAccess = false;
    
    if (permission != null) {
      hasAccess = PermissionService.hasPermission(user, permission!);
    } else if (anyPermissions != null) {
      hasAccess = PermissionService.hasAnyPermission(user, anyPermissions!);
    } else if (role != null) {
      hasAccess = PermissionService.hasRole(user, role!);
    } else if (anyRoles != null) {
      hasAccess = PermissionService.hasAnyRole(user, anyRoles!);
    }
    
    if (hasAccess) {
      return super.buildContent(context);
    }
    
    return fallbackRoute(context);
  }
}

/// Helper function to check if widget should be shown
/// Use in conditional rendering without wrapping in PermissionGuard
/// 
/// Example:
/// ```dart
/// if (showIfPermitted(context, Permission.deliveriesManage)) {
///   return CreateButton();
/// }
/// ```
bool showIfPermitted(BuildContext context, Permission permission) {
  final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
  return PermissionService.hasPermission(user, permission);
}

/// Helper function to check if user has any of the permissions
bool showIfAnyPermitted(BuildContext context, List<Permission> permissions) {
  final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
  return PermissionService.hasAnyPermission(user, permissions);
}

/// Helper function to check if user has specific role
bool showIfRole(BuildContext context, UserRole role) {
  final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
  return PermissionService.hasRole(user, role);
}
