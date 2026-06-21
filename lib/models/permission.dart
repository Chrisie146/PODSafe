/// Permission actions for RBAC system
/// These represent granular actions that can be performed in the app
/// 
/// Extension points:
/// - Add new permissions as needed (e.g., claims.manage, reports.schedule)
/// - Update PermissionService to map roles to new permissions
enum Permission {
  // Delivery permissions
  deliveriesView,      // View delivery list
  deliveriesManage,    // Create, edit deliveries
  deliveriesApprove,   // Approve delivery assignments
  deliveriesDelete,    // Delete deliveries
  
  // POD (Proof of Delivery) permissions
  podsView,            // View POD list
  podsUpload,          // Upload new PODs
  podsApprove,         // Approve uploaded PODs
  podsEdit,            // Edit POD metadata/tags
  
  // Finance permissions
  financeView,         // View financial reports
  financeExport,       // Export financial data
  financeEdit,         // Edit financial records
  
  // User management permissions (admin only)
  usersView,           // View user list
  usersManage,         // Create, edit, deactivate users
  usersAssignRoles,    // Assign/change user roles
  
  // Claims permissions
  claimsView,          // View claims
  claimsCreate,        // Create new claims
  claimsApprove,       // Approve/reject claims
  
  // Customer permissions
  customersView,       // View customer list
  customersManage,     // Create, edit customers
  
  // Analytics permissions
  analyticsView,       // View analytics dashboard
  analyticsExport,     // Export analytics data
  
  // Reports permissions
  reportsView,         // View reports
  reportsExport,       // Export reports
  
  // Driver-specific permissions
  driverDeliveries,    // View assigned deliveries (driver only)
  driverPodCapture,    // Capture POD signatures/photos (driver only)
}

/// Extension to get human-readable permission names
extension PermissionExtension on Permission {
  String get displayName {
    switch (this) {
      case Permission.deliveriesView:
        return 'View Deliveries';
      case Permission.deliveriesManage:
        return 'Manage Deliveries';
      case Permission.deliveriesApprove:
        return 'Approve Deliveries';
      case Permission.deliveriesDelete:
        return 'Delete Deliveries';
      case Permission.podsView:
        return 'View PODs';
      case Permission.podsUpload:
        return 'Upload PODs';
      case Permission.podsApprove:
        return 'Approve PODs';
      case Permission.podsEdit:
        return 'Edit PODs';
      case Permission.financeView:
        return 'View Finance';
      case Permission.financeExport:
        return 'Export Finance Data';
      case Permission.financeEdit:
        return 'Edit Finance';
      case Permission.usersView:
        return 'View Users';
      case Permission.usersManage:
        return 'Manage Users';
      case Permission.usersAssignRoles:
        return 'Assign Roles';
      case Permission.claimsView:
        return 'View Claims';
      case Permission.claimsCreate:
        return 'Create Claims';
      case Permission.claimsApprove:
        return 'Approve Claims';
      case Permission.customersView:
        return 'View Customers';
      case Permission.customersManage:
        return 'Manage Customers';
      case Permission.analyticsView:
        return 'View Analytics';
      case Permission.analyticsExport:
        return 'Export Analytics';
      case Permission.reportsView:
        return 'View Reports';
      case Permission.reportsExport:
        return 'Export Reports';
      case Permission.driverDeliveries:
        return 'Driver Deliveries';
      case Permission.driverPodCapture:
        return 'Capture POD';
    }
  }
  
  String get description {
    switch (this) {
      case Permission.deliveriesManage:
        return 'Create, edit, and assign deliveries';
      case Permission.deliveriesApprove:
        return 'Approve delivery assignments and routes';
      case Permission.podsUpload:
        return 'Upload proof of delivery documents';
      case Permission.podsApprove:
        return 'Review and approve uploaded PODs';
      case Permission.financeExport:
        return 'Export financial reports and data';
      case Permission.usersManage:
        return 'Create, edit, and deactivate user accounts';
      case Permission.usersAssignRoles:
        return 'Assign and modify user roles';
      default:
        return displayName;
    }
  }
}
