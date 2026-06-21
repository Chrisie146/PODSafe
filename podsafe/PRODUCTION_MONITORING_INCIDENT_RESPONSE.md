# Production Monitoring & Incident Response - PODSafe

**Version:** 1.0  
**Last Updated:** November 6, 2025  
**Audience:** DevOps/On-Call Engineers

---

## 📊 Production Monitoring Dashboard Setup

### Firebase Console Monitoring

#### 1. Set Up Real-Time Alerts

**Crashlytics Setup:**
```
1. Go to Firebase Console → podsafe-production
2. Click "Crashlytics"
3. Click "New Alert Policy"
4. Configure alerts for:
   - Crash-free users < 95%
   - New crash types
   - Fatal crashes
   - High-velocity crashes
```

**Analytics Setup:**
```
1. Go to Firebase Console → Analytics
2. Create custom dashboard with:
   - Daily active users
   - Session duration
   - Key event tracking (login, delivery created, POD captured)
   - Funnel analysis (signup → first delivery)
```

#### 2. Create Monitoring Dashboard

Use Firebase Dashboard to track:

**Key Metrics:**
```
Daily Active Users (DAU)      | Should be growing after launch
Session Length               | Target: >5 minutes
Error Rate                   | Target: <0.1%
Crash-Free Users             | Target: >99.5%
API Response Time            | Target: <2 seconds
Firestore Query Latency      | Target: <500ms
Storage Upload Success Rate  | Target: >99.5%
```

### Platform-Specific Monitoring

**Android (Google Play):**
1. Monitor Google Play Console for crash reports
2. Check ANR (Application Not Responding) rates
3. Monitor user reviews for issues
4. Set up Play Console alerts

**iOS (App Store):**
1. Monitor App Store Connect crash reports
2. Check user reviews
3. Monitor Crashes section in Xcode

**Web:**
1. Check browser console for JavaScript errors
2. Monitor network requests
3. Check local storage quota usage

---

## 🚨 Incident Response Playbook

### Severity Levels

| Severity | Description | Response Time | Communication |
|----------|-------------|----------------|-----------------|
| **P1: Critical** | App is down or completely broken | 15 minutes | Immediate |
| **P2: High** | Major feature broken, workaround exists | 30 minutes | Within 30 min |
| **P3: Medium** | Non-critical feature issue | 2 hours | Within 1 hour |
| **P4: Low** | UI glitches, minor issues | 24 hours | Next business day |

### P1: Critical Issue Response

**When:** App is down or unusable (>10% crash rate)

**Immediate Actions (0-5 minutes):**
1. [ ] Declare critical incident in Slack: `@channel CRITICAL: [Issue Description]`
2. [ ] Pull up Firebase Crashlytics - what's crashing?
3. [ ] Check Firebase status - are services down?
4. [ ] Check Analytics - how many users affected?

**Investigation (5-15 minutes):**
```bash
# SSH into server/check cloud function logs
firebase functions:log

# Check Firestore rules - did rules deploy break something?
firebase firestore:inspect-rules

# Check recent Cloud Function deployment
firebase deploy --only functions --dry-run
```

**Root Cause Analysis:**
- [ ] Check error logs in Crashlytics
- [ ] Review recent code changes
- [ ] Check if something changed in Firebase (rules, functions, etc.)
- [ ] Look for pattern: 
  - Affects all users? (Infrastructure issue)
  - Affects specific version? (Deployment issue)
  - Affects specific feature? (Feature-specific bug)

**Resolution Options:**

**Option A: Rollback (Fastest)**
```bash
# If issue is in Cloud Functions or Firestore rules:
# Get previous working version from git
git log --oneline -n 5
git show [commit-hash]:functions/index.js

# Restore previous version
git revert HEAD
firebase deploy --only functions

# Or manually restore previous rules:
git checkout [commit-hash] -- firestore.rules
firebase deploy --only firestore:rules
```

**Option B: Hotfix Deployment**
```bash
# If you can fix quickly:
# 1. Fix the issue in code
# 2. Test locally
# 3. Deploy immediately

firebase deploy --only functions  # for Cloud Functions
firebase deploy --only firestore:rules  # for Firestore
firebase deploy --only hosting  # for web
```

**Option C: Android/iOS Rollback**
```bash
# For mobile app issues, halt rollout or release hotfix
# Google Play Console: Decrease rollout to 0%
# App Store Connect: Submit new build quickly
```

**Communication (15-30 minutes):**
1. [ ] Update status in Slack: "Issue identified: [Description]"
2. [ ] Notify team: "Rolling back to previous version"
3. [ ] Once resolved: "Issue resolved, deploying fix"
4. [ ] Post-incident: "Incident resolved, post-mortem scheduled"

---

### P2: High Priority Issue Response

**When:** Major feature broken, workaround exists

**Response Time Goal:** 30 minutes

**Triage (First 5 minutes):**
1. [ ] Confirm issue - reproduce on device/web
2. [ ] Identify scope - affects all users or specific scenarios?
3. [ ] Check Firebase - any service issues?
4. [ ] Assess risk - how many users impacted?

**Investigation (5-20 minutes):**
- [ ] Review Crashlytics for related crashes
- [ ] Check recent code changes affecting feature
- [ ] Test feature in development environment
- [ ] Reproduce issue consistently

**Decision: Rollback or Hotfix?**
- Rollback if: Issue was just introduced, can't fix in <30 min
- Hotfix if: Can fix and deploy in <30 min with confidence

**Deployment & Communication:**
1. [ ] Create fix or plan rollback
2. [ ] Test fix locally (5 min)
3. [ ] Deploy to production
4. [ ] Verify fix works
5. [ ] Communicate: "Issue resolved at [time]"

---

### P3: Medium Priority Issue Response

**When:** Non-critical feature issue

**Response Time Goal:** 2 hours

**Process:**
1. [ ] Document issue in issue tracker
2. [ ] Reproduce and verify
3. [ ] Plan fix or workaround
4. [ ] Create pull request with fix
5. [ ] Schedule deployment for next release window
6. [ ] Monitor after deployment

---

### P4: Low Priority Issue Response

**When:** UI glitches, minor issues

**Response Time Goal:** 24 hours

**Process:**
1. [ ] Document in issue tracker
2. [ ] Add to next sprint
3. [ ] Fix in normal development cycle
4. [ ] Include in next scheduled release

---

## 📋 Daily On-Call Monitoring Checklist

### Every Hour (First 24 Hours After Launch)

```
⏰ [HH:MM] On-Call Check #1

□ Crashlytics - Any new crashes?
  - Check crash count trending up/down
  - Check for new error types
  - Alert threshold: >100 crashes in 1 hour

□ Error Rate - Is error rate increasing?
  - Firebase Console → Analytics
  - Look for error rate spike
  - Alert threshold: >5% error rate

□ User Sessions - Are users logging in?
  - Should see steady DAU growth
  - Alert threshold: 0 new sessions in 1 hour = investigate

□ Firestore - Database healthy?
  - No permission denied errors spiking
  - No timeouts
  - Query latency <2 seconds

□ Storage - File uploads working?
  - Check if POD images uploading
  - No 403/500 errors
  - Success rate >98%
```

### Every 4 Hours (First 48 Hours)

```
⏰ [HH:MM] 4-Hour Review

□ Crash Report Analysis
  - Download crashlog.txt from Crashlytics
  - Group by error type
  - Identify if pattern (crashes on startup, crashes on feature X, etc.)

□ User Feedback
  - Check Slack/support channel
  - Any complaints or issues reported?
  - Cross-reference with crash data

□ Performance Metrics
  - Average session length growing?
  - Average response time acceptable?
  - Any spike in error rates?

□ Firebase Functions
  - Check function execution times
  - Check error rates per function
  - Alert if function taking >5 seconds

□ Create Incident Log Entry
  - Time: [HH:MM]
  - DAU: [number]
  - Crash Rate: [%]
  - Issues: [none/list]
  - Status: ✅ All Clear / ⚠️ Issues Found
```

### Daily Review (After First Week)

```
Daily Review Checklist:

□ Overnight Issues
  - Check if any issues while team was sleeping
  - Review crash reports
  - Check error logs

□ Trend Analysis
  - Is DAU growing?
  - Is crash rate trending down?
  - Are features being used as expected?

□ Deployment Status
  - Android: What % rollout? Should increase by 20-30%/day
  - iOS: Any new builds since yesterday?
  - Web: Any changes deployed?

□ Prioritize Today's Work
  - Identify any bugs to fix today
  - Plan deployments for today
  - Schedule team meeting if issues found

□ Update Status Board
  - Production Health: 🟢 Healthy / 🟡 Issues / 🔴 Critical
  - DAU Trend: 📈 Growing
  - Issues This Period: [number]
```

---

## 🔍 Debugging Guides

### Issue: High Crash Rate

**Symptoms:**
- Crash-free users <95%
- Crashlytics dashboard showing red

**Investigation:**
```bash
# Step 1: Identify crash type
# In Crashlytics, check "Crash Type" column
# Common types:
# - NullPointerException (null value accessed)
# - OutOfMemoryError (app using too much RAM)
# - Firebase exceptions (Firestore/Storage errors)
# - Timeout exceptions (too slow responses)

# Step 2: Identify when it started
# If recent deployment, check diff:
git show HEAD:lib/screens/...dart
git diff HEAD~1 lib/screens/

# Step 3: Check if affects all users or specific subset
# In Crashlytics, check "Affected Devices"
# - All Android? → Platform-specific issue
# - Specific app version? → That build has problem
# - All devices? → Could be backend issue

# Step 4: Look at crash stack trace
# In Crashlytics, click crash type → View stack trace
# Identify the line of code causing crash
```

**Quick Fixes:**
- NullPointerException: Add null checks, use `?.` operator
- OutOfMemoryError: Reduce image sizes, clear caches
- Firebase errors: Check Firestore rules allow access
- Timeout: Optimize queries, add timeouts

### Issue: Slow App / High Latency

**Symptoms:**
- Users report app is slow
- API response time >5 seconds
- Firestore query latency >2 seconds

**Investigation:**
```bash
# Step 1: Check Firebase function logs
firebase functions:log

# Look for:
# - Functions taking >5 seconds
# - Cold starts (functions warming up)
# - Memory issues (hitting 512MB limit)

# Step 2: Check Firestore queries
# In Firebase Console → Firestore:
# Click "Usage" tab
# Look for queries that are slow or returning too much data

# Step 3: Check network on device
# Android Studio / Xcode network profiler
# Look for:
# - Large response payloads (>10MB)
# - Too many API calls
# - Retry loops
```

**Quick Fixes:**
- Add Firestore indexes for common queries
- Limit query results with `.limit(100)`
- Compress images before upload
- Implement caching in app
- Add pagination for large lists

### Issue: Data Corruption / Sync Issues

**Symptoms:**
- Users seeing wrong data
- Claim not showing in dashboard
- Delivery deleted unexpectedly

**Investigation:**
```bash
# Step 1: Check Firestore rules - did permissions change?
firebase firestore:inspect-rules

# Step 2: Look at recent code changes that touch database
git log --oneline -n 10 -- lib/services/

# Step 3: Check if issue specific to company/user
# In Firebase Console:
# Firestore → Collections → claims
# Filter by userId or companyId
# Check if data structure is correct

# Step 4: Check Cloud Function logs for write errors
firebase functions:log
# Search for "error" or specific function name
```

**Quick Fixes:**
- Fix Firestore rules if permission issues
- Fix Cloud Function logic if data manipulation issue
- Add data validation to prevent invalid writes
- Create database migration if schema changed

---

## 🛡️ Security Incident Response

### Issue: Unauthorized Data Access

**Symptoms:**
- User seeing other company's data
- User accessing admin features without permissions
- Data that should be private is visible

**Immediate Actions:**
```
🚨 SECURITY INCIDENT - STOP EVERYTHING

1. HALT deployments (do not deploy anything)
2. DISABLE public access if data leaked:
   firebase firestore:rules:deploy security-lockdown.rules
3. ASSESS damage:
   - How much data was accessible?
   - Who had access?
   - For how long?
4. NOTIFY stakeholders + legal
5. INVESTIGATE root cause
6. FIX the issue
7. VERIFY fix prevents access
8. Re-enable normal operations
9. POST-INCIDENT analysis
```

**Investigation:**
```bash
# Step 1: Check recent Firestore rules changes
git log -p --follow -- firestore.rules | head -100

# Step 2: Check if authentication working
# In Cloud Functions, check if user is authenticated
firebase functions:log | grep "auth"

# Step 3: Check if any recent code changes
git diff HEAD~5 -- lib/config/auth* lib/services/*
```

**Prevention:**
- [ ] Add data access logging to audit who accessed what
- [ ] Add tests for Firestore rules that verify access control
- [ ] Require security review before changing authentication/rules
- [ ] Implement automatic alerts for suspicious access patterns

---

## 📞 Escalation Procedures

### When to Escalate

**Escalate to On-Call Senior Engineer if:**
- P1 issue not resolved in 30 minutes
- Security incident
- Database corruption suspected
- Multiple errors of unknown origin
- Unsure how to proceed

**Escalate to Firebase Support if:**
- Firebase service is down
- Quota limits being hit
- Performance issue with Firebase infrastructure
- Billing issue

**Escalate to Platform Team if:**
- Infrastructure issue (servers, DNS)
- Deployment pipeline issue
- Certificate/SSL issues
- Domain/DNS issues

### Escalation Template

```
🔴 ESCALATION REQUIRED

Issue: [Brief description]
Severity: P[1-4]
Time Started: [Time]
Time Tried to Resolve: [Duration]
Actions Attempted: [List]
Current Status: [Description]
Suspect Root Cause: [If known]
Recommended Escalation: [Senior Engineer / Firebase Support / Platform]

Contact: [Name] [Phone] [Slack]
```

---

## 📝 Post-Incident Review Template

After any P1/P2 incident, complete this:

```markdown
# Incident Report - [Date] [Issue Name]

## Summary
[1-2 sentence summary of what happened]

## Timeline
- 14:23 - Issue first detected
- 14:28 - Incident declared as P1
- 14:35 - Root cause identified
- 14:42 - Fix deployed
- 14:47 - Issue resolved
- Duration: 24 minutes

## Impact
- Users Affected: [percentage]
- Features Down: [list]
- Revenue Lost: [estimate]
- Data Lost: [yes/no]

## Root Cause
[Detailed explanation of what caused the issue]

## Resolution
[What was done to fix]

## Preventive Actions
- [ ] Add monitoring alert for X
- [ ] Add test for Y
- [ ] Update Z documentation
- [ ] Change process to prevent recurrence

## Lessons Learned
[What did we learn, what will we do differently next time]

## Owner: [Name]
## Date Completed: [Date]
```

---

## 🎓 Quick Reference

### Important Contacts
- **On-Call Engineer:** [Name] [Phone]
- **Senior Engineer:** [Name] [Phone]
- **Firebase Support:** support@firebase.google.com
- **Slack Channel:** #podsafe-production

### Important URLs
- Firebase Console: https://console.firebase.google.com/project/podsafe-production
- Google Play Console: https://play.console.google.com
- App Store Connect: https://appstoreconnect.apple.com
- Firestore Emulator: localhost:8080

### Important Files
- Production Firestore Rules: `firestore.rules`
- Production Storage Rules: `storage.rules`
- Cloud Functions: `functions/index.js`
- Deployment Guide: `PRODUCTION_DEPLOYMENT_GUIDE.md`
- Readiness Checklist: `PRODUCTION_READINESS_CHECKLIST.md`

### Common Commands
```bash
# Check Firebase status
firebase status

# View crash logs
firebase functions:log

# Deploy everything
firebase deploy

# Deploy specific service
firebase deploy --only firestore:rules
firebase deploy --only storage
firebase deploy --only functions

# View project info
firebase projects:list
firebase use [project-name]
```

---

**Questions? Check Discord/Slack or contact senior engineer.**

🚀 **Let's keep PODSafe running smoothly in production!**
