# PODSafe Firebase Configuration

This file contains instructions for configuring Firebase services for the PODSafe application.

## Firebase Services Setup

### 1. Firestore Database
- **Location**: Set in Firebase Console during initial setup
- **Collections**: users, companies, deliveries, pods
- **Rules File**: `firestore.rules`

### 2. Firebase Storage
- **Bucket**: Created in Firebase Console
- **Rules File**: `storage.rules`
- **Storage Structure**:
  - `companies/{companyId}/deliveries/{deliveryId}/pods/{podId}/` - POD photos and signatures
  - `users/{userId}/profile/` - User profile images
  - `companies/{companyId}/assets/` - Company logos and assets
  - `temp/{userId}/` - Temporary files

### 3. Firebase Authentication
- **Enabled Methods**: Email/Password
- **User Management**: Via Firebase Console or app admin features

## Deploying Security Rules

### Option 1: Using Firebase Console (Easiest)

#### Firestore Rules:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your PODSafe project
3. Navigate to **Firestore Database** → **Rules**
4. Copy the content from `firestore.rules`
5. Paste into the rules editor
6. Click **Publish**

#### Storage Rules:
1. In Firebase Console, navigate to **Storage** → **Rules**
2. Copy the content from `storage.rules`
3. Paste into the rules editor
4. Click **Publish**

### Option 2: Using Firebase CLI

If you prefer command-line deployment:

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not done)
firebase init

# Select:
# - Firestore
# - Storage
# - Use existing project: select your PODSafe project

# Deploy rules
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

## Testing the Rules

After deploying the rules, test them by:

1. **Create a test user** in Firebase Console → Authentication
2. **Sign in to the app** with the test user
3. **Try uploading a POD** with photo and signature
4. **Verify access control** by trying to access other users' data

## Firebase Configuration Files

- `firestore.rules` - Firestore database security rules
- `storage.rules` - Firebase Storage security rules
- `android/app/google-services.json` - Android Firebase configuration
- `ios/Runner/GoogleService-Info.plist` - iOS Firebase configuration (add when building for iOS)

## Security Features

### Firestore:
- Role-based access control (admin, driver)
- Company-based data isolation
- Field-level update restrictions for deliveries
- Audit trail protection

### Storage:
- Organized file structure by company and delivery
- Role-based upload/download permissions
- Secure POD file access
- Temporary file cleanup support

## Production Checklist

- [ ] Security rules deployed and tested
- [ ] Test users created with different roles
- [ ] Storage bucket configured and accessible
- [ ] Authentication methods enabled
- [ ] Firestore indexes created (Firebase will suggest these as needed)
- [ ] App Check enabled for production (optional but recommended)
- [ ] Monitoring and alerts configured

## Support

For issues or questions about Firebase configuration, refer to:
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firebase Security Rules Guide](https://firebase.google.com/docs/rules)
