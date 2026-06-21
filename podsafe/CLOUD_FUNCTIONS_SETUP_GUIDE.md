# ⚡ Firebase Cloud Functions - Quick Setup Guide

## What Are Cloud Functions?

Cloud Functions are **server-side code** that runs in response to Firebase events (like Firestore document creation). For notifications, we need them to:
1. Listen for new documents in `notifications` collection
2. Fetch the user's FCM tokens from Firestore
3. Send the actual push notification via Firebase Cloud Messaging
4. Update the notification status to "sent" or "failed"

---

## 🚀 Setup Steps

### Step 1: Initialize Firebase Functions

Open a terminal in your project root and run:

```powershell
firebase init functions
```

**Configuration prompts**:
- "What language would you like to use?" → **JavaScript** (easier) or TypeScript
- "Do you want to use ESLint?" → **Yes** (recommended)
- "Do you want to install dependencies now?" → **Yes**

**What this creates**:
```
podsafe/
  ├── functions/
  │   ├── index.js          ← Your Cloud Functions code
  │   ├── package.json      ← Node.js dependencies
  │   └── .eslintrc.js      ← Linting config
  ├── firebase.json         ← Updated with functions config
  └── .firebaserc           ← Project aliases
```

---

### Step 2: Install Firebase Admin SDK

Navigate to functions folder:
```powershell
cd functions
npm install firebase-admin
```

---

### Step 3: Write the Cloud Function

Open `functions/index.js` and add this code:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Cloud Function: Send FCM notification when notification doc is created
 * Triggered by: onCreate in notifications/{notificationId}
 */
exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationId = context.params.notificationId;
    const notification = snap.data();
    
    console.log('📬 New notification:', notificationId);
    console.log('User ID:', notification.userId);
    console.log('Title:', notification.title);
    
    try {
      // Get user's FCM tokens from Firestore
      const devicesSnapshot = await admin.firestore()
        .collection('users')
        .doc(notification.userId)
        .collection('devices')
        .get();
      
      if (devicesSnapshot.empty) {
        console.warn('⚠️ No devices found for user:', notification.userId);
        
        // Mark as failed (no devices)
        await snap.ref.update({ 
          status: 'failed',
          error: 'No devices registered',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        return null;
      }
      
      // Extract FCM tokens from device documents
      const tokens = devicesSnapshot.docs.map(doc => doc.data().token);
      console.log(`📱 Found ${tokens.length} device(s) for user`);
      
      // Build FCM message payload
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        tokens: tokens, // Send to all user's devices
      };
      
      // Send multicast message (to multiple devices)
      const response = await admin.messaging().sendMulticast(message);
      
      console.log('✅ Successfully sent:', response.successCount);
      console.log('❌ Failed:', response.failureCount);
      
      // Log any failures
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to ${tokens[idx]}:`, resp.error);
          }
        });
      }
      
      // Update notification status
      await snap.ref.update({ 
        status: response.successCount > 0 ? 'sent' : 'failed',
        successCount: response.successCount,
        failureCount: response.failureCount,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return null;
      
    } catch (error) {
      console.error('❌ Error sending notification:', error);
      
      // Mark as failed with error message
      await snap.ref.update({ 
        status: 'failed',
        error: error.message,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw error; // Re-throw for Firebase to log
    }
  });

/**
 * OPTIONAL: Clean up old notification documents (older than 30 days)
 * Scheduled to run daily at midnight
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('0 0 * * *') // Cron: Every day at midnight
  .timeZone('America/New_York') // Adjust to your timezone
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const oldNotificationsSnapshot = await admin.firestore()
      .collection('notifications')
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();
    
    console.log(`🗑️ Deleting ${oldNotificationsSnapshot.size} old notifications`);
    
    const batch = admin.firestore().batch();
    oldNotificationsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log('✅ Cleanup complete');
    
    return null;
  });
```

---

### Step 4: Deploy to Firebase

Go back to project root:
```powershell
cd ..
firebase deploy --only functions
```

**Expected output**:
```
✔  functions: Finished running predeploy script.
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (XX.XX KB) for uploading
✔  functions: functions folder uploaded successfully

✔  Deploy complete!

Functions:
  sendNotification(us-central1)
  cleanupOldNotifications(us-central1)
```

---

## 🧪 Testing Cloud Functions

### Test 1: Trigger Function Manually

Use Firebase Console:
1. Go to **Firestore Database**
2. Navigate to `notifications` collection
3. Click "Add Document"
4. Set document ID: `test-notification-1`
5. Add fields:
   ```
   userId: "your-driver-user-id"
   title: "Test Notification"
   body: "This is a test from Firebase Console"
   data: { type: "test" }
   status: "pending"
   createdAt: (timestamp - now)
   ```
6. Click "Save"

**Expected**:
- Function triggers automatically
- Check Firebase Functions logs (see below)
- Notification appears on driver's device

---

### Test 2: Check Function Logs

View logs in Firebase Console:
1. Go to **Functions** → **Logs**
2. Filter by function: `sendNotification`
3. Look for:
   - ✅ "New notification: test-notification-1"
   - ✅ "Found X device(s) for user"
   - ✅ "Successfully sent: 1"

OR use Firebase CLI:
```powershell
firebase functions:log --only sendNotification
```

---

### Test 3: End-to-End Flow

1. **Login as admin** (web app)
2. **Create a delivery** and assign to driver
3. **Check Firestore**: New doc in `notifications` collection
4. **Check Functions logs**: Function should trigger within 1-2 seconds
5. **Check driver's device**: Notification should appear

---

## 🔍 Debugging

### Problem: Function not triggering
**Check**:
```powershell
firebase functions:log
```
Look for errors like:
- "Function initialization failed"
- "Permission denied"

**Fix**:
```powershell
firebase deploy --only functions
```

---

### Problem: "No devices found for user"
**Check Firestore**:
1. Go to `users/{userId}/devices`
2. Verify documents exist with valid FCM tokens

**Fix**:
- User needs to login again (triggers token save)
- Check `NotificationService.initialize()` is called

---

### Problem: FCM token invalid
**Check logs for**:
```
Failed to send to <token>: messaging/invalid-registration-token
```

**Fix**:
- Delete invalid tokens from Firestore
- Token refresh should create new token on next login

---

## 💰 Cost Considerations

### Cloud Functions Pricing:
- **Free tier**: 2M invocations/month, 400K GB-seconds compute time
- **Your usage** (estimated):
  - ~100 deliveries/day = 100 notifications/day
  - ~3,000 notifications/month
  - **Well within free tier! ✅**

### Firestore Pricing:
- **Free tier**: 50K reads, 20K writes, 20K deletes per day
- **Your usage** (estimated):
  - 1 read + 1 write per notification
  - ~200 operations/day
  - **Well within free tier! ✅**

### FCM Pricing:
- **Always free!** No limits on messages ✅

**Conclusion**: You can run this for free indefinitely with current usage! 🎉

---

## 🔐 Security Rules

Your Firestore rules should restrict notification creation to authenticated users:

```javascript
// firestore.rules
match /notifications/{notificationId} {
  // Only server (Cloud Functions) can read
  allow read: if false;
  
  // Only authenticated users can create
  allow create: if request.auth != null;
  
  // No updates or deletes from clients
  allow update, delete: if false;
}
```

---

## 📊 Monitoring

### View Function Performance:
1. Firebase Console → Functions → **Dashboard**
2. Metrics shown:
   - Invocations (how many times function ran)
   - Execution time (how long it took)
   - Errors (failed executions)

### Set Up Alerts:
1. Firebase Console → Functions → **Alerts**
2. Create alert for:
   - Error rate > 5%
   - Execution time > 10 seconds

---

## 🚀 Advanced Features (Optional)

### 1. Rate Limiting
Prevent notification spam:

```javascript
// In sendNotification function, before sending:
const recentNotifs = await admin.firestore()
  .collection('notifications')
  .where('userId', '==', notification.userId)
  .where('createdAt', '>', oneMinuteAgo)
  .get();

if (recentNotifs.size > 10) {
  console.warn('⚠️ Rate limit exceeded for user');
  await snap.ref.update({ status: 'rate_limited' });
  return null;
}
```

### 2. Retry Failed Notifications
Schedule retry for failed sends:

```javascript
exports.retryFailedNotifications = functions.pubsub
  .schedule('every 10 minutes')
  .onRun(async () => {
    const failedNotifs = await admin.firestore()
      .collection('notifications')
      .where('status', '==', 'failed')
      .where('retryCount', '<', 3)
      .get();
    
    // Retry logic here...
  });
```

### 3. Analytics Tracking
Track notification engagement:

```javascript
// After successful send:
await admin.firestore()
  .collection('analytics')
  .doc('notifications')
  .collection('daily')
  .doc(todayStr)
  .set({
    sent: admin.firestore.FieldValue.increment(1),
    // ... other metrics
  }, { merge: true });
```

---

## ✅ Deployment Checklist

Before deploying to production:

- [ ] Test function locally with emulator
- [ ] Test with real FCM tokens
- [ ] Verify Firestore security rules
- [ ] Set up error monitoring/alerts
- [ ] Document function behavior for team
- [ ] Test with multiple devices (iOS + Android)
- [ ] Test edge cases (no tokens, invalid tokens)
- [ ] Add function timeout limits
- [ ] Review billing/cost projections
- [ ] Add logging for debugging

---

## 📝 Quick Command Reference

```powershell
# Initialize functions
firebase init functions

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:sendNotification

# View logs
firebase functions:log

# View logs for specific function
firebase functions:log --only sendNotification

# Delete a function
firebase functions:delete sendNotification

# Test with emulator (local)
firebase emulators:start --only functions,firestore
```

---

## 🎯 Success Criteria

After deployment, you should see:
- ✅ Function appears in Firebase Console → Functions
- ✅ Function logs show successful executions
- ✅ Notifications status changes from "pending" to "sent"
- ✅ Push notifications appear on devices
- ✅ Tapping notifications navigates to correct screen
- ✅ No errors in Firebase Functions logs

---

**Ready to deploy?** Let me know if you want help with:
- Setting up the Firebase project
- Writing the function code
- Testing and debugging
- Or anything else!

