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
exports.pullShipments = pullShipments;
exports.validatePullRequest = validatePullRequest;
const admin = __importStar(require("firebase-admin"));
const client_1 = require("./client");
const firestore_1 = require("../../store/firestore");
const statusMap_1 = require("../../util/statusMap");
async function pullShipments(request) {
    const { companyId, since, limit = 100 } = request;
    const response = {
        success: false,
        created: 0,
        updated: 0,
        skipped: 0,
        errors: [],
    };
    try {
        const client = (0, client_1.createBcClient)(companyId);
        let endpoint = `companies(${await getBcCompanyId(companyId)})/salesShipments`;
        endpoint += '?$orderby=lastModifiedDateTime asc';
        endpoint += `&$top=${limit}`;
        if (since) {
            const sinceDate = new Date(since).toISOString();
            endpoint += `&$filter=lastModifiedDateTime gt ${sinceDate}`;
        }
        console.log(`Pulling shipments from BC: ${endpoint}`);
        const shipmentsData = await client.get(endpoint);
        const shipments = shipmentsData.value || [];
        console.log(`Fetched ${shipments.length} shipments from BC`);
        for (const shipment of shipments) {
            try {
                const lines = await fetchShipmentLines(client, companyId, shipment.id);
                const delivery = transformShipmentToDelivery(companyId, shipment, lines);
                const result = await (0, firestore_1.upsertDelivery)(delivery);
                if (result === 'created') {
                    response.created++;
                }
                else if (result === 'updated') {
                    response.updated++;
                }
                else {
                    response.skipped++;
                }
                console.log(`Shipment ${shipment.number}: ${result}`);
            }
            catch (error) {
                const errorMsg = `Failed to process shipment ${shipment.number}: ${error.message}`;
                console.error(errorMsg);
                response.errors.push(errorMsg);
            }
        }
        response.success = response.errors.length === 0;
        console.log('Pull complete:', response);
        return response;
    }
    catch (error) {
        console.error('Pull shipments failed:', error);
        response.errors.push(error.message);
        return response;
    }
}
async function fetchShipmentLines(client, companyId, shipmentId) {
    try {
        const bcCompanyId = await getBcCompanyId(companyId);
        const endpoint = `companies(${bcCompanyId})/salesShipmentLines?$filter=documentId eq ${shipmentId}`;
        const linesData = await client.get(endpoint);
        return linesData.value || [];
    }
    catch (error) {
        console.warn(`Failed to fetch lines for shipment ${shipmentId}:`, error);
        return [];
    }
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
function transformShipmentToDelivery(companyId, shipment, lines) {
    const scheduledDate = shipment.shipmentDate ||
        shipment.requestedDeliveryDate ||
        shipment.postingDate ||
        new Date().toISOString();
    const status = (0, statusMap_1.mapBcStatusToPodsafe)('posted');
    const items = lines
        .filter(line => line.lineType === 'Item' || line.quantity > 0)
        .map(line => ({
        sku: line.lineObjectNumber,
        name: line.description,
        qty: line.quantity,
        uom: line.unitOfMeasureCode,
        traceId: line.id,
    }));
    const delivery = {
        companyId,
        source: 'BusinessCentral',
        sourceId: shipment.id,
        orderNumber: shipment.number,
        customer: {
            id: shipment.sellToCustomerNumber,
            name: shipment.sellToCustomerName || 'Unknown Customer',
        },
        address: {
            line1: shipment.shipToAddress || '',
            line2: shipment.shipToAddress2,
            city: shipment.shipToCity || '',
            postalCode: shipment.shipToPostCode,
            country: shipment.shipToCountry,
        },
        scheduledDate,
        status,
        items,
        sync: {
            source: 'BusinessCentral',
            version: shipment['@odata.etag'],
            lastPullAt: admin.firestore.Timestamp.now(),
        },
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
    };
    return delivery;
}
function validatePullRequest(request) {
    if (!request || typeof request !== 'object') {
        return false;
    }
    if (!request.companyId || typeof request.companyId !== 'string') {
        return false;
    }
    if (request.since && typeof request.since !== 'string') {
        return false;
    }
    if (request.limit && typeof request.limit !== 'number') {
        return false;
    }
    return true;
}
//# sourceMappingURL=pull.js.map