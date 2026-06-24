import React, { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  FlatList,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { AdminShell } from '../../components/admin/AdminShell';
import {
  AppIcon,
  Card,
  EmptyState,
  ErrorState,
  FormField,
  IconButton,
  LoadingState,
  PrimaryButton,
  SearchField,
  SecondaryButton,
  StatusChip,
  StatusChipTone,
  AppModal,
} from '../../components/ui';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import {
  Claim,
  ClaimStatus,
  ClaimType,
  ALL_CLAIM_STATUSES,
  ALL_CLAIM_TYPES,
  claimStatusDisplayText,
  claimTypeDisplayText,
} from '../../models/claim';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/claims_dashboard_screen.dart
 * (`ClaimsDashboardMobile`, verified against source on 2026-06-22) — admin list/triage
 * view of every claim filed in the company, with stats, filters, search, and sort.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass (desktop
 * branch lands in Phase 4 as a `useWindowDimensions()` wrapper, same as ClaimSettings.tsx).
 *
 * Deviations from the Flutter source:
 * - Bug fix (flagged in the Phase 3 inventory): the settings gear button was a dead stub
 *   ("Claim Settings - Coming Soon" snackbar with a `// TODO: Navigate to claim settings`).
 *   Now that ClaimSettings.tsx exists, this navigates there for real.
 * - Filtering reads `useClaimStore.allClaims` and applies status/type/date-range/search/sort
 *   entirely locally in this component, rather than going through the store's
 *   `claims`/`statusFilter`/`searchQuery` fields — those exist for the driver-facing
 *   MyClaims screen's use of the *same* store, and the Dart source's screen-local
 *   `_selectedStatus`/`_selectedType` state never actually calls `ClaimProvider.setStatusFilter()`/
 *   `setTypeFilter()` either, so `claimProvider.claims` is effectively unfiltered from this
 *   screen's perspective in the Dart app too — replicating that exactly, just without the
 *   risk of one screen's filter state leaking into another via shared provider fields.
 * - Status/Type filter "dialogs" (AlertDialog + RadioListTile list) become a shared
 *   AppModal list picker. The Status filter list uses `claimStatusDisplayText()` instead
 *   of the Dart source's raw `status.name` (e.g. "pendingDriverResponse").
 * - Date range filter: no native date-range-picker is installed (none was in the package
 *   plan), so this is a modal with two plain `YYYY-MM-DD` text fields instead of
 *   `showDateRangePicker` — a degraded but honest equivalent.
 * - Per-card order/customer-number lookup: the Dart source does TWO separate Firestore
 *   reads per card; this port does ONE `deliveryRepository.getDeliveryById()` read per
 *   card and derives both fields from it — same displayed result, half the reads.
 * - Sort menu (`PopupMenuButton`) becomes a shared AppModal list, matching the pickers.
 *
 * UI/UX refresh (Operations Precision): all emoji/Unicode glyph controls replaced with the
 * shared SVG `AppIcon`/`IconButton`, `SearchField`, `StatusChip`, `Card`, loading/error/empty
 * state components, and `AppModal`. Semantic tokens only; no literal badge hex.
 */
type SortBy = 'date' | 'status' | 'type' | 'amount';

interface ClaimsDashboardProps {
  navigation: {
    navigate: (screen: string, params?: Record<string, unknown>) => void;
    goBack: () => void;
  };
}

const deliveryRepository = new DeliveryRepository();

const SORT_OPTIONS: Array<{ key: SortBy; label: string }> = [
  { key: 'date', label: 'Date' },
  { key: 'status', label: 'Status' },
  { key: 'type', label: 'Type' },
  { key: 'amount', label: 'Amount' },
];

/** Short triage labels (kept from the Flutter badge map) and their semantic tone. */
const STATUS_BADGE: Record<ClaimStatus, { tone: StatusChipTone; label: string }> = {
  draft: { tone: 'neutral', label: 'Draft' },
  submitted: { tone: 'info', label: 'Submitted' },
  pendingReview: { tone: 'warning', label: 'Pending Review' },
  investigating: { tone: 'info', label: 'Investigating' },
  pendingDriverResponse: { tone: 'warning', label: 'Needs Response' },
  driverResponded: { tone: 'info', label: 'Responded' },
  pendingApproval: { tone: 'info', label: 'In Progress' },
  pendingSecondApproval: { tone: 'info', label: 'In Progress' },
  pendingProcessing: { tone: 'info', label: 'In Progress' },
  processing: { tone: 'info', label: 'In Progress' },
  pendingFinalReview: { tone: 'info', label: 'In Progress' },
  approved: { tone: 'success', label: 'Approved' },
  rejected: { tone: 'error', label: 'Rejected' },
  resolved: { tone: 'success', label: 'Resolved' },
  closed: { tone: 'neutral', label: 'Closed' },
  cancelled: { tone: 'neutral', label: 'Cancelled' },
  disputed: { tone: 'warning', label: 'Disputed' },
};

const PENDING_STATUSES: ClaimStatus[] = [
  'submitted',
  'pendingReview',
  'pendingApproval',
];
const NEEDS_ACTION_STATUSES: ClaimStatus[] = [
  'pendingReview',
  'pendingApproval',
  'pendingSecondApproval',
];

function calculateStats(claims: Claim[]) {
  return {
    total: claims.length,
    pending: claims.filter(c => PENDING_STATUSES.includes(c.status)).length,
    approved: claims.filter(c => c.status === 'approved').length,
    rejected: claims.filter(c => c.status === 'rejected').length,
  };
}

function isClaimOverdue(claim: Claim): boolean {
  if (
    claim.status === 'resolved' ||
    claim.status === 'closed' ||
    claim.status === 'cancelled'
  )
    return false;
  const daysSinceCreated =
    (Date.now() - claim.createdAt.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceCreated > 7;
}

function claimNeedsAction(claim: Claim): boolean {
  return NEEDS_ACTION_STATUSES.includes(claim.status);
}

function formatRelativeDate(date: Date): string {
  const diffMs = Date.now() - date.getTime();
  const diffMinutes = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffDays === 0) {
    if (diffHours === 0) {
      return diffMinutes <= 0 ? 'Just now' : `${diffMinutes}m ago`;
    }
    return `${diffHours}h ago`;
  } else if (diffDays === 1) {
    return 'Yesterday';
  } else if (diffDays < 7) {
    return `${diffDays} days ago`;
  }
  return date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export default function ClaimsDashboard({ navigation }: ClaimsDashboardProps) {
  const currentUser = useAuthStore(s => s.currentUser);
  const signOut = useAuthStore(s => s.signOut);
  const allClaims = useClaimStore(s => s.allClaims);
  const isLoading = useClaimStore(s => s.isLoading);
  const errorMessage = useClaimStore(s => s.errorMessage);
  const loadAllClaims = useClaimStore(s => s.loadAllClaims);

  const [statusFilter, setStatusFilter] = useState<ClaimStatus | null>(null);
  const [typeFilter, setTypeFilter] = useState<ClaimType | null>(null);
  const [dateRange, setDateRange] = useState<{ start: Date; end: Date } | null>(
    null,
  );
  const [searchQuery, setSearchQuery] = useState('');
  const [sortBy, setSortBy] = useState<SortBy>('date');

  const [showStatusModal, setShowStatusModal] = useState(false);
  const [showTypeModal, setShowTypeModal] = useState(false);
  const [showDateModal, setShowDateModal] = useState(false);
  const [showSortModal, setShowSortModal] = useState(false);
  const [dateStartText, setDateStartText] = useState('');
  const [dateEndText, setDateEndText] = useState('');

  useEffect(() => {
    if (!currentUser) return;
    if (useClaimStore.getState().companyId !== currentUser.companyId) {
      useClaimStore.getState().initialize(currentUser.companyId);
    }
    loadAllClaims();
  }, [currentUser, loadAllClaims]);

  const hasActiveFilters =
    statusFilter != null || typeFilter != null || dateRange != null;

  const filteredClaims = useMemo(() => {
    let result = allClaims;

    if (statusFilter) result = result.filter(c => c.status === statusFilter);
    if (typeFilter) result = result.filter(c => c.type === typeFilter);
    if (dateRange) {
      const endInclusive = new Date(
        dateRange.end.getFullYear(),
        dateRange.end.getMonth(),
        dateRange.end.getDate() + 1,
      );
      result = result.filter(
        c => c.createdAt >= dateRange.start && c.createdAt < endInclusive,
      );
    }

    const q = searchQuery.trim().toLowerCase();
    if (q.length > 0) {
      result = result.filter(
        c =>
          c.id.toLowerCase().includes(q) ||
          c.customerName.toLowerCase().includes(q) ||
          c.description.toLowerCase().includes(q) ||
          (c.invoiceNumber?.toLowerCase().includes(q) ?? false),
      );
    }

    result = [...result];
    switch (sortBy) {
      case 'date':
        result.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        break;
      case 'status':
        result.sort((a, b) => a.status.localeCompare(b.status));
        break;
      case 'type':
        result.sort((a, b) => a.type.localeCompare(b.type));
        break;
      case 'amount':
        result.sort((a, b) => (b.claimAmount ?? 0) - (a.claimAmount ?? 0));
        break;
    }
    return result;
  }, [allClaims, statusFilter, typeFilter, dateRange, searchQuery, sortBy]);

  const stats = useMemo(() => calculateStats(allClaims), [allClaims]);

  const clearAllFilters = () => {
    setStatusFilter(null);
    setTypeFilter(null);
    setDateRange(null);
    setSearchQuery('');
  };

  const applyDateRange = () => {
    const start = new Date(dateStartText);
    const end = new Date(dateEndText);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      setShowDateModal(false);
      return;
    }
    setDateRange({ start, end });
    setShowDateModal(false);
  };

  const sortLabel =
    SORT_OPTIONS.find(option => option.key === sortBy)?.label ?? 'Date';

  const handleSignOut = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  return (
    <AdminShell
      activeNav="claims"
      title="Claims management"
      userName={currentUser?.fullName}
      onNavigate={screen => navigation.navigate(screen)}
      onRefresh={() => loadAllClaims()}
      onLogout={handleSignOut}
    >
      <View style={styles.container}>
        <View style={styles.statsSection}>
        <Text style={styles.sectionLabel}>Overview</Text>
        <View style={styles.statsRow}>
          <StatCard label="Total" value={stats.total} tone="info" />
          <StatCard label="Pending" value={stats.pending} tone="warning" />
          <StatCard label="Approved" value={stats.approved} tone="success" />
          <StatCard label="Rejected" value={stats.rejected} tone="error" />
        </View>
      </View>

      <View style={styles.filtersSection}>
        <View style={styles.filtersHeaderRow}>
          <Text style={styles.sectionLabel}>Filters</Text>
          <View style={styles.filtersHeaderActions}>
            {hasActiveFilters ? (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Clear all filters"
                style={styles.clearAllButton}
                onPress={clearAllFilters}
              >
                <AppIcon name="close" size={14} color={colors.shell} />
                <Text style={styles.clearAllText}>Clear all</Text>
              </Pressable>
            ) : null}
            <IconButton
              icon="settings"
              accessibilityLabel="Open claim settings"
              onPress={() => navigation.navigate('ClaimSettings')}
            />
          </View>
        </View>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.filterChipRow}
        >
          <FilterChip
            label="Status"
            value={statusFilter ? claimStatusDisplayText(statusFilter) : 'All'}
            active={statusFilter != null}
            onPress={() => setShowStatusModal(true)}
          />
          <FilterChip
            label="Type"
            value={typeFilter ? claimTypeDisplayText(typeFilter) : 'All'}
            active={typeFilter != null}
            onPress={() => setShowTypeModal(true)}
          />
          <FilterChip
            label="Date"
            value={
              dateRange
                ? `${dateRange.start.toLocaleDateString()} – ${dateRange.end.toLocaleDateString()}`
                : 'All time'
            }
            active={dateRange != null}
            onPress={() => setShowDateModal(true)}
          />
          <FilterChip
            label="Sort"
            value={sortLabel}
            active={false}
            onPress={() => setShowSortModal(true)}
          />
        </ScrollView>
      </View>

      <View style={styles.searchRow}>
        <SearchField
          accessibilityLabel="Search claims"
          placeholder="Search by claim ID, customer, invoice…"
          value={searchQuery}
          onChangeText={setSearchQuery}
          containerStyle={styles.searchField}
        />
        {searchQuery.length > 0 ? (
          <IconButton
            icon="close"
            accessibilityLabel="Clear search"
            onPress={() => setSearchQuery('')}
          />
        ) : null}
      </View>

      {isLoading && allClaims.length === 0 ? (
        <LoadingState
          title="Loading claims"
          message="Retrieving claims filed across your company."
        />
      ) : errorMessage ? (
        <ErrorState
          title="Couldn't load claims"
          message={errorMessage}
          onAction={() => loadAllClaims()}
        />
      ) : filteredClaims.length === 0 ? (
        <EmptyState
          icon="clipboard"
          title={
            hasActiveFilters
              ? 'No claims match your filters'
              : 'No claims filed yet'
          }
          message={
            hasActiveFilters
              ? 'Adjust or clear the active filters to see more claims.'
              : 'Claims filed by drivers and admins will appear here.'
          }
          actionLabel={hasActiveFilters ? 'Clear filters' : undefined}
          onAction={hasActiveFilters ? clearAllFilters : undefined}
        />
      ) : (
        <FlatList
          data={filteredClaims}
          keyExtractor={claim => claim.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => (
            <ClaimCard
              claim={item}
              onPress={() =>
                navigation.navigate('ClaimDetails', { claimId: item.id })
              }
            />
          )}
        />
      )}

      <AppModal
        visible={showStatusModal}
        title="Filter by status"
        onClose={() => setShowStatusModal(false)}
      >
        <ScrollView style={styles.pickerList}>
          <PickerRow
            label="All statuses"
            selected={statusFilter == null}
            onPress={() => {
              setStatusFilter(null);
              setShowStatusModal(false);
            }}
          />
          {ALL_CLAIM_STATUSES.map(status => (
            <PickerRow
              key={status}
              label={claimStatusDisplayText(status)}
              selected={statusFilter === status}
              onPress={() => {
                setStatusFilter(status);
                setShowStatusModal(false);
              }}
            />
          ))}
        </ScrollView>
      </AppModal>

      <AppModal
        visible={showTypeModal}
        title="Filter by type"
        onClose={() => setShowTypeModal(false)}
      >
        <ScrollView style={styles.pickerList}>
          <PickerRow
            label="All types"
            selected={typeFilter == null}
            onPress={() => {
              setTypeFilter(null);
              setShowTypeModal(false);
            }}
          />
          {ALL_CLAIM_TYPES.map(type => (
            <PickerRow
              key={type}
              label={claimTypeDisplayText(type)}
              selected={typeFilter === type}
              onPress={() => {
                setTypeFilter(type);
                setShowTypeModal(false);
              }}
            />
          ))}
        </ScrollView>
      </AppModal>

      <AppModal
        visible={showSortModal}
        title="Sort by"
        onClose={() => setShowSortModal(false)}
      >
        <View>
          {SORT_OPTIONS.map(option => (
            <PickerRow
              key={option.key}
              label={option.label}
              selected={sortBy === option.key}
              onPress={() => {
                setSortBy(option.key);
                setShowSortModal(false);
              }}
            />
          ))}
        </View>
      </AppModal>

      <AppModal
        visible={showDateModal}
        title="Filter by date range"
        onClose={() => setShowDateModal(false)}
        footer={
          <View style={styles.modalButtonRow}>
            <SecondaryButton
              label="Clear"
              style={styles.modalButton}
              onPress={() => {
                setDateRange(null);
                setDateStartText('');
                setDateEndText('');
                setShowDateModal(false);
              }}
            />
            <PrimaryButton
              label="Apply"
              style={styles.modalButton}
              onPress={applyDateRange}
            />
          </View>
        }
      >
        <View style={styles.dateFields}>
          <FormField
            label="Start date"
            helperText="Format: YYYY-MM-DD"
            placeholder="2026-01-01"
            value={dateStartText}
            onChangeText={setDateStartText}
            autoCapitalize="none"
          />
          <FormField
            label="End date"
            helperText="Format: YYYY-MM-DD"
            placeholder="2026-12-31"
            value={dateEndText}
            onChangeText={setDateEndText}
            autoCapitalize="none"
          />
        </View>
      </AppModal>
      </View>
    </AdminShell>
  );
}

const STAT_TONE_COLOR: Record<StatusChipTone, string> = {
  neutral: colors.contentSecondary,
  info: colors.info,
  success: colors.success,
  warning: colors.attention,
  error: colors.error,
};

function StatCard({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: StatusChipTone;
}) {
  const color = STAT_TONE_COLOR[tone];
  return (
    <View style={styles.statCard}>
      <Text style={[styles.statValue, { color }]}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function FilterChip({
  label,
  value,
  active,
  onPress,
}: {
  label: string;
  value: string;
  active: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${label}: ${value}`}
      style={[styles.filterChip, active && styles.filterChipActive]}
      onPress={onPress}
    >
      <Text
        style={[styles.filterChipLabel, active && styles.filterChipTextActive]}
      >
        {label}:{' '}
      </Text>
      <Text
        style={[styles.filterChipValue, active && styles.filterChipTextActive]}
        numberOfLines={1}
      >
        {value}
      </Text>
      <AppIcon
        name="chevronDown"
        size={14}
        color={active ? colors.shell : colors.contentSecondary}
      />
    </Pressable>
  );
}

function PickerRow({
  label,
  selected,
  onPress,
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      style={styles.pickerRow}
      onPress={onPress}
    >
      <View style={[styles.radioOuter, selected && styles.radioOuterSelected]}>
        {selected ? <View style={styles.radioInner} /> : null}
      </View>
      <Text style={styles.pickerRowLabel}>{label}</Text>
    </Pressable>
  );
}

function ClaimCard({ claim, onPress }: { claim: Claim; onPress: () => void }) {
  const [delivery, setDelivery] = useState<{
    orderNumber?: string;
    customerNumber?: string;
  } | null>(null);

  useEffect(() => {
    if (!claim.deliveryId) return;
    deliveryRepository
      .getDeliveryById(claim.deliveryId)
      .then(d =>
        setDelivery(
          d
            ? { orderNumber: d.orderNumber, customerNumber: d.customerNumber }
            : null,
        ),
      )
      .catch(() => setDelivery(null));
  }, [claim.deliveryId]);

  const overdue = isClaimOverdue(claim);
  const needsAction = claimNeedsAction(claim);
  const badge = STATUS_BADGE[claim.status];

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Open claim ${claim.invoiceNumber ?? claim.id}`}
      onPress={onPress}
    >
      <Card style={[styles.card, overdue && styles.cardOverdue]}>
        <View style={styles.cardTopRow}>
          <View style={styles.cardTitleBox}>
            <View style={styles.cardTitleRow}>
              <Text style={styles.cardTitleText} numberOfLines={1}>
                {claim.invoiceNumber ?? claim.id}
              </Text>
              {needsAction ? (
                <StatusChip label="Action needed" tone="warning" icon="alert" />
              ) : null}
              {overdue ? (
                <StatusChip label="Overdue" tone="error" icon="alert" />
              ) : null}
            </View>
            <Text style={styles.cardSubtitleText}>
              {claimTypeDisplayText(claim.type)}
            </Text>
          </View>
          <StatusChip label={badge.label} tone={badge.tone} />
        </View>

        <View style={styles.traceRow}>
          <Text style={styles.traceItem}>
            INV: {claim.invoiceNumber ?? 'N/A'}
          </Text>
          <Text style={styles.traceItem}>
            Cust #:{' '}
            {delivery?.customerNumber ?? claim.customerAccountNumber ?? 'N/A'}
          </Text>
          <Text style={styles.traceItem}>
            Order #: {delivery?.orderNumber ?? '-'}
          </Text>
        </View>

        <InfoLine label="Customer" value={claim.customerName} />
        <InfoLine label="Driver" value={claim.driverName} />
        <InfoLine label="Filed" value={formatRelativeDate(claim.createdAt)} />
        {claim.claimAmount != null ? (
          <InfoLine label="Amount" value={`R${claim.claimAmount.toFixed(2)}`} />
        ) : null}
        {claim.description.length > 0 ? (
          <Text style={styles.descriptionText} numberOfLines={2}>
            {claim.description}
          </Text>
        ) : null}

        <View style={styles.cardFooterRow}>
          {claim.photoUrls.length > 0 ? (
            <View style={styles.footerMeta}>
              <AppIcon name="image" size={16} color={colors.contentSecondary} />
              <Text style={styles.footerMetaText}>{claim.photoUrls.length}</Text>
            </View>
          ) : null}
          {claim.customerSignatureUrl ? (
            <View style={styles.footerMeta}>
              <AppIcon
                name="signature"
                size={16}
                color={colors.contentSecondary}
              />
            </View>
          ) : null}
          {claim.affectedItems.length > 0 ? (
            <View style={styles.footerMeta}>
              <AppIcon
                name="package"
                size={16}
                color={colors.contentSecondary}
              />
              <Text style={styles.footerMetaText}>
                {claim.affectedItems.length}
              </Text>
            </View>
          ) : null}
          <View style={styles.footerSpacer} />
          <AppIcon name="chevronRight" size={20} color={colors.contentSecondary} />
        </View>
      </Card>
    </Pressable>
  );
}

function InfoLine({ label, value }: { label: string; value: string }) {
  return (
    <Text style={styles.infoLine} numberOfLines={1}>
      <Text style={styles.infoLineLabel}>{label}: </Text>
      {value}
    </Text>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.canvas },
  sectionLabel: {
    ...textStyles.label,
    color: colors.contentSecondary,
    marginBottom: spacing.small,
  },
  statsSection: {
    paddingHorizontal: spacing.medium,
    paddingTop: spacing.medium,
  },
  statsRow: { flexDirection: 'row', gap: spacing.small },
  statCard: {
    flex: 1,
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: radii.cardRadius,
    paddingVertical: spacing.medium,
    alignItems: 'center',
  },
  statValue: { ...textStyles.heading2 },
  statLabel: {
    ...textStyles.labelSmall,
    color: colors.contentSecondary,
    marginTop: spacing.xs,
  },
  filtersSection: {
    paddingHorizontal: spacing.medium,
    paddingTop: spacing.medium,
  },
  filtersHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  filtersHeaderActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  clearAllButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.small,
  },
  clearAllText: { ...textStyles.labelSmall, color: colors.shell },
  filterChipRow: { gap: spacing.small, paddingVertical: spacing.xs },
  filterChip: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radii.inputRadius,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: spacing.small,
    maxWidth: 240,
  },
  filterChipActive: {
    borderColor: colors.shell,
    backgroundColor: colors.activeMuted,
  },
  filterChipLabel: {
    ...textStyles.labelSmall,
    color: colors.contentSecondary,
  },
  filterChipValue: {
    ...textStyles.labelSmall,
    color: colors.contentPrimary,
    flexShrink: 1,
  },
  filterChipTextActive: { color: colors.shell },
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small,
    paddingHorizontal: spacing.medium,
    paddingTop: spacing.medium,
  },
  searchField: { flex: 1 },
  listContent: { padding: spacing.medium },
  card: { marginBottom: spacing.medium },
  cardOverdue: { borderColor: colors.critical, borderWidth: 1 },
  cardTopRow: { flexDirection: 'row', alignItems: 'flex-start' },
  cardTitleBox: { flex: 1, marginRight: spacing.small },
  cardTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: spacing.small,
  },
  cardTitleText: { ...textStyles.heading3, color: colors.shell },
  cardSubtitleText: {
    ...textStyles.bodySmall,
    color: colors.contentSecondary,
    marginTop: spacing.xs,
  },
  traceRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.medium,
    marginTop: spacing.medium,
  },
  traceItem: { ...textStyles.bodySmall, color: colors.contentSecondary },
  infoLine: {
    ...textStyles.bodySmall,
    color: colors.contentPrimary,
    marginTop: spacing.small,
  },
  infoLineLabel: { fontWeight: '600', color: colors.contentSecondary },
  descriptionText: {
    ...textStyles.bodySmall,
    color: colors.contentSecondary,
    marginTop: spacing.small,
  },
  cardFooterRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.medium,
    marginTop: spacing.medium,
  },
  footerMeta: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  footerMetaText: {
    ...textStyles.labelSmall,
    color: colors.contentSecondary,
  },
  footerSpacer: { flex: 1 },
  pickerList: { maxHeight: 360 },
  pickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small + 4,
    paddingVertical: spacing.small + 4,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.border,
  },
  radioOuter: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioOuterSelected: { borderColor: colors.shell },
  radioInner: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: colors.shell,
  },
  pickerRowLabel: { ...textStyles.bodyMedium, color: colors.contentPrimary },
  dateFields: { gap: spacing.medium },
  modalButtonRow: { flexDirection: 'row', gap: spacing.medium },
  modalButton: { flex: 1 },
});
