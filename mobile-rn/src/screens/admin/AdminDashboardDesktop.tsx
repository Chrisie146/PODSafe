import React, { useEffect, useState } from 'react';
import { Alert, Image, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { useAuthStore } from '../../stores/useAuthStore';
import { useCompanyStore } from '../../stores/useCompanyStore';
import { useThemeStore } from '../../stores/useThemeStore';
import { getStartOfTodaySA, getEndOfTodaySA } from '../../utils/datetimeHelper';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/admin_dashboard_desktop.dart (verified against source on
 * 2026-06-23) — a much richer "hub" screen than admin_dashboard_screen.dart's mobile
 * variant (AdminDashboard.tsx): 5 header dropdown menus (Deliveries/Management/Claims/
 * Import/Documents), a hamburger drawer (Analytics/Live Tracking/Settings/Help & Support),
 * 8 tappable stat cards (vs. mobile's 4), and a live (not one-time-fetch) recent-deliveries
 * feed.
 *
 * Deviations from the Flutter source:
 * - The 5 AppBar `PopupMenuButton` dropdowns + the `Drawer` + the nested "Help & Support"
 *   sub-dialog all become ONE reusable bottom-sheet `MenuSheet` (Modal + ActionRow, the
 *   `DriverDetails.tsx` convention already used throughout this port) driven by a single
 *   `activeMenu` key + a `MENUS` config object, instead of ~7 separate Dart widget trees —
 *   same set of destinations, far less duplication.
 * - The 3 help-content `AlertDialog`s (User Guide / Quick Tips / Support) become one
 *   `HelpContentModal` parameterized by which content to show, instead of 3 near-identical
 *   dialog widgets.
 * - The "View Full Guide" button's `launchUrl('file:///C:/Users/.../PODSAFE_USER_GUIDE.md')`
 *   is dropped — that's a developer's local machine path, not a real production link in
 *   either app. The dialog's own fallback SnackBar text is shown instead as a directly
 *   informative message (no broken `launchUrl` attempt first).
 * - The Dart source dynamically recolors its entire AppBar from `ThemeProvider.primaryColor`
 *   (live per-company branding). No other ported screen does this — they all use the static
 *   `colors.primary` token — and per-company dynamic chrome theming is an explicitly
 *   "deferred product decision" in the UI/UX Refresh Workflow note. Kept static here for
 *   consistency; only the company-welcome card's logo still prefers `company.logoUrl` over
 *   the branded `appLogoUrl` fallback, matching the Dart source's own narrower logo-only use.
 * - Recent deliveries is ported as a live `onSnapshot` feed (matches the Dart source, which
 *   uses `StreamBuilder` here unlike the mobile screen's one-time fetch + `limit` repository
 *   call) reading raw Firestore docs directly, same as the Dart source.
 * - Keyboard shortcuts: none exist in this particular Dart file (unlike Vehicle/Catalog/
 *   ClaimSettings desktop screens), so nothing was dropped here.
 */
interface AdminDashboardDesktopProps {
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

type MenuKey = 'deliveries' | 'management' | 'claims' | 'import' | 'documents' | 'drawer' | 'help';

interface MenuItem {
  icon: string;
  label: string;
  onPress: () => void;
}

function statusColorFor(status: string): string {
  switch (status) {
    case 'delivered':
      return colors.success;
    case 'inTransit':
      return colors.info;
    default:
      return colors.warning;
  }
}

function statusIconFor(status: string): string {
  switch (status) {
    case 'delivered':
      return '✓';
    case 'inTransit':
      return '🚚';
    default:
      return '⏳';
  }
}

export default function AdminDashboardDesktop({ navigation }: AdminDashboardDesktopProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const signOut = useAuthStore((s) => s.signOut);
  const company = useCompanyStore((s) => s.company);
  const subscribeToCompany = useCompanyStore((s) => s.subscribeToCompany);
  const appLogoUrl = useThemeStore((s) => s.appLogoUrl);
  const loadBrandingSettings = useThemeStore((s) => s.loadBrandingSettings);

  const [stats, setStats] = useState({
    totalDeliveries: 0,
    pendingDeliveries: 0,
    inTransitDeliveries: 0,
    completedDeliveries: 0,
    activeDrivers: 0,
    totalDrivers: 0,
    pendingApprovals: 0,
    totalClaims: 0,
    pendingClaims: 0,
    totalPODs: 0,
  });
  const [recentDeliveries, setRecentDeliveries] = useState<FirebaseFirestoreTypes.QueryDocumentSnapshot[] | null>(null);
  const [logoFailed, setLogoFailed] = useState(false);
  const [activeMenu, setActiveMenu] = useState<MenuKey | null>(null);
  const [helpContent, setHelpContent] = useState<'guide' | 'tips' | 'support' | null>(null);

  const loadDashboardData = React.useCallback(async () => {
    if (!currentUser) return;
    try {
      const startOfDay = getStartOfTodaySA();
      const endOfDay = getEndOfTodaySA();

      const deliveriesSnapshot = await firestore()
        .collection('deliveries')
        .where('companyId', '==', currentUser.companyId)
        .where('scheduledDate', '>=', firestore.Timestamp.fromDate(startOfDay))
        .where('scheduledDate', '<', firestore.Timestamp.fromDate(endOfDay))
        .get();

      let pending = 0;
      let inTransit = 0;
      let completed = 0;
      deliveriesSnapshot.docs.forEach((doc) => {
        const status = doc.data().status as string | undefined;
        if (status === 'delivered') completed++;
        else if (status === 'inTransit') inTransit++;
        else pending++;
      });

      const driversSnapshot = await firestore().collection('users').where('role', '==', 'driver').where('companyId', '==', currentUser.companyId).get();
      let activeDriversCount = 0;
      let pendingApprovalsCount = 0;
      driversSnapshot.docs.forEach((doc) => {
        const approvalStatus = doc.data().approvalStatus as string | undefined;
        if (approvalStatus === 'approved') activeDriversCount++;
        else if (approvalStatus === 'pending') pendingApprovalsCount++;
      });

      const claimsSnapshot = await firestore().collection('companies').doc(currentUser.companyId).collection('claims').get();
      let pendingClaimsCount = 0;
      claimsSnapshot.docs.forEach((doc) => {
        const status = doc.data().status as string | undefined;
        if (status === 'open' || status === 'pending') pendingClaimsCount++;
      });

      const podsSnapshot = await firestore().collection('pods').where('timestamp', '>=', firestore.Timestamp.fromDate(startOfDay)).get();

      setStats({
        totalDeliveries: deliveriesSnapshot.docs.length,
        pendingDeliveries: pending,
        inTransitDeliveries: inTransit,
        completedDeliveries: completed,
        activeDrivers: activeDriversCount,
        totalDrivers: driversSnapshot.docs.length,
        pendingApprovals: pendingApprovalsCount,
        totalClaims: claimsSnapshot.docs.length,
        pendingClaims: pendingClaimsCount,
        totalPODs: podsSnapshot.docs.length,
      });
    } catch (e) {
      Alert.alert('Error', `Error loading dashboard data: ${(e as Error).message}`);
    }
  }, [currentUser]);

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  useEffect(() => {
    if (currentUser) {
      subscribeToCompany(currentUser.companyId);
      loadBrandingSettings(currentUser.companyId);
    }
  }, [currentUser, subscribeToCompany, loadBrandingSettings]);

  useEffect(() => {
    if (!currentUser) return;
    const unsubscribe = firestore()
      .collection('deliveries')
      .where('companyId', '==', currentUser.companyId)
      .orderBy('createdAt', 'desc')
      .limit(8)
      .onSnapshot(
        (snapshot) => setRecentDeliveries(snapshot.docs),
        () => setRecentDeliveries([]),
      );
    return unsubscribe;
  }, [currentUser]);

  const handleLogout = () => {
    Alert.alert('Logout', 'Are you sure you want to logout?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Logout', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  const MENUS: Record<MenuKey, { title: string; items: MenuItem[] }> = {
    deliveries: {
      title: 'Deliveries',
      items: [
        { icon: '📦', label: 'New Delivery', onPress: () => navigation.navigate('CreateDelivery') },
        { icon: '📋', label: 'View Deliveries', onPress: () => navigation.navigate('DeliveryManagement') },
      ],
    },
    management: {
      title: 'Management',
      items: [
        { icon: '👥', label: 'Drivers', onPress: () => navigation.navigate('DriverManagement') },
        { icon: '🚙', label: 'Vehicles', onPress: () => navigation.navigate('VehicleManagementDesktop') },
        { icon: '🛡', label: 'Users', onPress: () => navigation.navigate('UserManagement') },
        { icon: '📦', label: 'Items', onPress: () => navigation.navigate('ItemCatalogDesktop') },
      ],
    },
    claims: {
      title: 'Claims',
      items: [{ icon: '⚠', label: 'Claims Dashboard', onPress: () => navigation.navigate('ClaimsDashboard') }],
    },
    import: {
      title: 'Import',
      items: [
        { icon: '➕', label: 'Create Customers', onPress: () => navigation.navigate('CustomerCreation') },
        { icon: '📥', label: 'Import Customers', onPress: () => navigation.navigate('CustomerImport') },
        { icon: '⬇️', label: 'Import from Abaserve', onPress: () => navigation.navigate('AbaserveImport') },
      ],
    },
    documents: {
      title: 'Documents',
      items: [{ icon: '🧾', label: 'View PODs', onPress: () => navigation.navigate('PodViewer') }],
    },
    drawer: {
      title: 'Analytics & Reports',
      items: [
        { icon: '📊', label: 'Analytics Dashboard', onPress: () => navigation.navigate('AnalyticsDashboardDesktop') },
        { icon: '🗺️', label: 'Live Tracking', onPress: () => navigation.navigate('LiveTracking') },
        { icon: '⚙️', label: 'Settings', onPress: () => navigation.navigate('AdminSettings') },
        { icon: '❓', label: 'Help & Support', onPress: () => setActiveMenu('help') },
      ],
    },
    help: {
      title: 'Help & Support',
      items: [
        { icon: '📖', label: 'User Guide', onPress: () => setHelpContent('guide') },
        { icon: '💡', label: 'Quick Tips', onPress: () => setHelpContent('tips') },
        { icon: '🆘', label: 'Support', onPress: () => setHelpContent('support') },
      ],
    },
  };

  const openMenu = (key: MenuKey) => () => setActiveMenu(key);

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <View style={styles.headerBarLeft}>
          <Pressable onPress={openMenu('drawer')}>
            <Text style={styles.headerBarIcon}>☰</Text>
          </Pressable>
          <Text style={textStyles.heading3}>Admin Dashboard</Text>
          <Text style={styles.desktopBadge}>Desktop</Text>
        </View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.headerBarMenus}>
          <Pressable style={styles.headerMenuButton} onPress={openMenu('deliveries')}>
            <Text style={styles.headerMenuButtonText}>🚚 Deliveries ▾</Text>
          </Pressable>
          <Pressable style={styles.headerMenuButton} onPress={openMenu('management')}>
            <Text style={styles.headerMenuButtonText}>🛡 Management ▾</Text>
          </Pressable>
          <Pressable style={styles.headerMenuButton} onPress={openMenu('claims')}>
            <Text style={styles.headerMenuButtonText}>⚠ Claims ▾</Text>
          </Pressable>
          <Pressable style={styles.headerMenuButton} onPress={openMenu('import')}>
            <Text style={styles.headerMenuButtonText}>📤 Import ▾</Text>
          </Pressable>
          <Pressable style={styles.headerMenuButton} onPress={openMenu('documents')}>
            <Text style={styles.headerMenuButtonText}>🧾 Documents ▾</Text>
          </Pressable>
        </ScrollView>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => navigation.navigate('ChatListDesktop')}>
            <Text style={styles.headerBarIcon}>💬</Text>
          </Pressable>
          <Pressable onPress={loadDashboardData}>
            <Text style={styles.headerBarIcon}>↻</Text>
          </Pressable>
          <Pressable onPress={handleLogout}>
            <Text style={styles.headerBarIcon}>⎋</Text>
          </Pressable>
        </View>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        {company ? (
          <View style={[styles.card, shadows.card, styles.companyCard]}>
            <View style={styles.companyLeft}>
              <View style={styles.companyLogoBox}>
                {(company.logoUrl ?? appLogoUrl) && !logoFailed ? (
                  <Image source={{ uri: company.logoUrl ?? appLogoUrl }} style={styles.companyLogoImage} resizeMode="cover" onError={() => setLogoFailed(true)} />
                ) : (
                  <Text style={styles.companyLogoFallback}>🏢</Text>
                )}
              </View>
              <View style={styles.companyTextBox}>
                <Text style={[textStyles.heading3, { color: colors.primary }]}>{company.name}</Text>
                {company.registrationNumber ? <Text style={styles.companyMeta}>Reg: {company.registrationNumber}</Text> : null}
                <Text style={styles.companyMeta} numberOfLines={1}>
                  📍 {company.address || '—'}  ✉ {company.email}
                </Text>
                <Text style={styles.companyMeta} numberOfLines={1}>
                  ☏ {company.phone || '—'}
                  {company.plan.toLowerCase() !== 'free' ? `  •  🏆 ${company.plan.toUpperCase()}` : ''}
                  {'  •  '}
                  {company.isActive ? '● Active' : '○ Inactive'}
                  {'  •  '}📅 {company.createdAt.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}
                </Text>
              </View>
            </View>
            <View style={styles.companyDivider} />
            <View style={styles.companyRight}>
              <Text style={textStyles.bodyLarge}>Welcome back, {currentUser?.fullName ?? 'Admin'}</Text>
              <Text style={styles.welcomeTimestamp}>📅 {new Date().toLocaleString(undefined, { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })}</Text>
            </View>
          </View>
        ) : null}

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Today&apos;s Overview</Text>
        <View style={styles.statsGrid}>
          <StatCard title="Total Deliveries" value={stats.totalDeliveries} subtitle="Scheduled today" icon="🚚" color={colors.primary} onPress={() => navigation.navigate('DeliveryManagement')} />
          <StatCard title="Pending" value={stats.pendingDeliveries} subtitle="Awaiting pickup" icon="⏳" color={colors.warning} onPress={() => navigation.navigate('DeliveryManagement')} />
          <StatCard title="In Transit" value={stats.inTransitDeliveries} subtitle="On the road" icon="🚛" color={colors.info} onPress={() => navigation.navigate('DeliveryManagement')} />
          <StatCard title="Completed" value={stats.completedDeliveries} subtitle="Delivered today" icon="✓" color={colors.success} onPress={() => navigation.navigate('DeliveryManagement')} />
          <StatCard title="Active Drivers" value={stats.activeDrivers} subtitle={`${stats.totalDrivers} total drivers`} icon="👤" color="#2196F3" onPress={() => navigation.navigate('UserManagement')} />
          <StatCard title="Pending Approvals" value={stats.pendingApprovals} subtitle="Driver applications" icon="🧑‍💼" color="#FF9800" onPress={() => navigation.navigate('UserManagement')} />
          <StatCard title="Claims" value={stats.pendingClaims} subtitle={`${stats.totalClaims} total claims`} icon="⚠" color="#FF5722" onPress={() => navigation.navigate('ClaimsDashboard')} />
          <StatCard title="PODs Today" value={stats.totalPODs} subtitle="Proof of delivery" icon="🧾" color="#9C27B0" onPress={() => navigation.navigate('PodViewer')} />
        </View>

        <View style={[styles.card, shadows.card]}>
          <View style={styles.recentHeaderRow}>
            <Text style={textStyles.heading3}>Recent Deliveries</Text>
            <Pressable onPress={() => navigation.navigate('DeliveryManagement')}>
              <Text style={styles.viewAllLink}>View All →</Text>
            </Pressable>
          </View>

          {recentDeliveries === null ? (
            <ActivityIndicatorBlock />
          ) : recentDeliveries.length === 0 ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyStateIcon}>📥</Text>
              <Text style={styles.emptyStateText}>No deliveries yet</Text>
              <Pressable onPress={() => navigation.navigate('CreateDelivery')}>
                <Text style={styles.viewAllLink}>Create your first delivery</Text>
              </Pressable>
            </View>
          ) : (
            recentDeliveries.map((doc, index) => {
              const data = doc.data();
              const status = (data.status as string) ?? 'pending';
              const scheduledDate = (data.scheduledDate as FirebaseFirestoreTypes.Timestamp | undefined)?.toDate();
              return (
                <Pressable
                  key={doc.id}
                  style={[styles.recentRow, index < recentDeliveries.length - 1 && styles.recentRowDivider]}
                  onPress={() => navigation.navigate('DeliveryDetails', { deliveryId: doc.id })}
                >
                  <View style={[styles.recentIconBox, { backgroundColor: `${statusColorFor(status)}1A` }]}>
                    <Text style={[styles.recentIconText, { color: statusColorFor(status) }]}>{statusIconFor(status)}</Text>
                  </View>
                  <View style={styles.recentTextBox}>
                    <Text style={styles.recentTitle} numberOfLines={1}>
                      {(data.customerName as string) ?? 'Unknown'}
                    </Text>
                    <Text style={styles.recentMeta} numberOfLines={1}>
                      Order: {(data.orderNumber as string) ?? '-'} | Invoice: {(data.invoiceNumber as string) ?? '-'}
                    </Text>
                    <Text style={styles.recentAddress} numberOfLines={1}>
                      {(data.customerAddress as string) ?? 'No address'}
                    </Text>
                  </View>
                  <View style={styles.recentTrailing}>
                    <Text style={[styles.recentStatus, { color: statusColorFor(status) }]}>{status.toUpperCase()}</Text>
                    {scheduledDate ? <Text style={styles.recentDate}>{scheduledDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</Text> : null}
                  </View>
                </Pressable>
              );
            })
          )}
        </View>
      </ScrollView>

      <Modal visible={activeMenu != null} transparent animationType="fade" onRequestClose={() => setActiveMenu(null)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setActiveMenu(null)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <Text style={styles.actionSheetTitle}>{activeMenu ? MENUS[activeMenu].title : ''}</Text>
            {activeMenu
              ? MENUS[activeMenu].items.map((item) => (
                  <ActionRow
                    key={item.label}
                    icon={item.icon}
                    label={item.label}
                    onPress={() => {
                      setActiveMenu(null);
                      item.onPress();
                    }}
                  />
                ))
              : null}
          </View>
        </Pressable>
      </Modal>

      <HelpContentModal content={helpContent} onClose={() => setHelpContent(null)} />
    </View>
  );
}

function ActivityIndicatorBlock() {
  return (
    <View style={styles.emptyState}>
      <Text style={styles.emptyStateIcon}>⏳</Text>
    </View>
  );
}

function StatCard({
  title,
  value,
  subtitle,
  icon,
  color,
  onPress,
}: {
  title: string;
  value: number;
  subtitle: string;
  icon: string;
  color: string;
  onPress: () => void;
}) {
  return (
    <Pressable style={[styles.statCard, shadows.card]} onPress={onPress}>
      <View style={[styles.statIconBox, { backgroundColor: `${color}1A` }]}>
        <Text style={[styles.statIconText, { color }]}>{icon}</Text>
      </View>
      <Text style={[styles.statValue, { color }]}>{value}</Text>
      <Text style={styles.statTitle}>{title}</Text>
      <Text style={styles.statSubtitle}>{subtitle}</Text>
    </Pressable>
  );
}

function ActionRow({ label, icon, onPress }: { label: string; icon: string; onPress: () => void }) {
  return (
    <Pressable style={styles.actionRow} onPress={onPress}>
      <Text style={styles.actionRowIcon}>{icon}</Text>
      <Text style={styles.actionRowLabel}>{label}</Text>
    </Pressable>
  );
}

const HELP_CONTENT: Record<'guide' | 'tips' | 'support', { title: string; lines: string[] }> = {
  guide: {
    title: 'PODSafe User Guide',
    lines: [
      'Welcome to PODSafe!',
      'PODSafe is a comprehensive proof-of-delivery solution that helps you manage deliveries, track PODs, and handle claims professionally.',
      'Key Features:',
      '• Create and manage deliveries',
      '• Import deliveries from ABASERVE',
      '• Track delivery status in real-time',
      '• View and download POD documents',
      '• Manage drivers and vehicles',
      '• Handle claims for damaged/missing items',
      '• Generate reports and analytics',
    ],
  },
  tips: {
    title: 'Quick Tips',
    lines: [
      '🚀 Getting Started',
      '• Use the "New Delivery" button to create deliveries',
      '• Import from ABASERVE for bulk operations',
      '• Monitor delivery status in the dashboard',
      '📊 Dashboard Overview',
      '• Green = Completed deliveries',
      '• Blue = In transit',
      '• Orange = Pending assignments',
      '• Red = Issues requiring attention',
      '💡 Pro Tips',
      '• Use filters to find specific deliveries',
      '• Export data regularly for backups',
      '• Check claims daily to resolve issues quickly',
      '• Use the chat feature for driver communication',
    ],
  },
  support: {
    title: 'Support & Resources',
    lines: [
      'Need help? Here are your support options:',
      '📧 Email Support: support@podsafe.com',
      '📱 Documentation: Complete User Guide, feature-specific guides, troubleshooting FAQ',
      '🔧 Common Issues: check your internet connection, ensure GPS is enabled for drivers, verify ABASERVE integration settings',
      'For urgent issues, please contact support directly.',
    ],
  },
};

function HelpContentModal({ content, onClose }: { content: 'guide' | 'tips' | 'support' | null; onClose: () => void }) {
  return (
    <Modal visible={content != null} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop2}>
        <ScrollView style={[styles.modalCard, shadows.card]}>
          {content ? (
            <>
              <Text style={textStyles.heading3}>{HELP_CONTENT[content].title}</Text>
              {HELP_CONTENT[content].lines.map((line, i) => (
                <Text key={i} style={styles.helpLine}>
                  {line}
                </Text>
              ))}
            </>
          ) : null}
          <Pressable style={styles.modalCloseButton} onPress={onClose}>
            <Text style={textStyles.buttonText}>Close</Text>
          </Pressable>
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  headerBarLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.small + 4 },
  headerBarIcon: { fontSize: 18, color: colors.white },
  desktopBadge: { color: colors.white, fontSize: 11, fontWeight: '700', opacity: 0.8, borderWidth: 1, borderColor: colors.white, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 },
  headerBarMenus: { flex: 1, marginHorizontal: spacing.medium },
  headerMenuButton: { paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small },
  headerMenuButtonText: { color: colors.white, fontSize: 13, fontWeight: '600' },
  headerBarRight: { flexDirection: 'row', gap: spacing.medium },
  content: { flex: 1 },
  contentInner: { padding: spacing.large, paddingBottom: spacing.xLarge },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  companyCard: { flexDirection: 'row', alignItems: 'center' },
  companyLeft: { flex: 3, flexDirection: 'row', alignItems: 'center' },
  companyLogoBox: { width: 56, height: 56, borderRadius: radii.borderRadius, backgroundColor: `${colors.primary}1A`, alignItems: 'center', justifyContent: 'center', marginRight: spacing.medium, overflow: 'hidden' },
  companyLogoImage: { width: '100%', height: '100%' },
  companyLogoFallback: { fontSize: 24 },
  companyTextBox: { flex: 1 },
  companyMeta: { color: colors.textSecondary, fontSize: 12, marginTop: 4 },
  companyDivider: { width: 1, height: 60, backgroundColor: colors.divider, marginHorizontal: spacing.large },
  companyRight: { flex: 2 },
  welcomeTimestamp: { color: colors.textSecondary, fontSize: 11, marginTop: 4 },
  sectionTitle: { marginBottom: spacing.small + 4 },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium, marginBottom: spacing.large },
  statCard: { width: 200, backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, ...shadows.card },
  statIconBox: { width: 40, height: 40, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center' },
  statIconText: { fontSize: 18 },
  statValue: { fontSize: 26, fontWeight: 'bold', marginTop: spacing.small },
  statTitle: { fontSize: 13, fontWeight: '600', color: colors.textPrimary, marginTop: 2 },
  statSubtitle: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  recentHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.medium },
  viewAllLink: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  emptyState: { alignItems: 'center', paddingVertical: spacing.large },
  emptyStateIcon: { fontSize: 40, opacity: 0.4, marginBottom: spacing.small },
  emptyStateText: { color: colors.textSecondary, marginBottom: spacing.small },
  recentRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4 },
  recentRowDivider: { borderBottomWidth: 1, borderBottomColor: colors.divider },
  recentIconBox: { width: 44, height: 44, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  recentIconText: { fontSize: 18 },
  recentTextBox: { flex: 1, marginRight: spacing.small },
  recentTitle: { fontWeight: '600', fontSize: 14 },
  recentMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  recentAddress: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  recentTrailing: { alignItems: 'flex-end' },
  recentStatus: { fontWeight: 'bold', fontSize: 11 },
  recentDate: { color: colors.textSecondary, fontSize: 11, marginTop: 2 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  modalBackdrop2: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionSheetTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary, marginBottom: spacing.small },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600', color: colors.textPrimary },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 480, maxHeight: '80%' },
  helpLine: { marginTop: spacing.small + 4, color: colors.textPrimary, lineHeight: 20 },
  modalCloseButton: { marginTop: spacing.large, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
});
