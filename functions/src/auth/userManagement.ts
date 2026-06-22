/**
 * PODSafe - User Management Cloud Functions
 * 
 * Secure user creation for invite-only system
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const auth = admin.auth();

const USER_ROLES = ['admin', 'manager', 'logistics', 'accountant', 'filing_clerk', 'driver'];

/**
 * Create a user without changing the calling administrator's Firebase session.
 * This is the callable used by the Flutter/RN admin-management screens.
 */
export const createUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create users.');
  }

  const adminDoc = await db.collection('users').doc(context.auth.uid).get();
  const adminData = adminDoc.data();
  if (!adminDoc.exists || !adminData || adminData.role !== 'admin' || adminData.isActive !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Only active administrators can create users.');
  }

  const email = typeof data?.email === 'string' ? data.email.trim().toLowerCase() : '';
  const fullName = typeof data?.fullName === 'string' ? data.fullName.trim() : typeof data?.name === 'string' ? data.name.trim() : '';
  const password = typeof data?.password === 'string' ? data.password : '';
  const role = data?.role;
  const phoneNumber = typeof data?.phoneNumber === 'string' ? data.phoneNumber.trim() : '';
  const isActive = typeof data?.isActive === 'boolean' ? data.isActive : true;

  if (!email || !fullName || !password || !role) {
    throw new functions.https.HttpsError('invalid-argument', 'Email, name, password, and role are required.');
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid email format.');
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError('invalid-argument', 'Password must be at least 6 characters.');
  }
  if (!USER_ROLES.includes(role)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid user role.');
  }
  if (data?.companyId && data.companyId !== adminData.companyId) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot create users for another company.');
  }

  try {
    const existing = await auth.getUserByEmail(email).catch((error: { code?: string }) => {
      if (error.code === 'auth/user-not-found') return null;
      throw error;
    });
    if (existing) {
      throw new functions.https.HttpsError('already-exists', 'A user with this email already exists.');
    }

    const userRecord = await auth.createUser({ email, password, displayName: fullName, disabled: !isActive });
    try {
      await db.collection('users').doc(userRecord.uid).set({
        id: userRecord.uid,
        email,
        fullName,
        displayName: fullName,
        role,
        companyId: adminData.companyId,
        phoneNumber,
        isActive,
        emailVerified: false,
        approvalStatus: role === 'driver' ? 'pending' : 'approved',
        createdBy: context.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await auth.deleteUser(userRecord.uid);
      throw error;
    }

    return { success: true, uid: userRecord.uid, email, message: `Successfully created ${fullName}.` };
  } catch (error: any) {
    console.error('Error creating user:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    if (error?.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'A user with this email already exists.');
    }
    throw new functions.https.HttpsError('internal', 'Failed to create user.');
  }
});

/**
 * Invite a new user to the platform
 * Only admins can invite users to their company
 */
export const inviteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to invite users.');
  }

  const adminUid = context.auth.uid;

  try {
    const adminDoc = await db.collection('users').doc(adminUid).get();
    
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Admin user document not found.');
    }

    const adminData = adminDoc.data();

    if (!adminData || adminData.role !== 'admin') {
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
      existingUser = await auth.getUserByEmail(email);
    } catch (error: any) {
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    if (existingUser) {
      throw new functions.https.HttpsError('already-exists', 'A user with this email already exists.');
    }

    const tempPassword = generateSecurePassword();

    const userRecord = await auth.createUser({
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

    await db.collection('users').doc(userRecord.uid).set(userData);

    const resetLink = await auth.generatePasswordResetLink(email);

    console.log(`User invited: ${email} (${role})`);

    return {
      success: true,
      userId: userRecord.uid,
      message: `Successfully invited ${fullName} as ${role}.`,
      resetLink: resetLink,
    };

  } catch (error: any) {
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
export const createCompany = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create companies.');
  }

  const { name, email, phone, address, adminEmail, adminName } = data;

  if (!name || !email || !adminEmail || !adminName) {
    throw new functions.https.HttpsError('invalid-argument', 'Company name, email, admin email, and admin name are required.');
  }

  try {
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

  } catch (error: any) {
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
export const deactivateUser = functions.https.onCall(async (data, context) => {
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

    if (!adminData || adminData.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can deactivate users.');
    }

    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found.');
    }

    const userData = userDoc.data();

    if (!userData || userData.companyId !== adminData.companyId) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot deactivate users from other companies.');
    }

    await db.collection('users').doc(userId).update({
      isActive: false,
      deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deactivatedBy: adminUid,
    });

    await auth.updateUser(userId, { disabled: true });

    console.log(`User deactivated: ${userId} by ${adminUid}`);

    return {
      success: true,
      message: `User ${userData.fullName} has been deactivated.`,
    };

  } catch (error: any) {
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
export const reactivateUser = functions.https.onCall(async (data, context) => {
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

    if (!adminData || adminData.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can reactivate users.');
    }

    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData || userData.companyId !== adminData.companyId) {
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

  } catch (error: any) {
    console.error('Error reactivating user:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to reactivate user: ${error.message}`);
  }
});

// Helper function to generate secure password
function generateSecurePassword(): string {
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

/**
 * Generate a company code for setup (Developer only)
 */
export const generateCompanyCode = functions.https.onCall(async (data, context) => {
  const { companyName } = data;

  if (!companyName || typeof companyName !== 'string' || companyName.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Company name is required.');
  }

  try {
    // Generate a unique code
    const code = generateUniqueCode();

    // Check if code already exists (unlikely but safe)
    const existingCode = await db.collection('company_codes').where('code', '==', code).get();
    if (!existingCode.empty) {
      throw new functions.https.HttpsError('internal', 'Code generation collision, please try again.');
    }

    // Save the code
    await db.collection('company_codes').add({
      code: code,
      companyName: companyName.trim(),
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      used: false,
      usedBy: null,
      usedAt: null,
      createdBy: context.auth?.uid || 'developer',
    });

    console.log(`Company code generated: ${code} for ${companyName}`);

    return {
      success: true,
      code: code,
      companyName: companyName.trim(),
      message: `Company code generated successfully.`,
    };

  } catch (error: any) {
    console.error('Error generating company code:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to generate company code: ${error.message}`);
  }
});

/**
 * List company codes (Developer only)
 */
export const listCompanyCodes = functions.https.onCall(async () => {
  try {
    const codesSnapshot = await db.collection('company_codes')
      .orderBy('createdAt', 'desc')
      .get();

    const codes = codesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      success: true,
      codes: codes,
    };

  } catch (error: any) {
    console.error('Error listing company codes:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to list company codes: ${error.message}`);
  }
});

/**
 * Update company code status (Developer only)
 */
export const updateCompanyCodeStatus = functions.https.onCall(async (data, context) => {
  const { codeId, status } = data;

  if (!codeId || !status) {
    throw new functions.https.HttpsError('invalid-argument', 'codeId and status are required.');
  }

  if (!['active', 'inactive'].includes(status)) {
    throw new functions.https.HttpsError('invalid-argument', 'Status must be "active" or "inactive".');
  }

  try {
    await db.collection('company_codes').doc(codeId).update({
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth?.uid || 'developer',
    });

    console.log(`Company code ${codeId} status updated to ${status}`);

    return {
      success: true,
      message: `Company code status updated successfully.`,
    };

  } catch (error: any) {
    console.error('Error updating company code status:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to update company code status: ${error.message}`);
  }
});

/**
 * Delete company code (Developer only)
 */
export const deleteCompanyCode = functions.https.onCall(async (data) => {
  const { codeId } = data;

  if (!codeId) {
    throw new functions.https.HttpsError('invalid-argument', 'codeId is required.');
  }

  try {
    await db.collection('company_codes').doc(codeId).delete();

    console.log(`Company code ${codeId} deleted`);

    return {
      success: true,
      message: `Company code deleted successfully.`,
    };

  } catch (error: any) {
    console.error('Error deleting company code:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to delete company code: ${error.message}`);
  }
});

/**
 * Verify company code is valid and active
 */
export const verifyCompanyCode = functions.https.onCall(async (data) => {
  const { code } = data;

  if (!code || typeof code !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Code is required.');
  }

  try {
    const codeSnapshot = await db.collection('company_codes')
      .where('code', '==', code.trim())
      .where('status', '==', 'active')
      .where('used', '==', false)
      .limit(1)
      .get();

    if (codeSnapshot.empty) {
      return {
        success: false,
        valid: false,
        message: 'Invalid or already used company code.',
      };
    }

    const codeDoc = codeSnapshot.docs[0];
    const codeData = codeDoc.data();

    return {
      success: true,
      valid: true,
      companyName: codeData.companyName,
      codeId: codeDoc.id,
      message: 'Valid company code.',
    };

  } catch (error: any) {
    console.error('Error verifying company code:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to verify company code: ${error.message}`);
  }
});

/**
 * Register a new company with admin user using invite code
 */
export const registerWithInviteCode = functions.https.onCall(async (data) => {
  const { codeId, companyName, adminEmail, adminPassword, adminName } = data;

  if (!codeId || !companyName || !adminEmail || !adminPassword || !adminName) {
    throw new functions.https.HttpsError('invalid-argument', 'All fields are required.');
  }

  try {
    // 1. Verify the code is still valid
    const codeDoc = await db.collection('company_codes').doc(codeId).get();
    
    if (!codeDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Invalid invite code.');
    }

    const codeData = codeDoc.data();
    if (codeData?.used === true) {
      throw new functions.https.HttpsError('failed-precondition', 'Invite code has already been used.');
    }

    if (codeData?.status !== 'active') {
      throw new functions.https.HttpsError('failed-precondition', 'Invite code is not active.');
    }

    // 2. Create the company
    const companyRef = db.collection('companies').doc();
    const companyId = companyRef.id;

    await companyRef.set({
      name: companyName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      plan: 'free',
      isActive: true,
      settings: {
        autoApproveDrivers: false,
        requireDriverApproval: true,
      },
    });

    // 3. Create the admin user in Firebase Auth
    const adminUser = await auth.createUser({
      email: adminEmail,
      password: adminPassword,
      displayName: adminName,
      emailVerified: false,
    });

    // 4. Create the admin user document in Firestore
    await db.collection('users').doc(adminUser.uid).set({
      id: adminUser.uid,
      email: adminEmail,
      fullName: adminName,
      displayName: adminName,
      role: 'admin',
      companyId: companyId,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Mark the invite code as used
    await db.collection('company_codes').doc(codeId).update({
      used: true,
      usedBy: adminEmail,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`New company registered: ${companyName} (${companyId}) by ${adminEmail}`);

    return {
      success: true,
      companyId: companyId,
      userId: adminUser.uid,
      message: 'Registration successful.',
    };

  } catch (error: any) {
    console.error('Error registering with invite code:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Registration failed: ${error.message}`);
  }
});

/**
 * Mark company code as used
 */
export const markCodeAsUsed = functions.https.onCall(async (data) => {
  const { codeId, usedBy } = data;

  if (!codeId || !usedBy) {
    throw new functions.https.HttpsError('invalid-argument', 'codeId and usedBy are required.');
  }

  try {
    await db.collection('company_codes').doc(codeId).update({
      used: true,
      usedBy: usedBy,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Company code ${codeId} marked as used by ${usedBy}`);

    return {
      success: true,
      message: 'Company code marked as used.',
    };

  } catch (error: any) {
    console.error('Error marking code as used:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to mark code as used: ${error.message}`);
  }
});

/**
 * Helper function to generate unique codes
 */
function generateUniqueCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
