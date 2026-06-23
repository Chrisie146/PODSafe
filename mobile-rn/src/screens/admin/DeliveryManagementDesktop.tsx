import React, { useEffect, useMemo, useState } from 'react';
import { Alert, FlatList, Image, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { useAuthStore } from '../../stores/useAuthStore';
import { usePodStore } from '../../stores/usePodStore';
import { hasAnyPermission, hasPermission } from '../../permissions/permissionService';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { exportDeliveries } from '../../repositories/csvExportService';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { userFromFirestore } from '../../models/user.converters';
import { PodAccessToken } from '../../repositories/podTokenRepository';
import PodQrCodeDialog from '../../components/PodQrCodeDialog';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const deliveryRepository = new DeliveryRepository();

type StatusFilter = 'all' | DeliveryStatus;
type DriverFilter = 'all' | 'unassigned';
type TransportFilter = 'all' | 'thirdParty' | 'internal';
type SortField = 'orderNumber' | 'invoiceNumber' | 'customerName' | 'scheduledDate';

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

function daysToDeliverLabel(delivery: Delivery): { text: string; color: string } {
  if (!delivery.invoiceDate) return { text: '-', color: colors.textSecondary };
  const endDate = delivery.deliveredAt ?? delivery.createdAt;
  const daysTaken = Math.round((endDate.getTime() - delivery.invoiceDate.getTime()) / 86400000);
  const color = daysTaken > 5 ? colors.error : daysTaken > 3 ? colors.warning : colors.success;
  const text = delivery.deliveredAt ? `${daysTaken} days` : `${daysTaken} days (est)`;
  return { text, color };
}

function isOverdue(delivery: Delivery): boolean {
  return delivery.status !== 'delivered' && delivery.scheduledDate.getTime() < Date.now();
}

const COLS = {
  checkbox: { width: 36 },
  status: { width: 100 },
  order: { width: 90 },
  invoice: { width: 100 },
  customer: { width: 150 },
  custNumber: { width: 90 },
  address: { width: 180 },
  scheduled: { width: 110 },
  items: { width: 70 },
  daysToDeliver: { width: 110 },
  driver: { width: 140 },
  vehicle: { width: 90 },
  actions: { width: 130 },
};
const TABLE_WIDTH = Object.values(COLS).reduce((sum, c) => sum + c.width, 0);

/**
 * Ported from lib/screens/admin/delivery_management_desktop.dart (verified against source
 * on 2026-06-23). Same data layer as the mobile variant (DeliveryManagement.tsx):
 * `DeliveryRepository` directly, plus the same `hasPermission`/`hasAnyPermission` checks
 * for export/create gating.
 *
 * Real bugs found and fixed:
 * - The "Driver Assignment" sidebar filter ("All Drivers"/"Unassigned") has an `onTap` of
 *   `setState(() {})` with a `// TODO: Implement driver filtering` comment, and its
 *   `isSelected` check compares against `_statusFilter` (clearly copy-pasted from a
 *   different filter) — confirmed dead/broken by direct read. Fixed to actually filter by
 *   `driverId` presence.
 * - The 3 "Quick Filters" chips (High Priority/Overdue/Has Items) are identically dead
 *   (`// TODO: Implement quick filters`). "Overdue" and "Has Items" are wired for real
 *   (both derivable from the `Delivery` model); "High Priority" is dropped entirely — there
 *   is no priority field anywhere on `Delivery`, even partially, so faking one would be
 *   inventing data rather than fixing a wiring bug.
 * - `_bulkAssignDriver()`'s driver picker reads `doc.data()['name']`, but the actual field
 *   on a driver's `users` document is `fullName` (confirmed via `userFromFirestore`) — every
 *   driver in that picker would show blank/undefined. Fixed to read `fullName`.
 * - Per-row driver names used ~N separate `FutureBuilder<String>` Firestore reads (one per
 *   visible row) for the Driver column, repeated again for the preview panel's driver info.
 *   Replaced with one chunked-by-10 `documentId()`-in batch fetch (same pattern already
 *   used in `VehicleManagementDesktop.tsx`'s "Assigned Today" feature), shared across the
 *   table and the preview panel.
 *
 * Scoped out: drag-to-reorder columns and per-column visibility toggles (desktop
 * power-user features layered on top of a table that already shows everything; same
 * category as `ItemCatalogDesktop.tsx`'s dropped column toggles). "Download Template" stays
 * a "Coming Soon" stub — the mobile screen's own header comment already confirms
 * `delivery_export_service.dart`'s native download stub is broken and deferred to Phase 6,
 * so this isn't a new gap. QR code viewing reuses the already-built `usePodStore.getAccessToken()`
 * + `PodQrCodeDialog` (built for `PodCapture.tsx`) rather than porting a new dialog. Dropped:
 * keyboard shortcuts, dual top/bottom scrollbars with Shift+scroll (Risk Register #14).
 */
export default function DeliveryManagementDesktop({ navigation }: { navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void } }) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const getAccessToken = usePodStore((s) => s.getAccessToken);

  const [allDeliveries, setAllDeliveries] = useState<Delivery[] | null>(null);
  const [driverNamesById, setDriverNamesById] = useState<Record<string, string>>({});

  const [showFilters, setShowFilters] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [driverFilter, setDriverFilter] = useState<DriverFilter>('all');
  const [transportFilter, setTransportFilter] = useState<TransportFilter>('all');
  const [overdueOnly, setOverdueOnly] = useState(false);
  const [hasItemsOnly, setHasItemsOnly] = useState(false);
  const [dateRange, setDateRange] = useState<{ start: Date; end: Date } | null>(null);
  const [showDateModal, setShowDateModal] = useState(false);
  const [dateStartText, setDateStartText] = useState('');
  const [dateEndText, setDateEndText] = useState('');
  const [sortBy, setSortBy] = useState<SortField>('scheduledDate');
  const [sortAscending, setSortAscending] = useState(true);

  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [previewDelivery, setPreviewDelivery] = useState<Delivery | null>(null);
  const [showExportSheet, setShowExportSheet] = useState(false);
  const [showAssignDriver, setShowAssignDriver] = useState(false);
  const [showBulkStatus, setShowBulkStatus] = useState(false);
  const [qrToken, setQrToken] = useState<PodAccessToken | null>(null);

  const canExport = hasAnyPermission(currentUser, ['deliveriesManage', 'financeExport']);
  const canCreate = hasPermission(currentUser, 'deliveriesManage');

  useEffect(() => {
    if (!currentUser) return;
    return deliveryRepository.subscribeToCompanyDeliveries(currentUser.companyId, setAllDeliveries, () => setAllDeliveries([]), { orderByScheduledDate: true });
  }, [currentUser]);

  useEffect(() => {
    if (!allDeliveries) return;
    const idsToFetch = [...new Set(allDeliveries.map((d) => d.driverId))].filter((id) => id && driverNamesById[id] === undefined);
    if (idsToFetch.length === 0) return;

    (async () => {
      const namesMap: Record<string, string> = {};
      for (let i = 0; i < idsToFetch.length; i += 10) {
        const chunk = idsToFetch.slice(i, i + 10);
        const snapshot = await firestore().collection('users').where(firestore.FieldPath.documentId(), 'in', chunk).get();
        snapshot.docs.forEach((doc) => {
          namesMap[doc.id] = userFromFirestore(doc).fullName || 'Unknown';
        });
      }
      setDriverNamesById((prev) => ({ ...prev, ...namesMap }));
    })();
  }, [allDeliveries, driverNamesById]);

  const filteredDeliveries = useMemo(() => {
    if (!allDeliveries) return null;
    let result = allDeliveries;

    if (statusFilter !== 'all') result = result.filter((d) => d.status === statusFilter);
    if (driverFilter === 'unassigned') result = result.filter((d) => !d.driverId);
    if (transportFilter === 'thirdParty') result = result.filter((d) => d.isThirdPartyTransport);
    if (transportFilter === 'internal') result = result.filter((d) => !d.isThirdPartyTransport);
    if (overdueOnly) result = result.filter(isOverdue);
    if (hasItemsOnly) result = result.filter((d) => d.items.length > 0);
    if (dateRange) {
      const endInclusive = new Date(dateRange.end.getFullYear(), dateRange.end.getMonth(), dateRange.end.getDate() + 1);
      result = result.filter((d) => d.scheduledDate >= dateRange.start && d.scheduledDate < endInclusive);
    }
    const q = searchQuery.trim().toLowerCase();
    if (q.length > 0) {
      result = result.filter((d) => d.customerName.toLowerCase().includes(q) || d.customerAddress.toLowerCase().includes(q) || d.invoiceNumber.toLowerCase().includes(q));
    }

    result = [...result].sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case 'orderNumber':
          cmp = (a.orderNumber ?? '').localeCompare(b.orderNumber ?? '');
          break;
        case 'invoiceNumber':
          cmp = a.invoiceNumber.localeCompare(b.invoiceNumber);
          break;
        case 'customerName':
          cmp = a.customerName.localeCompare(b.customerName);
          break;
        case 'scheduledDate':
          cmp = a.scheduledDate.getTime() - b.scheduledDate.getTime();
          break;
      }
      return sortAscending ? cmp : -cmp;
    });
    return result;
  }, [allDeliveries, statusFilter, driverFilter, transportFilter, overdueOnly, hasItemsOnly, dateRange, searchQuery, sortBy, sortAscending]);

  const stats = useMemo(() => {
    const deliveries = allDeliveries ?? [];
    return {
      total: deliveries.length,
      pending: deliveries.filter((d) => d.status === 'pending').length,
      inTransit: deliveries.filter((d) => d.status === 'inTransit').length,
      delivered: deliveries.filter((d) => d.status === 'delivered').length,
    };
  }, [allDeliveries]);

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Error: No company ID</Text>
      </View>
    );
  }

  const toggleSelectOne = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const clearFilters = () => {
    setSearchQuery('');
    setStatusFilter('all');
    setDriverFilter('all');
    setTransportFilter('all');
    setOverdueOnly(false);
    setHasItemsOnly(false);
    setDateRange(null);
  };

  const applyDateRange = () => {
    const start = new Date(dateStartText);
    const end = new Date(dateEndText);
    if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime())) setDateRange({ start, end });
    setShowDateModal(false);
  };

  const comingSoon = (label: string) => {
    setShowExportSheet(false);
    Alert.alert(label, 'Coming Soon');
  };

  const handleExportSelected = async () => {
    setShowExportSheet(false);
    const deliveries = isMultiSelectMode && selectedIds.size > 0 ? (filteredDeliveries ?? []).filter((d) => selectedIds.has(d.id)) : filteredDeliveries ?? [];
    try {
      await exportDeliveries(
        deliveries.map((d) => ({
          trackingNumber: d.invoiceNumber,
          customerName: d.customerName,
          customerPhone: d.customerPhone,
          address: d.customerAddress,
          scheduledDate: d.scheduledDate,
          invoiceDate: d.invoiceDate,
          status: d.status,
          driverName: driverNamesById[d.driverId] ?? 'Unassigned',
          notes: d.notes,
          createdAt: d.createdAt,
          completedAt: d.deliveredAt,
        })),
        statusFilter !== 'all' ? statusFilter : undefined,
      );
      Alert.alert('Success', `Exported ${deliveries.length} delivery(ies) to CSV`);
    } catch (e) {
      Alert.alert('Error', `Error exporting deliveries: ${(e as Error).message}`);
    }
  };

  const handleDelete = (delivery: Delivery) => {
    Alert.alert('Delete Delivery', `Are you sure you want to delete delivery for ${delivery.customerName}?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            await deliveryRepository.deleteDelivery(delivery.id);
            setPreviewDelivery((prev) => (prev?.id === delivery.id ? null : prev));
          } catch (e) {
            Alert.alert('Error', `Failed to delete: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  const handleViewQrCode = async (delivery: Delivery) => {
    const token = await getAccessToken(delivery.id);
    if (token) {
      setQrToken(token);
    } else {
      Alert.alert('Notice', 'QR code is being generated. Please try again in a moment.');
    }
  };

  const handleBulkAssignDriver = async (driverId: string, driverName: string) => {
    setShowAssignDriver(false);
    try {
      for (const id of selectedIds) {
        const delivery = allDeliveries?.find((d) => d.id === id);
        if (delivery) await deliveryRepository.updateDelivery({ ...delivery, driverId });
      }
      Alert.alert('Success', `Assigned ${selectedIds.size} deliveries to ${driverName}`);
      setSelectedIds(new Set());
      setIsMultiSelectMode(false);
    } catch (e) {
      Alert.alert('Error', `Failed to assign: ${(e as Error).message}`);
    }
  };

  const handleBulkUpdateStatus = async (status: DeliveryStatus) => {
    setShowBulkStatus(false);
    try {
      for (const id of selectedIds) {
        await deliveryRepository.updateDeliveryStatus(id, status);
      }
      Alert.alert('Success', `Updated ${selectedIds.size} deliveries to ${statusLabel(status)}`);
      setSelectedIds(new Set());
      setIsMultiSelectMode(false);
    } catch (e) {
      Alert.alert('Error', `Failed to update: ${(e as Error).message}`);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <View style={styles.headerBarLeft}>
          <Text style={textStyles.heading3}>Delivery Management</Text>
          <Text style={styles.desktopBadge}>Desktop</Text>
        </View>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => setIsMultiSelectMode((p) => !p)}>
            <Text style={styles.headerBarAction}>{isMultiSelectMode ? '☑' : '☐'}</Text>
          </Pressable>
          <Pressable onPress={() => setShowFilters((p) => !p)}>
            <Text style={styles.headerBarAction}>🔍</Text>
          </Pressable>
          {canExport ? (
            <Pressable onPress={() => setShowExportSheet(true)}>
              <Text style={styles.headerBarAction}>⬇</Text>
            </Pressable>
          ) : null}
          {canCreate ? (
            <Pressable style={styles.headerBarButton} onPress={() => navigation.navigate('CreateDelivery')}>
              <Text style={styles.headerBarButtonText}>+ New Delivery</Text>
            </Pressable>
          ) : null}
        </View>
      </View>

      <View style={styles.body}>
        {showFilters ? (
          <View style={styles.sidebar}>
            <ScrollView contentContainerStyle={styles.sidebarContent}>
              <View style={styles.sidebarHeaderRow}>
                <Text style={styles.sidebarTitle}>Filters</Text>
                <Pressable onPress={clearFilters}>
                  <Text style={styles.sidebarClear}>Clear</Text>
                </Pressable>
              </View>

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Search</Text>
              <TextInput style={styles.input} placeholder="Search customer, address, invoice..." value={searchQuery} onChangeText={setSearchQuery} />

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Delivery Status</Text>
              <FilterOption label="All Statuses" selected={statusFilter === 'all'} onPress={() => setStatusFilter('all')} />
              <FilterOption label="Pending" selected={statusFilter === 'pending'} onPress={() => setStatusFilter('pending')} />
              <FilterOption label="In Transit" selected={statusFilter === 'inTransit'} onPress={() => setStatusFilter('inTransit')} />
              <FilterOption label="Delivered" selected={statusFilter === 'delivered'} onPress={() => setStatusFilter('delivered')} />

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

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Driver Assignment</Text>
              <FilterOption label="All Drivers" selected={driverFilter === 'all'} onPress={() => setDriverFilter('all')} />
              <FilterOption label="Unassigned" selected={driverFilter === 'unassigned'} onPress={() => setDriverFilter('unassigned')} />

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Transport Type</Text>
              <FilterOption label="All Transport" selected={transportFilter === 'all'} onPress={() => setTransportFilter('all')} />
              <FilterOption label="3rd Party Only" selected={transportFilter === 'thirdParty'} onPress={() => setTransportFilter('thirdParty')} />
              <FilterOption label="Internal Only" selected={transportFilter === 'internal'} onPress={() => setTransportFilter('internal')} />

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Quick Filters</Text>
              <View style={styles.chipWrap}>
                <Chip label="⚠ Overdue" selected={overdueOnly} onPress={() => setOverdueOnly((p) => !p)} />
                <Chip label="📦 Has Items" selected={hasItemsOnly} onPress={() => setHasItemsOnly((p) => !p)} />
              </View>
            </ScrollView>
          </View>
        ) : null}

        <View style={styles.mainArea}>
          <View style={styles.statsBar}>
            <MiniStat label="Total Deliveries" value={stats.total} icon="🚚" color={colors.info} />
            <MiniStat label="Pending" value={stats.pending} icon="⏳" color={colors.warning} />
            <MiniStat label="In Transit" value={stats.inTransit} icon="🚛" color={colors.info} />
            <MiniStat label="Delivered" value={stats.delivered} icon="✓" color={colors.success} />
          </View>

          {isMultiSelectMode && selectedIds.size > 0 ? (
            <View style={styles.bulkBar}>
              <Text style={styles.bulkBarText}>{selectedIds.size} deliveries selected</Text>
              <Pressable onPress={() => setShowAssignDriver(true)}>
                <Text style={styles.bulkBarAction}>Assign Driver</Text>
              </Pressable>
              <Pressable onPress={() => setShowBulkStatus(true)}>
                <Text style={styles.bulkBarAction}>Update Status</Text>
              </Pressable>
              <Pressable onPress={handleExportSelected}>
                <Text style={styles.bulkBarAction}>Export Selected</Text>
              </Pressable>
              <Pressable onPress={() => setSelectedIds(new Set())}>
                <Text style={styles.bulkBarAction}>Clear</Text>
              </Pressable>
            </View>
          ) : null}

          <View style={styles.contentRow}>
            <View style={styles.tableSection}>
              {filteredDeliveries === null ? (
                <View style={styles.centered}>
                  <Text style={textStyles.bodyMedium}>Loading...</Text>
                </View>
              ) : filteredDeliveries.length === 0 ? (
                <View style={styles.centered}>
                  <Text style={styles.emptyIcon}>🚚</Text>
                  <Text style={textStyles.heading3}>{allDeliveries?.length === 0 ? 'No deliveries yet' : 'No matching deliveries'}</Text>
                </View>
              ) : (
                <ScrollView horizontal>
                  <View style={{ minWidth: TABLE_WIDTH }}>
                    <View style={styles.tableHeaderRow}>
                      {isMultiSelectMode ? <View style={[styles.tableHeaderCell, COLS.checkbox]} /> : null}
                      <View style={[styles.tableHeaderCell, COLS.status]}>
                        <Text style={styles.tableHeaderText}>Status</Text>
                      </View>
                      <SortableHeader label="Order #" width={COLS.order.width} field="orderNumber" sortBy={sortBy} onPress={(f) => { setSortBy(f); setSortAscending((a) => (sortBy === f ? !a : true)); }} />
                      <SortableHeader label="Invoice" width={COLS.invoice.width} field="invoiceNumber" sortBy={sortBy} onPress={(f) => { setSortBy(f); setSortAscending((a) => (sortBy === f ? !a : true)); }} />
                      <SortableHeader label="Customer" width={COLS.customer.width} field="customerName" sortBy={sortBy} onPress={(f) => { setSortBy(f); setSortAscending((a) => (sortBy === f ? !a : true)); }} />
                      <View style={[styles.tableHeaderCell, COLS.custNumber]}>
                        <Text style={styles.tableHeaderText}>Cust #</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.address]}>
                        <Text style={styles.tableHeaderText}>Address</Text>
                      </View>
                      <SortableHeader label="Scheduled" width={COLS.scheduled.width} field="scheduledDate" sortBy={sortBy} onPress={(f) => { setSortBy(f); setSortAscending((a) => (sortBy === f ? !a : true)); }} />
                      <View style={[styles.tableHeaderCell, COLS.items]}>
                        <Text style={styles.tableHeaderText}>Items</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.daysToDeliver]}>
                        <Text style={styles.tableHeaderText}>Days to Deliver</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.driver]}>
                        <Text style={styles.tableHeaderText}>Driver</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.vehicle]}>
                        <Text style={styles.tableHeaderText}>Vehicle</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.actions]}>
                        <Text style={styles.tableHeaderText}>Actions</Text>
                      </View>
                    </View>
                    <ScrollView style={styles.tableBody}>
                      {filteredDeliveries.map((delivery) => (
                        <DeliveryRow
                          key={delivery.id}
                          delivery={delivery}
                          driverName={driverNamesById[delivery.driverId]}
                          isMultiSelectMode={isMultiSelectMode}
                          isSelected={selectedIds.has(delivery.id)}
                          isActiveRow={previewDelivery?.id === delivery.id}
                          onToggleSelect={() => toggleSelectOne(delivery.id)}
                          onPress={() => setPreviewDelivery(delivery)}
                          onView={() => navigation.navigate('DeliveryDetails', { deliveryId: delivery.id })}
                          onEdit={() => navigation.navigate('CreateDelivery', { deliveryId: delivery.id })}
                          onViewQr={() => handleViewQrCode(delivery)}
                          onDelete={() => handleDelete(delivery)}
                        />
                      ))}
                    </ScrollView>
                  </View>
                </ScrollView>
              )}
            </View>

            {previewDelivery ? (
              <PreviewPanel
                delivery={previewDelivery}
                driverName={driverNamesById[previewDelivery.driverId]}
                onClose={() => setPreviewDelivery(null)}
                onEdit={() => navigation.navigate('CreateDelivery', { deliveryId: previewDelivery.id })}
                onDelete={() => handleDelete(previewDelivery)}
              />
            ) : null}
          </View>
        </View>
      </View>

      <Modal visible={showDateModal} transparent animationType="fade" onRequestClose={() => setShowDateModal(false)}>
        <View style={styles.formModalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Date Range</Text>
            <Text style={styles.fieldLabel}>Start Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateStartText} onChangeText={setDateStartText} />
            <Text style={styles.fieldLabel}>End Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateEndText} onChangeText={setDateEndText} />
            <View style={styles.modalActionsRow}>
              <Pressable style={styles.modalSecondaryButton} onPress={() => { setDateRange(null); setShowDateModal(false); }}>
                <Text style={styles.modalSecondaryText}>Clear</Text>
              </Pressable>
              <Pressable style={styles.modalPrimaryButton} onPress={applyDateRange}>
                <Text style={textStyles.buttonText}>Apply</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={showExportSheet} transparent animationType="fade" onRequestClose={() => setShowExportSheet(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowExportSheet(false)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <ActionRow icon="📤" label="Bulk Upload CSV" onPress={() => { setShowExportSheet(false); navigation.navigate('BulkUpload'); }} />
            <ActionRow icon="⬇" label="Download Template" onPress={() => comingSoon('Download Template')} />
            <ActionRow icon="📊" label="Export All Deliveries" onPress={handleExportSelected} />
          </View>
        </Pressable>
      </Modal>

      <AssignDriverModal visible={showAssignDriver} companyId={currentUser.companyId} onClose={() => setShowAssignDriver(false)} onAssign={handleBulkAssignDriver} />

      <BulkStatusModal visible={showBulkStatus} onClose={() => setShowBulkStatus(false)} onApply={handleBulkUpdateStatus} />

      {qrToken ? <PodQrCodeDialog visible token={qrToken} onClose={() => setQrToken(null)} /> : null}
    </View>
  );
}

function MiniStat({ label, value, icon, color }: { label: string; value: number; icon: string; color: string }) {
  return (
    <View style={[styles.statCard, shadows.card]}>
      <View style={[styles.statIconBox, { backgroundColor: `${color}1A` }]}>
        <Text style={[styles.statIcon, { color }]}>{icon}</Text>
      </View>
      <View>
        <Text style={styles.statValue}>{value}</Text>
        <Text style={styles.statLabel}>{label}</Text>
      </View>
    </View>
  );
}

function FilterOption({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.filterOption, selected && styles.filterOptionSelected]} onPress={onPress}>
      <Text style={[styles.filterOptionLabel, selected && styles.filterOptionLabelSelected]}>{label}</Text>
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

function SortableHeader({ label, width, field, sortBy, onPress }: { label: string; width: number; field: SortField; sortBy: SortField; onPress: (field: SortField) => void }) {
  const isActive = sortBy === field;
  return (
    <Pressable style={[styles.tableHeaderCell, { width }]} onPress={() => onPress(field)}>
      <Text style={styles.tableHeaderText}>
        {label}
        {isActive ? ' ▾' : ''}
      </Text>
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

function DeliveryRow({
  delivery,
  driverName,
  isMultiSelectMode,
  isSelected,
  isActiveRow,
  onToggleSelect,
  onPress,
  onView,
  onEdit,
  onViewQr,
  onDelete,
}: {
  delivery: Delivery;
  driverName?: string;
  isMultiSelectMode: boolean;
  isSelected: boolean;
  isActiveRow: boolean;
  onToggleSelect: () => void;
  onPress: () => void;
  onView: () => void;
  onEdit: () => void;
  onViewQr: () => void;
  onDelete: () => void;
}) {
  const color = statusColor(delivery.status);
  const days = daysToDeliverLabel(delivery);

  return (
    <Pressable style={[styles.tableRow, isActiveRow && styles.tableRowActive]} onPress={isMultiSelectMode ? onToggleSelect : onPress}>
      {isMultiSelectMode ? (
        <View style={[styles.tableCell, COLS.checkbox]}>
          <Text>{isSelected ? '☑' : '☐'}</Text>
        </View>
      ) : null}
      <View style={[styles.tableCell, COLS.status]}>
        <View style={[styles.statusBadge, { backgroundColor: color }]}>
          <Text style={styles.statusBadgeText}>{statusLabel(delivery.status)}</Text>
        </View>
      </View>
      <View style={[styles.tableCell, COLS.order]}>
        <Text style={styles.tableCellText}>{delivery.orderNumber ?? '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.invoice]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {delivery.invoiceNumber}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.customer]}>
        <Text style={styles.tableCellTextBold} numberOfLines={1}>
          {delivery.customerName}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.custNumber]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {delivery.customerNumber ?? '-'}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.address]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {delivery.customerAddress}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.scheduled]}>
        <Text style={styles.tableCellText}>{delivery.scheduledDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}</Text>
      </View>
      <View style={[styles.tableCell, COLS.items]}>
        <Text style={styles.tableCellText}>{delivery.items.length}</Text>
      </View>
      <View style={[styles.tableCell, COLS.daysToDeliver]}>
        <Text style={[styles.tableCellTextBold, { color: days.color }]}>{days.text}</Text>
      </View>
      <View style={[styles.tableCell, COLS.driver]}>
        {delivery.isThirdPartyTransport ? (
          <View style={styles.thirdPartyBadge}>
            <Text style={styles.thirdPartyBadgeText} numberOfLines={1}>
              🚚 {delivery.thirdPartyProviderName ?? 'Third-Party'}
            </Text>
          </View>
        ) : (
          <Text style={styles.tableCellText} numberOfLines={1}>
            {driverName ?? 'Loading...'}
          </Text>
        )}
      </View>
      <View style={[styles.tableCell, COLS.vehicle]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {delivery.vehicleUsed ?? '-'}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.actions, styles.actionsCell]}>
        <Pressable onPress={onView}>
          <Text style={styles.actionIcon}>👁</Text>
        </Pressable>
        <Pressable onPress={onEdit}>
          <Text style={styles.actionIcon}>✎</Text>
        </Pressable>
        {delivery.status === 'delivered' ? (
          <Pressable onPress={onViewQr}>
            <Text style={styles.actionIcon}>▦</Text>
          </Pressable>
        ) : null}
        <Pressable onPress={onDelete}>
          <Text style={[styles.actionIcon, { color: colors.error }]}>🗑</Text>
        </Pressable>
      </View>
    </Pressable>
  );
}

function PreviewRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue} numberOfLines={2}>
        {value}
      </Text>
    </View>
  );
}

function PreviewPanel({
  delivery,
  driverName,
  onClose,
  onEdit,
  onDelete,
}: {
  delivery: Delivery;
  driverName?: string;
  onClose: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <View style={styles.detailPanel}>
      <View style={styles.detailPanelHeader}>
        <View style={styles.detailPanelHeaderText}>
          <Text style={styles.detailPanelTitle}>{delivery.customerName}</Text>
          <Text style={styles.detailPanelSubtitle}>Invoice: {delivery.invoiceNumber}</Text>
        </View>
        <Pressable onPress={onClose}>
          <Text style={styles.closeGlyph}>✕</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.detailPanelContent}>
        <Text style={styles.detailSectionTitle}>Customer Information</Text>
        <PreviewRow label="Name" value={delivery.customerName} />
        <PreviewRow label="Address" value={delivery.customerAddress} />
        {delivery.customerPhone ? <PreviewRow label="Phone" value={delivery.customerPhone} /> : null}

        <View style={styles.sectionSpacer} />
        <Text style={styles.detailSectionTitle}>Delivery Details</Text>
        <PreviewRow label="Scheduled" value={delivery.scheduledDate.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' })} />
        <PreviewRow label="Created" value={delivery.createdAt.toLocaleString()} />
        {delivery.deliveredAt ? <PreviewRow label="Delivered" value={delivery.deliveredAt.toLocaleString()} /> : null}

        {!delivery.isThirdPartyTransport ? (
          <>
            <View style={styles.sectionSpacer} />
            <Text style={styles.detailSectionTitle}>Driver</Text>
            <PreviewRow label="Name" value={driverName ?? 'Loading...'} />
          </>
        ) : (
          <>
            <View style={styles.sectionSpacer} />
            <View style={styles.thirdPartyBox}>
              <Text style={styles.thirdPartyBoxTitle}>🚚 Third-Party Transport</Text>
              <PreviewRow label="Provider" value={delivery.thirdPartyProviderName ?? 'N/A'} />
              {delivery.thirdPartyDriverName ? <PreviewRow label="Driver" value={delivery.thirdPartyDriverName} /> : null}
              {delivery.uploadToken ? <Text style={styles.uploadLinkText}>podsafe.app/upload/{delivery.uploadToken}</Text> : null}
              {delivery.thirdPartyDocs && delivery.thirdPartyDocs.length > 0 ? (
                <>
                  <Text style={styles.docsUploadedText}>✓ Docs Uploaded ({delivery.thirdPartyDocs.length})</Text>
                  <View style={styles.thirdPartyDocsRow}>
                    {delivery.thirdPartyDocs.slice(0, 3).map((url) => (
                      <Image key={url} source={{ uri: url }} style={styles.thirdPartyDocThumb} resizeMode="cover" />
                    ))}
                  </View>
                </>
              ) : null}
            </View>
          </>
        )}

        <View style={styles.sectionSpacer} />
        <Pressable style={styles.modalOutlinedButton} onPress={onEdit}>
          <Text style={styles.modalOutlinedText}>✎ Edit Delivery</Text>
        </Pressable>
        <Pressable style={[styles.modalOutlinedButton, styles.deleteButton]} onPress={onDelete}>
          <Text style={styles.deleteButtonText}>🗑 Delete Delivery</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

function AssignDriverModal({
  visible,
  companyId,
  onClose,
  onAssign,
}: {
  visible: boolean;
  companyId: string;
  onClose: () => void;
  onAssign: (driverId: string, driverName: string) => void;
}) {
  const [drivers, setDrivers] = useState<{ id: string; name: string }[]>([]);

  useEffect(() => {
    if (!visible) return;
    firestore()
      .collection('users')
      .where('companyId', '==', companyId)
      .where('role', '==', 'driver')
      .where('isActive', '==', true)
      .get()
      .then((snapshot) => setDrivers(snapshot.docs.map((doc) => ({ id: doc.id, name: userFromFirestore(doc).fullName || 'Unknown' }))));
  }, [visible, companyId]);

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.formModalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Assign Driver</Text>
          {drivers.length === 0 ? (
            <Text style={styles.modalHint}>No active drivers available</Text>
          ) : (
            <FlatList
              style={styles.pickerList}
              data={drivers}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <Pressable style={styles.pickerRow} onPress={() => onAssign(item.id, item.name)}>
                  <Text style={styles.pickerRowLabel}>{item.name}</Text>
                </Pressable>
              )}
            />
          )}
          <Pressable style={styles.modalSecondaryButton} onPress={onClose}>
            <Text style={styles.modalSecondaryText}>Cancel</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

function BulkStatusModal({ visible, onClose, onApply }: { visible: boolean; onClose: () => void; onApply: (status: DeliveryStatus) => void }) {
  const statuses: DeliveryStatus[] = ['pending', 'inTransit', 'delivered', 'failed'];
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.formModalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Update Status</Text>
          {statuses.map((status) => (
            <Pressable key={status} style={styles.pickerRow} onPress={() => onApply(status)}>
              <Text style={[styles.pickerRowLabel, { color: statusColor(status) }]}>{statusLabel(status)}</Text>
            </Pressable>
          ))}
          <Pressable style={styles.modalSecondaryButton} onPress={onClose}>
            <Text style={styles.modalSecondaryText}>Cancel</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyIcon: { fontSize: 56, opacity: 0.3, marginBottom: spacing.medium },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.medium, paddingVertical: spacing.medium },
  headerBarLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.small + 4 },
  desktopBadge: { color: colors.white, fontSize: 11, fontWeight: '700', opacity: 0.8, borderWidth: 1, borderColor: colors.white, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 },
  headerBarRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  headerBarAction: { color: colors.white, fontSize: 18 },
  headerBarButton: { backgroundColor: colors.white, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small },
  headerBarButtonText: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 280, borderRightWidth: 1, borderRightColor: colors.divider, backgroundColor: colors.card },
  sidebarContent: { padding: spacing.medium },
  sidebarHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  sidebarTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary },
  sidebarClear: { color: colors.primary, fontWeight: '600' },
  sidebarLabel: { fontWeight: '600', color: colors.textSecondary, marginBottom: spacing.small, fontSize: 12 },
  sidebarSectionSpacer: { marginTop: spacing.large },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  filterOption: { paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small + 4, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, marginBottom: spacing.small },
  filterOptionSelected: { backgroundColor: `${colors.primary}1A`, borderColor: colors.primary },
  filterOptionLabel: { fontSize: 13, color: colors.textPrimary },
  filterOptionLabelSelected: { color: colors.primary, fontWeight: '600' },
  modalOutlinedButton: { alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedText: { color: colors.textPrimary, fontWeight: '600' },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: 20, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 12, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  mainArea: { flex: 1 },
  statsBar: { flexDirection: 'row', gap: spacing.small + 4, padding: spacing.medium },
  statCard: { flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.small + 4 },
  statIconBox: { width: 36, height: 36, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small },
  statIcon: { fontSize: 16 },
  statValue: { fontSize: 18, fontWeight: 'bold', color: colors.textPrimary },
  statLabel: { fontSize: 11, color: colors.textSecondary },
  bulkBar: { flexDirection: 'row', alignItems: 'center', gap: spacing.large, backgroundColor: `${colors.primary}14`, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, marginHorizontal: spacing.medium, borderRadius: radii.borderRadius },
  bulkBarText: { flex: 1, fontWeight: '700', color: colors.textPrimary },
  bulkBarAction: { fontWeight: '600', color: colors.primary },
  contentRow: { flex: 1, flexDirection: 'row' },
  tableSection: { flex: 1, margin: spacing.medium, backgroundColor: colors.card, borderRadius: radii.cardRadius, overflow: 'hidden' },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.background, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableHeaderCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small + 4, justifyContent: 'center' },
  tableHeaderText: { fontSize: 12, fontWeight: '700', color: colors.textSecondary },
  tableBody: { flex: 1 },
  tableRow: { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: colors.divider, minHeight: 56 },
  tableRowActive: { backgroundColor: `${colors.primary}0F` },
  tableCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small, justifyContent: 'center' },
  tableCellText: { fontSize: 13, color: colors.textPrimary },
  tableCellTextBold: { fontSize: 13, fontWeight: '700', color: colors.textPrimary },
  statusBadge: { alignSelf: 'flex-start', borderRadius: 12, paddingHorizontal: spacing.small, paddingVertical: 3 },
  statusBadgeText: { color: colors.white, fontSize: 11, fontWeight: 'bold' },
  thirdPartyBadge: { backgroundColor: `${colors.warning}1A`, borderWidth: 1, borderColor: `${colors.warning}66`, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2, alignSelf: 'flex-start' },
  thirdPartyBadgeText: { color: colors.warning, fontWeight: '700', fontSize: 11 },
  actionsCell: { flexDirection: 'row', gap: spacing.small + 4 },
  actionIcon: { fontSize: 16, color: colors.textPrimary },
  detailPanel: { width: 400, borderLeftWidth: 1, borderLeftColor: colors.divider, backgroundColor: colors.card },
  detailPanelHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', padding: spacing.medium, borderBottomWidth: 1, borderBottomColor: colors.divider },
  detailPanelHeaderText: { flex: 1 },
  detailPanelTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary },
  detailPanelSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  detailPanelContent: { padding: spacing.large },
  detailSectionTitle: { fontWeight: '700', fontSize: 14, color: colors.textPrimary, marginBottom: spacing.small },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4, gap: spacing.medium },
  detailLabel: { color: colors.textSecondary },
  detailValue: { fontWeight: '600', color: colors.textPrimary, flex: 1, textAlign: 'right' },
  sectionSpacer: { height: spacing.medium },
  thirdPartyBox: { backgroundColor: `${colors.warning}0D`, borderWidth: 1, borderColor: `${colors.warning}4D`, borderRadius: radii.borderRadius, padding: spacing.small + 4 },
  thirdPartyBoxTitle: { fontWeight: '700', color: colors.warning, marginBottom: spacing.small },
  uploadLinkText: { fontFamily: 'monospace', fontSize: 11, color: colors.info, marginTop: spacing.small },
  docsUploadedText: { fontSize: 12, fontWeight: '600', color: colors.success, marginTop: spacing.small },
  thirdPartyDocsRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.small },
  thirdPartyDocThumb: { width: 56, height: 56, borderRadius: 4, borderWidth: 1, borderColor: colors.divider },
  deleteButton: { borderColor: colors.error },
  deleteButtonText: { color: colors.error, fontWeight: '600' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  formModalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600', color: colors.textPrimary },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 380, maxHeight: '80%' },
  modalHint: { color: colors.textSecondary, marginTop: spacing.medium },
  fieldLabel: { fontWeight: '600', fontSize: 13, marginTop: spacing.medium, marginBottom: spacing.small },
  dateInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalPrimaryButton: { flex: 1, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  modalSecondaryButton: { alignItems: 'center', paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius, borderWidth: 1, borderColor: colors.divider, marginTop: spacing.medium },
  modalSecondaryText: { color: colors.textSecondary, fontWeight: '600' },
  pickerList: { maxHeight: 320, marginTop: spacing.medium },
  pickerRow: { paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  pickerRowLabel: { fontSize: 14, color: colors.textPrimary },
});
