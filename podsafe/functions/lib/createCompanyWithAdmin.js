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
exports.createCompanyWithAdmin = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
exports.createCompanyWithAdmin = functions.https.onCall(async (data, _context) => {
    try {
        const { companyName, adminName, email, password } = data;
        if (!companyName || !adminName || !email || !password) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: companyName, adminName, email, password');
        }
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            throw new functions.https.HttpsError('invalid-argument', 'Invalid email format');
        }
        if (password.length < 6) {
            throw new functions.https.HttpsError('invalid-argument', 'Password must be at least 6 characters');
        }
        const companyRef = admin.firestore().collection('companies').doc();
        const companyId = companyRef.id;
        const companyData = {
            id: companyId,
            name: companyName.trim(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            isActive: true,
            plan: 'free',
            settings: {
                timezone: 'UTC',
                dateFormat: 'MM/dd/yyyy',
                timeFormat: '12h',
            },
        };
        await companyRef.set(companyData);
        let userRecord;
        try {
            userRecord = await admin.auth().createUser({
                email: email.trim().toLowerCase(),
                password: password,
                displayName: adminName.trim(),
            });
        }
        catch (authError) {
            await companyRef.delete();
            throw new functions.https.HttpsError('already-exists', authError.code === 'auth/email-already-exists'
                ? 'An account with this email already exists'
                : `Failed to create user: ${authError.message}`);
        }
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
    }
    catch (error) {
        console.error('❌ Error in createCompanyWithAdmin:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to create company: ${error.message}`);
    }
});
//# sourceMappingURL=createCompanyWithAdmin.js.map