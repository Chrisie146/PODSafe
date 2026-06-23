import Papa from 'papaparse';
import CryptoJS from 'crypto-js';
import Share from 'react-native-share';
import { Vehicle } from '../models/vehicle';
import { CatalogItem, itemCategoryDisplayName } from '../models/catalogItem';

/**
 * Ported from lib/services/csv_export_service.dart + csv_export_mobile.dart (verified
 * against source on 2026-06-22). Pure formatting helpers + CSV generation are 1:1 ports;
 * uses papaparse instead of Dart's `csv` package, matching customerImportService.ts.
 *
 * Deviation: the Dart mobile implementation silently writes the CSV to the device's
 * Downloads/Documents directory via path_provider and returns the file path — there's
 * no share sheet, no user-visible confirmation of *where* the file landed beyond a toast.
 * This port uses react-native-share's native share sheet instead (passing the CSV as a
 * base64 data URL, no temp file needed), which lets the user actually choose where the
 * file goes (Save to Files, share via email, etc.) — strictly more discoverable than a
 * silent background write, and avoids needing react-native-fs for a one-off write.
 * exportToCSV() therefore returns void, not a file path.
 */
export async function exportToCSV(filename: string, headers: string[], rows: unknown[][]): Promise<void> {
  const csv = Papa.unparse([headers, ...rows]);
  const csvWithBom = `﻿${csv}`;
  const base64 = CryptoJS.enc.Base64.stringify(CryptoJS.enc.Utf8.parse(csvWithBom));

  await Share.open({
    url: `data:text/csv;base64,${base64}`,
    filename: `${filename}.csv`,
    type: 'text/csv',
  });
}

/** Mirrors CSVExportService.formatDate(). */
export function formatDate(date?: Date): string {
  if (!date) return 'N/A';
  return date.toLocaleDateString(undefined, { month: 'short', day: '2-digit', year: 'numeric' });
}

/** Mirrors CSVExportService.formatDateTime(). */
export function formatDateTime(date?: Date): string {
  if (!date) return 'N/A';
  const time = date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  return `${formatDate(date)} ${time}`;
}

/** Mirrors CSVExportService.cleanText(). */
export function cleanText(text?: string): string {
  if (!text) return '';
  return text.replace(/\n/g, ' ').replace(/\r/g, ' ').replace(/ {2}/g, ' ').trim();
}

/** Mirrors CSVExportService.formatPhone(). */
export function formatPhone(phone?: string): string {
  return phone || 'N/A';
}

/** Mirrors CSVExportService.formatCurrency(). */
export function formatCurrency(amount?: number): string {
  return amount == null ? '$0.00' : `$${amount.toFixed(2)}`;
}

/** Mirrors CSVExportService.formatStatus(). */
export function formatStatus(status?: string): string {
  return status ? status.toUpperCase() : 'N/A';
}

/** Mirrors CSVExportService.getTimestamp(). */
export function getTimestamp(): string {
  const now = new Date();
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
}

/** Mirrors CSVExportService.generateFilename(). */
export function generateFilename(baseName: string): string {
  return `${baseName}_${getTimestamp()}`;
}

// ============================================================================
// DRIVER EXPORT
// ============================================================================

/** Mirrors CSVExportService.exportDrivers(). */
export async function exportDrivers(drivers: Record<string, unknown>[], filterStatus?: string, searchQuery?: string): Promise<void> {
  const headers = ['Name', 'Email', 'Phone', 'Status', 'Registration Date', 'Last Active', 'Total Deliveries', 'Approved By'];

  const rows = drivers.map((driver) => [
    cleanText((driver.name as string) ?? 'N/A'),
    cleanText((driver.email as string) ?? 'N/A'),
    formatPhone(driver.phone as string | undefined),
    formatStatus((driver.approvalStatus as string) ?? 'pending'),
    formatDateTime(driver.createdAt as Date | undefined),
    formatDateTime(driver.lastActive as Date | undefined),
    String(driver.totalDeliveries ?? 0),
    cleanText((driver.approvedBy as string) ?? 'N/A'),
  ]);

  let filename = 'drivers_export';
  if (filterStatus && filterStatus !== 'all') filename += `_${filterStatus.toLowerCase()}`;
  if (searchQuery) filename += '_filtered';

  await exportToCSV(generateFilename(filename), headers, rows);
}

// ============================================================================
// DELIVERY EXPORT
// ============================================================================

/** Mirrors CSVExportService.exportDeliveries(). */
export async function exportDeliveries(deliveries: Record<string, unknown>[], filterStatus?: string, filterDate?: string): Promise<void> {
  const headers = [
    'Tracking Number',
    'Customer Name',
    'Customer Phone',
    'Delivery Address',
    'Scheduled Date',
    'Invoice Date',
    'Status',
    'Driver Name',
    'Notes',
    'Created Date',
    'Completed Date',
  ];

  const rows = deliveries.map((delivery) => [
    cleanText((delivery.trackingNumber as string) ?? 'N/A'),
    cleanText((delivery.customerName as string) ?? 'N/A'),
    formatPhone(delivery.customerPhone as string | undefined),
    cleanText((delivery.address as string) ?? 'N/A'),
    formatDateTime(delivery.scheduledDate as Date | undefined),
    formatDateTime(delivery.invoiceDate as Date | undefined),
    formatStatus((delivery.status as string) ?? 'pending'),
    cleanText((delivery.driverName as string) ?? 'Unassigned'),
    cleanText((delivery.notes as string) ?? ''),
    formatDateTime(delivery.createdAt as Date | undefined),
    formatDateTime(delivery.completedAt as Date | undefined),
  ]);

  let filename = 'deliveries_export';
  if (filterStatus && filterStatus !== 'all') filename += `_${filterStatus.toLowerCase()}`;
  if (filterDate && filterDate !== 'all') filename += `_${filterDate.toLowerCase()}`;

  await exportToCSV(generateFilename(filename), headers, rows);
}

// ============================================================================
// CLAIM EXPORT
// ============================================================================

/** Mirrors CSVExportService.exportClaims(). */
export async function exportClaims(claims: Record<string, unknown>[], filterStatus?: string, filterType?: string): Promise<void> {
  const headers = ['Claim ID', 'Driver Name', 'Claim Type', 'Description', 'Status', 'Created Date', 'Updated Date', 'Resolution Notes', 'Amount'];

  const rows = claims.map((claim) => [
    cleanText((claim.id as string) ?? 'N/A'),
    cleanText((claim.driverName as string) ?? 'N/A'),
    cleanText((claim.type as string) ?? 'N/A'),
    cleanText((claim.description as string) ?? 'N/A'),
    formatStatus((claim.status as string) ?? 'pending'),
    formatDateTime(claim.createdAt as Date | undefined),
    formatDateTime(claim.updatedAt as Date | undefined),
    cleanText((claim.resolutionNotes as string) ?? 'N/A'),
    formatCurrency(claim.claimAmount as number | undefined),
  ]);

  let filename = 'claims_export';
  if (filterStatus && filterStatus !== 'all') filename += `_${filterStatus.toLowerCase()}`;
  if (filterType && filterType !== 'all') filename += `_${filterType.toLowerCase()}`;

  await exportToCSV(generateFilename(filename), headers, rows);
}

// ============================================================================
// POD EXPORT
// ============================================================================

/** Mirrors CSVExportService.exportPODs(). */
export async function exportPODs(pods: Record<string, unknown>[], filterStatus?: string): Promise<void> {
  const headers = [
    'Delivery ID',
    'Tracking Number',
    'Customer Name',
    'Delivery Address',
    'Delivered Date',
    'Status',
    'Has Signature',
    'Has Photo',
    'Recipient Name',
    'Notes',
  ];

  const rows = pods.map((pod) => {
    const photoUrls = pod.photoUrls as string[] | undefined;
    const hasPhoto = (photoUrls?.length ?? 0) > 0 || Boolean(pod.photoUrl);
    return [
      cleanText((pod.deliveryId as string) ?? 'N/A'),
      cleanText((pod.trackingNumber as string) ?? 'N/A'),
      cleanText((pod.customerName as string) ?? 'N/A'),
      cleanText((pod.deliveryAddress as string) ?? 'N/A'),
      formatDateTime(pod.timestamp as Date | undefined),
      formatStatus((pod.status as string) ?? 'delivered'),
      pod.signatureUrl ? 'Yes' : 'No',
      hasPhoto ? 'Yes' : 'No',
      cleanText((pod.recipientName as string) ?? 'N/A'),
      cleanText((pod.notes as string) ?? ''),
    ];
  });

  let filename = 'pods_export';
  if (filterStatus && filterStatus !== 'all') filename += `_${filterStatus.toLowerCase()}`;

  await exportToCSV(generateFilename(filename), headers, rows);
}

// ============================================================================
// ANALYTICS EXPORT
// ============================================================================

/** Mirrors CSVExportService.exportAnalyticsSummary(). */
export async function exportAnalyticsSummary(summary: Record<string, unknown>, startDate: Date, endDate: Date): Promise<void> {
  const headers = ['Metric', 'Value'];

  const rows = [
    ['Report Period', `${formatDate(startDate)} - ${formatDate(endDate)}`],
    ['Total Deliveries', String(summary.totalDeliveries ?? 0)],
    ['Completed Deliveries', String(summary.completedDeliveries ?? 0)],
    ['Pending Deliveries', String(summary.pendingDeliveries ?? 0)],
    ['In Transit Deliveries', String(summary.inTransitDeliveries ?? 0)],
    ['Completion Rate', `${((summary.completionRate as number) ?? 0).toFixed(1)}%`],
    ['Active Drivers', String(summary.activeDrivers ?? 0)],
    ['Total Drivers', String(summary.totalDrivers ?? 0)],
    ['Total Claims', String(summary.totalClaims ?? 0)],
    ['Pending Claims', String(summary.pendingClaims ?? 0)],
    ['Total PODs', String(summary.totalPODs ?? 0)],
  ];

  await exportToCSV(generateFilename('analytics_summary'), headers, rows);
}

// ============================================================================
// VEHICLE EXPORT
// ============================================================================

/**
 * New — no Dart CSVExportService.exportVehicles() ever existed; vehicle_management_desktop.dart
 * built a CSV via a StringBuffer in `_exportToCsv()` that was never written to disk or shared
 * anywhere (dead code — confirmed by direct read, see vault Risk Register). This follows the
 * same per-entity export convention as exportDrivers/exportDeliveries/exportClaims/exportPODs
 * instead of repeating that bug. Takes `Vehicle[]` directly (rather than the other exporters'
 * `Record<string, unknown>[]`) since a typed model already exists here — no need for the loose
 * shape those functions use.
 */
export async function exportVehicles(vehicles: Vehicle[]): Promise<void> {
  const headers = ['Registration', 'Make', 'Model', 'Plate', 'Status', 'Deliveries', 'Last Used', 'Created'];

  const rows = vehicles.map((vehicle) => [
    cleanText(vehicle.registration ?? 'N/A'),
    cleanText(vehicle.make ?? ''),
    cleanText(vehicle.model ?? ''),
    cleanText(vehicle.licensePlate ?? ''),
    formatStatus(vehicle.status ?? 'active'),
    String(vehicle.totalDeliveries ?? 0),
    formatDateTime(vehicle.lastUsedAt),
    formatDateTime(vehicle.createdAt),
  ]);

  await exportToCSV(generateFilename('vehicles_export'), headers, rows);
}

// ============================================================================
// CATALOG ITEM EXPORT
// ============================================================================

/**
 * New — no Dart CSVExportService.exportCatalogItems() ever existed; item_catalog_desktop.dart's
 * `_exportToCsv()` builds a CSV StringBuffer and then only shows a `SnackBar` ("CSV ready: N
 * items") — the buffer is never written to disk or shared anywhere (dead code, same pattern as
 * vehicle_management_desktop's bug — see vault Risk Register). Wired for real here.
 */
export async function exportCatalogItems(items: CatalogItem[]): Promise<void> {
  const headers = ['Description', 'SKU', 'Category', 'Unit', 'Default Qty', 'Price', 'Usage Count', 'Created'];

  const rows = items.map((item) => [
    cleanText(item.description ?? 'N/A'),
    cleanText(item.sku ?? ''),
    cleanText(itemCategoryDisplayName(item.category)),
    cleanText(item.unit ?? ''),
    item.defaultQuantity != null ? String(item.defaultQuantity) : '',
    item.unitPrice != null ? item.unitPrice.toFixed(2) : '',
    String(item.usageCount ?? 0),
    formatDateTime(item.createdAt),
  ]);

  await exportToCSV(generateFilename('catalog_items_export'), headers, rows);
}
