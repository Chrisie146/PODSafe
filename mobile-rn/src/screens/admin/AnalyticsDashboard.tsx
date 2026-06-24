import React, { useCallback, useEffect, useState } from 'react';
import { Alert, Linking, Pressable, RefreshControl, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { LineChart } from 'react-native-gifted-charts';
import { AdminShell } from '../../components/admin/AdminShell';
import {
  AppIcon,
  AppIconName,
  Card,
  EmptyState,
  LoadingState,
} from '../../components/ui';
import { useAuthStore } from '../../stores/useAuthStore';
import { hasPermission } from '../../permissions/permissionService';
import { DeliveryStatus } from '../../models/delivery';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/analytics_dashboard_screen.dart
 * (`AnalyticsDashboardMobile`, verified against source on 2026-06-22) — overview stats,
 * a delivery-trend line chart, a delivery-locations list, status distribution, top
 * drivers, and driver stats.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the >1000px
 * desktop branch lands in Phase 4. `react-native-gifted-charts` provides the `LineChart`.
 *
 * Deviations from the Flutter source:
 * - `fl_chart` LineChart → `react-native-gifted-charts` LineChart.
 * - `AnalyticsMapWidget` → scrollable location list with an "Open in Maps" link per row
 *   (react-native-maps not installed; same degraded-but-honest pattern as ClaimDetails).
 * - POD locations read the canonical top-level `pods/{deliveryId}`; claim locations read
 *   `companies/{companyId}/claims`'s `gpsLocation`.
 * - Permission gate is a direct `hasPermission()` check.
 *
 * UI/UX refresh (Operations Precision): the custom navy header, emoji stat/period/location/
 * status/driver glyphs, and access-denied glyph are replaced with the shared AppHeader, SVG
 * AppIcon, Card, EmptyState, and LoadingState. Semantic tokens only.
 */
type Period = 'week' | 'month' | 'year';

interface AnalyticsDashboardProps {
  navigation: {
    goBack: () => void;
    navigate: (screen: string, params?: Record<string, unknown>) => void;
  };
}

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
      return colors.attention;
    case 'inTransit':
      return colors.active;
    case 'delivered':
      return colors.verified;
    case 'failed':
      return colors.critical;
    default:
      return colors.contentSecondary;
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

export default function AnalyticsDashboard({ navigation }: AnalyticsDashboardProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const signOut = useAuthStore((s) => s.signOut);
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
    // Company-scoped fetch + local date filter: avoids a composite
    // (companyId == + scheduledDate >=) index, matching the dashboards' fallback.
    const snapshot = await firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .get();

    const counts: Record<string, number> = {};
    snapshot.docs.forEach((doc) => {
      const scheduledDate = (doc.data().scheduledDate as { toDate?: () => Date })?.toDate?.();
      if (scheduledDate && scheduledDate >= startDate) {
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

  const handleSignOut = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  if (!hasPermission(currentUser, 'analyticsView')) {
    return (
      <AdminShell
        activeNav="analytics"
        title="Analytics & reports"
        userName={currentUser?.fullName}
        onNavigate={(screen) => navigation.navigate(screen)}
        onLogout={handleSignOut}
      >
        <EmptyState icon="lock" title="Access denied" message="You don't have permission to view analytics." />
      </AdminShell>
    );
  }

  const dailyEntries = Object.entries(dailyDeliveries);
  const chartData = dailyEntries.map(([label, value]) => ({ value, label }));
  const statusTotal = Object.values(deliveriesByStatus).reduce((a, b) => a + b, 0);

  return (
    <AdminShell
      activeNav="analytics"
      title="Analytics & reports"
      userName={currentUser?.fullName}
      onNavigate={(screen) => navigation.navigate(screen)}
      onRefresh={loadAnalytics}
      onLogout={handleSignOut}
    >
      <View style={styles.container}>
      {isLoading ? (
        <LoadingState title="Loading analytics" message="Aggregating delivery and driver statistics." />
      ) : (
        <ScrollView
          style={styles.content}
          contentContainerStyle={styles.contentInner}
          refreshControl={<RefreshControl refreshing={false} onRefresh={loadAnalytics} />}
        >
          <Card style={[styles.card, styles.periodRow]}>
            <AppIcon name="calendar" size={18} color={colors.contentSecondary} />
            <Text style={styles.periodLabel}>Period:</Text>
            {(['week', 'month', 'year'] as Period[]).map((period) => (
              <Pressable
                key={period}
                accessibilityRole="button"
                accessibilityState={{ selected: selectedPeriod === period }}
                style={[styles.periodChip, selectedPeriod === period && styles.periodChipSelected]}
                onPress={() => setSelectedPeriod(period)}
              >
                <Text style={[styles.periodChipText, selectedPeriod === period && styles.periodChipTextSelected]}>
                  {period.charAt(0).toUpperCase() + period.slice(1)}
                </Text>
              </Pressable>
            ))}
          </Card>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Overview</Text>
          <View style={styles.statsGrid}>
            <StatCard label="Total deliveries" value={String(totalDeliveries)} icon="truck" color={colors.shell} width={columns} />
            <StatCard label="Completed" value={String(completedDeliveries)} icon="check" color={colors.verified} width={columns} />
            <StatCard label="In transit" value={String(activeDeliveries)} icon="activity" color={colors.active} width={columns} />
            <StatCard label="Completion rate" value={`${completionRate.toFixed(1)}%`} icon="chart" color={colors.verified} width={columns} />
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery trend</Text>
          <Card style={styles.card}>
            {chartData.length === 0 ? (
              <EmptyState icon="chart" title="No delivery data available" message="Delivery trend will appear once deliveries are scheduled in this period." />
            ) : (
              <LineChart
                data={chartData}
                height={180}
                color={colors.active}
                thickness={3}
                curved
                areaChart
                startFillColor={colors.active}
                endFillColor={colors.active}
                startOpacity={0.2}
                endOpacity={0.02}
                dataPointsColor={colors.active}
                yAxisTextStyle={styles.chartAxisText}
                xAxisLabelTextStyle={styles.chartAxisText}
                rulesColor={colors.border}
                xAxisColor={colors.border}
                yAxisColor={colors.border}
                noOfSections={4}
                initialSpacing={12}
              />
            )}
          </Card>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery locations</Text>
          <View style={styles.infoBanner}>
            <AppIcon name="location" size={16} color={colors.shell} />
            <Text style={styles.infoBannerText}>Locations loaded: {locations.length}</Text>
          </View>
          <Card style={[styles.card, styles.flushCard]}>
            {locations.length === 0 ? (
              <EmptyState icon="location" title="No location data available" message="POD and claim locations will appear here once captured." />
            ) : (
              locations.map((loc, index) => (
                <Pressable
                  key={loc.id}
                  accessibilityRole="button"
                  accessibilityLabel={`Open ${loc.title} in Maps`}
                  style={[styles.locationRow, index < locations.length - 1 && styles.rowDivider]}
                  onPress={() => Linking.openURL(`https://www.google.com/maps?q=${loc.latitude},${loc.longitude}`)}
                >
                  <AppIcon name={loc.type === 'pod' ? 'package' : 'alert'} size={20} color={loc.type === 'pod' ? colors.shell : colors.attention} />
                  <View style={styles.locationTextBox}>
                    <Text style={styles.locationTitle} numberOfLines={1}>{loc.title}</Text>
                    <Text style={styles.locationSubtitle} numberOfLines={1}>{loc.subtitle}</Text>
                  </View>
                  <AppIcon name="map" size={20} color={colors.contentSecondary} />
                </Pressable>
              ))
            )}
          </Card>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Status distribution</Text>
          <Card style={styles.card}>
            {Object.keys(deliveriesByStatus).length === 0 ? (
              <EmptyState icon="chart" title="No status data available" message="The delivery status breakdown will appear here." />
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
          </Card>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Top performing drivers</Text>
          <Card style={[styles.card, styles.flushCard]}>
            {topDrivers.length === 0 ? (
              <EmptyState icon="users" title="No driver performance data yet" message="Completed-delivery leaders will appear here." />
            ) : (
              topDrivers.map((driver, index) => {
                const isTop = index === 0;
                return (
                  <View key={`${driver.name}-${index}`} style={[styles.driverRow, index < topDrivers.length - 1 && styles.rowDivider]}>
                    <View style={[styles.driverRank, { backgroundColor: isTop ? colors.verifiedMuted : colors.activeMuted }]}>
                      <Text style={[styles.driverRankText, { color: isTop ? colors.verified : colors.shell }]}>{index + 1}</Text>
                    </View>
                    <Text style={[styles.driverName, isTop && styles.driverNameTop]}>{driver.name}</Text>
                    <View style={[styles.driverBadge, { backgroundColor: isTop ? colors.verified : colors.activeMuted }]}>
                      <Text style={[styles.driverBadgeText, { color: isTop ? colors.shell : colors.shell }]}>{driver.deliveries} deliveries</Text>
                    </View>
                  </View>
                );
              })
            )}
          </Card>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Driver statistics</Text>
          <View style={styles.driverStatsRow}>
            <Card style={styles.driverStatCard}>
              <AppIcon name="users" size={26} color={colors.shell} />
              <Text style={[styles.driverStatValue, { color: colors.shell }]}>{totalDrivers}</Text>
              <Text style={styles.driverStatLabel}>Total drivers</Text>
            </Card>
            <Card style={styles.driverStatCard}>
              <AppIcon name="check" size={26} color={colors.verified} />
              <Text style={[styles.driverStatValue, { color: colors.verified }]}>{activeDrivers}</Text>
              <Text style={styles.driverStatLabel}>Active drivers</Text>
            </Card>
          </View>
        </ScrollView>
      )}
      </View>
    </AdminShell>
  );
}

function StatCard({ label, value, icon, color, width }: { label: string; value: string; icon: AppIconName; color: string; width: number }) {
  return (
    <Card style={[styles.statCard, { width: `${100 / width - 2}%` }]}>
      <AppIcon name={icon} size={22} color={color} />
      <Text style={[styles.statValue, { color }]}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </Card>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.canvas },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  card: { marginBottom: spacing.large },
  flushCard: { padding: 0, overflow: 'hidden' },
  chartAxisText: { ...textStyles.bodySmall, color: colors.contentSecondary },
  periodRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  periodLabel: { ...textStyles.label, marginRight: spacing.small },
  periodChip: { borderRadius: radii.inputRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
  periodChipSelected: { backgroundColor: colors.activeMuted, borderColor: colors.shell },
  periodChipText: { ...textStyles.bodySmall, color: colors.contentSecondary, fontWeight: '600' },
  periodChipTextSelected: { color: colors.shell },
  sectionTitle: { marginBottom: spacing.small + 4 },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small + 4, marginBottom: spacing.large },
  statCard: { alignItems: 'center', padding: spacing.medium },
  statValue: { ...textStyles.heading3, marginTop: spacing.small },
  statLabel: { ...textStyles.labelSmall, color: colors.contentSecondary, marginTop: 4, textAlign: 'center' },
  infoBanner: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, backgroundColor: colors.activeMuted, borderRadius: radii.inputRadius, padding: spacing.small + 4, marginBottom: spacing.small + 4 },
  infoBannerText: { ...textStyles.labelSmall, color: colors.shell },
  locationRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small + 4, padding: spacing.medium },
  rowDivider: { borderBottomWidth: 1, borderBottomColor: colors.border },
  locationTextBox: { flex: 1 },
  locationTitle: { ...textStyles.label },
  locationSubtitle: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 2 },
  statusRow: { marginBottom: spacing.medium },
  statusHeaderRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small },
  statusLabelRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  statusDot: { width: 12, height: 12, borderRadius: 6 },
  statusLabel: { ...textStyles.label },
  statusValue: { ...textStyles.bodySmall, fontWeight: '700', color: colors.contentSecondary },
  statusTrack: { height: 8, borderRadius: 4, backgroundColor: colors.surfaceMuted, overflow: 'hidden' },
  statusFill: { height: 8, borderRadius: 4 },
  driverRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium, padding: spacing.medium },
  driverRank: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
  driverRankText: { fontWeight: '700' },
  driverName: { flex: 1, ...textStyles.label },
  driverNameTop: { fontWeight: '700' },
  driverBadge: { borderRadius: radii.inputRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small },
  driverBadgeText: { ...textStyles.labelSmall, fontWeight: '700' },
  driverStatsRow: { flexDirection: 'row', gap: spacing.medium },
  driverStatCard: { flex: 1, alignItems: 'center', paddingVertical: spacing.large },
  driverStatValue: { ...textStyles.heading2, marginTop: spacing.small },
  driverStatLabel: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 4 },
});
