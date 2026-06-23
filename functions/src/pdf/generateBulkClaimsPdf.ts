/**
 * Server-side port of lib/services/bulk_claims_pdf_service.dart (verified against
 * source on 2026-06-23). The Dart version generated one PDF per claim on-device with
 * the `pdf` package and downloaded them as a ZIP; here the same layout is rebuilt with
 * pdfkit server-side, the ZIP is stored once in Storage, and a download URL is returned.
 *
 * Claims live in the `companies/{companyId}/claims/{claimId}` subcollection (matches
 * claimRepository.ts and the Dart source — NOT consolidated like top-level `pods`).
 *
 * Security (stronger than the Dart client-side original): the caller must be an
 * authenticated, active admin of the company. Each claimId is re-read server-side
 * from the caller's own company collection, so a claimId from another company simply
 * isn't found and is skipped — it can never be fabricated into the export.
 *
 * Deviation: a single broken image no longer aborts the whole ZIP (same precedent as
 * generatePodPdf) — failed fetches are omitted per-file.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import PDFDocument from 'pdfkit';
import JSZip from 'jszip';
import { randomUUID } from 'crypto';
import {
  fetchImageBytes,
  normalizeRegistration,
  drawSectionHeader,
  drawInfoRows,
  drawImageCentered,
  formatTimestamp,
} from './generatePodPdf';

const db = admin.firestore();
const MAX_CLAIMS = 50;

interface GenerateBulkClaimsPdfData {
  claimIds: string[];
}

function sanitizeName(raw: string, fallback: string): string {
  const cleaned = String(raw ?? '').replace(/[^A-Za-z0-9_-]/g, '').trim();
  return cleaned.length > 0 ? cleaned : fallback;
}

/**
 * Dart stored claim `type`/`status` as enum values whose `.toString()` was
 * `ClaimType.damage`-style; the PDF printed `.split('.').last`. Firestore may store
 * either the bare string ('damage') or the dotted form. Reproduce the same behaviour.
 */
function enumLabel(value: unknown): string {
  if (value === null || value === undefined) return 'N/A';
  const str = String(value);
  const dot = str.lastIndexOf('.');
  return dot >= 0 ? str.slice(dot + 1) : str;
}

interface ClaimPdfInput {
  claimId: string;
  claim: Record<string, any>;
  delivery?: Record<string, any> | undefined;
  driver?: Record<string, any> | undefined;
  vehicle?: Record<string, any> | undefined;
  company?: Record<string, any> | undefined;
  photoBytesList: (Buffer | null)[];
  documentBytesList: (Buffer | null)[];
  documentMetadata: Array<{ type?: string }>;
  customerSignatureBytes: Buffer | null;
  approvalSignatureBytes: Buffer | null;
  logoBytes: Buffer | null;
}

async function buildClaimPdfBuffer(input: ClaimPdfInput): Promise<Buffer> {
  const {
    claimId, claim, delivery, driver, vehicle, company,
    photoBytesList, documentBytesList, documentMetadata,
    customerSignatureBytes, approvalSignatureBytes, logoBytes,
  } = input;

  const doc = new PDFDocument({ size: 'A4', margin: 40, bufferPages: true });
  const chunks: Buffer[] = [];
  doc.on('data', (chunk: Buffer) => chunks.push(chunk));
  const donePromise = new Promise<Buffer>((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });

  const pageWidth = doc.page.width - doc.page.margins.left - doc.page.margins.right;
  const generatedAt = new Date();

  // Header with Logo and Company Info
  if (logoBytes) {
    try {
      doc.image(logoBytes, doc.page.margins.left, doc.y, { fit: [60, 60] });
    } catch {
      // unrenderable logo, skip
    }
  }
  const headerTextX = logoBytes ? doc.page.margins.left + 75 : doc.page.margins.left;
  const headerTextWidth = pageWidth - (logoBytes ? 75 : 0);
  let headerY = doc.y;
  if (company?.name) {
    doc.font('Helvetica-Bold').fontSize(16).fillColor('#1565C0').text(company.name, headerTextX, headerY, { width: headerTextWidth });
    headerY = doc.y + 4;
  }
  doc.font('Helvetica-Bold').fontSize(14).fillColor('#212121').text('CLAIM REPORT', headerTextX, headerY, { width: headerTextWidth });
  doc.font('Helvetica-Oblique').fontSize(10).fillColor('#9E9E9E').text('Official Claim Documentation', headerTextX, doc.y + 2, { width: headerTextWidth });
  doc.y = Math.max(doc.y, doc.page.margins.top + 70);
  doc.x = doc.page.margins.left;
  doc.moveDown(0.5);
  doc.moveTo(doc.page.margins.left, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y).lineWidth(2).strokeColor('#1565C0').stroke();
  doc.moveDown(0.5);

  // Claim ID and date
  doc.font('Helvetica-Bold').fontSize(11).fillColor('#000000').text(`Claim ID: ${claimId}`, doc.page.margins.left, doc.y, { continued: false, width: pageWidth / 2 });
  doc.font('Helvetica').fontSize(10).fillColor('#000000').text(`Generated: ${formatTimestamp(generatedAt)}`, doc.page.margins.left + pageWidth / 2, doc.y - doc.currentLineHeight(), { align: 'right', width: pageWidth / 2 });
  doc.moveDown(1);

  // Claim Information
  drawSectionHeader(doc, 'Claim Information');
  drawInfoRows(doc, [
    { label: 'Invoice Number', value: claim.invoiceNumber ?? 'N/A' },
    { label: 'Claim Type', value: enumLabel(claim.type) },
    { label: 'Status', value: enumLabel(claim.status) },
    { label: 'Claim Amount', value: `ZAR ${claim.claimAmount ?? '0.00'}` },
  ]);
  doc.moveDown(0.5);

  // Customer Information
  drawSectionHeader(doc, 'Customer Information');
  drawInfoRows(doc, [
    { label: 'Customer Name', value: claim.customerName ?? 'N/A' },
    { label: 'Customer Number', value: claim.customerAccountNumber ?? 'N/A' },
    { label: 'Customer Address', value: delivery?.customerAddress ?? 'N/A' },
    { label: 'Customer Phone', value: delivery?.customerPhone ?? 'N/A' },
  ]);
  doc.moveDown(0.5);

  // Driver Information
  drawSectionHeader(doc, 'Driver Information');
  drawInfoRows(doc, [
    { label: 'Driver Name', value: driver?.displayName ?? driver?.fullName ?? claim.driverName ?? 'N/A' },
    { label: 'Driver Phone', value: driver?.phoneNumber ?? 'N/A' },
    { label: 'License Number', value: driver?.licenseNumber ?? 'N/A' },
  ]);
  doc.moveDown(0.5);

  // Order Details
  drawSectionHeader(doc, 'Order Details');
  drawInfoRows(doc, [
    { label: 'Order Number', value: delivery?.orderNumber ?? 'N/A' },
    { label: 'Invoice Total', value: `${delivery?.currency ?? 'ZAR'} ${delivery?.invoiceTotal ?? 'N/A'}` },
    { label: 'Delivery Date', value: formatTimestamp(delivery?.scheduledDate) },
  ]);
  doc.moveDown(0.5);

  // Vehicle Information
  drawSectionHeader(doc, 'Vehicle Information');
  drawInfoRows(doc, [
    { label: 'Vehicle Registration', value: delivery?.vehicleUsed ?? 'N/A' },
    { label: 'Make', value: (vehicle?.make as string) ?? 'N/A' },
    { label: 'Model', value: (vehicle?.model as string) ?? 'N/A' },
  ]);
  doc.moveDown(0.5);

  // GPS Location
  if (claim.gpsLocation && typeof claim.gpsLocation === 'object') {
    const gps = claim.gpsLocation as { latitude?: number; longitude?: number; accuracy?: number };
    drawSectionHeader(doc, 'GPS Location');
    drawInfoRows(doc, [
      { label: 'Latitude', value: String(gps.latitude ?? 'N/A') },
      { label: 'Longitude', value: String(gps.longitude ?? 'N/A') },
      { label: 'Accuracy', value: `${typeof gps.accuracy === 'number' ? gps.accuracy.toFixed(1) : 'N/A'} meters` },
    ]);
    doc.moveDown(0.5);
  }

  // Claim Description
  drawSectionHeader(doc, 'Claim Description');
  doc.font('Helvetica').fontSize(12).fillColor('#000000').text(claim.description ?? 'No description provided', { width: pageWidth });
  doc.moveDown(0.8);

  // Timeline
  drawSectionHeader(doc, 'Timeline');
  drawInfoRows(doc, [
    { label: 'Created', value: formatTimestamp(claim.createdAt) },
    { label: 'Last Updated', value: formatTimestamp(claim.updatedAt) },
  ]);
  doc.moveDown(0.5);

  // Resolution Notes (if available)
  if (typeof claim.resolutionNotes === 'string' && claim.resolutionNotes.length > 0) {
    drawSectionHeader(doc, 'Resolution Notes');
    doc.font('Helvetica').fontSize(12).fillColor('#000000').text(claim.resolutionNotes, { width: pageWidth });
    doc.moveDown(0.5);
  }

  // Evidence — Customer Signature
  if (customerSignatureBytes) {
    drawSectionHeader(doc, 'Customer Signature');
    drawImageCentered(doc, customerSignatureBytes, 300, 150);
  }

  // Evidence — Approval Signature
  if (approvalSignatureBytes) {
    drawSectionHeader(doc, 'Approval Signature');
    drawImageCentered(doc, approvalSignatureBytes, 300, 150);
  }

  // Footer
  doc.moveDown(0.5);
  doc.moveTo(doc.page.margins.left, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y).lineWidth(1).strokeColor('#E0E0E0').stroke();
  doc.moveDown(0.5);
  doc.font('Helvetica-Oblique').fontSize(10).fillColor('#9E9E9E').text(`This is an official Claim document. Document ID: ${claimId}`, { align: 'center' });

  // Full-page claim photos
  const validPhotos = photoBytesList.filter((b): b is Buffer => b !== null);
  validPhotos.forEach((bytes, index) => {
    doc.addPage();
    doc.rect(doc.page.margins.left, doc.y, pageWidth, 30).fill('#E3F2FD');
    doc.fillColor('#0D47A1').font('Helvetica-Bold').fontSize(14).text(
      `Claim Photo ${index + 1} of ${validPhotos.length}`,
      doc.page.margins.left, doc.y - 22, { width: pageWidth, align: 'center' },
    );
    doc.moveDown(1.5);
    try {
      doc.image(bytes, doc.page.margins.left, doc.y, { fit: [pageWidth, doc.page.height - doc.y - doc.page.margins.bottom], align: 'center' });
    } catch (error) {
      console.warn('generateBulkClaimsPdf: skipping unrenderable photo', (error as Error).message);
    }
  });

  // Full-page scanned documents
  const validDocuments = documentBytesList.filter((b): b is Buffer => b !== null);
  validDocuments.forEach((bytes, index) => {
    doc.addPage();
    doc.rect(doc.page.margins.left, doc.y, pageWidth, 30).fill('#E8F5E9');
    const docType = documentMetadata[index]?.type;
    doc.fillColor('#1B5E20').font('Helvetica-Bold').fontSize(14).text(
      `Scanned Document ${index + 1} of ${validDocuments.length}${docType ? ` — ${docType}` : ''}`,
      doc.page.margins.left, doc.y - 22, { width: pageWidth, align: 'center' },
    );
    doc.moveDown(1.5);
    try {
      doc.image(bytes, doc.page.margins.left, doc.y, { fit: [pageWidth, doc.page.height - doc.y - doc.page.margins.bottom], align: 'center' });
    } catch (error) {
      console.warn('generateBulkClaimsPdf: skipping unrenderable document', (error as Error).message);
    }
  });

  doc.end();
  return donePromise;
}

export const generateBulkClaimsPdf = functions.https.onCall(async (data: GenerateBulkClaimsPdfData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to export claims.');
  }
  const claimIds: string[] = Array.isArray(data?.claimIds) ? data.claimIds.filter((id): id is string => typeof id === 'string' && id.trim().length > 0) : [];
  if (claimIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'claimIds must be a non-empty array.');
  }
  if (claimIds.length > MAX_CLAIMS) {
    throw new functions.https.HttpsError('invalid-argument', `Too many claims requested (${claimIds.length}); limit is ${MAX_CLAIMS} per export.`);
  }

  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  const caller = callerDoc.data();
  if (!callerDoc.exists || !caller || caller.isActive !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Active user account required.');
  }
  if (caller.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Administrator role required to bulk-export claims.');
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

  for (const claimId of claimIds) {
    try {
      // Claims are company-scoped: read from the caller's own company collection, so a
      // foreign claimId simply isn't found and is skipped — it can't be fabricated in.
      const claimDoc = await db.collection('companies').doc(companyId).collection('claims').doc(claimId).get();
      if (!claimDoc.exists) { skipped++; continue; }
      const claim = claimDoc.data()!;

      // Fetch delivery info if deliveryId exists
      let delivery: Record<string, any> | undefined;
      if (typeof claim.deliveryId === 'string' && claim.deliveryId.length > 0) {
        const deliveryDoc = await db.collection('deliveries').doc(claim.deliveryId).get();
        delivery = deliveryDoc.data();
      }

      // Fetch driver information
      let driver: Record<string, any> | undefined;
      if (typeof claim.driverId === 'string' && claim.driverId.length > 0) {
        const driverDoc = await db.collection('users').doc(claim.driverId).get();
        driver = driverDoc.data();
      }

      // Fetch vehicle information (Phase 1 enhancement in the Dart source)
      let vehicle: Record<string, any> | undefined;
      if (delivery?.vehicleUsed) {
        const vehicleSnapshot = await db
          .collection('companies').doc(companyId).collection('vehicles')
          .where('registration', '==', normalizeRegistration(delivery.vehicleUsed))
          .limit(1)
          .get();
        vehicle = vehicleSnapshot.empty ? undefined : vehicleSnapshot.docs[0].data();
      }

      const photoUrls: string[] = Array.isArray(claim.photoUrls) ? claim.photoUrls.filter((u): u is string => typeof u === 'string' && u.length > 0) : [];
      const documentUrls: string[] = Array.isArray(claim.documentUrls) ? claim.documentUrls.filter((u): u is string => typeof u === 'string' && u.length > 0) : [];
      const documentMetadata: Array<{ type?: string }> = Array.isArray(claim.documentMetadata) ? claim.documentMetadata : [];

      const [photoBytesList, documentBytesList, customerSignatureBytes, approvalSignatureBytes, logoBytes] = await Promise.all([
        Promise.all(photoUrls.map(fetchImageBytes)),
        Promise.all(documentUrls.map(fetchImageBytes)),
        fetchImageBytes(claim.customerSignatureUrl),
        fetchImageBytes(claim.signatureUrl),
        fetchImageBytes(company?.logoUrl),
      ]);

      const pdfBuffer = await buildClaimPdfBuffer({
        claimId, claim, delivery, driver, vehicle, company,
        photoBytesList, documentBytesList, documentMetadata,
        customerSignatureBytes, approvalSignatureBytes, logoBytes,
      });

      const baseName = sanitizeName(claim.invoiceNumber ?? claimId, claimId);
      zip.file(`Claim_${baseName}.pdf`, pdfBuffer);
      included++;
    } catch (error) {
      console.warn('generateBulkClaimsPdf: skipping claim due to error', claimId, (error as Error).message);
      skipped++;
    }
  }

  if (included === 0) {
    throw new functions.https.HttpsError('not-found', 'No claims could be exported (none found in your company, or all fetches failed).');
  }

  const zipBuffer = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
  const bucket = admin.storage().bucket();
  const filePath = `companies/${companyId}/exports/claims_${Date.now()}.zip`;
  const file = bucket.file(filePath);
  const downloadToken = randomUUID();
  await file.save(zipBuffer, {
    metadata: {
      contentType: 'application/zip',
      metadata: { firebaseStorageDownloadTokens: downloadToken },
    },
  });
  const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media&token=${downloadToken}`;

  return { success: true, downloadUrl, included, skipped };
});