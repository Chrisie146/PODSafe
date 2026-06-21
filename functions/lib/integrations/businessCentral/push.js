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
exports.pushPod = pushPod;
exports.validatePushPodRequest = validatePushPodRequest;
exports.uploadPodAttachment = uploadPodAttachment;
const admin = __importStar(require("firebase-admin"));
const client_1 = require("./client");
const firestore_1 = require("../../store/firestore");
const statusMap_1 = require("../../util/statusMap");
async function pushPod(request) {
    const { companyId, sourceId, status, pod } = request;
    try {
        console.log(`Pushing POD for shipment ${sourceId}`);
        const delivery = await (0, firestore_1.getDeliveryBySourceId)(companyId, sourceId);
        if (!delivery) {
            return {
                success: false,
                error: `Delivery not found: ${sourceId}`,
            };
        }
        const client = (0, client_1.createBcClient)(companyId);
        const bcCompanyId = await getBcCompanyId(companyId);
        const bcPayload = buildBcPodPayload(status, pod);
        const etag = delivery.sync.version;
        const endpoint = `companies(${bcCompanyId})/salesShipments(${sourceId})`;
        try {
            await client.patch(endpoint, bcPayload, etag);
            console.log(`POD pushed successfully for ${sourceId}`);
            await (0, firestore_1.updateDeliverySync)(companyId, sourceId, {
                lastPushAt: admin.firestore.Timestamp.now(),
                lastPushError: undefined,
            });
            return {
                success: true,
                message: 'POD data pushed to Business Central successfully',
            };
        }
        catch (error) {
            if (error.message.includes('modified')) {
                console.warn('Etag mismatch, refetching and retrying...');
                const latestShipment = await client.get(endpoint);
                const latestEtag = latestShipment['@odata.etag'];
                await client.patch(endpoint, bcPayload, latestEtag);
                await (0, firestore_1.updateDeliverySync)(companyId, sourceId, {
                    version: latestEtag,
                    lastPushAt: admin.firestore.Timestamp.now(),
                    lastPushError: undefined,
                });
                return {
                    success: true,
                    message: 'POD data pushed after refetch (etag conflict resolved)',
                };
            }
            throw error;
        }
    }
    catch (error) {
        const errorMsg = error.message;
        console.error('Push POD failed:', errorMsg);
        try {
            await (0, firestore_1.updateDeliverySync)(companyId, sourceId, {
                lastPushError: errorMsg,
            });
        }
        catch (updateError) {
            console.error('Failed to update delivery sync error:', updateError);
        }
        return {
            success: false,
            error: errorMsg,
        };
    }
}
function buildBcPodPayload(status, pod) {
    const bcStatus = (0, statusMap_1.mapPodsafeStatusToBc)(status);
    const payload = {
        PODSafe_Status: bcStatus,
        PODSafe_CompletedAt: pod.completedAt,
        PODSafe_DeliveryNote: pod.note || '',
    };
    if (pod.gpsLat !== undefined && pod.gpsLng !== undefined) {
        payload.PODSafe_GPSLatitude = pod.gpsLat;
        payload.PODSafe_GPSLongitude = pod.gpsLng;
    }
    if (pod.signature) {
        payload.PODSafe_SignatureData = pod.signature;
    }
    return payload;
}
async function getBcCompanyId(companyId) {
    const doc = await admin.firestore()
        .collection('companies')
        .doc(companyId)
        .collection('integrations')
        .doc('businessCentral')
        .get();
    if (!doc.exists) {
        throw new Error(`BC integration not found for company: ${companyId}`);
    }
    const bcCompanyId = doc.data()?.companyId;
    if (!bcCompanyId) {
        throw new Error('BC company ID not configured');
    }
    return bcCompanyId;
}
function validatePushPodRequest(request) {
    if (!request || typeof request !== 'object') {
        return false;
    }
    if (!request.companyId || typeof request.companyId !== 'string') {
        return false;
    }
    if (!request.sourceId || typeof request.sourceId !== 'string') {
        return false;
    }
    if (!request.status || typeof request.status !== 'string') {
        return false;
    }
    if (!request.pod || typeof request.pod !== 'object') {
        return false;
    }
    if (!request.pod.completedAt || typeof request.pod.completedAt !== 'string') {
        return false;
    }
    return true;
}
async function uploadPodAttachment(companyId, sourceId, file) {
    const client = (0, client_1.createBcClient)(companyId);
    const bcCompanyId = await getBcCompanyId(companyId);
    const endpoint = `companies(${bcCompanyId})/attachments`;
    const payload = {
        parentId: sourceId,
        parentType: 'Sales Shipment',
        fileName: file.fileName,
        attachmentContent: file.content,
    };
    await client.post(endpoint, payload);
    console.log(`Uploaded attachment ${file.fileName} for shipment ${sourceId}`);
}
//# sourceMappingURL=push.js.map