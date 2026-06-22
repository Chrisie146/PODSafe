import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, RefreshControl, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { LineChart } from 'react-native-gifted-charts';
import { useAuthStore } from '../../stores/useAuthStore';
import { hasPermission } from '../../permissions/permissionService';
import { DeliveryStatus } from '../../models/delivery';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/analytics_dashboard_screen.dart
 * (`AnalyticsDashboardMobile`, verified against source on 2026-06-22) — overview stats,
 * a delivery-trend line chart, a delivery-locations map, status distribution, top
 * drivers, and driver stats.
 *
 * Group A responsive-split screen, the last of 9 — only the mobile path is ported this
 * pass; the >1000px desktop branch lands in Phase 4. This is the one screen in the
 * entire inventory that was genuinely blocked on a missing package: confirmed via direct
 * read that it needs `fl_chart`'s `LineChart`. `react-native-gifted-charts` (the package
 * named in the migration plan) was installed this pass specifically to unblock it.
 *
 * Deviations from the Flutter source:
 * - `fl_chart`'s `LineChart` becomes `react-native-gifted-charts`'s `LineChart` (data as
 *   `{ value, label }[]`, `curved`/`areaChart`/`startFillColor`/`endFillColor` map
 *   directly onto the Dart source's `isCurved`/`belowBarData`).
 * - `AnalyticsMapWidget` (a custom map widget) becomes a scrollable list of location
 *   entries with an "Open in Maps" link per row (`Linking.openURL`), same
 *   degraded-but-honest pattern as ClaimDetails.tsx's GPS section — `react-native-maps`
 *   isn't installed (that's still deferred to whenever live_tracking_screen is tackled;
 *   installing it wasn't part of this pass's scope, which was specifically the chart
 *   library). Per-location driver vehicle-info and per-claim POD-info enrichment (each an
 *   extra Firestore read per row in the Dart source) are dropped — the degraded list
 *   doesn't surface those fields, so fetching them would be pure waste.
 * - Location data reads PODs from the canonical top-level `pods/{deliveryId}` collection
 *   instead of the Dart source's `companies/{companyId}/pods` subcollection. Per this
 *   migration's own Section 4 (Dual-POD Architecture Decision, settled back in Phase 2):
 *   that subcollection is the *abandoned* pipeline with no real driver-capture writers in
 *   production (`document_intake_screen.dart` is its only consumer) — querying it here
 *   would almost always return nothing. Claim locations still read from
 *   `companies/{companyId}/claims`'s `gpsLocation` field, which *is* the canonical claims
 *   location (matches claimRepository.ts).
 * - Permission gate (`Permission.analyticsView`) is a direct `hasPermission()` check
 *   instead of the `PermissionBuilder` widget (same precedent as DeliveryManagement.tsx).
 * - Period selector (`SegmentedButton`) and status-distribution bars use existing
 *   chip/progress-bar patterns already established elsewhere in this phase.
 */
type Period = 'week' | 'month' | 'year';

interface LocationEntry {
  id: string;
  type: 'pod' | 'claim';
  latitude: number;
  longitude: number;
  title: string;
  subtitle: string;
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

function periodStartDate(period: Period): Date {
  const days = period === 'week' ? 7 : period === 'month' ? 30 : 365;
  return new Date(Date.now() - days * 86400000);
}

export default function AnalyticsDashboard() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const { width } = useWindowDimensions();
  const columns = width > 800 ? 4 : 2;

  const [selectedPeriod, setSelectedPeriod] = useState<Period>('week');
  const [isLoading, setIsLoading] = useState(true);

  const [totalDeliveries, setTotalDeliveries] = useState(0);
  const [completedDeliveries, setCompletedDeliveries] = useState(0);
  const [activeDeliveries, setActiveDeliveries] = useState(0);
  const [completionRate, setCompletionRate] = useState(0);
  const [deliveriesByStatus, setDeliveriesByStatus] = useState<Record<string, number>>({});

  const [totalDrivers, setTotalDrivers] = useState(0);
  const [activeDrivers, setActiveDrivers] = useState(0);

  const [dailyDeliveries, setDailyDeliveries] = useState<Record<string, number>>({});
  const [topDrivers, setTopDrivers] = useState<{ name: string; deliveries: number }[]>([]);
  const [locations, setLocations] = useState<LocationEntry[]>([]);

  const loadDeliveryStats = useCallback(async (companyId: string) => {
    const snapshot = await firestore().collection('deliveries').where('companyId', '==', companyId).get();
    let completed = 0;
    let active = 0;
    const statusCount: Record<string, number> = {};

    snapshot.docs.forEach((doc) => {
      const status = doc.data().status as DeliveryStatus | undefined;
      if (status) {
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        if (status === 'delivered') completed++;
        else if (status === 'inTransit') active++;
      }
    });

    const total = snapshot.docs.length;
    setTotalDeliveries(total);
    setCompletedDeliveries(completed);
    setActiveDeliveries(active);
    setCompletionRate(total > 0 ? (completed / total) * 100 : 0);
    setDeliveriesByStatus(statusCount);
  }, []);

  const loadDriverStats = useCallback(async (companyId: string) => {
    const snapshot = await firestore().collection('users').where('role', '==', 'driver').where('companyId', '==', companyId).get();
    let active = 0;
    snapshot.docs.forEach((doc) => {
      if ((doc.data().approvalStatus ?? 'approved') === 'approved') active++;
    });
    setTotalDrivers(snapshot.docs.length);
    setActiveDrivers(active);
  }, []);

  const loadDailyDeliveries = useCallback(async (companyId: string, period: Period) => {
    const startDate = periodStartDate(period);
    const snapshot = await firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(startDate))
      .get();

    const counts: Record<string, number> = {};
    snapshot.docs.forEach((doc) => {
      const scheduledDate = (doc.data().scheduledDate as { toDate?: () => Date })?.toDate?.();
      if (scheduledDate) {
        const key = scheduledDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
        counts[key] = (counts[key] ?? 0) + 1;
      }
    });
    setDailyDeliveries(counts);
  }, []);

  const loadTopDrivers = useCallback(async (companyId: string) => {
    const snapshot = await firestore().collection('deliveries').where('companyId', '==', companyId).where('status', '==', 'delivered').get();
    const driverCounts: Record<string, number> = {};
    snapshot.docs.forEach((doc) => {
      const driverId = doc.data().driverId as string | undefined;
      if (driverId) driverCounts[driverId] = (driverCounts[driverId] ?? 0) + 1;
    });

    const sorted = Object.entries(driverCounts).sort((a, b) => b[1] - a[1]).slice(0, 5);
    const result: { name: string; deliveries: number }[] = [];
    for (const [driverId, count] of sorted) {
      try {
        const driverDoc = await firestore().collection('users').doc(driverId).get();
        if (driverDoc.exists()) {
          result.push({ name: driverDoc.data()?.fullName ?? 'Unknown', deliveries: count });
        }
      } catch {
        // Skip drivers we can't read, matching the Dart source's catch-and-continue.
      }
    }
    setTopDrivers(result);
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

  const loadAnalytics = useCallback(async () => {
    if (!currentUser) return;
    setIsLoading(true);
    try {
      await Promise.all([
        loadDeliveryStats(currentUser.companyId),
        loadDriverStats(currentUser.companyId),
        loadDailyDeliveries(currentUser.companyId, selectedPeriod),
        loadTopDrivers(currentUser.companyId),
        loadLocationData(currentUser.companyId),
      ]);
    } finally {
      setIsLoading(false);
    }
  }, [currentUser, selectedPeriod, loadDeliveryStats, loadDriverStats, loadDailyDeliveries, loadTopDrivers, loadLocationData]);

  useEffect(() => {
    loadAnalytics();
  }, [loadAnalytics]);

  if (!hasPermission(currentUser, 'analyticsView')) {
    return (
      <View style={styles.centered}>
        <Text style={styles.deniedIcon}>🔒</Text>
        <Text style={styles.deniedTitle}>Access Denied</Text>
        <Text style={styles.deniedSubtitle}>You don&apos;t have permission to view analytics</Text>
      </View>
    );
  }

  const dailyEntries = Object.entries(dailyDeliveries);
  const chartData = dailyEntries.map(([label, value]) => ({ value, label }));
  const statusTotal = Object.values(deliveriesByStatus).reduce((a, b) => a + b, 0);

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>Analytics & Reports</Text>
        <Pressable onPress={loadAnalytics}>
          <Text style={styles.headerBarIcon}>↻</Text>
        </Pressable>
      </View>

      {isLoading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : (
        <ScrollView
          style={styles.content}
          contentContainerStyle={styles.contentInner}
          refreshControl={<RefreshControl refreshing={false} onRefresh={loadAnalytics} />}
        >
          <View style={[styles.card, shadows.card, styles.periodRow]}>
            <Text style={styles.periodLabel}>📅 Period:</Text>
            {(['week', 'month', 'year'] as Period[]).map((period) => (
              <Pressable key={period} style={[styles.periodChip, selectedPeriod === period && styles.periodChipSelected]} onPress={() => setSelectedPeriod(period)}>
                <Text style={[styles.periodChipText, selectedPeriod === period && styles.periodChipTextSelected]}>
                  {period.charAt(0).toUpperCase() + period.slice(1)}
                </Text>
              </Pressable>
            ))}
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Overview</Text>
          <View style={styles.statsGrid}>
            <StatCard label="Total Deliveries" value={String(totalDeliveries)} icon="🚚" color={colors.primary} width={columns} />
            <StatCard label="Completed" value={String(completedDeliveries)} icon="✓" color={colors.success} width={columns} />
            <StatCard label="In Transit" value={String(activeDeliveries)} icon="⏳" color={colors.info} width={columns} />
            <StatCard label="Completion Rate" value={`${completionRate.toFixed(1)}%`} icon="📈" color={colors.success} width={columns} />
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Trend</Text>
          <View style={[styles.card, shadows.card]}>
            {chartData.length === 0 ? (
              <View style={styles.emptyState}>
                <Text style={styles.emptyStateIcon}>📈</Text>
                <Text style={styles.emptyStateText}>No delivery data available</Text>
              </View>
            ) : (
              <LineChart
                data={chartData}
                height={180}
                color={colors.primary}
                thickness={3}
                curved
                areaChart
                startFillColor={colors.primary}
                endFillColor={colors.primary}
                startOpacity={0.2}
                endOpacity={0.02}
                dataPointsColor={colors.primary}
                yAxisTextStyle={styles.chartYAxisText}
                xAxisLabelTextStyle={styles.chartXAxisText}
                rulesColor={colors.divider}
                xAxisColor={colors.divider}
                yAxisColor={colors.divider}
                noOfSections={4}
                initialSpacing={12}
              />
            )}
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Locations</Text>
          <View style={[styles.infoBanner]}>
            <Text style={styles.infoBannerText}>Locations loaded: {locations.length}</Text>
          </View>
          <View style={[styles.card, shadows.card, styles.locationsCard]}>
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
                    <Text style={styles.locationTitle} numberOfLines={1}>
                      {loc.title}
                    </Text>
                    <Text style={styles.locationSubtitle} numberOfLines={1}>
                      {loc.subtitle}
                    </Text>
                  </View>
                  <Text style={styles.locationMapsLink}>🗺</Text>
                </Pressable>
              ))
            )}
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Status Distribution</Text>
          <View style={[styles.card, shadows.card]}>
            {Object.keys(deliveriesByStatus).length === 0 ? (
              <View style={styles.emptyState}>
                <Text style={styles.emptyStateIcon}>📊</Text>
                <Text style={styles.emptyStateText}>No status data available</Text>
              </View>
            ) : (
              Object.entries(deliveriesByStatus).map(([status, count]) => {
                const percentage = statusTotal > 0 ? (count / statusTotal) * 100 : 0;
                const color = statusColor(status);
                return (
                  <View key={status} style={styles.statusRow}>
                    <View style={styles.statusHeaderRow}>
                      <View style={styles.statusLabelRow}>
                        <View style={[styles.statusDot, { backgroundColor: color }]} />
                        <Text style={styles.statusLabel}>{formatStatus(status)}</Text>
                      </View>
                      <Text style={styles.statusValue}>
                        {count} ({percentage.toFixed(1)}%)
                      </Text>
                    </View>
                    <View style={styles.statusTrack}>
                      <View style={[styles.statusFill, { width: `${percentage}%`, backgroundColor: color }]} />
                    </View>
                  </View>
                );
              })
            )}
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Top Performing Drivers</Text>
          <View style={[styles.card, shadows.card, styles.locationsCard]}>
            {topDrivers.length === 0 ? (
              <View style={styles.emptyState}>
                <Text style={styles.emptyStateIcon}>👥</Text>
                <Text style={styles.emptyStateText}>No driver performance data yet</Text>
              </View>
            ) : (
              topDrivers.map((driver, index) => {
                const isTop = index === 0;
                return (
                  <View key={`${driver.name}-${index}`} style={[styles.driverRow, index < topDrivers.length - 1 && styles.locationRowDivider]}>
                    <View style={[styles.driverRank, { backgroundColor: isTop ? `${colors.success}33` : `${colors.primary}1A` }]}>
                      <Text style={[styles.driverRankText, { color: isTop ? colors.success : colors.primary }]}>{index + 1}</Text>
                    </View>
                    <Text style={[styles.driverName, isTop && styles.driverNameTop]}>{driver.name}</Text>
                    <View style={[styles.driverBadge, { backgroundColor: isTop ? colors.success : `${colors.primary}1A` }]}>
                      <Text style={[styles.driverBadgeText, { color: isTop ? colors.white : colors.primary }]}>{driver.deliveries} deliveries</Text>
                    </View>
                  </View>
                );
              })
            )}
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Driver Statistics</Text>
          <View style={styles.driverStatsRow}>
            <View style={[styles.card, shadows.card, styles.driverStatCard]}>
              <Text style={styles.driverStatIcon}>👥</Text>
              <Text style={[styles.driverStatValue, { color: colors.primary }]}>{totalDrivers}</Text>
              <Text style={styles.driverStatLabel}>Total Drivers</Text>
            </View>
            <View style={[styles.card, shadows.card, styles.driverStatCard]}>
              <Text style={styles.driverStatIcon}>✓</Text>
              <Text style={[styles.driverStatValue, { color: colors.success }]}>{activeDrivers}</Text>
              <Text style={styles.driverStatLabel}>Active Drivers</Text>
            </View>
          </View>
        </ScrollView>
      )}
    </View>
  );
}

function StatCard({ label, value, icon, color, width }: { label: string; value: string; icon: string; color: string; width: number }) {
  return (
    <View style={[styles.statCard, shadows.card, { width: `${100 / width - 2}%` }]}>
      <Text style={styles.statIcon}>{icon}</Text>
      <Text style={[styles.statValue, { color }]}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background, padding: spacing.large },
  deniedIcon: { fontSize: 56 },
  deniedTitle: { fontSize: 22, fontWeight: 'bold', marginTop: spacing.medium },
  deniedSubtitle: { color: colors.textSecondary, marginTop: spacing.small },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  headerBarIcon: { fontSize: 18, color: colors.white },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  chartYAxisText: { fontSize: 10, color: colors.textSecondary },
  chartXAxisText: { fontSize: 9, color: colors.textSecondary },
  periodRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  periodLabel: { fontWeight: '600', marginRight: spacing.small },
  periodChip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  periodChipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  periodChipText: { fontSize: 13, color: colors.textSecondary, fontWeight: '600' },
  periodChipTextSelected: { color: colors.primary },
  sectionTitle: { marginBottom: spacing.small + 4 },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small + 4, marginBottom: spacing.large },
  statCard: { alignItems: 'center', backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium },
  statIcon: { fontSize: 22 },
  statValue: { fontSize: 20, fontWeight: 'bold', marginTop: spacing.small },
  statLabel: { fontSize: 11, color: colors.textSecondary, marginTop: 4, textAlign: 'center' },
  emptyState: { alignItems: 'center', paddingVertical: spacing.large },
  emptyStateIcon: { fontSize: 40, opacity: 0.4 },
  emptyStateText: { color: colors.textSecondary, marginTop: spacing.small },
  infoBanner: { backgroundColor: `${colors.info}1A`, borderRadius: radii.borderRadius, padding: spacing.small + 4, marginBottom: spacing.small + 4 },
  infoBannerText: { color: colors.info, fontSize: 12, fontWeight: '600' },
  locationsCard: { padding: 0, overflow: 'hidden' },
  locationRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.medium },
  locationRowDivider: { borderBottomWidth: 1, borderBottomColor: colors.divider },
  locationIcon: { fontSize: 20, marginRight: spacing.small + 4 },
  locationTextBox: { flex: 1, marginRight: spacing.small },
  locationTitle: { fontWeight: '600' },
  locationSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  locationMapsLink: { fontSize: 18 },
  statusRow: { marginBottom: spacing.medium },
  statusHeaderRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small },
  statusLabelRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  statusDot: { width: 12, height: 12, borderRadius: 6 },
  statusLabel: { fontWeight: '600' },
  statusValue: { fontWeight: 'bold', color: colors.textSecondary },
  statusTrack: { height: 8, borderRadius: 4, backgroundColor: colors.divider, overflow: 'hidden' },
  statusFill: { height: 8, borderRadius: 4 },
  driverRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.medium },
  driverRank: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center', marginRight: spacing.medium },
  driverRankText: { fontWeight: 'bold' },
  driverName: { flex: 1, fontWeight: '600' },
  driverNameTop: { fontWeight: 'bold' },
  driverBadge: { borderRadius: 16, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small },
  driverBadgeText: { fontWeight: 'bold', fontSize: 12 },
  driverStatsRow: { flexDirection: 'row', gap: spacing.medium },
  driverStatCard: { flex: 1, alignItems: 'center' },
  driverStatIcon: { fontSize: 28 },
  driverStatValue: { fontSize: 24, fontWeight: 'bold', marginTop: spacing.small },
  driverStatLabel: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
});
