"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.markCodeAsUsed = exports.registerWithInviteCode = exports.verifyCompanyCode = exports.deleteCompanyCode = exports.updateCompanyCodeStatus = exports.listCompanyCodes = exports.generateCompanyCode = exports.reactivateUser = exports.deactivateUser = exports.createCompany = exports.inviteUser = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
const auth = admin.auth();
exports.inviteUser = functions.https.onCall(async (data, context) => {
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
        }
        catch (error) {
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
    }
    catch (error) {
        console.error('Error inviting user:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to invite user: ${error.message}`);
    }
});
exports.createCompany = functions.https.onCall(async (data, context) => {
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
    }
    catch (error) {
        console.error('Error creating company:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to create company: ${error.message}`);
    }
});
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
    }
    catch (error) {
        console.error('Error deactivating user:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to deactivate user: ${error.message}`);
    }
});
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
    }
    catch (error) {
        console.error('Error reactivating user:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to reactivate user: ${error.message}`);
    }
});
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
exports.generateCompanyCode = functions.https.onCall(async (data, context) => {
    const { companyName } = data;
    if (!companyName || typeof companyName !== 'string' || companyName.trim().length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Company name is required.');
    }
    try {
        const code = generateUniqueCode();
        const existingCode = await db.collection('company_codes').where('code', '==', code).get();
        if (!existingCode.empty) {
            throw new functions.https.HttpsError('internal', 'Code generation collision, please try again.');
        }
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
    }
    catch (error) {
        console.error('Error generating company code:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to generate company code: ${error.message}`);
    }
});
exports.listCompanyCodes = functions.https.onCall(async () => {
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
    }
    catch (error) {
        console.error('Error listing company codes:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to list company codes: ${error.message}`);
    }
});
exports.updateCompanyCodeStatus = functions.https.onCall(async (data, context) => {
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
    }
    catch (error) {
        console.error('Error updating company code status:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to update company code status: ${error.message}`);
    }
});
exports.deleteCompanyCode = functions.https.onCall(async (data) => {
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
    }
    catch (error) {
        console.error('Error deleting company code:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to delete company code: ${error.message}`);
    }
});
exports.verifyCompanyCode = functions.https.onCall(async (data) => {
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
    }
    catch (error) {
        console.error('Error verifying company code:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to verify company code: ${error.message}`);
    }
});
exports.registerWithInviteCode = functions.https.onCall(async (data) => {
    const { codeId, companyName, adminEmail, adminPassword, adminName } = data;
    if (!codeId || !companyName || !adminEmail || !adminPassword || !adminName) {
        throw new functions.https.HttpsError('invalid-argument', 'All fields are required.');
    }
    try {
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
        const adminUser = await auth.createUser({
            email: adminEmail,
            password: adminPassword,
            displayName: adminName,
            emailVerified: false,
        });
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
    }
    catch (error) {
        console.error('Error registering with invite code:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Registration failed: ${error.message}`);
    }
});
exports.markCodeAsUsed = functions.https.onCall(async (data) => {
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
    }
    catch (error) {
        console.error('Error marking code as used:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to mark code as used: ${error.message}`);
    }
});
function generateUniqueCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}
//# sourceMappingURL=userManagement.js.map