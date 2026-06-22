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
exports.bcTestConnection = exports.bcApiCall = exports.bcAuthenticate = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const client_1 = require("../integrations/businessCentral/client");
async function requireCompanyAdmin(context, companyId) {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    if (typeof companyId !== 'string' || !companyId) {
        throw new functions.https.HttpsError('invalid-argument', 'companyId is required.');
    }
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const user = userDoc.data();
    if (!userDoc.exists || !user || user.isActive !== true || user.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Only active administrators can use Business Central integration.');
    }
    if (user.companyId !== companyId) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot access another company.');
    }
    return companyId;
}
function validateEndpoint(endpoint) {
    if (typeof endpoint !== 'string' || !endpoint.startsWith('companies(') || endpoint.includes('://') || endpoint.includes('..') || endpoint.includes('\\')) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid Business Central API endpoint.');
    }
}
exports.bcAuthenticate = functions.https.onCall(async (data, context) => {
    const companyId = await requireCompanyAdmin(context, data?.companyId);
    const accessToken = await (0, client_1.getAccessToken)(companyId);
    return { accessToken, expiresIn: 3000 };
});
exports.bcApiCall = functions.https.onCall(async (data, context) => {
    const companyId = await requireCompanyAdmin(context, data?.companyId);
    const method = data?.method;
    validateEndpoint(data?.endpoint);
    if (!['GET', 'POST', 'PATCH'].includes(method)) {
        throw new functions.https.HttpsError('invalid-argument', 'method must be GET, POST, or PATCH.');
    }
    if ((method === 'POST' || method === 'PATCH') && (data.body == null || typeof data.body !== 'object' || Array.isArray(data.body))) {
        throw new functions.https.HttpsError('invalid-argument', 'body must be an object for POST and PATCH requests.');
    }
    const client = (0, client_1.createBcClient)(companyId);
    switch (method) {
        case 'GET': return client.get(data.endpoint);
        case 'POST': return client.post(data.endpoint, data.body);
        case 'PATCH': return client.patch(data.endpoint, data.body, typeof data.etag === 'string' ? data.etag : undefined);
    }
});
exports.bcTestConnection = functions.https.onCall(async (data, context) => {
    const companyId = await requireCompanyAdmin(context, data?.companyId);
    try {
        const response = await (0, client_1.createBcClient)(companyId).get('companies');
        return { success: true, message: 'Connected to Business Central.', companiesCount: response.value?.length ?? 0 };
    }
    catch (error) {
        console.error('BC connection test failed:', error);
        throw new functions.https.HttpsError('unavailable', 'Could not connect to Business Central.');
    }
});
//# sourceMappingURL=bcCallables.js.map