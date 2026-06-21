# Production Firebase Setup Guide

## Overview

This guide covers setting up a separate production Firebase project for PODSafe, configuring environment-specific settings, and implementing safe deployment procedures.

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Flutter SDK 3.8.1+
- Access to Firebase Console
- Admin access to Google Cloud Console (for advanced features)

## Step 1: Create Production Firebase Project

### 1.1 Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `podsafe-production`
4. Enable Google Analytics (recommended)
5. Select or create Analytics account
6. Wait for project creation

### 1.2 Configure Project Settings

1. Go to Project Settings (gear icon)
2. Set project ID: `podsafe-prod` (must be unique)
3. Set public-facing name: "PODSafe"
4. Set support email
5. Enable billing (required for production features)

## Step 2: Add Apps to Production Project

### 2.1 Add Android App

```bash
# In Firebase Console:
1. Click "Add app" → Android
2. Package name: com.podsafe.app
3. App nickname: PODSafe Android
4. Download google-services.json
5. Place in: android/app/google-services.json
```

### 2.2 Add iOS App

```bash
# In Firebase Console:
1. Click "Add app" → iOS
2. Bundle ID: com.podsafe.app
3. App nickname: PODSafe iOS
4. Download GoogleService-Info.plist
5. Place in: ios/Runner/GoogleService-Info.plist
```

### 2.3 Add Web App

```bash
# In Firebase Console:
1. Click "Add app" → Web
2. App nickname: PODSafe Web
3. Enable Firebase Hosting
4. Copy web configuration
```

## Step 3: Configure Firebase Services

### 3.1 Authentication

```bash
# Enable authentication methods:
1. Go to Authentication → Sign-in method
2. Enable Email/Password
3. Configure email templates:
   - Password reset
   - Email verification
   - Email address change
4. Add authorized domains:
   - podsafe.app (your production domain)
   - localhost (for local testing)
```

### 3.2 Firestore Database

```bash
# Create production database:
1. Go to Firestore Database
2. Click "Create database"
3. Select location: closest to users (e.g., europe-west1)
4. Start in production mode (rules already defined)
5. Deploy security rules (see below)
```

**Deploy Firestore Rules:**

```bash
# From project root:
firebase deploy --only firestore:rules --project podsafe-prod
```

**Create Indexes:**

```bash
# Deploy indexes:
firebase deploy --only firestore:indexes --project podsafe-prod
```

### 3.3 Cloud Storage

```bash
# Configure storage:
1. Go to Storage
2. Click "Get started"
3. Select location (same as Firestore)
4. Deploy security rules:

firebase deploy --only storage --project podsafe-prod
```

### 3.4 Cloud Functions (if needed)

```bash
# Set up functions:
cd functions
npm install
firebase deploy --only functions --project podsafe-prod
```

### 3.5 Crashlytics

```bash
# Enable Crashlytics:
1. Go to Crashlytics in Firebase Console
2. Click "Enable Crashlytics"
3. Follow platform-specific setup
4. Already configured in lib/main.dart
```

### 3.6 Analytics

```bash
# Configure Analytics:
1. Already enabled during project creation
2. Go to Analytics → Events
3. Review default events
4. Configure custom events if needed
```

### 3.7 Cloud Messaging (FCM)

```bash
# Configure push notifications:
1. Go to Cloud Messaging
2. Generate new key pair (Web)
3. Copy VAPID key
4. Add to .env.production:
   FCM_VAPID_KEY=your_vapid_key_here
```

## Step 4: Environment Configuration

### 4.1 Create Environment Files

Create three environment files in project root:

**`.env.development`** (current/staging):
```bash
FIREBASE_PROJECT_ID=podsafe-staging
ENVIRONMENT=development
API_URL=https://staging-api.podsafe.app
ENABLE_DEBUG_LOGGING=true
SENTRY_DSN=your_sentry_dsn_dev
```

**`.env.production`**:
```bash
FIREBASE_PROJECT_ID=podsafe-prod
ENVIRONMENT=production
API_URL=https://api.podsafe.app
ENABLE_DEBUG_LOGGING=false
SENTRY_DSN=your_sentry_dsn_prod
FCM_VAPID_KEY=your_production_vapid_key
```

**`.env.local`** (for local development):
```bash
FIREBASE_PROJECT_ID=podsafe-dev
ENVIRONMENT=local
API_URL=http://localhost:5001
ENABLE_DEBUG_LOGGING=true
USE_EMULATORS=true
```

### 4.2 Update .gitignore

Ensure environment files are protected:

```bash
# Add to .gitignore if not already present:
.env
.env.*
!.env.example
google-services.json
GoogleService-Info.plist
firebase-debug.log
```

### 4.3 Generate Firebase Options

```bash
# Install FlutterFire CLI:
dart pub global activate flutterfire_cli

# Configure for development:
flutterfire configure --project=podsafe-staging --out=lib/firebase_options_dev.dart

# Configure for production:
flutterfire configure --project=podsafe-prod --out=lib/firebase_options_prod.dart
```

### 4.4 Update Main.dart

Update `lib/main.dart` to use environment-specific configuration:

```dart
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment
  const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  
  // Select Firebase options based on environment
  final firebaseOptions = environment == 'production' 
      ? prod.DefaultFirebaseOptions.currentPlatform
      : dev.DefaultFirebaseOptions.currentPlatform;
  
  await Firebase.initializeApp(
    options: firebaseOptions,
  );
  
  // ... rest of initialization
}
```

## Step 5: Build and Deploy

### 5.1 Build for Production

**Android:**
```bash
# Build release APK:
flutter build apk --release --dart-define=ENVIRONMENT=production

# Build app bundle (for Play Store):
flutter build appbundle --release --dart-define=ENVIRONMENT=production
```

**iOS:**
```bash
# Build iOS release:
flutter build ios --release --dart-define=ENVIRONMENT=production

# Archive in Xcode:
# Open ios/Runner.xcworkspace in Xcode
# Product → Archive → Distribute App
```

**Web:**
```bash
# Build web release:
flutter build web --release --dart-define=ENVIRONMENT=production

# Deploy to Firebase Hosting:
firebase deploy --only hosting --project podsafe-prod
```

### 5.2 Deploy Backend Services

```bash
# Deploy Firestore rules:
firebase deploy --only firestore:rules --project podsafe-prod

# Deploy storage rules:
firebase deploy --only storage --project podsafe-prod

# Deploy indexes:
firebase deploy --only firestore:indexes --project podsafe-prod

# Deploy Cloud Functions (if any):
firebase deploy --only functions --project podsafe-prod

# Deploy everything:
firebase deploy --project podsafe-prod
```

### 5.3 Verify Deployment

```bash
# Check deployment status:
firebase projects:list
firebase hosting:sites:list --project podsafe-prod

# Test production URL:
# https://podsafe-prod.web.app
# or your custom domain
```

## Step 6: Configure Custom Domain (Optional)

### 6.1 Add Custom Domain to Firebase Hosting

```bash
# In Firebase Console:
1. Go to Hosting
2. Click "Add custom domain"
3. Enter domain: podsafe.app
4. Follow DNS verification steps
5. Wait for SSL certificate provisioning (can take 24 hours)
```

### 6.2 Configure DNS

Add these DNS records at your domain registrar:

```
Type: A
Name: @
Value: 151.101.1.195 (Firebase IP)

Type: A  
Name: @
Value: 151.101.65.195 (Firebase IP)

Type: TXT
Name: @
Value: [verification code from Firebase]
```

## Step 7: Database Migration

### 7.1 Export Data from Development

```bash
# Export Firestore data:
gcloud firestore export gs://podsafe-staging-backup --project=podsafe-staging

# Download locally:
gsutil -m cp -r gs://podsafe-staging-backup .
```

### 7.2 Import to Production

```bash
# Upload to production bucket:
gsutil -m cp -r ./backup gs://podsafe-prod-backup

# Import to production:
gcloud firestore import gs://podsafe-prod-backup --project=podsafe-prod
```

### 7.3 Verify Data

```bash
# Use Firebase Console to verify:
1. Check user counts
2. Verify delivery records
3. Check claim records
4. Verify customer data
5. Test authentication
```

## Step 8: Security Checklist

### 8.1 Firestore Security Rules

- [ ] Rules deployed and tested
- [ ] Multi-tenant isolation working
- [ ] Role-based access control verified
- [ ] No read/write allowed without authentication

### 8.2 Storage Security Rules

- [ ] File type validation working
- [ ] File size limits enforced
- [ ] User can only access their company files
- [ ] POD signatures protected

### 8.3 Authentication

- [ ] Email verification enabled
- [ ] Password reset working
- [ ] Account approval workflow tested
- [ ] Session timeout configured

### 8.4 API Security

- [ ] API keys restricted (HTTP referrers, iOS bundle ID, Android package)
- [ ] CORS configured correctly
- [ ] Rate limiting enabled (if using Cloud Functions)

## Step 9: Monitoring and Alerts

### 9.1 Set Up Crashlytics Alerts

```bash
# In Firebase Console:
1. Go to Crashlytics
2. Configure email alerts for:
   - New issues
   - Regressed issues
   - High velocity crashes
```

### 9.2 Set Up Performance Monitoring

```bash
# Already integrated in code
# Monitor in Firebase Console:
1. Go to Performance
2. Review app start time
3. Monitor network requests
4. Check screen rendering
```

### 9.3 Set Up Analytics Alerts

```bash
# Configure custom alerts:
1. Go to Analytics
2. Set up alerts for:
   - Daily active users drop
   - Error rate increase
   - Conversion funnel drop-off
```

## Step 10: Backup and Disaster Recovery

### 10.1 Automated Backups

```bash
# Set up scheduled Firestore exports:
1. Go to Google Cloud Console
2. Cloud Scheduler → Create Job
3. Name: daily-firestore-backup
4. Schedule: 0 2 * * * (2 AM daily)
5. Target: gcloud firestore export gs://podsafe-prod-backup/$(date +%Y%m%d)
```

### 10.2 Backup Strategy

- **Daily:** Automated Firestore export
- **Weekly:** Full database export with verification
- **Monthly:** Archive to cold storage
- **Retention:** 30 days rolling, 12 monthly archives

### 10.3 Recovery Procedures

**Emergency Recovery:**
```bash
# Restore from latest backup:
gsutil ls gs://podsafe-prod-backup/  # List backups
gcloud firestore import gs://podsafe-prod-backup/20251019 --project=podsafe-prod
```

## Deployment Commands Cheat Sheet

```bash
# Switch to production:
firebase use podsafe-prod

# Deploy everything:
firebase deploy --project podsafe-prod

# Deploy specific services:
firebase deploy --only firestore:rules --project podsafe-prod
firebase deploy --only storage --project podsafe-prod
firebase deploy --only hosting --project podsafe-prod
firebase deploy --only functions --project podsafe-prod

# Build production apps:
flutter build web --release --dart-define=ENVIRONMENT=production
flutter build apk --release --dart-define=ENVIRONMENT=production
flutter build appbundle --release --dart-define=ENVIRONMENT=production
flutter build ios --release --dart-define=ENVIRONMENT=production

# Check deployment status:
firebase projects:list
firebase hosting:channel:list --project podsafe-prod
```

## Rollback Procedures

If production deployment fails:

```bash
# Rollback Firestore rules:
firebase deploy --only firestore:rules --project podsafe-prod [previous-version]

# Rollback hosting:
firebase hosting:channel:rollback --project podsafe-prod

# Restore database from backup:
gcloud firestore import gs://podsafe-prod-backup/[backup-date] --project=podsafe-prod
```

## Support and Maintenance

### Regular Maintenance Tasks

**Daily:**
- Monitor Crashlytics for new issues
- Check error rates in Analytics
- Review Cloud Function logs

**Weekly:**
- Review performance metrics
- Check storage usage
- Verify backup completion

**Monthly:**
- Review and update security rules
- Audit user access and permissions
- Update dependencies and Flutter SDK
- Review and optimize Firestore indexes

### Getting Help

- Firebase Support: https://firebase.google.com/support
- Firebase Community: https://firebase.google.com/community
- Stack Overflow: Tag `firebase` + `flutter`

---

**Last Updated:** October 19, 2025
**Environment:** Production Setup Guide v1.0
**Contact:** admin@podsafe.app
