/**
 * Firebase Cloud Functions - Business Central Integration
 * Main entry point for all BC-related functions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Import configuration and validate
// Import handlers
import * as bcAuth from './auth/bcAuth';
import { bcApiCall, bcAuthenticate, bcTestConnection } from './auth/bcCallables';
import { pullShipments, validatePullRequest } from './integrations/businessCentral/pull';
import { pushPod, validatePushPodRequest } from './integrations/businessCentral/push';
import { createCompanyWithAdmin } from './createCompanyWithAdmin';

// ==================== SELF-SERVICE COMPANY REGISTRATION ====================

/**
 * Create a new company with admin user - enables self-service onboarding
 * POST /createCompanyWithAdmin
 * 
 * Request body:
 * {
 *   "companyName": "Company Name",
 *   "adminName": "Admin Full Name",
 *   "email": "admin@example.com",
 *   "password": "secure_password"
 * }
 */
export { createCompanyWithAdmin };

// ==================== OAUTH ENDPOINTS ====================

/**
 * Initiate Business Central OAuth flow
 * GET /bcOAuthRedirect?companyId=xxx
 */
export const bcOAuthRedirect = bcAuth.redirect;

/**
 * Handle OAuth callback from Microsoft
 * GET /bcOAuthCallback?code=xxx&state=yyy
 */
export const bcOAuthCallback = bcAuth.callback;

export { bcAuthenticate, bcApiCall, bcTestConnection };

// ==================== DATA SYNC ENDPOINTS ====================

/**
 * Pull sales shipments from Business Central
 * POST /bcPullShipments
 * 
 * Request body:
 * {
 *   "companyId": "podsafe-company-id",
 *   "since": "2025-10-01T00:00:00Z",  // Optional: incremental sync
 *   "limit": 100                       // Optional: max records
 * }
 * 
 * Response:
 * {
 *   "success": true,
 *   "created": 5,
 *   "updated": 3,
 *   "skipped": 2,
 *   "errors": []
 * }
 */
export const bcPullShipments = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Only accept POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // Validate request
    if (!validatePullRequest(req.body)) {
      res.status(400).json({ error: 'Invalid request body' });
      return;
    }

    await requireCompanyAdmin(req, req.body.companyId);

    console.log('Pull request:', req.body);

    // Execute pull
    const result = await pullShipments(req.body);

    res.status(200).json(result);
  } catch (error) {
    console.error('Pull shipments error:', error);
    if (error instanceof HttpRequestError) {
      res.status(error.statusCode).json({ success: false, error: error.message });
      return;
    }
    res.status(500).json({
      success: false,
      error: (error as Error).message,
      created: 0,
      updated: 0,
      skipped: 0,
      errors: [(error as Error).message],
    });
  }
});

/**
 * Push Proof of Delivery to Business Central
 * POST /bcPushPod
 * 
 * Request body:
 * {
 *   "companyId": "podsafe-company-id",
 *   "sourceId": "bc-shipment-guid",
 *   "status": "DELIVERED",
 *   "pod": {
 *     "completedAt": "2025-10-26T14:30:00Z",
 *     "gpsLat": 47.6062,
 *     "gpsLng": -122.3321,
 *     "note": "Delivered to reception",
 *     "signature": "base64-encoded-signature"
 *   }
 * }
 * 
 * Response:
 * {
 *   "success": true,
 *   "message": "POD data pushed successfully"
 * }
 */
export const bcPushPod = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Only accept POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // Validate request
    if (!validatePushPodRequest(req.body)) {
      res.status(400).json({
        success: false,
        error: 'Invalid request body',
      });
      return;
    }

    await requireCompanyAdmin(req, req.body.companyId);

    console.log('Push POD request:', {
      companyId: req.body.companyId,
      sourceId: req.body.sourceId,
      status: req.body.status,
    });

    // Execute push
    const result = await pushPod(req.body);

    const statusCode = result.success ? 200 : 500;
    res.status(statusCode).json(result);
  } catch (error) {
    console.error('Push POD error:', error);
    if (error instanceof HttpRequestError) {
      res.status(error.statusCode).json({ success: false, error: error.message });
      return;
    }
    res.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

// ==================== SCHEDULED SYNC ====================

/**
 * Scheduled function to pull shipments for all connected companies
 * Runs daily at 2 AM UTC
 * 
 * To enable: Deploy and configure in Firebase Console
 */
export const bcScheduledPull = functions.pubsub
  .schedule('0 2 * * *') // Daily at 2 AM UTC
  .timeZone('UTC')
  .onRun(async (_context) => {
    console.log('Starting scheduled BC pull for all companies');

    try {
      // Get all companies with BC integration
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
          // Pull shipments from last 7 days
          const since = new Date();
          since.setDate(since.getDate() - 7);

          const result = await pullShipments({
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
        } catch (error) {
          console.error(`Failed to pull for company ${companyId}:`, error);
          results.push({
            companyId,
            success: false,
            error: (error as Error).message,
          });
        }
      }

      console.log('Scheduled pull complete:', results);
      return results;
    } catch (error) {
      console.error('Scheduled pull failed:', error);
      throw error;
    }
  });

// ==================== FIRESTORE TRIGGERS ====================

/**
 * Firestore trigger: Auto-push POD when delivery status changes to final state
 * Triggered on: deliveries/{deliveryId} update
 */
export const bcAutoPushPod = functions.firestore
  .document('deliveries/{deliveryId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only process BC deliveries
    if (after.source !== 'BusinessCentral') {
      return null;
    }

    // Check if status changed to a final state
    const finalStates = ['DELIVERED', 'FAILED', 'PARTIAL'];
    const statusChanged = before.status !== after.status;
    const isFinalState = finalStates.includes(after.status);

    if (!statusChanged || !isFinalState) {
      return null;
    }

    console.log(`Auto-pushing POD for delivery ${context.params.deliveryId}: ${before.status} -> ${after.status}`);

    try {
      // Build POD payload from delivery data
      const podPayload = {
        completedAt: after.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
        note: `Status changed to ${after.status}`,
        // Add more fields from delivery as needed
      };

      // Push to BC
      const result = await pushPod({
        companyId: after.companyId,
        sourceId: after.sourceId,
        status: after.status,
        pod: podPayload,
      });

      if (result.success) {
        console.log('Auto-push successful:', context.params.deliveryId);
      } else {
        console.error('Auto-push failed:', result.error);
      }

      return result;
    } catch (error) {
      console.error('Auto-push POD error:', error);
      return null;
    }
  });

// ==================== UTILITY FUNCTIONS ====================

/**
 * Verify Firebase ID token (for authenticated endpoints)
 */
async function verifyFirebaseToken(req: functions.https.Request): Promise<admin.auth.DecodedIdToken> {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new HttpRequestError(401, 'Missing or invalid authorization header');
  }

  try {
    return await admin.auth().verifyIdToken(authHeader.substring('Bearer '.length));
  } catch {
    throw new HttpRequestError(401, 'Invalid or expired authentication token');
  }
}

class HttpRequestError extends Error {
  constructor(public readonly statusCode: number, message: string) {
    super(message);
  }
}

/** Ensures an HTTP BC sync request is made by an active admin of the requested tenant. */
async function requireCompanyAdmin(req: functions.https.Request, companyId: string): Promise<void> {
  const token = await verifyFirebaseToken(req);
  const userDoc = await admin.firestore().collection('users').doc(token.uid).get();
  const user = userDoc.data();

  if (!userDoc.exists || !user || user.isActive !== true) {
    throw new HttpRequestError(403, 'Active user account required');
  }
  if (user.role !== 'admin') {
    throw new HttpRequestError(403, 'Administrator access required');
  }
  if (user.companyId !== companyId) {
    throw new HttpRequestError(403, 'Cannot access another company');
  }
}

// ==================== HEALTH CHECK ====================

/**
 * Health check endpoint
 * GET /bcHealth
 */
export const bcHealth = functions.https.onRequest((_req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'PODSafe Business Central Integration',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// ==================== USER MANAGEMENT ====================

/**
 * User Management Functions - Invite-Only System
 */
export * from './auth/userManagement';

// ==================== POD PDF REPORTS ====================

/**
 * Generate a branded PDF report for a POD (Proof of Delivery), upload it to
 * Storage under pods/{deliveryId}/, and persist the download URL on the POD doc.
 */
export * from './pdf/generatePodPdf';

console.log('✅ All Cloud Functions loaded successfully');
