const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onCall, HttpsError} = require('firebase-functions/v2/https');

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function: Send FCM push notification when notification document is created
 * 
 * Trigger: Firestore onCreate - notifications/{notificationId}
 * 
 * Flow:
 * 1. New notification document created in Firestore
 * 2. Function triggers automatically
 * 3. Fetches user's FCM device tokens
 * 4. Sends push notification via Firebase Cloud Messaging
 * 5. Updates notification status (sent/failed)
 */
exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationId = context.params.notificationId;
    const notification = snap.data();
    
    console.log('📬 New notification created:', notificationId);
    console.log('User ID:', notification.userId);
    console.log('Title:', notification.title);
    console.log('Body:', notification.body);
    
    try {
      // Step 1: Get user's FCM device tokens from Firestore
      const devicesSnapshot = await admin.firestore()
        .collection('users')
        .doc(notification.userId)
        .collection('devices')
        .get();
      
      // Check if user has any registered devices
      if (devicesSnapshot.empty) {
        console.warn('⚠️ No devices found for user:', notification.userId);
        
        // Mark notification as failed (no devices)
        await snap.ref.update({ 
          status: 'failed',
          error: 'No devices registered for user',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        return null;
      }
      
      // Step 2: Extract FCM tokens from device documents
      const tokens = devicesSnapshot.docs.map(doc => doc.data().token);
      console.log(`📱 Found ${tokens.length} device(s) for user`);
      
      // Step 3: Build FCM message payload
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {}, // Custom data payload
        tokens: tokens, // Send to all user's devices
        android: {
          priority: 'high', // High priority for Android
          notification: {
            sound: 'default',
            channelId: 'delivery_notifications',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
      
      // Step 4: Send multicast message (to multiple devices)
      console.log('🚀 Sending notification to', tokens.length, 'device(s)...');
      const response = await admin.messaging().sendMulticast(message);
      
      console.log('✅ Successfully sent:', response.successCount);
      console.log('❌ Failed:', response.failureCount);
      
      // Log individual failures for debugging
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${idx}:`, resp.error);
            
            // If token is invalid, delete it from Firestore
            if (resp.error.code === 'messaging/invalid-registration-token' ||
                resp.error.code === 'messaging/registration-token-not-registered') {
              console.log('🗑️ Deleting invalid token:', tokens[idx]);
              admin.firestore()
                .collection('users')
                .doc(notification.userId)
                .collection('devices')
                .doc(tokens[idx])
                .delete()
                .catch(err => console.error('Error deleting token:', err));
            }
          }
        });
      }
      
      // Step 5: Update notification status in Firestore
      await snap.ref.update({ 
        status: response.successCount > 0 ? 'sent' : 'failed',
        successCount: response.successCount,
        failureCount: response.failureCount,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log('✅ Notification processing complete');
      return null;
      
    } catch (error) {
      console.error('❌ Error sending notification:', error);
      
      // Mark notification as failed with error details
      await snap.ref.update({ 
        status: 'failed',
        error: error.message,
        errorCode: error.code || 'unknown',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Re-throw error so Firebase logs it
      throw error;
    }
  });

/**
 * Cloud Function: Clean up old notification documents
 * 
 * Schedule: Runs daily at midnight (EST)
 * Purpose: Delete notifications older than 30 days to save storage
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('0 0 * * *') // Cron: Every day at midnight
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('🗑️ Starting notification cleanup...');
    
    // Calculate date 30 days ago
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    // Query old notifications
    const oldNotificationsSnapshot = await admin.firestore()
      .collection('notifications')
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .limit(500) // Process in batches
      .get();
    
    console.log(`Found ${oldNotificationsSnapshot.size} old notifications to delete`);
    
    if (oldNotificationsSnapshot.empty) {
      console.log('✅ No old notifications to clean up');
      return null;
    }
    
    // Delete in batch (max 500 per batch)
    const batch = admin.firestore().batch();
    oldNotificationsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`✅ Deleted ${oldNotificationsSnapshot.size} old notifications`);
    
    return null;
  });

/**
 * Cloud Function: Handle delivery status changes
 * 
 * Trigger: Firestore onUpdate - deliveries/{deliveryId}
 * Purpose: Alternative to client-side notification triggering
 * 
 * NOTE: Currently disabled - notifications are triggered from Flutter app.
 * Uncomment if you want server-side status change notifications.
 */
/*
exports.onDeliveryStatusChange = functions.firestore
  .document('deliveries/{deliveryId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Only trigger if status actually changed
    if (before.status === after.status) {
      return null;
    }
    
    console.log(`📦 Delivery ${context.params.deliveryId} status changed: ${before.status} → ${after.status}`);
    
    // Skip notifications for pending status
    if (after.status === 'pending') {
      return null;
    }
    
    // Determine notification details
    let emoji = '📦';
    let title = 'Delivery Update';
    let priority = 'normal';
    
    switch (after.status) {
      case 'inTransit':
        emoji = '🚚';
        title = 'Delivery In Transit';
        break;
      case 'delivered':
        emoji = '✅';
        title = 'Delivery Completed';
        priority = 'high';
        break;
      case 'failed':
        emoji = '❌';
        title = 'Delivery Failed';
        priority = 'urgent';
        break;
    }
    
    // Get all admins for this company
    const adminsSnapshot = await admin.firestore()
      .collection('users')
      .where('companyId', '==', after.companyId)
      .where('role', '==', 'admin')
      .get();
    
    // Create notification for each admin
    const batch = admin.firestore().batch();
    adminsSnapshot.docs.forEach(adminDoc => {
      const notificationRef = admin.firestore().collection('notifications').doc();
      batch.set(notificationRef, {
        userId: adminDoc.id,
        title: `${emoji} ${title}`,
        body: `${after.customerName} - ${after.customerAddress}`,
        data: {
          type: 'delivery_status_change',
          deliveryId: context.params.deliveryId,
          customerId: after.customerId || '',
          customerName: after.customerName,
          newStatus: after.status,
          priority: priority,
        },
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    
    await batch.commit();
    console.log(`✅ Created ${adminsSnapshot.size} notifications for admins`);
    
    return null;
  });
*/

/**
 * Cloud Function: Create a new user with email/password (Admin only)
 * 
 * Callable Function: Can be invoked from Flutter app
 * Security: Only allows admins to create users in their own company
 * 
 * Request Parameters:
 * - email: User's email address
 * - password: User's password (min 6 characters)
 * - name: User's full name
 * - role: User role (admin, manager, driver)
 * - isActive: Whether user is active (optional, defaults to true)
 * 
 * Returns:
 * - uid: The created user's unique ID
 * - email: The created user's email
 */
exports.createUser = onCall({cors: true}, async (request) => {
  // Verify user is authenticated
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to create users');
  }

  const callerId = request.auth.uid;
  console.log('👤 CreateUser called by:', callerId);

  try {
    // Get caller's user document to verify they're an admin
    const callerDoc = await admin.firestore()
      .collection('users')
      .doc(callerId)
      .get();

    if (!callerDoc.exists) {
      throw new HttpsError('not-found', 'Caller user document not found');
    }

    const callerData = callerDoc.data();
    
    // Verify caller is an admin
    if (callerData.role !== 'admin') {
      console.warn('⚠️ Non-admin user attempted to create user:', callerId);
      throw new HttpsError('permission-denied', 'Only admins can create users');
    }

    const callerCompanyId = callerData.companyId;
    console.log('✅ Caller is admin for company:', callerCompanyId);

    // Extract and validate parameters
    const {email, password, name, role, isActive} = request.data;

    // Validate required fields
    if (!email || !password || !name || !role) {
      throw new HttpsError('invalid-argument', 'Missing required fields: email, password, name, role');
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new HttpsError('invalid-argument', 'Invalid email format');
    }

    // Validate password length
    if (password.length < 6) {
      throw new HttpsError('invalid-argument', 'Password must be at least 6 characters');
    }

    // Validate role
    const validRoles = ['admin', 'manager', 'driver'];
    if (!validRoles.includes(role)) {
      throw new HttpsError('invalid-argument', `Invalid role. Must be one of: ${validRoles.join(', ')}`);
    }

    console.log(`📝 Creating user: ${email} with role: ${role}`);

    // Step 1: Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
      emailVerified: false,
    });

    console.log('✅ Firebase Auth user created:', userRecord.uid);

    // Step 2: Create Firestore user document
    const userDocData = {
      email: email,
      name: name,
      role: role,
      companyId: callerCompanyId, // Assign to caller's company
      isActive: isActive !== undefined ? isActive : true,
      approvalStatus: role === 'driver' ? 'pending' : 'approved', // Drivers require approval
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerId, // Track who created this user
    };

    await admin.firestore()
      .collection('users')
      .doc(userRecord.uid)
      .set(userDocData);

    console.log('✅ Firestore user document created');

    // Return success response
    return {
      success: true,
      uid: userRecord.uid,
      email: userRecord.email,
      message: `User ${email} created successfully`,
    };

  } catch (error) {
    console.error('❌ Error creating user:', error);

    // If it's already an HttpsError, re-throw it
    if (error instanceof HttpsError) {
      throw error;
    }

    // Handle specific Firebase Auth errors
    if (error.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'A user with this email already exists');
    }
    if (error.code === 'auth/invalid-email') {
      throw new HttpsError('invalid-argument', 'Invalid email address');
    }
    if (error.code === 'auth/weak-password') {
      throw new HttpsError('invalid-argument', 'Password is too weak');
    }

    // Generic error
    throw new HttpsError('internal', `Failed to create user: ${error.message}`);
  }
});

// ==================== BUSINESS CENTRAL INTEGRATION ====================

const axios = require('axios');

/**
 * Authenticate with Business Central (server-side to avoid CORS)
 */
exports.bcAuthenticate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { companyId, clientSecret } = data;

  if (!companyId || !clientSecret) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    // Get BC configuration from Firestore
    const configDoc = await admin.firestore()
      .collection('companies')
      .doc(companyId)
      .collection('integrations')
      .doc('businessCentral')
      .get();

    if (!configDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'BC configuration not found');
    }

    const config = configDoc.data();

    if (!config.tenantId || !config.clientId || !config.bcApiUrl) {
      throw new functions.https.HttpsError('failed-precondition', 'BC configuration incomplete');
    }

    // Request token from Microsoft
    const tokenUrl = `https://login.microsoftonline.com/${config.tenantId}/oauth2/v2.0/token`;

    // For Business Central, always use the base API scope regardless of whether
    // it's production or trial/sandbox. The tenant/environment in the API URL
    // is used for API calls, not OAuth scope.
    const bcScope = 'https://api.businesscentral.dynamics.com/.default';

    console.log('BC OAuth - Tenant:', config.tenantId);
    console.log('BC OAuth - API URL:', config.bcApiUrl);
    console.log('BC OAuth - Scope:', bcScope);

    const response = await axios.post(
      tokenUrl,
      new URLSearchParams({
        client_id: config.clientId,
        client_secret: clientSecret,
        scope: bcScope,
        grant_type: 'client_credentials',
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    // Store token info (not the token itself for security)
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + (response.data.expires_in * 1000)
    );

    await admin.firestore()
      .collection('companies')
      .doc(companyId)
      .collection('integrations')
      .doc('businessCentral')
      .update({
        lastAuthenticatedAt: admin.firestore.FieldValue.serverTimestamp(),
        tokenExpiresAt: expiresAt,
      });

    return {
      accessToken: response.data.access_token,
      expiresIn: response.data.expires_in,
      expiresAt: expiresAt.toMillis(),
    };
  } catch (error) {
    console.error('BC Authentication Error:', error.response?.data || error.message);
    
    if (error.response) {
      throw new functions.https.HttpsError(
        'internal',
        `Auth failed: ${error.response.data?.error_description || error.response.statusText}`
      );
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Make authenticated API call to Business Central
 */
exports.bcApiCall = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { companyId, endpoint, method = 'GET', body, accessToken } = data;

  if (!companyId || !endpoint || !accessToken) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    // Get BC configuration
    const configDoc = await admin.firestore()
      .collection('companies')
      .doc(companyId)
      .collection('integrations')
      .doc('businessCentral')
      .get();

    if (!configDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'BC configuration not found');
    }

    const config = configDoc.data();

    // Build full URL
    const baseUrl = config.bcApiUrl.endsWith('/') ? config.bcApiUrl : `${config.bcApiUrl}/`;
    const cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    const url = `${baseUrl}${cleanEndpoint}`;

    // Make API call
    const response = await axios({
      method: method.toUpperCase(),
      url: url,
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      data: body,
    });

    return {
      success: true,
      data: response.data,
    };
  } catch (error) {
    console.error('BC API Call Error:', error.response?.data || error.message);
    
    if (error.response) {
      throw new functions.https.HttpsError(
        'internal',
        `API call failed: ${error.response.status}`
      );
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Test BC connection
 */
exports.bcTestConnection = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { companyId, clientSecret } = data;

  console.log('BC Test Connection - companyId:', companyId);

  if (!companyId || !clientSecret) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing companyId or clientSecret');
  }

  try {
    console.log('Step 1: Authenticating...');
    // Authenticate - call the function directly (not as HTTP callable)
    const authData = { companyId, clientSecret };
    const authResult = await exports.bcAuthenticate.run(authData, context);
    
    console.log('Step 2: Authentication successful, testing API access...');
    // Test API access
    const apiData = { 
      companyId, 
      endpoint: 'companies', 
      accessToken: authResult.accessToken 
    };
    const testResult = await exports.bcApiCall.run(apiData, context);

    const companies = testResult.data.value || [];
    console.log('Step 3: API call successful, found', companies.length, 'companies');

    return {
      success: true,
      message: `Connection successful! Found ${companies.length} companies.`,
      companiesCount: companies.length,
    };
  } catch (error) {
    console.error('Connection Test Error:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      details: error.details,
      response: error.response?.data,
    });
    
    // Return detailed error for debugging
    return {
      success: false,
      message: `Connection failed: ${error.message}`,
      companiesCount: 0,
      error: {
        code: error.code,
        message: error.message,
        details: error.details || error.response?.data,
      },
    };
  }
});

// ==================== NEW MULTI-TENANT BC INTEGRATION ====================
// Export TypeScript-based BC integration functions from compiled lib/index.js
// These functions provide production-ready OAuth and data sync
// Run 'npm run build' to compile TypeScript before deploying

try {
  const bcIntegration = require('./lib/index');
  
  // OAuth endpoints
  exports.bcOAuthRedirect = bcIntegration.bcOAuthRedirect;
  exports.bcOAuthCallback = bcIntegration.bcOAuthCallback;
  
  // Data sync endpoints
  exports.bcPullShipments = bcIntegration.bcPullShipments;
  exports.bcPushPod = bcIntegration.bcPushPod;
  
  // Scheduled functions
  exports.bcScheduledPull = bcIntegration.bcScheduledPull;
  
  // Firestore triggers
  exports.bcAutoPushPod = bcIntegration.bcAutoPushPod;
  
  // Health check
  exports.bcHealth = bcIntegration.bcHealth;
  
  console.log('✅ Multi-tenant BC integration loaded successfully');
} catch (error) {
  console.warn('⚠️ BC integration not compiled yet. Run: npm run build');
  console.warn('Error:', error.message);
}

// ============================================================================
// USER MANAGEMENT FUNCTIONS (Invite-Only System)
// ============================================================================

/**
 * Invite a new user to the platform
 * Only admins can invite users to their company
 */
exports.inviteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to invite users.');
  }

  const adminUid = context.auth.uid;

  try {
    const adminDoc = await admin.firestore().collection('users').doc(adminUid).get();
    
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Admin user document not found.');
    }

    const adminData = adminDoc.data();

    if (adminData.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can invite users.');
    }

    if (!adminData.isActive) {
      throw new functions.https.HttpsError('permission-denied', 'Admin account is not active.');
    }

    const { email, fullName, role, phoneNumber } = data;

    if (!email || !fullName || !role) {
      throw new functions.https.HttpsError('invalid-argument', 'Email, fullName, and role are required.');
    }

    if (!['admin', 'driver'].includes(role)) {
      throw new functions.https.HttpsError('invalid-argument', 'Role must be either "admin" or "driver".');
    }

    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    if (!emailRegex.test(email)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid email format.');
    }

    let existingUser;
    try {
      existingUser = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    if (existingUser) {
      throw new functions.https.HttpsError('already-exists', 'A user with this email already exists.');
    }

    const tempPassword = generateSecurePassword();

    const userRecord = await admin.auth().createUser({
      email: email,
      password: tempPassword,
      displayName: fullName,
      emailVerified: false,
    });

    const userData = {
      email: email,
      fullName: fullName,
      role: role,
      companyId: adminData.companyId,
      phoneNumber: phoneNumber || '',
      isActive: true,
      emailVerified: false,
      invitedBy: adminUid,
      invitedByName: adminData.fullName,
      invitedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await admin.firestore().collection('users').doc(userRecord.uid).set(userData);

    const resetLink = await admin.auth().generatePasswordResetLink(email);

    console.log(`User invited: ${email} (${role})`);

    return {
      success: true,
      userId: userRecord.uid,
      message: `Successfully invited ${fullName} as ${role}.`,
      resetLink: resetLink,
    };

  } catch (error) {
    console.error('Error inviting user:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to invite user: ${error.message}`);
  }
});

/**
 * Create a new company (Super Admin only)
 */
exports.createCompany = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create companies.');
  }

  const { name, email, phone, address, adminEmail, adminName } = data;

  if (!name || !email || !adminEmail || !adminName) {
    throw new functions.https.HttpsError('invalid-argument', 'Company name, email, admin email, and admin name are required.');
  }

  try {
    const companyRef = admin.firestore().collection('companies').doc();
    const companyId = companyRef.id;

    const companyData = {
      companyId: companyId,
      name: name,
      email: email,
      phoneNumber: phone || '',
      address: address || '',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
    };

    await companyRef.set(companyData);

    const tempPassword = generateSecurePassword();

    const adminUserRecord = await admin.auth().createUser({
      email: adminEmail,
      password: tempPassword,
      displayName: adminName,
      emailVerified: false,
    });

    const adminUserData = {
      email: adminEmail,
      fullName: adminName,
      role: 'admin',
      companyId: companyId,
      phoneNumber: '',
      isActive: true,
      emailVerified: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await admin.firestore().collection('users').doc(adminUserRecord.uid).set(adminUserData);

    const resetLink = await admin.auth().generatePasswordResetLink(adminEmail);

    console.log(`Company created: ${name} (${companyId})`);
    console.log(`Admin user created: ${adminEmail}`);

    return {
      success: true,
      companyId: companyId,
      companyName: name,
      adminUserId: adminUserRecord.uid,
      adminEmail: adminEmail,
      resetLink: resetLink,
      message: `Successfully created company "${name}" with admin user "${adminName}".`,
    };

  } catch (error) {
    console.error('Error creating company:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to create company: ${error.message}`);
  }
});

/**
 * Deactivate a user (soft delete)
 */
exports.deactivateUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const adminUid = context.auth.uid;
  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required.');
  }

  try {
    const adminDoc = await admin.firestore().collection('users').doc(adminUid).get();
    const adminData = adminDoc.data();

    if (adminData.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can deactivate users.');
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found.');
    }

    const userData = userDoc.data();

    if (userData.companyId !== adminData.companyId) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot deactivate users from other companies.');
    }

    await admin.firestore().collection('users').doc(userId).update({
      isActive: false,
      deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deactivatedBy: adminUid,
    });

    await admin.auth().updateUser(userId, { disabled: true });

    console.log(`User deactivated: ${userId} by ${adminUid}`);

    return {
      success: true,
      message: `User ${userData.fullName} has been deactivated.`,
    };

  } catch (error) {
    console.error('Error deactivating user:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to deactivate user: ${error.message}`);
  }
});

/**
 * Reactivate a user
 */
exports.reactivateUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const adminUid = context.auth.uid;
  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required.');
  }

  try {
    const adminDoc = await admin.firestore().collection('users').doc(adminUid).get();
    const adminData = adminDoc.data();

    if (adminData.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can reactivate users.');
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData.companyId !== adminData.companyId) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot reactivate users from other companies.');
    }

    await admin.firestore().collection('users').doc(userId).update({
      isActive: true,
      reactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      reactivatedBy: adminUid,
    });

    await admin.auth().updateUser(userId, { disabled: false });

    console.log(`User reactivated: ${userId} by ${adminUid}`);

    return {
      success: true,
      message: `User ${userData.fullName} has been reactivated.`,
    };

  } catch (error) {
    console.error('Error reactivating user:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to reactivate user: ${error.message}`);
  }
});

// Helper function to generate secure password
function generateSecurePassword() {
  const length = 16;
  const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
  let password = '';
  const crypto = require('crypto');
  const randomBytes = crypto.randomBytes(length);
  
  for (let i = 0; i < length; i++) {
    password += charset[randomBytes[i] % charset.length];
  }
  
  return password;
}

console.log('✅ User management functions loaded');
