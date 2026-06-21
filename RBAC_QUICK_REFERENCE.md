# RBAC Quick Reference - PODSafe

## 🎯 Quick Start

### Import Required Files
```dart
import 'package:podsafe/models/permission.dart';
import 'package:podsafe/services/permission_service.dart';
import 'package:podsafe/widgets/permission_guard.dart';
```

---

## 👥 Roles

```dart
UserRole.admin          // Full access
UserRole.manager        // View/approve PODs, reports
UserRole.logistics      // Create deliveries, assign drivers
UserRole.accountant     // View financials, export
UserRole.filing_clerk   // Upload/tag PODs
UserRole.driver         // Scan PODs, deliveries (requires approval)
```

---

## ✅ Permission Checks

### In Code
```dart
// Single permission
if (PermissionService.hasPermission(user, Permission.deliveriesManage)) {
  // Do something
}

// Any permission
if (PermissionService.hasAnyPermission(user, [
  Permission.deliveriesManage,
  Permission.deliveriesApprove
])) { }

// All permissions
if (PermissionService.hasAllPermissions(user, [...])) { }

// Role check
if (PermissionService.hasRole(user, UserRole.admin)) { }

// Any role
if (PermissionService.hasAnyRole(user, [UserRole.admin, UserRole.manager])) { }

// Feature access
if (PermissionService.canAccess(user, 'user_management')) { }
```

---

## 🎨 UI Guards

### Hide Widget
```dart
PermissionGuard(
  permission: Permission.deliveriesManage,
  child: CreateButton(),
  fallback: SizedBox.shrink(), // Optional
)
```

### Conditional Rendering
```dart
PermissionBuilder(
  permission: Permission.usersManage,
  builder: (context, hasAccess) {
    return Button(
      onPressed: hasAccess ? _action : null,
      child: Text('Action'),
    );
  },
)
```

### Role-Based Button
```dart
RoleBasedButton(
  permission: Permission.deliveriesManage,
  onPressed: _createDelivery,
  child: Text('Create'),
)
```

### Protected Route
```dart
Navigator.push(
  context,
  PermissionRoute(
    permission: Permission.usersManage,
    builder: (context) => UserManagementScreen(),
  ),
)
```

---

## 🔧 Admin Functions

### Create User
```dart
final authProvider = context.read<AuthProvider>();

await authProvider.createUserAsAdmin(
  email: 'user@company.com',
  password: 'pass123',
  fullName: 'John Doe',
  role: UserRole.manager,
  phoneNumber: '+27123456789', // Optional
);
```

### Update User
```dart
await authProvider.updateUserAsAdmin(updatedUser);
```

### Change Role
```dart
await authProvider.assignRole(userId, UserRole.logistics);
```

### Activate/Deactivate
```dart
await authProvider.toggleUserStatus(userId, true);  // Activate
await authProvider.toggleUserStatus(userId, false); // Deactivate
```

### Reset Password
```dart
await authProvider.sendPasswordResetEmail('user@company.com');
```

---

## 📋 All Permissions

```dart
// Deliveries
Permission.deliveriesView
Permission.deliveriesManage
Permission.deliveriesApprove
Permission.deliveriesDelete

// PODs
Permission.podsView
Permission.podsUpload
Permission.podsApprove
Permission.podsEdit

// Finance
Permission.financeView
Permission.financeExport
Permission.financeEdit

// Users (Admin only)
Permission.usersView
Permission.usersManage
Permission.usersAssignRoles

// Claims
Permission.claimsView
Permission.claimsCreate
Permission.claimsApprove

// Customers
Permission.customersView
Permission.customersManage

// Analytics
Permission.analyticsView
Permission.analyticsExport

// Driver-specific
Permission.driverDeliveries
Permission.driverPodCapture
```

---

## 🚀 Common Patterns

### Protect Admin Screen
```dart
class AdminScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PermissionBuilder(
      permission: Permission.usersManage,
      builder: (context, hasAccess) {
        if (!hasAccess) {
          return AccessDeniedScreen();
        }
        return Scaffold(...);
      },
    );
  }
}
```

### Show/Hide Menu Items
```dart
if (showIfPermitted(context, Permission.usersManage)) {
  menuItems.add(UserManagementItem());
}
```

### Protect FAB
```dart
floatingActionButton: PermissionGuard(
  permission: Permission.deliveriesManage,
  child: FloatingActionButton(...),
)
```

---

## 🔒 Security Rules Snippet

```javascript
// Users can only access their company's data
function belongsToCompany(companyId) {
  return getUserData().companyId == companyId;
}

// Check role
function hasRole(role) {
  return getUserData().role == role;
}

// Driver must be approved
function isApprovedDriver() {
  return hasRole('driver') && 
         getUserData().approvalStatus == 'approved';
}
```

---

## 🔄 Migration

```bash
# Run migration script
dart run scripts/migrate_user_roles.dart

# Deploy Firestore rules
cp firestore.rules.rbac firestore.rules
firebase deploy --only firestore:rules
```

---

## 🐛 Quick Fixes

**Can't access feature?**
- Check `user.isActive == true`
- Drivers: Check `approvalStatus == 'approved'`
- Verify `companyId` matches

**Permission denied?**
- Run migration script
- Deploy new Firestore rules
- Check user has correct role

**Can't create users?**
- Must be admin
- Must have `companyId`
- Check Firestore rules deployed

---

## 📖 Full Documentation
See `RBAC_IMPLEMENTATION_GUIDE.md` for complete details.
