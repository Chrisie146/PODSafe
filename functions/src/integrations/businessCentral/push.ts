/**
 * Business Central Push Integration
 * Push POD data back to Business Central
 */

import * as admin from 'firebase-admin';
import { createBcClient } from './client';
import { getDeliveryBySourceId, updateDeliverySync } from '../../store/firestore';
import { mapPodsafeStatusToBc } from '../../util/statusMap';
import {
  PushPodRequest,
  PushPodResponse,
  PodPayload,
} from '../../types';

/**
 * Push Proof of Delivery data to Business Central
 * 
 * Updates the BC sales shipment with:
 * - POD status
 * - Completion timestamp
 * - GPS coordinates
 * - Delivery notes
 * - Signature/photos (as custom fields)
 * 
 * @param request Push POD request
 * @returns Push result
 */
export async function pushPod(request: PushPodRequest): Promise<PushPodResponse> {
  const { companyId, sourceId, status, pod } = request;

  try {
    console.log(`Pushing POD for shipment ${sourceId}`);

    // Verify delivery exists
    const delivery = await getDeliveryBySourceId(companyId, sourceId);
    if (!delivery) {
      return {
        success: false,
        error: `Delivery not found: ${sourceId}`,
      };
    }

    const client = createBcClient(companyId);
    const bcCompanyId = await getBcCompanyId(companyId);

    // Build BC update payload
    // NOTE: These field names may need customization based on your BC configuration
    // You may need to create custom fields in BC for POD data
    const bcPayload = buildBcPodPayload(status, pod);

    // Get current etag from delivery sync metadata
    const etag = delivery.sync.version;

    // PATCH the shipment with retry on 412 (etag conflict)
    const endpoint = `companies(${bcCompanyId})/salesShipments(${sourceId})`;
    
    try {
      await client.patch(endpoint, bcPayload, etag);

      console.log(`POD pushed successfully for ${sourceId}`);

      // Update delivery sync metadata
      await updateDeliverySync(companyId, sourceId, {
        lastPushAt: admin.firestore.Timestamp.now(),
        lastPushError: undefined,
      });

      return {
        success: true,
        message: 'POD data pushed to Business Central successfully',
      };
    } catch (error) {
      // Handle 412 Precondition Failed (etag mismatch)
      if ((error as Error).message.includes('modified')) {
        console.warn('Etag mismatch, refetching and retrying...');

        // Refetch shipment to get latest etag
        const latestShipment = await client.get<any>(endpoint);
        const latestEtag = latestShipment['@odata.etag'];

        // Retry with latest etag
        await client.patch(endpoint, bcPayload, latestEtag);

        // Update sync metadata with new etag
        await updateDeliverySync(companyId, sourceId, {
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
  } catch (error) {
    const errorMsg = (error as Error).message;
    console.error('Push POD failed:', errorMsg);

    // Update delivery with error
    try {
      await updateDeliverySync(companyId, sourceId, {
        lastPushError: errorMsg,
      });
    } catch (updateError) {
      console.error('Failed to update delivery sync error:', updateError);
    }

    return {
      success: false,
      error: errorMsg,
    };
  }
}

/**
 * Build BC-compatible POD payload
 * 
 * NOTE: Field names here are illustrative. You'll need to customize these
 * based on your actual Business Central configuration. These may be:
 * - Custom fields you've added to the Sales Shipment table
 * - Standard BC fields
 * - Extensions from AppSource
 * 
 * Common approaches:
 * 1. Custom fields: PODSafe_Status, PODSafe_CompletedAt, etc.
 * 2. Standard fields: External Document No, Description
 * 3. Document attachments API for photos/signatures
 */
function buildBcPodPayload(status: string, pod: PodPayload): Record<string, any> {
  const bcStatus = mapPodsafeStatusToBc(status as any);

  const payload: Record<string, any> = {
    // Custom POD fields (customize these based on your BC setup)
    PODSafe_Status: bcStatus,
    PODSafe_CompletedAt: pod.completedAt,
    PODSafe_DeliveryNote: pod.note || '',
  };

  // Add GPS coordinates if available
  if (pod.gpsLat !== undefined && pod.gpsLng !== undefined) {
    payload.PODSafe_GPSLatitude = pod.gpsLat;
    payload.PODSafe_GPSLongitude = pod.gpsLng;
  }

  // Add signature if available
  if (pod.signature) {
    payload.PODSafe_SignatureData = pod.signature;
  }

  // File attachments are typically handled via separate BC Document Attachments API
  // Example: POST /companies({id})/attachments
  // This would require additional implementation

  return payload;
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
 * Validate push POD request
 */
export function validatePushPodRequest(request: any): request is PushPodRequest {
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

/**
 * Upload POD attachment to Business Central
 * 
 * Uses BC Document Attachments API to upload photos/signatures
 * This is a separate operation from updating shipment fields
 * 
 * @param companyId PODSafe company ID
 * @param sourceId BC shipment ID
 * @param file File to upload
 */
export async function uploadPodAttachment(
  companyId: string,
  sourceId: string,
  file: {
    fileName: string;
    fileType: string;
    content: string; // Base64 encoded
  }
): Promise<void> {
  const client = createBcClient(companyId);
  const bcCompanyId = await getBcCompanyId(companyId);

  // BC Document Attachments API endpoint
  const endpoint = `companies(${bcCompanyId})/attachments`;

  const payload = {
    parentId: sourceId,
    parentType: 'Sales Shipment', // Or appropriate document type
    fileName: file.fileName,
    attachmentContent: file.content, // Base64
  };

  await client.post(endpoint, payload);

  console.log(`Uploaded attachment ${file.fileName} for shipment ${sourceId}`);
}
