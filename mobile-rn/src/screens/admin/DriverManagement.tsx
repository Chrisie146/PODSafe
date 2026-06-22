import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { AuthRepository } from '../../repositories/authRepository';
import { AppUser, ApprovalStatus } from '../../models/user';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/driver_management_screen.dart
 * (`DriverManagementMobile`, verified against source on 2026-06-22) — 3-tab
 * (Approved/Pending/Rejected) driver list with search, quick approve/reject actions on
 * pending cards, and an "Add Driver" FAB.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the
 * >1000px desktop branch lands in Phase 4.
 *
 * Deviations from the Flutter source:
 * - Subscribes to all 3 approval-status tabs simultaneously via 3 independent
 *   `authRepository.subscribeToUsersByCompany()` calls (extended this pass with
 *   `approvalStatus`/`orderByCreatedAtDesc` filters), matching Flutter's `TabBarView`
 *   which builds and keeps all tab children mounted (and their StreamBuilders live) at
 *   once, not lazily per-tab. Uses `AuthRepository` directly rather than
 *   `useUserManagementStore`'s `users`/`subscribeForCompany` (a single-list shape that
 *   doesn't fit this screen's three-simultaneous-lists need) — same precedent as
 *   ClaimsDashboard.tsx instantiating `DeliveryRepository` directly for a per-card need
 *   the shared delivery store doesn't cover.
 * - Approve/Reject quick actions reuse `useUserManagementStore.updateUser()` (a
 *   full-document write via the existing `AppUser` already held in the list, since the
 *   live subscription returns full `AppUser` objects, not raw maps) instead of a
 *   hand-rolled targeted Firestore `.update()` — same end state (approvalStatus,
 *   isActive, approvedBy, approvedAt all get set), no new repository method needed.
 * - Tab bar is a custom Pressable strip (house convention), not a tab-bar library.
 * - "Add Driver" navigates to a `CreateDriver` route that doesn't exist yet —
 *   create_driver_screen.dart is explicitly blocked on Phase 5's `createUser` callable,
 *   same forward-reference pattern as DriverDetails.tsx's Edit button.
 */
const TABS: { key: ApprovalStatus; label: string; icon: string }[] = [
  { key: 'approved', label: 'Approved', icon: '✓' },
  { key: 'pending', label: 'Pending', icon: '⏳' },
  { key: 'rejected', label: 'Rejected', icon: '✕' },
];

interface DriverManagementProps {
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

const authRepository = new AuthRepository();

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

function formatRelativeDate(date: Date): string {
  const diffDays = Math.floor((Date.now() - date.getTime()) / 86400000);
  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays} days ago`;
  return `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
}

export default function DriverManagement({ navigation }: DriverManagementProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const updateUser = useUserManagementStore((s) => s.updateUser);

  const [activeTab, setActiveTab] = useState<ApprovalStatus>('approved');
  const [searchQuery, setSearchQuery] = useState('');
  const [driversByStatus, setDriversByStatus] = useState<Record<ApprovalStatus, AppUser[] | null>>({
    approved: null,
    pending: null,
    rejected: null,
  });

  useEffect(() => {
    if (!currentUser) return;

    const unsubscribes = TABS.map(({ key }) =>
      authRepository.subscribeToUsersByCompany(
        currentUser.companyId,
        (users) => setDriversByStatus((prev) => ({ ...prev, [key]: users })),
        () => setDriversByStatus((prev) => ({ ...prev, [key]: [] })),
        { role: 'driver', approvalStatus: key, orderByCreatedAtDesc: true },
      ),
    );

    return () => unsubscribes.forEach((unsub) => unsub());
  }, [currentUser]);

  const handleApprove = async (driver: AppUser) => {
    if (!currentUser) return;
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
          if (!currentUser) return;
          try {
            await updateUser({ ...driver, approvalStatus: 'rejected', isActive: false, approvedBy: currentUser.id, approvedAt: new Date() });
            Alert.alert('Rejected', `${driver.fullName} has been rejected`);
          } catch (e) {
            Alert.alert('Error', `Error rejecting driver: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  const activeDrivers = driversByStatus[activeTab];
  const q = searchQuery.trim().toLowerCase();
  const filteredDrivers = activeDrivers?.filter((d) => q.length === 0 || d.fullName.toLowerCase().includes(q) || d.email.toLowerCase().includes(q)) ?? null;

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>Driver Management</Text>
      </View>

      <View style={styles.tabStrip}>
        {TABS.map((tab) => (
          <Pressable key={tab.key} style={[styles.tabButton, activeTab === tab.key && styles.tabButtonActive]} onPress={() => setActiveTab(tab.key)}>
            <Text style={[styles.tabButtonIcon, activeTab === tab.key && styles.tabButtonTextActive]}>{tab.icon}</Text>
            <Text style={[styles.tabButtonText, activeTab === tab.key && styles.tabButtonTextActive]}>{tab.label}</Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.searchBox}>
        <Text style={styles.searchIcon}>🔍</Text>
        <TextInput style={styles.searchInput} placeholder="Search by name or email..." value={searchQuery} onChangeText={setSearchQuery} />
        {searchQuery.length > 0 ? (
          <Pressable onPress={() => setSearchQuery('')}>
            <Text style={styles.searchClear}>✕</Text>
          </Pressable>
        ) : null}
      </View>

      {filteredDrivers === null ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : filteredDrivers.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.emptyIcon}>👥</Text>
          <Text style={styles.emptyText}>
            {searchQuery.length > 0
              ? 'No matching drivers'
              : activeTab === 'approved'
                ? 'No approved drivers'
                : activeTab === 'pending'
                  ? 'No pending approvals'
                  : 'No rejected drivers'}
          </Text>
          {searchQuery.length === 0 ? <Text style={styles.emptyHint}>Tap + to add a new driver</Text> : null}
        </View>
      ) : (
        <FlatList
          data={filteredDrivers}
          keyExtractor={(driver) => driver.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => (
            <DriverCard
              driver={item}
              onPress={() => navigation.navigate('DriverDetails', { driverId: item.id })}
              onApprove={() => handleApprove(item)}
              onReject={() => handleReject(item)}
            />
          )}
        />
      )}

      <Pressable style={styles.fab} onPress={() => navigation.navigate('CreateDriver')}>
        <Text style={styles.fabIcon}>＋</Text>
        <Text style={styles.fabLabel}>Add Driver</Text>
      </Pressable>
    </View>
  );
}

function DriverCard({ driver, onPress, onApprove, onReject }: { driver: AppUser; onPress: () => void; onApprove: () => void; onReject: () => void }) {
  const color = statusColor(driver.approvalStatus ?? 'approved');

  return (
    <View style={[styles.card, shadows.card]}>
      <Pressable style={styles.cardTopRow} onPress={onPress}>
        <View style={[styles.avatar, { backgroundColor: `${color}1A` }]}>
          <Text style={[styles.avatarText, { color }]}>{getInitials(driver.fullName)}</Text>
        </View>
        <View style={styles.cardTextBox}>
          <View style={styles.cardNameRow}>
            <Text style={styles.cardName} numberOfLines={1}>
              {driver.fullName}
            </Text>
            <View style={[styles.statusPill, { backgroundColor: color }]}>
              <Text style={styles.statusPillText}>{(driver.approvalStatus ?? 'approved').toUpperCase()}</Text>
            </View>
          </View>
          <Text style={styles.cardMeta} numberOfLines={1}>
            ✉ {driver.email}
          </Text>
          {driver.phoneNumber ? <Text style={styles.cardMeta}>☏ {driver.phoneNumber}</Text> : null}
          {driver.licenseNumber ? <Text style={styles.cardMeta}>License: {driver.licenseNumber}</Text> : null}
          {driver.vehicleInfo ? (
            <Text style={styles.cardMeta} numberOfLines={1}>
              🚚 {driver.vehicleInfo}
            </Text>
          ) : null}
          <Text style={styles.cardMetaSmall}>Registered: {formatRelativeDate(driver.createdAt)}</Text>
        </View>
      </Pressable>

      {driver.approvalStatus === 'pending' ? (
        <View style={styles.cardActionsRow}>
          <Pressable style={styles.rejectButton} onPress={onReject}>
            <Text style={styles.rejectButtonText}>✕ Reject</Text>
          </Pressable>
          <Pressable style={styles.approveButton} onPress={onApprove}>
            <Text style={styles.approveButtonText}>✓ Approve</Text>
          </Pressable>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  headerBar: { backgroundColor: colors.primary, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  tabStrip: { flexDirection: 'row', backgroundColor: colors.primary },
  tabButton: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.small, paddingVertical: spacing.medium, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabButtonActive: { borderBottomColor: colors.white },
  tabButtonIcon: { fontSize: 14, color: 'rgba(255,255,255,0.7)' },
  tabButtonText: { fontSize: 13, fontWeight: '600', color: 'rgba(255,255,255,0.7)' },
  tabButtonTextActive: { color: colors.white },
  searchBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, margin: spacing.medium, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4 },
  searchIcon: { marginRight: spacing.small },
  searchInput: { flex: 1, paddingVertical: spacing.small + 4 },
  searchClear: { color: colors.textSecondary, padding: spacing.small },
  emptyIcon: { fontSize: 56, opacity: 0.3 },
  emptyText: { fontSize: 17, fontWeight: '600', color: colors.textSecondary, marginTop: spacing.medium },
  emptyHint: { fontSize: 13, color: colors.textSecondary, marginTop: spacing.small },
  listContent: { padding: spacing.medium, paddingBottom: 96 },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, marginBottom: spacing.medium, overflow: 'hidden' },
  cardTopRow: { flexDirection: 'row', padding: spacing.medium },
  avatar: { width: 56, height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center', marginRight: spacing.medium },
  avatarText: { fontSize: 18, fontWeight: 'bold' },
  cardTextBox: { flex: 1 },
  cardNameRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.small },
  cardName: { flex: 1, fontSize: 16, fontWeight: '600' },
  statusPill: { borderRadius: 12, paddingHorizontal: spacing.small + 4, paddingVertical: 4 },
  statusPillText: { color: colors.white, fontSize: 11, fontWeight: 'bold' },
  cardMeta: { fontSize: 13, color: colors.textSecondary, marginTop: 4 },
  cardMetaSmall: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  cardActionsRow: { flexDirection: 'row', gap: spacing.medium, padding: spacing.small + 4, backgroundColor: colors.background, borderTopWidth: 1, borderTopColor: colors.divider },
  rejectButton: { flex: 1, alignItems: 'center', borderWidth: 1, borderColor: colors.error, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  rejectButtonText: { color: colors.error, fontWeight: '600' },
  approveButton: { flex: 1, alignItems: 'center', backgroundColor: colors.success, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  approveButtonText: { color: colors.white, fontWeight: '600' },
  fab: {
    position: 'absolute',
    right: spacing.large,
    bottom: spacing.large,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small,
    backgroundColor: colors.primary,
    borderRadius: 28,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.medium,
    ...shadows.button,
  },
  fabIcon: { color: colors.white, fontSize: 16, fontWeight: 'bold' },
  fabLabel: { color: colors.white, fontWeight: '600' },
});
