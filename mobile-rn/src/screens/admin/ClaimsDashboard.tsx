import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, FlatList, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { Claim, ClaimStatus, ClaimType, ALL_CLAIM_STATUSES, ALL_CLAIM_TYPES, claimStatusDisplayText, claimTypeDisplayText } from '../../models/claim';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
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
 * - Status/Type filter "dialogs" (AlertDialog + RadioListTile list) become a Modal list
 *   picker, matching BulkItemCreation.tsx's category-picker precedent. The Status filter
 *   list uses `claimStatusDisplayText()` instead of the Dart source's raw `status.name`
 *   (e.g. "pendingDriverResponse") — a one-line, zero-risk fix since the existing
 *   formatter was already built and used elsewhere; not a redesign.
 * - Date range filter: no native date-range-picker is installed (none was in the package
 *   plan), so this is a Modal with two plain `YYYY-MM-DD` text inputs instead of
 *   `showDateRangePicker` — a degraded but honest equivalent.
 * - Per-card order/customer-number lookup: the Dart source does TWO separate Firestore
 *   reads per card (`_getOrderNumber`/`_getCustomerNumber`, each its own `FutureBuilder`)
 *   even though both come from the same `deliveries/{deliveryId}` document. This port
 *   does ONE `deliveryRepository.getDeliveryById()` read per card and derives both fields
 *   from it — same displayed result, half the reads, no behavior change.
 * - Sort menu (`PopupMenuButton`) becomes a Modal list, matching the rest of this file's
 *   picker pattern.
 */
type SortBy = 'date' | 'status' | 'type' | 'amount';

interface ClaimsDashboardProps {
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

const deliveryRepository = new DeliveryRepository();

const STATUS_BADGE: Record<ClaimStatus, { bg: string; text: string; label: string }> = {
  draft: { bg: '#E0E0E0', text: '#424242', label: 'Draft' },
  submitted: { bg: '#BBDEFB', text: '#0D47A1', label: 'Submitted' },
  pendingReview: { bg: '#FFE0B2', text: '#E65100', label: 'Pending Review' },
  investigating: { bg: '#E1BEE7', text: '#4A148C', label: 'Investigating' },
  pendingDriverResponse: { bg: '#FFECB3', text: '#FF6F00', label: 'Needs Response' },
  driverResponded: { bg: '#B2DFDB', text: '#004D40', label: 'Responded' },
  pendingApproval: { bg: '#C5CAE9', text: '#1A237E', label: 'In Progress' },
  pendingSecondApproval: { bg: '#C5CAE9', text: '#1A237E', label: 'In Progress' },
  pendingProcessing: { bg: '#C5CAE9', text: '#1A237E', label: 'In Progress' },
  processing: { bg: '#C5CAE9', text: '#1A237E', label: 'In Progress' },
  pendingFinalReview: { bg: '#C5CAE9', text: '#1A237E', label: 'In Progress' },
  approved: { bg: '#C8E6C9', text: '#1B5E20', label: 'Approved' },
  rejected: { bg: '#FFCDD2', text: '#B71C1C', label: 'Rejected' },
  resolved: { bg: '#B2DFDB', text: '#004D40', label: 'Resolved' },
  closed: { bg: '#BDBDBD', text: '#212121', label: 'Closed' },
  cancelled: { bg: '#E0E0E0', text: '#616161', label: 'Cancelled' },
  disputed: { bg: '#FFCCBC', text: '#BF360C', label: 'Disputed' },
};

const PENDING_STATUSES: ClaimStatus[] = ['submitted', 'pendingReview', 'pendingApproval'];
const NEEDS_ACTION_STATUSES: ClaimStatus[] = ['pendingReview', 'pendingApproval', 'pendingSecondApproval'];

function calculateStats(claims: Claim[]) {
  return {
    total: claims.length,
    pending: claims.filter((c) => PENDING_STATUSES.includes(c.status)).length,
    approved: claims.filter((c) => c.status === 'approved').length,
    rejected: claims.filter((c) => c.status === 'rejected').length,
  };
}

function isClaimOverdue(claim: Claim): boolean {
  if (claim.status === 'resolved' || claim.status === 'closed' || claim.status === 'cancelled') return false;
  const daysSinceCreated = (Date.now() - claim.createdAt.getTime()) / (1000 * 60 * 60 * 24);
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
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

export default function ClaimsDashboard({ navigation }: ClaimsDashboardProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const allClaims = useClaimStore((s) => s.allClaims);
  const isLoading = useClaimStore((s) => s.isLoading);
  const errorMessage = useClaimStore((s) => s.errorMessage);
  const loadAllClaims = useClaimStore((s) => s.loadAllClaims);

  const [statusFilter, setStatusFilter] = useState<ClaimStatus | null>(null);
  const [typeFilter, setTypeFilter] = useState<ClaimType | null>(null);
  const [dateRange, setDateRange] = useState<{ start: Date; end: Date } | null>(null);
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

  const hasActiveFilters = statusFilter != null || typeFilter != null || dateRange != null;

  const filteredClaims = useMemo(() => {
    let result = allClaims;

    if (statusFilter) result = result.filter((c) => c.status === statusFilter);
    if (typeFilter) result = result.filter((c) => c.type === typeFilter);
    if (dateRange) {
      const endInclusive = new Date(dateRange.end.getFullYear(), dateRange.end.getMonth(), dateRange.end.getDate() + 1);
      result = result.filter((c) => c.createdAt >= dateRange.start && c.createdAt < endInclusive);
    }

    const q = searchQuery.trim().toLowerCase();
    if (q.length > 0) {
      result = result.filter(
        (c) =>
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

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>Claims Management</Text>
        <View style={styles.headerBarActions}>
          <Pressable onPress={() => loadAllClaims()}>
            <Text style={styles.headerBarIcon}>↻</Text>
          </Pressable>
          <Pressable onPress={() => navigation.navigate('ClaimSettings')}>
            <Text style={styles.headerBarIcon}>⚙</Text>
          </Pressable>
        </View>
      </View>

      <View style={[styles.statsSection, shadows.card]}>
        <Text style={styles.statsTitle}>Overview</Text>
        <View style={styles.statsRow}>
          <StatCard label="Total" value={stats.total} color={colors.info} />
          <StatCard label="Pending" value={stats.pending} color={colors.warning} />
          <StatCard label="Approved" value={stats.approved} color={colors.success} />
          <StatCard label="Rejected" value={stats.rejected} color={colors.error} />
        </View>
      </View>

      <View style={styles.filtersSection}>
        <View style={styles.filtersHeaderRow}>
          <Text style={styles.filtersLabel}>Filters</Text>
          {hasActiveFilters ? (
            <Pressable onPress={clearAllFilters}>
              <Text style={styles.clearFiltersText}>✕ Clear All</Text>
            </Pressable>
          ) : null}
        </View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterChipRow}>
          <FilterChip label="Status" value={statusFilter ? claimStatusDisplayText(statusFilter) : 'All'} active={statusFilter != null} onPress={() => setShowStatusModal(true)} />
          <FilterChip label="Type" value={typeFilter ? claimTypeDisplayText(typeFilter) : 'All'} active={typeFilter != null} onPress={() => setShowTypeModal(true)} />
          <FilterChip
            label="Date Range"
            value={dateRange ? `${dateRange.start.toLocaleDateString()} - ${dateRange.end.toLocaleDateString()}` : 'All Time'}
            active={dateRange != null}
            onPress={() => setShowDateModal(true)}
          />
        </ScrollView>
      </View>

      <View style={styles.searchSortRow}>
        <View style={styles.searchBox}>
          <Text style={styles.searchIcon}>🔍</Text>
          <TextInput
            style={styles.searchInput}
            placeholder="Search by claim ID, customer, invoice..."
            value={searchQuery}
            onChangeText={setSearchQuery}
          />
          {searchQuery.length > 0 ? (
            <Pressable onPress={() => setSearchQuery('')}>
              <Text style={styles.searchClear}>✕</Text>
            </Pressable>
          ) : null}
        </View>
        <Pressable style={styles.sortButton} onPress={() => setShowSortModal(true)}>
          <Text style={styles.sortButtonText}>⇅</Text>
        </Pressable>
      </View>

      {isLoading && allClaims.length === 0 ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : errorMessage ? (
        <View style={styles.centered}>
          <Text style={styles.errorIcon}>⚠</Text>
          <Text style={styles.errorText}>{errorMessage}</Text>
          <Pressable style={styles.retryButton} onPress={() => loadAllClaims()}>
            <Text style={textStyles.buttonText}>Retry</Text>
          </Pressable>
        </View>
      ) : filteredClaims.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.emptyIcon}>🧾</Text>
          <Text style={styles.emptyText}>{hasActiveFilters ? 'No claims match your filters' : 'No claims filed yet'}</Text>
          {hasActiveFilters ? (
            <Pressable onPress={clearAllFilters}>
              <Text style={styles.clearFiltersText}>Clear Filters</Text>
            </Pressable>
          ) : null}
        </View>
      ) : (
        <FlatList
          data={filteredClaims}
          keyExtractor={(claim) => claim.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => (
            <ClaimCard claim={item} onPress={() => navigation.navigate('ClaimDetails', { claimId: item.id })} />
          )}
        />
      )}

      <PickerModal visible={showStatusModal} title="Filter by Status" onClose={() => setShowStatusModal(false)}>
        <PickerRow label="All Statuses" selected={statusFilter == null} onPress={() => { setStatusFilter(null); setShowStatusModal(false); }} />
        {ALL_CLAIM_STATUSES.map((status) => (
          <PickerRow key={status} label={claimStatusDisplayText(status)} selected={statusFilter === status} onPress={() => { setStatusFilter(status); setShowStatusModal(false); }} />
        ))}
      </PickerModal>

      <PickerModal visible={showTypeModal} title="Filter by Type" onClose={() => setShowTypeModal(false)}>
        <PickerRow label="All Types" selected={typeFilter == null} onPress={() => { setTypeFilter(null); setShowTypeModal(false); }} />
        {ALL_CLAIM_TYPES.map((type) => (
          <PickerRow key={type} label={claimTypeDisplayText(type)} selected={typeFilter === type} onPress={() => { setTypeFilter(type); setShowTypeModal(false); }} />
        ))}
      </PickerModal>

      <PickerModal visible={showSortModal} title="Sort by" onClose={() => setShowSortModal(false)}>
        <PickerRow label="Date" selected={sortBy === 'date'} onPress={() => { setSortBy('date'); setShowSortModal(false); }} />
        <PickerRow label="Status" selected={sortBy === 'status'} onPress={() => { setSortBy('status'); setShowSortModal(false); }} />
        <PickerRow label="Type" selected={sortBy === 'type'} onPress={() => { setSortBy('type'); setShowSortModal(false); }} />
        <PickerRow label="Amount" selected={sortBy === 'amount'} onPress={() => { setSortBy('amount'); setShowSortModal(false); }} />
      </PickerModal>

      <Modal visible={showDateModal} transparent animationType="fade" onRequestClose={() => setShowDateModal(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Filter by Date Range</Text>
            <Text style={styles.fieldLabel}>Start Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} placeholder="2026-01-01" value={dateStartText} onChangeText={setDateStartText} />
            <Text style={styles.fieldLabel}>End Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} placeholder="2026-12-31" value={dateEndText} onChangeText={setDateEndText} />
            <View style={styles.modalButtonRow}>
              <Pressable
                style={styles.modalSecondaryButton}
                onPress={() => {
                  setDateRange(null);
                  setDateStartText('');
                  setDateEndText('');
                  setShowDateModal(false);
                }}
              >
                <Text style={styles.modalSecondaryButtonText}>Clear</Text>
              </Pressable>
              <Pressable style={styles.modalPrimaryButton} onPress={applyDateRange}>
                <Text style={textStyles.buttonText}>Apply</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <View style={[styles.statCard, { backgroundColor: `${color}1A`, borderColor: `${color}4D` }]}>
      <Text style={[styles.statValue, { color }]}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function FilterChip({ label, value, active, onPress }: { label: string; value: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.filterChip, active && styles.filterChipActive]} onPress={onPress}>
      <Text style={[styles.filterChipLabel, active && styles.filterChipLabelActive]}>{label}: </Text>
      <Text style={[styles.filterChipValue, active && styles.filterChipValueActive]}>{value}</Text>
      <Text style={[styles.filterChipCaret, active && styles.filterChipValueActive]}>▾</Text>
    </Pressable>
  );
}

function PickerModal({ visible, title, onClose, children }: { visible: boolean; title: string; onClose: () => void; children: React.ReactNode }) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>{title}</Text>
          <ScrollView style={styles.pickerList}>{children}</ScrollView>
          <Pressable style={styles.modalCloseButton} onPress={onClose}>
            <Text style={textStyles.buttonText}>Close</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

function PickerRow({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={styles.pickerRow} onPress={onPress}>
      <Text style={styles.pickerRowGlyph}>{selected ? '◉' : '○'}</Text>
      <Text style={styles.pickerRowLabel}>{label}</Text>
    </Pressable>
  );
}

function ClaimCard({ claim, onPress }: { claim: Claim; onPress: () => void }) {
  const [delivery, setDelivery] = useState<{ orderNumber?: string; customerNumber?: string } | null>(null);

  useEffect(() => {
    if (!claim.deliveryId) return;
    deliveryRepository
      .getDeliveryById(claim.deliveryId)
      .then((d) => setDelivery(d ? { orderNumber: d.orderNumber, customerNumber: d.customerNumber } : null))
      .catch(() => setDelivery(null));
  }, [claim.deliveryId]);

  const overdue = isClaimOverdue(claim);
  const needsAction = claimNeedsAction(claim);
  const badge = STATUS_BADGE[claim.status];

  return (
    <Pressable style={[styles.card, shadows.card, overdue && styles.cardOverdue]} onPress={onPress}>
      <View style={styles.cardTopRow}>
        <View style={styles.cardTitleBox}>
          <View style={styles.cardTitleRow}>
            <Text style={styles.cardTitleText}>{claim.invoiceNumber ?? claim.id}</Text>
            {needsAction ? (
              <View style={[styles.pill, styles.pillAction]}>
                <Text style={styles.pillText}>ACTION NEEDED</Text>
              </View>
            ) : null}
            {overdue ? (
              <View style={[styles.pill, styles.pillOverdue]}>
                <Text style={styles.pillText}>OVERDUE</Text>
              </View>
            ) : null}
          </View>
          <Text style={styles.cardSubtitleText}>{claimTypeDisplayText(claim.type)}</Text>
        </View>
        <View style={[styles.statusBadge, { backgroundColor: badge.bg }]}>
          <Text style={[styles.statusBadgeText, { color: badge.text }]}>{badge.label}</Text>
        </View>
      </View>

      <View style={styles.traceRow}>
        <Text style={styles.traceItem}>INV: {claim.invoiceNumber ?? 'N/A'}</Text>
        <Text style={styles.traceItem}>Cust #: {delivery?.customerNumber ?? claim.customerAccountNumber ?? 'N/A'}</Text>
        <Text style={styles.traceItem}>Order #: {delivery?.orderNumber ?? '-'}</Text>
      </View>

      <InfoLine label="Customer" value={claim.customerName} />
      <InfoLine label="Driver" value={claim.driverName} />
      <InfoLine label="Filed" value={formatRelativeDate(claim.createdAt)} />
      {claim.claimAmount != null ? <InfoLine label="Amount" value={`R${claim.claimAmount.toFixed(2)}`} /> : null}
      {claim.description.length > 0 ? (
        <Text style={styles.descriptionText} numberOfLines={2}>
          {claim.description}
        </Text>
      ) : null}

      <View style={styles.cardFooterRow}>
        {claim.photoUrls.length > 0 ? <Text style={styles.footerMeta}>📷 {claim.photoUrls.length}</Text> : null}
        {claim.customerSignatureUrl ? <Text style={styles.footerMeta}>✎</Text> : null}
        {claim.affectedItems.length > 0 ? <Text style={styles.footerMeta}>📦 {claim.affectedItems.length}</Text> : null}
        <View style={styles.footerSpacer} />
        <Text style={styles.footerChevron}>›</Text>
      </View>
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
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.card,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.medium,
  },
  headerBarActions: { flexDirection: 'row', gap: spacing.medium },
  headerBarIcon: { fontSize: 20, color: colors.primary },
  statsSection: { backgroundColor: colors.card, padding: spacing.medium },
  statsTitle: { fontWeight: 'bold', fontSize: 15, marginBottom: spacing.small + 4 },
  statsRow: { flexDirection: 'row', gap: spacing.small },
  statCard: { flex: 1, borderRadius: radii.borderRadius, borderWidth: 1, padding: spacing.small + 4, alignItems: 'center' },
  statValue: { fontSize: 20, fontWeight: 'bold' },
  statLabel: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  filtersSection: { backgroundColor: colors.background, padding: spacing.medium, borderBottomWidth: 1, borderBottomColor: colors.divider },
  filtersHeaderRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small },
  filtersLabel: { fontSize: 13, fontWeight: '600', color: colors.textSecondary },
  clearFiltersText: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  filterChipRow: { gap: spacing.small },
  filterChip: { flexDirection: 'row', alignItems: 'center', borderRadius: 20, borderWidth: 1, borderColor: colors.divider, backgroundColor: colors.card, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small },
  filterChipActive: { borderColor: colors.primary, borderWidth: 2, backgroundColor: `${colors.primary}1A` },
  filterChipLabel: { fontSize: 12, fontWeight: '600', color: colors.textSecondary },
  filterChipLabelActive: { color: colors.primary },
  filterChipValue: { fontSize: 12, color: colors.textPrimary },
  filterChipValueActive: { color: colors.primary },
  filterChipCaret: { fontSize: 10, marginLeft: 4, color: colors.textSecondary },
  searchSortRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, gap: spacing.small },
  searchBox: { flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4 },
  searchIcon: { marginRight: spacing.small },
  searchInput: { flex: 1, paddingVertical: spacing.small + 4 },
  searchClear: { color: colors.textSecondary, padding: spacing.small },
  sortButton: { width: 40, height: 40, borderRadius: radii.borderRadius, backgroundColor: colors.card, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: colors.divider },
  sortButtonText: { fontSize: 18, color: colors.primary },
  errorIcon: { fontSize: 48, color: colors.error },
  errorText: { color: colors.error, textAlign: 'center', marginTop: spacing.small + 4 },
  retryButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4, marginTop: spacing.medium },
  emptyIcon: { fontSize: 64, opacity: 0.3 },
  emptyText: { fontSize: 16, color: colors.textSecondary, marginTop: spacing.medium },
  listContent: { padding: spacing.medium },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.medium },
  cardOverdue: { borderWidth: 2, borderColor: colors.error },
  cardTopRow: { flexDirection: 'row', alignItems: 'flex-start' },
  cardTitleBox: { flex: 1, marginRight: spacing.small },
  cardTitleRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: spacing.small },
  cardTitleText: { fontSize: 16, fontWeight: 'bold', color: colors.primary },
  cardSubtitleText: { fontSize: 13, color: colors.textSecondary, marginTop: 2 },
  pill: { borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2 },
  pillAction: { backgroundColor: colors.warning },
  pillOverdue: { backgroundColor: colors.error },
  pillText: { fontSize: 10, fontWeight: 'bold', color: colors.white },
  statusBadge: { borderRadius: 12, paddingHorizontal: spacing.small + 4, paddingVertical: 5 },
  statusBadgeText: { fontSize: 11, fontWeight: '600' },
  traceRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium, marginTop: spacing.medium },
  traceItem: { fontSize: 12, color: colors.textSecondary },
  infoLine: { fontSize: 12, color: colors.textPrimary, marginTop: spacing.small },
  infoLineLabel: { fontWeight: '600', color: colors.textSecondary },
  descriptionText: { fontSize: 13, color: colors.textSecondary, marginTop: spacing.small + 4 },
  cardFooterRow: { flexDirection: 'row', alignItems: 'center', marginTop: spacing.medium },
  footerMeta: { fontSize: 11, color: colors.textSecondary, marginRight: spacing.medium },
  footerSpacer: { flex: 1 },
  footerChevron: { fontSize: 20, color: colors.divider },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '80%' },
  pickerList: { maxHeight: 320, marginTop: spacing.medium },
  pickerRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  pickerRowGlyph: { fontSize: 16, color: colors.primary, marginRight: spacing.small + 4 },
  pickerRowLabel: { fontSize: 14, color: colors.textPrimary },
  modalCloseButton: { marginTop: spacing.large, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  fieldLabel: { fontWeight: '600', fontSize: 13, marginTop: spacing.medium, marginBottom: spacing.small },
  dateInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  modalButtonRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalSecondaryButton: { flex: 1, alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  modalSecondaryButtonText: { color: colors.textSecondary, fontWeight: '600' },
  modalPrimaryButton: { flex: 1, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
});
