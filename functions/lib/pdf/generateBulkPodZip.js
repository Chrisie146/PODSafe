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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateBulkPodZip = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const jszip_1 = __importDefault(require("jszip"));
const crypto_1 = require("crypto");
const generatePodPdf_1 = require("./generatePodPdf");
const db = admin.firestore();
const MAX_PODS = 50;
function sanitizeName(raw, fallback) {
    const cleaned = String(raw ?? '').replace(/[^A-Za-z0-9_-]/g, '').trim();
    return cleaned.length > 0 ? cleaned : fallback;
}
exports.generateBulkPodZip = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to export PODs.');
    }
    const podIds = Array.isArray(data?.podIds) ? data.podIds.filter((id) => typeof id === 'string' && id.trim().length > 0) : [];
    if (podIds.length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'podIds must be a non-empty array.');
    }
    if (podIds.length > MAX_PODS) {
        throw new functions.https.HttpsError('invalid-argument', `Too many PODs requested (${podIds.length}); limit is ${MAX_PODS} per export.`);
    }
    const mode = data?.mode === 'images' ? 'images' : 'pdf';
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    const caller = callerDoc.data();
    if (!callerDoc.exists || !caller || caller.isActive !== true) {
        throw new functions.https.HttpsError('permission-denied', 'Active user account required.');
    }
    if (caller.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Administrator role required to bulk-export PODs.');
    }
    const companyId = caller.companyId;
    if (typeof companyId !== 'string' || companyId.length === 0) {
        throw new functions.https.HttpsError('permission-denied', 'Caller is not associated with a company.');
    }
    const companyDoc = await db.collection('companies').doc(companyId).get();
    const company = companyDoc.data();
    const zip = new jszip_1.default();
    let included = 0;
    let skipped = 0;
    for (const podId of podIds) {
        try {
            const podDoc = await db.collection('pods').doc(podId).get();
            if (!podDoc.exists) {
                skipped++;
                continue;
            }
            const pod = podDoc.data();
            if (pod.companyId !== companyId) {
                skipped++;
                continue;
            }
            const deliveryId = typeof pod.deliveryId === 'string' && pod.deliveryId.length > 0 ? pod.deliveryId : podId;
            const deliveryDoc = await db.collection('deliveries').doc(deliveryId).get();
            const delivery = deliveryDoc.data();
            const driverDoc = delivery?.driverId ? await db.collection('users').doc(delivery.driverId).get() : null;
            const driver = driverDoc?.data();
            let vehicle;
            if (delivery?.vehicleUsed) {
                const vehicleSnapshot = await db
                    .collection('companies').doc(companyId).collection('vehicles')
                    .where('registration', '==', (0, generatePodPdf_1.normalizeRegistration)(delivery.vehicleUsed))
                    .limit(1)
                    .get();
                vehicle = vehicleSnapshot.empty ? undefined : vehicleSnapshot.docs[0].data();
            }
            const baseName = sanitizeName(delivery?.invoiceNumber ?? delivery?.orderNumber ?? podId, podId);
            if (mode === 'pdf') {
                const photoUrls = Array.isArray(pod.photoUrls) && pod.photoUrls.length > 0
                    ? pod.photoUrls
                    : (pod.photoUrl ? [pod.photoUrl] : []);
                const documentUrls = Array.isArray(pod.documentUrls) ? pod.documentUrls : [];
                const documentMetadata = Array.isArray(pod.documentMetadata) ? pod.documentMetadata : [];
                const [photoBytesList, documentBytesList, signatureBytes, stampBytes, logoBytes] = await Promise.all([
                    Promise.all(photoUrls.map(generatePodPdf_1.fetchImageBytes)),
                    Promise.all(documentUrls.map(generatePodPdf_1.fetchImageBytes)),
                    (0, generatePodPdf_1.fetchImageBytes)(pod.signatureUrl),
                    (0, generatePodPdf_1.fetchImageBytes)(pod.stampPhotoUrl),
                    (0, generatePodPdf_1.fetchImageBytes)(company?.logoUrl),
                ]);
                const input = {
                    deliveryId, pod, delivery, driver, vehicle, company,
                    photoBytesList, documentBytesList, documentMetadata,
                    signatureBytes, stampBytes, logoBytes,
                };
                const pdfBuffer = await (0, generatePodPdf_1.buildPodPdfBuffer)(input);
                zip.file(`POD_${baseName}.pdf`, pdfBuffer);
            }
            else {
                const folder = zip.folder(`POD_${baseName}`);
                if (!folder) {
                    skipped++;
                    continue;
                }
                const photoUrls = Array.isArray(pod.photoUrls) && pod.photoUrls.length > 0
                    ? pod.photoUrls
                    : (pod.photoUrl ? [pod.photoUrl] : []);
                let photoIndex = 0;
                for (const url of photoUrls) {
                    const bytes = await (0, generatePodPdf_1.fetchImageBytes)(url);
                    if (bytes) {
                        photoIndex++;
                        const ext = url.match(/\.(png|jpe?g|webp|gif)(\?|$)/i)?.[1]?.toLowerCase() ?? 'jpg';
                        folder.file(`photo_${photoIndex}.${ext}`, bytes);
                    }
                }
                const sigBytes = await (0, generatePodPdf_1.fetchImageBytes)(pod.signatureUrl);
                if (sigBytes)
                    folder.file('customer_signature.png', sigBytes);
                const stampBytes = await (0, generatePodPdf_1.fetchImageBytes)(pod.stampPhotoUrl);
                if (stampBytes)
                    folder.file('stamp.png', stampBytes);
                if (photoIndex === 0 && !sigBytes && !stampBytes) {
                    zip.remove(`POD_${baseName}`);
                    skipped++;
                    continue;
                }
            }
            included++;
        }
        catch (error) {
            console.warn('generateBulkPodZip: skipping pod due to error', podId, error.message);
            skipped++;
        }
    }
    if (included === 0) {
        throw new functions.https.HttpsError('not-found', 'No PODs could be exported (none found in your company, or all fetches failed).');
    }
    const zipBuffer = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
    const bucket = admin.storage().bucket();
    const filePath = `companies/${companyId}/exports/pods_${mode}_${Date.now()}.zip`;
    const file = bucket.file(filePath);
    const downloadToken = (0, crypto_1.randomUUID)();
    await file.save(zipBuffer, {
        metadata: {
            contentType: 'application/zip',
            metadata: { firebaseStorageDownloadTokens: downloadToken },
        },
    });
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media&token=${downloadToken}`;
    return { success: true, downloadUrl, included, skipped, mode };
});
//# sourceMappingURL=generateBulkPodZip.js.map