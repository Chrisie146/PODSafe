# 🚀 Automated Firebase Setup

## Overview
PODSafe now includes an automated setup tool that creates all necessary test data in Firebase with a single button click!

## ✨ What Gets Created

### 1. Test Company
- **ID**: `company-001`
- **Name**: Test Company
- **Status**: Active with premium subscription

### 2. Test Users

#### Admin User
- **Email**: `admin@podsafe.com`
- **Password**: `Admin123!`
- **Role**: Admin (full access)
- **Company**: company-001

#### Driver User
- **Email**: `driver@podsafe.com`
- **Password**: `Driver123!`
- **Role**: Driver (delivery access)
- **Company**: company-001

### 3. Sample Delivery
- **Customer**: John Doe
- **Status**: Assigned to test driver
- **Pickup**: 789 Pine Rd
- **Delivery**: 456 Oak Ave
- **Scheduled**: 2-4 hours from creation

## 🎯 How to Use

### Method 1: Through the App (Easiest)

1. **Launch the app**
2. **On the login screen**, tap "Firebase Setup" button at the bottom
3. **Tap "Run Setup"** button
4. **Wait** for the setup to complete (30-60 seconds)
5. **View the logs** to see what was created
6. **Sign in** with the test credentials

### Method 2: Run the Script Directly

```bash
# From project root
flutter run lib/setup/firebase_setup_script.dart
```

## ✅ After Setup

You can immediately test with:

**Admin Access:**
```
Email: admin@podsafe.com
Password: Admin123!
```

**Driver Access:**
```
Email: driver@podsafe.com
Password: Driver123!
```

## 🔄 Running Multiple Times

The setup script is **idempotent** - it's safe to run multiple times:
- If data already exists, it will skip creation
- If users exist in Auth but not Firestore, it will create the Firestore documents
- You can run it to "repair" missing data

## 🛠️ What Happens Behind the Scenes

1. **Creates Company Document** in Firestore
2. **Creates Firebase Auth Users** (admin & driver)
3. **Creates Firestore User Documents** with roles and company assignment
4. **Creates Sample Delivery** assigned to the driver
5. **Signs out** any authenticated users

## 🐛 Troubleshooting

### "Permission Denied" Errors
- Ensure your Firestore security rules are deployed
- Check that the rules allow user creation
- Verify Firebase is properly initialized

### "Email Already in Use"
- The script handles this gracefully
- It will sign in and update the Firestore document
- No action needed - this is expected behavior

### Setup Fails Midway
- Check your internet connection
- Verify Firebase configuration is correct
- Review the error logs in the setup screen
- Try running again - it will skip completed steps

### Users Created but Can't Sign In
- Verify the user documents exist in Firestore
- Check that `role` and `companyId` fields are set correctly
- Ensure security rules allow user reads

## 📝 Manual Verification

After running setup, verify in Firebase Console:

### Firestore Database:
```
companies/
  ├─ company-001/
users/
  ├─ [admin-uid]/
  └─ [driver-uid]/
deliveries/
  └─ [auto-generated-id]/
```

### Authentication:
- 2 users should appear in the Users list
- Both emails should be verified (optional)

## ⚠️ Security Notes

### Development:
- Test credentials are fine for development
- The setup screen is accessible to everyone
- No sensitive data in test accounts

### Production:
- **REMOVE** the setup button from login screen
- **DELETE** or **PROTECT** the setup screen
- **CHANGE** all default passwords
- **DISABLE** setup functionality in production builds

## 🔒 Production Recommendations

Before deploying to production:

1. **Remove Setup Button**:
```dart
// In login_screen.dart, comment out or remove:
// TextButton.icon(
//   onPressed: () { ... SetupScreen() ... },
//   ...
// )
```

2. **Add Environment Check**:
```dart
// Only show setup in debug mode
if (kDebugMode) {
  // Setup button code
}
```

3. **Use Real Credentials**:
- Create actual admin accounts with strong passwords
- Use production email addresses
- Enable 2FA for admin accounts

## 💡 Tips

- **Run setup once** when starting development
- **Recreate data** anytime by running setup again
- **Test both roles** by signing in as admin and driver
- **Check Firebase Console** to see created data
- **Update test data** directly in Firestore as needed

## 🎓 Next Steps

After running setup:

1. ✅ Sign in as admin
2. ✅ Explore the admin dashboard
3. ✅ Sign in as driver
4. ✅ View the assigned delivery
5. ✅ Test POD capture flow
6. ✅ Verify offline functionality

## 🔗 Related Files

- `lib/setup/firebase_setup_script.dart` - Standalone script
- `lib/screens/setup/setup_screen.dart` - UI for setup
- `FIREBASE_TEST_DATA.md` - Manual setup guide (fallback)
- `FIREBASE_SETUP.md` - General Firebase configuration

---

**Ready to go!** Just tap "Firebase Setup" on the login screen and you're ready to test PODSafe! 🎉
