import React, { useEffect, useMemo, useState } from 'react';
import { Alert, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { exportClaims } from '../../repositories/csvExportService';
import {
  Claim,
  ClaimStatus,
  ClaimType,
  ALL_CLAIM_STATUSES,
  ALL_CLAIM_TYPES,
  claimStatusDisplayText,
  claimTypeDisplayText,
} from '../../models/claim';
import CreateClaimForm from './CreateClaimForm';
import UploadEvidenceForm from './UploadEvidenceForm';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const deliveryRepository = new DeliveryRepository();

type StatusFilter = 'all' | ClaimStatus;
type SortField = 'date' | 'status' | 'amount';
type Tab = 'all' | 'create' | 'upload';

const ELIGIBLE_FOR_QUICK_DECISION: ClaimStatus[] = ['submitted', 'pendingReview'];

function isClaimOverdue(claim: Claim): boolean {
  if (claim.status === 'resolved' || claim.status === 'closed' || claim.status === 'cancelled') return false;
  return (Date.now() - claim.createdAt.getTime()) / 86400000 > 7;
}

const COLS = {
  checkbox: { width: 36 },
  invoice: { width: 110 },
  custNumber: { width: 90 },
  orderNumber: { width: 90 },
  type: { width: 130 },
  status: { width: 150 },
  customer: { width: 150 },
  driver: { width: 130 },
  amount: { width: 100 },
  date: { width: 100 },
  actions: { width: 70 },
};
const TABLE_WIDTH = Object.values(COLS).reduce((sum, c) => sum + c.width, 0);

/**
 * Ported from lib/screens/admin/claims_dashboard_desktop.dart (verified against source on
 * 2026-06-23). Same data layer as the mobile variant (ClaimsDashboard.tsx): reads
 * `useClaimStore.allClaims` and filters/sorts entirely locally, rather than through the
 * store's admin-triage filter fields — those were deliberately left off `useClaimStore`
 * (see its own header comment: "left out; they can be added back when the admin claims
 * list is ported") specifically for this screen to add locally, which is what this does
 * (status/type/date-range/search plus the 4 "advanced" text filters: customer number,
 * customer name, invoice number, order number).
 *
 * Adds vs. the mobile screen: 3 tabs (All Claims / Create Claim / Upload Evidence — the
 * latter two just render the already-ported `CreateClaimForm.tsx`/`UploadEvidenceForm.tsx`
 * directly), an editable status cell (tap badge → status picker → `updateClaimStatus`),
 * quick approve/reject with an optional/required notes prompt, working bulk approve/reject,
 * a >1200px-wide conditional detail panel, copy-claim-ID, and CSV export (real, via the
 * already-built `exportClaims()`).
 *
 * Deviations:
 * - The Dart source has the SAME search field bound to the same controller in both the
 *   compact top bar AND the filter sidebar — two inputs, one piece of state. Kept as one
 *   search input (in the sidebar) here; no functionality lost.
 * - Per-row Cust#/Order# columns: the Dart source does TWO separate `FutureBuilder`s per
 *   row, each its own `_getCustomerNumber`/`_getOrderNumber` Firestore read, even though
 *   both come from the same `deliveries/{deliveryId}` document — same redundant-read pattern
 *   already fixed once in the mobile screen's `ClaimCard`. Fixed the same way here: one
 *   `deliveryRepository.getDeliveryById()` read per row.
 * - Bulk PDF export (`BulkClaimsPdfService.downloadClaimsAsZip`) is genuine client-side Dart
 *   PDF+zip generation, not a missing Cloud Function — but porting it is its own
 *   significant chunk of work (a second client-side PDF generator, the kind of thing this
 *   migration already chose to move server-side once for POD PDFs). Out of scope for this
 *   Phase 4 pass: the "Export as PDF" option shows a "not yet available" message instead of
 *   either silently dropping the menu item or building a new generator mid-screen-port.
 * - Column-visibility toggles (`_showClaimId`/`_showType`/etc.) are dropped — a desktop
 *   power-user convenience over a table that already shows everything; not reachable from
 *   anywhere else, low value relative to the rest of this already-large screen.
 * - Keyboard shortcuts (Ctrl+F, Esc) dropped — see Risk Register #14.
 */
export default function ClaimsDashboardDesktop({ navigation }: { navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void } }) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const allClaims = useClaimStore((s) => s.allClaims);
  const isLoading = useClaimStore((s) => s.isLoading);
  const loadAllClaims = useClaimStore((s) => s.loadAllClaims);
  const updateClaimStatus = useClaimStore((s) => s.updateClaimStatus);

  const { width } = useWindowDimensions();

  const [activeTab, setActiveTab] = useState<Tab>('all');
  const [showFilters, setShowFilters] = useState(true);
  const [statsExpanded, setStatsExpanded] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [typeFilter, setTypeFilter] = useState<ClaimType | null>(null);
  const [dateRange, setDateRange] = useState<{ start: Date; end: Date } | null>(null);
  const [customerNumberFilter, setCustomerNumberFilter] = useState('');
  const [customerNameFilter, setCustomerNameFilter] = useState('');
  const [invoiceNumberFilter, setInvoiceNumberFilter] = useState('');
  const [orderNumberFilter, setOrderNumberFilter] = useState('');
  const [sortBy, setSortBy] = useState<SortField>('date');
  const [sortAscending, setSortAscending] = useState(false);

  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [selectedClaim, setSelectedClaim] = useState<Claim | null>(null);
  const [actionSheetClaim, setActionSheetClaim] = useState<Claim | null>(null);
  const [statusEditClaim, setStatusEditClaim] = useState<Claim | null>(null);
  const [showDateModal, setShowDateModal] = useState(false);
  const [dateStartText, setDateStartText] = useState('');
  const [dateEndText, setDateEndText] = useState('');
  const [showExportSheet, setShowExportSheet] = useState(false);
  const [quickNotesTarget, setQuickNotesTarget] = useState<{ claim?: Claim; bulkIds?: Set<string>; decision: 'approve' | 'reject' } | null>(null);
  const [deliveryLookup, setDeliveryLookup] = useState<Record<string, { orderNumber?: string; customerNumber?: string }>>({});

  useEffect(() => {
    if (!currentUser) return;
    if (useClaimStore.getState().companyId !== currentUser.companyId) {
      useClaimStore.getState().initialize(currentUser.companyId);
    }
    loadAllClaims();
  }, [currentUser, loadAllClaims]);

  useEffect(() => {
    allClaims.forEach((claim) => {
      if (!claim.deliveryId || deliveryLookup[claim.deliveryId] !== undefined) return;
      deliveryRepository
        .getDeliveryById(claim.deliveryId)
        .then((d) =>
          setDeliveryLookup((prev) => ({
            ...prev,
            [claim.deliveryId]: d ? { orderNumber: d.orderNumber, customerNumber: d.customerNumber } : {},
          })),
        )
        .catch(() => setDeliveryLookup((prev) => ({ ...prev, [claim.deliveryId]: {} })));
    });
  }, [allClaims, deliveryLookup]);

  const hasAdvancedFilters = customerNumberFilter || customerNameFilter || invoiceNumberFilter || orderNumberFilter;
  const hasActiveFilters = statusFilter !== 'all' || typeFilter != null || dateRange != null || !!hasAdvancedFilters;

  const filteredClaims = useMemo(() => {
    let result = allClaims;
    if (statusFilter !== 'all') result = result.filter((c) => c.status === statusFilter);
    if (typeFilter) result = result.filter((c) => c.type === typeFilter);
    if (dateRange) {
      const endInclusive = new Date(dateRange.end.getFullYear(), dateRange.end.getMonth(), dateRange.end.getDate() + 1);
      result = result.filter((c) => c.createdAt >= dateRange.start && c.createdAt < endInclusive);
    }
    if (customerNumberFilter) {
      const q = customerNumberFilter.toLowerCase();
      result = result.filter((c) => (c.customerNumber?.toLowerCase().includes(q) ?? false) || (c.customerAccountNumber?.toLowerCase().includes(q) ?? false));
    }
    if (customerNameFilter) {
      const q = customerNameFilter.toLowerCase();
      result = result.filter((c) => c.customerName.toLowerCase().includes(q));
    }
    if (invoiceNumberFilter) {
      const q = invoiceNumberFilter.toLowerCase();
      result = result.filter((c) => c.invoiceNumber?.toLowerCase().includes(q) ?? false);
    }
    if (orderNumberFilter) {
      const q = orderNumberFilter.toLowerCase();
      result = result.filter((c) => {
        const metadataOrderNumber = c.metadata.orderNumber as string | undefined;
        return c.deliveryId.toLowerCase().includes(q) || (metadataOrderNumber?.toLowerCase().includes(q) ?? false);
      });
    }
    const q = searchQuery.trim().toLowerCase();
    if (q.length > 0) {
      result = result.filter((c) => c.id.toLowerCase().includes(q) || c.customerName.toLowerCase().includes(q) || c.description.toLowerCase().includes(q));
    }

    result = [...result].sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case 'date':
          cmp = a.createdAt.getTime() - b.createdAt.getTime();
          break;
        case 'status':
          cmp = a.status.localeCompare(b.status);
          break;
        case 'amount':
          cmp = (a.claimAmount ?? 0) - (b.claimAmount ?? 0);
          break;
      }
      return sortAscending ? cmp : -cmp;
    });
    return result;
  }, [allClaims, statusFilter, typeFilter, dateRange, customerNumberFilter, customerNameFilter, invoiceNumberFilter, orderNumberFilter, searchQuery, sortBy, sortAscending]);

  const stats = useMemo(() => {
    const total = allClaims.length;
    const submitted = allClaims.filter((c) => c.status === 'submitted').length;
    const pending = allClaims.filter((c) => c.status === 'pendingReview').length;
    const approved = allClaims.filter((c) => c.status === 'approved').length;
    const rejected = allClaims.filter((c) => c.status === 'rejected').length;
    const totalAmount = allClaims.reduce((sum, c) => sum + (c.claimAmount ?? 0), 0);
    return { total, submitted, pending, approved, rejected, totalAmount, avgAmount: total > 0 ? totalAmount / total : 0 };
  }, [allClaims]);

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Please log in</Text>
      </View>
    );
  }

  const clearAllFilters = () => {
    setStatusFilter('all');
    setTypeFilter(null);
    setDateRange(null);
    setSearchQuery('');
  };

  const clearAdvancedFilters = () => {
    setCustomerNumberFilter('');
    setCustomerNameFilter('');
    setInvoiceNumberFilter('');
    setOrderNumberFilter('');
  };

  const applyDateRange = () => {
    const start = new Date(dateStartText);
    const end = new Date(dateEndText);
    if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime())) {
      setDateRange({ start, end });
    }
    setShowDateModal(false);
  };

  const toggleSelectOne = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleQuickDecision = async (notes: string) => {
    if (!quickNotesTarget || !currentUser) return;
    const { claim, bulkIds, decision } = quickNotesTarget;
    setQuickNotesTarget(null);
    const newStatus: ClaimStatus = decision === 'approve' ? 'approved' : 'rejected';

    try {
      if (claim) {
        const ok = await updateClaimStatus({ claimId: claim.id, newStatus, userId: currentUser.id, userName: currentUser.fullName, notes: notes || undefined });
        Alert.alert(ok ? 'Success' : 'Error', ok ? `Claim ${decision}d` : `Failed to ${decision} claim`);
        if (ok && selectedClaim?.id === claim.id) setSelectedClaim(null);
      } else if (bulkIds) {
        let successCount = 0;
        for (const id of bulkIds) {
          const ok = await updateClaimStatus({ claimId: id, newStatus, userId: currentUser.id, userName: currentUser.fullName, notes: notes || undefined });
          if (ok) successCount++;
        }
        Alert.alert('Done', `${decision === 'approve' ? 'Approved' : 'Rejected'} ${successCount} of ${bulkIds.size} claims`);
        setSelectedIds(new Set());
        setIsMultiSelectMode(false);
      }
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    }
  };

  const handleUpdateStatus = async (claim: Claim, newStatus: ClaimStatus) => {
    setStatusEditClaim(null);
    if (!currentUser) return;
    try {
      await updateClaimStatus({ claimId: claim.id, newStatus, userId: currentUser.id, userName: currentUser.fullName });
      Alert.alert('Success', `Status updated to ${claimStatusDisplayText(newStatus)}`);
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    }
  };

  const handleExportCsv = async () => {
    setShowExportSheet(false);
    try {
      await exportClaims(
        filteredClaims.map((c) => ({
          id: c.id,
          driverName: c.driverName,
          type: c.type,
          description: c.description,
          status: c.status,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          resolutionNotes: c.resolutionNotes,
          claimAmount: c.claimAmount,
        })),
        statusFilter !== 'all' ? statusFilter : undefined,
        typeFilter ?? undefined,
      );
      Alert.alert('Success', `Exported ${filteredClaims.length} claim(s) to CSV`);
    } catch (e) {
      Alert.alert('Error', `Error exporting claims: ${(e as Error).message}`);
    }
  };

  const handleExportPdf = () => {
    setShowExportSheet(false);
    Alert.alert('Not Yet Available', 'Bulk PDF export is planned for a later phase (server-side PDF generation, tracked separately).');
  };

  const handleCopyId = (claim: Claim) => {
    Clipboard.setString(claim.id);
    Alert.alert('Copied', 'Claim ID copied to clipboard');
  };

  const showDetailPanel = width > 1200 && selectedClaim != null;

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading3}>Claims Management</Text>
        <View style={styles.headerBarRight}>
          {selectedIds.size > 0 ? (
            <View style={styles.selectedChip}>
              <Text style={styles.selectedChipText}>{selectedIds.size} selected</Text>
              <Pressable
                onPress={() => {
                  setSelectedIds(new Set());
                  setIsMultiSelectMode(false);
                }}
              >
                <Text style={styles.selectedChipClose}>✕</Text>
              </Pressable>
            </View>
          ) : null}
          {selectedIds.size > 1 ? (
            <>
              <Pressable onPress={() => setQuickNotesTarget({ bulkIds: selectedIds, decision: 'approve' })}>
                <Text style={styles.headerBarAction}>✓</Text>
              </Pressable>
              <Pressable onPress={() => setQuickNotesTarget({ bulkIds: selectedIds, decision: 'reject' })}>
                <Text style={styles.headerBarAction}>✕</Text>
              </Pressable>
            </>
          ) : null}
          <Pressable onPress={() => setIsMultiSelectMode((p) => !p)}>
            <Text style={styles.headerBarAction}>{isMultiSelectMode ? '☑' : '☐'}</Text>
          </Pressable>
          <Pressable onPress={() => setShowFilters((p) => !p)}>
            <Text style={styles.headerBarAction}>🔍</Text>
          </Pressable>
          <Pressable onPress={() => loadAllClaims()}>
            <Text style={styles.headerBarAction}>↻</Text>
          </Pressable>
          <Pressable onPress={() => setShowExportSheet(true)}>
            <Text style={styles.headerBarAction}>⬇</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.tabStrip}>
        <TabButton label="All Claims" active={activeTab === 'all'} onPress={() => setActiveTab('all')} />
        <TabButton label="Create Claim" active={activeTab === 'create'} onPress={() => setActiveTab('create')} />
        <TabButton label="Upload Evidence" active={activeTab === 'upload'} onPress={() => setActiveTab('upload')} />
      </View>

      {activeTab === 'create' ? (
        <CreateClaimForm />
      ) : activeTab === 'upload' ? (
        <UploadEvidenceForm />
      ) : (
        <View style={styles.body}>
          {showFilters ? (
            <View style={styles.sidebar}>
              <ScrollView contentContainerStyle={styles.sidebarContent}>
                <View style={styles.sidebarHeaderRow}>
                  <Text style={styles.sidebarTitle}>Filters</Text>
                  {hasActiveFilters ? (
                    <Pressable onPress={clearAllFilters}>
                      <Text style={styles.sidebarClear}>Clear</Text>
                    </Pressable>
                  ) : null}
                </View>

                <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Search</Text>
                <TextInput style={styles.input} placeholder="Search claims..." value={searchQuery} onChangeText={setSearchQuery} />

                <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Status</Text>
                <View style={styles.chipWrap}>
                  <Chip label="All" selected={statusFilter === 'all'} onPress={() => setStatusFilter('all')} />
                  <Chip label="Submitted" selected={statusFilter === 'submitted'} onPress={() => setStatusFilter('submitted')} />
                  <Chip label="Pending Review" selected={statusFilter === 'pendingReview'} onPress={() => setStatusFilter('pendingReview')} />
                  <Chip label="Approved" selected={statusFilter === 'approved'} onPress={() => setStatusFilter('approved')} />
                  <Chip label="Rejected" selected={statusFilter === 'rejected'} onPress={() => setStatusFilter('rejected')} />
                </View>

                <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Claim Type</Text>
                <View style={styles.chipWrap}>
                  <Chip label="All Types" selected={typeFilter == null} onPress={() => setTypeFilter(null)} />
                  {ALL_CLAIM_TYPES.map((type) => (
                    <Chip key={type} label={claimTypeDisplayText(type)} selected={typeFilter === type} onPress={() => setTypeFilter(type)} />
                  ))}
                </View>

                <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Date Range</Text>
                <Pressable
                  style={styles.modalOutlinedButton}
                  onPress={() => {
                    setDateStartText(dateRange ? dateRange.start.toISOString().slice(0, 10) : '');
                    setDateEndText(dateRange ? dateRange.end.toISOString().slice(0, 10) : '');
                    setShowDateModal(true);
                  }}
                >
                  <Text style={styles.modalOutlinedText} numberOfLines={1}>
                    {dateRange ? `${dateRange.start.toLocaleDateString()} - ${dateRange.end.toLocaleDateString()}` : 'Select Date Range'}
                  </Text>
                </Pressable>
                {dateRange ? (
                  <Pressable style={[styles.modalOutlinedButton, styles.clearDateButton]} onPress={() => setDateRange(null)}>
                    <Text style={styles.modalOutlinedText}>Clear Date</Text>
                  </Pressable>
                ) : null}

                <View style={styles.divider} />
                <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Advanced Filters</Text>
                <TextInput style={styles.input} placeholder="Customer Number" value={customerNumberFilter} onChangeText={setCustomerNumberFilter} />
                <TextInput style={[styles.input, styles.inputSpacer]} placeholder="Customer Name" value={customerNameFilter} onChangeText={setCustomerNameFilter} />
                <TextInput style={[styles.input, styles.inputSpacer]} placeholder="Invoice Number" value={invoiceNumberFilter} onChangeText={setInvoiceNumberFilter} />
                <TextInput style={[styles.input, styles.inputSpacer]} placeholder="Order Number" value={orderNumberFilter} onChangeText={setOrderNumberFilter} />
                {hasAdvancedFilters ? (
                  <Pressable style={[styles.modalOutlinedButton, styles.clearAdvancedButton]} onPress={clearAdvancedFilters}>
                    <Text style={[styles.modalOutlinedText, styles.clearAdvancedText]}>Clear Advanced Filters</Text>
                  </Pressable>
                ) : null}

                <View style={styles.divider} />
                <Pressable style={styles.sidebarHeaderRow} onPress={() => setStatsExpanded((p) => !p)}>
                  <Text style={styles.sidebarTitle}>📊 Overview</Text>
                  <Text style={styles.sidebarClear}>{statsExpanded ? '▲' : '▼'}</Text>
                </Pressable>
                {statsExpanded ? (
                  <View style={styles.statsList}>
                    <SidebarStat label="Total Claims" value={String(stats.total)} color={colors.info} />
                    <SidebarStat label="Submitted" value={String(stats.submitted)} color="#9C27B0" />
                    <SidebarStat label="Pending Review" value={String(stats.pending)} color={colors.warning} />
                    <SidebarStat label="Approved" value={String(stats.approved)} color={colors.success} />
                    <SidebarStat label="Rejected" value={String(stats.rejected)} color={colors.error} />
                    <SidebarStat label="Total Amount" value={`R${stats.totalAmount.toFixed(2)}`} color="#9C27B0" />
                    <SidebarStat label="Avg Claim" value={`R${stats.avgAmount.toFixed(2)}`} color="#00897B" />
                  </View>
                ) : null}
              </ScrollView>
            </View>
          ) : null}

          <View style={styles.mainArea}>
            <View style={styles.topBar}>
              <Pressable style={styles.exportButtonSmall} onPress={() => setShowExportSheet(true)}>
                <Text style={styles.exportButtonSmallText}>⬇ Export CSV</Text>
              </Pressable>
            </View>

            <View style={styles.contentRow}>
              <View style={styles.tableSection}>
                {isLoading && allClaims.length === 0 ? (
                  <View style={styles.centered}>
                    <Text style={textStyles.bodyMedium}>Loading...</Text>
                  </View>
                ) : filteredClaims.length === 0 ? (
                  <View style={styles.centered}>
                    <Text style={styles.emptyIcon}>📥</Text>
                    <Text style={textStyles.heading3}>No claims found</Text>
                    <Text style={[textStyles.bodyMedium, styles.emptySubtitle]}>Try adjusting your filters or search terms</Text>
                  </View>
                ) : (
                  <ScrollView horizontal>
                    <View style={{ minWidth: TABLE_WIDTH }}>
                      <View style={styles.tableHeaderRow}>
                        {isMultiSelectMode ? (
                          <View style={[styles.tableHeaderCell, COLS.checkbox]} />
                        ) : null}
                        <SortableHeader label="Inv #" width={COLS.invoice.width} field={null} sortBy={sortBy} onPress={() => {}} />
                        <View style={[styles.tableHeaderCell, COLS.custNumber]}>
                          <Text style={styles.tableHeaderText}>Cust #</Text>
                        </View>
                        <View style={[styles.tableHeaderCell, COLS.orderNumber]}>
                          <Text style={styles.tableHeaderText}>Order #</Text>
                        </View>
                        <View style={[styles.tableHeaderCell, COLS.type]}>
                          <Text style={styles.tableHeaderText}>Type</Text>
                        </View>
                        <SortableHeader label="Status" width={COLS.status.width} field="status" sortBy={sortBy} onPress={(f) => { setSortBy(f); setSortAscending((a) => (sortBy === f ? !a : true)); }} />
                        <View style={[styles.tableHeaderCell, COLS.customer]}>
                          <Text style={styles.tableHeaderText}>Customer</Text>
                        </View>
                        <View style={[styles.tableHeaderCell, COLS.driver]}>
                          <Text style={styles.tableHeaderText}>Driver</Text>
                        </View>
                        <SortableHeader label="Amount" width={COLS.amount.width} field="amount" sortBy={sortBy} onPress={(f) => { setSortBy(f); setSortAscending((a) => (sortBy === f ? !a : true)); }} />
                        <SortableHeader label="Date" width={COLS.date.width} field="date" sortBy={sortBy} onPress={(f) => { setSortBy(f); setSortAscending((a) => (sortBy === f ? !a : true)); }} />
                        <View style={[styles.tableHeaderCell, COLS.actions]}>
                          <Text style={styles.tableHeaderText}>Actions</Text>
                        </View>
                      </View>
                      <ScrollView style={styles.tableBody}>
                        {filteredClaims.map((claim) => (
                          <ClaimRow
                            key={claim.id}
                            claim={claim}
                            delivery={deliveryLookup[claim.deliveryId]}
                            isMultiSelectMode={isMultiSelectMode}
                            isSelected={selectedIds.has(claim.id)}
                            isActiveRow={selectedClaim?.id === claim.id}
                            isOverdue={isClaimOverdue(claim)}
                            onToggleSelect={() => toggleSelectOne(claim.id)}
                            onPress={() => setSelectedClaim(claim)}
                            onEditStatus={() => setStatusEditClaim(claim)}
                            onOpenActions={() => setActionSheetClaim(claim)}
                          />
                        ))}
                      </ScrollView>
                    </View>
                  </ScrollView>
                )}
              </View>

              {showDetailPanel && selectedClaim ? (
                <DetailPanel
                  claim={selectedClaim}
                  delivery={deliveryLookup[selectedClaim.deliveryId]}
                  onClose={() => setSelectedClaim(null)}
                  onApprove={() => setQuickNotesTarget({ claim: selectedClaim, decision: 'approve' })}
                  onReject={() => setQuickNotesTarget({ claim: selectedClaim, decision: 'reject' })}
                  onEditStatus={() => setStatusEditClaim(selectedClaim)}
                  onViewFull={() => navigation.navigate('ClaimDetails', { claimId: selectedClaim.id })}
                />
              ) : null}
            </View>
          </View>
        </View>
      )}

      <Modal visible={actionSheetClaim != null} transparent animationType="fade" onRequestClose={() => setActionSheetClaim(null)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setActionSheetClaim(null)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <ActionRow
              icon="👁"
              label="View Details"
              color={colors.textPrimary}
              onPress={() => {
                const claim = actionSheetClaim;
                setActionSheetClaim(null);
                if (claim) setSelectedClaim(claim);
              }}
            />
            {actionSheetClaim && ELIGIBLE_FOR_QUICK_DECISION.includes(actionSheetClaim.status) ? (
              <>
                <ActionRow
                  icon="✓"
                  label="Approve"
                  color={colors.success}
                  onPress={() => {
                    const claim = actionSheetClaim;
                    setActionSheetClaim(null);
                    if (claim) setQuickNotesTarget({ claim, decision: 'approve' });
                  }}
                />
                <ActionRow
                  icon="✕"
                  label="Reject"
                  color={colors.error}
                  onPress={() => {
                    const claim = actionSheetClaim;
                    setActionSheetClaim(null);
                    if (claim) setQuickNotesTarget({ claim, decision: 'reject' });
                  }}
                />
              </>
            ) : null}
            <ActionRow
              icon="✎"
              label="Edit Status"
              color={colors.textPrimary}
              onPress={() => {
                const claim = actionSheetClaim;
                setActionSheetClaim(null);
                if (claim) setStatusEditClaim(claim);
              }}
            />
            <ActionRow
              icon="⧉"
              label="Copy Claim ID"
              color={colors.textPrimary}
              onPress={() => {
                const claim = actionSheetClaim;
                setActionSheetClaim(null);
                if (claim) handleCopyId(claim);
              }}
            />
          </View>
        </Pressable>
      </Modal>

      <Modal visible={statusEditClaim != null} transparent animationType="fade" onRequestClose={() => setStatusEditClaim(null)}>
        <View style={styles.formModalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Update Claim Status</Text>
            {statusEditClaim ? <Text style={styles.modalHint}>Claim: {statusEditClaim.invoiceNumber ?? statusEditClaim.id}</Text> : null}
            <ScrollView style={styles.statusPickerList}>
              {ALL_CLAIM_STATUSES.map((status) => (
                <Pressable
                  key={status}
                  style={styles.pickerRow}
                  onPress={() => {
                    if (statusEditClaim) handleUpdateStatus(statusEditClaim, status);
                  }}
                >
                  <Text style={styles.pickerRowGlyph}>{statusEditClaim?.status === status ? '◉' : '○'}</Text>
                  <Text style={styles.pickerRowLabel}>{claimStatusDisplayText(status)}</Text>
                </Pressable>
              ))}
            </ScrollView>
            <Pressable style={styles.modalSecondaryButton} onPress={() => setStatusEditClaim(null)}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
          </View>
        </View>
      </Modal>

      <Modal visible={showDateModal} transparent animationType="fade" onRequestClose={() => setShowDateModal(false)}>
        <View style={styles.formModalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Filter by Date Range</Text>
            <Text style={styles.fieldLabel}>Start Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateStartText} onChangeText={setDateStartText} />
            <Text style={styles.fieldLabel}>End Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateEndText} onChangeText={setDateEndText} />
            <View style={styles.modalActionsRow}>
              <Pressable
                style={styles.modalSecondaryButton}
                onPress={() => {
                  setDateRange(null);
                  setShowDateModal(false);
                }}
              >
                <Text style={styles.modalSecondaryText}>Clear</Text>
              </Pressable>
              <Pressable style={styles.modalPrimaryButton} onPress={applyDateRange}>
                <Text style={textStyles.buttonText}>Apply</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <QuickNotesModal target={quickNotesTarget} onCancel={() => setQuickNotesTarget(null)} onSubmit={handleQuickDecision} />

      <Modal visible={showExportSheet} transparent animationType="fade" onRequestClose={() => setShowExportSheet(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowExportSheet(false)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <Text style={styles.actionSheetTitle}>Export Claims</Text>
            <ActionRow icon="📄" label="Export as PDF Reports" color={colors.textPrimary} onPress={handleExportPdf} />
            <ActionRow icon="📊" label="Export as CSV" color={colors.textPrimary} onPress={handleExportCsv} />
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

function TabButton({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.tabButton, active && styles.tabButtonActive]} onPress={onPress}>
      <Text style={[styles.tabButtonText, active && styles.tabButtonTextActive]}>{label}</Text>
    </Pressable>
  );
}

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function SidebarStat({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <View style={[styles.sidebarStat, { backgroundColor: `${color}1A` }]}>
      <Text style={styles.sidebarStatLabel}>{label}</Text>
      <Text style={[styles.sidebarStatValue, { color }]}>{value}</Text>
    </View>
  );
}

function SortableHeader({
  label,
  width,
  field,
  sortBy,
  onPress,
}: {
  label: string;
  width: number;
  field: SortField | null;
  sortBy: SortField;
  onPress: (field: SortField) => void;
}) {
  const isActive = field != null && sortBy === field;
  return (
    <Pressable style={[styles.tableHeaderCell, { width }]} onPress={() => field && onPress(field)}>
      <Text style={styles.tableHeaderText}>
        {label}
        {isActive ? ' ▾' : ''}
      </Text>
    </Pressable>
  );
}

function ActionRow({ label, icon, color, onPress }: { label: string; icon: string; color: string; onPress: () => void }) {
  return (
    <Pressable style={styles.actionRow} onPress={onPress}>
      <Text style={[styles.actionRowIcon, { color }]}>{icon}</Text>
      <Text style={[styles.actionRowLabel, { color }]}>{label}</Text>
    </Pressable>
  );
}

function StatusBadge({ status, onPress }: { status: ClaimStatus; onPress: () => void }) {
  return (
    <Pressable style={styles.statusBadge} onPress={onPress}>
      <Text style={styles.statusBadgeText} numberOfLines={1}>
        {claimStatusDisplayText(status)}
      </Text>
    </Pressable>
  );
}

function ClaimRow({
  claim,
  delivery,
  isMultiSelectMode,
  isSelected,
  isActiveRow,
  isOverdue,
  onToggleSelect,
  onPress,
  onEditStatus,
  onOpenActions,
}: {
  claim: Claim;
  delivery?: { orderNumber?: string; customerNumber?: string };
  isMultiSelectMode: boolean;
  isSelected: boolean;
  isActiveRow: boolean;
  isOverdue: boolean;
  onToggleSelect: () => void;
  onPress: () => void;
  onEditStatus: () => void;
  onOpenActions: () => void;
}) {
  return (
    <Pressable style={[styles.tableRow, isActiveRow && styles.tableRowActive, isOverdue && styles.tableRowOverdue]} onPress={isMultiSelectMode ? onToggleSelect : onPress}>
      {isMultiSelectMode ? (
        <View style={[styles.tableCell, COLS.checkbox]}>
          <Text>{isSelected ? '☑' : '☐'}</Text>
        </View>
      ) : null}
      <View style={[styles.tableCell, COLS.invoice]}>
        <Text style={styles.tableCellTextBold} numberOfLines={1}>
          {claim.invoiceNumber ?? claim.id}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.custNumber]}>
        <Text style={styles.tableCellText}>{delivery?.customerNumber ?? claim.customerAccountNumber ?? 'N/A'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.orderNumber]}>
        <Text style={styles.tableCellText}>{delivery?.orderNumber ?? '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.type]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {claimTypeDisplayText(claim.type)}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.status]}>
        <StatusBadge status={claim.status} onPress={onEditStatus} />
      </View>
      <View style={[styles.tableCell, COLS.customer]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {claim.customerName}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.driver]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {claim.driverName}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.amount]}>
        <Text style={styles.tableCellTextBold}>R{(claim.claimAmount ?? 0).toFixed(2)}</Text>
      </View>
      <View style={[styles.tableCell, COLS.date]}>
        <Text style={styles.tableCellText}>{claim.createdAt.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}</Text>
      </View>
      <Pressable style={[styles.tableCell, COLS.actions]} onPress={onOpenActions}>
        <Text style={styles.tableActionsGlyph}>⋮</Text>
      </Pressable>
    </Pressable>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue} numberOfLines={2}>
        {value}
      </Text>
    </View>
  );
}

function DetailPanel({
  claim,
  delivery,
  onClose,
  onApprove,
  onReject,
  onEditStatus,
  onViewFull,
}: {
  claim: Claim;
  delivery?: { orderNumber?: string; customerNumber?: string };
  onClose: () => void;
  onApprove: () => void;
  onReject: () => void;
  onEditStatus: () => void;
  onViewFull: () => void;
}) {
  const eligible = ELIGIBLE_FOR_QUICK_DECISION.includes(claim.status);
  return (
    <View style={styles.detailPanel}>
      <View style={styles.detailPanelHeader}>
        <Text style={styles.detailPanelTitle}>Claim Details</Text>
        <Pressable onPress={onClose}>
          <Text style={styles.closeGlyph}>✕</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.detailPanelContent}>
        <Text style={textStyles.heading3}>{claim.invoiceNumber ?? claim.id}</Text>
        <View style={styles.detailStatusRow}>
          <StatusBadge status={claim.status} onPress={onEditStatus} />
        </View>
        <View style={styles.divider} />

        <DetailRow label="Type" value={claimTypeDisplayText(claim.type)} />
        <DetailRow label="Customer" value={claim.customerName} />
        <DetailRow label="Driver" value={claim.driverName} />
        <DetailRow label="Cust #" value={delivery?.customerNumber ?? claim.customerAccountNumber ?? 'N/A'} />
        <DetailRow label="Order #" value={delivery?.orderNumber ?? '-'} />
        {claim.claimAmount != null ? <DetailRow label="Amount" value={`R${claim.claimAmount.toFixed(2)}`} /> : null}
        <DetailRow label="Filed" value={claim.createdAt.toLocaleString()} />
        {claim.description ? <DetailRow label="Description" value={claim.description} /> : null}
        {claim.photoUrls.length > 0 ? <DetailRow label="Photos" value={String(claim.photoUrls.length)} /> : null}

        <View style={styles.sectionSpacer} />
        {eligible ? (
          <>
            <Pressable style={styles.modalPrimaryButton} onPress={onApprove}>
              <Text style={textStyles.buttonText}>✓ Approve</Text>
            </Pressable>
            <Pressable style={[styles.modalOutlinedButton, styles.rejectButton]} onPress={onReject}>
              <Text style={styles.rejectButtonText}>✕ Reject</Text>
            </Pressable>
          </>
        ) : null}
        <Pressable style={styles.modalOutlinedButton} onPress={onEditStatus}>
          <Text style={styles.modalOutlinedText}>✎ Edit Status</Text>
        </Pressable>
        <Pressable style={styles.modalOutlinedButton} onPress={onViewFull}>
          <Text style={styles.modalOutlinedText}>↗ View Full Details</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

function QuickNotesModal({
  target,
  onCancel,
  onSubmit,
}: {
  target: { claim?: Claim; bulkIds?: Set<string>; decision: 'approve' | 'reject' } | null;
  onCancel: () => void;
  onSubmit: (notes: string) => void;
}) {
  const [notes, setNotes] = useState('');

  useEffect(() => {
    setNotes('');
  }, [target]);

  if (!target) return null;
  const count = target.bulkIds?.size;
  const isReject = target.decision === 'reject';
  const title = count ? (isReject ? 'Bulk Reject' : 'Bulk Approve') : isReject ? 'Reject Claim' : 'Approve Claim';
  const hint = count ? `${isReject ? 'Reason' : 'Notes'} for ${count} claims:` : isReject ? 'Reason for rejection (required):' : 'Optional approval notes:';

  return (
    <Modal visible transparent animationType="fade" onRequestClose={onCancel}>
      <View style={styles.formModalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>{title}</Text>
          <Text style={[styles.fieldLabel, styles.modalHintSpacer]}>{hint}</Text>
          <TextInput style={styles.notesInput} value={notes} onChangeText={setNotes} multiline placeholder={isReject ? 'Required' : 'Optional'} />
          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} onPress={onCancel}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable
              style={[styles.modalPrimaryButton, isReject && styles.rejectPrimaryButton, isReject && notes.trim().length === 0 && styles.modalPrimaryButtonDisabled]}
              disabled={isReject && notes.trim().length === 0}
              onPress={() => onSubmit(notes.trim())}
            >
              <Text style={textStyles.buttonText}>{isReject ? 'Reject' : 'Approve'}</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyIcon: { fontSize: 56, opacity: 0.3, marginBottom: spacing.medium },
  emptySubtitle: { color: colors.textSecondary, textAlign: 'center' },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.medium, paddingVertical: spacing.medium },
  headerBarRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  headerBarAction: { color: colors.white, fontSize: 18 },
  selectedChip: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, backgroundColor: 'rgba(255,255,255,0.2)', borderRadius: 16, paddingHorizontal: spacing.small + 4, paddingVertical: 4 },
  selectedChipText: { color: colors.white, fontSize: 12, fontWeight: '600' },
  selectedChipClose: { color: colors.white, fontSize: 14 },
  tabStrip: { flexDirection: 'row', backgroundColor: colors.card, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tabButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.medium, borderBottomWidth: 3, borderBottomColor: 'transparent' },
  tabButtonActive: { borderBottomColor: colors.primary },
  tabButtonText: { color: colors.textSecondary, fontWeight: '600' },
  tabButtonTextActive: { color: colors.primary },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 280, borderRightWidth: 1, borderRightColor: colors.divider, backgroundColor: colors.card },
  sidebarContent: { padding: spacing.medium },
  sidebarHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  sidebarTitle: { fontWeight: '700', fontSize: 14, color: colors.textPrimary },
  sidebarClear: { color: colors.primary, fontWeight: '600' },
  sidebarLabel: { fontWeight: '600', color: colors.textSecondary, marginBottom: spacing.small, fontSize: 12 },
  sidebarSectionSpacer: { marginTop: spacing.large },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  inputSpacer: { marginTop: spacing.small + 4 },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 12, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  modalOutlinedButton: { alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedText: { color: colors.textPrimary, fontWeight: '600' },
  clearDateButton: { borderColor: colors.error },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  clearAdvancedButton: { borderColor: colors.error, marginTop: spacing.medium },
  clearAdvancedText: { color: colors.error },
  statsList: { marginTop: spacing.small },
  sidebarStat: { borderRadius: radii.borderRadius, padding: spacing.small + 4, marginBottom: spacing.small },
  sidebarStatLabel: { fontSize: 11, color: colors.textSecondary },
  sidebarStatValue: { fontSize: 16, fontWeight: 'bold', marginTop: 2 },
  mainArea: { flex: 1 },
  topBar: { flexDirection: 'row', justifyContent: 'flex-end', padding: spacing.medium, borderBottomWidth: 1, borderBottomColor: colors.divider },
  exportButtonSmall: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small },
  exportButtonSmallText: { color: colors.textSecondary, fontWeight: '600', fontSize: 12 },
  contentRow: { flex: 1, flexDirection: 'row' },
  tableSection: { flex: 1, margin: spacing.medium, backgroundColor: colors.card, borderRadius: radii.cardRadius, overflow: 'hidden' },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.background, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableHeaderCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small + 4, justifyContent: 'center' },
  tableHeaderText: { fontSize: 12, fontWeight: '700', color: colors.textSecondary },
  tableBody: { flex: 1 },
  tableRow: { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: colors.divider, minHeight: 56 },
  tableRowActive: { backgroundColor: `${colors.primary}0F` },
  tableRowOverdue: { borderLeftWidth: 3, borderLeftColor: colors.error },
  tableCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small, justifyContent: 'center' },
  tableCellText: { fontSize: 13, color: colors.textPrimary },
  tableCellTextBold: { fontSize: 13, fontWeight: '700', color: colors.textPrimary },
  tableActionsGlyph: { fontSize: 18, color: colors.textSecondary, textAlign: 'center' },
  statusBadge: { alignSelf: 'flex-start', borderRadius: 12, backgroundColor: `${colors.primary}1A`, paddingHorizontal: spacing.small, paddingVertical: 4 },
  statusBadgeText: { fontSize: 11, fontWeight: '600', color: colors.primary },
  detailPanel: { width: 480, borderLeftWidth: 1, borderLeftColor: colors.divider, backgroundColor: colors.card },
  detailPanelHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: spacing.medium, borderBottomWidth: 1, borderBottomColor: colors.divider },
  detailPanelTitle: { fontWeight: '700', fontSize: 15, color: colors.textPrimary },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  detailPanelContent: { padding: spacing.large },
  detailStatusRow: { marginTop: spacing.small },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4, gap: spacing.medium },
  detailLabel: { color: colors.textSecondary },
  detailValue: { fontWeight: '600', color: colors.textPrimary, flex: 1, textAlign: 'right' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  formModalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionSheetTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary, marginBottom: spacing.small },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600' },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '85%' },
  modalHint: { color: colors.textSecondary, fontSize: 12, marginTop: spacing.small },
  modalHintSpacer: { marginTop: spacing.medium },
  statusPickerList: { maxHeight: 320, marginTop: spacing.medium },
  pickerRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  pickerRowGlyph: { fontSize: 16, color: colors.primary, marginRight: spacing.small + 4 },
  pickerRowLabel: { fontSize: 14, color: colors.textPrimary },
  fieldLabel: { fontWeight: '600', fontSize: 13, marginTop: spacing.medium, marginBottom: spacing.small },
  dateInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  notesInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background, minHeight: 80, textAlignVertical: 'top' },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalPrimaryButton: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.success, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalPrimaryButtonDisabled: { opacity: 0.5 },
  rejectPrimaryButton: { backgroundColor: colors.error },
  modalSecondaryButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius, borderWidth: 1, borderColor: colors.divider, marginTop: spacing.small },
  modalSecondaryText: { color: colors.textSecondary, fontWeight: '600' },
  rejectButton: { borderColor: colors.error },
  rejectButtonText: { color: colors.error, fontWeight: '600' },
  sectionSpacer: { height: spacing.medium },
});
