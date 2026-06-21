/**
 * Business Central Pull Integration
 * Fetch sales shipments from BC and normalize into PODSafe deliveries
 */

import * as admin from 'firebase-admin';
import { createBcClient } from './client';
import { upsertDelivery } from '../../store/firestore';
import { mapBcStatusToPodsafe } from '../../util/statusMap';
import {
  BCSalesShipment,
  BCSalesShipmentLine,
  DeliveryNormalized,
  PullShipmentsRequest,
  PullShipmentsResponse,
} from '../../types';

/**
 * Pull sales shipments from Business Central
 * 
 * @param request Pull request parameters
 * @returns Summary of sync operation
 */
export async function pullShipments(
  request: PullShipmentsRequest
): Promise<PullShipmentsResponse> {
  const { companyId, since, limit = 100 } = request;
  
  const response: PullShipmentsResponse = {
    success: false,
    created: 0,
    updated: 0,
    skipped: 0,
    errors: [],
  };

  try {
    const client = createBcClient(companyId);
    
    // Build OData query
    let endpoint = `companies(${await getBcCompanyId(companyId)})/salesShipments`;
    endpoint += '?$orderby=lastModifiedDateTime asc';
    endpoint += `&$top=${limit}`;
    
    // Add filter for incremental sync
    if (since) {
      const sinceDate = new Date(since).toISOString();
      endpoint += `&$filter=lastModifiedDateTime gt ${sinceDate}`;
    }

    console.log(`Pulling shipments from BC: ${endpoint}`);

    // Fetch shipments
    const shipmentsData = await client.get<{ value: BCSalesShipment[] }>(endpoint);
    const shipments = shipmentsData.value || [];

    console.log(`Fetched ${shipments.length} shipments from BC`);

    // Process each shipment
    for (const shipment of shipments) {
      try {
        // Fetch shipment lines
        const lines = await fetchShipmentLines(client, companyId, shipment.id);

        // Transform to PODSafe delivery
        const delivery = transformShipmentToDelivery(companyId, shipment, lines);

        // Upsert to Firestore (idempotent by etag)
        const result = await upsertDelivery(delivery);

        // Update counters
        if (result === 'created') {
          response.created++;
        } else if (result === 'updated') {
          response.updated++;
        } else {
          response.skipped++;
        }

        console.log(`Shipment ${shipment.number}: ${result}`);
      } catch (error) {
        const errorMsg = `Failed to process shipment ${shipment.number}: ${(error as Error).message}`;
        console.error(errorMsg);
        response.errors.push(errorMsg);
      }
    }

    response.success = response.errors.length === 0;
    console.log('Pull complete:', response);

    return response;
  } catch (error) {
    console.error('Pull shipments failed:', error);
    response.errors.push((error as Error).message);
    return response;
  }
}

/**
 * Fetch shipment lines for a sales shipment
 */
async function fetchShipmentLines(
  client: ReturnType<typeof createBcClient>,
  companyId: string,
  shipmentId: string
): Promise<BCSalesShipmentLine[]> {
  try {
    const bcCompanyId = await getBcCompanyId(companyId);
    const endpoint = `companies(${bcCompanyId})/salesShipmentLines?$filter=documentId eq ${shipmentId}`;
    
    const linesData = await client.get<{ value: BCSalesShipmentLine[] }>(endpoint);
    return linesData.value || [];
  } catch (error) {
    console.warn(`Failed to fetch lines for shipment ${shipmentId}:`, error);
    return [];
  }
}

/**
 * Get BC company ID from integration config
 */
async function getBcCompanyId(companyId: string): Promise<string> {
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

/**
 * Transform BC sales shipment to PODSafe delivery
 */
function transformShipmentToDelivery(
  companyId: string,
  shipment: BCSalesShipment,
  lines: BCSalesShipmentLine[]
): DeliveryNormalized {
  // Extract scheduled date (prefer shipment date, fallback to posting date)
  const scheduledDate = shipment.shipmentDate || 
                        shipment.requestedDeliveryDate || 
                        shipment.postingDate || 
                        new Date().toISOString();

  // Map status (BC shipments are typically "posted" = delivered)
  // You may need custom logic based on your BC configuration
  const status = mapBcStatusToPodsafe('posted'); // Shipments are usually completed

  // Transform lines to items
  const items = lines
    .filter(line => line.lineType === 'Item' || line.quantity > 0)
    .map(line => ({
      sku: line.lineObjectNumber,
      name: line.description,
      qty: line.quantity,
      uom: line.unitOfMeasureCode,
      traceId: line.id,
    }));

  // Build delivery document
  const delivery: DeliveryNormalized = {
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

/**
 * Validate pull request
 */
export function validatePullRequest(request: any): request is PullShipmentsRequest {
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
