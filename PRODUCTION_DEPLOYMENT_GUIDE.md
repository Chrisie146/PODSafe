# Production Deployment Guide - PODSafe

**Version:** 1.0  
**Last Updated:** November 6, 2025  
**Audience:** DevOps/Release Team

---

## 🚀 Quick Start

This guide walks you through deploying PODSafe to production. Before starting, ensure you've completed the **PRODUCTION_READINESS_CHECKLIST.md**.

---

## Pre-Deployment Verification

### Verify Go/No-Go Status
Before deployment, confirm:
- [ ] All code changes reviewed and approved
- [ ] All tests passing (`flutter test`)
- [ ] No compilation warnings (`flutter analyze`)
- [ ] Security review completed
- [ ] Stakeholder sign-off obtained
- [ ] Rollback plan documented
- [ ] Monitoring configured
- [ ] Team ready for on-call support (24/7 for 7 days post-launch)

---

## Phase 1: Firebase Deployment (Production Infrastructure)

### Step 1.1: Verify Production Firebase Project Exists

```bash
# List all Firebase projects
firebase projects:list
```

Expected output should show: `podsafe-production`

### Step 1.2: Switch to Production Firebase Project

```bash
# In workspace root (c:\Users\christopherm\PODSafe\podsafe)
# Update .firebaserc to use production project
firebase use podsafe-production
```

Verify: `.firebaserc` should show:
```json
{
  "projects": {
    "default": "podsafe-production"
  }
}
```

### Step 1.3: Deploy Firestore Security Rules

```bash
# Validate rules syntax
firebase firestore:rules:validate

# Deploy rules
firebase deploy --only firestore:rules
```

Expected output:
```
✔ Deployed Cloud Firestore indexes
✔ Cloud Firestore rules have been successfully deployed
```

**What was deployed:**
- `firestore.rules` - Access control for Firestore database
- Ensures users can only see their company's data
- Ensures drivers can only see their own deliveries

### Step 1.4: Deploy Cloud Storage Rules

```bash
# Deploy storage rules
firebase deploy --only storage
```

Expected output:
```
✔ Cloud Storage rules have been successfully deployed
```

**What was deployed:**
- `storage.rules` - Access control for uploaded files (POD images, signatures)
- Enforces company data isolation
- Enforces file size limits

### Step 1.5: Deploy Cloud Functions

```bash
# Deploy all functions to production
firebase deploy --only functions
```

Expected output:
```
✔ functions: Finished running predeploy script.
✔ functions[functionName1]: Successful
✔ functions[functionName2]: Successful
...
```

**What was deployed:**
- All Cloud Functions from `functions/` directory
- These handle server-side logic (e.g., PDF export, email notifications)

### Step 1.6: Verify Firebase Deployment

```bash
# Check deployed rules in Firebase Console
firebase firestore:inspect-rules

# Check deployed functions
firebase functions:list
```

---

## Phase 2: Android Deployment

### Step 2.1: Build Release APK/Bundle

```bash
# Build production Android App Bundle (preferred for Play Store)
cd c:\Users\christopherm\PODSafe\podsafe
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Step 2.2: Verify Build Artifacts

```bash
# Check file exists and size reasonable (usually 30-100 MB)
dir build/app/outputs/bundle/release/
```

### Step 2.3: Sign App Bundle

The app should already be signed if configured in `android/key.properties` and `android/app/build.gradle`. Verify by:

```bash
# Check signing configuration
type android/key.properties
```

Should show:
```
storePassword=<password>
keyPassword=<password>
keyAlias=podsafe
storeFile=key.jks
```

### Step 2.4: Upload to Google Play Store

1. Go to [Google Play Console](https://play.console.google.com/)
2. Select "PODSafe" app
3. Navigate to **Release** → **Testing** → **Internal Testing**
4. Click **Create new release**
5. Upload `build/app/outputs/bundle/release/app-release.aab`
6. Review app info, content rating, privacy policy
7. Click **Review release**
8. Click **Start rollout** → **Internal Testing** (first, before production)

### Step 2.5: Internal Testing Phase (Android)

- [ ] Send testing link to 5-10 testers
- [ ] Wait for feedback (24 hours minimum)
- [ ] Verify no critical issues reported
- [ ] Check crash reports in Firebase Crashlytics

### Step 2.6: Rollout to Production (Android)

1. In Google Play Console
2. Navigate to **Release** → **Production**
3. Click **Create new release**
4. Upload the same `app-release.aab`
5. Review all information
6. **IMPORTANT**: Start with 5% rollout:
   - Click **Create new release for 5% of users**
   - Monitor for 24 hours
7. If no issues, increase to 100%:
   - Click **Increase rollout to 100%**

---

## Phase 3: iOS Deployment

### Step 3.1: Build Release for App Store

```bash
# Build iOS release
flutter build ios --release

# This creates an archive for upload to App Store
# Follow Xcode prompts for code signing
```

### Step 3.2: Upload to App Store Connect Using Xcode

```bash
# Open Xcode project
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner project
# 2. Select Runner target
# 3. Product → Archive
# 4. Organizer window opens
# 5. Validate App
# 6. Distribute App
# 7. Select "App Store Connect" as destination
# 8. Continue through signing/provisioning prompts
# 9. Finish upload
```

Alternatively, use transporter:

```bash
# Download from App Store Connect if needed
# xcrun altool --upload-app ...
```

### Step 3.3: TestFlight Review (iOS)

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select "PODSafe" app
3. Go to **TestFlight**
4. Build should appear under "Builds"
5. Wait for Apple's automated review (~30 min - 2 hours)
6. Once approved, send to internal testers

### Step 3.4: Internal Testing Phase (iOS)

- [ ] Send TestFlight link to 5-10 testers
- [ ] Wait for feedback (24 hours minimum)
- [ ] Verify no critical issues
- [ ] Check crash reports in Firebase Crashlytics

### Step 3.5: Submit to App Store Review

1. In App Store Connect
2. Go to **App Review**
3. Review app information, screenshots, etc.
4. Click **Submit for Review**
5. Apple review takes 24-48 hours
6. Once approved, app is automatically released (or you can schedule release)

---

## Phase 4: Web Deployment

### Step 4.1: Build Web Release

```bash
flutter build web --release

# Output: build/web/
```

### Step 4.2: Deploy to Firebase Hosting

```bash
# Deploy web build
firebase deploy --only hosting
```

Expected output:
```
✔ Deploy complete!

Project Console: https://console.firebase.google.com/project/podsafe-production
Hosting URL: https://podsafe-production.web.app
```

### Step 4.3: Verify Web Deployment

Visit: `https://podsafe-production.web.app`

- [ ] App loads without errors
- [ ] Login works
- [ ] Dashboard displays
- [ ] Can view deliveries
- [ ] Can create new delivery

---

## Phase 5: Post-Deployment Verification

### Step 5.1: Verify All Platforms

**Android:**
- [ ] Install from Google Play Store (5% rollout)
- [ ] Login works
- [ ] Dashboard loads
- [ ] Can create delivery
- [ ] POD capture works
- [ ] No crashes in Firebase Crashlytics

**iOS:**
- [ ] Install from TestFlight
- [ ] Login works
- [ ] Dashboard loads
- [ ] Can create delivery
- [ ] POD capture works
- [ ] No crashes in Firebase Crashlytics

**Web:**
- [ ] Visit web app URL
- [ ] Login works
- [ ] All features accessible
- [ ] Responsive on desktop/mobile

### Step 5.2: Monitor Firebase Services

```bash
# Check Firebase project status
firebase status
```

Verify all services are operational:
- [ ] Authentication
- [ ] Firestore
- [ ] Storage
- [ ] Cloud Functions
- [ ] Analytics
- [ ] Crashlytics

### Step 5.3: Check Analytics Dashboard

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select `podsafe-production` project
3. Go to **Analytics Dashboard**
4. Should see real user sessions
5. Track key events:
   - User logins
   - Delivery creation
   - POD capture
   - Errors

### Step 5.4: Review Crashlytics

1. Go to **Crashlytics**
2. Verify NO critical crashes
3. Expected: Low crash rate (<0.1%)
4. Any crashes? Investigate immediately

---

## Phase 6: Communication & Handoff

### Notify Stakeholders

Send notification:
```
Subject: PODSafe Production Launch Complete ✅

Body:
- Android: Released to 5% of users via Google Play Store
- iOS: Available on TestFlight (internal testers)
- Web: Deployed to https://podsafe-production.web.app

Status: All services operational
Monitoring: 24/7 on-call support active for next 7 days
Next: Will increase Android rollout to 100% after 24-hour monitoring

On-Call Contact: [YOUR NAME] [PHONE] [EMAIL]
```

### Prepare Operations Team

Hand off documentation:
1. **Production Readiness Checklist** - What was verified
2. **Firestore Rules** - Access control logic
3. **Cloud Functions** - Server-side functions deployed
4. **Monitoring Dashboard** - How to monitor health
5. **Incident Response Playbook** - What to do if issues occur

---

## Phase 7: 24-Hour Monitoring (Critical)

### On-Call Duties for First 24 Hours

**Every hour:**
- [ ] Check Firebase Crashlytics for new crashes
- [ ] Check error rate in Analytics
- [ ] Verify all services responding
- [ ] Check user feedback channels

**Every 4 hours:**
- [ ] Review Firebase Function logs for errors
- [ ] Check Firestore query performance
- [ ] Verify no unusual database activity

**If critical issue found:**
1. Immediately notify team
2. Assess severity
3. If production is broken: Execute rollback (see below)
4. Otherwise: Create incident ticket and investigate

---

## Phase 8: Scale Android Rollout (After 24-Hour Monitoring)

### If No Critical Issues Found

**After 24 hours of monitoring:**

1. Go to Google Play Console
2. Navigate to **Release** → **Production**
3. Click the active release (currently at 5%)
4. Scroll to "Rollout percentage"
5. Change from 5% to 100%
6. Click **Save changes**
7. Confirm increase

Expected timeline: Reaches 100% of users within 6-24 hours

---

## Emergency: Rollback Procedures

### If Critical Issue Discovered

#### Option 1: Halt Android Rollout (5% → 0%)

```bash
# In Google Play Console:
1. Navigate to Release → Production
2. Click active release
3. Scroll to "Rollout percentage"
4. Change to 0% (HALT)
5. Click "Save changes"

# This removes app from Play Store visibility
```

#### Option 2: Deploy Hotfix for Other Platforms

```bash
# If issue is in Firebase functions or web:

# Fix the issue in code
# Then:

firebase deploy --only functions  # If Cloud Function fix
firebase deploy --only hosting     # If web fix
```

#### Option 3: Full Rollback (Last Resort)

```bash
# Redeploy previous version of Firebase rules
# Or revert web hosting to previous build
firebase deploy
```

**Alert:** Keep backup of previous good builds!

---

## Post-Launch Checklist (Week 1)

**Day 1:**
- [ ] 24-hour monitoring complete
- [ ] No critical issues
- [ ] Increase Android to 100%

**Days 2-3:**
- [ ] Monitor app usage growing as rollout completes
- [ ] Check user feedback
- [ ] Verify no new crash patterns

**Days 4-5:**
- [ ] Review first week of analytics
- [ ] Identify any UX issues from user feedback
- [ ] Plan any urgent hotfixes

**Days 6-7:**
- [ ] Production health review meeting
- [ ] Plan transition from on-call 24/7 to on-call business hours
- [ ] Document any lessons learned

---

## Ongoing Production Support

### Weekly Tasks
- [ ] Review crash reports
- [ ] Check analytics trends
- [ ] Monitor Firebase costs
- [ ] Plan any necessary updates

### Monthly Tasks
- [ ] Security audit of Firestore rules
- [ ] Performance optimization review
- [ ] Plan next feature release

### Quarterly Tasks
- [ ] Full production security audit
- [ ] Update dependencies (if security patches available)
- [ ] Disaster recovery drill

---

## Troubleshooting Deployment Issues

### Issue: Firebase Deploy Fails

```bash
# Check authentication
firebase login

# Check project selection
firebase use podsafe-production

# Try deploy again with verbose logging
firebase deploy --debug
```

### Issue: Android Build Fails

```bash
# Clean build
flutter clean
flutter pub get
flutter build appbundle --release

# If still failing, check:
# - Android SDK version in android/app/build.gradle
# - Signing certificate is valid
# - Flutter version is 3.8.1+
```

### Issue: iOS Build Fails

```bash
# Clean build
flutter clean
flutter pub get
flutter build ios --release

# If still failing, check in Xcode:
# - Provisioning profiles are valid
# - Signing certificate is valid
# - Deployment target matches Flutter requirements
```

### Issue: Web Build Doesn't Load

```bash
# Check Firebase config
cat lib/firebase_options.dart

# Verify production Firebase credentials
# Verify CORS is configured in firebase.json
firebase deploy --only hosting
```

---

## Success Criteria

✅ **Deployment is successful when:**

1. **Android**: Released on Play Store (even if only 5%)
2. **iOS**: Approved on App Store (available on TestFlight minimum)
3. **Web**: Deployed to Firebase Hosting
4. **Firebase**: All rules and functions deployed
5. **Users**: Can log in and use app on all platforms
6. **Monitoring**: Crashlytics shows <0.1% crash rate
7. **Team**: Comfortable with on-call support

---

## Support Contacts

- **Firebase Issues**: Contact Firebase Support + Project Admin
- **App Store Issues**: Contact Apple Developer Support
- **Google Play Issues**: Contact Google Play Support
- **Critical Bugs**: On-call engineer

---

**Questions? Review PRODUCTION_READINESS_CHECKLIST.md for more details.**

🎉 **Welcome to Production!**
