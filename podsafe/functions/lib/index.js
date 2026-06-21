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
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.bcHealth = exports.bcAutoPushPod = exports.bcScheduledPull = exports.bcPushPod = exports.bcPullShipments = exports.bcOAuthCallback = exports.bcOAuthRedirect = exports.createCompanyWithAdmin = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const config_1 = require("./config");
(0, config_1.validateConfig)();
const bcAuth = __importStar(require("./auth/bcAuth"));
const pull_1 = require("./integrations/businessCentral/pull");
const push_1 = require("./integrations/businessCentral/push");
const createCompanyWithAdmin_1 = require("./createCompanyWithAdmin");
Object.defineProperty(exports, "createCompanyWithAdmin", { enumerable: true, get: function () { return createCompanyWithAdmin_1.createCompanyWithAdmin; } });
exports.bcOAuthRedirect = bcAuth.redirect;
exports.bcOAuthCallback = bcAuth.callback;
exports.bcPullShipments = functions.https.onRequest(async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }
    try {
        if (!(0, pull_1.validatePullRequest)(req.body)) {
            res.status(400).json({ error: 'Invalid request body' });
            return;
        }
        console.log('Pull request:', req.body);
        const result = await (0, pull_1.pullShipments)(req.body);
        res.status(200).json(result);
    }
    catch (error) {
        console.error('Pull shipments error:', error);
        res.status(500).json({
            success: false,
            error: error.message,
            created: 0,
            updated: 0,
            skipped: 0,
            errors: [error.message],
        });
    }
});
exports.bcPushPod = functions.https.onRequest(async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }
    try {
        if (!(0, push_1.validatePushPodRequest)(req.body)) {
            res.status(400).json({
                success: false,
                error: 'Invalid request body',
            });
            return;
        }
        console.log('Push POD request:', {
            companyId: req.body.companyId,
            sourceId: req.body.sourceId,
            status: req.body.status,
        });
        const result = await (0, push_1.pushPod)(req.body);
        const statusCode = result.success ? 200 : 500;
        res.status(statusCode).json(result);
    }
    catch (error) {
        console.error('Push POD error:', error);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});
exports.bcScheduledPull = functions.pubsub
    .schedule('0 2 * * *')
    .timeZone('UTC')
    .onRun(async (_context) => {
    console.log('Starting scheduled BC pull for all companies');
    try {
        const integrationsSnapshot = await admin.firestore()
            .collectionGroup('integrations')
            .where('status', '==', 'connected')
            .get();
        console.log(`Found ${integrationsSnapshot.size} connected BC integrations`);
        const results = [];
        for (const doc of integrationsSnapshot.docs) {
            const integration = doc.data();
            const companyId = doc.ref.parent.parent?.id;
            if (!companyId) {
                console.warn('Could not determine company ID for integration:', doc.id);
                continue;
            }
            try {
                const since = new Date();
                since.setDate(since.getDate() - 7);
                const result = await (0, pull_1.pullShipments)({
                    companyId,
                    since: since.toISOString(),
                    limit: 500,
                });
                results.push({
                    companyId,
                    companyName: integration.companyName,
                    ...result,
                });
                console.log(`Pulled for ${integration.companyName}:`, result);
            }
            catch (error) {
                console.error(`Failed to pull for company ${companyId}:`, error);
                results.push({
                    companyId,
                    success: false,
                    error: error.message,
                });
            }
        }
        console.log('Scheduled pull complete:', results);
        return results;
    }
    catch (error) {
        console.error('Scheduled pull failed:', error);
        throw error;
    }
});
exports.bcAutoPushPod = functions.firestore
    .document('deliveries/{deliveryId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (after.source !== 'BusinessCentral') {
        return null;
    }
    const finalStates = ['DELIVERED', 'FAILED', 'PARTIAL'];
    const statusChanged = before.status !== after.status;
    const isFinalState = finalStates.includes(after.status);
    if (!statusChanged || !isFinalState) {
        return null;
    }
    console.log(`Auto-pushing POD for delivery ${context.params.deliveryId}: ${before.status} -> ${after.status}`);
    try {
        const podPayload = {
            completedAt: after.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
            note: `Status changed to ${after.status}`,
        };
        const result = await (0, push_1.pushPod)({
            companyId: after.companyId,
            sourceId: after.sourceId,
            status: after.status,
            pod: podPayload,
        });
        if (result.success) {
            console.log('Auto-push successful:', context.params.deliveryId);
        }
        else {
            console.error('Auto-push failed:', result.error);
        }
        return result;
    }
    catch (error) {
        console.error('Auto-push POD error:', error);
        return null;
    }
});
async function verifyFirebaseToken(req) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        throw new Error('Missing or invalid authorization header');
    }
    const token = authHeader.split('Bearer ')[1];
    return admin.auth().verifyIdToken(token);
}
exports.bcHealth = functions.https.onRequest((_req, res) => {
    res.status(200).json({
        status: 'healthy',
        service: 'PODSafe Business Central Integration',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
    });
});
__exportStar(require("./auth/userManagement"), exports);
console.log('✅ All Cloud Functions loaded successfully');
//# sourceMappingURL=index.js.map