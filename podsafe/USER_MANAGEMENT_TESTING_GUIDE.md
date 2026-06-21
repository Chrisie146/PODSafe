# 🧪 User Management Testing Guide - Step-by-Step

## 📋 Prerequisites

Before testing, ensure:
- ✅ Firebase is configured and running
- ✅ You have at least one admin user in your database
- ✅ Flutter app compiles without errors (`flutter analyze` passed)

---

## 🚀 Phase 1: Build & Launch the App

### Step 1: Run the App

```bash
# Make sure you're in the project directory
cd C:\Users\christopherm\PODSafe\podsafe

# Run the app (Chrome or Android/iOS)
flutter run

# Or for Chrome specifically:
flutter run -d chrome
```

**Expected Result:** App launches successfully without errors

---

## 🔐 Phase 2: Login as Admin

### Step 2: Sign In

1. **Launch the app** - You should see the login screen
2. **Enter admin credentials:**
   - Email: Your admin email
   - Password: Your admin password
3. **Tap "Login"**

**Expected Result:** 
- ✅ Login successful
- ✅ Redirected to Admin Dashboard
- ✅ See company info and delivery stats

**Troubleshooting:**
- ❌ **If login fails:** Check Firebase Console → Authentication → Users
- ❌ **If no admin exists:** See "Creating First Admin User" below

---

## 👥 Phase 3: Access User Management

### Step 3: Navigate to User Management

1. **From Admin Dashboard**, look for the action buttons grid
2. **Find the "User Management" button** (purple color with admin_panel_settings icon)
3. **Tap/Click the button**

**Expected Result:**
- ✅ Opens User Management screen
- ✅ Shows search bar at top
- ✅ Shows list of existing users (if any)
- ✅ Shows floating action button "+ Add User" at bottom right

**What You'll See:**
```
┌─────────────────────────────────────┐
│ User Management                     │
│ [🔍 Search users...]           [⚙️]│
├─────────────────────────────────────┤
│                                     │
│  👤 John Doe                        │
│     john@company.com                │
│     [ADMIN] [Active]               │
│                                     │
│  👤 Jane Smith                      │
│     jane@company.com                │
│     [DRIVER] [Pending]             │
│                                     │
└─────────────────────────────────────┘
           [+ Add User] ←── FAB
```

---

## ➕ Phase 4: Create New User

### Step 4: Add a Manager User

1. **Tap the "+ Add User" FAB** (floating action button)
2. **Fill in the form:**
   - **Full Name:** `Test Manager`
   - **Email:** `manager@test.com`
   - **Phone:** `+27821234567` (optional)
   - **Initial Password:** `TestPass123`
   - **Role:** Select "Manager" from dropdown
3. **Tap "Create"**

**Expected Result:**
- ✅ Shows loading indicator briefly
- ✅ Dialog closes
- ✅ Shows "User created successfully" snackbar
- ✅ New user appears in the list
- ✅ User has green "MANAGER" badge

**Screenshot of Create Dialog:**
```
┌──────────────────────────────────┐
│ Create New User             ✕   │
├──────────────────────────────────┤
│ Full Name                        │
│ [Test Manager              ]    │
│                                  │
│ Email                            │
│ [manager@test.com          ]    │
│                                  │
│ Phone (Optional)                 │
│ [+27821234567              ]    │
│                                  │
│ Initial Password                 │
│ [••••••••••                ]    │
│ User can change this after login │
│                                  │
│ Role                             │
│ [Manager ▼                 ]    │
│                                  │
│     [Cancel]      [Create]      │
└──────────────────────────────────┘
```

### Step 5: Create Users for Each Role

Repeat Step 4 for each role:

| Role | Email | Password | Expected Badge Color |
|------|-------|----------|---------------------|
| Admin | `admin2@test.com` | `TestPass123` | 🔴 Red |
| Manager | `manager@test.com` | `TestPass123` | 🔵 Blue |
| Logistics | `logistics@test.com` | `TestPass123` | 🟢 Green |
| Accountant | `accountant@test.com` | `TestPass123` | 🟣 Purple |
| Filing Clerk | `clerk@test.com` | `TestPass123` | 🟠 Orange |
| Driver | `driver@test.com` | `TestPass123` | 🔷 Teal |

**Expected Result:**
- ✅ All 6 users created successfully
- ✅ Each has different colored role badge
- ✅ All show as "Active" (green chip)
- ✅ Driver shows "Pending" approval status

---

## 🔍 Phase 5: View User Details

### Step 6: Inspect a User

1. **Tap on any user** in the list (e.g., "Test Manager")
2. **Bottom sheet slides up** showing user details

**Expected Result - User Details Sheet:**
```
┌──────────────────────────────────────┐
│ User Details                    ✕   │
├──────────────────────────────────────┤
│ Full Name       Test Manager        │
│ Email           manager@test.com    │
│ Phone           +27821234567        │
│ Role            Manager             │
│ Status          Active              │
│ Company ID      your-company-id     │
│                                     │
│ Permissions                         │
│ [View Deliveries] [Manage Deliveries]│
│ [Approve Deliveries] [View PODs]    │
│ [Approve PODs] [Edit PODs]          │
│ [View Finance] [View Claims]        │
│ [Approve Claims] [View Customers]   │
│ [View Analytics] [Export Analytics] │
│                                     │
│ [Edit User]                         │
│ [Deactivate User]                   │
│ [Reset Password]                    │
└──────────────────────────────────────┘
```

**What to Check:**
- ✅ All user info displayed correctly
- ✅ Permissions list shows role-appropriate permissions
- ✅ Three action buttons present
- ✅ No errors in console

---

## ✏️ Phase 6: Edit User

### Step 7: Change User Role

1. **From the User Details sheet**, tap "Edit User"
2. **Change the role** from "Manager" to "Logistics"
3. **Optionally update** phone number or name
4. **Tap "Update"**

**Expected Result:**
- ✅ Dialog closes
- ✅ Shows "User updated successfully"
- ✅ User list refreshes
- ✅ User now shows green "LOGISTICS" badge
- ✅ If you open details again, permissions changed

**Before vs After:**
```
BEFORE:                    AFTER:
┌──────────────────┐      ┌──────────────────┐
│ Test Manager     │      │ Test Manager     │
│ manager@test.com │      │ manager@test.com │
│ [MANAGER]        │  →   │ [LOGISTICS]      │
└──────────────────┘      └──────────────────┘
```

---

## 🔒 Phase 7: Deactivate User

### Step 8: Deactivate a User

1. **Open user details** for the test manager
2. **Tap "Deactivate User"**
3. **Confirm** in the dialog
4. **Wait for success message**

**Expected Result:**
- ✅ Shows "User deactivated successfully"
- ✅ User appears grayed out in list
- ✅ Shows "Inactive" chip next to name
- ✅ User cannot login anymore

**Inactive User Appearance:**
```
┌──────────────────────────────────┐
│ 👤 Test Manager (grayed)        │
│    manager@test.com              │
│    [LOGISTICS] [Inactive]        │
└──────────────────────────────────┘
```

### Step 9: Reactivate User

1. **Tap the deactivated user**
2. **Tap "Activate User"** (button text changed)
3. **Confirm**

**Expected Result:**
- ✅ User becomes active again
- ✅ No longer grayed out
- ✅ "Inactive" chip removed

---

## 📧 Phase 8: Password Reset

### Step 10: Send Password Reset

1. **Open user details** for any user
2. **Tap "Reset Password"**
3. **Confirm** the action

**Expected Result:**
- ✅ Shows "Password reset email sent to [email]"
- ✅ User receives email from Firebase
- ✅ Email contains reset link

**Note:** Check the user's email inbox (may be in spam)

---

## 🔍 Phase 9: Search & Filter

### Step 11: Search Users

1. **In User Management screen**, tap the search bar
2. **Type:** `manager`

**Expected Result:**
- ✅ List filters to show only users with "manager" in name/email
- ✅ Updates in real-time as you type

### Step 12: Filter by Role

1. **Tap the filter icon** (⚙️) in the top right
2. **Select "Role"** dropdown
3. **Choose "Driver"**
4. **Tap "Apply"**

**Expected Result:**
- ✅ Shows only users with Driver role
- ✅ Shows filter chip below search bar
- ✅ Can remove filter by tapping X on chip

### Step 13: Show Inactive Users

1. **Open filters** again
2. **Check "Show Inactive Users"**
3. **Tap "Apply"**

**Expected Result:**
- ✅ Inactive users now visible in list
- ✅ Filter chip shows "Show Inactive"
- ✅ Can combine with role filter

---

## 🚦 Phase 10: Test Permission Guards

Now let's verify permissions work correctly!

### Step 14: Logout and Test Manager Login

1. **Logout** from admin account
2. **Login as Manager:**
   - Email: `manager@test.com`
   - Password: `TestPass123`

**Expected Result:**
- ✅ Login successful
- ✅ Redirected to appropriate dashboard
- ✅ **User Management button HIDDEN** (managers can't manage users)
- ✅ Can see Delivery Management
- ✅ Can see Analytics Dashboard
- ✅ **CANNOT create deliveries** (no + FAB)

### Step 15: Test Logistics Login

1. **Logout**
2. **Login as Logistics:**
   - Email: `logistics@test.com`
   - Password: `TestPass123`

**Expected Result:**
- ✅ Can see Delivery Management
- ✅ **CAN create deliveries** (+ FAB visible)
- ✅ **CANNOT see Analytics** (permission denied)
- ✅ **CANNOT manage users**

### Step 16: Test Driver Login

1. **Logout**
2. **Login as Driver:**
   - Email: `driver@test.com`
   - Password: `TestPass123`

**Expected Result:**
- ✅ Redirected to Driver Dashboard (not Admin Dashboard)
- ✅ Can see assigned deliveries only
- ✅ **CANNOT access admin features**
- ✅ Shows "Pending Approval" message (driver not approved yet)

---

## ✅ Phase 11: Approve Driver

### Step 17: Approve the Driver

1. **Logout and login as Admin**
2. **Go to Driver Management** (existing screen)
3. **Find the test driver**
4. **Approve the driver**
5. **Logout and login as driver again**

**Expected Result:**
- ✅ Driver can now access deliveries
- ✅ Can capture PODs
- ✅ No longer shows pending approval

---

## 🐛 Phase 12: Error Testing

### Step 18: Test Validation

Try creating a user with invalid data:

1. **Open Create User dialog**
2. **Leave Full Name empty**
3. **Tap Create**

**Expected Result:**
- ❌ Shows "Please enter full name" error
- ❌ Dialog stays open

4. **Fill name, but enter invalid email** (e.g., "notanemail")
5. **Tap Create**

**Expected Result:**
- ❌ Shows "Please enter valid email" error

6. **Enter password less than 6 characters**
7. **Tap Create**

**Expected Result:**
- ❌ Shows "Password must be at least 6 characters" error

### Step 19: Test Duplicate Email

1. **Try creating a user** with email that already exists
2. **Tap Create**

**Expected Result:**
- ❌ Shows error "An account already exists with this email"
- ❌ User not created

---

## 📊 Phase 13: Verify Firestore Data

### Step 20: Check Firebase Console

1. **Open Firebase Console**
2. **Go to Firestore Database**
3. **Navigate to `users` collection**

**What to Verify:**
```json
{
  "email": "manager@test.com",
  "fullName": "Test Manager",
  "role": "logistics",  ← Check role is correct
  "companyId": "your-company-id",
  "isActive": true,     ← Should be true
  "createdAt": Timestamp,
  "lastLoginAt": null or Timestamp
}
```

**Check:**
- ✅ All fields present
- ✅ `role` matches selected role
- ✅ `isActive` is `true`
- ✅ `companyId` matches admin's company
- ✅ No missing required fields

---

## 🎯 Success Criteria Checklist

After all tests, verify:

### User Management
- [ ] ✅ Can create users with all 6 roles
- [ ] ✅ Can edit user details and roles
- [ ] ✅ Can activate/deactivate users
- [ ] ✅ Can send password reset emails
- [ ] ✅ Can search users by name/email
- [ ] ✅ Can filter by role
- [ ] ✅ Can show/hide inactive users
- [ ] ✅ User details show correct permissions
- [ ] ✅ Role badges display with correct colors

### Permission Guards
- [ ] ✅ Admin sees all features
- [ ] ✅ Manager cannot manage users
- [ ] ✅ Manager cannot create deliveries
- [ ] ✅ Logistics can create deliveries
- [ ] ✅ Accountant can view analytics
- [ ] ✅ Driver only sees driver dashboard
- [ ] ✅ Unapproved driver blocked from deliveries
- [ ] ✅ Inactive users cannot login

### Data Integrity
- [ ] ✅ Users stored correctly in Firestore
- [ ] ✅ All required fields present
- [ ] ✅ Company ID isolation working
- [ ] ✅ Role changes persist
- [ ] ✅ Status changes persist

---

## 🔧 Troubleshooting

### Problem: User Management button not visible

**Solution:**
- Make sure you're logged in as admin
- Check `user.role == 'admin'` in Firestore
- Check console for permission errors

### Problem: Cannot create users

**Solutions:**
1. Check Firebase Console → Authentication → Settings
2. Ensure "Email/Password" provider is enabled
3. Check Firestore rules allow admin to create users
4. Look for errors in browser/app console

### Problem: Users can access unauthorized features

**Solutions:**
1. Deploy Firestore security rules: `firebase deploy --only firestore:rules`
2. Check user has correct role in Firestore
3. Verify `isActive == true`
4. Clear app cache and restart

### Problem: Driver shows as approved but can't access deliveries

**Solutions:**
1. Check Firestore: `approvalStatus == 'approved'`
2. Check `isActive == true`
3. Ensure driver has deliveries assigned
4. Check companyId matches

---

## 🎬 Quick Test Script

Run through this in 5 minutes:

```
1. ✅ Login as admin
2. ✅ Open User Management
3. ✅ Create 1 user (any role)
4. ✅ View user details
5. ✅ Edit user role
6. ✅ Deactivate user
7. ✅ Reactivate user
8. ✅ Search for user
9. ✅ Logout, login as new user
10. ✅ Verify can't see User Management
```

---

## 📸 Expected UI Screenshots Reference

### User List Screen:
- Search bar at top
- Filter icon (⚙️) in app bar
- Scrollable user list
- Each user shows: avatar, name, email, role badge, status
- FAB "+ Add User" at bottom right

### Create User Dialog:
- 5 input fields (name, email, phone, password, role)
- Role dropdown with 6 options
- Password helper text
- Cancel and Create buttons

### User Details Sheet:
- User info section (6 fields)
- Permissions section (chips)
- 3 action buttons (Edit, Deactivate, Reset)
- Scrollable content

### Edit User Dialog:
- Same as create but password field hidden
- Pre-filled with current values
- Cancel and Update buttons

---

## 🚀 Next: Production Testing

Once all tests pass:

1. ✅ Run migration script: `dart run scripts/migrate_user_roles.dart`
2. ✅ Deploy Firestore rules: `firebase deploy --only firestore:rules`
3. ✅ Test with real users
4. ✅ Monitor Firebase Console for errors
5. ✅ Set up audit logging (optional)

---

**You're ready to test! 🎉**

Start with Phase 1 and work through each phase systematically. Take screenshots of any issues you encounter!
