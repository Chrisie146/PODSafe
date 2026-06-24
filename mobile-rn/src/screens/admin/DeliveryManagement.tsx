import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import { AdminToolbar } from '../../components/admin/AdminPrimitives';
import { AdminShell } from '../../components/admin/AdminShell';
import {
  AppIcon,
  AppIconName,
  AppModal,
  Card,
  EmptyState,
  ErrorState,
  IconButton,
  LoadingState,
  PrimaryButton,
  SearchField,
  SecondaryButton,
  StatusChip,
} from '../../components/ui';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import {
  hasAnyPermission,
  hasPermission,
} from '../../permissions/permissionService';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { useAuthStore } from '../../stores/useAuthStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const TABS: { key: DeliveryStatus | null; label: string }[] = [
  { key: null, label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'inTransit', label: 'Active' },
  { key: 'delivered', label: 'Completed' },
];

type StatusTone = 'info' | 'warning' | 'success' | 'error';

const STATUS: Record<
  DeliveryStatus,
  { icon: AppIconName; label: string; tone: StatusTone }
> = {
  pending: { icon: 'calendar', label: 'Pending', tone: 'warning' },
  inTransit: { icon: 'truck', label: 'In transit', tone: 'info' },
  delivered: { icon: 'check', label: 'Delivered', tone: 'success' },
  failed: { icon: 'alert', label: 'Failed', tone: 'error' },
};

interface DeliveryManagementProps {
  navigation: {
    navigate: (screen: string, params?: Record<string, unknown>) => void;
  };
}

const deliveryRepository = new DeliveryRepository();

/** Responsive Wave A delivery operations workspace. */
export default function DeliveryManagement({
  navigation,
}: DeliveryManagementProps) {
  const currentUser = useAuthStore(state => state.currentUser);
  const signOut = useAuthStore(state => state.signOut);
  const { width } = useWindowDimensions();
  const isDesktop = width >= 1200;
  const [activeTab, setActiveTab] = useState<DeliveryStatus | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [showActions, setShowActions] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [deliveriesByTab, setDeliveriesByTab] = useState<
    Record<string, Delivery[] | null>
  >({
    all: null,
    pending: null,
    inTransit: null,
    delivered: null,
  });

  const canExport = hasAnyPermission(currentUser, [
    'deliveriesManage',
    'financeExport',
  ]);
  const canCreate = hasPermission(currentUser, 'deliveriesManage');

  const refresh = useCallback(() => {
    setErrorMessage(null);
    setIsRefreshing(true);
    setRefreshKey(value => value + 1);
  }, []);

  useEffect(() => {
    if (!currentUser) return undefined;
    setErrorMessage(null);
    const unsubscribes = TABS.map(({ key }) =>
      deliveryRepository.subscribeToCompanyDeliveries(
        currentUser.companyId,
        deliveries => {
          setDeliveriesByTab(previous => ({
            ...previous,
            [key ?? 'all']: deliveries,
          }));
          setIsRefreshing(false);
        },
        error => {
          setErrorMessage(error.message || 'Deliveries could not be loaded.');
          setIsRefreshing(false);
        },
        { status: key ?? undefined, orderByScheduledDate: true },
      ),
    );

    return () => unsubscribes.forEach(unsubscribe => unsubscribe());
  }, [currentUser, refreshKey]);

  const activeDeliveries = deliveriesByTab[activeTab ?? 'all'];
  const filteredDeliveries = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();
    return (
      activeDeliveries?.filter(delivery => {
        if (!normalizedQuery) return true;
        return [
          delivery.customerName,
          delivery.customerAddress,
          delivery.invoiceNumber,
          delivery.orderNumber ?? '',
          delivery.customerNumber ?? '',
        ]
          .join(' ')
          .toLowerCase()
          .includes(normalizedQuery);
      }) ?? null
    );
  }, [activeDeliveries, searchQuery]);

  const handleSignOut = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  const announceComingSoon = (label: string) => {
    setShowActions(false);
    Alert.alert(label, 'This export option is not available yet.');
  };

  const heading = (
    <View style={styles.heading}>
      <View style={styles.headingCopy}>
        <Text style={textStyles.heading2}>Delivery operations</Text>
        <Text style={textStyles.bodyMedium}>
          Search, review, and route the company delivery queue.
        </Text>
      </View>
      {canCreate ? (
        <PrimaryButton
          label="New delivery"
          icon="plus"
          onPress={() => navigation.navigate('CreateDelivery')}
          style={styles.createButton}
        />
      ) : null}
    </View>
  );

  const filters = (
    <AdminToolbar style={styles.filters}>
      {!isDesktop ? (
        <View style={styles.searchRow}>
          <SearchField
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search customer, address, or invoice"
            containerStyle={styles.search}
          />
          {searchQuery ? (
            <IconButton
              icon="close"
              accessibilityLabel="Clear delivery search"
              onPress={() => setSearchQuery('')}
            />
          ) : null}
        </View>
      ) : null}
      <View accessibilityRole="tablist" style={styles.tabList}>
        {TABS.map(tab => {
          const selected = activeTab === tab.key;
          return (
            <Pressable
              key={tab.label}
              accessibilityRole="button"
              accessibilityLabel={`${tab.label} deliveries`}
              accessibilityState={{ selected }}
              onPress={() => setActiveTab(tab.key)}
              style={({ pressed }) => [
                styles.tab,
                selected && styles.tabSelected,
                pressed && styles.pressed,
              ]}
            >
              <Text
                style={[styles.tabLabel, selected && styles.tabLabelSelected]}
              >
                {tab.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
      {canExport ? (
        <SecondaryButton
          label="Delivery actions"
          icon="more"
          onPress={() => setShowActions(true)}
          style={styles.actionsButton}
        />
      ) : null}
    </AdminToolbar>
  );

  const content = errorMessage ? (
    <ErrorState
      title="Deliveries need attention"
      message={errorMessage}
      onAction={refresh}
    />
  ) : filteredDeliveries === null ? (
    <LoadingState
      title="Loading deliveries"
      message="Retrieving the latest delivery queue."
    />
  ) : filteredDeliveries.length === 0 ? (
    <EmptyState
      title={
        searchQuery
          ? 'No matching deliveries'
          : activeTab
          ? `No ${STATUS[activeTab].label.toLowerCase()} deliveries`
          : 'No deliveries yet'
      }
      message={
        searchQuery
          ? 'Try a different customer, address, or invoice number.'
          : 'Create a delivery to begin planning the next route.'
      }
      icon={searchQuery ? 'search' : 'truck'}
      actionLabel={
        searchQuery ? 'Clear search' : canCreate ? 'New delivery' : undefined
      }
      onAction={
        searchQuery
          ? () => setSearchQuery('')
          : canCreate
          ? () => navigation.navigate('CreateDelivery')
          : undefined
      }
    />
  ) : (
    <FlatList
      data={filteredDeliveries}
      keyExtractor={delivery => delivery.id}
      contentContainerStyle={styles.listContent}
      ListHeaderComponent={isDesktop ? <DesktopTableHeader /> : null}
      refreshControl={
        <RefreshControl
          refreshing={isRefreshing}
          onRefresh={refresh}
          colors={[colors.active]}
        />
      }
      renderItem={({ item }) => (
        <DeliveryRow
          delivery={item}
          desktop={isDesktop}
          onPress={() =>
            navigation.navigate('DeliveryDetails', { deliveryId: item.id })
          }
        />
      )}
    />
  );

  return (
    <AdminShell
      activeNav="deliveries"
      title="Deliveries"
      userName={currentUser?.fullName}
      searchValue={searchQuery}
      searchPlaceholder="Search deliveries"
      onNavigate={screen => navigation.navigate(screen)}
      onSearchChange={setSearchQuery}
      onRefresh={refresh}
      onLogout={handleSignOut}
    >
      <View style={styles.workspace}>
        <View style={styles.page}>
          {heading}
          {filters}
        </View>
        {content}
      </View>
      <AppModal
        visible={showActions}
        title="Delivery actions"
        onClose={() => setShowActions(false)}
      >
        <View style={styles.actionList}>
          <SecondaryButton
            label="Bulk upload CSV"
            icon="upload"
            onPress={() => {
              setShowActions(false);
              navigation.navigate('BulkUpload');
            }}
          />
          <SecondaryButton
            label="Download template"
            icon="download"
            onPress={() => announceComingSoon('Download template')}
          />
          <SecondaryButton
            label="Export all deliveries"
            icon="chart"
            onPress={() => announceComingSoon('Export all deliveries')}
          />
        </View>
      </AppModal>
    </AdminShell>
  );
}

function DesktopTableHeader() {
  return (
    <View style={styles.tableHeader}>
      <Text style={[styles.tableHeading, styles.customerColumn]}>Customer</Text>
      <Text style={[styles.tableHeading, styles.referenceColumn]}>
        References
      </Text>
      <Text style={[styles.tableHeading, styles.scheduleColumn]}>
        Scheduled
      </Text>
      <Text style={[styles.tableHeading, styles.statusColumn]}>Status</Text>
      <View style={styles.chevronColumn} />
    </View>
  );
}

function DeliveryRow({
  delivery,
  desktop,
  onPress,
}: {
  delivery: Delivery;
  desktop: boolean;
  onPress: () => void;
}) {
  const status = STATUS[delivery.status];
  const schedule = delivery.scheduledDate.toLocaleDateString(undefined, {
    weekday: desktop ? undefined : 'short',
    month: 'short',
    day: 'numeric',
    year: desktop ? 'numeric' : undefined,
  });

  if (desktop) {
    return (
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Open delivery for ${delivery.customerName}`}
        onPress={onPress}
        style={({ pressed }) => [
          styles.desktopRow,
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
        <View style={styles.referenceColumn}>
          <Text numberOfLines={1} style={textStyles.bodySmall}>
            Invoice {delivery.invoiceNumber}
          </Text>
          {delivery.orderNumber ? (
            <Text numberOfLines={1} style={textStyles.bodySmall}>
              Order {delivery.orderNumber}
            </Text>
          ) : null}
        </View>
        <Text style={[textStyles.bodySmall, styles.scheduleColumn]}>
          {schedule}
        </Text>
        <View style={styles.statusColumn}>
          <StatusChip
            label={status.label}
            tone={status.tone}
            icon={status.icon}
          />
        </View>
        <View style={styles.chevronColumn}>
          <AppIcon
            name="chevronRight"
            size={20}
            color={colors.contentSecondary}
          />
        </View>
      </Pressable>
    );
  }

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Open delivery for ${delivery.customerName}`}
      onPress={onPress}
      style={({ pressed }) => pressed && styles.pressed}
    >
      <Card style={styles.deliveryCard}>
        <View style={styles.cardTop}>
          <View
            style={[
              styles.statusIcon,
              { backgroundColor: toneBackground(status.tone) },
            ]}
          >
            <AppIcon
              name={status.icon}
              size={22}
              color={toneColor(status.tone)}
            />
          </View>
          <View style={styles.cardCopy}>
            <Text numberOfLines={1} style={textStyles.heading3}>
              {delivery.customerName}
            </Text>
            <Text numberOfLines={1} style={textStyles.bodySmall}>
              Invoice {delivery.invoiceNumber}
            </Text>
          </View>
          <StatusChip
            label={status.label}
            tone={status.tone}
            icon={status.icon}
          />
        </View>
        <View style={styles.divider} />
        <InfoLine icon="location" label={delivery.customerAddress} />
        <InfoLine
          icon="calendar"
          label={schedule}
          trailing={
            delivery.items.length
              ? `${delivery.items.length} item${
                  delivery.items.length === 1 ? '' : 's'
                }`
              : undefined
          }
        />
        {delivery.vehicleUsed ? (
          <InfoLine icon="vehicle" label={`Vehicle ${delivery.vehicleUsed}`} />
        ) : null}
      </Card>
    </Pressable>
  );
}

function InfoLine({
  icon,
  label,
  trailing,
}: {
  icon: AppIconName;
  label: string;
  trailing?: string;
}) {
  return (
    <View style={styles.infoLine}>
      <AppIcon name={icon} size={18} color={colors.contentSecondary} />
      <Text numberOfLines={1} style={[textStyles.bodyMedium, styles.infoLabel]}>
        {label}
      </Text>
      {trailing ? <Text style={textStyles.bodySmall}>{trailing}</Text> : null}
    </View>
  );
}

function toneColor(tone: StatusTone) {
  return {
    info: colors.active,
    warning: colors.attention,
    success: colors.verified,
    error: colors.critical,
  }[tone];
}

function toneBackground(tone: StatusTone) {
  return {
    info: colors.activeMuted,
    warning: colors.attentionMuted,
    success: colors.verifiedMuted,
    error: colors.criticalMuted,
  }[tone];
}

const styles = StyleSheet.create({
  workspace: { flex: 1 },
  page: { gap: spacing.medium, padding: spacing.medium },
  heading: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.medium,
    justifyContent: 'space-between',
  },
  headingCopy: { flex: 1, gap: spacing.xs },
  createButton: { minWidth: 150 },
  filters: { alignItems: 'stretch', gap: spacing.small },
  searchRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  search: { flex: 1 },
  tabList: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs },
  tab: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 999,
    borderWidth: StyleSheet.hairlineWidth,
    justifyContent: 'center',
    minHeight: 40,
    paddingHorizontal: spacing.medium,
  },
  tabSelected: { backgroundColor: colors.shell, borderColor: colors.shell },
  tabLabel: textStyles.labelSmall,
  tabLabelSelected: { color: colors.onPrimary },
  actionsButton: { alignSelf: 'flex-start' },
  listContent: {
    gap: spacing.small,
    paddingHorizontal: spacing.medium,
    paddingBottom: spacing.xxLarge,
  },
  tableHeader: {
    alignItems: 'center',
    backgroundColor: colors.surfaceMuted,
    borderColor: colors.border,
    borderRadius: spacing.small,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 44,
    paddingHorizontal: spacing.medium,
  },
  tableHeading: { ...textStyles.labelSmall, color: colors.contentSecondary },
  customerColumn: { flex: 1.55, minWidth: 0 },
  referenceColumn: { flex: 1, minWidth: 0, paddingLeft: spacing.small },
  scheduleColumn: { flex: 0.8, minWidth: 0, paddingLeft: spacing.small },
  statusColumn: {
    alignItems: 'flex-start',
    flex: 0.85,
    minWidth: 112,
    paddingLeft: spacing.small,
  },
  chevronColumn: { alignItems: 'flex-end', width: 28 },
  desktopRow: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: spacing.small,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 76,
    paddingHorizontal: spacing.medium,
  },
  deliveryCard: { gap: spacing.small },
  cardTop: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.small,
  },
  statusIcon: {
    alignItems: 'center',
    borderRadius: 14,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  cardCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  divider: {
    backgroundColor: colors.border,
    height: StyleSheet.hairlineWidth,
    marginVertical: spacing.xs,
  },
  infoLine: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
    minHeight: 24,
  },
  infoLabel: { flex: 1, minWidth: 0 },
  actionList: { gap: spacing.small },
  pressed: { opacity: 0.8 },
  rowPressed: { backgroundColor: colors.surfaceMuted },
});
