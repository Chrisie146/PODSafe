import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { AuthRepository } from '../../repositories/authRepository';
import { exportDrivers } from '../../repositories/csvExportService';
import { AppUser, ApprovalStatus } from '../../models/user';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const authRepository = new AuthRepository();

type StatusFilter = 'all' | ApprovalStatus;
type SortField = 'name' | 'email' | 'date';

function getInitials(name: string): string {
  const parts = name.trim().split(' ').filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

function statusColor(status: ApprovalStatus): string {
  switch (status) {
    case 'approved':
      return colors.success;
    case 'pending':
      return colors.warning;
    case 'rejected':
      return colors.error;
  }
}

function statusIcon(status: ApprovalStatus): string {
  switch (status) {
    case 'approved':
      return '✓';
    case 'pending':
      return '⏳';
    case 'rejected':
      return '✕';
  }
}

function formatDate(date: Date): string {
  const diffDays = Math.floor((Date.now() - date.getTime()) / 86400000);
  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays} days ago`;
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

const COLS = {
  checkbox: { width: 36 },
  avatar: { width: 56 },
  name: { width: 170 },
  email: { width: 200 },
  phone: { width: 130 },
  status: { width: 110 },
  registered: { width: 110 },
  actions: { width: 90 },
};
const TABLE_WIDTH = Object.values(COLS).reduce((sum, c) => sum + c.width, 0);

/**
 * Ported from lib/screens/admin/driver_management_desktop.dart (verified against source on
 * 2026-06-23). Same data layer as the mobile variant (DriverManagement.tsx): `AuthRepository`
 * directly (not `useUserManagementStore`'s single-list shape) and `useUserManagementStore`'s
 * `updateUser()` for approve/reject writes. Unlike the mobile screen's 3 simultaneous
 * per-status subscriptions (one per tab), this subscribes once to ALL drivers and filters
 * client-side, matching the Dart desktop source's single `StreamBuilder` + `_applyFilters`.
 *
 * Real (working) bulk approve/reject and a real CSV export — both already wired in the Dart
 * source (unlike Vehicle's no-op bulk actions), so ported as working features here too, via
 * the existing `exportDrivers()` in csvExportService.ts and a loop of `updateUser()` calls.
 *
 * Dropped (deliberate scope-trim, see Risk Register #14): keyboard shortcuts bar/handlers.
 * Field-name note: the Dart source's "Active Today" stat reads a `lastActivityAt` field that
 * doesn't exist anywhere on the `AppUser` model or its converters (confirmed by grep) — likely
 * a stat that was never actually wired to a real write path even in Dart. Re-pointed at the
 * closest real, modeled equivalent (`lastLoginAt`) rather than reproducing a stat that would
 * always read zero.
 */
export default function DriverManagementDesktop({ navigation }: { navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void } }) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const updateUser = useUserManagementStore((s) => s.updateUser);

  const [allDrivers, setAllDrivers] = useState<AppUser[] | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [sortBy, setSortBy] = useState<SortField>('name');
  const [sortAscending, setSortAscending] = useState(true);
  const [showFilters, setShowFilters] = useState(true);
  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [selectedDriver, setSelectedDriver] = useState<AppUser | null>(null);

  useEffect(() => {
    if (!currentUser) return;
    return authRepository.subscribeToUsersByCompany(
      currentUser.companyId,
      setAllDrivers,
      () => setAllDrivers([]),
      { role: 'driver', orderByCreatedAtDesc: true },
    );
  }, [currentUser]);

  const filteredDrivers = useMemo(() => {
    if (!allDrivers) return null;
    const q = searchQuery.trim().toLowerCase();
    let result = allDrivers.filter((d) => {
      if (statusFilter !== 'all' && (d.approvalStatus ?? 'approved') !== statusFilter) return false;
      if (q.length > 0) {
        const haystack = `${d.fullName} ${d.email} ${d.phoneNumber ?? ''}`.toLowerCase();
        if (!haystack.includes(q)) return false;
      }
      return true;
    });
    result = [...result].sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case 'name':
          cmp = a.fullName.localeCompare(b.fullName);
          break;
        case 'email':
          cmp = a.email.localeCompare(b.email);
          break;
        case 'date':
          cmp = a.createdAt.getTime() - b.createdAt.getTime();
          break;
      }
      return sortAscending ? cmp : -cmp;
    });
    return result;
  }, [allDrivers, statusFilter, searchQuery, sortBy, sortAscending]);

  const stats = useMemo(() => {
    const drivers = allDrivers ?? [];
    const total = drivers.length;
    const approved = drivers.filter((d) => (d.approvalStatus ?? 'approved') === 'approved').length;
    const pending = drivers.filter((d) => d.approvalStatus === 'pending').length;
    const rejected = drivers.filter((d) => d.approvalStatus === 'rejected').length;
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const activeToday = drivers.filter((d) => d.lastLoginAt && d.lastLoginAt.getTime() >= startOfToday.getTime()).length;
    return { total, approved, pending, rejected, activeToday };
  }, [allDrivers]);

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Error: No company ID</Text>
      </View>
    );
  }

  const allSelected = (filteredDrivers?.length ?? 0) > 0 && filteredDrivers!.every((d) => selectedIds.has(d.id));

  const toggleSelectOne = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleSelectAll = () => {
    if (!filteredDrivers) return;
    setSelectedIds(allSelected ? new Set() : new Set(filteredDrivers.map((d) => d.id)));
  };

  const clearFilters = () => {
    setSearchQuery('');
    setStatusFilter('all');
    setSortBy('name');
    setSortAscending(true);
  };

  const handleApprove = async (driver: AppUser) => {
    try {
      await updateUser({ ...driver, approvalStatus: 'approved', isActive: true, approvedBy: currentUser.id, approvedAt: new Date() });
      Alert.alert('Success', `${driver.fullName} has been approved`);
    } catch (e) {
      Alert.alert('Error', `Error approving driver: ${(e as Error).message}`);
    }
  };

  const handleReject = (driver: AppUser) => {
    Alert.alert('Reject Driver', `Are you sure you want to reject ${driver.fullName}?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Reject',
        style: 'destructive',
        onPress: async () => {
          try {
            await updateUser({ ...driver, approvalStatus: 'rejected', isActive: false, approvedBy: currentUser.id, approvedAt: new Date() });
            Alert.alert('Rejected', `${driver.fullName} has been rejected`);
            setSelectedDriver((prev) => (prev?.id === driver.id ? null : prev));
          } catch (e) {
            Alert.alert('Error', `Error rejecting driver: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  const handleBulkApprove = () => {
    const count = selectedIds.size;
    Alert.alert('Approve Drivers', `Are you sure you want to approve ${count} driver(s)?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Approve',
        onPress: async () => {
          try {
            for (const id of selectedIds) {
              const driver = allDrivers?.find((d) => d.id === id);
              if (driver) await updateUser({ ...driver, approvalStatus: 'approved', isActive: true, approvedBy: currentUser.id, approvedAt: new Date() });
            }
            Alert.alert('Success', `${count} driver(s) approved successfully`);
            setSelectedIds(new Set());
            setIsMultiSelectMode(false);
          } catch (e) {
            Alert.alert('Error', `Error approving drivers: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  const handleBulkReject = () => {
    const count = selectedIds.size;
    Alert.alert('Reject Drivers', `Are you sure you want to reject ${count} driver(s)?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Reject',
        style: 'destructive',
        onPress: async () => {
          try {
            for (const id of selectedIds) {
              const driver = allDrivers?.find((d) => d.id === id);
              if (driver) await updateUser({ ...driver, approvalStatus: 'rejected', isActive: false, approvedBy: currentUser.id, approvedAt: new Date() });
            }
            Alert.alert('Rejected', `${count} driver(s) rejected successfully`);
            setSelectedIds(new Set());
            setIsMultiSelectMode(false);
          } catch (e) {
            Alert.alert('Error', `Error rejecting drivers: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  const handleExportCsv = async () => {
    if (!filteredDrivers) return;
    try {
      await exportDrivers(
        filteredDrivers.map((d) => ({
          name: d.fullName,
          email: d.email,
          phone: d.phoneNumber,
          approvalStatus: d.approvalStatus ?? 'approved',
          createdAt: d.createdAt,
          lastActive: d.lastLoginAt,
          totalDeliveries: 0,
          approvedBy: d.approvedBy,
        })),
        statusFilter !== 'all' ? statusFilter : undefined,
        searchQuery || undefined,
      );
      Alert.alert('Success', `Exported ${filteredDrivers.length} driver(s) to CSV`);
    } catch (e) {
      Alert.alert('Error', `Error exporting drivers: ${(e as Error).message}`);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <View style={styles.headerBarLeft}>
          <Text style={textStyles.heading3}>Driver Management</Text>
          <Text style={styles.desktopBadge}>Desktop</Text>
        </View>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => setIsMultiSelectMode((p) => !p)}>
            <Text style={styles.headerBarAction}>{isMultiSelectMode ? '☑' : '☐'}</Text>
          </Pressable>
          <Pressable onPress={() => setShowFilters((p) => !p)}>
            <Text style={styles.headerBarAction}>🔍</Text>
          </Pressable>
          <Pressable onPress={() => navigation.navigate('CreateDriver')}>
            <Text style={styles.headerBarAction}>👤➕</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.body}>
        {showFilters ? (
          <View style={styles.sidebar}>
            <ScrollView contentContainerStyle={styles.sidebarContent}>
              <Text style={styles.sidebarTitle}>Filters</Text>
              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Search</Text>
              <TextInput style={styles.input} placeholder="Search drivers..." value={searchQuery} onChangeText={setSearchQuery} />

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Status</Text>
              <FilterOption label="All Drivers" selected={statusFilter === 'all'} onPress={() => setStatusFilter('all')} />
              <FilterOption label="Approved" selected={statusFilter === 'approved'} onPress={() => setStatusFilter('approved')} />
              <FilterOption label="Pending" selected={statusFilter === 'pending'} onPress={() => setStatusFilter('pending')} />
              <FilterOption label="Rejected" selected={statusFilter === 'rejected'} onPress={() => setStatusFilter('rejected')} />

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Sort By</Text>
              <SortOption label="Name" selected={sortBy === 'name'} onPress={() => setSortBy('name')} />
              <SortOption label="Email" selected={sortBy === 'email'} onPress={() => setSortBy('email')} />
              <SortOption label="Registration Date" selected={sortBy === 'date'} onPress={() => setSortBy('date')} />

              <View style={styles.switchRow}>
                <Text style={styles.settingTitle}>Ascending</Text>
                <Switch value={sortAscending} onValueChange={setSortAscending} trackColor={{ true: colors.primary, false: colors.divider }} />
              </View>

              <Pressable style={[styles.modalOutlinedButton, styles.clearFiltersButton]} onPress={clearFilters}>
                <Text style={styles.modalOutlinedText}>Clear Filters</Text>
              </Pressable>
            </ScrollView>
          </View>
        ) : null}

        <View style={styles.mainArea}>
          <View style={styles.statsBar}>
            <MiniStat label="Total Drivers" value={stats.total} icon="👥" color={colors.primary} />
            <MiniStat label="Approved" value={stats.approved} icon="✓" color={colors.success} />
            <MiniStat label="Pending" value={stats.pending} icon="⏳" color={colors.warning} />
            <MiniStat label="Rejected" value={stats.rejected} icon="✕" color={colors.error} />
            <MiniStat label="Active Today" value={stats.activeToday} icon="🚚" color="#2196F3" />
            <Pressable style={styles.exportButton} onPress={handleExportCsv}>
              <Text style={styles.exportButtonText}>⬇ Export CSV</Text>
            </Pressable>
          </View>

          {isMultiSelectMode && selectedIds.size > 0 ? (
            <View style={styles.bulkBar}>
              <Text style={styles.bulkBarText}>{selectedIds.size} driver(s) selected</Text>
              <Pressable onPress={handleBulkApprove}>
                <Text style={[styles.bulkBarAction, { color: colors.success }]}>Approve</Text>
              </Pressable>
              <Pressable onPress={handleBulkReject}>
                <Text style={[styles.bulkBarAction, { color: colors.error }]}>Reject</Text>
              </Pressable>
              <Pressable
                onPress={() => {
                  setSelectedIds(new Set());
                  setIsMultiSelectMode(false);
                }}
              >
                <Text style={styles.bulkBarAction}>Clear</Text>
              </Pressable>
            </View>
          ) : null}

          <View style={styles.contentRow}>
            <View style={styles.tableSection}>
              {filteredDrivers === null ? (
                <ActivityIndicator color={colors.primary} style={styles.loadingIndicator} />
              ) : filteredDrivers.length === 0 ? (
                <View style={styles.centered}>
                  <Text style={styles.emptyIcon}>👥</Text>
                  <Text style={textStyles.bodyMedium}>{allDrivers?.length === 0 ? 'No drivers found' : 'No matching drivers'}</Text>
                </View>
              ) : (
                <ScrollView horizontal>
                  <View style={{ minWidth: TABLE_WIDTH }}>
                    <View style={styles.tableHeaderRow}>
                      {isMultiSelectMode ? (
                        <Pressable style={[styles.tableHeaderCell, COLS.checkbox]} onPress={toggleSelectAll}>
                          <Text style={styles.tableHeaderText}>{allSelected ? '☑' : '☐'}</Text>
                        </Pressable>
                      ) : null}
                      <View style={[styles.tableHeaderCell, COLS.avatar]} />
                      <View style={[styles.tableHeaderCell, COLS.name]}>
                        <Text style={styles.tableHeaderText}>NAME</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.email]}>
                        <Text style={styles.tableHeaderText}>EMAIL</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.phone]}>
                        <Text style={styles.tableHeaderText}>PHONE</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.status]}>
                        <Text style={styles.tableHeaderText}>STATUS</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.registered]}>
                        <Text style={styles.tableHeaderText}>REGISTERED</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.actions]}>
                        <Text style={styles.tableHeaderText}>ACTIONS</Text>
                      </View>
                    </View>
                    <ScrollView style={styles.tableBody}>
                      {filteredDrivers.map((driver) => (
                        <DriverRow
                          key={driver.id}
                          driver={driver}
                          isMultiSelectMode={isMultiSelectMode}
                          isSelected={selectedIds.has(driver.id)}
                          isActiveRow={selectedDriver?.id === driver.id}
                          onToggleSelect={() => toggleSelectOne(driver.id)}
                          onPress={() => setSelectedDriver(driver)}
                          onApprove={() => handleApprove(driver)}
                          onReject={() => handleReject(driver)}
                          onViewDetails={() => navigation.navigate('DriverDetails', { driverId: driver.id })}
                        />
                      ))}
                    </ScrollView>
                  </View>
                </ScrollView>
              )}
            </View>

            {selectedDriver ? (
              <DetailPanel
                driver={selectedDriver}
                onClose={() => setSelectedDriver(null)}
                onApprove={() => handleApprove(selectedDriver)}
                onReject={() => handleReject(selectedDriver)}
                onViewDetails={() => navigation.navigate('DriverDetails', { driverId: selectedDriver.id })}
              />
            ) : null}
          </View>
        </View>
      </View>
    </View>
  );
}

function MiniStat({ label, value, icon, color }: { label: string; value: number; icon: string; color: string }) {
  return (
    <View style={[styles.statCard, shadows.card]}>
      <View style={styles.statTopRow}>
        <Text style={[styles.statIcon, { color }]}>{icon}</Text>
        <Text style={styles.statLabel}>{label}</Text>
      </View>
      <Text style={[styles.statValue, { color }]}>{value}</Text>
    </View>
  );
}

function FilterOption({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.filterOption, selected && styles.filterOptionSelected]} onPress={onPress}>
      <Text style={styles.filterOptionGlyph}>{selected ? '●' : '○'}</Text>
      <Text style={[styles.filterOptionLabel, selected && styles.filterOptionLabelSelected]}>{label}</Text>
    </Pressable>
  );
}

function SortOption({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.filterOption, selected && styles.sortOptionSelected]} onPress={onPress}>
      <Text style={[styles.filterOptionGlyph, selected && styles.sortOptionGlyphSelected]}>{selected ? '◉' : '○'}</Text>
      <Text style={[styles.filterOptionLabel, selected && styles.sortOptionLabelSelected]}>{label}</Text>
    </Pressable>
  );
}

function DriverRow({
  driver,
  isMultiSelectMode,
  isSelected,
  isActiveRow,
  onToggleSelect,
  onPress,
  onApprove,
  onReject,
  onViewDetails,
}: {
  driver: AppUser;
  isMultiSelectMode: boolean;
  isSelected: boolean;
  isActiveRow: boolean;
  onToggleSelect: () => void;
  onPress: () => void;
  onApprove: () => void;
  onReject: () => void;
  onViewDetails: () => void;
}) {
  const status = driver.approvalStatus ?? 'approved';
  const color = statusColor(status);
  return (
    <Pressable style={[styles.tableRow, isActiveRow && styles.tableRowActive]} onPress={isMultiSelectMode ? onToggleSelect : onPress}>
      {isMultiSelectMode ? (
        <View style={[styles.tableCell, COLS.checkbox]}>
          <Text>{isSelected ? '☑' : '☐'}</Text>
        </View>
      ) : null}
      <View style={[styles.tableCell, COLS.avatar]}>
        <View style={[styles.avatar, { backgroundColor: `${color}1A` }]}>
          <Text style={[styles.avatarText, { color }]}>{getInitials(driver.fullName)}</Text>
        </View>
      </View>
      <View style={[styles.tableCell, COLS.name]}>
        <Text style={styles.tableCellTextBold} numberOfLines={1}>
          {driver.fullName}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.email]}>
        <Text style={styles.tableCellText} numberOfLines={1}>
          {driver.email}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.phone]}>
        <Text style={styles.tableCellText}>{driver.phoneNumber ?? '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.status]}>
        <View style={[styles.statusBadge, { backgroundColor: `${color}1A`, borderColor: `${color}4D` }]}>
          <Text style={[styles.statusBadgeText, { color }]}>
            {statusIcon(status)} {status.toUpperCase()}
          </Text>
        </View>
      </View>
      <View style={[styles.tableCell, COLS.registered]}>
        <Text style={styles.tableCellText}>{formatDate(driver.createdAt)}</Text>
      </View>
      <View style={[styles.tableCell, COLS.actions, styles.actionsCell]}>
        {status === 'pending' ? (
          <>
            <Pressable onPress={onApprove}>
              <Text style={[styles.actionIcon, { color: colors.success }]}>✓</Text>
            </Pressable>
            <Pressable onPress={onReject}>
              <Text style={[styles.actionIcon, { color: colors.error }]}>✕</Text>
            </Pressable>
          </>
        ) : (
          <Pressable onPress={onViewDetails}>
            <Text style={styles.actionIcon}>👁</Text>
          </Pressable>
        )}
      </View>
    </Pressable>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue}>{value}</Text>
    </View>
  );
}

function DetailPanel({
  driver,
  onClose,
  onApprove,
  onReject,
  onViewDetails,
}: {
  driver: AppUser;
  onClose: () => void;
  onApprove: () => void;
  onReject: () => void;
  onViewDetails: () => void;
}) {
  const status = driver.approvalStatus ?? 'approved';
  const color = statusColor(status);

  return (
    <View style={styles.detailPanel}>
      <View style={styles.detailPanelHeader}>
        <Text style={styles.detailPanelTitle}>Driver Details</Text>
        <Pressable onPress={onClose}>
          <Text style={styles.closeGlyph}>✕</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.detailPanelContent}>
        <View style={styles.detailAvatarBox}>
          <View style={[styles.detailAvatar, { backgroundColor: `${color}1A` }]}>
            <Text style={[styles.detailAvatarText, { color }]}>{getInitials(driver.fullName)}</Text>
          </View>
          <Text style={[textStyles.heading3, styles.detailName]}>{driver.fullName}</Text>
          <View style={[styles.detailStatusPill, { backgroundColor: color }]}>
            <Text style={styles.detailStatusPillText}>
              {statusIcon(status)} {status.toUpperCase()}
            </Text>
          </View>
        </View>

        <Text style={styles.detailSectionTitle}>Contact Information</Text>
        <DetailRow label="Email" value={driver.email} />
        {driver.phoneNumber ? <DetailRow label="Phone" value={driver.phoneNumber} /> : null}

        <Text style={styles.detailSectionTitle}>Driver Information</Text>
        {driver.licenseNumber ? <DetailRow label="License Number" value={driver.licenseNumber} /> : null}
        {driver.vehicleInfo ? <DetailRow label="Vehicle" value={driver.vehicleInfo} /> : null}
        <DetailRow label="Status" value={driver.isActive ? 'Active' : 'Inactive'} />
        <DetailRow label="Registered" value={driver.createdAt.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })} />

        <View style={styles.sectionSpacer} />
        {status === 'pending' ? (
          <>
            <Pressable style={styles.modalPrimaryButton} onPress={onApprove}>
              <Text style={textStyles.buttonText}>✓ Approve Driver</Text>
            </Pressable>
            <Pressable style={[styles.modalOutlinedButton, styles.rejectButton]} onPress={onReject}>
              <Text style={styles.rejectButtonText}>✕ Reject Driver</Text>
            </Pressable>
          </>
        ) : (
          <Pressable style={styles.modalOutlinedButton} onPress={onViewDetails}>
            <Text style={styles.modalOutlinedText}>↗ View Full Details</Text>
          </Pressable>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyIcon: { fontSize: 56, opacity: 0.3, marginBottom: spacing.medium },
  loadingIndicator: { marginTop: spacing.xLarge },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.medium, paddingVertical: spacing.medium },
  headerBarLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.small + 4 },
  desktopBadge: { color: colors.white, fontSize: 11, fontWeight: '700', opacity: 0.8, borderWidth: 1, borderColor: colors.white, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 },
  headerBarRight: { flexDirection: 'row', gap: spacing.medium },
  headerBarAction: { color: colors.white, fontSize: 18 },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 280, borderRightWidth: 1, borderRightColor: colors.divider, backgroundColor: colors.card },
  sidebarContent: { padding: spacing.medium },
  sidebarTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary },
  sidebarLabel: { fontWeight: '600', color: colors.textSecondary, marginBottom: spacing.small },
  sidebarSectionSpacer: { marginTop: spacing.large },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  filterOption: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small + 4, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, marginBottom: spacing.small },
  filterOptionSelected: { backgroundColor: colors.primary, borderColor: colors.primary },
  filterOptionGlyph: { fontSize: 16, marginRight: spacing.small, color: colors.textSecondary, width: 18 },
  filterOptionLabel: { fontSize: 14, color: colors.textPrimary },
  filterOptionLabelSelected: { color: colors.white, fontWeight: '600' },
  sortOptionSelected: { backgroundColor: `${colors.primary}1A`, borderColor: colors.primary },
  sortOptionGlyphSelected: { color: colors.primary },
  sortOptionLabelSelected: { color: colors.primary, fontWeight: '600' },
  switchRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: spacing.large },
  settingTitle: { fontSize: 14, fontWeight: '600', color: colors.textPrimary },
  clearFiltersButton: { marginTop: spacing.large },
  modalOutlinedButton: { alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedText: { color: colors.textPrimary, fontWeight: '600' },
  mainArea: { flex: 1 },
  statsBar: { flexDirection: 'row', gap: spacing.small + 4, padding: spacing.medium, alignItems: 'stretch' },
  statCard: { flex: 1, backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.small + 4 },
  statTopRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  statIcon: { fontSize: 16 },
  statLabel: { fontSize: 11, color: colors.textSecondary, fontWeight: '500' },
  statValue: { fontSize: 20, fontWeight: 'bold', marginTop: 6 },
  exportButton: { justifyContent: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.medium },
  exportButtonText: { color: colors.white, fontWeight: '600', fontSize: 13 },
  bulkBar: { flexDirection: 'row', alignItems: 'center', gap: spacing.large, backgroundColor: `${colors.primary}14`, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, marginHorizontal: spacing.medium, borderRadius: radii.borderRadius },
  bulkBarText: { flex: 1, fontWeight: '600', color: colors.textPrimary },
  bulkBarAction: { fontWeight: '600', color: colors.primary },
  contentRow: { flex: 1, flexDirection: 'row' },
  tableSection: { flex: 1, margin: spacing.medium, backgroundColor: colors.card, borderRadius: radii.cardRadius, overflow: 'hidden' },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.background, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableHeaderCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small + 4, justifyContent: 'center' },
  tableHeaderText: { fontSize: 12, fontWeight: '700', color: colors.textSecondary },
  tableBody: { flex: 1 },
  tableRow: { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: colors.divider, minHeight: 64 },
  tableRowActive: { backgroundColor: `${colors.primary}0F` },
  tableCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small, justifyContent: 'center' },
  tableCellText: { fontSize: 13, color: colors.textPrimary },
  tableCellTextBold: { fontSize: 13, fontWeight: '700', color: colors.textPrimary },
  avatar: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  avatarText: { fontSize: 14, fontWeight: 'bold' },
  statusBadge: { alignSelf: 'flex-start', borderRadius: 12, borderWidth: 1, paddingHorizontal: spacing.small, paddingVertical: 3 },
  statusBadgeText: { fontSize: 11, fontWeight: 'bold' },
  actionsCell: { flexDirection: 'row', gap: spacing.medium },
  actionIcon: { fontSize: 18, color: colors.textPrimary },
  detailPanel: { width: 400, borderLeftWidth: 1, borderLeftColor: colors.divider, backgroundColor: colors.card },
  detailPanelHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: spacing.medium, borderBottomWidth: 1, borderBottomColor: colors.divider },
  detailPanelTitle: { fontWeight: '700', fontSize: 15, color: colors.textPrimary },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  detailPanelContent: { padding: spacing.large },
  detailAvatarBox: { alignItems: 'center', marginBottom: spacing.large },
  detailAvatar: { width: 90, height: 90, borderRadius: 45, alignItems: 'center', justifyContent: 'center' },
  detailAvatarText: { fontSize: 28, fontWeight: 'bold' },
  detailName: { marginTop: spacing.medium, textAlign: 'center' },
  detailStatusPill: { marginTop: spacing.small, borderRadius: 12, paddingHorizontal: spacing.medium, paddingVertical: 6 },
  detailStatusPillText: { color: colors.white, fontSize: 12, fontWeight: 'bold' },
  detailSectionTitle: { fontWeight: '700', fontSize: 15, color: colors.textPrimary, marginTop: spacing.large, marginBottom: spacing.small },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4 },
  detailLabel: { color: colors.textSecondary },
  detailValue: { fontWeight: '600', color: colors.textPrimary },
  sectionSpacer: { height: spacing.medium },
  modalPrimaryButton: { alignItems: 'center', justifyContent: 'center', backgroundColor: colors.success, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  rejectButton: { borderColor: colors.error },
  rejectButtonText: { color: colors.error, fontWeight: '600' },
});
