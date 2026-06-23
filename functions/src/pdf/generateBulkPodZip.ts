/**
 * Server-side port of lib/services/bulk_pod_download_service.dart (verified against
 * source on 2026-06-23). The Dart version built POD PDFs (or collected POD images)
 * on-device with the `pdf`/`archive` packages and triggered a browser download; here
 * the same work happens server-side inside a callable, the resulting ZIP is stored
 * once in Storage, and a download URL is returned to the client.
 *
 * Two modes (mirroring the Dart service's `downloadPODsAsZip` + `downloadPODImagesAsZip`):
 *  - mode: 'pdf' (default) — one POD report PDF per podId (reuses the shared
 *    `buildPodPdfBuffer` layout from generatePodPdf.ts), all zipped together.
 *  - mode: 'images' — the raw photos / customer signature / stamp image files for
 *    each POD, zipped together under a per-POD folder.
 *
 * Security (stronger than the Dart client-side original, which only trusted the
 * caller-supplied companyId): the caller must be an authenticated, active admin of
 * the company, and EVERY POD is re-read server-side and checked against the caller's
 * own companyId before it enters the archive — a podId from another company is
 * silently skipped, not included.
 *
 * Deviation: a single broken image no longer aborts the whole ZIP (same precedent as
 * generatePodPdf) — failed fetches are omitted per-file. The Dart original also
 * generated PDFs client-side per POD; here that moves server-side (same decision the
 * single-POD port already made).
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import JSZip from 'jszip';
import { randomUUID } from 'crypto';
import {
  buildPodPdfBuffer,
  fetchImageBytes,
  normalizeRegistration,
  PodPdfInput,
} from './generatePodPdf';

const db = admin.firestore();
const MAX_PODS = 50;

interface GenerateBulkPodZipData {
  podIds: string[];
  mode?: 'pdf' | 'images';
}

function sanitizeName(raw: string, fallback: string): string {
  const cleaned = String(raw ?? '').replace(/[^A-Za-z0-9_-]/g, '').trim();
  return cleaned.length > 0 ? cleaned : fallback;
}

export const generateBulkPodZip = functions.https.onCall(async (data: GenerateBulkPodZipData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to export PODs.');
  }
  const podIds: string[] = Array.isArray(data?.podIds) ? data.podIds.filter((id): id is string => typeof id === 'string' && id.trim().length > 0) : [];
  if (podIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'podIds must be a non-empty array.');
  }
  if (podIds.length > MAX_PODS) {
    throw new functions.https.HttpsError('invalid-argument', `Too many PODs requested (${podIds.length}); limit is ${MAX_PODS} per export.`);
  }
  const mode: 'pdf' | 'images' = data?.mode === 'images' ? 'images' : 'pdf';

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

  const zip = new JSZip();
  let included = 0;
  let skipped = 0;

  for (const podId of podIds) {
    try {
      const podDoc = await db.collection('pods').doc(podId).get();
      if (!podDoc.exists) { skipped++; continue; }
      const pod = podDoc.data()!;
      // Per-POD company gate: never include a POD from another company, even if the
      // caller somehow supplies its id. Silently skip rather than abort the whole export.
      if (pod.companyId !== companyId) { skipped++; continue; }

      const deliveryId = typeof pod.deliveryId === 'string' && pod.deliveryId.length > 0 ? pod.deliveryId : podId;
      const deliveryDoc = await db.collection('deliveries').doc(deliveryId).get();
      const delivery = deliveryDoc.data();

      const driverDoc = delivery?.driverId ? await db.collection('users').doc(delivery.driverId).get() : null;
      const driver = driverDoc?.data();

      let vehicle: Record<string, unknown> | undefined;
      if (delivery?.vehicleUsed) {
        const vehicleSnapshot = await db
          .collection('companies').doc(companyId).collection('vehicles')
          .where('registration', '==', normalizeRegistration(delivery.vehicleUsed))
          .limit(1)
          .get();
        vehicle = vehicleSnapshot.empty ? undefined : vehicleSnapshot.docs[0].data();
      }

      const baseName = sanitizeName(delivery?.invoiceNumber ?? delivery?.orderNumber ?? podId, podId);

      if (mode === 'pdf') {
        const photoUrls: string[] = Array.isArray(pod.photoUrls) && pod.photoUrls.length > 0
          ? pod.photoUrls
          : (pod.photoUrl ? [pod.photoUrl] : []);
        const documentUrls: string[] = Array.isArray(pod.documentUrls) ? pod.documentUrls : [];
        const documentMetadata: Array<{ type?: string }> = Array.isArray(pod.documentMetadata) ? pod.documentMetadata : [];

        const [photoBytesList, documentBytesList, signatureBytes, stampBytes, logoBytes] = await Promise.all([
          Promise.all(photoUrls.map(fetchImageBytes)),
          Promise.all(documentUrls.map(fetchImageBytes)),
          fetchImageBytes(pod.signatureUrl),
          fetchImageBytes(pod.stampPhotoUrl),
          fetchImageBytes(company?.logoUrl),
        ]);

        const input: PodPdfInput = {
          deliveryId, pod, delivery, driver, vehicle, company,
          photoBytesList, documentBytesList, documentMetadata,
          signatureBytes, stampBytes, logoBytes,
        };
        const pdfBuffer = await buildPodPdfBuffer(input);
        zip.file(`POD_${baseName}.pdf`, pdfBuffer);
      } else {
        // images mode: raw photo / signature / stamp files under a per-POD folder.
        const folder = zip.folder(`POD_${baseName}`);
        if (!folder) { skipped++; continue; }
        const photoUrls: string[] = Array.isArray(pod.photoUrls) && pod.photoUrls.length > 0
          ? pod.photoUrls
          : (pod.photoUrl ? [pod.photoUrl] : []);
        let photoIndex = 0;
        for (const url of photoUrls) {
          const bytes = await fetchImageBytes(url);
          if (bytes) {
            photoIndex++;
            const ext = url.match(/\.(png|jpe?g|webp|gif)(\?|$)/i)?.[1]?.toLowerCase() ?? 'jpg';
            folder.file(`photo_${photoIndex}.${ext}`, bytes);
          }
        }
        const sigBytes = await fetchImageBytes(pod.signatureUrl);
        if (sigBytes) folder.file('customer_signature.png', sigBytes);
        const stampBytes = await fetchImageBytes(pod.stampPhotoUrl);
        if (stampBytes) folder.file('stamp.png', stampBytes);
        if (photoIndex === 0 && !sigBytes && !stampBytes) {
          // nothing renderable for this POD — drop the empty folder
          zip.remove(`POD_${baseName}`);
          skipped++;
          continue;
        }
      }
      included++;
    } catch (error) {
      console.warn('generateBulkPodZip: skipping pod due to error', podId, (error as Error).message);
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
  const downloadToken = randomUUID();
  await file.save(zipBuffer, {
    metadata: {
      contentType: 'application/zip',
      metadata: { firebaseStorageDownloadTokens: downloadToken },
    },
  });
  const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media&token=${downloadToken}`;

  return { success: true, downloadUrl, included, skipped, mode };
});