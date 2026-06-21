# Role-Based Access Control (RBAC) Implementation - PODSafe

## 🎯 Overview

This document describes the complete RBAC implementation for PODSafe, providing granular role-based permissions for secure multi-tenant access control.

---

## 📋 Roles & Permissions

### **Roles Defined**

| Role | Code | Description |
|------|------|-------------|
| **Administrator** | `admin` | Full system access, user management, all features |
| **Manager** | `manager` | View/approve PODs, view reports, manage deliveries |
| **Logistics** | `logistics` | Create deliveries, assign drivers, manage customers |
| **Accountant** | `accountant` | View financials, export reports, view claims |
| **Filing Clerk** | `filing_clerk` | Upload and tag scanned PODs |
| **Driver** | `driver` | Scan/upload PODs, mark deliveries complete |

### **Permission Matrix**

| Permission | Admin | Manager | Logistics | Accountant | Filing Clerk | Driver |
|------------|-------|---------|-----------|------------|--------------|--------|
| `deliveriesView` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅* |
| `deliveriesManage` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `deliveriesApprove` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `deliveriesDelete` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `podsView` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅* |
| `podsUpload` | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| `podsApprove` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `podsEdit` | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| `financeView` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| `financeExport` | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `financeEdit` | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `usersView` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `usersManage` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `usersAssignRoles` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `claimsView` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅* |
| `claimsCreate` | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `claimsApprove` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `customersView` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `customersManage` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `analyticsView` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| `analyticsExport` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| `driverDeliveries` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `driverPodCapture` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

**Note:** * = Only for assigned/own deliveries, requires `approvalStatus == 'approved'`

---

## 🏗️ Architecture

### **Files Created/Modified**

```
lib/
├── models/
│   ├── user_model.dart          [MODIFIED] - Added 6 roles, isActive field
│   └── permission.dart           [NEW] - Permission enum definitions
├── services/
│   ├── auth_service.dart         [MODIFIED] - Admin user management methods
│   └── permission_service.dart   [NEW] - RBAC logic and permission checks
├── providers/
│   └── auth_provider.dart        [MODIFIED] - Admin methods, role getters
├── widgets/
│   └── permission_guard.dart     [NEW] - UI permission guards
├── screens/
│   ├── admin/
│   │   ├── user_management_screen.dart  [NEW] - User CRUD UI
│   │   ├── admin_dashboard_screen.dart  [MODIFIED] - Added user mgmt button
│   │   ├── delivery_management_screen.dart [MODIFIED] - Permission demos
│   │   └── analytics_dashboard_screen.dart [MODIFIED] - Permission demos
scripts/
└── migrate_user_roles.dart       [NEW] - Migration script for existing users

firestore.rules.rbac              [NEW] - Multi-tenant RBAC security rules
```

---

## 🚀 Usage Examples

### **1. Check Permission in Code**

```dart
import 'package:provider/provider.dart';
import '../models/permission.dart';
import '../services/permission_service.dart';

// In your widget
final user = context.read<AuthProvider>().currentUser;

if (PermissionService.hasPermission(user, Permission.deliveriesManage)) {
  // Show create delivery button
}

// Check multiple permissions
if (PermissionService.hasAnyPermission(user, [
  Permission.deliveriesManage,
  Permission.deliveriesApprove
])) {
  // Show delivery actions
}
```

### **2. Protect UI Elements**

```dart
import '../widgets/permission_guard.dart';

// Hide widget if no permission
PermissionGuard(
  permission: Permission.deliveriesManage,
  child: FloatingActionButton(
    onPressed: _createDelivery,
    child: Icon(Icons.add),
  ),
)

// Conditional rendering
PermissionBuilder(
  permission: Permission.usersManage,
  builder: (context, hasAccess) {
    return ElevatedButton(
      onPressed: hasAccess ? _manageUsers : null,
      child: Text('Manage Users'),
    );
  },
)
```

### **3. Protect Routes**

```dart
import '../widgets/permission_guard.dart';

Navigator.push(
  context,
  PermissionRoute(
    permission: Permission.usersManage,
    builder: (context) => UserManagementScreen(),
    fallbackRoute: (context) => AccessDeniedScreen(),
  ),
)
```

### **4. Admin User Management**

```dart
final authProvider = context.read<AuthProvider>();

// Create new user
await authProvider.createUserAsAdmin(
  email: 'newuser@company.com',
  password: 'initialPassword123',
  fullName: 'John Doe',
  role: UserRole.logistics,
  phoneNumber: '+27123456789',
);

// Update user role
await authProvider.assignRole(userId, UserRole.manager);

// Deactivate user
await authProvider.toggleUserStatus(userId, false);

// Send password reset
await authProvider.sendPasswordResetEmail('user@company.com');
```

---

## 🔒 Firestore Security Rules

### **Multi-Tenant Isolation**

All documents have a `companyId` field. Rules ensure:
- Users only access data from their own company
- Cross-company data access is blocked
- Admins cannot access other companies' data

### **Role-Based Access**

```javascript
// Example: Deliveries collection
match /deliveries/{deliveryId} {
  // Manager can view all company deliveries
  allow read: if hasRole('manager') && isCompanyDocument(resource.data);
  
  // Driver can only view assigned deliveries (and must be approved)
  allow read: if isApprovedDriver() && 
                 resource.data.driverId == request.auth.uid;
  
  // Admin, Manager, Logistics can create/edit
  allow write: if canManageDeliveries();
}
```

### **Deployment**

```bash
# Test rules locally
firebase emulators:start --only firestore

# Deploy rules to production
firebase deploy --only firestore:rules

# Or copy firestore.rules.rbac to firestore.rules
cp firestore.rules.rbac firestore.rules
firebase deploy --only firestore:rules
```

---

## 🔄 Migration Guide

### **Migrate Existing Users**

Run the migration script to add roles and `isActive` flags:

```bash
# From project root
dart run scripts/migrate_user_roles.dart
```

**What it does:**
- Assigns `driver` role to users with driver fields
- Assigns `manager` role to all other users (default staff)
- Sets `isActive = true` for all users
- Migrates legacy approval status for drivers

**Review before production:**
1. Test on a backup/staging database first
2. Review the console output for changes
3. Manually assign correct roles for specific users

### **Manual Role Assignment**

```dart
// In Firebase Console or via script
final firestore = FirebaseFirestore.instance;

await firestore.collection('users').doc(userId).update({
  'role': 'admin',
  'isActive': true,
});
```

---

## 🛡️ Security Best Practices

### **1. Password Management**
- Minimum 6 characters (enforced by Firebase Auth)
- Admin sets initial password when creating users
- Users can reset via email link
- Admins cannot see user passwords

### **2. User Deactivation**
- Use `isActive = false` instead of deleting
- Preserves audit trail
- Can be reactivated if needed

### **3. Driver Approval**
- Drivers must have `approvalStatus == 'approved'` to access deliveries
- Even if role is `driver`, unapproved users have no access
- Admin/Manager must manually approve drivers

### **4. Least Privilege**
- Default new users to lowest necessary role
- Grant additional permissions explicitly
- Review roles quarterly

---

## 🧪 Testing

### **Test User Creation**

```dart
// As admin
final authProvider = context.read<AuthProvider>();

// Test creating each role
for (var role in UserRole.values) {
  await authProvider.createUserAsAdmin(
    email: 'test_${role.name}@company.com',
    password: 'TestPass123',
    fullName: 'Test ${role.name}',
    role: role,
  );
}
```

### **Test Permission Checks**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin has all permissions', () {
    final admin = AppUser(
      id: '1',
      email: 'admin@test.com',
      fullName: 'Admin',
      role: UserRole.admin,
      companyId: 'company1',
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    for (var permission in Permission.values) {
      expect(
        PermissionService.hasPermission(admin, permission),
        true,
        reason: 'Admin should have ${permission.name}',
      );
    }
  });
  
  test('Driver cannot manage users', () {
    final driver = AppUser(
      id: '2',
      email: 'driver@test.com',
      fullName: 'Driver',
      role: UserRole.driver,
      companyId: 'company1',
      isActive: true,
      approvalStatus: 'approved',
      createdAt: DateTime.now(),
    );
    
    expect(
      PermissionService.hasPermission(driver, Permission.usersManage),
      false,
    );
  });
}
```

---

## 🔧 Extension Points

### **Adding New Roles**

1. Add to `UserRole` enum in `lib/models/user_model.dart`
2. Update `_rolePermissions` map in `lib/services/permission_service.dart`
3. Update Firestore rules in `firestore.rules.rbac`
4. Update documentation

### **Adding New Permissions**

1. Add to `Permission` enum in `lib/models/permission.dart`
2. Add `displayName` and `description` in extension
3. Map to roles in `PermissionService._rolePermissions`
4. Implement in Firestore rules if needed

### **Custom Permission Logic**

```dart
// Override in PermissionService
static bool hasCustomPermission(AppUser? user, String feature) {
  // Complex logic combining multiple factors
  if (feature == 'high_value_delivery') {
    return hasAnyRole(user, [UserRole.admin, UserRole.manager]) &&
           user?.experienceLevel == 'senior';
  }
  return false;
}
```

---

## 📊 Monitoring & Audit

### **User Activity Logs**

Consider adding audit logging for sensitive actions:

```dart
// In AuthProvider.assignRole()
await FirebaseFirestore.instance.collection('audit_logs').add({
  'action': 'role_assigned',
  'performedBy': currentUser!.id,
  'targetUser': userId,
  'oldRole': oldRole,
  'newRole': role.toString(),
  'timestamp': FieldValue.serverTimestamp(),
  'companyId': currentUser!.companyId,
});
```

---

## 🐛 Troubleshooting

### **Issue: User can't access features**
- Check `isActive == true`
- For drivers: Check `approvalStatus == 'approved'`
- Verify `companyId` matches document `companyId`
- Check Firestore rules are deployed

### **Issue: Admin can't create users**
- Verify admin is authenticated
- Check admin has `role == 'admin'`
- Ensure `companyId` is set correctly
- Check Firestore rules allow admin write access

### **Issue: Permission denied errors**
- Run migration script if upgrading from old version
- Check Firestore rules are updated and deployed
- Verify user document has all required fields

---

## ✅ Checklist for Production

- [ ] Run migration script on all existing users
- [ ] Deploy new Firestore security rules
- [ ] Test each role can access appropriate features
- [ ] Test permission denials work correctly
- [ ] Create at least one admin user for each company
- [ ] Document custom role assignments
- [ ] Set up audit logging for user management
- [ ] Train admins on user management UI
- [ ] Backup database before deployment

---

## 📞 Support

For questions or issues with RBAC implementation:
1. Check this documentation
2. Review permission matrix above
3. Test with migration script in dev environment
4. Check Firestore rules in Firebase Console

---

**Version:** 1.0  
**Last Updated:** October 2025  
**Author:** PODSafe Development Team
