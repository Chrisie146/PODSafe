import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  LayoutAnimation,
  Linking,
  Modal,
  Pressable,
  RefreshControl,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { BarChart, LineChart, PieChart } from 'react-native-gifted-charts';
import Clipboard from '@react-native-clipboard/clipboard';
import { useAuthStore } from '../../stores/useAuthStore';
import { hasPermission } from '../../permissions/permissionService';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/analytics_dashboard_desktop.dart (4039 lines — the largest
 * Dart file in this migration; verified against source on 2026-06-23). The desktop variant
 * is materially richer than analytics_dashboard_screen.dart's mobile layout (already ported
 * as AnalyticsDashboard.tsx): a 280px filter sidebar, a collapsible metrics bar (delivery
 * stats + fleet/claims bars), a 2×2 charts grid (line/pie/bar/bar), an enhanced locations
 * section, six data tables (leaderboard, trucks, claims, claim types, top customers, plus
 * the six chart-data tables), a 320px chart-details side panel, CSV/PDF export, and a
 * keyboard-shortcut system.
 *
 * Deviations from the Flutter source:
 * - Keyboard shortcuts (digits 1-6 chart-focus, Ctrl+E export, Ctrl+F filters, F5 refresh)
 *   are DROPPED — RN has no reliable cross-target Focus+onKeyEvent analog. Their functions
 *   stay surfaced as visible header/panel buttons; the 6 numeric shortcut badges on the
 *   chart-focus buttons are visual-only labels. (Dart lines 65-116, 2234-2283 dead code.)
 * - fl_chart (LineChart/PieChart/BarChart) → react-native-gifted-charts (same package the
 *   mobile variant already uses). LineChart config reused from AnalyticsDashboard.tsx;
 *   PieChart/BarChart are new but the package exports both. fl_chart `withValues(alpha:)`
 *   has no direct equivalent — opacity/gradient props are used directly.
 * - Flutter DataTable → a local View-based DataTable helper (header row + mapped rows inside
 *   a horizontal ScrollView with minWidth), matching DeliveryManagementDesktop/
 *   ClaimsDashboardDesktop precedent — RN has no DataTable and FlatList inside a ScrollView
 *   trips nested-virtualization warnings, so plain map is used (8-10 rows is fine).
 * - AnimatedSize (metrics collapse) → LayoutAnimation.configureNext(Presets.easeInEaseOut)
 *   before setShowMetrics. No-op on web (acceptable; no RNW target yet).
 * - showDateRangePicker → a local Modal calendar-grid RangeCalendarPicker (no
 *   @react-native-community/datetimepicker in this project). Bounds 2020..now, Clear kept.
 * - AnalyticsMapWidget (real map) → the same degraded scrollable list of location rows with
 *   "Open in Maps" Google Maps links that the mobile variant uses. react-native-maps IS
 *   installed now (LiveTracking), but this screen ultimately targets the RNW admin web
 *   shell where react-native-maps does not render — and the mobile variant already set this
 *   precedent and documented the deviation. Per-location driver/pod/customer enrichment
 *   (each an N+1 Firestore read in the Dart source) is dropped: the degraded list doesn't
 *   surface those fields, so fetching them would be pure waste (same call as mobile).
 * - POD locations read from the canonical top-level `pods/{deliveryId}` collection, NOT the
 *   Dart source's `companies/{companyId}/pods` subcollection — per this migration's own
 *   Dual-POD Architecture Decision (settled in Phase 2): that subcollection is the abandoned
 *   pipeline with no real driver-capture writers. Claim locations still read from
 *   `companies/{companyId}/claims.gpsLocation` (canonical claims location).
 * - CSVExportService / PDFExportService have no RN equivalents. CSV is built inline and
 *   shared via RN core `Share.share`. PDF export is stubbed as a "coming soon" Alert (no
 *   expo-print/react-native-pdf-lib in this project). _exportChartAsImage and _shareChart
 *   were already Dart stubs ("coming soon") — ported faithfully as Alerts.
 * - BUG FIXED in port: the Dart _buildClaimsChartDetails reads c['customer']/c['reason']
 *   but the _topClaims entries are built with keys 'customerName'/'type', so it always
 *   rendered 'Unknown'/empty. The port reads customerName/type correctly.
 * - BUG FIXED in port: the Dart _exportChartData Copy button only showed a SnackBar and
 *   never copied. The port wires it to @react-native-clipboard/clipboard (already a dep).
 * - DUPLICATED LOGIC consolidated: the Dart _exportToCSV and _exportToPDF each inline a
 *   date-range switch that duplicates _getDateRange. The port calls the centralized
 *   getDateRange() from both.
 * - Permission gate: the desktop Dart has NO PermissionBuilder wrapper (the mobile screen
 *   wraps the desktop widget and applies Permission.analyticsView). The port restores the
 *   check directly via hasPermission(currentUser, 'analyticsView') returning an inline
 *   Access Denied view — same precedent as AnalyticsDashboard.tsx / DeliveryManagement.tsx.
 * - Dynamic per-company AppBar recoloring (ThemeProvider.primaryColor) → static colors.primary
 *   token, consistent with every other ported desktop screen (deferred product decision).
 * - _loadPerformanceMetrics uses scheduledDate >= start with NO end bound, and
 *   _loadTopCustomerDeliveries adds +1 day to the end date — both preserved faithfully as
 *   documented known inconsistencies (not "fixed", to avoid behavior drift).
 * - claims.createdAt is parsed as Timestamp OR String (schema inconsistency) — preserved.
 * - Heavy debug prints (CLAIMS DEBUG, location logs) and the commented-out
 *   _buildKeyboardShortcutsBar/_buildShortcutChip dead code are not ported.
 * - _selectedChart defaults to 'trend' so the details panel is visible on first load (the
 *   Dart close button is the only thing that sets 'none') — preserved as intended.
 */
type Period = 'week' | 'month' | 'quarter' | 'year' | 'custom';
type ChartFocus = 'trend' | 'status' | 'drivers' | 'performance' | 'deliveries' | 'claims';

interface AnalyticsDashboardDesktopProps {
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

interface TopDriver {
  id: string;
  name: string;
  deliveries: number;
}

interface LocationEntry {
  id: string;
  type: 'pod' | 'claim';
  latitude: number;
  longitude: number;
  title: string;
  subtitle: string;
}

interface PerformanceMetric {
  day: string;
  count: number;
}

interface TruckEntry {
  vehicle: string;
  count: number;
}

interface ClaimRow {
  id: string;
  customerName: string;
  customerNumber: string;
  type: string;
  description: string;
  createdAt: Date | null;
  status: string;
  amount: number;
}

interface CustomerDeliveries {
  customerNumber: string;
  customerName: string;
  count: number;
}

interface DeliveryStats {
  total: number;
  completed: number;
  active: number;
  pending: number;
  failed: number;
  completionRate: number;
  avgDeliveryTime: number;
}

interface InvoiceMetrics {
  avgDaysToDeliver: number;
  onTime: number;
  late: number;
}

interface ClaimsSummary {
  total: number;
  typeCount: Record<string, number>;
  customersWithClaims: number;
}

const DAY_NAMES = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const CLAIM_TYPE_LABELS: Record<string, string> = {
  damaged: 'Damaged',
  shortage: 'Shortage',
  shortweight: 'Short Weight',
  missing: 'Missing',
  wrongitems: 'Wrong Items',
  returns: 'Returns',
  priceerror: 'Price Error',
  latedelivery: 'Late Delivery',
  didnotdeliver: 'Did Not Deliver',
  quality: 'Quality',
  temperature: 'Temperature',
  packaging: 'Packaging',
  expiry: 'Expiry',
  service: 'Service',
  other: 'Other',
};

function formatClaimType(type: string): string {
  const t = (type || 'other').toLowerCase().replace(/\s+/g, '');
  if (CLAIM_TYPE_LABELS[t]) return CLAIM_TYPE_LABELS[t];
  // camelCase / PascalCase splitter fallback (matches the Dart fallback).
  return (type || 'Other').replace(/([a-z])([A-Z])/g, '$1 $2').replace(/^./, (c) => c.toUpperCase());
}

function statusColor(status: string): string {
  switch (status) {
    case 'pending':
      return colors.warning;
    case 'inTransit':
      return colors.info;
    case 'delivered':
      return colors.success;
    case 'failed':
      return colors.error;
    default:
      return colors.textSecondary;
  }
}

function formatStatus(status: string): string {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'inTransit':
      return 'In Transit';
    case 'delivered':
      return 'Delivered';
    case 'failed':
      return 'Failed';
    default:
      return status;
  }
}

function toDate(value: unknown): Date | null {
  if (!value) return null;
  if (typeof (value as FirebaseFirestoreTypes.Timestamp).toDate === 'function') {
    return (value as FirebaseFirestoreTypes.Timestamp).toDate();
  }
  if (typeof value === 'string') {
    const d = new Date(value);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function firstName(name: string): string {
  return (name || 'Unknown').split(' ')[0] || 'Unknown';
}

export default function AnalyticsDashboardDesktop({ navigation: _navigation }: AnalyticsDashboardDesktopProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const { width } = useWindowDimensions();

  const [selectedPeriod, setSelectedPeriod] = useState<Period>('week');
  const [isLoading, setIsLoading] = useState(true);
  const [showFilters, setShowFilters] = useState(false);
  const [showMetrics, setShowMetrics] = useState(true);
  const [selectedChart, setSelectedChart] = useState<ChartFocus | 'none'>('trend');
  const [showChartAsTable, setShowChartAsTable] = useState(false);
  const [startDate, setStartDate] = useState<Date | null>(null);
  const [endDate, setEndDate] = useState<Date | null>(null);
  const [showRangePicker, setShowRangePicker] = useState(false);
  const [exportText, setExportText] = useState<string | null>(null);

  const [stats, setStats] = useState<DeliveryStats>({
    total: 0,
    completed: 0,
    active: 0,
    pending: 0,
    failed: 0,
    completionRate: 0,
    avgDeliveryTime: 0,
  });
  const [invoice, setInvoice] = useState<InvoiceMetrics>({ avgDaysToDeliver: 0, onTime: 0, late: 0 });
  const [driverStats, setDriverStats] = useState({ total: 0, active: 0 });
  const [dailyDeliveries, setDailyDeliveries] = useState<Record<string, number>>({});
  const [deliveriesByStatus, setDeliveriesByStatus] = useState<Record<string, number>>({});
  const [topDrivers, setTopDrivers] = useState<TopDriver[]>([]);
  const [performanceMetrics, setPerformanceMetrics] = useState<PerformanceMetric[]>([]);
  const [locations, setLocations] = useState<LocationEntry[]>([]);
  const [deliveriesPerTruck, setDeliveriesPerTruck] = useState<TruckEntry[]>([]);
  const [claims, setClaims] = useState<ClaimsSummary>({ total: 0, typeCount: {}, customersWithClaims: 0 });
  const [topClaims, setTopClaims] = useState<ClaimRow[]>([]);
  const [topCustomerDeliveries, setTopCustomerDeliveries] = useState<CustomerDeliveries[]>([]);

  const getDateRange = useCallback((): { start: Date; end: Date } => {
    if (selectedPeriod === 'custom' && startDate && endDate) {
      return { start: startDate, end: endDate };
    }
    const days = selectedPeriod === 'week' ? 7 : selectedPeriod === 'month' ? 30 : selectedPeriod === 'quarter' ? 90 : 365;
    const start = new Date(Date.now() - days * 86400000);
    const end = new Date();
    end.setHours(23, 59, 59, 999);
    return { start, end };
  }, [selectedPeriod, startDate, endDate]);

  const loadDeliveryStats = useCallback(
    async (companyId: string, start: Date, end: Date) => {
      const snapshot = await firestore()
        .collection('deliveries')
        .where('companyId', '==', companyId)
        .where('scheduledDate', '>=', firestore.Timestamp.fromDate(start))
        .where('scheduledDate', '<', firestore.Timestamp.fromDate(end))
        .get();

      let completed = 0;
      let active = 0;
      let pending = 0;
      let failed = 0;
      const statusCount: Record<string, number> = {};
      let deliveryHoursSum = 0;
      let deliveryHoursCount = 0;
      let daysSum = 0;
      let daysCount = 0;
      let onTime = 0;
      let late = 0;

      snapshot.docs.forEach((doc) => {
        const d = doc.data();
        const status = d.status as string | undefined;
        if (status) {
          statusCount[status] = (statusCount[status] ?? 0) + 1;
          if (status === 'delivered') completed++;
          else if (status === 'inTransit') active++;
          else if (status === 'pending') pending++;
          else if (status === 'failed') failed++;
        }
        const created = toDate(d.createdAt);
        const delivered = toDate(d.deliveredAt);
        if (created && delivered && delivered.getTime() > created.getTime()) {
          deliveryHoursSum += (delivered.getTime() - created.getTime()) / 3600000;
          deliveryHoursCount++;
        }
        const inv = toDate(d.invoiceDate);
        if (inv && delivered && delivered.getTime() >= inv.getTime()) {
          const days = (delivered.getTime() - inv.getTime()) / 86400000;
          daysSum += days;
          daysCount++;
          if (days <= 3) onTime++;
          else late++;
        }
      });

      const total = snapshot.docs.length;
      setStats({
        total,
        completed,
        active,
        pending,
        failed,
        completionRate: total > 0 ? (completed / total) * 100 : 0,
        avgDeliveryTime: deliveryHoursCount > 0 ? deliveryHoursSum / deliveryHoursCount : 0,
      });
      setInvoice({ avgDaysToDeliver: daysCount > 0 ? daysSum / daysCount : 0, onTime, late });
      setDeliveriesByStatus(statusCount);
    },
    [],
  );

  const loadDriverStats = useCallback(async (companyId: string) => {
    const snapshot = await firestore().collection('users').where('role', '==', 'driver').where('companyId', '==', companyId).get();
    let active = 0;
    snapshot.docs.forEach((doc) => {
      if ((doc.data().approvalStatus ?? 'approved') === 'approved') active++;
    });
    setDriverStats({ total: snapshot.docs.length, active });
  }, []);

  const loadDailyDeliveries = useCallback(async (companyId: string, start: Date, end: Date) => {
    const snapshot = await firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(start))
      .where('scheduledDate', '<', firestore.Timestamp.fromDate(end))
      .get();
    const counts: Record<string, number> = {};
    snapshot.docs.forEach((doc) => {
      const sd = toDate(doc.data().scheduledDate);
      if (sd) {
        const key = sd.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
        counts[key] = (counts[key] ?? 0) + 1;
      }
    });
    setDailyDeliveries(counts);
  }, []);

  const loadTopDrivers = useCallback(async (companyId: string) => {
    const snapshot = await firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .where('status', '==', 'delivered')
      .get();
    const driverCounts: Record<string, number> = {};
    snapshot.docs.forEach((doc) => {
      const driverId = doc.data().driverId as string | undefined;
      if (driverId) driverCounts[driverId] = (driverCounts[driverId] ?? 0) + 1;
    });
    const sorted = Object.entries(driverCounts).sort((a, b) => b[1] - a[1]).slice(0, 10);
    const result: TopDriver[] = [];
    for (const [driverId, count] of sorted) {
      try {
        const driverDoc = await firestore().collection('users').doc(driverId).get();
        if (driverDoc.exists()) {
          const data = driverDoc.data();
          const name = (data?.displayName as string | undefined) || (data?.fullName as string | undefined) || 'Unknown';
          result.push({ id: driverId, name, deliveries: count });
        }
      } catch {
        // Skip drivers we can't read, matching the Dart source's catch-and-continue.
      }
    }
    setTopDrivers(result);
  }, []);

  const loadPerformanceMetrics = useCallback(async (companyId: string, start: Date) => {
    const snapshot = await firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(start))
      .get();
    const counts = [0, 0, 0, 0, 0, 0, 0];
    snapshot.docs.forEach((doc) => {
      const sd = toDate(doc.data().scheduledDate);
      if (sd) {
        const idx = (sd.getDay() + 6) % 7; // Mon=0 .. Sun=6
        counts[idx]++;
      }
    });
    setPerformanceMetrics(DAY_NAMES.map((day, i) => ({ day, count: counts[i] })));
  }, []);

  const loadLocationData = useCallback(async (companyId: string) => {
    const result: LocationEntry[] = [];

    const podsSnapshot = await firestore().collection('pods').where('companyId', '==', companyId).get();
    podsSnapshot.docs.forEach((doc) => {
      const p = doc.data();
      const location = p.location as { latitude?: number; longitude?: number } | undefined;
      if (location?.latitude != null && location?.longitude != null) {
        result.push({
          id: doc.id,
          type: 'pod',
          latitude: location.latitude,
          longitude: location.longitude,
          title: (p.customerName as string) ?? 'Unknown',
          subtitle: `Invoice: ${(p.invoiceNumber as string) ?? 'N/A'} • ${formatStatus((p.status as string) ?? 'pending')}`,
        });
      }
    });

    const claimsSnapshot = await firestore().collection('companies').doc(companyId).collection('claims').get();
    claimsSnapshot.docs.forEach((doc) => {
      const c = doc.data();
      const gps = c.gpsLocation as { latitude?: number; longitude?: number } | undefined;
      if (gps?.latitude != null && gps?.longitude != null) {
        result.push({
          id: doc.id,
          type: 'claim',
          latitude: gps.latitude,
          longitude: gps.longitude,
          title: (c.customerName as string) ?? 'Unknown',
          subtitle: `Claim: ${(c.title as string) ?? 'N/A'} • R${((c.claimAmount as number) ?? 0).toFixed(2)}`,
        });
      }
    });

    setLocations(result);
  }, []);

  const loadDeliveriesPerTruck = useCallback(async (companyId: string, start: Date, end: Date) => {
    const snapshot = await firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(start))
      .where('scheduledDate', '<', firestore.Timestamp.fromDate(end))
      .get();
    const counts: Record<string, number> = {};
    snapshot.docs.forEach((doc) => {
      const v = (doc.data().vehicleUsed as string | undefined) || 'Unassigned';
      counts[v] = (counts[v] ?? 0) + 1;
    });
    const entries = Object.entries(counts)
      .map(([vehicle, count]) => ({ vehicle, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 8);
    setDeliveriesPerTruck(entries);
  }, []);

  const loadClaimsData = useCallback(async (companyId: string) => {
    const snapshot = await firestore().collection('companies').doc(companyId).collection('claims').get();
    const typeCount: Record<string, number> = {};
    const customerSet = new Set<string>();
    const rows: ClaimRow[] = [];

    snapshot.docs.forEach((doc) => {
      const c = doc.data();
      const custNum = (c.customerNumber as string | undefined) || (c.customerName as string | undefined) || 'Unknown';
      customerSet.add(custNum);
      const type = (c.type as string | undefined) || 'other';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
      rows.push({
        id: doc.id,
        customerName: (c.customerName as string | undefined) ?? 'Unknown',
        customerNumber: (c.customerNumber as string | undefined) ?? '-',
        type,
        description: (c.description as string | undefined) ?? '',
        createdAt: toDate(c.createdAt),
        status: (c.status as string | undefined) ?? 'open',
        amount: (c.claimAmount as number | undefined) ?? 0,
      });
    });

    rows.sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0));
    setClaims({ total: snapshot.docs.length, typeCount, customersWithClaims: customerSet.size });
    setTopClaims(rows.slice(0, 10));
  }, []);

  const loadTopCustomerDeliveries = useCallback(async (companyId: string, start: Date, end: Date) => {
    // Dart adds +1 day to the end bound here — preserved faithfully (documented inconsistency).
    const endPlus1 = new Date(end.getTime() + 86400000);
    const snapshot = await firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(start))
      .where('scheduledDate', '<', firestore.Timestamp.fromDate(endPlus1))
      .get();
    const counts: Record<string, number> = {};
    const names: Record<string, string> = {};
    snapshot.docs.forEach((doc) => {
      const d = doc.data();
      const num = (d.customerNumber as string | undefined) || (d.customerName as string | undefined) || 'Unknown';
      counts[num] = (counts[num] ?? 0) + 1;
      names[num] = (d.customerName as string | undefined) || num;
    });
    const entries = Object.entries(counts)
      .map(([num, count]) => ({ customerNumber: num, customerName: names[num], count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 8);
    setTopCustomerDeliveries(entries);
  }, []);

  const loadAnalytics = useCallback(async () => {
    if (!currentUser) return;
    setIsLoading(true);
    try {
      const { start, end } = getDateRange();
      await Promise.all([
        loadDeliveryStats(currentUser.companyId, start, end),
        loadDriverStats(currentUser.companyId),
        loadDailyDeliveries(currentUser.companyId, start, end),
        loadTopDrivers(currentUser.companyId),
        loadPerformanceMetrics(currentUser.companyId, start),
        loadLocationData(currentUser.companyId),
        loadDeliveriesPerTruck(currentUser.companyId, start, end),
        loadClaimsData(currentUser.companyId),
        loadTopCustomerDeliveries(currentUser.companyId, start, end),
      ]);
    } catch (e) {
      Alert.alert('Error', `Error loading analytics: ${(e as Error).message}`);
    } finally {
      setIsLoading(false);
    }
  }, [
    currentUser,
    getDateRange,
    loadDeliveryStats,
    loadDriverStats,
    loadDailyDeliveries,
    loadTopDrivers,
    loadPerformanceMetrics,
    loadLocationData,
    loadDeliveriesPerTruck,
    loadClaimsData,
    loadTopCustomerDeliveries,
  ]);

  useEffect(() => {
    loadAnalytics();
  }, [loadAnalytics]);

  const selectPeriod = (period: Period) => {
    if (period !== 'custom') {
      setStartDate(null);
      setEndDate(null);
    }
    setSelectedPeriod(period);
    // loadAnalytics fires via the getDateRange dependency change below.
  };

  useEffect(() => {
    if (selectedPeriod !== 'custom' || (startDate && endDate)) {
      loadAnalytics();
    }
  }, [selectedPeriod, startDate, endDate, loadAnalytics]);

  const exportToCSV = () => {
    const { start, end } = getDateRange();
    const range = `${start.toLocaleDateString()} - ${end.toLocaleDateString()}`;
    const lines = [
      'PODSafe Analytics Summary',
      `Date Range,${range}`,
      `Generated,${new Date().toLocaleString()}`,
      '',
      'Metric,Value',
      `Total Deliveries,${stats.total}`,
      `Completed,${stats.completed}`,
      `In Transit,${stats.active}`,
      `Pending,${stats.pending}`,
      `Failed,${stats.failed}`,
      `Completion Rate,${stats.completionRate.toFixed(1)}%`,
      `Avg Delivery Time (hrs),${stats.avgDeliveryTime.toFixed(1)}`,
      `Avg Days to Deliver,${invoice.avgDaysToDeliver.toFixed(1)}`,
      `On-Time Deliveries,${invoice.onTime}`,
      `Late Deliveries,${invoice.late}`,
      `Total Drivers,${driverStats.total}`,
      `Active Drivers,${driverStats.active}`,
      `Total Claims,${claims.total}`,
      `Customers With Claims,${claims.customersWithClaims}`,
      `Trucks In Use,${deliveriesPerTruck.length}`,
      '',
      'Status,Count',
      ...Object.entries(deliveriesByStatus).map(([s, c]) => `${formatStatus(s)},${c}`),
      '',
      'Driver,Deliveries',
      ...topDrivers.map((d) => `${d.name},${d.deliveries}`),
    ];
    Share.share({ title: 'PODSafe Analytics', message: lines.join('\n') }).catch(() => undefined);
  };

  const exportTopDrivers = () => {
    const lines = ['Rank,Driver,Deliveries', ...topDrivers.map((d, i) => `${i + 1},${d.name},${d.deliveries}`)];
    Share.share({ title: 'Top Drivers', message: lines.join('\n') }).catch(() => undefined);
  };

  const buildChartExportText = (): string => {
    const tab = '\t';
    switch (selectedChart) {
      case 'trend':
        return ['Date\tDeliveries', ...Object.entries(dailyDeliveries).map(([k, v]) => `${k}${tab}${v}`)].join('\n');
      case 'status':
        return ['Status\tCount', ...Object.entries(deliveriesByStatus).map(([k, v]) => `${formatStatus(k)}${tab}${v}`)].join('\n');
      case 'drivers':
        return ['Driver\tDeliveries', ...topDrivers.map((d) => `${d.name}${tab}${d.deliveries}`)].join('\n');
      case 'performance':
        return ['Day\tDeliveries', ...performanceMetrics.map((m) => `${m.day}${tab}${m.count}`)].join('\n');
      case 'deliveries':
        return ['Vehicle\tDeliveries', ...deliveriesPerTruck.map((t) => `${t.vehicle}${tab}${t.count}`)].join('\n');
      case 'claims':
        return ['Customer\tType\tDate\tAmount', ...topClaims.map((c) => `${c.customerName}${tab}${formatClaimType(c.type)}${tab}${c.createdAt ? c.createdAt.toLocaleDateString() : '-'}${tab}${c.amount.toFixed(2)}`)].join('\n');
      default:
        return '';
    }
  };

  const showExportDialog = () => {
    Alert.alert('Export Analytics', 'Choose a format', [
      { text: 'CSV', onPress: exportToCSV },
      { text: 'PDF', onPress: () => Alert.alert('Export to PDF', 'Coming soon') },
      { text: 'Cancel', style: 'cancel' },
    ]);
  };

  const showChartExportDialog = () => {
    Alert.alert('Export Chart', 'Choose a format', [
      { text: 'PNG', onPress: () => Alert.alert('Export as Image', 'Coming soon') },
      { text: 'CSV Data', onPress: () => setExportText(buildChartExportText()) },
      { text: 'Share', onPress: () => Alert.alert('Share Chart', 'Coming soon') },
      { text: 'Cancel', style: 'cancel' },
    ]);
  };

  if (!hasPermission(currentUser, 'analyticsView')) {
    return (
      <View style={styles.centered}>
        <Text style={styles.deniedIcon}>🔒</Text>
        <Text style={styles.deniedTitle}>Access Denied</Text>
        <Text style={styles.deniedSubtitle}>You don&apos;t have permission to view analytics</Text>
      </View>
    );
  }

  const podCount = locations.filter((l) => l.type === 'pod').length;
  const claimCount = locations.filter((l) => l.type === 'claim').length;
  const avgDeliveriesPerTruck = deliveriesPerTruck.length > 0 ? stats.total / deliveriesPerTruck.length : 0;
  const tableMinWidth = Math.min(width - 560, 760);

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <View style={styles.headerBarLeft}>
          <Text style={textStyles.heading3}>Analytics &amp; Reports</Text>
          <Text style={styles.desktopBadge}>Desktop</Text>
        </View>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => setShowFilters((v) => !v)}>
            <Text style={styles.headerBarIcon}>⚙</Text>
          </Pressable>
          <Pressable onPress={showExportDialog}>
            <Text style={styles.headerBarIcon}>⬇</Text>
          </Pressable>
          <Pressable onPress={loadAnalytics}>
            <Text style={styles.headerBarIcon}>↻</Text>
          </Pressable>
        </View>
      </View>

      {isLoading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : (
        <View style={styles.bodyRow}>
          {showFilters ? (
            <>
              <FilterSidebar
                selectedPeriod={selectedPeriod}
                selectedChart={selectedChart}
                startDate={startDate}
                endDate={endDate}
                onSelectPeriod={selectPeriod}
                onSelectChart={setSelectedChart}
                onOpenRangePicker={() => setShowRangePicker(true)}
                stats={stats}
                invoice={invoice}
                driverStats={driverStats}
              />
              <View style={styles.verticalDivider} />
            </>
          ) : null}

          <ScrollView
            style={styles.mainColumn}
            contentContainerStyle={styles.mainColumnInner}
            refreshControl={<RefreshControl refreshing={false} onRefresh={loadAnalytics} />}
          >
            <View style={styles.metricsHeader}>
              <Text style={textStyles.heading3}>Metrics</Text>
              <Pressable onPress={() => { LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut); setShowMetrics((v) => !v); }}>
                <Text style={styles.metricsCollapseIcon}>{showMetrics ? '▾' : '▸'}</Text>
              </Pressable>
            </View>

            {showMetrics ? (
              <View style={styles.metricsBlock}>
                <View style={styles.statsBar}>
                  <StatCard label="Total" value={String(stats.total)} icon="🚚" color={colors.primary} />
                  <StatCard label="Completed" value={String(stats.completed)} icon="✓" color={colors.success} />
                  <StatCard label="In Transit" value={String(stats.active)} icon="🚛" color={colors.info} />
                  <StatCard label="Pending" value={String(stats.pending)} icon="⏳" color={colors.warning} />
                  <StatCard label="Completion" value={`${stats.completionRate.toFixed(1)}%`} icon="📈" color={colors.success} />
                </View>
                <View style={styles.sectionDivider} />
                <View style={styles.statsBar}>
                  <StatCard label="Total Claims" value={String(claims.total)} icon="⚠" color="#FF5722" />
                  <StatCard label="Claim Types" value={String(Object.keys(claims.typeCount).length)} icon="🏷" color="#9C27B0" />
                  <StatCard label="Cust. w/ Claims" value={String(claims.customersWithClaims)} icon="👥" color="#FF9800" />
                  <StatCard label="Trucks In Use" value={String(deliveriesPerTruck.length)} icon="🚙" color={colors.accent} />
                  <StatCard label="Avg/Truck" value={avgDeliveriesPerTruck.toFixed(1)} icon="📦" color={colors.primary} />
                </View>
              </View>
            ) : null}

            <Text style={[textStyles.heading3, styles.sectionTitle]}>Charts</Text>
            <View style={styles.chartsGrid}>
              <ChartCard title="Delivery Trend" focused={selectedChart === 'trend'} onPress={() => setSelectedChart('trend')}>
                <DeliveryTrendChart data={dailyDeliveries} />
              </ChartCard>
              <ChartCard title="Status Distribution" focused={selectedChart === 'status'} onPress={() => setSelectedChart('status')}>
                <StatusPieChart data={deliveriesByStatus} />
              </ChartCard>
              <ChartCard title="Top Drivers" focused={selectedChart === 'drivers'} onPress={() => setSelectedChart('drivers')}>
                <TopDriversChart data={topDrivers} />
              </ChartCard>
              <ChartCard title="Weekly Performance" focused={selectedChart === 'performance'} onPress={() => setSelectedChart('performance')}>
                <WeeklyPerformanceChart data={performanceMetrics} />
              </ChartCard>
            </View>

            <View style={styles.sectionSpacer} />

            <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Locations</Text>
            <View style={[styles.card, shadows.card]}>
              <View style={styles.locationsHeader}>
                <Text style={styles.locationsHeaderText}>📍 {locations.length} locations</Text>
                <Text style={[styles.locationsChip, { backgroundColor: `${colors.info}1A`, color: colors.info }]}>📦 {podCount} PODs</Text>
                <Text style={[styles.locationsChip, { backgroundColor: `${colors.error}1A`, color: colors.error }]}>⚠ {claimCount} Claims</Text>
              </View>
              <View style={styles.locationsList}>
                {locations.length === 0 ? (
                  <View style={styles.emptyState}>
                    <Text style={styles.emptyStateIcon}>📍</Text>
                    <Text style={styles.emptyStateText}>No location data available</Text>
                  </View>
                ) : (
                  locations.map((loc, index) => (
                    <Pressable
                      key={loc.id}
                      style={[styles.locationRow, index < locations.length - 1 && styles.locationRowDivider]}
                      onPress={() => Linking.openURL(`https://www.google.com/maps?q=${loc.latitude},${loc.longitude}`)}
                    >
                      <Text style={styles.locationIcon}>{loc.type === 'pod' ? '📦' : '⚠'}</Text>
                      <View style={styles.locationTextBox}>
                        <Text style={styles.locationTitle} numberOfLines={1}>{loc.title}</Text>
                        <Text style={styles.locationSubtitle} numberOfLines={1}>{loc.subtitle}</Text>
                      </View>
                      <Text style={styles.locationMapsLink}>🗺</Text>
                    </Pressable>
                  ))
                )}
              </View>
            </View>

            <View style={styles.sectionSpacer} />

            <TopDriversTable drivers={topDrivers} onExport={exportTopDrivers} minWidth={tableMinWidth} />

            <View style={styles.sectionSpacer} />

            <View style={styles.twoColumnTables}>
              <View style={styles.twoColumnCell}>
                <DeliveriesPerTruckTable entries={deliveriesPerTruck} minWidth={Math.min(tableMinWidth, 360)} />
              </View>
              <View style={styles.twoColumnCell}>
                <TopClaimsTable claims={topClaims} total={claims.total} minWidth={Math.min(tableMinWidth, 360)} />
              </View>
            </View>

            <View style={styles.sectionSpacer} />

            <TopClaimTypesTable typeCount={claims.typeCount} minWidth={tableMinWidth} />

            <View style={styles.sectionSpacer} />

            <TopCustomerDeliveriesTable entries={topCustomerDeliveries} minWidth={tableMinWidth} />
          </ScrollView>

          {selectedChart !== 'none' ? (
            <>
              <View style={styles.verticalDivider} />
              <ChartDetailsPanel
                focus={selectedChart}
                asTable={showChartAsTable}
                onToggleTable={() => setShowChartAsTable((v) => !v)}
                onExport={showChartExportDialog}
                onClose={() => setSelectedChart('none')}
                stats={stats}
                invoice={invoice}
                driverStats={driverStats}
                dailyDeliveries={dailyDeliveries}
                deliveriesByStatus={deliveriesByStatus}
                topDrivers={topDrivers}
                performanceMetrics={performanceMetrics}
                deliveriesPerTruck={deliveriesPerTruck}
                topClaims={topClaims}
                claims={claims}
                minWidth={300}
              />
            </>
          ) : null}
        </View>
      )}

      <RangeCalendarPicker
        visible={showRangePicker}
        startDate={startDate}
        endDate={endDate}
        onConfirm={(s, e) => {
          setStartDate(s);
          setEndDate(e);
          setShowRangePicker(false);
        }}
        onClear={() => {
          setStartDate(null);
          setEndDate(null);
          setShowRangePicker(false);
        }}
        onClose={() => setShowRangePicker(false)}
      />

      <ExportTextModal text={exportText} onClose={() => setExportText(null)} />
    </View>
  );
}

/* -------------------------------------------------------------------------- */
/* Filter sidebar                                                              */
/* -------------------------------------------------------------------------- */

interface FilterSidebarProps {
  selectedPeriod: Period;
  selectedChart: ChartFocus | 'none';
  startDate: Date | null;
  endDate: Date | null;
  onSelectPeriod: (p: Period) => void;
  onSelectChart: (c: ChartFocus) => void;
  onOpenRangePicker: () => void;
  stats: DeliveryStats;
  invoice: InvoiceMetrics;
  driverStats: { total: number; active: number };
}

const PERIODS: { key: Period; label: string }[] = [
  { key: 'week', label: 'Week' },
  { key: 'month', label: 'Month' },
  { key: 'quarter', label: 'Quarter' },
  { key: 'year', label: 'Year' },
  { key: 'custom', label: 'Custom' },
];

const CHART_FOCI: { key: ChartFocus; icon: string; label: string; badge: string }[] = [
  { key: 'trend', icon: '📈', label: 'Delivery Trend', badge: '1' },
  { key: 'status', icon: '🥧', label: 'Status', badge: '2' },
  { key: 'drivers', icon: '👤', label: 'Top Drivers', badge: '3' },
  { key: 'performance', icon: '📊', label: 'Weekly Perf', badge: '4' },
  { key: 'deliveries', icon: '🚚', label: 'Deliveries/Truck', badge: '5' },
  { key: 'claims', icon: '⚠', label: 'Claims', badge: '6' },
];

function FilterSidebar(props: FilterSidebarProps) {
  const { selectedPeriod, selectedChart, startDate, endDate, onSelectPeriod, onSelectChart, onOpenRangePicker, stats, invoice, driverStats } = props;
  const successRate = stats.total > 0 ? (stats.completed / stats.total) * 100 : 0;
  return (
    <View style={styles.filterSidebar}>
      <ScrollView contentContainerStyle={styles.filterSidebarInner}>
        <Text style={textStyles.heading3}>Filters</Text>

        <Text style={styles.sidebarSectionTitle}>Time Period</Text>
        {PERIODS.map((p) => (
          <Pressable key={p.key} style={styles.periodButton} onPress={() => onSelectPeriod(p.key)}>
            <View style={[styles.periodDot, selectedPeriod === p.key && styles.periodDotSelected]} />
            <Text style={[styles.periodLabel, selectedPeriod === p.key && styles.periodLabelSelected]}>{p.label}</Text>
          </Pressable>
        ))}

        {selectedPeriod === 'custom' ? (
          <View style={styles.customRangeBox}>
            <Pressable style={styles.customRangeButton} onPress={onOpenRangePicker}>
              <Text style={styles.customRangeText}>
                {startDate && endDate
                  ? `${startDate.toLocaleDateString()} → ${endDate.toLocaleDateString()}`
                  : 'Select date range'}
              </Text>
            </Pressable>
          </View>
        ) : null}

        <Text style={[styles.sidebarSectionTitle, { marginTop: spacing.medium }]}>Chart Focus</Text>
        {CHART_FOCI.map((c) => (
          <Pressable
            key={c.key}
            style={[styles.chartFocusButton, selectedChart === c.key && styles.chartFocusButtonSelected]}
            onPress={() => onSelectChart(c.key)}
          >
            <Text style={styles.chartFocusIcon}>{c.icon}</Text>
            <Text style={[styles.chartFocusLabel, selectedChart === c.key && styles.chartFocusLabelSelected]}>{c.label}</Text>
            <Text style={styles.chartFocusBadge}>{c.badge}</Text>
          </Pressable>
        ))}

        <Text style={[styles.sidebarSectionTitle, { marginTop: spacing.medium }]}>Quick Stats</Text>
        <View style={styles.quickStatsPanel}>
          <StatRow label="Success Rate" value={`${successRate.toFixed(1)}%`} />
          <StatRow label="Avg Delivery Time" value={`${stats.avgDeliveryTime.toFixed(1)} hrs`} />
          <StatRow label="Active Drivers" value={String(driverStats.active)} />
          <StatRow label="Failed Deliveries" value={String(stats.failed)} />
          <View style={styles.sectionDivider} />
          <StatRow label="Avg Days to Deliver" value={invoice.avgDaysToDeliver.toFixed(1)} />
          <StatRow label="On-Time" value={String(invoice.onTime)} />
          <StatRow label="Late" value={String(invoice.late)} />
        </View>
      </ScrollView>
    </View>
  );
}

function StatRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statRow}>
      <Text style={styles.statRowLabel}>{label}</Text>
      <Text style={styles.statRowValue}>{value}</Text>
    </View>
  );
}

/* -------------------------------------------------------------------------- */
/* Stat card (desktop)                                                         */
/* -------------------------------------------------------------------------- */

function StatCard({ label, value, icon, color }: { label: string; value: string; icon: string; color: string }) {
  return (
    <View style={[styles.statCard, shadows.card]}>
      <View style={[styles.statCardIconBox, { backgroundColor: `${color}1A` }]}>
        <Text style={[styles.statCardIcon, { color }]}>{icon}</Text>
      </View>
      <Text style={[styles.statCardValue, { color }]}>{value}</Text>
      <Text style={styles.statCardLabel}>{label}</Text>
    </View>
  );
}

/* -------------------------------------------------------------------------- */
/* Chart cards + charts                                                        */
/* -------------------------------------------------------------------------- */

function ChartCard({ title, focused, onPress, children }: { title: string; focused: boolean; onPress: () => void; children: React.ReactNode }) {
  return (
    <Pressable style={[styles.card, styles.chartCard, shadows.card, focused && styles.chartCardFocused]} onPress={onPress}>
      <View style={styles.chartCardHeader}>
        <Text style={styles.chartCardTitle}>{title}</Text>
        {focused ? <Text style={styles.chartCardBadge}>FOCUSED</Text> : null}
      </View>
      <View style={styles.chartBody}>{children}</View>
    </Pressable>
  );
}

function EmptyChart({ icon, text }: { icon: string; text: string }) {
  return (
    <View style={styles.emptyState}>
      <Text style={styles.emptyStateIcon}>{icon}</Text>
      <Text style={styles.emptyStateText}>{text}</Text>
    </View>
  );
}

function DeliveryTrendChart({ data }: { data: Record<string, number> }) {
  const entries = Object.entries(data).slice(0, 10);
  const chartData = entries.map(([label, value]) => ({ value, label }));
  if (chartData.length === 0) return <EmptyChart icon="📈" text="No delivery data available" />;
  return (
    <LineChart
      data={chartData}
      height={170}
      color={colors.primary}
      thickness={3}
      curved
      areaChart
      startFillColor={colors.primary}
      endFillColor={colors.primary}
      startOpacity={0.2}
      endOpacity={0.02}
      dataPointsColor={colors.primary}
      yAxisTextStyle={styles.chartAxisText}
      xAxisLabelTextStyle={styles.chartAxisText}
      rulesColor={colors.divider}
      xAxisColor={colors.divider}
      yAxisColor={colors.divider}
      noOfSections={4}
      initialSpacing={12}
    />
  );
}

function StatusPieChart({ data }: { data: Record<string, number> }) {
  const entries = Object.entries(data);
  const total = entries.reduce((a, [, v]) => a + v, 0);
  if (entries.length === 0 || total === 0) return <EmptyChart icon="🥧" text="No status data available" />;
  const pieData = entries.map(([status, count]) => ({ value: count, color: statusColor(status) }));
  return (
    <View style={styles.pieBlock}>
      <PieChart data={pieData} radius={70} donut innerRadius={42} focusOnPress backgroundColor={colors.card} strokeColor={colors.card} />
      <View style={styles.legendWrap}>
        {entries.map(([status, count]) => {
          const pct = total > 0 ? (count / total) * 100 : 0;
          return (
            <View key={status} style={styles.legendItem}>
              <View style={[styles.legendDot, { backgroundColor: statusColor(status) }]} />
              <Text style={styles.legendText}>{formatStatus(status)}: {count} ({pct.toFixed(0)}%)</Text>
            </View>
          );
        })}
      </View>
    </View>
  );
}

function TopDriversChart({ data }: { data: TopDriver[] }) {
  const top5 = data.slice(0, 5);
  if (top5.length === 0) return <EmptyChart icon="👥" text="No driver performance data yet" />;
  const maxVal = Math.max(...top5.map((d) => d.deliveries), 1);
  const chartData = top5.map((d, i) => ({
    value: d.deliveries,
    label: firstName(d.name),
    frontColor: i === 0 ? colors.warning : colors.primary,
    gradientColor: i === 0 ? '#F6C342' : colors.accent,
    showGradient: true,
    labelTextStyle: styles.chartAxisText,
  }));
  return (
    <BarChart
      data={chartData}
      height={170}
      barWidth={28}
      spacing={18}
      noOfSections={4}
      maxValue={Math.ceil(maxVal)}
      yAxisTextStyle={styles.chartAxisText}
      xAxisColor={colors.divider}
      yAxisColor={colors.divider}
      rulesColor={colors.divider}
      initialSpacing={12}
    />
  );
}

function WeeklyPerformanceChart({ data }: { data: PerformanceMetric[] }) {
  if (data.length === 0 || data.every((m) => m.count === 0)) return <EmptyChart icon="📊" text="No performance data available" />;
  const maxVal = Math.max(...data.map((m) => m.count), 1);
  const chartData = data.map((m) => ({
    value: m.count,
    label: m.day,
    frontColor: colors.success,
    gradientColor: '#66BB6A',
    showGradient: true,
    labelTextStyle: styles.chartAxisText,
  }));
  return (
    <BarChart
      data={chartData}
      height={170}
      barWidth={24}
      spacing={14}
      noOfSections={4}
      maxValue={Math.ceil(maxVal)}
      yAxisTextStyle={styles.chartAxisText}
      xAxisColor={colors.divider}
      yAxisColor={colors.divider}
      rulesColor={colors.divider}
      initialSpacing={12}
    />
  );
}

/* -------------------------------------------------------------------------- */
/* Tables                                                                      */
/* -------------------------------------------------------------------------- */

interface Column {
  key: string;
  label: string;
  width: number;
  render?: (row: Record<string, unknown>) => React.ReactNode;
}

function DataTable({ columns, rows, minWidth }: { columns: Column[]; rows: Record<string, unknown>[]; minWidth: number }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false}>
      <View style={{ minWidth }}>
        <View style={styles.tableHeader}>
          {columns.map((c) => (
            <Text key={c.key} style={[styles.tableHeaderCell, { width: c.width }]}>{c.label}</Text>
          ))}
        </View>
        {rows.length === 0 ? (
          <Text style={styles.tableEmpty}>No data</Text>
        ) : (
          rows.map((row, i) => (
            <View key={i} style={[styles.tableRow, i < rows.length - 1 && styles.tableRowDivider]}>
              {columns.map((c) => (
                <Text key={c.key} style={[styles.tableCell, { width: c.width }]} numberOfLines={1}>
                  {c.render ? c.render(row) : (row[c.key] as React.ReactNode)}
                </Text>
              ))}
            </View>
          ))
        )}
      </View>
    </ScrollView>
  );
}

function TableCard({ title, action, children }: { title: string; action?: React.ReactNode; children: React.ReactNode }) {
  return (
    <View style={[styles.card, shadows.card]}>
      <View style={styles.tableCardHeader}>
        <Text style={textStyles.heading3}>{title}</Text>
        {action ?? null}
      </View>
      {children}
    </View>
  );
}

function medalFor(rank: number): string {
  if (rank === 1) return '🥇';
  if (rank === 2) return '🥈';
  if (rank === 3) return '🥉';
  return `${rank}`;
}

function badgeFor(rank: number, total: number): { text: string; color: string } {
  if (rank === 1) return { text: 'Champion', color: colors.warning };
  if (rank <= 3) return { text: 'Top 3', color: colors.success };
  if (rank <= 5) return { text: 'Top 5', color: colors.primary };
  return { text: total > 5 ? 'Active' : 'Top', color: colors.info };
}

function TopDriversTable({ drivers, onExport, minWidth }: { drivers: TopDriver[]; onExport: () => void; minWidth: number }) {
  return (
    <TableCard
      title="Top Performers"
      action={
        <Pressable onPress={onExport}>
          <Text style={styles.tableExportLink}>⬇ Export</Text>
        </Pressable>
      }
    >
      {drivers.length === 0 ? (
        <Text style={styles.tableEmpty}>No driver performance data yet</Text>
      ) : (
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View style={{ minWidth }}>
            <View style={styles.tableHeader}>
              <Text style={[styles.tableHeaderCell, styles.colRank]}>Rank</Text>
              <Text style={[styles.tableHeaderCell, styles.colDriver]}>Driver</Text>
              <Text style={[styles.tableHeaderCell, styles.colDeliveries]}>Deliveries</Text>
              <Text style={[styles.tableHeaderCell, styles.colBadge]}>Badge</Text>
            </View>
            {drivers.map((d, i) => {
              const rank = i + 1;
              const badge = badgeFor(rank, drivers.length);
              return (
                <View key={d.id} style={[styles.tableRow, i < drivers.length - 1 && styles.tableRowDivider]}>
                  <Text style={[styles.tableCell, styles.colRank]}>{medalFor(rank)}</Text>
                  <Text style={[styles.tableCell, styles.colDriver]} numberOfLines={1}>{d.name}</Text>
                  <Text style={[styles.tableCell, styles.colDeliveries]}>{d.deliveries}</Text>
                  <View style={[styles.driverBadge, styles.colBadge, { backgroundColor: `${badge.color}1A` }]}>
                    <Text style={[styles.driverBadgeText, { color: badge.color }]}>{badge.text}</Text>
                  </View>
                </View>
              );
            })}
          </View>
        </ScrollView>
      )}
    </TableCard>
  );
}

function DeliveriesPerTruckTable({ entries, minWidth }: { entries: TruckEntry[]; minWidth: number }) {
  const rows = entries.map((e) => ({ vehicle: e.vehicle, count: e.count }));
  return (
    <TableCard title="Deliveries Per Truck">
      <DataTable
        columns={[
          { key: 'vehicle', label: 'Vehicle', width: minWidth * 0.6 },
          { key: 'count', label: 'Deliveries', width: minWidth * 0.35 },
        ]}
        rows={rows}
        minWidth={minWidth}
      />
    </TableCard>
  );
}

function TopClaimsTable({ claims: rows, total, minWidth }: { claims: ClaimRow[]; total: number; minWidth: number }) {
  return (
    <TableCard title={`Top Claims (${rows.length} recent / ${total} total)`}>
      {rows.length === 0 ? (
        <Text style={styles.tableEmpty}>No claims data</Text>
      ) : (
        <DataTable
          columns={[
            { key: 'customer', label: 'Customer', width: minWidth * 0.4, render: (r) => `${r.customerName as string} (${r.customerNumber as string})` },
            { key: 'reason', label: 'Reason', width: minWidth * 0.3, render: (r) => formatClaimType(r.type as string) },
            { key: 'date', label: 'Date', width: minWidth * 0.25, render: (r) => (r.createdAt as Date | null) ? (r.createdAt as Date).toLocaleDateString() : '-' },
          ]}
          rows={rows as unknown as Record<string, unknown>[]}
          minWidth={minWidth}
        />
      )}
    </TableCard>
  );
}

function TopClaimTypesTable({ typeCount, minWidth }: { typeCount: Record<string, number>; minWidth: number }) {
  const rows = Object.entries(typeCount)
    .map(([type, count]) => ({ type, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8);
  return (
    <TableCard title="Top Claim Types">
      <DataTable
        columns={[
          { key: 'type', label: 'Claim Type', width: minWidth * 0.6, render: (r) => formatClaimType(r.type as string) },
          { key: 'count', label: 'Count', width: minWidth * 0.3 },
        ]}
        rows={rows as unknown as Record<string, unknown>[]}
        minWidth={minWidth}
      />
    </TableCard>
  );
}

function TopCustomerDeliveriesTable({ entries, minWidth }: { entries: CustomerDeliveries[]; minWidth: number }) {
  return (
    <TableCard title="Top Customers by Deliveries">
      {entries.length === 0 ? (
        <Text style={styles.tableEmpty}>No customer delivery data</Text>
      ) : (
        <DataTable
          columns={[
            { key: 'customerNumber', label: 'Cust #', width: minWidth * 0.25 },
            { key: 'customerName', label: 'Customer', width: minWidth * 0.45 },
            { key: 'count', label: 'Deliveries', width: minWidth * 0.25 },
          ]}
          rows={entries as unknown as Record<string, unknown>[]}
          minWidth={minWidth}
        />
      )}
    </TableCard>
  );
}

/* -------------------------------------------------------------------------- */
/* Chart details side panel                                                    */
/* -------------------------------------------------------------------------- */

interface ChartDetailsPanelProps {
  focus: ChartFocus | 'none';
  asTable: boolean;
  onToggleTable: () => void;
  onExport: () => void;
  onClose: () => void;
  stats: DeliveryStats;
  invoice: InvoiceMetrics;
  driverStats: { total: number; active: number };
  dailyDeliveries: Record<string, number>;
  deliveriesByStatus: Record<string, number>;
  topDrivers: TopDriver[];
  performanceMetrics: PerformanceMetric[];
  deliveriesPerTruck: TruckEntry[];
  topClaims: ClaimRow[];
  claims: ClaimsSummary;
  minWidth: number;
}

function ChartDetailsPanel(props: ChartDetailsPanelProps) {
  const { focus, asTable, onToggleTable, onExport, onClose } = props;
  const meta = CHART_FOCI.find((c) => c.key === focus);
  return (
    <View style={styles.detailsPanel}>
      <View style={styles.detailsHeader}>
        <Text style={styles.detailsHeaderIcon}>{meta?.icon ?? '📊'}</Text>
        <Text style={styles.detailsHeaderTitle}>{meta?.label ?? 'Chart'}</Text>
        <View style={styles.detailsHeaderActions}>
          <Pressable onPress={onToggleTable}>
            <Text style={styles.detailsHeaderIcon}>{asTable ? '📊' : '📋'}</Text>
          </Pressable>
          <Pressable onPress={onExport}>
            <Text style={styles.detailsHeaderIcon}>⬇</Text>
          </Pressable>
          <Pressable onPress={onClose}>
            <Text style={styles.detailsHeaderIcon}>✕</Text>
          </Pressable>
        </View>
      </View>
      <ScrollView style={styles.detailsBody} contentContainerStyle={styles.detailsBodyInner}>
        <ChartDetailsContent {...props} />
      </ScrollView>
    </View>
  );
}

function ChartDetailsContent(props: ChartDetailsPanelProps): React.ReactNode {
  const { focus, asTable, minWidth } = props;
  if (asTable) {
    switch (focus) {
      case 'trend':
        return (
          <DataTable
            columns={[
              { key: 'date', label: 'Date', width: minWidth * 0.6 },
              { key: 'count', label: 'Deliveries', width: minWidth * 0.3 },
            ]}
            rows={Object.entries(props.dailyDeliveries).map(([date, count]) => ({ date, count }))}
            minWidth={minWidth}
          />
        );
      case 'status': {
        const total = Object.values(props.deliveriesByStatus).reduce((a, b) => a + b, 0);
        return (
          <DataTable
            columns={[
              { key: 'status', label: 'Status', width: minWidth * 0.4, render: (r) => formatStatus(r.status as string) },
              { key: 'count', label: 'Count', width: minWidth * 0.2 },
              { key: 'pct', label: '%', width: minWidth * 0.2, render: (r) => `${total > 0 ? ((r.count as number) / total) * 100 : 0}` },
            ]}
            rows={Object.entries(props.deliveriesByStatus).map(([status, count]) => ({ status, count }))}
            minWidth={minWidth}
          />
        );
      }
      case 'drivers':
        return (
          <DataTable
            columns={[
              { key: 'name', label: 'Driver', width: minWidth * 0.6 },
              { key: 'deliveries', label: 'Deliveries', width: minWidth * 0.3 },
            ]}
            rows={props.topDrivers as unknown as Record<string, unknown>[]}
            minWidth={minWidth}
          />
        );
      case 'performance':
        return (
          <DataTable
            columns={[
              { key: 'day', label: 'Day', width: minWidth * 0.5 },
              { key: 'count', label: 'Deliveries', width: minWidth * 0.4 },
            ]}
            rows={props.performanceMetrics as unknown as Record<string, unknown>[]}
            minWidth={minWidth}
          />
        );
      case 'deliveries':
        return (
          <DataTable
            columns={[
              { key: 'vehicle', label: 'Vehicle', width: minWidth * 0.6 },
              { key: 'count', label: 'Deliveries', width: minWidth * 0.3 },
            ]}
            rows={props.deliveriesPerTruck as unknown as Record<string, unknown>[]}
            minWidth={minWidth}
          />
        );
      case 'claims':
        return (
          <DataTable
            columns={[
              { key: 'customer', label: 'Customer', width: minWidth * 0.4, render: (r) => r.customerName as string },
              { key: 'type', label: 'Type', width: minWidth * 0.3, render: (r) => formatClaimType(r.type as string) },
              { key: 'amount', label: 'Amount', width: minWidth * 0.25, render: (r) => `R${(r.amount as number).toFixed(2)}` },
            ]}
            rows={props.topClaims as unknown as Record<string, unknown>[]}
            minWidth={minWidth}
          />
        );
      default:
        return null;
    }
  }
  switch (focus) {
    case 'trend':
      return (
        <View>
          <DetailRow label="Total Deliveries" value={String(props.stats.total)} />
          <DetailRow label="Completed" value={String(props.stats.completed)} />
          <DetailRow label="Completion Rate" value={`${props.stats.completionRate.toFixed(1)}%`} />
          <DetailRow label="Avg Delivery Time" value={`${props.stats.avgDeliveryTime.toFixed(1)} hrs`} />
          <Text style={styles.detailBullets}>
            {'\n'}• Trend tracks deliveries scheduled in the selected period.{'\n'}• Tap the chart to focus this panel.
          </Text>
        </View>
      );
    case 'status': {
      const total = Object.values(props.deliveriesByStatus).reduce((a, b) => a + b, 0);
      return (
        <View>
          {Object.entries(props.deliveriesByStatus).map(([status, count]) => (
            <StatusDetailRow key={status} status={status} count={count} total={total} />
          ))}
          {Object.keys(props.deliveriesByStatus).length === 0 ? <Text style={styles.tableEmpty}>No status data</Text> : null}
        </View>
      );
    }
    case 'drivers':
      return (
        <View>
          <DetailRow label="Top 10 Drivers" value={String(props.topDrivers.length)} />
          {props.topDrivers.slice(0, 5).map((d, i) => (
            <DetailRow key={d.id} label={`${medalFor(i + 1)} ${d.name}`} value={`${d.deliveries} deliveries`} />
          ))}
          {props.topDrivers.length === 0 ? <Text style={styles.tableEmpty}>No driver data</Text> : null}
        </View>
      );
    case 'performance': {
      const peak = [...props.performanceMetrics].sort((a, b) => b.count - a.count)[0];
      return (
        <View>
          {props.performanceMetrics.map((m) => (
            <DetailRow key={m.day} label={m.day} value={String(m.count)} />
          ))}
          {peak ? <Text style={styles.detailBullets}>{'\n'}• Peak day: {peak.day} ({peak.count} deliveries)</Text> : null}
        </View>
      );
    }
    case 'deliveries': {
      const top = props.deliveriesPerTruck[0];
      return (
        <View>
          <DetailRow label="Trucks In Use" value={String(props.deliveriesPerTruck.length)} />
          <DetailRow label="Avg Deliveries/Truck" value={(props.stats.total / Math.max(props.deliveriesPerTruck.length, 1)).toFixed(1)} />
          {props.deliveriesPerTruck.slice(0, 5).map((t) => (
            <DetailRow key={t.vehicle} label={t.vehicle} value={String(t.count)} />
          ))}
          {top ? <Text style={styles.detailBullets}>{'\n'}• Top truck: {top.vehicle} ({top.count} deliveries)</Text> : null}
        </View>
      );
    }
    case 'claims':
      return (
        <View>
          <DetailRow label="Total Claims" value={String(props.claims.total)} />
          <DetailRow label="Customers w/ Claims" value={String(props.claims.customersWithClaims)} />
          <DetailRow label="Claim Types" value={String(Object.keys(props.claims.typeCount).length)} />
          <Text style={[styles.sidebarSectionTitle, { marginTop: spacing.small }]}>Top Types</Text>
          {Object.entries(props.claims.typeCount)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([type, count]) => (
              <DetailRow key={type} label={formatClaimType(type)} value={String(count)} />
            ))}
          <Text style={[styles.sidebarSectionTitle, { marginTop: spacing.small }]}>Recent Claims</Text>
          {props.topClaims.slice(0, 5).map((c) => (
            <DetailRow key={c.id} label={`${c.customerName} • ${formatClaimType(c.type)}`} value={`R${c.amount.toFixed(2)}`} />
          ))}
          {props.topClaims.length === 0 ? <Text style={styles.tableEmpty}>No claims data</Text> : null}
        </View>
      );
    default:
      return null;
  }
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailRowLabel} numberOfLines={1}>{label}</Text>
      <Text style={styles.detailRowValue}>{value}</Text>
    </View>
  );
}

function StatusDetailRow({ status, count, total }: { status: string; count: number; total: number }) {
  const pct = total > 0 ? (count / total) * 100 : 0;
  return (
    <View style={styles.detailRow}>
      <View style={styles.statusDetailLeft}>
        <View style={[styles.legendDot, { backgroundColor: statusColor(status) }]} />
        <Text style={styles.detailRowLabel}>{formatStatus(status)}</Text>
      </View>
      <Text style={styles.detailRowValue}>{count} ({pct.toFixed(0)}%)</Text>
    </View>
  );
}

/* -------------------------------------------------------------------------- */
/* Range calendar picker (Modal, no date-picker dep)                           */
/* -------------------------------------------------------------------------- */

interface RangeCalendarPickerProps {
  visible: boolean;
  startDate: Date | null;
  endDate: Date | null;
  onConfirm: (start: Date, end: Date) => void;
  onClear: () => void;
  onClose: () => void;
}

const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const MIN_DATE = new Date(2020, 0, 1);

function RangeCalendarPicker(props: RangeCalendarPickerProps) {
  const { visible, startDate, endDate, onConfirm, onClear, onClose } = props;
  const [viewMonth, setViewMonth] = useState(() => {
    const d = startDate ?? new Date();
    return new Date(d.getFullYear(), d.getMonth(), 1);
  });
  const [pendingStart, setPendingStart] = useState<Date | null>(startDate);
  const [pendingEnd, setPendingEnd] = useState<Date | null>(endDate);

  useEffect(() => {
    if (visible) {
      const d = startDate ?? new Date();
      setViewMonth(new Date(d.getFullYear(), d.getMonth(), 1));
      setPendingStart(startDate);
      setPendingEnd(endDate);
    }
  }, [visible, startDate, endDate]);

  const today = new Date();
  today.setHours(23, 59, 59, 999);

  const shiftMonth = (delta: number) => {
    const next = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + delta, 1);
    if (next < MIN_DATE) return;
    if (next > new Date(today.getFullYear(), today.getMonth(), 1)) return;
    setViewMonth(next);
  };

  const pickDay = (day: Date) => {
    if (!pendingStart || (pendingStart && pendingEnd)) {
      setPendingStart(day);
      setPendingEnd(null);
      return;
    }
    if (day.getTime() < pendingStart.getTime()) {
      setPendingStart(day);
    } else {
      setPendingEnd(day);
    }
  };

  const firstOfMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth(), 1);
  const startWeekday = (firstOfMonth.getDay() + 6) % 7; // Mon=0
  const daysInMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 0).getDate();
  const cells: (Date | null)[] = [];
  for (let i = 0; i < startWeekday; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(viewMonth.getFullYear(), viewMonth.getMonth(), d));

  const inRange = (day: Date) => {
    if (!pendingStart || !pendingEnd) return false;
    return day.getTime() >= pendingStart.getTime() && day.getTime() <= pendingEnd.getTime();
  };
  const isStart = (day: Date) => !!pendingStart && day.toDateString() === pendingStart.toDateString();
  const isEnd = (day: Date) => !!pendingEnd && day.toDateString() === pendingEnd.toDateString();
  const isDisabled = (day: Date) => day < MIN_DATE || day > today;

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.calendarCard, shadows.card]}>
          <View style={styles.calendarHeader}>
            <Pressable onPress={() => shiftMonth(-1)}>
              <Text style={styles.calendarNav}>‹</Text>
            </Pressable>
            <Text style={textStyles.heading3}>{MONTH_NAMES[viewMonth.getMonth()]} {viewMonth.getFullYear()}</Text>
            <Pressable onPress={() => shiftMonth(1)}>
              <Text style={styles.calendarNav}>›</Text>
            </Pressable>
          </View>
          <View style={styles.calendarWeekHeader}>
            {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => (
              <Text key={i} style={styles.calendarWeekDay}>{d}</Text>
            ))}
          </View>
          <View style={styles.calendarGrid}>
            {cells.map((day, i) => {
              if (!day) return <View key={i} style={styles.calendarDay} />;
              const disabled = isDisabled(day);
              const selected = isStart(day) || isEnd(day);
              const range = inRange(day);
              return (
                <Pressable
                  key={i}
                  disabled={disabled}
                  onPress={() => pickDay(day)}
                  style={[
                    styles.calendarDay,
                    selected && styles.calendarDaySelected,
                    range && styles.calendarDayRange,
                    disabled && styles.calendarDayDim,
                  ]}
                >
                  <Text style={[styles.calendarDayText, (selected || range) && styles.calendarDayTextSelected]}>{day.getDate()}</Text>
                </Pressable>
              );
            })}
          </View>
          <Text style={styles.calendarRangeLabel}>
            {pendingStart ? pendingStart.toLocaleDateString() : 'Start'} → {pendingEnd ? pendingEnd.toLocaleDateString() : 'End'}
          </Text>
          <View style={styles.calendarActions}>
            <Pressable style={styles.calendarClearButton} onPress={onClear}>
              <Text style={styles.calendarClearText}>Clear</Text>
            </Pressable>
            <Pressable style={styles.modalCloseButton} onPress={onClose}>
              <Text style={textStyles.buttonText}>Cancel</Text>
            </Pressable>
            <Pressable
              style={[styles.modalCloseButton, (!pendingStart || !pendingEnd) && styles.calendarOkDisabled]}
              onPress={() => {
                if (pendingStart && pendingEnd) onConfirm(pendingStart, pendingEnd);
                else if (pendingStart) onConfirm(pendingStart, pendingStart);
              }}
            >
              <Text style={textStyles.buttonText}>OK</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

/* -------------------------------------------------------------------------- */
/* Export text modal (CSV-data view + real copy)                               */
/* -------------------------------------------------------------------------- */

function ExportTextModal({ text, onClose }: { text: string | null; onClose: () => void }) {
  return (
    <Modal visible={text != null} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.exportTextCard, shadows.card]}>
          <Text style={textStyles.heading3}>Chart Data</Text>
          <ScrollView style={styles.exportTextScroll}>
            <Text selectable style={styles.exportTextContent}>{text ?? ''}</Text>
          </ScrollView>
          <View style={styles.calendarActions}>
            <Pressable
              style={styles.modalCloseButton}
              onPress={() => {
                if (text) Clipboard.setString(text);
                Alert.alert('Copied', 'Chart data copied to clipboard.');
              }}
            >
              <Text style={textStyles.buttonText}>Copy</Text>
            </Pressable>
            <Pressable style={styles.modalCloseButton} onPress={onClose}>
              <Text style={textStyles.buttonText}>Close</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

/* -------------------------------------------------------------------------- */
/* Styles                                                                      */
/* -------------------------------------------------------------------------- */

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background, padding: spacing.large },
  deniedIcon: { fontSize: 56 },
  deniedTitle: { fontSize: 22, fontWeight: 'bold', marginTop: spacing.medium },
  deniedSubtitle: { color: colors.textSecondary, marginTop: spacing.small },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  headerBarLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.small + 4 },
  desktopBadge: { color: colors.white, fontSize: 11, fontWeight: '700', opacity: 0.8, borderWidth: 1, borderColor: colors.white, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 },
  headerBarRight: { flexDirection: 'row', gap: spacing.medium },
  headerBarIcon: { fontSize: 18, color: colors.white },
  bodyRow: { flex: 1, flexDirection: 'row' },
  verticalDivider: { width: 1, height: '100%', backgroundColor: colors.divider },
  filterSidebar: { width: 280, backgroundColor: colors.card },
  filterSidebarInner: { padding: spacing.medium },
  sidebarSectionTitle: { fontSize: 12, fontWeight: '700', color: colors.textSecondary, marginTop: spacing.medium, marginBottom: spacing.small, textTransform: 'uppercase' },
  periodButton: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small },
  periodDot: { width: 14, height: 14, borderRadius: 7, borderWidth: 2, borderColor: colors.divider, marginRight: spacing.small + 4 },
  periodDotSelected: { backgroundColor: colors.primary, borderColor: colors.primary },
  periodLabel: { fontSize: 14, color: colors.textPrimary },
  periodLabelSelected: { color: colors.primary, fontWeight: '700' },
  customRangeBox: { marginTop: spacing.small },
  customRangeButton: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, alignItems: 'center' },
  customRangeText: { fontSize: 12, color: colors.primary, fontWeight: '600' },
  chartFocusButton: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small, paddingHorizontal: spacing.small, borderRadius: radii.borderRadius, marginBottom: 4 },
  chartFocusButtonSelected: { backgroundColor: `${colors.primary}1A` },
  chartFocusIcon: { fontSize: 16, marginRight: spacing.small + 4, width: 22, textAlign: 'center' },
  chartFocusLabel: { flex: 1, fontSize: 13, color: colors.textPrimary },
  chartFocusLabelSelected: { color: colors.primary, fontWeight: '700' },
  chartFocusBadge: { fontSize: 10, color: colors.textSecondary, borderWidth: 1, borderColor: colors.divider, borderRadius: 4, paddingHorizontal: 4, paddingVertical: 1 },
  quickStatsPanel: { backgroundColor: colors.background, borderRadius: radii.borderRadius, padding: spacing.small + 4, marginTop: spacing.small },
  statRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4 },
  statRowLabel: { fontSize: 12, color: colors.textSecondary },
  statRowValue: { fontSize: 12, fontWeight: '700', color: colors.textPrimary },
  mainColumn: { flex: 1 },
  mainColumnInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  metricsHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small },
  metricsCollapseIcon: { fontSize: 18, color: colors.textSecondary },
  metricsBlock: { marginBottom: spacing.medium },
  statsBar: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium, marginVertical: spacing.small },
  statCard: { width: 150, backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium },
  statCardIconBox: { width: 36, height: 36, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center' },
  statCardIcon: { fontSize: 16 },
  statCardValue: { fontSize: 22, fontWeight: 'bold', marginTop: spacing.small },
  statCardLabel: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  sectionDivider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small },
  sectionTitle: { marginTop: spacing.small, marginBottom: spacing.small + 4 },
  sectionSpacer: { height: spacing.large },
  chartsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium },
  chartCard: { width: '48%', minWidth: 340, padding: spacing.medium },
  chartCardFocused: { borderWidth: 2, borderColor: colors.primary },
  chartCardHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small },
  chartCardTitle: { fontSize: 14, fontWeight: '700', color: colors.textPrimary },
  chartCardBadge: { fontSize: 9, fontWeight: '700', color: colors.white, backgroundColor: colors.primary, borderRadius: 4, paddingHorizontal: 5, paddingVertical: 1 },
  chartBody: { alignItems: 'center', justifyContent: 'center', minHeight: 190 },
  chartAxisText: { fontSize: 9, color: colors.textSecondary },
  pieBlock: { alignItems: 'center' },
  legendWrap: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', marginTop: spacing.small, gap: 6 },
  legendItem: { flexDirection: 'row', alignItems: 'center', marginHorizontal: 4 },
  legendDot: { width: 10, height: 10, borderRadius: 5, marginRight: 4 },
  legendText: { fontSize: 10, color: colors.textSecondary },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  locationsHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginBottom: spacing.small },
  locationsHeaderText: { fontWeight: '700', color: colors.textPrimary },
  locationsChip: { fontSize: 11, fontWeight: '700', borderRadius: 12, paddingHorizontal: 8, paddingVertical: 3, overflow: 'hidden' },
  locationsList: { padding: 0 },
  locationRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 2 },
  locationRowDivider: { borderBottomWidth: 1, borderBottomColor: colors.divider },
  locationIcon: { fontSize: 18, marginRight: spacing.small + 4, width: 24, textAlign: 'center' },
  locationTextBox: { flex: 1, marginRight: spacing.small },
  locationTitle: { fontWeight: '600' },
  locationSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  locationMapsLink: { fontSize: 16 },
  emptyState: { alignItems: 'center', paddingVertical: spacing.medium, justifyContent: 'center' },
  emptyStateIcon: { fontSize: 36, opacity: 0.4, marginBottom: spacing.small },
  emptyStateText: { color: colors.textSecondary, textAlign: 'center' },
  twoColumnTables: { flexDirection: 'row', gap: spacing.large },
  twoColumnCell: { flex: 1 },
  tableCardHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small },
  tableExportLink: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  tableHeader: { flexDirection: 'row', paddingVertical: spacing.small, borderBottomWidth: 2, borderBottomColor: colors.primary },
  tableHeaderCell: { fontSize: 12, fontWeight: '700', color: colors.primary, paddingHorizontal: 4 },
  tableRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 2 },
  tableRowDivider: { borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableCell: { fontSize: 13, color: colors.textPrimary, paddingHorizontal: 4 },
  colRank: { width: 60 },
  colDriver: { width: 220 },
  colDeliveries: { width: 100 },
  colBadge: { width: 120 },
  tableEmpty: { color: colors.textSecondary, paddingVertical: spacing.medium, textAlign: 'center' },
  driverBadge: { borderRadius: 12, paddingHorizontal: 8, paddingVertical: 2, alignItems: 'center', justifyContent: 'center' },
  driverBadgeText: { fontSize: 11, fontWeight: '700' },
  detailsPanel: { width: 320, backgroundColor: colors.card },
  detailsHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  detailsHeaderIcon: { fontSize: 16, color: colors.white },
  detailsHeaderTitle: { color: colors.white, fontWeight: '700', fontSize: 14, flex: 1, marginLeft: spacing.small },
  detailsHeaderActions: { flexDirection: 'row', gap: spacing.medium },
  detailsBody: { flex: 1 },
  detailsBodyInner: { padding: spacing.medium },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 6 },
  detailRowLabel: { fontSize: 12, color: colors.textSecondary, flex: 1, marginRight: spacing.small },
  detailRowValue: { fontSize: 12, fontWeight: '700', color: colors.textPrimary },
  statusDetailLeft: { flexDirection: 'row', alignItems: 'center', flex: 1, marginRight: spacing.small },
  detailBullets: { fontSize: 11, color: colors.textSecondary, marginTop: spacing.small, lineHeight: 18 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  calendarCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, width: '100%', maxWidth: 360 },
  calendarHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small },
  calendarNav: { fontSize: 22, color: colors.primary, fontWeight: 'bold', paddingHorizontal: spacing.small },
  calendarWeekHeader: { flexDirection: 'row', marginBottom: 4 },
  calendarWeekDay: { flex: 1, textAlign: 'center', fontSize: 11, fontWeight: '700', color: colors.textSecondary },
  calendarGrid: { flexDirection: 'row', flexWrap: 'wrap' },
  calendarDay: { width: `${100 / 7}%`, aspectRatio: 1, alignItems: 'center', justifyContent: 'center', borderRadius: 6 },
  calendarDaySelected: { backgroundColor: colors.primary },
  calendarDayRange: { backgroundColor: `${colors.primary}33` },
  calendarDayDim: { opacity: 0.3 },
  calendarDayText: { fontSize: 13, color: colors.textPrimary },
  calendarDayTextSelected: { color: colors.white, fontWeight: '700' },
  calendarRangeLabel: { textAlign: 'center', fontSize: 12, color: colors.textSecondary, marginVertical: spacing.small },
  calendarActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.small, marginTop: spacing.small },
  calendarClearButton: { paddingVertical: spacing.small + 4, paddingHorizontal: spacing.medium },
  calendarClearText: { color: colors.error, fontWeight: '600' },
  calendarOkDisabled: { opacity: 0.4 },
  modalCloseButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, paddingHorizontal: spacing.medium },
  exportTextCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, width: '100%', maxWidth: 520, maxHeight: '80%' },
  exportTextScroll: { marginTop: spacing.small, backgroundColor: colors.background, borderRadius: radii.borderRadius, padding: spacing.small },
  exportTextContent: { fontFamily: 'monospace', fontSize: 11, color: colors.textPrimary },
});