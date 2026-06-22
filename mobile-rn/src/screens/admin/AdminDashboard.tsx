import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Image, Modal, Pressable, RefreshControl, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { useAuthStore } from '../../stores/useAuthStore';
import { useCompanyStore } from '../../stores/useCompanyStore';
import { AuthRepository } from '../../repositories/authRepository';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { getSouthAfricanTime, getStartOfTodaySA, getEndOfTodaySA } from '../../utils/datetimeHelper';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/admin_dashboard_screen.dart
 * (`AdminDashboardMobile`, verified against source on 2026-06-22) — the admin home
 * screen: welcome banner, live company info card, today's stats, a quick-actions grid,
 * and a recent-deliveries list.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the
 * >1200px desktop branch lands in Phase 4.
 *
 * Deviations from the Flutter source:
 * - Bug fix: the "Recent Deliveries" widget's status color/icon/label helpers checked
 *   for `'in_transit'`/`'arrived'`/`'assigned'` — none of which are real `DeliveryStatus`
 *   values (the actual enum is `pending`/`inTransit`/`delivered`/`failed`, confirmed
 *   against delivery_model.dart). Every delivery has always fallen through to the
 *   "unknown status" default in production. Fixed by reusing the same correct
 *   status-color/icon/label helpers already established in DeliveryManagement.tsx.
 * - `getSouthAfricanTime()`/`getStartOfTodaySA()`/`getEndOfTodaySA()` ported this pass
 *   into `utils/datetimeHelper.ts` (no RN equivalent existed yet) — see that file's
 *   header comment for how it fakes a fixed SAST offset without a timezone library,
 *   since JS Date has no equivalent of Dart's `isUtc`-tagged-but-field-shifted trick.
 * - Added `deliveryRepository.subscribeToCompanyDeliveries`'s `limit` filter and
 *   `authRepository.getUsersByCompany`'s `role`/`approvalStatus` filters this pass —
 *   needed for the recent-deliveries widget (limit 5) and the active-drivers count.
 * - "Today's stats" (delivery counts by status + active driver count) stay a one-time
 *   fetch + pull-to-refresh, matching the Dart source exactly (not a live subscription).
 * - Quick Actions navigates directly to already-ported screens (DeliveryManagement,
 *   PodViewer, DriverManagement, UserManagement, ClaimsDashboard, ClaimSettings) instead
 *   of the Dart source's named routes (`/admin/deliveries` etc., which don't exist in
 *   this RN app — there's no central route table yet). Vehicle Management, Create
 *   Delivery, Analytics, and Reports are forward references to screens not built yet.
 * - Help/Logout `AlertDialog`s become a Modal (help, scrollable rich content) and
 *   `Alert.alert` (logout, a plain confirm/cancel) respectively. Logout just calls
 *   `useAuthStore.signOut()` — RootNavigator reacts to the auth-state change and
 *   redirects on its own, no manual navigation call needed.
 */
interface AdminDashboardProps {
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

const authRepository = new AuthRepository();
const deliveryRepository = new DeliveryRepository();

function statusColor(status: DeliveryStatus): string {
  switch (status) {
    case 'pending':
      return colors.warning;
    case 'inTransit':
      return colors.info;
    case 'delivered':
      return colors.success;
    case 'failed':
      return colors.error;
  }
}

function statusIcon(status: DeliveryStatus): string {
  switch (status) {
    case 'pending':
      return '📝';
    case 'inTransit':
      return '🚚';
    case 'delivered':
      return '✓';
    case 'failed':
      return '✕';
  }
}

function statusLabel(status: DeliveryStatus): string {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'inTransit':
      return 'In Transit';
    case 'delivered':
      return 'Delivered';
    case 'failed':
      return 'Failed';
  }
}

/** Formats "today" in SAST as a long date string, reading fields via UTC getters — see datetimeHelper.ts. */
function formatSastToday(): string {
  const sast = getSouthAfricanTime();
  const calendarDay = new Date(Date.UTC(sast.getUTCFullYear(), sast.getUTCMonth(), sast.getUTCDate()));
  return calendarDay.toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' });
}

interface QuickAction {
  title: string;
  icon: string;
  color: string;
  onPress: (navigation: AdminDashboardProps['navigation']) => void;
}

const QUICK_ACTIONS: QuickAction[] = [
  { title: 'New Delivery', icon: '📦', color: colors.primary, onPress: (nav) => nav.navigate('CreateDelivery') },
  { title: 'View Deliveries', icon: '📋', color: colors.info, onPress: (nav) => nav.navigate('DeliveryManagement') },
  { title: 'View PODs', icon: '🧾', color: colors.success, onPress: (nav) => nav.navigate('PodViewer') },
  { title: 'Manage Drivers', icon: '👥', color: colors.warning, onPress: (nav) => nav.navigate('DriverManagement') },
  { title: 'Vehicle Management', icon: '🚙', color: '#00BCD4', onPress: (nav) => nav.navigate('VehicleManagement') },
  { title: 'User Management', icon: '🛡', color: '#673AB7', onPress: (nav) => nav.navigate('UserManagement') },
  { title: 'Claims Management', icon: '⚠', color: '#FF5722', onPress: (nav) => nav.navigate('ClaimsDashboard') },
  { title: 'Claim Settings', icon: '⚙', color: '#E65100', onPress: (nav) => nav.navigate('ClaimSettings') },
  { title: 'View Analytics & Reports', icon: '📊', color: '#9C27B0', onPress: (nav) => nav.navigate('AnalyticsDashboard') },
  { title: 'Reports', icon: '📈', color: '#00BCD4', onPress: (nav) => nav.navigate('Reports') },
];

export default function AdminDashboard({ navigation }: AdminDashboardProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const signOut = useAuthStore((s) => s.signOut);
  const company = useCompanyStore((s) => s.company);
  const subscribeToCompany = useCompanyStore((s) => s.subscribeToCompany);

  const { width } = useWindowDimensions();
  const columns = width > 900 ? 4 : width > 600 ? 3 : 2;

  const [isLoading, setIsLoading] = useState(true);
  const [stats, setStats] = useState({ total: 0, pending: 0, completed: 0, activeDrivers: 0 });
  const [recentDeliveries, setRecentDeliveries] = useState<Delivery[] | null>(null);
  const [showHelp, setShowHelp] = useState(false);

  const loadDashboardData = useCallback(async () => {
    if (!currentUser) return;
    setIsLoading(true);
    try {
      const startOfDay = getStartOfTodaySA();
      const endOfDay = getEndOfTodaySA();

      const deliveriesSnapshot = await firestore()
        .collection('deliveries')
        .where('companyId', '==', currentUser.companyId)
        .where('scheduledDate', '>=', firestore.Timestamp.fromDate(startOfDay))
        .where('scheduledDate', '<=', firestore.Timestamp.fromDate(endOfDay))
        .get();

      let pending = 0;
      let completed = 0;
      deliveriesSnapshot.docs.forEach((doc) => {
        if (doc.data().status === 'delivered') completed++;
        else pending++;
      });

      const activeDrivers = await authRepository.getUsersByCompany(currentUser.companyId, { role: 'driver', approvalStatus: 'approved' });

      setStats({ total: deliveriesSnapshot.docs.length, pending, completed, activeDrivers: activeDrivers.length });
    } catch (e) {
      Alert.alert('Error', `Error loading dashboard data: ${(e as Error).message}`);
    } finally {
      setIsLoading(false);
    }
  }, [currentUser]);

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  useEffect(() => {
    if (currentUser) {
      subscribeToCompany(currentUser.companyId);
    }
  }, [currentUser, subscribeToCompany]);

  useEffect(() => {
    if (!currentUser) return;
    return deliveryRepository.subscribeToCompanyDeliveries(currentUser.companyId, setRecentDeliveries, () => setRecentDeliveries([]), { limit: 5 });
  }, [currentUser]);

  const handleLogout = () => {
    Alert.alert('Logout', 'Are you sure you want to logout?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Logout', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>Admin Dashboard</Text>
        <View style={styles.headerBarActions}>
          <Pressable onPress={() => setShowHelp(true)}>
            <Text style={styles.headerBarIcon}>❓</Text>
          </Pressable>
          <Pressable onPress={loadDashboardData}>
            <Text style={styles.headerBarIcon}>↻</Text>
          </Pressable>
          <Pressable onPress={handleLogout}>
            <Text style={styles.headerBarIcon}>⎋</Text>
          </Pressable>
        </View>
      </View>

      {isLoading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : (
        <ScrollView
          style={styles.content}
          contentContainerStyle={styles.contentInner}
          refreshControl={<RefreshControl refreshing={false} onRefresh={loadDashboardData} />}
        >
          <View style={[styles.card, shadows.card, styles.welcomeCard]}>
            <View style={styles.welcomeIconBox}>
              <Text style={styles.welcomeIconText}>🛡</Text>
            </View>
            <View style={styles.welcomeTextBox}>
              <Text style={textStyles.heading3}>Welcome back, {currentUser?.fullName ?? 'Admin'}!</Text>
              <Text style={styles.welcomeDate}>{formatSastToday()}</Text>
            </View>
          </View>

          {company ? (
            <View style={[styles.card, shadows.card]}>
              <View style={styles.companyTopRow}>
                <View style={styles.companyLogoBox}>
                  {company.logoUrl ? (
                    <Image source={{ uri: company.logoUrl }} style={styles.companyLogoImage} resizeMode="cover" />
                  ) : (
                    <Text style={styles.companyLogoFallback}>🏢</Text>
                  )}
                </View>
                <View style={styles.companyTextBox}>
                  <Text style={[textStyles.heading3, { color: colors.primary }]}>{company.name}</Text>
                  {company.registrationNumber ? <Text style={styles.companyMeta}>Reg: {company.registrationNumber}</Text> : null}
                  <Text style={styles.companyMeta} numberOfLines={1}>
                    ✉ {company.email}
                  </Text>
                  <Text style={styles.companyMeta} numberOfLines={1}>
                    📍 {company.address || '—'}
                  </Text>
                  <Text style={styles.companyMeta}>
                    ☏ {company.phone || '—'}
                    {company.plan.toLowerCase() !== 'free' ? `  •  🏆 ${company.plan.toUpperCase()}` : ''}
                    {'  •  '}
                    {company.isActive ? '● Active' : '○ Inactive'}
                    {'  •  '}📅 {company.createdAt.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}
                  </Text>
                </View>
              </View>
              <View style={styles.companyInfoBanner}>
                <Text style={styles.companyInfoBannerText}>ℹ Share this code with drivers so they can register and join your company.</Text>
              </View>
              <Pressable style={styles.manageCompanyButton} onPress={() => navigation.navigate('AdminSettings')}>
                <Text style={styles.manageCompanyButtonText}>Manage Company</Text>
              </Pressable>
            </View>
          ) : null}

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Today&apos;s Overview</Text>
          <View style={styles.statsGrid}>
            <StatCard title="Total Deliveries" value={stats.total} icon="🚚" color={colors.primary} />
            <StatCard title="Active Drivers" value={stats.activeDrivers} icon="👤" color={colors.info} />
            <StatCard title="Pending" value={stats.pending} icon="⏳" color={colors.warning} />
            <StatCard title="Completed" value={stats.completed} icon="✓" color={colors.success} />
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Quick Actions</Text>
          <View style={styles.actionsGrid}>
            {QUICK_ACTIONS.map((action) => (
              <Pressable
                key={action.title}
                style={[styles.actionButton, { width: `${100 / columns}%` }]}
                onPress={() => action.onPress(navigation)}
              >
                <View style={[styles.actionButtonInner, { backgroundColor: `${action.color}1A`, borderColor: `${action.color}4D` }]}>
                  <Text style={styles.actionButtonIcon}>{action.icon}</Text>
                  <Text style={[styles.actionButtonText, { color: action.color }]}>{action.title}</Text>
                </View>
              </Pressable>
            ))}
          </View>

          <Text style={[textStyles.heading3, styles.sectionTitle]}>Recent Deliveries</Text>
          {recentDeliveries === null ? (
            <ActivityIndicator color={colors.primary} style={styles.recentLoading} />
          ) : recentDeliveries.length === 0 ? (
            <View style={[styles.card, shadows.card, styles.emptyState]}>
              <Text style={styles.emptyStateIcon}>📭</Text>
              <Text style={styles.emptyStateText}>No deliveries yet</Text>
            </View>
          ) : (
            <View style={[styles.card, shadows.card, styles.recentCard]}>
              {recentDeliveries.map((delivery, index) => (
                <Pressable
                  key={delivery.id}
                  style={[styles.recentRow, index < recentDeliveries.length - 1 && styles.recentRowDivider]}
                  onPress={() => navigation.navigate('DeliveryManagement')}
                >
                  <View style={[styles.recentIconBox, { backgroundColor: `${statusColor(delivery.status)}1A` }]}>
                    <Text style={[styles.recentIconText, { color: statusColor(delivery.status) }]}>{statusIcon(delivery.status)}</Text>
                  </View>
                  <View style={styles.recentTextBox}>
                    <Text style={styles.recentTitle} numberOfLines={1}>
                      {delivery.customerName}
                    </Text>
                    <Text style={styles.recentMeta} numberOfLines={1}>
                      Order: {delivery.orderNumber ?? '-'} | Invoice: {delivery.invoiceNumber}
                    </Text>
                    <Text style={styles.recentMeta} numberOfLines={1}>
                      Customer #: {delivery.customerNumber ?? '-'}
                    </Text>
                    <Text style={styles.recentAddress} numberOfLines={1}>
                      {delivery.customerAddress}
                    </Text>
                  </View>
                  <View style={styles.recentTrailing}>
                    <Text style={[styles.recentStatus, { color: statusColor(delivery.status) }]}>{statusLabel(delivery.status)}</Text>
                    <Text style={styles.recentDate}>{delivery.scheduledDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</Text>
                  </View>
                </Pressable>
              ))}
            </View>
          )}
        </ScrollView>
      )}

      <Modal visible={showHelp} transparent animationType="fade" onRequestClose={() => setShowHelp(false)}>
        <View style={styles.modalBackdrop}>
          <ScrollView style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>PODSafe Help</Text>
            <Text style={styles.helpIntro}>Welcome to PODSafe!</Text>
            <Text style={styles.helpBody}>PODSafe helps you manage deliveries and proof-of-delivery documents professionally.</Text>
            <Text style={styles.helpSectionLabel}>Quick Actions:</Text>
            <Text style={styles.helpLine}>• Tap &quot;New Delivery&quot; to create deliveries</Text>
            <Text style={styles.helpLine}>• Use &quot;View Deliveries&quot; to manage existing ones</Text>
            <Text style={styles.helpLine}>• Check &quot;Claims&quot; for issues</Text>
            <Text style={styles.helpLine}>• Access &quot;Analytics&quot; for reports</Text>
            <Text style={styles.helpFooter}>Need more help? Check the user guide or contact support.</Text>
            <Pressable style={styles.modalCloseButton} onPress={() => setShowHelp(false)}>
              <Text style={textStyles.buttonText}>Close</Text>
            </Pressable>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

function StatCard({ title, value, icon, color }: { title: string; value: number; icon: string; color: string }) {
  return (
    <View style={[styles.statCard, shadows.card]}>
      <View style={styles.statTopRow}>
        <View style={[styles.statIconBox, { backgroundColor: `${color}1A` }]}>
          <Text style={[styles.statIconText, { color }]}>{icon}</Text>
        </View>
        <Text style={[styles.statValue, { color }]}>{value}</Text>
      </View>
      <Text style={styles.statTitle}>{title}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  headerBarActions: { flexDirection: 'row', gap: spacing.medium },
  headerBarIcon: { fontSize: 18, color: colors.white },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  welcomeCard: { flexDirection: 'row', alignItems: 'center' },
  welcomeIconBox: { width: 60, height: 60, borderRadius: radii.borderRadius, backgroundColor: `${colors.primary}1A`, alignItems: 'center', justifyContent: 'center', marginRight: spacing.medium },
  welcomeIconText: { fontSize: 28 },
  welcomeTextBox: { flex: 1 },
  welcomeDate: { color: colors.textSecondary, fontSize: 13, marginTop: 4 },
  companyTopRow: { flexDirection: 'row', alignItems: 'flex-start' },
  companyLogoBox: { width: 56, height: 56, borderRadius: radii.borderRadius, backgroundColor: `${colors.primary}1A`, alignItems: 'center', justifyContent: 'center', marginRight: spacing.medium, overflow: 'hidden' },
  companyLogoImage: { width: '100%', height: '100%' },
  companyLogoFallback: { fontSize: 24 },
  companyTextBox: { flex: 1 },
  companyMeta: { color: colors.textSecondary, fontSize: 13, marginTop: 4 },
  companyInfoBanner: { backgroundColor: `${colors.info}1A`, borderRadius: radii.borderRadius, padding: spacing.small + 4, marginTop: spacing.medium },
  companyInfoBannerText: { color: colors.info, fontSize: 12 },
  manageCompanyButton: { alignSelf: 'flex-end', marginTop: spacing.medium },
  manageCompanyButtonText: { color: colors.primary, fontWeight: '600' },
  sectionTitle: { marginBottom: spacing.small + 4 },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small + 4, marginBottom: spacing.large },
  statCard: { width: '47%', backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium },
  statTopRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  statIconBox: { width: 44, height: 44, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center' },
  statIconText: { fontSize: 20 },
  statValue: { fontSize: 28, fontWeight: 'bold' },
  statTitle: { fontSize: 13, color: colors.textSecondary, fontWeight: '500', marginTop: spacing.small + 4 },
  actionsGrid: { flexDirection: 'row', flexWrap: 'wrap', marginBottom: spacing.large, marginHorizontal: -spacing.small / 2 },
  actionButton: { padding: spacing.small / 2 },
  actionButtonInner: { borderRadius: radii.borderRadius, borderWidth: 1, alignItems: 'center', padding: spacing.medium, minHeight: 92 },
  actionButtonIcon: { fontSize: 28 },
  actionButtonText: { fontSize: 12, fontWeight: '600', textAlign: 'center', marginTop: spacing.small },
  recentLoading: { marginVertical: spacing.medium },
  emptyState: { alignItems: 'center', paddingVertical: spacing.large },
  emptyStateIcon: { fontSize: 40, opacity: 0.4 },
  emptyStateText: { color: colors.textSecondary, marginTop: spacing.small },
  recentCard: { padding: 0, overflow: 'hidden' },
  recentRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.medium },
  recentRowDivider: { borderBottomWidth: 1, borderBottomColor: colors.divider },
  recentIconBox: { width: 40, height: 40, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  recentIconText: { fontSize: 18 },
  recentTextBox: { flex: 1, marginRight: spacing.small },
  recentTitle: { fontWeight: '600' },
  recentMeta: { fontSize: 12, marginTop: 2 },
  recentAddress: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  recentTrailing: { alignItems: 'flex-end' },
  recentStatus: { fontWeight: '600', fontSize: 12 },
  recentDate: { color: colors.textSecondary, fontSize: 11, marginTop: 2 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '80%' },
  helpIntro: { fontWeight: 'bold', fontSize: 16, marginTop: spacing.medium },
  helpBody: { lineHeight: 21, marginTop: spacing.small + 4 },
  helpSectionLabel: { fontWeight: 'bold', marginTop: spacing.medium },
  helpLine: { marginTop: 4, color: colors.textSecondary },
  helpFooter: { fontStyle: 'italic', marginTop: spacing.medium, color: colors.textSecondary },
  modalCloseButton: { marginTop: spacing.large, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
});
