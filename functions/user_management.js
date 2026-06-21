/**
 * PODSafe - User Invitation Cloud Functions
 * 
 * Secure user creation for invite-only system
 * Deploy these functions to enable user management
 * 
 * Deploy: cd functions && npm run deploy
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

/**
 * Invite a new user to the platform
 * Only admins can invite users to their company
 * 
 * Usage:
 * const inviteUser = httpsCallable(functions, 'inviteUser');
 * await inviteUser({
 *   email: 'driver@example.com',
 *   fullName: 'John Driver',
 *   role: 'driver',
 *   phoneNumber: '+27123456789'
 * });
 */
exports.inviteUser = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to invite users.'
    );
  }

  const adminUid = context.auth.uid;

  try {
    // Get admin user document
    const adminDoc = await db.collection('users').doc(adminUid).get();
    
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Admin user document not found.'
      );
    }

    const adminData = adminDoc.data();

    // Verify admin role
    if (adminData.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can invite users.'
      );
    }

    // Verify admin is active
    if (!adminData.isActive) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Admin account is not active.'
      );
    }

    const { email, fullName, role, phoneNumber } = data;

    // Validate required fields
    if (!email || !fullName || !role) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email, fullName, and role are required.'
      );
    }

    // Validate role
    if (!['admin', 'driver'].includes(role)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Role must be either "admin" or "driver".'
      );
    }

    // Validate email format
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    if (!emailRegex.test(email)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email format.'
      );
    }

    // Check if user already exists
    let existingUser;
    try {
      existingUser = await auth.getUserByEmail(email);
    } catch (error) {
      // User doesn't exist, which is good for new invites
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    if (existingUser) {
      throw new functions.https.HttpsError(
        'already-exists',
        'A user with this email already exists.'
      );
    }

    // Generate temporary password
    const tempPassword = generateSecurePassword();

    // Create Firebase Auth user
    const userRecord = await auth.createUser({
      email: email,
      password: tempPassword,
      displayName: fullName,
      emailVerified: false,
    });

    // Create Firestore user document
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

    await db.collection('users').doc(userRecord.uid).set(userData);

    // Send password reset email (allows user to set their own password)
    const resetLink = await auth.generatePasswordResetLink(email);

    // TODO: Send custom invitation email with resetLink
    // For now, return the link to the admin
    console.log(`User invited: ${email} (${role})`);

    return {
      success: true,
      userId: userRecord.uid,
      message: `Successfully invited ${fullName} as ${role}.`,
      resetLink: resetLink, // Send this to user via email
      tempPassword: tempPassword, // Remove in production - only for testing
    };

  } catch (error) {
    console.error('Error inviting user:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      `Failed to invite user: ${error.message}`
    );
  }
});

/**
 * Create a new company (Super Admin only)
 * This should be called rarely - only when adding new clients
 * 
 * Usage:
 * const createCompany = httpsCallable(functions, 'createCompany');
 * await createCompany({
 *   name: 'ACME Transport Ltd',
 *   email: 'admin@acme.com',
 *   phone: '+27123456789',
 *   address: '123 Main St, City',
 *   adminEmail: 'admin@acme.com',
 *   adminName: 'John Admin'
 * });
 */
exports.createCompany = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to create companies.'
    );
  }

  // TODO: Add super admin check here
  // For now, any authenticated user can create a company for testing
  // In production, check if context.auth.token.superAdmin === true

  const { name, email, phone, address, adminEmail, adminName } = data;

  // Validate required fields
  if (!name || !email || !adminEmail || !adminName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Company name, email, admin email, and admin name are required.'
    );
  }

  try {
    // Create company document
    const companyRef = db.collection('companies').doc();
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

    // Create admin user for this company
    const tempPassword = generateSecurePassword();

    const adminUserRecord = await auth.createUser({
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

    await db.collection('users').doc(adminUserRecord.uid).set(adminUserData);

    // Generate password reset link
    const resetLink = await auth.generatePasswordResetLink(adminEmail);

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
    
    throw new functions.https.HttpsError(
      'internal',
      `Failed to create company: ${error.message}`
    );
  }
});

/**
 * Deactivate a user (soft delete)
 * Only admins can deactivate users in their company
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
    // Get admin user
    const adminDoc = await db.collection('users').doc(adminUid).get();
    const adminData = adminDoc.data();

    if (adminData.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can deactivate users.');
    }

    // Get target user
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found.');
    }

    const userData = userDoc.data();

    // Verify same company
    if (userData.companyId !== adminData.companyId) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot deactivate users from other companies.');
    }

    // Deactivate in Firestore
    await db.collection('users').doc(userId).update({
      isActive: false,
      deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deactivatedBy: adminUid,
    });

    // Disable in Firebase Auth
    await auth.updateUser(userId, { disabled: true });

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
    const adminDoc = await db.collection('users').doc(adminUid).get();
    const adminData = adminDoc.data();

    if (adminData.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can reactivate users.');
    }

    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData.companyId !== adminData.companyId) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot reactivate users from other companies.');
    }

    await db.collection('users').doc(userId).update({
      isActive: true,
      reactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      reactivatedBy: adminUid,
    });

    await auth.updateUser(userId, { disabled: false });

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
