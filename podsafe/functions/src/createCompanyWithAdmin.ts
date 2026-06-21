import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function to create a new company with an admin user
 * This enables self-service company registration without needing developer access
 */
export const createCompanyWithAdmin = functions.https.onCall(async (data, _context) => {
  try {
    const { companyName, adminName, email, password } = data;

    // Validate input
    if (!companyName || !adminName || !email || !password) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: companyName, adminName, email, password'
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email format'
      );
    }

    // Validate password length
    if (password.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Password must be at least 6 characters'
      );
    }

    // Create the company document first
    const companyRef = admin.firestore().collection('companies').doc();
    const companyId = companyRef.id;
    
    const companyData = {
      id: companyId,
      name: companyName.trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      plan: 'free', // Start with free plan
      settings: {
        timezone: 'UTC',
        dateFormat: 'MM/dd/yyyy',
        timeFormat: '12h',
      },
    };

    await companyRef.set(companyData);

    // Create the admin user in Firebase Auth
    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email: email.trim().toLowerCase(),
        password: password,
        displayName: adminName.trim(),
      });
    } catch (authError: any) {
      // If user creation fails, delete the company document
      await companyRef.delete();
      throw new functions.https.HttpsError(
        'already-exists',
        authError.code === 'auth/email-already-exists'
          ? 'An account with this email already exists'
          : `Failed to create user: ${authError.message}`
      );
    }

    // Create the user document in Firestore
    const userRef = admin.firestore().collection('users').doc(userRecord.uid);
    const userData = {
      id: userRecord.uid,
      email: email.trim().toLowerCase(),
      fullName: adminName.trim(),
      role: 'admin',
      companyId: companyId,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: null,
      profileImageUrl: null,
      phoneNumber: null,
    };

    await userRef.set(userData);

    // Set custom claims for the user
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      role: 'admin',
      companyId: companyId,
    });

    console.log(`✅ Company created: ${companyId} with admin user: ${userRecord.uid}`);

    return {
      success: true,
      companyId: companyId,
      userId: userRecord.uid,
      message: 'Company and admin account created successfully',
    };

  } catch (error: any) {
    console.error('❌ Error in createCompanyWithAdmin:', error);
    
    // If it's already an HttpsError, rethrow it
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Otherwise, wrap it in a generic error
    throw new functions.https.HttpsError(
      'internal',
      `Failed to create company: ${error.message}`
    );
  }
});
