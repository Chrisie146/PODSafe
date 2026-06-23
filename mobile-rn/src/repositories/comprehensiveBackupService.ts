import firestore from '@react-native-firebase/firestore';
import JSZip from 'jszip';
import Papa from 'papaparse';
import Share from 'react-native-share';
import { AuthRepository } from './authRepository';

/**
 * Ported from lib/services/comprehensive_backup_service.dart (verified against source on
 * 2026-06-23) — exports all company data (deliveries, drivers, claims, PODs) as one ZIP
 * with CSVs + evidence images, then shares it and bumps the company's backup metadata.
 *
 * Deviations from the Flutter source:
 * - Uses `jszip` for archive creation (pure JS, no native module) and
 *   `react-native-share`'s share sheet (base64 data URL) instead of Dart's
 *   web-`Blob`-download/`path_provider`+`Share.shareXFiles` split — same convention as
 *   csvExportService.ts's exportToCSV().
 * - Fixed two real bugs found while porting, both pre-existing in the Dart source:
 *   1. `_addDriversToArchive` queried a top-level `drivers` collection that nothing in
 *      this app ever writes to (drivers are `users` docs with `role: 'driver'`) — grep
 *      confirmed zero writers across `lib/` and `functions/src/`, so that section always
 *      silently exported an empty CSV in production. Fixed to query `users` via
 *      `AuthRepository.getUsersByCompany(companyId, { role: 'driver' })`.
 *   2. The claims/PODs CSV column readers used stale field names that don't match the
 *      current models (`amount` instead of `claimAmount`; `customerSignature`/
 *      `approvalSignature` instead of `customerSignatureUrl`/`driverSignatureUrl`;
 *      `deliveredDate`/`driverName` don't exist on the POD model, which only has
 *      `timestamp`/`driverId`) — fixed to read the real field names so the exported CSVs
 *      are actually populated instead of silently blank.
 * - Reads raw Firestore document data directly (`doc.data()`), not through the typed
 *   Claim/PodRecord/Delivery converters, matching the Dart source's own approach for this
 *   one-off CSV-flattening use case.
 */
const authRepository = new AuthRepository();

function csvOf(rows: string[][]): Uint8Array {
  return new TextEncoder().encode(Papa.unparse(rows));
}

function cell(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (value == null) return 'N/A';
  if (value instanceof firestore.Timestamp) return value.toDate().toISOString();
  return String(value);
}

async function addImagesToArchive(zip: JSZip, imageUrls: string[], archivePath: string, onProgress: (message: string) => void): Promise<void> {
  if (imageUrls.length === 0) return;
  onProgress(`Downloading ${imageUrls.length} images...`);

  for (let i = 0; i < imageUrls.length; i++) {
    const url = imageUrls[i];
    try {
      const response = await fetch(url);
      if (!response.ok) continue;
      const buffer = await response.arrayBuffer();
      const fileName = extractImageFileName(url, i);
      zip.file(`${archivePath}${fileName}`, buffer);
    } catch {
      // Mirrors Dart: skip failed downloads, continue with the rest.
    }
  }
}

function extractImageFileName(url: string, index: number): string {
  try {
    const path = decodeURIComponent(new URL(url).pathname);
    const fileName = path.split('/').pop()?.replace(/[<>:"|?*]/g, '_');
    if (fileName && fileName.includes('.')) return fileName;
  } catch {
    // Falls through to the numbered fallback below.
  }
  return `image_${String(index).padStart(4, '0')}.jpg`;
}

async function addDeliveriesToArchive(zip: JSZip, companyId: string, onProgress: (message: string) => void): Promise<void> {
  const snapshot = await firestore().collection('deliveries').where('companyId', '==', companyId).limit(1000).get();

  const rows: string[][] = [['Invoice', 'Customer Name', 'Address', 'Phone', 'Scheduled Date', 'Driver Email', 'Status', 'Notes', 'Created Date', 'Has Images']];
  const imageUrls: string[] = [];

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const photoUrls = Array.isArray(data.photoUrls) ? (data.photoUrls as string[]) : [];
    rows.push([
      cell(data, 'invoiceNumber'),
      cell(data, 'customerName'),
      cell(data, 'customerAddress'),
      cell(data, 'customerPhone'),
      cell(data, 'scheduledDate'),
      cell(data, 'driverEmail'),
      cell(data, 'status'),
      cell(data, 'notes'),
      cell(data, 'createdAt'),
      photoUrls.length > 0 ? 'Yes' : 'No',
    ]);
    imageUrls.push(...photoUrls);
  });

  zip.file('deliveries/deliveries.csv', csvOf(rows));
  await addImagesToArchive(zip, imageUrls, 'deliveries/images/', onProgress);
  onProgress(`Added ${rows.length - 1} deliveries to backup`);
}

async function addDriversToArchive(zip: JSZip, companyId: string, onProgress: (message: string) => void): Promise<void> {
  const drivers = await authRepository.getUsersByCompany(companyId, { role: 'driver' });

  const rows: string[][] = [['Name', 'Email', 'Phone', 'License Number', 'Status', 'Approved Date', 'Created Date']];
  drivers.forEach((driver) => {
    rows.push([
      driver.fullName || 'N/A',
      driver.email || 'N/A',
      driver.phoneNumber || 'N/A',
      driver.licenseNumber || 'N/A',
      driver.approvalStatus || 'N/A',
      driver.approvedAt ? driver.approvedAt.toISOString() : 'N/A',
      driver.createdAt ? driver.createdAt.toISOString() : 'N/A',
    ]);
  });

  zip.file('drivers/drivers.csv', csvOf(rows));
  onProgress(`Added ${rows.length - 1} drivers to backup`);
}

async function addClaimsToArchive(zip: JSZip, companyId: string, onProgress: (message: string) => void): Promise<void> {
  const snapshot = await firestore().collection('companies').doc(companyId).collection('claims').limit(1000).get();

  const rows: string[][] = [
    ['Claim ID', 'Invoice', 'Driver Name', 'Type', 'Description', 'Status', 'Amount (ZAR)', 'Created Date', 'Updated Date', 'Has Evidence'],
  ];
  const imageUrls: string[] = [];

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const photoUrls = Array.isArray(data.photoUrls) ? (data.photoUrls as string[]) : [];
    const hasEvidence = photoUrls.length > 0 || Boolean(data.customerSignatureUrl) || Boolean(data.driverSignatureUrl);

    rows.push([
      doc.id,
      cell(data, 'invoiceNumber'),
      cell(data, 'driverName'),
      cell(data, 'type'),
      cell(data, 'description'),
      cell(data, 'status'),
      data.claimAmount != null ? Number(data.claimAmount).toFixed(2) : '0.00',
      cell(data, 'createdAt'),
      cell(data, 'updatedAt'),
      hasEvidence ? 'Yes' : 'No',
    ]);

    imageUrls.push(...photoUrls);
    if (data.customerSignatureUrl) imageUrls.push(String(data.customerSignatureUrl));
    if (data.driverSignatureUrl) imageUrls.push(String(data.driverSignatureUrl));
  });

  zip.file('claims/claims.csv', csvOf(rows));
  await addImagesToArchive(zip, imageUrls, 'claims/images/', onProgress);
  onProgress(`Added ${rows.length - 1} claims to backup`);
}

async function addPodsToArchive(zip: JSZip, companyId: string, onProgress: (message: string) => void): Promise<void> {
  const snapshot = await firestore().collection('pods').where('companyId', '==', companyId).limit(1000).get();

  const rows: string[][] = [['POD ID', 'Invoice', 'Customer Name', 'Driver ID', 'Status', 'Timestamp', 'Created Date', 'Has Signature', 'Has Photos']];
  const imageUrls: string[] = [];

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const photoUrls = Array.isArray(data.photoUrls) ? (data.photoUrls as string[]) : [];
    const hasSignature = Boolean(data.signatureUrl);

    rows.push([
      doc.id,
      cell(data, 'invoiceNumber'),
      cell(data, 'customerName'),
      cell(data, 'driverId'),
      cell(data, 'status'),
      cell(data, 'timestamp'),
      cell(data, 'createdAt'),
      hasSignature ? 'Yes' : 'No',
      photoUrls.length > 0 ? 'Yes' : 'No',
    ]);

    imageUrls.push(...photoUrls);
    if (data.signatureUrl) imageUrls.push(String(data.signatureUrl));
  });

  zip.file('pods/pods.csv', csvOf(rows));
  await addImagesToArchive(zip, imageUrls, 'pods/images/', onProgress);
  onProgress(`Added ${rows.length - 1} PODs to backup`);
}

function readmeContent(): string {
  return `PODSafe COMPREHENSIVE BACKUP
============================

Backup Date: ${new Date().toString()}
Version: 1.0.0

CONTENTS
--------
This backup contains:
- All Deliveries (CSV + Images)
- All Drivers (CSV)
- All Claims (CSV + Evidence Images)
- All PODs (CSV + Images)

HOW TO USE
----------
1. Extract the ZIP file to a safe location
2. Open CSV files in Excel, Google Sheets, or any spreadsheet application
3. View images in images/ subfolders
4. Keep this backup file for record-keeping and disaster recovery

Questions? Contact PODSafe Support
`;
}

/** Mirrors ComprehensiveBackupService.backupAllData(). */
export async function backupAllData(companyId: string, onProgress: (message: string) => void): Promise<void> {
  onProgress('Initializing backup...');
  const zip = new JSZip();

  zip.file('README.txt', readmeContent());
  zip.file(
    'backup_info.json',
    JSON.stringify({ backup_date: new Date().toISOString(), company_id: companyId, app_version: '1.0.0', backup_type: 'comprehensive' }),
  );

  onProgress('Exporting deliveries...');
  try {
    await addDeliveriesToArchive(zip, companyId, onProgress);
  } catch {
    onProgress('Skipped deliveries (error)');
  }

  onProgress('Exporting drivers...');
  try {
    await addDriversToArchive(zip, companyId, onProgress);
  } catch {
    onProgress('Skipped drivers (error)');
  }

  onProgress('Exporting claims...');
  try {
    await addClaimsToArchive(zip, companyId, onProgress);
  } catch {
    onProgress('Skipped claims (error)');
  }

  onProgress('Exporting PODs...');
  try {
    await addPodsToArchive(zip, companyId, onProgress);
  } catch {
    onProgress('Skipped PODs (error)');
  }

  onProgress('Creating backup file...');
  const base64 = await zip.generateAsync({ type: 'base64' });

  const now = new Date();
  const pad = (n: number) => n.toString().padStart(2, '0');
  const filename = `PODSafe_Backup_${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.zip`;

  onProgress('Sharing backup...');
  await Share.open({ url: `data:application/zip;base64,${base64}`, filename, type: 'application/zip' });

  await firestore()
    .collection('companies')
    .doc(companyId)
    .update({ lastBackupDate: firestore.FieldValue.serverTimestamp(), backupCount: firestore.FieldValue.increment(1) });

  onProgress('Backup complete!');
}
