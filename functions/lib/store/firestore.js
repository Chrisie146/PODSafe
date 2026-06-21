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
exports.TokenVault = void 0;
exports.getBcIntegration = getBcIntegration;
exports.saveBcIntegration = saveBcIntegration;
exports.deleteBcIntegration = deleteBcIntegration;
exports.upsertDelivery = upsertDelivery;
exports.getDeliveryBySourceId = getDeliveryBySourceId;
exports.updateDeliverySync = updateDeliverySync;
exports.getDeliveries = getDeliveries;
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
class TokenVault {
    async saveRefreshToken(companyId, refreshToken) {
        const secretId = `bc-refresh-${companyId}-${Date.now()}`;
        await db
            .collection('_secrets')
            .doc(secretId)
            .set({
            type: 'bc_refresh_token',
            companyId,
            value: refreshToken,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return secretId;
    }
    async loadRefreshToken(secretId) {
        const doc = await db.collection('_secrets').doc(secretId).get();
        if (!doc.exists) {
            return null;
        }
        const data = doc.data();
        return data?.value || null;
    }
    async deleteRefreshToken(secretId) {
        await db.collection('_secrets').doc(secretId).delete();
    }
}
exports.TokenVault = TokenVault;
async function getBcIntegration(companyId) {
    const doc = await db
        .collection('companies')
        .doc(companyId)
        .collection('integrations')
        .doc('businessCentral')
        .get();
    if (!doc.exists) {
        return null;
    }
    return doc.data();
}
async function saveBcIntegration(companyId, integration) {
    await db
        .collection('companies')
        .doc(companyId)
        .collection('integrations')
        .doc('businessCentral')
        .set({
        ...integration,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function deleteBcIntegration(companyId) {
    await db
        .collection('companies')
        .doc(companyId)
        .collection('integrations')
        .doc('businessCentral')
        .delete();
}
async function upsertDelivery(delivery) {
    const { companyId, source, sourceId } = delivery;
    const snapshot = await db
        .collection('deliveries')
        .where('companyId', '==', companyId)
        .where('source', '==', source)
        .where('sourceId', '==', sourceId)
        .limit(1)
        .get();
    if (snapshot.empty) {
        await db.collection('deliveries').add({
            ...delivery,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return 'created';
    }
    const existingDoc = snapshot.docs[0];
    const existingData = existingDoc.data();
    if (existingData.sync.version &&
        delivery.sync.version &&
        existingData.sync.version === delivery.sync.version) {
        return 'skipped';
    }
    await existingDoc.ref.update({
        ...delivery,
        createdAt: existingData.createdAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return 'updated';
}
async function getDeliveryBySourceId(companyId, sourceId) {
    const snapshot = await db
        .collection('deliveries')
        .where('companyId', '==', companyId)
        .where('source', '==', 'BusinessCentral')
        .where('sourceId', '==', sourceId)
        .limit(1)
        .get();
    if (snapshot.empty) {
        return null;
    }
    return snapshot.docs[0].data();
}
async function updateDeliverySync(companyId, sourceId, syncUpdate) {
    const snapshot = await db
        .collection('deliveries')
        .where('companyId', '==', companyId)
        .where('source', '==', 'BusinessCentral')
        .where('sourceId', '==', sourceId)
        .limit(1)
        .get();
    if (snapshot.empty) {
        throw new Error(`Delivery not found: ${sourceId}`);
    }
    const doc = snapshot.docs[0];
    await doc.ref.update({
        sync: {
            ...doc.data().sync,
            ...syncUpdate,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function getDeliveries(companyId, limit = 50, startAfter) {
    let query = db
        .collection('deliveries')
        .where('companyId', '==', companyId)
        .where('source', '==', 'BusinessCentral')
        .orderBy('createdAt', 'desc')
        .limit(limit);
    if (startAfter) {
        query = query.startAfter(startAfter);
    }
    const snapshot = await query.get();
    return snapshot.docs.map(doc => doc.data());
}
//# sourceMappingURL=firestore.js.map