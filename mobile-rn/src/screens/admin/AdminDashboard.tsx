import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Image,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import firestore from '@react-native-firebase/firestore';
import {
  AdminMetricCard,
  AdminSectionHeader,
} from '../../components/admin/AdminPrimitives';
import { AdminShell } from '../../components/admin/AdminShell';
import {
  AppIcon,
  AppIconName,
  Card,
  EmptyState,
  ErrorState,
  LoadingState,
  PrimaryButton,
  SecondaryButton,
  StatusChip,
} from '../../components/ui';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { AuthRepository } from '../../repositories/authRepository';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { useAuthStore } from '../../stores/useAuthStore';
import { useCompanyStore } from '../../stores/useCompanyStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import {
  getEndOfTodaySA,
  getSouthAfricanTime,
  getStartOfTodaySA,
} from '../../utils/datetimeHelper';

interface AdminDashboardProps {
  navigation: {
    navigate: (screen: string, params?: Record<string, unknown>) => void;
  };
}

type DashboardStats = {
  total: number;
  pending: number;
  completed: number;
  activeDrivers: number;
};
type StatusTone = 'success' | 'info' | 'warning' | 'error';

const authRepository = new AuthRepository();
const deliveryRepository = new DeliveryRepository();

const statusTone: Record<DeliveryStatus, StatusTone> = {
  pending: 'warning',
  inTransit: 'info',
  delivered: 'success',
  failed: 'error',
};

const statusIcon: Record<DeliveryStatus, AppIconName> = {
  pending: 'calendar',
  inTransit: 'truck',
  delivered: 'check',
  failed: 'alert',
};

const statusLabel: Record<DeliveryStatus, string> = {
  pending: 'Pending',
  inTransit: 'In transit',
  delivered: 'Delivered',
  failed: 'Attention needed',
};

function valueAsDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { toDate?: unknown }).toDate === 'function'
  ) {
    // Call as a method so `this` is preserved — the web modular SDK's
    // Timestamp.toDate() is `new Date(this.toMillis())` and throws if invoked
    // unbound (extracting the function into a variable loses `this`).
    return (value as { toDate: () => Date }).toDate();
  }
  return null;
}

function formatSastToday(): string {
  const sast = getSouthAfricanTime();
  const date = new Date(
    Date.UTC(sast.getUTCFullYear(), sast.getUTCMonth(), sast.getUTCDate()),
  );
  return date.toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  });
}

export default function AdminDashboard({ navigation }: AdminDashboardProps) {
  const currentUser = useAuthStore(state => state.currentUser);
  const signOut = useAuthStore(state => state.signOut);
  const company = useCompanyStore(state => state.company);
  const subscribeToCompany = useCompanyStore(state => state.subscribeToCompany);
  const { width } = useWindowDimensions();
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [stats, setStats] = useState<DashboardStats>({
    total: 0,
    pending: 0,
    completed: 0,
    activeDrivers: 0,
  });
  const [recentDeliveries, setRecentDeliveries] = useState<Delivery[] | null>(
    null,
  );
  const isDesktop = width >= 1200;

  const loadDashboardData = useCallback(async () => {
    if (!currentUser) return;
    setIsLoading(true);
    setErrorMessage(null);
    try {
      const startOfToday = getStartOfTodaySA();
      const endOfToday = getEndOfTodaySA();
      let deliveryDocuments;
      try {
        const deliveriesSnapshot = await firestore()
          .collection('deliveries')
          .where('companyId', '==', currentUser.companyId)
          .where(
            'scheduledDate',
            '>=',
            firestore.Timestamp.fromDate(startOfToday),
          )
          .where(
            'scheduledDate',
            '<=',
            firestore.Timestamp.fromDate(endOfToday),
          )
          .get();
        deliveryDocuments = deliveriesSnapshot.docs;
      } catch {
        const companyDeliveries = await firestore()
          .collection('deliveries')
          .where('companyId', '==', currentUser.companyId)
          .get();
        deliveryDocuments = companyDeliveries.docs.filter(document => {
          const scheduledDate = valueAsDate(document.data().scheduledDate);
          return Boolean(
            scheduledDate &&
              scheduledDate >= startOfToday &&
              scheduledDate <= endOfToday,
          );
        });
      }
      let pending = 0;
      let completed = 0;
      deliveryDocuments.forEach(document => {
        if (document.data().status === 'delivered') completed += 1;
        else pending += 1;
      });
      const activeDrivers = await authRepository.getUsersByCompany(
        currentUser.companyId,
        { role: 'driver', approvalStatus: 'approved' },
      );
      setStats({
        total: deliveryDocuments.length,
        pending,
        completed,
        activeDrivers: activeDrivers.length,
      });
    } catch (error) {
      const message = (error as Error).message;
      setErrorMessage(message);
      Alert.alert(
        'Dashboard unavailable',
        'The operational summary could not be refreshed. Try again shortly.',
      );
    } finally {
      setIsLoading(false);
    }
  }, [currentUser]);

  useEffect(() => {
    loadDashboardData().catch(() => undefined);
  }, [loadDashboardData]);

  useEffect(() => {
    if (currentUser) subscribeToCompany(currentUser.companyId);
  }, [currentUser, subscribeToCompany]);

  useEffect(() => {
    if (!currentUser) return undefined;
    return deliveryRepository.subscribeToCompanyDeliveries(
      currentUser.companyId,
      setRecentDeliveries,
      () => setRecentDeliveries([]),
      { limit: 8 },
    );
  }, [currentUser]);

  const filteredDeliveries = useMemo(() => {
    const source = recentDeliveries ?? [];
    const normalizedQuery = query.trim().toLowerCase();
    if (!normalizedQuery) return source;
    return source.filter(delivery =>
      [
        delivery.customerName,
        delivery.customerAddress,
        delivery.invoiceNumber,
        delivery.orderNumber ?? '',
      ]
        .join(' ')
        .toLowerCase()
        .includes(normalizedQuery),
    );
  }, [query, recentDeliveries]);

  const handleLogout = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  return (
    <AdminShell
      activeNav="dashboard"
      title="Operations dashboard"
      userName={currentUser?.fullName}
      searchValue={query}
      onNavigate={screen => navigation.navigate(screen)}
      onSearchChange={setQuery}
      onRefresh={loadDashboardData}
      onLogout={handleLogout}
    >
      {isLoading ? (
        <LoadingState
          title="Loading operations"
          message="Refreshing deliveries, drivers, and exceptions."
        />
      ) : errorMessage ? (
        <ErrorState
          title="Dashboard needs attention"
          message={errorMessage}
          onAction={loadDashboardData}
        />
      ) : (
        <ScrollView
          contentContainerStyle={[styles.page, isDesktop && styles.pageDesktop]}
          refreshControl={
            <RefreshControl
              refreshing={false}
              onRefresh={loadDashboardData}
              colors={[colors.active]}
            />
          }
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.pageHeading}>
            <View style={styles.pageHeadingCopy}>
              <Text style={textStyles.heading2}>Today’s operations</Text>
              <Text style={textStyles.bodyMedium}>{formatSastToday()}</Text>
            </View>
            <PrimaryButton
              label="New delivery"
              icon="plus"
              onPress={() => navigation.navigate('CreateDelivery')}
              style={styles.createButton}
            />
          </View>

          {company ? (
            <CompanyCard
              company={company}
              onManage={() => navigation.navigate('AdminSettings')}
            />
          ) : null}

          <View style={styles.metricsGrid}>
            <AdminMetricCard
              title="Scheduled"
              value={stats.total}
              description="Deliveries today"
              icon="truck"
              tone="info"
            />
            <AdminMetricCard
              title="Needs action"
              value={stats.pending}
              description="Pending deliveries"
              icon="alert"
              tone="warning"
            />
            <AdminMetricCard
              title="Completed"
              value={stats.completed}
              description="Proofs completed today"
              icon="check"
              tone="success"
            />
            <AdminMetricCard
              title="Active drivers"
              value={stats.activeDrivers}
              description="Approved driver accounts"
              icon="users"
              tone="info"
            />
          </View>

          <View
            style={[
              styles.workspaceGrid,
              isDesktop && styles.workspaceGridDesktop,
            ]}
          >
            <Card style={[styles.workspaceCard, styles.deliveryWorkspace]}>
              <AdminSectionHeader
                title="Recent deliveries"
                actionLabel="View deliveries"
                onAction={() => navigation.navigate('DeliveryManagement')}
              />
              {recentDeliveries === null ? (
                <LoadingState title="Loading deliveries" message="" />
              ) : filteredDeliveries.length === 0 ? (
                <EmptyState
                  title={
                    query ? 'No matching deliveries' : 'No recent deliveries'
                  }
                  message={
                    query
                      ? 'Clear the dashboard filter or try another customer or invoice.'
                      : 'Create a delivery to begin your operations day.'
                  }
                  actionLabel={query ? 'Clear filter' : 'Create delivery'}
                  onAction={
                    query
                      ? () => setQuery('')
                      : () => navigation.navigate('CreateDelivery')
                  }
                  icon={query ? 'search' : 'truck'}
                />
              ) : (
                <DeliveryTable
                  deliveries={filteredDeliveries}
                  onOpen={delivery =>
                    navigation.navigate('DeliveryDetails', {
                      deliveryId: delivery.id,
                    })
                  }
                />
              )}
            </Card>

            <View style={styles.sideColumn}>
              <Card style={styles.workspaceCard}>
                <AdminSectionHeader title="Exception queue" />
                <ExceptionQueue
                  deliveries={recentDeliveries ?? []}
                  onOpen={delivery =>
                    navigation.navigate('DeliveryDetails', {
                      deliveryId: delivery.id,
                    })
                  }
                />
              </Card>
              <Card style={styles.workspaceCard}>
                <AdminSectionHeader title="Quick actions" />
                <View style={styles.quickActions}>
                  <SecondaryButton
                    label="Proofs of delivery"
                    icon="signature"
                    onPress={() => navigation.navigate('PodViewer')}
                  />
                  <SecondaryButton
                    label="Manage drivers"
                    icon="users"
                    onPress={() => navigation.navigate('DriverManagement')}
                  />
                  <SecondaryButton
                    label="Review claims"
                    icon="alert"
                    onPress={() => navigation.navigate('ClaimsDashboard')}
                  />
                </View>
              </Card>
            </View>
          </View>
        </ScrollView>
      )}
    </AdminShell>
  );
}

function CompanyCard({
  company,
  onManage,
}: {
  company: {
    name: string;
    email: string;
    address?: string;
    logoUrl?: string;
    plan: string;
    isActive: boolean;
  };
  onManage: () => void;
}) {
  return (
    <Card style={styles.companyCard}>
      <View style={styles.companyIdentity}>
        <View style={styles.companyMark}>
          {company.logoUrl ? (
            <Image
              source={{ uri: company.logoUrl }}
              resizeMode="cover"
              style={styles.companyLogo}
            />
          ) : (
            <AppIcon name="users" size={28} color={colors.shell} />
          )}
        </View>
        <View style={styles.companyCopy}>
          <Text style={textStyles.heading3}>{company.name}</Text>
          <Text numberOfLines={1} style={textStyles.bodySmall}>
            {company.address || company.email}
          </Text>
        </View>
      </View>
      <View style={styles.companyActions}>
        <StatusChip
          label={company.isActive ? `${company.plan} plan` : 'Account inactive'}
          tone={company.isActive ? 'success' : 'warning'}
          icon={company.isActive ? 'check' : 'alert'}
        />
        <SecondaryButton
          label="Manage"
          icon="settings"
          onPress={onManage}
          style={styles.manageButton}
        />
      </View>
    </Card>
  );
}

function DeliveryTable({
  deliveries,
  onOpen,
}: {
  deliveries: Delivery[];
  onOpen: (delivery: Delivery) => void;
}) {
  return (
    <View style={styles.table}>
      <View style={styles.tableHeader}>
        <Text style={[styles.tableHeading, styles.customerColumn]}>
          Customer
        </Text>
        <Text style={[styles.tableHeading, styles.invoiceColumn]}>Invoice</Text>
        <Text style={[styles.tableHeading, styles.statusColumn]}>Status</Text>
      </View>
      {deliveries.map(delivery => (
        <Pressable
          key={delivery.id}
          accessibilityRole="button"
          accessibilityLabel={`Open delivery for ${delivery.customerName}`}
          onPress={() => onOpen(delivery)}
          style={({ pressed }) => [
            styles.deliveryRow,
            pressed && styles.rowPressed,
          ]}
        >
          <View style={styles.customerColumn}>
            <Text numberOfLines={1} style={textStyles.label}>
              {delivery.customerName}
            </Text>
            <Text numberOfLines={1} style={textStyles.bodySmall}>
              {delivery.customerAddress}
            </Text>
          </View>
          <Text
            numberOfLines={1}
            style={[textStyles.bodySmall, styles.invoiceColumn]}
          >
            {delivery.invoiceNumber}
          </Text>
          <View style={styles.statusColumn}>
            <StatusChip
              label={statusLabel[delivery.status]}
              tone={statusTone[delivery.status]}
              icon={statusIcon[delivery.status]}
            />
          </View>
        </Pressable>
      ))}
    </View>
  );
}

function ExceptionQueue({
  deliveries,
  onOpen,
}: {
  deliveries: Delivery[];
  onOpen: (delivery: Delivery) => void;
}) {
  const exceptions = deliveries
    .filter(
      delivery => delivery.status === 'pending' || delivery.status === 'failed',
    )
    .slice(0, 4);
  if (!exceptions.length)
    return (
      <EmptyState
        title="No delivery exceptions"
        message="Pending and failed deliveries will appear here."
        icon="check"
      />
    );
  return (
    <View style={styles.exceptionList}>
      {exceptions.map(delivery => (
        <Pressable
          key={delivery.id}
          accessibilityRole="button"
          accessibilityLabel={`Review ${delivery.customerName}`}
          onPress={() => onOpen(delivery)}
          style={({ pressed }) => [
            styles.exceptionRow,
            pressed && styles.rowPressed,
          ]}
        >
          <View style={styles.exceptionIcon}>
            <AppIcon
              name={statusIcon[delivery.status]}
              size={20}
              color={
                delivery.status === 'failed'
                  ? colors.critical
                  : colors.attention
              }
            />
          </View>
          <View style={styles.exceptionCopy}>
            <Text numberOfLines={1} style={textStyles.label}>
              {delivery.customerName}
            </Text>
            <Text numberOfLines={1} style={textStyles.bodySmall}>
              {delivery.status === 'failed'
                ? 'Delivery failed - review evidence'
                : 'Pending driver action'}
            </Text>
          </View>
          <AppIcon
            name="chevronRight"
            size={20}
            color={colors.contentSecondary}
          />
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  page: {
    gap: spacing.large,
    padding: spacing.medium,
    paddingBottom: spacing.xxLarge,
  },
  pageDesktop: {
    alignSelf: 'center',
    maxWidth: 1440,
    padding: spacing.large,
    width: '100%',
  },
  pageHeading: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.medium,
    justifyContent: 'space-between',
  },
  pageHeadingCopy: { flex: 1, gap: spacing.xs },
  createButton: { minWidth: 156 },
  companyCard: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.medium,
    justifyContent: 'space-between',
  },
  companyIdentity: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    gap: spacing.medium,
    minWidth: 0,
  },
  companyMark: {
    alignItems: 'center',
    backgroundColor: colors.verifiedMuted,
    borderRadius: 28,
    height: 56,
    justifyContent: 'center',
    overflow: 'hidden',
    width: 56,
  },
  companyLogo: { height: '100%', width: '100%' },
  companyCopy: { flex: 1, gap: spacing.xs },
  companyActions: { alignItems: 'flex-end', gap: spacing.small },
  manageButton: { minWidth: 112 },
  metricsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium },
  workspaceGrid: { gap: spacing.medium },
  workspaceGridDesktop: { alignItems: 'flex-start', flexDirection: 'row' },
  workspaceCard: { gap: spacing.medium },
  deliveryWorkspace: { flex: 2, width: '100%' },
  sideColumn: { flex: 1, gap: spacing.medium, width: '100%' },
  table: {
    borderColor: colors.border,
    borderRadius: spacing.small,
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
  },
  tableHeader: {
    backgroundColor: colors.surfaceMuted,
    flexDirection: 'row',
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
  },
  tableHeading: { ...textStyles.labelSmall, color: colors.contentSecondary },
  customerColumn: { flex: 1.5, minWidth: 0 },
  invoiceColumn: { flex: 0.8, minWidth: 0, paddingLeft: spacing.small },
  statusColumn: {
    alignItems: 'flex-end',
    flex: 1,
    minWidth: 112,
    paddingLeft: spacing.small,
  },
  deliveryRow: {
    alignItems: 'center',
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 68,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
  },
  rowPressed: { backgroundColor: colors.surfaceMuted },
  exceptionList: { gap: spacing.xs },
  exceptionRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.small,
    minHeight: 64,
    paddingVertical: spacing.small,
  },
  exceptionIcon: {
    alignItems: 'center',
    backgroundColor: colors.attentionMuted,
    borderRadius: 20,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  exceptionCopy: { flex: 1, gap: spacing.xs },
  quickActions: { gap: spacing.small },
});
