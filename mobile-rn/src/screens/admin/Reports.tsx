import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { AdminShell } from '../../components/admin/AdminShell';
import {
  AppIcon,
  Card,
  EmptyState,
  FormField,
  LoadingState,
  PrimaryButton,
  SecondaryButton,
  AppModal,
} from '../../components/ui';
import { useAuthStore } from '../../stores/useAuthStore';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/reports_screen.dart
 * (`ReportsMobile`, verified against source on 2026-06-22) — 5 report types
 * (Deliveries/Drivers/Claims/Customers/PODs), each with its own raw-Firestore
 * aggregation, a summary-stat grid, and a scrollable data table, over a date range.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the >1200px
 * desktop branch lands in Phase 4.
 *
 * Deviations from the Flutter source:
 * - All 5 report types' data-aggregation queries read raw Firestore doc data directly,
 *   matching the Dart source (ad-hoc fields not on any typed model).
 * - Material `DataTable` → custom horizontally + vertically scrollable, data-driven table.
 * - `showDateRangePicker` → a modal with two `YYYY-MM-DD` text fields.
 * - Report-type selector `FilterChip`s → the existing Chip pattern.
 *
 * UI/UX refresh (Operations Precision): the custom navy header, emoji refresh/calendar/
 * empty/signed/photo/location glyphs are replaced with the shared AppHeader, SVG AppIcon,
 * Card, EmptyState, LoadingState, AppModal, FormField, and button primitives. Semantic
 * tokens only.
 */
export type ReportType = 'delivery' | 'driver' | 'claims' | 'customers' | 'pod';

interface ReportsProps {
  navigation: {
    goBack: () => void;
    navigate: (screen: string, params?: Record<string, unknown>) => void;
  };
}

const REPORT_TABS: { key: ReportType; label: string }[] = [
  { key: 'delivery', label: 'Deliveries' },
  { key: 'driver', label: 'Drivers' },
  { key: 'claims', label: 'Claims' },
  { key: 'customers', label: 'Customers' },
  { key: 'pod', label: 'PODs' },
];

interface SummaryCardDef {
  label: string;
  key: string;
  color: string;
  format?: (value: unknown) => string;
}

interface ReportColumn {
  label: string;
  width: number;
  render: (row: Record<string, unknown>) => React.ReactNode;
}

function truncate(value: unknown, max: number): string {
  const text = value == null ? 'N/A' : String(value);
  return text.length > max ? `${text.slice(0, max)}...` : text;
}

function formatTimestamp(value: unknown): string {
  if (!value) return 'N/A';
  const date = value instanceof Date ? value : (value as { toDate?: () => Date }).toDate?.();
  return date ? date.toLocaleDateString(undefined, { month: 'short', day: '2-digit' }) : 'N/A';
}

function formatCurrency(value: unknown): string {
  return `R${((value as number) ?? 0).toFixed(2)}`;
}

function getStatusColor(status: unknown): string {
  switch (String(status).toLowerCase()) {
    case 'delivered':
    case 'completed':
    case 'approved':
      return colors.verified;
    case 'pending':
      return colors.attention;
    case 'intransit':
    case 'intransit_':
      return colors.active;
    case 'rejected':
      return colors.critical;
    default:
      return colors.contentSecondary;
  }
}

function getPriorityColor(priority: unknown): string {
  switch (String(priority).toLowerCase()) {
    case 'urgent':
      return colors.critical;
    case 'high':
      return colors.attention;
    case 'normal':
      return colors.active;
    case 'low':
      return colors.verified;
    default:
      return colors.contentSecondary;
  }
}

function CellChip({ label, color }: { label: string; color: string }) {
  return (
    <View style={[styles.cellChip, { backgroundColor: `${color}26`, borderColor: color }]}>
      <Text style={[styles.cellChipText, { color }]}>{label}</Text>
    </View>
  );
}

async function loadDeliveryReport(companyId: string, startDate: Date, endDate: Date) {
  const snapshot = await firestore()
    .collection('deliveries')
    .where('companyId', '==', companyId)
    .where('scheduledDate', '>=', firestore.Timestamp.fromDate(startDate))
    .where('scheduledDate', '<=', firestore.Timestamp.fromDate(endDate))
    .orderBy('scheduledDate', 'desc')
    .get();

  const data: Record<string, unknown>[] = [];
  let completed = 0;
  let pending = 0;
  let inTransit = 0;
  let totalAmount = 0;
  let totalItems = 0;
  let onTimeDeliveries = 0;

  snapshot.docs.forEach((doc) => {
    const d = doc.data();
    const status = (d.status as string) ?? 'unknown';
    if (status === 'delivered') completed++;
    if (status === 'pending') pending++;
    if (status === 'inTransit') inTransit++;

    const items = (d.items as Record<string, unknown>[]) ?? [];
    totalItems += items.length;

    const scheduledDate = (d.scheduledDate as { toDate?: () => Date })?.toDate?.();
    const deliveredAt = (d.deliveredAt as { toDate?: () => Date })?.toDate?.();
    if (scheduledDate && deliveredAt && status === 'delivered' && deliveredAt.getTime() < scheduledDate.getTime() + 3600000) {
      onTimeDeliveries++;
    }

    const amount = (d.invoiceTotal as number) ?? 0;
    totalAmount += amount;

    data.push({
      trackingNumber: d.trackingNumber ?? d.invoiceNumber ?? 'N/A',
      customerName: d.customerName ?? 'N/A',
      customerPhone: d.customerPhone ?? 'N/A',
      address: d.customerAddress ?? d.address ?? 'N/A',
      status,
      scheduledDate: d.scheduledDate,
      completedAt: d.completedAt ?? d.deliveredAt,
      driverName: d.driverName ?? 'Unassigned',
      amount,
      orderNumber: d.orderNumber ?? 'N/A',
      invoiceNumber: d.invoiceNumber ?? 'N/A',
      notes: d.notes ?? '',
      itemCount: items.length,
    });
  });

  const total = snapshot.docs.length;
  return {
    data,
    summary: {
      total,
      completed,
      pending,
      inTransit,
      completionRate: total > 0 ? ((completed / total) * 100).toFixed(1) : '0.0',
      onTimeRate: completed > 0 ? ((onTimeDeliveries / completed) * 100).toFixed(1) : '0.0',
      totalItems,
      totalAmount,
    },
  };
}

async function loadDriverReport(companyId: string, startDate: Date, endDate: Date) {
  const driversSnapshot = await firestore().collection('users').where('companyId', '==', companyId).where('role', '==', 'driver').get();

  const data: Record<string, unknown>[] = [];
  let activeDrivers = 0;
  let approvedDrivers = 0;
  let totalDeliveries = 0;
  let totalCompleted = 0;
  let totalRevenue = 0;
  let onTimeRateSum = 0;
  let driversWithDeliveries = 0;

  for (const driverDoc of driversSnapshot.docs) {
    const driver = driverDoc.data();
    if (driver.isActive) activeDrivers++;
    if (driver.approvalStatus === 'approved') approvedDrivers++;

    const deliveriesSnapshot = await firestore()
      .collection('deliveries')
      .where('driverId', '==', driverDoc.id)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(startDate))
      .where('scheduledDate', '<=', firestore.Timestamp.fromDate(endDate))
      .get();

    let completedCount = 0;
    let onTimeCount = 0;
    let totalDeliveryTimeMin = 0;
    let deliveriesWithTime = 0;
    let driverRevenue = 0;

    deliveriesSnapshot.docs.forEach((doc) => {
      const d = doc.data();
      if (d.status === 'delivered') {
        completedCount++;
        const scheduledDate = (d.scheduledDate as { toDate?: () => Date })?.toDate?.();
        const deliveredAt = (d.deliveredAt as { toDate?: () => Date })?.toDate?.();
        if (scheduledDate && deliveredAt) {
          if (deliveredAt.getTime() < scheduledDate.getTime() + 3600000) onTimeCount++;
          const minutes = (deliveredAt.getTime() - scheduledDate.getTime()) / 60000;
          if (minutes > 0) {
            totalDeliveryTimeMin += minutes;
            deliveriesWithTime++;
          }
        }
        driverRevenue += (d.invoiceTotal as number) ?? 0;
      }
    });

    const onTimeRate = completedCount > 0 ? (onTimeCount / completedCount) * 100 : 0;
    if (deliveriesSnapshot.docs.length > 0) {
      onTimeRateSum += onTimeRate;
      driversWithDeliveries++;
    }
    totalDeliveries += deliveriesSnapshot.docs.length;
    totalCompleted += completedCount;
    totalRevenue += driverRevenue;

    data.push({
      fullName: driver.fullName ?? 'N/A',
      email: driver.email ?? 'N/A',
      phone: driver.phoneNumber ?? driver.phone ?? 'N/A',
      approvalStatus: driver.approvalStatus ?? 'pending',
      deliveriesCount: deliveriesSnapshot.docs.length,
      completedCount,
      onTimeRate: onTimeRate.toFixed(1),
      averageDeliveryTime: `${(deliveriesWithTime > 0 ? totalDeliveryTimeMin / deliveriesWithTime / 60 : 0).toFixed(1)}h`,
      totalRevenue: driverRevenue,
    });
  }

  return {
    data,
    summary: {
      totalDrivers: driversSnapshot.docs.length,
      activeDrivers,
      approvedDrivers,
      pendingApprovals: driversSnapshot.docs.length - approvedDrivers,
      totalDeliveries,
      completionRate: totalDeliveries > 0 ? ((totalCompleted / totalDeliveries) * 100).toFixed(1) : '0.0',
      averageOnTimeRate: driversWithDeliveries > 0 ? (onTimeRateSum / driversWithDeliveries).toFixed(1) : '0.0',
      totalRevenue,
    },
  };
}

async function loadClaimsReport(companyId: string, startDate: Date, endDate: Date) {
  const snapshot = await firestore()
    .collection('companies')
    .doc(companyId)
    .collection('claims')
    .where('createdAt', '>=', startDate.toISOString())
    .where('createdAt', '<=', endDate.toISOString())
    .orderBy('createdAt', 'desc')
    .get();

  const data: Record<string, unknown>[] = [];
  let pending = 0;
  let approved = 0;
  let rejected = 0;
  let urgentClaims = 0;
  let overdue = 0;

  snapshot.docs.forEach((doc) => {
    const c = doc.data();
    const status = (c.status as string) ?? 'pending';
    const amount = (c.claimAmount as number) ?? 0;
    if (status === 'pending') pending++;
    if (status === 'approved') approved++;
    if (status === 'rejected') rejected++;
    if (c.priority === 'urgent') urgentClaims++;

    const dueDate = c.dueDate as string | undefined;
    if (dueDate && new Date() > new Date(dueDate) && status !== 'resolved') overdue++;

    data.push({
      claimNumber: doc.id,
      customerName: c.customerName ?? 'N/A',
      type: c.type ?? 'N/A',
      priority: c.priority ?? 'normal',
      status,
      amount,
      dueDate: c.dueDate,
      resolution: c.resolution ?? 'N/A',
    });
  });

  const total = snapshot.docs.length;
  return {
    data,
    summary: {
      total,
      pending,
      approved,
      rejected,
      urgentClaims,
      overdue,
      resolutionRate: total > 0 ? (((approved + rejected) / total) * 100).toFixed(1) : '0.0',
      averageResolutionTime: '— days',
    },
  };
}

async function loadCustomersReport(companyId: string, startDate: Date, endDate: Date) {
  const customersSnapshot = await firestore().collection('customers').where('companyId', '==', companyId).get();

  const data: Record<string, unknown>[] = [];
  let totalDeliveries = 0;
  let totalCompleted = 0;
  let totalPending = 0;
  let totalRevenue = 0;
  let activeCustomers = 0;
  let vipCustomers = 0;

  for (const customerDoc of customersSnapshot.docs) {
    const customer = customerDoc.data();
    const deliveriesSnapshot = await firestore()
      .collection('deliveries')
      .where('customerId', '==', customerDoc.id)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(startDate))
      .where('scheduledDate', '<=', firestore.Timestamp.fromDate(endDate))
      .get();

    let completedCount = 0;
    let pendingCount = 0;
    let customerAmount = 0;
    let lastDeliveryDate: Date | undefined;

    deliveriesSnapshot.docs.forEach((doc) => {
      const d = doc.data();
      const status = (d.status as string) ?? 'unknown';
      const amount = (d.invoiceTotal as number) ?? 0;
      const scheduledDate = (d.scheduledDate as { toDate?: () => Date })?.toDate?.();
      if (status === 'delivered') {
        completedCount++;
        if (scheduledDate && (!lastDeliveryDate || scheduledDate > lastDeliveryDate)) lastDeliveryDate = scheduledDate;
      } else if (status === 'pending') {
        pendingCount++;
      }
      customerAmount += amount;
    });

    totalDeliveries += deliveriesSnapshot.docs.length;
    totalCompleted += completedCount;
    totalPending += pendingCount;
    totalRevenue += customerAmount;
    if (deliveriesSnapshot.docs.length > 0) activeCustomers++;
    if (customer.customerType === 'vip' || customerAmount > 10000) vipCustomers++;

    data.push({
      name: customer.name ?? 'N/A',
      email: customer.email ?? 'N/A',
      phone: customer.phone ?? 'N/A',
      city: customer.city ?? 'N/A',
      accountNumber: customer.accountNumber ?? customer.customerNumber ?? 'N/A',
      deliveriesCount: deliveriesSnapshot.docs.length,
      completedCount,
      totalAmount: customerAmount,
      lastDeliveryDate,
    });
  }

  return {
    data,
    summary: {
      totalCustomers: customersSnapshot.docs.length,
      activeCustomers,
      vipCustomers,
      totalDeliveries,
      completionRate: totalDeliveries > 0 ? ((totalCompleted / totalDeliveries) * 100).toFixed(1) : '0.0',
      totalRevenue,
      averageOrderValue: totalDeliveries > 0 ? (totalRevenue / totalDeliveries).toFixed(2) : '0.00',
      totalPending,
    },
  };
}

async function loadPodReport(companyId: string, startDate: Date, endDate: Date) {
  const snapshot = await firestore()
    .collection('pods')
    .where('companyId', '==', companyId)
    .where('createdAt', '>=', firestore.Timestamp.fromDate(startDate))
    .where('createdAt', '<=', firestore.Timestamp.fromDate(endDate))
    .orderBy('createdAt', 'desc')
    .get();

  const data: Record<string, unknown>[] = [];
  let signed = 0;
  let withPhotos = 0;
  let withNotes = 0;

  snapshot.docs.forEach((doc) => {
    const p = doc.data();
    const hasSigned = Boolean(p.signatureUrl);
    const photoUrls = (p.photoUrls as string[]) ?? (p.photoUrl ? [p.photoUrl] : []);
    const hasPhotos = photoUrls.length > 0;
    const notes = (p.notes as string) ?? '';
    const hasNotes = notes.length > 0;
    const location = p.location as Record<string, unknown> | undefined;

    if (hasSigned) signed++;
    if (hasPhotos) withPhotos++;
    if (hasNotes) withNotes++;

    data.push({
      deliveryId: doc.id,
      driverName: p.driverId ?? 'N/A',
      customerName: p.customerName ?? 'N/A',
      receiverName: p.signedBy ?? 'Not specified',
      hasSigned,
      hasPhotos,
      photoCount: photoUrls.length,
      notes: truncate(notes, 50),
      hasLocation: Boolean(location),
      createdAt: p.createdAt ?? p.timestamp,
    });
  });

  return {
    data,
    summary: {
      total: snapshot.docs.length,
      signed,
      withPhotos,
      withNotes,
      signatureRate: snapshot.docs.length > 0 ? ((signed / snapshot.docs.length) * 100).toFixed(1) : '0.0',
    },
  };
}

export const LOADERS: Record<ReportType, (companyId: string, start: Date, end: Date) => Promise<{ data: Record<string, unknown>[]; summary: Record<string, unknown> }>> = {
  delivery: loadDeliveryReport,
  driver: loadDriverReport,
  claims: loadClaimsReport,
  customers: loadCustomersReport,
  pod: loadPodReport,
};

export const SUMMARY_CARDS: Record<ReportType, SummaryCardDef[]> = {
  delivery: [
    { label: 'Total', key: 'total', color: colors.active },
    { label: 'Completed', key: 'completed', color: colors.verified },
    { label: 'Pending', key: 'pending', color: colors.attention },
    { label: 'In Transit', key: 'inTransit', color: colors.shell },
    { label: 'Completion Rate', key: 'completionRate', color: colors.verified, format: (v) => `${v}%` },
    { label: 'On-Time Rate', key: 'onTimeRate', color: colors.shell, format: (v) => `${v}%` },
    { label: 'Total Items', key: 'totalItems', color: colors.attention },
    { label: 'Revenue', key: 'totalAmount', color: colors.verified, format: formatCurrency },
  ],
  driver: [
    { label: 'Total Drivers', key: 'totalDrivers', color: colors.active },
    { label: 'Active', key: 'activeDrivers', color: colors.verified },
    { label: 'Approved', key: 'approvedDrivers', color: colors.shell },
    { label: 'Pending', key: 'pendingApprovals', color: colors.attention },
    { label: 'Total Deliveries', key: 'totalDeliveries', color: colors.verified },
    { label: 'Completion Rate', key: 'completionRate', color: colors.shell, format: (v) => `${v}%` },
    { label: 'Avg On-Time', key: 'averageOnTimeRate', color: colors.attention, format: (v) => `${v}%` },
    { label: 'Total Revenue', key: 'totalRevenue', color: colors.verified, format: formatCurrency },
  ],
  claims: [
    { label: 'Total Claims', key: 'total', color: colors.active },
    { label: 'Pending', key: 'pending', color: colors.attention },
    { label: 'Approved', key: 'approved', color: colors.verified },
    { label: 'Rejected', key: 'rejected', color: colors.critical },
    { label: 'Urgent', key: 'urgentClaims', color: colors.critical },
    { label: 'Overdue', key: 'overdue', color: colors.shell },
    { label: 'Resolution Rate', key: 'resolutionRate', color: colors.verified, format: (v) => `${v}%` },
    { label: 'Avg Resolution', key: 'averageResolutionTime', color: colors.shell },
  ],
  customers: [
    { label: 'Total Customers', key: 'totalCustomers', color: colors.active },
    { label: 'Active', key: 'activeCustomers', color: colors.verified },
    { label: 'VIP Customers', key: 'vipCustomers', color: colors.shell },
    { label: 'Total Deliveries', key: 'totalDeliveries', color: colors.verified },
    { label: 'Completion Rate', key: 'completionRate', color: colors.shell, format: (v) => `${v}%` },
    { label: 'Total Revenue', key: 'totalRevenue', color: colors.verified, format: formatCurrency },
    { label: 'Avg Order Value', key: 'averageOrderValue', color: colors.attention, format: (v) => `R${v}` },
    { label: 'Pending Orders', key: 'totalPending', color: colors.attention },
  ],
  pod: [
    { label: 'Total PODs', key: 'total', color: colors.active },
    { label: 'Signed', key: 'signed', color: colors.verified },
    { label: 'With Photos', key: 'withPhotos', color: colors.shell },
    { label: 'With Notes', key: 'withNotes', color: colors.verified },
  ],
};

export const COLUMNS: Record<ReportType, ReportColumn[]> = {
  delivery: [
    { label: 'Tracking #', width: 90, render: (r) => <Text style={styles.cellText}>{truncate(r.trackingNumber, 10)}</Text> },
    { label: 'Customer', width: 120, render: (r) => <Text style={styles.cellText}>{truncate(r.customerName, 15)}</Text> },
    { label: 'Phone', width: 110, render: (r) => <Text style={styles.cellText}>{String(r.customerPhone)}</Text> },
    { label: 'Address', width: 150, render: (r) => <Text style={styles.cellText}>{truncate(r.address, 20)}</Text> },
    { label: 'Driver', width: 100, render: (r) => <Text style={styles.cellText}>{truncate(r.driverName, 12)}</Text> },
    { label: 'Status', width: 90, render: (r) => <CellChip label={String(r.status)} color={getStatusColor(r.status)} /> },
    { label: 'Scheduled', width: 80, render: (r) => <Text style={styles.cellText}>{formatTimestamp(r.scheduledDate)}</Text> },
    { label: 'Completed', width: 80, render: (r) => <Text style={styles.cellText}>{formatTimestamp(r.completedAt)}</Text> },
    { label: 'Items', width: 60, render: (r) => <Text style={styles.cellText}>{String(r.itemCount)}</Text> },
    { label: 'Amount', width: 90, render: (r) => <Text style={styles.cellText}>{formatCurrency(r.amount)}</Text> },
    { label: 'Order #', width: 90, render: (r) => <Text style={styles.cellText}>{String(r.orderNumber)}</Text> },
    { label: 'Invoice #', width: 90, render: (r) => <Text style={styles.cellText}>{String(r.invoiceNumber)}</Text> },
    { label: 'Notes', width: 110, render: (r) => <Text style={styles.cellText}>{truncate(r.notes, 15)}</Text> },
  ],
  driver: [
    { label: 'Name', width: 130, render: (r) => <Text style={styles.cellText}>{String(r.fullName)}</Text> },
    { label: 'Email', width: 150, render: (r) => <Text style={styles.cellText}>{truncate(r.email, 20)}</Text> },
    { label: 'Phone', width: 110, render: (r) => <Text style={styles.cellText}>{String(r.phone)}</Text> },
    { label: 'Status', width: 90, render: (r) => <CellChip label={String(r.approvalStatus)} color={getStatusColor(r.approvalStatus)} /> },
    { label: 'Deliveries', width: 80, render: (r) => <Text style={styles.cellText}>{String(r.deliveriesCount)}</Text> },
    { label: 'Completed', width: 80, render: (r) => <Text style={styles.cellText}>{String(r.completedCount)}</Text> },
    { label: 'On-Time %', width: 80, render: (r) => <Text style={styles.cellText}>{String(r.onTimeRate)}%</Text> },
    { label: 'Avg Time', width: 80, render: (r) => <Text style={styles.cellText}>{String(r.averageDeliveryTime)}</Text> },
    { label: 'Revenue', width: 100, render: (r) => <Text style={styles.cellText}>{formatCurrency(r.totalRevenue)}</Text> },
  ],
  claims: [
    { label: 'Claim #', width: 110, render: (r) => <Text style={styles.cellText}>{truncate(r.claimNumber, 12)}</Text> },
    { label: 'Customer', width: 120, render: (r) => <Text style={styles.cellText}>{truncate(r.customerName, 15)}</Text> },
    { label: 'Type', width: 100, render: (r) => <Text style={styles.cellText}>{String(r.type)}</Text> },
    { label: 'Priority', width: 90, render: (r) => <CellChip label={String(r.priority)} color={getPriorityColor(r.priority)} /> },
    { label: 'Status', width: 90, render: (r) => <CellChip label={String(r.status)} color={getStatusColor(r.status)} /> },
    { label: 'Amount', width: 90, render: (r) => <Text style={styles.cellText}>{formatCurrency(r.amount)}</Text> },
    { label: 'Due Date', width: 80, render: (r) => <Text style={styles.cellText}>{formatTimestamp(r.dueDate)}</Text> },
    { label: 'Resolution', width: 100, render: (r) => <Text style={styles.cellText}>{truncate(r.resolution, 10)}</Text> },
  ],
  customers: [
    { label: 'Name', width: 130, render: (r) => <Text style={styles.cellText}>{String(r.name)}</Text> },
    { label: 'Email', width: 150, render: (r) => <Text style={styles.cellText}>{truncate(r.email, 20)}</Text> },
    { label: 'Phone', width: 110, render: (r) => <Text style={styles.cellText}>{String(r.phone)}</Text> },
    { label: 'City', width: 90, render: (r) => <Text style={styles.cellText}>{String(r.city)}</Text> },
    { label: 'Account #', width: 100, render: (r) => <Text style={styles.cellText}>{String(r.accountNumber)}</Text> },
    { label: 'Deliveries', width: 80, render: (r) => <Text style={styles.cellText}>{String(r.deliveriesCount)}</Text> },
    { label: 'Completed', width: 80, render: (r) => <Text style={styles.cellText}>{String(r.completedCount)}</Text> },
    { label: 'Total Amount', width: 100, render: (r) => <Text style={styles.cellText}>{formatCurrency(r.totalAmount)}</Text> },
    { label: 'Last Delivery', width: 90, render: (r) => <Text style={styles.cellText}>{r.lastDeliveryDate ? formatTimestamp(r.lastDeliveryDate) : 'Never'}</Text> },
  ],
  pod: [
    { label: 'Delivery ID', width: 90, render: (r) => <Text style={styles.cellText}>{truncate(r.deliveryId, 8)}</Text> },
    { label: 'Driver', width: 110, render: (r) => <Text style={styles.cellText}>{truncate(r.driverName, 12)}</Text> },
    { label: 'Customer', width: 120, render: (r) => <Text style={styles.cellText}>{truncate(r.customerName, 15)}</Text> },
    { label: 'Receiver', width: 110, render: (r) => <Text style={styles.cellText}>{truncate(r.receiverName, 15)}</Text> },
    {
      label: 'Signed',
      width: 60,
      render: (r) => <AppIcon name={r.hasSigned ? 'check' : 'close'} size={16} color={r.hasSigned ? colors.verified : colors.critical} />,
    },
    {
      label: 'Photos',
      width: 70,
      render: (r) => (
        <View style={styles.cellIconRow}>
          {r.hasPhotos ? <AppIcon name="image" size={16} color={colors.contentSecondary} /> : <Text style={styles.cellText}>—</Text>}
          <Text style={styles.cellText}>{String(r.photoCount)}</Text>
        </View>
      ),
    },
    { label: 'Notes', width: 110, render: (r) => <Text style={styles.cellText}>{truncate(r.notes, 10)}</Text> },
    {
      label: 'Location',
      width: 70,
      render: (r) => (r.hasLocation ? <AppIcon name="location" size={16} color={colors.shell} /> : <Text style={styles.cellText}>—</Text>),
    },
    { label: 'Date', width: 80, render: (r) => <Text style={styles.cellText}>{formatTimestamp(r.createdAt)}</Text> },
  ],
};

export default function Reports({ navigation }: ReportsProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const signOut = useAuthStore((s) => s.signOut);

  const [selectedReport, setSelectedReport] = useState<ReportType>('delivery');
  const [startDate, setStartDate] = useState(new Date(Date.now() - 7 * 86400000));
  const [endDate, setEndDate] = useState(new Date());
  const [isLoading, setIsLoading] = useState(false);
  const [reportData, setReportData] = useState<Record<string, unknown>[]>([]);
  const [summaryStats, setSummaryStats] = useState<Record<string, unknown>>({});
  const [showDateModal, setShowDateModal] = useState(false);
  const [dateStartText, setDateStartText] = useState('');
  const [dateEndText, setDateEndText] = useState('');

  const loadReport = useCallback(async () => {
    if (!currentUser) return;
    setIsLoading(true);
    try {
      const { data, summary } = await LOADERS[selectedReport](currentUser.companyId, startDate, endDate);
      setReportData(data);
      setSummaryStats(summary);
    } catch {
      setReportData([]);
      setSummaryStats({});
    } finally {
      setIsLoading(false);
    }
  }, [currentUser, selectedReport, startDate, endDate]);

  useEffect(() => {
    loadReport();
  }, [loadReport]);

  const applyDateRange = () => {
    const start = new Date(dateStartText);
    const end = new Date(dateEndText);
    if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime())) {
      setStartDate(start);
      setEndDate(end);
    }
    setShowDateModal(false);
  };

  const columns = COLUMNS[selectedReport];
  const summaryCards = SUMMARY_CARDS[selectedReport];
  const tableWidth = columns.reduce((sum, c) => sum + c.width + spacing.small, 0);

  const openDateRange = () => {
    setDateStartText(startDate.toISOString().slice(0, 10));
    setDateEndText(endDate.toISOString().slice(0, 10));
    setShowDateModal(true);
  };

  const handleSignOut = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  return (
    <AdminShell
      activeNav="reports"
      title="Reports"
      userName={currentUser?.fullName}
      onNavigate={(screen) => navigation.navigate(screen)}
      onRefresh={loadReport}
      onLogout={handleSignOut}
    >
      <View style={styles.container}>
      <View style={styles.toolbar}>
        <SecondaryButton
          label="Date range"
          icon="calendar"
          onPress={openDateRange}
        />
      </View>

      {isLoading ? (
        <LoadingState title="Building report" message="Aggregating records for the selected range." />
      ) : (
        <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.reportTypeRow}>
            {REPORT_TABS.map((tab) => (
              <Pressable
                key={tab.key}
                accessibilityRole="button"
                accessibilityState={{ selected: selectedReport === tab.key }}
                style={[styles.chip, selectedReport === tab.key && styles.chipSelected]}
                onPress={() => setSelectedReport(tab.key)}
              >
                <Text style={[styles.chipText, selectedReport === tab.key && styles.chipTextSelected]}>{tab.label}</Text>
              </Pressable>
            ))}
          </ScrollView>

          <Card style={styles.card}>
            <Text style={textStyles.heading3}>Summary</Text>
            <View style={styles.summaryGrid}>
              {summaryCards.map((card) => (
                <View key={card.key} style={[styles.summaryCard, { backgroundColor: `${card.color}1A`, borderColor: `${card.color}4D` }]}>
                  <Text style={styles.summaryLabel}>{card.label}</Text>
                  <Text style={[styles.summaryValue, { color: card.color }]}>
                    {card.format ? card.format(summaryStats[card.key]) : String(summaryStats[card.key] ?? 0)}
                  </Text>
                </View>
              ))}
            </View>
          </Card>

          {reportData.length === 0 ? (
            <Card style={styles.card}>
              <EmptyState icon="clipboard" title="No data available" message="No records match this report type and date range." />
            </Card>
          ) : (
            <ScrollView horizontal>
              <Card style={[styles.card, styles.tableCard, { width: tableWidth }]}>
                <View style={styles.tableHeaderRow}>
                  {columns.map((col) => (
                    <Text key={col.label} style={[styles.tableHeaderCell, { width: col.width }]}>
                      {col.label}
                    </Text>
                  ))}
                </View>
                {reportData.map((row, index) => (
                  <View key={index} style={[styles.tableRow, index % 2 === 1 && styles.tableRowAlt]}>
                    {columns.map((col) => (
                      <View key={col.label} style={[styles.tableCell, { width: col.width }]}>
                        {col.render(row)}
                      </View>
                    ))}
                  </View>
                ))}
              </Card>
            </ScrollView>
          )}
        </ScrollView>
      )}

      <AppModal
        visible={showDateModal}
        title="Date range"
        onClose={() => setShowDateModal(false)}
        footer={
          <View style={styles.modalButtonRow}>
            <SecondaryButton label="Cancel" style={styles.modalButton} onPress={() => setShowDateModal(false)} />
            <PrimaryButton label="Apply" style={styles.modalButton} onPress={applyDateRange} />
          </View>
        }
      >
        <View style={styles.dateFields}>
          <FormField label="Start date" helperText="Format: YYYY-MM-DD" value={dateStartText} onChangeText={setDateStartText} autoCapitalize="none" />
          <FormField label="End date" helperText="Format: YYYY-MM-DD" value={dateEndText} onChangeText={setDateEndText} autoCapitalize="none" />
        </View>
      </AppModal>
      </View>
    </AdminShell>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.canvas },
  toolbar: {
    alignItems: 'flex-end',
    paddingHorizontal: spacing.medium,
    paddingTop: spacing.medium,
  },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  reportTypeRow: { gap: spacing.small, marginBottom: spacing.medium },
  chip: { borderRadius: radii.inputRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
  chipSelected: { backgroundColor: colors.activeMuted, borderColor: colors.shell },
  chipText: { ...textStyles.bodySmall, color: colors.contentSecondary, fontWeight: '600' },
  chipTextSelected: { color: colors.shell },
  card: { marginBottom: spacing.large },
  summaryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small + 4, marginTop: spacing.medium },
  summaryCard: { width: '47%', borderRadius: radii.inputRadius, borderWidth: 1, padding: spacing.small + 4 },
  summaryLabel: { ...textStyles.bodySmall, color: colors.contentSecondary },
  summaryValue: { ...textStyles.heading3, marginTop: 4 },
  tableCard: { padding: 0, overflow: 'hidden' },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.surfaceMuted, paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small },
  tableHeaderCell: { ...textStyles.labelSmall, color: colors.contentPrimary, fontWeight: '700', paddingRight: spacing.small },
  tableRow: { flexDirection: 'row', paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small, borderBottomWidth: 1, borderBottomColor: colors.border },
  tableRowAlt: { backgroundColor: colors.surfaceMuted },
  tableCell: { paddingRight: spacing.small, justifyContent: 'center' },
  cellText: { ...textStyles.bodySmall, color: colors.contentPrimary },
  cellIconRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  cellChip: { borderRadius: 10, borderWidth: 1, paddingHorizontal: spacing.small, paddingVertical: 2, alignSelf: 'flex-start' },
  cellChipText: { ...textStyles.labelSmall, fontWeight: '600' },
  dateFields: { gap: spacing.medium },
  modalButtonRow: { flexDirection: 'row', gap: spacing.medium },
  modalButton: { flex: 1 },
});
