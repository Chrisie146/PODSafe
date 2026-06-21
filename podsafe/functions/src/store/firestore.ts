/**
 * Firestore Data Access Layer
 * CRUD operations and token vault interface
 */

import * as admin from 'firebase-admin';
import { BCIntegration, DeliveryNormalized } from '../types';

const db = admin.firestore();

/**
 * Token Vault Interface
 * Abstract storage for sensitive tokens (refresh tokens, secrets)
 * 
 * In development: Store encrypted in Firestore
 * In production: Use Google Secret Manager
 */
export class TokenVault {
  /**
   * Save refresh token securely
   * @param companyId PODSafe company ID
   * @param refreshToken OAuth refresh token
   */
  async saveRefreshToken(companyId: string, refreshToken: string): Promise<string> {
    // TODO: In production, use Secret Manager
    // For now, store in a secure subcollection with encryption
    const secretId = `bc-refresh-${companyId}-${Date.now()}`;
    
    await db
      .collection('_secrets')
      .doc(secretId)
      .set({
        type: 'bc_refresh_token',
        companyId,
        value: refreshToken, // TODO: Encrypt before storing
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return secretId;
  }

  /**
   * Load refresh token
   * @param secretId Secret identifier
   */
  async loadRefreshToken(secretId: string): Promise<string | null> {
    const doc = await db.collection('_secrets').doc(secretId).get();
    
    if (!doc.exists) {
      return null;
    }

    const data = doc.data();
    // TODO: Decrypt before returning
    return data?.value || null;
  }

  /**
   * Delete refresh token
   * @param secretId Secret identifier
   */
  async deleteRefreshToken(secretId: string): Promise<void> {
    await db.collection('_secrets').doc(secretId).delete();
  }
}

/**
 * Get BC integration configuration for a company
 */
export async function getBcIntegration(companyId: string): Promise<BCIntegration | null> {
  const doc = await db
    .collection('companies')
    .doc(companyId)
    .collection('integrations')
    .doc('businessCentral')
    .get();

  if (!doc.exists) {
    return null;
  }

  return doc.data() as BCIntegration;
}

/**
 * Save BC integration configuration
 */
export async function saveBcIntegration(
  companyId: string,
  integration: Partial<BCIntegration>
): Promise<void> {
  await db
    .collection('companies')
    .doc(companyId)
    .collection('integrations')
    .doc('businessCentral')
    .set(
      {
        ...integration,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

/**
 * Delete BC integration configuration
 */
export async function deleteBcIntegration(companyId: string): Promise<void> {
  await db
    .collection('companies')
    .doc(companyId)
    .collection('integrations')
    .doc('businessCentral')
    .delete();
}

/**
 * Upsert delivery document
 * Idempotent operation based on (companyId, source, sourceId)
 * 
 * @returns 'created' | 'updated' | 'skipped'
 */
export async function upsertDelivery(
  delivery: DeliveryNormalized
): Promise<'created' | 'updated' | 'skipped'> {
  const { companyId, source, sourceId } = delivery;

  // Query for existing delivery
  const snapshot = await db
    .collection('deliveries')
    .where('companyId', '==', companyId)
    .where('source', '==', source)
    .where('sourceId', '==', sourceId)
    .limit(1)
    .get();

  if (snapshot.empty) {
    // Create new delivery
    await db.collection('deliveries').add({
      ...delivery,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return 'created';
  }

  const existingDoc = snapshot.docs[0];
  const existingData = existingDoc.data() as DeliveryNormalized;

  // Check etag version to avoid unnecessary updates
  if (
    existingData.sync.version &&
    delivery.sync.version &&
    existingData.sync.version === delivery.sync.version
  ) {
    return 'skipped';
  }

  // Update existing delivery
  await existingDoc.ref.update({
    ...delivery,
    createdAt: existingData.createdAt, // Preserve creation time
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return 'updated';
}

/**
 * Get delivery by source ID
 */
export async function getDeliveryBySourceId(
  companyId: string,
  sourceId: string
): Promise<DeliveryNormalized | null> {
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

  return snapshot.docs[0].data() as DeliveryNormalized;
}

/**
 * Update delivery sync metadata
 */
export async function updateDeliverySync(
  companyId: string,
  sourceId: string,
  syncUpdate: Partial<DeliveryNormalized['sync']>
): Promise<void> {
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

/**
 * Get all deliveries for a company (paginated)
 */
export async function getDeliveries(
  companyId: string,
  limit: number = 50,
  startAfter?: admin.firestore.DocumentSnapshot
): Promise<DeliveryNormalized[]> {
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
  return snapshot.docs.map(doc => doc.data() as DeliveryNormalized);
}
