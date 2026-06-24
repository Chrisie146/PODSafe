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
  SearchField,
  SecondaryButton,
  StatusChip,
} from '../../components/ui';
import { PodRecord } from '../../models/pod';
import { PodRepository } from '../../repositories/podRepository';
import { useAuthStore } from '../../stores/useAuthStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

type DateFilter = 'all' | 'today' | 'week' | 'month';

const FILTER_LABELS: Record<DateFilter, string> = {
  all: 'All proofs',
  today: 'Today',
  week: 'This week',
  month: 'This month',
};

interface PodViewerProps {
  navigation: {
    navigate: (screen: string, params?: Record<string, unknown>) => void;
  };
}

const podRepository = new PodRepository();

function filterSinceDate(filter: DateFilter): Date | undefined {
  const now = new Date();
  switch (filter) {
    case 'today':
      return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    case 'week':
      return new Date(now.getTime() - 7 * 86400000);
    case 'month':
      return new Date(now.getFullYear(), now.getMonth(), 1);
    case 'all':
      return undefined;
  }
}

/** Evidence-first Wave A proof review workspace. */
export default function PodViewer({ navigation }: PodViewerProps) {
  const currentUser = useAuthStore(state => state.currentUser);
  const signOut = useAuthStore(state => state.signOut);
  const { width } = useWindowDimensions();
  const isDesktop = width >= 1200;
  const [filter, setFilter] = useState<DateFilter>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [showFilterDialog, setShowFilterDialog] = useState(false);
  const [pods, setPods] = useState<PodRecord[] | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  const refresh = useCallback(() => {
    setErrorMessage(null);
    setIsRefreshing(true);
    setRefreshKey(value => value + 1);
  }, []);

  useEffect(() => {
    if (!currentUser) return undefined;
    setPods(null);
    setErrorMessage(null);
    const unsubscribe = podRepository.subscribeToCompanyPods(
      currentUser.companyId,
      nextPods => {
        setPods(nextPods);
        setIsRefreshing(false);
      },
      error => {
        setErrorMessage(
          error.message || 'Proofs of delivery could not be loaded.',
        );
        setIsRefreshing(false);
      },
      { since: filterSinceDate(filter) },
    );
    return unsubscribe;
  }, [currentUser, filter, refreshKey]);

  const filteredPods = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();
    if (!normalizedQuery) return pods;
    return (
      pods?.filter(pod =>
        [
          pod.customerName,
          pod.deliveryId,
          pod.invoiceNumber,
          pod.signedBy ?? '',
          pod.metadata.customerNumber ?? '',
          pod.metadata.orderNumber ?? '',
        ]
          .join(' ')
          .toLowerCase()
          .includes(normalizedQuery),
      ) ?? null
    );
  }, [pods, searchQuery]);

  const handleSignOut = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  const header = (
    <View style={styles.heading}>
      <View style={styles.headingCopy}>
        <Text style={textStyles.heading2}>Evidence review</Text>
        <Text style={textStyles.bodyMedium}>
          Review delivery photos, signatures, and location evidence.
        </Text>
      </View>
      <SecondaryButton
        label={FILTER_LABELS[filter]}
        icon="filter"
        onPress={() => setShowFilterDialog(true)}
        style={styles.filterButton}
      />
    </View>
  );

  const toolbar = (
    <AdminToolbar style={styles.toolbar}>
      {!isDesktop ? (
        <View style={styles.searchRow}>
          <SearchField
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search proof, invoice, or receiver"
            containerStyle={styles.search}
          />
          {searchQuery ? (
            <IconButton
              icon="close"
              accessibilityLabel="Clear proof search"
              onPress={() => setSearchQuery('')}
            />
          ) : null}
        </View>
      ) : null}
      <View style={styles.filterHint}>
        <AppIcon name="filter" size={18} color={colors.contentSecondary} />
        <Text style={textStyles.bodySmall}>{FILTER_LABELS[filter]}</Text>
      </View>
    </AdminToolbar>
  );

  const content = errorMessage ? (
    <ErrorState
      title="Proofs could not be loaded"
      message={errorMessage}
      onAction={refresh}
    />
  ) : filteredPods === null ? (
    <LoadingState
      title="Loading proofs of delivery"
      message="Retrieving the latest evidence records."
    />
  ) : filteredPods.length === 0 ? (
    <EmptyState
      title={searchQuery ? 'No matching proofs' : 'No proofs of delivery yet'}
      message={
        searchQuery
          ? 'Try another delivery, invoice, or receiver name.'
          : 'Completed delivery evidence will appear here for review.'
      }
      icon={searchQuery ? 'search' : 'signature'}
      actionLabel={searchQuery ? 'Clear search' : undefined}
      onAction={searchQuery ? () => setSearchQuery('') : undefined}
    />
  ) : (
    <FlatList
      data={filteredPods}
      keyExtractor={pod => pod.id}
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
        <PodRow
          pod={item}
          desktop={isDesktop}
          onPress={() =>
            navigation.navigate('PodDetails', { deliveryId: item.deliveryId })
          }
        />
      )}
    />
  );

  return (
    <AdminShell
      activeNav="proofs"
      title="Proofs of delivery"
      userName={currentUser?.fullName}
      searchValue={searchQuery}
      searchPlaceholder="Search proofs of delivery"
      onNavigate={screen => navigation.navigate(screen)}
      onSearchChange={setSearchQuery}
      onRefresh={refresh}
      onLogout={handleSignOut}
    >
      <View style={styles.workspace}>
        <View style={styles.page}>
          {header}
          {toolbar}
        </View>
        {content}
      </View>
      <AppModal
        visible={showFilterDialog}
        title="Filter proofs of delivery"
        onClose={() => setShowFilterDialog(false)}
      >
        <View style={styles.filterOptions}>
          {(Object.keys(FILTER_LABELS) as DateFilter[]).map(key => {
            const selected = filter === key;
            return (
              <Pressable
                key={key}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                accessibilityLabel={`${FILTER_LABELS[key]} proofs`}
                onPress={() => {
                  setFilter(key);
                  setShowFilterDialog(false);
                }}
                style={({ pressed }) => [
                  styles.filterOption,
                  selected && styles.filterOptionSelected,
                  pressed && styles.pressed,
                ]}
              >
                <AppIcon
                  name={selected ? 'check' : 'calendar'}
                  size={20}
                  color={selected ? colors.shell : colors.contentSecondary}
                />
                <Text
                  style={[
                    textStyles.label,
                    selected && styles.filterOptionLabelSelected,
                  ]}
                >
                  {FILTER_LABELS[key]}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </AppModal>
    </AdminShell>
  );
}

function DesktopTableHeader() {
  return (
    <View style={styles.tableHeader}>
      <Text style={[styles.tableHeading, styles.customerColumn]}>Delivery</Text>
      <Text style={[styles.tableHeading, styles.referenceColumn]}>Invoice</Text>
      <Text style={[styles.tableHeading, styles.dateColumn]}>Captured</Text>
      <Text style={[styles.tableHeading, styles.evidenceColumn]}>Evidence</Text>
      <View style={styles.chevronColumn} />
    </View>
  );
}

function PodRow({
  pod,
  desktop,
  onPress,
}: {
  pod: PodRecord;
  desktop: boolean;
  onPress: () => void;
}) {
  const evidence = getEvidence(pod);
  const capturedAt = pod.timestamp.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: desktop ? 'numeric' : undefined,
  });
  const customerNumber =
    typeof pod.metadata.customerNumber === 'string'
      ? pod.metadata.customerNumber
      : undefined;
  const orderNumber =
    typeof pod.metadata.orderNumber === 'string'
      ? pod.metadata.orderNumber
      : undefined;

  if (desktop) {
    return (
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Review proof for ${
          pod.customerName || pod.deliveryId
        }`}
        onPress={onPress}
        style={({ pressed }) => [
          styles.desktopRow,
          pressed && styles.rowPressed,
        ]}
      >
        <View style={styles.customerColumn}>
          <Text numberOfLines={1} style={textStyles.label}>
            {pod.customerName || `Delivery ${pod.deliveryId.substring(0, 8)}`}
          </Text>
          <Text numberOfLines={1} style={textStyles.bodySmall}>
            Delivery {pod.deliveryId.substring(0, 8)}
          </Text>
        </View>
        <Text
          numberOfLines={1}
          style={[textStyles.bodySmall, styles.referenceColumn]}
        >
          {pod.invoiceNumber || 'No invoice reference'}
        </Text>
        <Text style={[textStyles.bodySmall, styles.dateColumn]}>
          {capturedAt}
        </Text>
        <View style={styles.evidenceColumn}>
          <EvidenceChip evidence={evidence} />
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
      accessibilityLabel={`Review proof for ${
        pod.customerName || pod.deliveryId
      }`}
      onPress={onPress}
      style={({ pressed }) => pressed && styles.pressed}
    >
      <Card style={styles.proofCard}>
        <View style={styles.cardTop}>
          <View style={styles.proofIcon}>
            <AppIcon name="signature" size={22} color={colors.verified} />
          </View>
          <View style={styles.cardCopy}>
            <Text numberOfLines={1} style={textStyles.heading3}>
              {pod.customerName || `Delivery ${pod.deliveryId.substring(0, 8)}`}
            </Text>
            <Text numberOfLines={1} style={textStyles.bodySmall}>
              {capturedAt} · Invoice {pod.invoiceNumber || 'not recorded'}
            </Text>
          </View>
          <AppIcon
            name="chevronRight"
            size={20}
            color={colors.contentSecondary}
          />
        </View>
        <View style={styles.tagRow}>
          {customerNumber ? (
            <ReferenceTag label="Customer" value={customerNumber} />
          ) : null}
          {orderNumber ? (
            <ReferenceTag label="Order" value={orderNumber} />
          ) : null}
          {pod.signedBy ? (
            <ReferenceTag label="Receiver" value={pod.signedBy} />
          ) : null}
        </View>
        <View style={styles.divider} />
        <View style={styles.evidenceRow}>
          <EvidenceItem
            icon="signature"
            label="Signature"
            active={evidence.signature}
          />
          <EvidenceItem icon="camera" label="Photo" active={evidence.photo} />
          <EvidenceItem icon="image" label="Stamp" active={evidence.stamp} />
          <EvidenceItem
            icon="location"
            label="GPS"
            active={evidence.location}
          />
        </View>
        <EvidenceChip evidence={evidence} />
      </Card>
    </Pressable>
  );
}

function getEvidence(pod: PodRecord) {
  return {
    signature: Boolean(pod.signatureUrl),
    photo: Boolean(pod.photoUrl || pod.photoUrls?.length),
    stamp: Boolean(pod.metadata.stampPhotoUrl),
    location: Boolean(pod.location),
  };
}

function EvidenceChip({
  evidence,
}: {
  evidence: ReturnType<typeof getEvidence>;
}) {
  const complete = evidence.signature && evidence.photo && evidence.location;
  return (
    <StatusChip
      label={complete ? 'Evidence complete' : 'Review evidence'}
      tone={complete ? 'success' : 'warning'}
      icon={complete ? 'check' : 'alert'}
    />
  );
}

function EvidenceItem({
  icon,
  label,
  active,
}: {
  icon: AppIconName;
  label: string;
  active: boolean;
}) {
  return (
    <View
      accessibilityLabel={`${label}: ${active ? 'present' : 'missing'}`}
      style={styles.evidenceItem}
    >
      <AppIcon
        name={icon}
        size={18}
        color={active ? colors.verified : colors.contentSecondary}
      />
      <Text
        style={[textStyles.labelSmall, !active && styles.evidenceLabelMissing]}
      >
        {label}
      </Text>
    </View>
  );
}

function ReferenceTag({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.referenceTag}>
      <Text style={textStyles.labelSmall}>{label}</Text>
      <Text numberOfLines={1} style={styles.referenceValue}>
        {value}
      </Text>
    </View>
  );
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
  filterButton: { minWidth: 128 },
  toolbar: { alignItems: 'stretch', gap: spacing.small },
  searchRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  search: { flex: 1 },
  filterHint: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    flexDirection: 'row',
    gap: spacing.xs,
    minHeight: 28,
  },
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
  dateColumn: { flex: 0.82, minWidth: 0, paddingLeft: spacing.small },
  evidenceColumn: {
    alignItems: 'flex-start',
    flex: 1,
    minWidth: 132,
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
  proofCard: { gap: spacing.small },
  cardTop: { alignItems: 'center', flexDirection: 'row', gap: spacing.small },
  proofIcon: {
    alignItems: 'center',
    backgroundColor: colors.verifiedMuted,
    borderRadius: 14,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  cardCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  tagRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs },
  referenceTag: {
    backgroundColor: colors.surfaceMuted,
    borderRadius: spacing.xs,
    maxWidth: '100%',
    paddingHorizontal: spacing.small,
    paddingVertical: spacing.xs,
  },
  referenceValue: { ...textStyles.labelSmall, color: colors.contentPrimary },
  divider: {
    backgroundColor: colors.border,
    height: StyleSheet.hairlineWidth,
    marginVertical: spacing.xs,
  },
  evidenceRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium },
  evidenceItem: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  evidenceLabelMissing: { color: colors.contentSecondary },
  filterOptions: { gap: spacing.xs },
  filterOption: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: spacing.small,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.small,
    minHeight: 48,
    paddingHorizontal: spacing.medium,
  },
  filterOptionSelected: {
    backgroundColor: colors.verifiedMuted,
    borderColor: colors.verified,
  },
  filterOptionLabelSelected: { color: colors.shell },
  pressed: { opacity: 0.8 },
  rowPressed: { backgroundColor: colors.surfaceMuted },
});
