import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, Image, Modal, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { Asset, launchImageLibrary } from 'react-native-image-picker';
import { useAuthStore } from '../../stores/useAuthStore';
import { useVehicleStore } from '../../stores/useVehicleStore';
import { Vehicle, VehicleStatus } from '../../models/vehicle';
import { Delivery } from '../../models/delivery';
import { deliveryFromFirestore } from '../../models/delivery.converters';
import { userFromFirestore } from '../../models/user.converters';
import { normalizeRegistration } from '../../utils/vehicleUtils';
import { getStartOfTodaySA, getEndOfTodaySA } from '../../utils/datetimeHelper';
import { exportVehicles, formatDate } from '../../repositories/csvExportService';
import FirebaseStorageImage from '../../components/FirebaseStorageImage';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/vehicle_management_desktop.dart (verified against source on
 * 2026-06-23). Companion route is VehicleManagement.tsx (mobile) — an explicit-choice pair
 * (two distinct routes, caller picks explicitly, no auto-switch breakpoint; see vault
 * Inventory note). No nav entry point wires to this route yet — Phase 4's desktop nav shell
 * doesn't exist; AdminStack registers the route so it's reachable once that shell lands.
 *
 * Deviations from the Flutter source:
 * - PopupMenuButton per row + the desktop's own AlertDialogs become a bottom-sheet Modal
 *   action list (house convention, same as DriverDetails.tsx — see its header comment).
 * - The data table is a custom `View`-based scrollable table, not a new grid/table library
 *   (none installed; this is the first desktop table in the port, no precedent existed yet).
 * - Keyboard shortcuts (Ctrl+F search focus, Ctrl+A select-all, Esc clear selection, F5
 *   refresh) are dropped — RN has no hardware-keyboard listener without a new native module,
 *   and this is a convenience layer over buttons that already exist on screen. Same kind of
 *   deliberate scope-trim as CreateDelivery.tsx's Wizard-mode-only note.
 * - `_exportToCsv()` in the Dart source builds a CSV string that is never written to disk or
 *   shared anywhere (dead code — confirmed by direct read; see vault Risk Register). This
 *   port wires the Export CSV button for real, via the new `exportVehicles()` helper in
 *   csvExportService.ts.
 * - `_bulkActivateVehicles()`/`_bulkMaintenanceVehicles()`/`_bulkDeactivateVehicles()` are
 *   empty in the Dart source — the bulk-action buttons are wired but do nothing. Ported
 *   faithfully as no-ops (same precedent as other pre-existing, documented Dart bugs in the
 *   Risk Register) rather than inventing new bulk-write behavior that was never specified.
 * - The Dart source's "Add Vehicle" dialog renders its own "Uploaded Photos:" preview block
 *   twice (verbatim duplicate, confirmed by direct read) — this port renders it once.
 * - Per-photo upload retry UI is simplified the same way as VehicleManagement.tsx (mobile):
 *   one aggregate "Uploading photo X of Y..." status line instead of a per-file retry button.
 */
const MAX_PHOTOS = 2;
type StatusFilter = 'all' | VehicleStatus;
type SortField = 'registration' | 'status' | 'deliveries' | 'lastUsed';

const COLS = {
  checkbox: { width: 36 },
  registration: { width: 110 },
  makeModel: { width: 150 },
  plate: { width: 100 },
  status: { width: 110 },
  deliveries: { width: 90 },
  assignedToday: { width: 200 },
  lastUsed: { width: 110 },
  actions: { width: 50 },
};
const TABLE_WIDTH = Object.values(COLS).reduce((sum, c) => sum + c.width, 0);

function statusColor(status: VehicleStatus): string {
  switch (status) {
    case 'active':
      return colors.success;
    case 'maintenance':
      return colors.warning;
    case 'inactive':
      return colors.textSecondary;
  }
}

function statusLabel(status: VehicleStatus): string {
  switch (status) {
    case 'active':
      return 'Active';
    case 'maintenance':
      return 'Maintenance';
    case 'inactive':
      return 'Inactive';
  }
}

/** Mirrors _isImageUrl(): path-extension check with a raw-string fallback if URL parsing fails. */
function isImageUrl(url: string): boolean {
  let path = url;
  try {
    path = new URL(url).pathname;
  } catch {
    // fall through to raw-string match below
  }
  return /\.(png|jpe?g|gif|webp)$/i.test(path) || /\.(png|jpe?g|gif|webp)/i.test(url.toLowerCase());
}

export default function VehicleManagementDesktop() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const vehicles = useVehicleStore((s) => s.vehicles);
  const isLoading = useVehicleStore((s) => s.isLoading);
  const subscribeForCompany = useVehicleStore((s) => s.subscribeForCompany);
  const deleteVehicle = useVehicleStore((s) => s.deleteVehicle);
  const updateVehicleAction = useVehicleStore((s) => s.updateVehicle);

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<StatusFilter>('all');
  const [sortBy, setSortBy] = useState<SortField>('registration');
  const [sortAscending, setSortAscending] = useState(true);
  const [showFilters, setShowFilters] = useState(false);
  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [selectedVehicle, setSelectedVehicle] = useState<Vehicle | null>(null);
  const [actionSheetVehicle, setActionSheetVehicle] = useState<Vehicle | null>(null);
  const [formVehicle, setFormVehicle] = useState<Vehicle | null | undefined>(undefined);
  const [todaysDeliveriesByVehicle, setTodaysDeliveriesByVehicle] = useState<Record<string, Delivery[]>>({});
  const [driverNamesById, setDriverNamesById] = useState<Record<string, string>>({});

  useEffect(() => {
    if (currentUser) {
      subscribeForCompany(currentUser.companyId);
    }
  }, [currentUser, subscribeForCompany]);

  useEffect(() => {
    if (!currentUser) return;
    const start = getStartOfTodaySA();
    const end = getEndOfTodaySA();
    const unsubscribe = firestore()
      .collection('deliveries')
      .where('companyId', '==', currentUser.companyId)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(start))
      .where('scheduledDate', '<=', firestore.Timestamp.fromDate(end))
      .onSnapshot(async (snapshot) => {
        const deliveries = snapshot.docs.map(deliveryFromFirestore);
        const byVehicle: Record<string, Delivery[]> = {};
        const driverIds = new Set<string>();
        for (const delivery of deliveries) {
          if (!delivery.vehicleUsed) continue;
          driverIds.add(delivery.driverId);
          const normalized = normalizeRegistration(delivery.vehicleUsed);
          if (!byVehicle[normalized]) byVehicle[normalized] = [];
          byVehicle[normalized].push(delivery);
          if (!byVehicle[delivery.vehicleUsed]) byVehicle[delivery.vehicleUsed] = [];
          byVehicle[delivery.vehicleUsed].push(delivery);
        }
        setTodaysDeliveriesByVehicle(byVehicle);

        const idsArray = [...driverIds];
        const namesMap: Record<string, string> = {};
        for (let i = 0; i < idsArray.length; i += 10) {
          const chunk = idsArray.slice(i, i + 10);
          if (chunk.length === 0) continue;
          const usersSnap = await firestore().collection('users').where(firestore.FieldPath.documentId(), 'in', chunk).get();
          usersSnap.docs.forEach((doc) => {
            namesMap[doc.id] = userFromFirestore(doc).fullName || 'Unknown';
          });
        }
        setDriverNamesById(namesMap);
      });
    return unsubscribe;
  }, [currentUser]);

  const getAssignedToday = (vehicle: Vehicle): Delivery[] =>
    todaysDeliveriesByVehicle[normalizeRegistration(vehicle.registration)] ?? todaysDeliveriesByVehicle[vehicle.registration] ?? [];

  const filteredSortedVehicles = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    let result = vehicles.filter((v) => {
      if (selectedStatus !== 'all' && v.status !== selectedStatus) return false;
      if (query.length > 0) {
        const haystack = `${v.registration} ${v.make ?? ''} ${v.model ?? ''} ${v.licensePlate ?? ''}`.toLowerCase();
        if (!haystack.includes(query)) return false;
      }
      return true;
    });
    result = [...result].sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case 'registration':
          cmp = a.registration.localeCompare(b.registration);
          break;
        case 'status':
          cmp = a.status.localeCompare(b.status);
          break;
        case 'deliveries':
          cmp = a.totalDeliveries - b.totalDeliveries;
          break;
        case 'lastUsed':
          cmp = (a.lastUsedAt?.getTime() ?? 0) - (b.lastUsedAt?.getTime() ?? 0);
          break;
      }
      return sortAscending ? cmp : -cmp;
    });
    return result;
  }, [vehicles, selectedStatus, searchQuery, sortBy, sortAscending]);

  const stats = useMemo(() => {
    const total = vehicles.length;
    const active = vehicles.filter((v) => v.status === 'active').length;
    const maintenance = vehicles.filter((v) => v.status === 'maintenance').length;
    const inactive = vehicles.filter((v) => v.status === 'inactive').length;
    const utilization = total > 0 ? Math.round((active / total) * 100) : 0;
    return { total, active, maintenance, inactive, utilization };
  }, [vehicles]);

  const allFilteredSelected = filteredSortedVehicles.length > 0 && filteredSortedVehicles.every((v) => selectedIds.has(v.id));

  const toggleOrSetSort = (field: SortField) => {
    if (sortBy === field) {
      setSortAscending((prev) => !prev);
    } else {
      setSortBy(field);
      setSortAscending(true);
    }
  };

  const toggleSelectAll = () => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (allFilteredSelected) {
        filteredSortedVehicles.forEach((v) => next.delete(v.id));
      } else {
        filteredSortedVehicles.forEach((v) => next.add(v.id));
      }
      return next;
    });
  };

  const toggleSelectOne = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const clearFilters = () => {
    setSearchQuery('');
    setSelectedStatus('all');
    setSortBy('registration');
    setSortAscending(true);
  };

  const handleDeleteVehicle = (vehicle: Vehicle) => {
    Alert.alert('Delete Vehicle', `Are you sure you want to delete ${vehicle.registration}? This action cannot be undone.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteVehicle(vehicle.id);
            setSelectedVehicle((prev) => (prev?.id === vehicle.id ? null : prev));
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  const handleToggleStatus = async (vehicle: Vehicle) => {
    const newStatus: VehicleStatus = vehicle.status === 'active' ? 'maintenance' : 'active';
    try {
      await updateVehicleAction(vehicle, {
        registration: vehicle.registration,
        make: vehicle.make,
        model: vehicle.model,
        color: vehicle.color,
        licensePlate: vehicle.licensePlate,
        status: newStatus,
        notes: vehicle.notes,
      });
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    }
  };

  const handleExportCsv = async () => {
    try {
      await exportVehicles(vehicles);
    } catch (e) {
      Alert.alert('Error', `Failed to export: ${(e as Error).message}`);
    }
  };

  // Faithful port of vehicle_management_desktop.dart's _bulkActivateVehicles/_bulkMaintenanceVehicles/
  // _bulkDeactivateVehicles — all three are empty in the Dart source (confirmed by direct read); the
  // buttons are wired but do nothing. See vault Risk Register for this pre-existing Dart bug.
  const bulkActivateVehicles = () => {};
  const bulkMaintenanceVehicles = () => {};
  const bulkDeactivateVehicles = () => {};

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Error: No company ID</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={[textStyles.heading3, { color: colors.onPrimary }]}>Vehicle Management</Text>
        <Text style={styles.desktopBadge}>Desktop</Text>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => setIsMultiSelectMode((p) => !p)}>
            <Text style={styles.headerBarAction}>{isMultiSelectMode ? '☑' : '☐'}</Text>
          </Pressable>
          <Pressable onPress={() => setShowFilters((p) => !p)}>
            <Text style={styles.headerBarAction}>🔍</Text>
          </Pressable>
          <Pressable onPress={() => setFormVehicle(null)}>
            <Text style={styles.headerBarAction}>＋</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.body}>
        {showFilters ? (
          <FilterSidebar
            searchQuery={searchQuery}
            onSearchChange={setSearchQuery}
            selectedStatus={selectedStatus}
            onStatusChange={setSelectedStatus}
            sortBy={sortBy}
            onSortByChange={setSortBy}
            sortAscending={sortAscending}
            onSortAscendingChange={setSortAscending}
            onClear={clearFilters}
          />
        ) : null}

        <View style={styles.mainArea}>
          <View style={styles.statsBar}>
            <MiniStat label="Total" value={stats.total} icon="🚙" color={colors.primary} />
            <MiniStat label="Active" value={stats.active} icon="✓" color={colors.success} />
            <MiniStat label="Maintenance" value={stats.maintenance} icon="🔧" color={colors.warning} />
            <MiniStat label="Inactive" value={stats.inactive} icon="⏸" color={colors.textSecondary} />
            <MiniStat label="Utilization" value={`${stats.utilization}%`} icon="📊" color={colors.info} />
            <Pressable style={styles.exportButton} onPress={handleExportCsv}>
              <Text style={styles.exportButtonText}>⬇ Export CSV</Text>
            </Pressable>
          </View>

          {isMultiSelectMode && selectedIds.size > 0 ? (
            <View style={styles.bulkBar}>
              <Text style={styles.bulkBarText}>{selectedIds.size} vehicle(s) selected</Text>
              <Pressable onPress={bulkActivateVehicles}>
                <Text style={styles.bulkBarAction}>Activate</Text>
              </Pressable>
              <Pressable onPress={bulkMaintenanceVehicles}>
                <Text style={styles.bulkBarAction}>Maintenance</Text>
              </Pressable>
              <Pressable onPress={bulkDeactivateVehicles}>
                <Text style={[styles.bulkBarAction, { color: colors.error }]}>Deactivate</Text>
              </Pressable>
              <Pressable onPress={() => setSelectedIds(new Set())}>
                <Text style={styles.bulkBarAction}>Clear</Text>
              </Pressable>
            </View>
          ) : null}

          <View style={styles.tableSection}>
            {isLoading && vehicles.length === 0 ? (
              <ActivityIndicator color={colors.primary} style={styles.loadingIndicator} />
            ) : filteredSortedVehicles.length === 0 ? (
              <View style={styles.centered}>
                <Text style={styles.emptyIcon}>🚙</Text>
                <Text style={textStyles.bodyMedium}>No vehicles found</Text>
              </View>
            ) : (
              <ScrollView horizontal>
                <View style={{ minWidth: TABLE_WIDTH }}>
                  <View style={styles.tableHeaderRow}>
                    {isMultiSelectMode ? (
                      <Pressable style={[styles.tableHeaderCell, COLS.checkbox]} onPress={toggleSelectAll}>
                        <Text style={styles.tableHeaderText}>{allFilteredSelected ? '☑' : '☐'}</Text>
                      </Pressable>
                    ) : null}
                    <SortableHeader label="Registration" field="registration" width={COLS.registration.width} sortBy={sortBy} sortAscending={sortAscending} onPress={toggleOrSetSort} />
                    <View style={[styles.tableHeaderCell, COLS.makeModel]}>
                      <Text style={styles.tableHeaderText}>Make / Model</Text>
                    </View>
                    <View style={[styles.tableHeaderCell, COLS.plate]}>
                      <Text style={styles.tableHeaderText}>Plate</Text>
                    </View>
                    <SortableHeader label="Status" field="status" width={COLS.status.width} sortBy={sortBy} sortAscending={sortAscending} onPress={toggleOrSetSort} />
                    <SortableHeader label="Deliveries" field="deliveries" width={COLS.deliveries.width} sortBy={sortBy} sortAscending={sortAscending} onPress={toggleOrSetSort} />
                    <View style={[styles.tableHeaderCell, COLS.assignedToday]}>
                      <Text style={styles.tableHeaderText}>Assigned Today</Text>
                    </View>
                    <SortableHeader label="Last Used" field="lastUsed" width={COLS.lastUsed.width} sortBy={sortBy} sortAscending={sortAscending} onPress={toggleOrSetSort} />
                    <View style={[styles.tableHeaderCell, COLS.actions]}>
                      <Text style={styles.tableHeaderText}>Actions</Text>
                    </View>
                  </View>
                  <ScrollView style={styles.tableBody}>
                    {filteredSortedVehicles.map((vehicle) => (
                      <VehicleRow
                        key={vehicle.id}
                        vehicle={vehicle}
                        isMultiSelectMode={isMultiSelectMode}
                        isSelected={selectedIds.has(vehicle.id)}
                        isActiveRow={selectedVehicle?.id === vehicle.id}
                        assignedToday={getAssignedToday(vehicle)}
                        driverNamesById={driverNamesById}
                        onToggleSelect={() => toggleSelectOne(vehicle.id)}
                        onPress={() => setSelectedVehicle(vehicle)}
                        onOpenActions={() => setActionSheetVehicle(vehicle)}
                      />
                    ))}
                  </ScrollView>
                </View>
              </ScrollView>
            )}
          </View>
        </View>

        {selectedVehicle ? (
          <DetailPanel
            vehicle={selectedVehicle}
            assignedToday={getAssignedToday(selectedVehicle)}
            driverNamesById={driverNamesById}
            onClose={() => setSelectedVehicle(null)}
            onEdit={() => {
              setFormVehicle(selectedVehicle);
              setSelectedVehicle(null);
            }}
            onToggleStatus={() => handleToggleStatus(selectedVehicle)}
            onDelete={() => handleDeleteVehicle(selectedVehicle)}
          />
        ) : null}
      </View>

      <Modal visible={actionSheetVehicle != null} transparent animationType="fade" onRequestClose={() => setActionSheetVehicle(null)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setActionSheetVehicle(null)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <ActionRow
              icon="👁"
              label="View Details"
              color={colors.textPrimary}
              onPress={() => {
                setSelectedVehicle(actionSheetVehicle);
                setActionSheetVehicle(null);
              }}
            />
            <ActionRow
              icon="✎"
              label="Edit"
              color={colors.textPrimary}
              onPress={() => {
                setFormVehicle(actionSheetVehicle);
                setActionSheetVehicle(null);
              }}
            />
            <ActionRow
              icon={actionSheetVehicle?.status === 'active' ? '🔧' : '✓'}
              label={actionSheetVehicle?.status === 'active' ? 'Send to Maintenance' : 'Activate'}
              color={actionSheetVehicle?.status === 'active' ? colors.warning : colors.success}
              onPress={() => {
                const vehicle = actionSheetVehicle;
                setActionSheetVehicle(null);
                if (vehicle) handleToggleStatus(vehicle);
              }}
            />
            <View style={styles.actionSheetDivider} />
            <ActionRow
              icon="🗑"
              label="Delete"
              color={colors.error}
              onPress={() => {
                const vehicle = actionSheetVehicle;
                setActionSheetVehicle(null);
                if (vehicle) handleDeleteVehicle(vehicle);
              }}
            />
          </View>
        </Pressable>
      </Modal>

      {formVehicle !== undefined ? <VehicleFormModal vehicle={formVehicle} onClose={() => setFormVehicle(undefined)} /> : null}
    </View>
  );
}

function MiniStat({ label, value, icon, color }: { label: string; value: number | string; icon: string; color: string }) {
  return (
    <View style={[styles.statCard, shadows.card]}>
      <Text style={[styles.statIcon, { color }]}>{icon}</Text>
      <Text style={[styles.statValue, { color }]}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function SortableHeader({
  label,
  field,
  width,
  sortBy,
  sortAscending,
  onPress,
}: {
  label: string;
  field: SortField;
  width: number;
  sortBy: SortField;
  sortAscending: boolean;
  onPress: (field: SortField) => void;
}) {
  const isActive = sortBy === field;
  return (
    <Pressable style={[styles.tableHeaderCell, { width }]} onPress={() => onPress(field)}>
      <Text style={styles.tableHeaderText}>
        {label}
        {isActive ? (sortAscending ? ' ▲' : ' ▼') : ''}
      </Text>
    </Pressable>
  );
}

function AssignedTodayChip({ deliveries, driverNamesById }: { deliveries: Delivery[]; driverNamesById: Record<string, string> }) {
  if (deliveries.length === 0) {
    return (
      <View style={[styles.statusBadge, { backgroundColor: `${colors.success}1A` }]}>
        <Text style={[styles.statusBadgeText, { color: colors.success }]}>Available</Text>
      </View>
    );
  }
  const driverIds = [...new Set(deliveries.map((d) => d.driverId))];
  if (driverIds.length === 1) {
    const name = driverNamesById[driverIds[0]] ?? 'Unknown';
    return (
      <View style={[styles.statusBadge, { backgroundColor: `${colors.error}1A` }]}>
        <Text style={[styles.statusBadgeText, { color: colors.error }]} numberOfLines={1}>
          Unavailable • {name} ({deliveries.length})
        </Text>
      </View>
    );
  }
  const names = driverIds.map((id) => driverNamesById[id] ?? 'Unknown').join(', ');
  return (
    <View style={[styles.statusBadge, { backgroundColor: `${colors.warning}1A` }]}>
      <Text style={[styles.statusBadgeText, { color: colors.warning }]} numberOfLines={1}>
        Conflict ({deliveries.length}) • {names}
      </Text>
    </View>
  );
}

function VehicleRow({
  vehicle,
  isMultiSelectMode,
  isSelected,
  isActiveRow,
  assignedToday,
  driverNamesById,
  onToggleSelect,
  onPress,
  onOpenActions,
}: {
  vehicle: Vehicle;
  isMultiSelectMode: boolean;
  isSelected: boolean;
  isActiveRow: boolean;
  assignedToday: Delivery[];
  driverNamesById: Record<string, string>;
  onToggleSelect: () => void;
  onPress: () => void;
  onOpenActions: () => void;
}) {
  return (
    <Pressable style={[styles.tableRow, isActiveRow && styles.tableRowActive]} onPress={isMultiSelectMode ? onToggleSelect : onPress}>
      {isMultiSelectMode ? (
        <View style={[styles.tableCell, COLS.checkbox]}>
          <Text>{isSelected ? '☑' : '☐'}</Text>
        </View>
      ) : null}
      <View style={[styles.tableCell, COLS.registration]}>
        <Text style={styles.tableCellTextBold}>{vehicle.registration}</Text>
      </View>
      <View style={[styles.tableCell, COLS.makeModel]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {[vehicle.make, vehicle.model].filter(Boolean).join(' ') || '-'}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.plate]}>
        <Text style={styles.tableCellText}>{vehicle.licensePlate || '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.status]}>
        <View style={[styles.statusBadge, { backgroundColor: `${statusColor(vehicle.status)}1A` }]}>
          <Text style={[styles.statusBadgeText, { color: statusColor(vehicle.status) }]}>{statusLabel(vehicle.status)}</Text>
        </View>
      </View>
      <View style={[styles.tableCell, COLS.deliveries]}>
        <Text style={styles.tableCellText}>{vehicle.totalDeliveries}</Text>
      </View>
      <View style={[styles.tableCell, COLS.assignedToday]}>
        <AssignedTodayChip deliveries={assignedToday} driverNamesById={driverNamesById} />
      </View>
      <View style={[styles.tableCell, COLS.lastUsed]}>
        <Text style={styles.tableCellText}>{vehicle.lastUsedAt ? formatDate(vehicle.lastUsedAt) : 'Never'}</Text>
      </View>
      <Pressable style={[styles.tableCell, COLS.actions]} onPress={onOpenActions}>
        <Text style={styles.tableActionsGlyph}>⋮</Text>
      </Pressable>
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

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function SortOption({ label, field, sortBy, onPress }: { label: string; field: SortField; sortBy: SortField; onPress: (field: SortField) => void }) {
  const selected = sortBy === field;
  return (
    <Pressable style={styles.sortOptionRow} onPress={() => onPress(field)}>
      <Text style={styles.sortOptionGlyph}>{selected ? '◉' : '○'}</Text>
      <Text style={styles.sortOptionLabel}>{label}</Text>
    </Pressable>
  );
}

function FilterSidebar({
  searchQuery,
  onSearchChange,
  selectedStatus,
  onStatusChange,
  sortBy,
  onSortByChange,
  sortAscending,
  onSortAscendingChange,
  onClear,
}: {
  searchQuery: string;
  onSearchChange: (value: string) => void;
  selectedStatus: StatusFilter;
  onStatusChange: (value: StatusFilter) => void;
  sortBy: SortField;
  onSortByChange: (value: SortField) => void;
  sortAscending: boolean;
  onSortAscendingChange: (value: boolean) => void;
  onClear: () => void;
}) {
  return (
    <View style={styles.sidebar}>
      <ScrollView contentContainerStyle={styles.sidebarContent}>
        <Text style={styles.sidebarLabel}>Search</Text>
        <TextInput style={styles.input} placeholder="Registration, make, model, plate..." value={searchQuery} onChangeText={onSearchChange} />

        <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Status</Text>
        <View style={styles.chipWrap}>
          <Chip label="All" selected={selectedStatus === 'all'} onPress={() => onStatusChange('all')} />
          <Chip label="Active" selected={selectedStatus === 'active'} onPress={() => onStatusChange('active')} />
          <Chip label="Maintenance" selected={selectedStatus === 'maintenance'} onPress={() => onStatusChange('maintenance')} />
          <Chip label="Inactive" selected={selectedStatus === 'inactive'} onPress={() => onStatusChange('inactive')} />
        </View>

        <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Sort By</Text>
        <SortOption label="Registration" field="registration" sortBy={sortBy} onPress={onSortByChange} />
        <SortOption label="Status" field="status" sortBy={sortBy} onPress={onSortByChange} />
        <SortOption label="Deliveries" field="deliveries" sortBy={sortBy} onPress={onSortByChange} />
        <SortOption label="Last Used" field="lastUsed" sortBy={sortBy} onPress={onSortByChange} />

        <View style={styles.switchRow}>
          <Text style={styles.settingTitle}>Ascending</Text>
          <Switch value={sortAscending} onValueChange={onSortAscendingChange} trackColor={{ true: colors.primary, false: colors.divider }} />
        </View>

        <Pressable style={[styles.modalOutlinedButton, styles.clearFiltersButton]} onPress={onClear}>
          <Text style={styles.modalOutlinedText}>Clear Filters</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={[textStyles.bodyMedium, styles.detailValue]}>{value}</Text>
    </View>
  );
}

function DetailPanel({
  vehicle,
  assignedToday,
  driverNamesById,
  onClose,
  onEdit,
  onToggleStatus,
  onDelete,
}: {
  vehicle: Vehicle;
  assignedToday: Delivery[];
  driverNamesById: Record<string, string>;
  onClose: () => void;
  onEdit: () => void;
  onToggleStatus: () => void;
  onDelete: () => void;
}) {
  const documents = vehicle.documents ?? [];
  return (
    <View style={styles.detailPanel}>
      <ScrollView contentContainerStyle={styles.detailPanelContent}>
        <View style={styles.sheetHeaderRow}>
          <Text style={textStyles.heading3}>{vehicle.registration}</Text>
          <Pressable onPress={onClose}>
            <Text style={styles.closeGlyph}>✕</Text>
          </Pressable>
        </View>
        <View style={[styles.statusBadge, styles.detailStatusBadge, { backgroundColor: `${statusColor(vehicle.status)}1A` }]}>
          <Text style={[styles.statusBadgeText, { color: statusColor(vehicle.status) }]}>{statusLabel(vehicle.status)}</Text>
        </View>
        <View style={styles.divider} />

        <Text style={styles.sidebarLabel}>Assigned Today</Text>
        <View style={styles.sectionSpacerSmall} />
        <AssignedTodayChip deliveries={assignedToday} driverNamesById={driverNamesById} />
        <View style={styles.sectionSpacer} />

        <DetailRow label="Make" value={vehicle.make || 'Not specified'} />
        <DetailRow label="Model" value={vehicle.model || 'Not specified'} />
        <DetailRow label="Color" value={vehicle.color || 'Not specified'} />
        <DetailRow label="License Plate" value={vehicle.licensePlate || 'Not specified'} />
        <DetailRow label="Total Deliveries" value={String(vehicle.totalDeliveries)} />
        <DetailRow label="Last Used" value={vehicle.lastUsedAt ? vehicle.lastUsedAt.toLocaleString() : 'Never'} />
        {vehicle.notes ? <DetailRow label="Notes" value={vehicle.notes} /> : null}

        {documents.length > 0 ? (
          <>
            <View style={styles.sectionSpacer} />
            <Text style={textStyles.heading3}>Photos</Text>
            <View style={styles.photoGrid}>
              {documents.map((url) => (
                <View key={url} style={styles.photoThumb}>
                  {isImageUrl(url) ? (
                    <FirebaseStorageImage imageUrl={url} style={styles.photoThumbImage} resizeMode="cover" />
                  ) : (
                    <View style={[styles.photoThumbImage, styles.photoThumbFallback]}>
                      <Text>📄</Text>
                    </View>
                  )}
                </View>
              ))}
            </View>
          </>
        ) : null}

        <View style={styles.sectionSpacer} />
        <Pressable style={styles.modalPrimaryButton} onPress={onEdit}>
          <Text style={textStyles.buttonText}>✎ Edit Vehicle</Text>
        </Pressable>
        <Pressable style={styles.modalOutlinedButton} onPress={onToggleStatus}>
          <Text style={styles.modalOutlinedText}>{vehicle.status === 'active' ? '🔧 Send to Maintenance' : '✓ Activate'}</Text>
        </Pressable>
        <Pressable style={[styles.modalOutlinedButton, styles.deleteButton]} onPress={onDelete}>
          <Text style={styles.deleteButtonText}>🗑 Delete Vehicle</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

function VehicleFormModal({ vehicle, onClose }: { vehicle: Vehicle | null; onClose: () => void }) {
  const createVehicleAction = useVehicleStore((s) => s.createVehicle);
  const updateVehicleAction = useVehicleStore((s) => s.updateVehicle);
  const uploadDocument = useVehicleStore((s) => s.uploadDocument);
  const setDocuments = useVehicleStore((s) => s.setDocuments);
  const appendDocuments = useVehicleStore((s) => s.appendDocuments);

  const [registration, setRegistration] = useState(vehicle?.registration ?? '');
  const [make, setMake] = useState(vehicle?.make ?? '');
  const [model, setModel] = useState(vehicle?.model ?? '');
  const [licensePlate, setLicensePlate] = useState(vehicle?.licensePlate ?? '');
  const [photos, setPhotos] = useState<Asset[]>([]);
  const [isSaving, setIsSaving] = useState(false);
  const [uploadStatus, setUploadStatus] = useState<string | null>(null);

  const pickPhotos = async () => {
    const remaining = MAX_PHOTOS - photos.length;
    if (remaining <= 0) return;
    try {
      const response = await launchImageLibrary({ mediaType: 'photo', selectionLimit: remaining, maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      if (response.didCancel) return;
      setPhotos((prev) => [...prev, ...(response.assets ?? []).slice(0, remaining)]);
    } catch (e) {
      Alert.alert('Error', `Error picking photos: ${(e as Error).message}`);
    }
  };

  const removePhoto = (index: number) => setPhotos((prev) => prev.filter((_, i) => i !== index));

  const handleSave = async () => {
    if (registration.trim().length === 0) {
      Alert.alert('Missing Information', 'Please enter a registration number');
      return;
    }

    setIsSaving(true);
    try {
      const params = {
        registration: normalizeRegistration(registration),
        make: make.trim() || undefined,
        model: model.trim() || undefined,
        color: vehicle?.color,
        licensePlate: licensePlate.trim() || undefined,
        status: vehicle?.status ?? ('active' as VehicleStatus),
        notes: vehicle?.notes,
      };

      let vehicleId: string;
      if (vehicle) {
        await updateVehicleAction(vehicle, params);
        vehicleId = vehicle.id;
      } else {
        vehicleId = await createVehicleAction(params);
      }

      if (photos.length > 0) {
        const urls: string[] = [];
        let failedCount = 0;
        for (let i = 0; i < photos.length; i++) {
          const photo = photos[i];
          if (!photo.uri) continue;
          setUploadStatus(`Uploading photo ${i + 1} of ${photos.length}...`);
          try {
            urls.push(await uploadDocument(vehicleId, photo.uri, photo.fileName ?? `vehicle_photo_${i + 1}.jpg`));
          } catch {
            failedCount += 1;
          }
        }
        setUploadStatus(null);
        if (urls.length > 0) {
          if (vehicle) {
            await appendDocuments(vehicleId, urls);
          } else {
            await setDocuments(vehicleId, urls);
          }
        }
        if (failedCount > 0) {
          Alert.alert('Notice', `Vehicle saved, but ${failedCount} photo(s) failed to upload.`);
        }
      }

      Alert.alert('Success', vehicle ? 'Vehicle updated successfully' : 'Vehicle created successfully');
      onClose();
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    } finally {
      setIsSaving(false);
      setUploadStatus(null);
    }
  };

  return (
    <Modal visible transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.formModalBackdrop}>
        <ScrollView style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>{vehicle ? 'Edit Vehicle' : 'Add Vehicle'}</Text>

          <Text style={styles.fieldLabel}>Registration *</Text>
          <TextInput style={styles.input} value={registration} onChangeText={setRegistration} autoCapitalize="characters" />

          <Text style={styles.fieldLabel}>Make</Text>
          <TextInput style={styles.input} value={make} onChangeText={setMake} />

          <Text style={styles.fieldLabel}>Model</Text>
          <TextInput style={styles.input} value={model} onChangeText={setModel} />

          <Text style={styles.fieldLabel}>License Plate</Text>
          <TextInput style={styles.input} value={licensePlate} onChangeText={setLicensePlate} autoCapitalize="characters" />

          <Text style={[styles.fieldLabel, styles.sectionTitle]}>Photos (max {MAX_PHOTOS})</Text>
          {photos.length > 0 ? (
            <View style={styles.photoGrid}>
              {photos.map((photo, index) => (
                <View key={`${photo.uri}-${index}`} style={styles.photoThumb}>
                  <Image source={{ uri: photo.uri }} style={styles.photoThumbImage} resizeMode="cover" />
                  <Pressable style={styles.photoRemoveButton} onPress={() => removePhoto(index)}>
                    <Text style={styles.photoRemoveText}>✕</Text>
                  </Pressable>
                </View>
              ))}
            </View>
          ) : null}
          {photos.length < MAX_PHOTOS ? (
            <Pressable style={[styles.modalOutlinedButton, styles.addPhotoButton]} onPress={pickPhotos}>
              <Text style={styles.modalOutlinedText}>＋ Add Photo</Text>
            </Pressable>
          ) : null}
          {uploadStatus ? <Text style={styles.helperText}>{uploadStatus}</Text> : null}

          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} disabled={isSaving} onPress={onClose}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.modalPrimaryButton} disabled={isSaving} onPress={handleSave}>
              {isSaving ? <ActivityIndicator color={colors.white} size="small" /> : <Text style={textStyles.buttonText}>Save</Text>}
            </Pressable>
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  emptyIcon: { fontSize: 40, opacity: 0.4, marginBottom: spacing.small },
  loadingIndicator: { marginTop: spacing.xLarge },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.medium,
  },
  desktopBadge: { color: colors.white, fontSize: 11, fontWeight: '700', opacity: 0.8, borderWidth: 1, borderColor: colors.white, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 },
  headerBarRight: { flexDirection: 'row', gap: spacing.medium },
  headerBarAction: { color: colors.white, fontSize: 18, fontWeight: '600' },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 280, borderRightWidth: 1, borderRightColor: colors.divider, backgroundColor: colors.card },
  sidebarContent: { padding: spacing.medium },
  sidebarLabel: { fontWeight: '600', color: colors.textSecondary, marginBottom: spacing.small },
  sidebarSectionSpacer: { marginTop: spacing.large },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  sortOptionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small },
  sortOptionGlyph: { fontSize: 16, marginRight: spacing.small, color: colors.primary, width: 20 },
  sortOptionLabel: { fontSize: 14, color: colors.textPrimary },
  switchRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: spacing.large },
  settingTitle: { fontSize: 14, fontWeight: '600', color: colors.textPrimary },
  clearFiltersButton: { marginTop: spacing.large },
  mainArea: { flex: 1 },
  statsBar: { flexDirection: 'row', gap: spacing.small + 4, padding: spacing.medium, alignItems: 'stretch' },
  statCard: { flex: 1, alignItems: 'center', backgroundColor: colors.card, borderRadius: radii.cardRadius, paddingVertical: spacing.small + 4 },
  statIcon: { fontSize: 18 },
  statValue: { fontSize: 18, fontWeight: 'bold', marginTop: 4 },
  statLabel: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  exportButton: { justifyContent: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.medium },
  exportButtonText: { color: colors.white, fontWeight: '600', fontSize: 13 },
  bulkBar: { flexDirection: 'row', alignItems: 'center', gap: spacing.large, backgroundColor: `${colors.primary}14`, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, marginHorizontal: spacing.medium, borderRadius: radii.borderRadius },
  bulkBarText: { flex: 1, fontWeight: '600', color: colors.textPrimary },
  bulkBarAction: { fontWeight: '600', color: colors.primary },
  tableSection: { flex: 1, margin: spacing.medium, backgroundColor: colors.card, borderRadius: radii.cardRadius, overflow: 'hidden' },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.background, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableHeaderCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small + 4, justifyContent: 'center' },
  tableHeaderText: { fontSize: 12, fontWeight: '700', color: colors.textSecondary },
  tableBody: { flex: 1 },
  tableRow: { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableRowActive: { backgroundColor: `${colors.primary}0F` },
  tableCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small + 4, justifyContent: 'center' },
  tableCellText: { fontSize: 13, color: colors.textPrimary },
  tableCellTextBold: { fontSize: 13, fontWeight: '700', color: colors.textPrimary },
  tableActionsGlyph: { fontSize: 18, color: colors.textSecondary, textAlign: 'center' },
  statusBadge: { alignSelf: 'flex-start', borderRadius: 10, paddingHorizontal: spacing.small, paddingVertical: 2 },
  statusBadgeText: { fontSize: 11, fontWeight: '600' },
  detailPanel: { width: 400, borderLeftWidth: 1, borderLeftColor: colors.divider, backgroundColor: colors.card },
  detailPanelContent: { padding: spacing.large },
  sheetHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  detailStatusBadge: { marginTop: spacing.small },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  detailRow: { flexDirection: 'row', marginBottom: spacing.small + 4 },
  detailLabel: { width: 120, fontWeight: '600', color: colors.textSecondary },
  detailValue: { flex: 1 },
  sectionSpacer: { height: spacing.medium },
  sectionSpacerSmall: { height: spacing.small },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  photoThumb: { width: 90, height: 90, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.divider },
  photoThumbImage: { width: '100%', height: '100%' },
  photoThumbFallback: { alignItems: 'center', justifyContent: 'center' },
  photoRemoveButton: { position: 'absolute', top: 4, right: 4, backgroundColor: colors.error, borderRadius: 10, width: 20, height: 20, alignItems: 'center', justifyContent: 'center' },
  photoRemoveText: { color: colors.white, fontSize: 12, fontWeight: 'bold' },
  modalPrimaryButton: { alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedButton: { alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedText: { color: colors.textPrimary, fontWeight: '600' },
  deleteButton: { borderColor: colors.error },
  deleteButtonText: { color: colors.error, fontWeight: '600' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  formModalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '85%' },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionSheetDivider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600' },
  fieldLabel: { fontWeight: '600', marginTop: spacing.medium, marginBottom: spacing.small },
  sectionTitle: { marginTop: spacing.large },
  addPhotoButton: { alignSelf: 'flex-start', paddingHorizontal: spacing.large },
  helperText: { fontSize: 12, color: colors.textSecondary, marginTop: spacing.small },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalSecondaryButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius, borderWidth: 1, borderColor: colors.divider },
  modalSecondaryText: { color: colors.textSecondary, fontWeight: '600' },
});
