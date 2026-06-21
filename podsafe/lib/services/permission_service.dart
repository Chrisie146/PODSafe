import '../models/user_model.dart';
import '../models/permission.dart';

/// PermissionService - Centralized RBAC permission management
/// 
/// This service maps roles to permissions and provides helper methods
/// to check user access throughout the app.
/// 
/// Extension points:
/// - Add new roles: Update _rolePermissions map
/// - Add new permissions: Add to Permission enum and update role mappings
/// - Add custom logic: Override methods for complex permission checks
class PermissionService {
  /// Role-to-Permission mapping
  /// Defines which permissions each role has access to
  static final Map<UserRole, Set<Permission>> _rolePermissions = {
    // Admin: Full access to everything
    UserRole.admin: {
      ...Permission.values, // All permissions
    },
    
    // Manager: Can view and approve PODs, view reports, manage deliveries
    UserRole.manager: {
      Permission.deliveriesView,
      Permission.deliveriesManage,
      Permission.deliveriesApprove,
      Permission.podsView,
      Permission.podsApprove,
      Permission.podsEdit,
      Permission.financeView,
      Permission.claimsView,
      Permission.claimsApprove,
      Permission.customersView,
      Permission.analyticsView,
      Permission.analyticsExport,
    },
    
    // Logistics: Can create deliveries and assign drivers
    UserRole.logistics: {
      Permission.deliveriesView,
      Permission.deliveriesManage,
      Permission.deliveriesApprove,
      Permission.podsView,
      Permission.customersView,
      Permission.customersManage,
      Permission.claimsView,
    },
    
    // Accountant: Can view financials and export reports
    UserRole.accountant: {
      Permission.deliveriesView,
      Permission.podsView,
      Permission.financeView,
      Permission.financeExport,
      Permission.financeEdit,
      Permission.claimsView,
      Permission.customersView,
      Permission.analyticsView,
      Permission.analyticsExport,
    },
    
    // Filing Clerk: Can upload and tag scanned PODs
    UserRole.filing_clerk: {
      Permission.deliveriesView,
      Permission.podsView,
      Permission.podsUpload,
      Permission.podsEdit,
      Permission.customersView,
    },
    
    // Driver: Can scan/upload PODs, mark deliveries complete
    UserRole.driver: {
      Permission.driverDeliveries,
      Permission.driverPodCapture,
      Permission.podsView,
      Permission.podsUpload,
    },
  };
  
  /// Check if a user has a specific permission
  /// 
  /// For drivers, also checks if they are approved
  /// Returns false if user is null or inactive
  /// 
  /// Example:
  /// ```dart
  /// if (PermissionService.hasPermission(user, Permission.deliveriesManage)) {
  ///   // Show create delivery button
  /// }
  /// ```
  static bool hasPermission(AppUser? user, Permission permission) {
    if (user == null || !user.isActive) {
      return false;
    }
    
    // Special check for drivers: must be approved
    if (user.role == UserRole.driver) {
      if (user.approvalStatus != 'approved') {
        return false;
      }
    }
    
    // Get permissions for this role
    final permissions = _rolePermissions[user.role];
    if (permissions == null) {
      return false;
    }
    
    return permissions.contains(permission);
  }
  
  /// Check if user has ANY of the specified permissions
  /// 
  /// Example:
  /// ```dart
  /// if (PermissionService.hasAnyPermission(user, [
  ///   Permission.deliveriesManage,
  ///   Permission.deliveriesApprove
  /// ])) {
  ///   // Show delivery actions
  /// }
  /// ```
  static bool hasAnyPermission(AppUser? user, List<Permission> permissions) {
    return permissions.any((permission) => hasPermission(user, permission));
  }
  
  /// Check if user has ALL of the specified permissions
  /// 
  /// Example:
  /// ```dart
  /// if (PermissionService.hasAllPermissions(user, [
  ///   Permission.deliveriesManage,
  ///   Permission.customersManage
  /// ])) {
  ///   // Show advanced workflow
  /// }
  /// ```
  static bool hasAllPermissions(AppUser? user, List<Permission> permissions) {
    return permissions.every((permission) => hasPermission(user, permission));
  }
  
  /// Check if user has any of the specified roles
  /// 
  /// Example:
  /// ```dart
  /// if (PermissionService.hasAnyRole(user, [UserRole.admin, UserRole.manager])) {
  ///   // Show management features
  /// }
  /// ```
  static bool hasAnyRole(AppUser? user, List<UserRole> roles) {
    if (user == null || !user.isActive) {
      return false;
    }
    
    return roles.contains(user.role);
  }
  
  /// Check if user has a specific role
  /// 
  /// Example:
  /// ```dart
  /// if (PermissionService.hasRole(user, UserRole.admin)) {
  ///   // Show admin panel
  /// }
  /// ```
  static bool hasRole(AppUser? user, UserRole role) {
    if (user == null || !user.isActive) {
      return false;
    }
    
    return user.role == role;
  }
  
  /// Check if user can access a specific screen/feature
  /// This is a higher-level abstraction over permissions
  /// 
  /// Example:
  /// ```dart
  /// if (PermissionService.canAccess(user, 'user_management')) {
  ///   // Show user management menu item
  /// }
  /// ```
  static bool canAccess(AppUser? user, String feature) {
    if (user == null || !user.isActive) {
      return false;
    }
    
    // Map features to required permissions
    switch (feature) {
      case 'user_management':
        return hasPermission(user, Permission.usersManage);
      
      case 'delivery_management':
        return hasAnyPermission(user, [
          Permission.deliveriesManage,
          Permission.deliveriesView,
        ]);
      
      case 'pod_upload':
        return hasPermission(user, Permission.podsUpload);
      
      case 'financial_reports':
        return hasPermission(user, Permission.financeView);
      
      case 'analytics_dashboard':
        return hasPermission(user, Permission.analyticsView);
      
      case 'claims_management':
        return hasAnyPermission(user, [
          Permission.claimsView,
          Permission.claimsApprove,
        ]);
      
      case 'customer_management':
        return hasAnyPermission(user, [
          Permission.customersView,
          Permission.customersManage,
        ]);
      
      case 'driver_dashboard':
        return hasRole(user, UserRole.driver) && 
               user.approvalStatus == 'approved';
      
      case 'admin_dashboard':
        return hasRole(user, UserRole.admin);
      
      default:
        return false;
    }
  }
  
  /// Get all permissions for a specific role
  /// Useful for displaying role capabilities in UI
  /// 
  /// Example:
  /// ```dart
  /// final permissions = PermissionService.getPermissionsForRole(UserRole.manager);
  /// for (var permission in permissions) {
  ///   print(permission.displayName);
  /// }
  /// ```
  static Set<Permission> getPermissionsForRole(UserRole role) {
    return _rolePermissions[role] ?? {};
  }
  
  /// Get user's company-scoped query constraint
  /// Ensures multi-tenancy - users only see data from their company
  /// 
  /// Example:
  /// ```dart
  /// query.where('companyId', isEqualTo: user.companyId)
  /// ```
  static String? getCompanyId(AppUser? user) {
    return user?.companyId;
  }
  
  /// Check if user is active and can perform any actions
  static bool isActive(AppUser? user) {
    return user != null && user.isActive;
  }
  
  /// Check if driver is approved for deliveries
  static bool isDriverApproved(AppUser? user) {
    if (user == null || user.role != UserRole.driver) {
      return false;
    }
    
    return user.approvalStatus == 'approved' && user.isActive;
  }
  
  /// Helper to require admin role
  /// Throws exception if user is not admin
  /// Use in backend/cloud functions for stricter enforcement
  static void requireAdmin(AppUser? user) {
    if (!hasRole(user, UserRole.admin)) {
      throw Exception('Admin access required');
    }
  }
  
  /// Helper to require any of specified roles
  /// Throws exception if user doesn't have required role
  static void requireAnyRole(AppUser? user, List<UserRole> roles) {
    if (!hasAnyRole(user, roles)) {
      throw Exception('Insufficient permissions: Required roles: ${roles.map((r) => r.name).join(', ')}');
    }
  }
  
  /// Helper to require specific permission
  /// Throws exception if user doesn't have permission
  static void requirePermission(AppUser? user, Permission permission) {
    if (!hasPermission(user, permission)) {
      throw Exception('Insufficient permissions: ${permission.displayName} required');
    }
  }
}
