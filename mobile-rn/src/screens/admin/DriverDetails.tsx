// expects route.params: { driverId: string }
import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { AppUser, ApprovalStatus } from '../../models/user';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/driver_details_screen.dart (verified against source on
 * 2026-06-22).
 *
 * Deviations from the Flutter source:
 * - Takes only `driverId` via route params and loads the full user doc through
 *   useUserManagementStore (added loadUserById/selectedUser/deleteUser this pass) instead
 *   of requiring the caller to pass the full driverData map — same robustness argument as
 *   driver/DeliveryDetails.tsx's class comment (deep-link/refresh safety).
 * - Stats + "Recent Deliveries" both derive from a single
 *   DeliveryRepository.subscribeToDeliveriesForDriver() live subscription (already
 *   ordered desc by scheduledDate) instead of the Dart source's two separate Firestore
 *   reads (`.get()` for stats, a second `.snapshots()` stream limited to 5 for the list).
 * - The PopupMenuButton (Approve/Reject/Toggle Status/Delete) becomes a bottom-sheet-style
 *   Modal action list (house convention — no menu library installed); each action still
 *   confirms via Alert.alert exactly as the Dart source's AlertDialogs did.
 * - "Edit" navigates to a `CreateDriver` route that doesn't exist yet — create_driver_screen
 *   is explicitly blocked on Phase 5's `createUser` callable per the master plan, so this
 *   is wired ahead of that screen existing, same as other forward-references in this phase.
 */
interface DriverDetailsProps {
  route: { params: { driverId: string } };
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void; goBack: () => void };
}

const deliveryRepository = new DeliveryRepository();

function getInitials(name: string): string {
  const parts = name.trim().split(' ').filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

function statusColor(status: DeliveryStatus): string {
  switch (status) {
    case 'pending':
      return colors.warning;
    case 'inTransit':
      return colors.info;
    case 'delivered':
      return colors.success;
    default:
      return colors.textSecondary;
  }
}

function statusIcon(status: DeliveryStatus): string {
  switch (status) {
    case 'pending':
      return '⏳';
    case 'inTransit':
      return '🚚';
    case 'delivered':
      return '✓';
    default:
      return '?';
  }
}

function formatStatus(status: DeliveryStatus): string {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'inTransit':
      return 'In Transit';
    case 'delivered':
      return 'Delivered';
    default:
      return status;
  }
}

function approvalStatusColor(status?: ApprovalStatus): string {
  switch (status) {
    case 'approved':
      return colors.success;
    case 'pending':
      return colors.warning;
    case 'rejected':
      return colors.error;
    default:
      return colors.textSecondary;
  }
}

function approvalStatusText(status?: ApprovalStatus): string {
  switch (status) {
    case 'approved':
      return 'Approved';
    case 'pending':
      return 'Pending Approval';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Unknown';
  }
}

function formatDate(date: Date): string {
  return date.toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' });
}

function formatShortDate(date: Date): string {
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

export default function DriverDetails({ route, navigation }: DriverDetailsProps) {
  const { driverId } = route.params;
  const selectedUser = useUserManagementStore((s) => s.selectedUser);
  const isLoading = useUserManagementStore((s) => s.isLoading);
  const loadUserById = useUserManagementStore((s) => s.loadUserById);
  const updateUser = useUserManagementStore((s) => s.updateUser);
  const deleteUser = useUserManagementStore((s) => s.deleteUser);

  const [deliveries, setDeliveries] = useState<Delivery[] | null>(null);
  const [showActions, setShowActions] = useState(false);

  useEffect(() => {
    loadUserById(driverId);
  }, [driverId, loadUserById]);

  useEffect(() => {
    const unsubscribe = deliveryRepository.subscribeToDeliveriesForDriver(driverId, setDeliveries, () => setDeliveries([]));
    return unsubscribe;
  }, [driverId]);

  const stats = useMemo(() => {
    if (!deliveries) return null;
    return {
      total: deliveries.length,
      completed: deliveries.filter((d) => d.status === 'delivered').length,
      active: deliveries.filter((d) => d.status === 'inTransit').length,
    };
  }, [deliveries]);

  const recentDeliveries = useMemo(() => deliveries?.slice(0, 5) ?? [], [deliveries]);

  const handleToggleStatus = () => {
    if (!selectedUser) return;
    const newStatus = !selectedUser.isActive;
    setShowActions(false);
    Alert.alert(
      newStatus ? 'Activate Driver' : 'Deactivate Driver',
      newStatus
        ? 'Are you sure you want to activate this driver? They will be able to receive new deliveries.'
        : 'Are you sure you want to deactivate this driver? They will no longer receive new deliveries.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: newStatus ? 'Activate' : 'Deactivate',
          onPress: async () => {
            try {
              await updateUser({ ...selectedUser, isActive: newStatus });
              Alert.alert('Success', newStatus ? 'Driver activated successfully' : 'Driver deactivated successfully');
              navigation.goBack();
            } catch (e) {
              Alert.alert('Error', `${(e as Error).message}`);
            }
          },
        },
      ],
    );
  };

  const handleApproveDriver = () => {
    if (!selectedUser) return;
    setShowActions(false);
    Alert.alert('Approve Driver', 'Are you sure you want to approve this driver? They will be able to receive deliveries immediately.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Approve',
        onPress: async () => {
          try {
            await updateUser({ ...selectedUser, approvalStatus: 'approved' });
            Alert.alert('Success', 'Driver approved successfully');
            navigation.goBack();
          } catch (e) {
            Alert.alert('Error', `Error approving driver: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  const handleRejectDriver = () => {
    if (!selectedUser) return;
    setShowActions(false);
    Alert.alert('Reject Driver', 'Are you sure you want to reject this driver? They will not be able to receive deliveries.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Reject',
        style: 'destructive',
        onPress: async () => {
          try {
            await updateUser({ ...selectedUser, approvalStatus: 'rejected' });
            Alert.alert('Driver rejected', '');
            navigation.goBack();
          } catch (e) {
            Alert.alert('Error', `Error rejecting driver: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  const handleDeleteDriver = () => {
    setShowActions(false);
    Alert.alert(
      'Delete Driver',
      'Are you sure you want to delete this driver? This action cannot be undone. All their delivery history will be affected.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await deleteUser(driverId);
              Alert.alert('Success', 'Driver deleted successfully');
              navigation.goBack();
            } catch (e) {
              Alert.alert('Error', `Error deleting driver: ${(e as Error).message}`);
            }
          },
        },
      ],
    );
  };

  if (isLoading || !selectedUser) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  const driver: AppUser = selectedUser;

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => navigation.goBack()}>
          <Text style={styles.headerBarAction}>‹ Back</Text>
        </Pressable>
        <Text style={textStyles.heading3}>Driver Details</Text>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => navigation.navigate('CreateDriver', { driverId })}>
            <Text style={styles.headerBarAction}>✎</Text>
          </Pressable>
          <Pressable onPress={() => setShowActions(true)}>
            <Text style={styles.headerBarAction}>⋮</Text>
          </Pressable>
        </View>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        <View style={[styles.card, shadows.card, styles.headerCard]}>
          <View style={[styles.avatar, { backgroundColor: driver.isActive ? `${colors.success}1A` : colors.divider }]}>
            <Text style={[styles.avatarText, { color: driver.isActive ? colors.success : colors.textSecondary }]}>{getInitials(driver.fullName)}</Text>
          </View>
          <Text style={styles.driverName}>{driver.fullName}</Text>
          <View style={styles.badgeRow}>
            <View style={[styles.badge, { backgroundColor: driver.isActive ? colors.success : colors.textSecondary }]}>
              <Text style={styles.badgeText}>{driver.isActive ? 'Active' : 'Inactive'}</Text>
            </View>
            {driver.approvalStatus ? (
              <View style={[styles.badge, { backgroundColor: approvalStatusColor(driver.approvalStatus) }]}>
                <Text style={styles.badgeText}>{approvalStatusText(driver.approvalStatus)}</Text>
              </View>
            ) : null}
          </View>
        </View>

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Performance Statistics</Text>
        {!stats ? (
          <ActivityIndicator color={colors.primary} style={styles.statsLoading} />
        ) : (
          <View style={styles.statsRow}>
            <StatCard label="Total" value={stats.total} icon="🚚" color={colors.primary} />
            <StatCard label="Active" value={stats.active} icon="⏳" color={colors.info} />
            <StatCard label="Completed" value={stats.completed} icon="✓" color={colors.success} />
          </View>
        )}

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Contact Information</Text>
        <View style={[styles.card, shadows.card]}>
          <InfoRow label="Email" value={driver.email} icon="✉" />
          {driver.phoneNumber ? <InfoRow label="Phone" value={driver.phoneNumber} icon="📞" /> : null}
        </View>

        {driver.licenseNumber || driver.vehicleInfo ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Driver Information</Text>
            <View style={[styles.card, shadows.card]}>
              {driver.licenseNumber ? <InfoRow label="License Number" value={driver.licenseNumber} icon="🪪" /> : null}
              {driver.vehicleInfo ? <InfoRow label="Vehicle" value={driver.vehicleInfo} icon="🚚" /> : null}
            </View>
          </>
        ) : null}

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Account Information</Text>
        <View style={[styles.card, shadows.card]}>
          <InfoRow label="Driver ID" value={driver.id.substring(0, 12)} icon="🔑" />
          {driver.createdAt ? <InfoRow label="Joined" value={formatDate(driver.createdAt)} icon="📅" /> : null}
        </View>

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Recent Deliveries</Text>
        {deliveries === null ? (
          <ActivityIndicator color={colors.primary} style={styles.statsLoading} />
        ) : recentDeliveries.length === 0 ? (
          <View style={[styles.card, shadows.card, styles.emptyDeliveries]}>
            <Text style={styles.emptyDeliveriesIcon}>🚚</Text>
            <Text style={styles.emptyDeliveriesText}>No deliveries assigned yet</Text>
          </View>
        ) : (
          recentDeliveries.map((delivery) => (
            <View key={delivery.id} style={[styles.card, shadows.card, styles.deliveryRow]}>
              <Text style={[styles.deliveryIcon, { color: statusColor(delivery.status) }]}>{statusIcon(delivery.status)}</Text>
              <View style={styles.deliveryTextBox}>
                <Text style={styles.deliveryTitle}>{delivery.orderNumber ? `${delivery.orderNumber} - ${delivery.customerName}` : delivery.customerName}</Text>
                <Text style={styles.deliverySubtitle}>{formatShortDate(delivery.scheduledDate)}</Text>
              </View>
              <View style={[styles.deliveryStatusPill, { backgroundColor: `${statusColor(delivery.status)}1A` }]}>
                <Text style={[styles.deliveryStatusText, { color: statusColor(delivery.status) }]}>{formatStatus(delivery.status)}</Text>
              </View>
            </View>
          ))
        )}
      </ScrollView>

      <Modal visible={showActions} transparent animationType="fade" onRequestClose={() => setShowActions(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowActions(false)}>
          <View style={[styles.actionSheet, shadows.card]}>
            {driver.approvalStatus === 'pending' ? (
              <>
                <ActionRow label="Approve Driver" icon="✓" color={colors.success} onPress={handleApproveDriver} />
                <ActionRow label="Reject Driver" icon="✕" color={colors.error} onPress={handleRejectDriver} />
                <View style={styles.actionSheetDivider} />
              </>
            ) : null}
            <ActionRow
              label={driver.isActive ? 'Deactivate' : 'Activate'}
              icon={driver.isActive ? '🚫' : '✓'}
              color={driver.isActive ? colors.warning : colors.success}
              onPress={handleToggleStatus}
            />
            <ActionRow label="Delete Driver" icon="🗑" color={colors.error} onPress={handleDeleteDriver} />
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

function StatCard({ label, value, icon, color }: { label: string; value: number; icon: string; color: string }) {
  return (
    <View style={[styles.card, shadows.card, styles.statCard]}>
      <Text style={[styles.statIcon, { color }]}>{icon}</Text>
      <Text style={[styles.statValue, { color }]}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function InfoRow({ label, value, icon }: { label: string; value: string; icon: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoIcon}>{icon}</Text>
      <View style={styles.infoTextBox}>
        <Text style={styles.infoLabel}>{label}</Text>
        <Text style={styles.infoValue}>{value}</Text>
      </View>
    </View>
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

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.medium,
  },
  headerBarRight: { flexDirection: 'row', gap: spacing.medium },
  headerBarAction: { color: colors.white, fontSize: 16, fontWeight: '600' },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium },
  headerCard: { alignItems: 'center', marginBottom: spacing.large },
  avatar: { width: 80, height: 80, borderRadius: 40, alignItems: 'center', justifyContent: 'center' },
  avatarText: { fontSize: 32, fontWeight: 'bold' },
  driverName: { fontSize: 20, fontWeight: 'bold', marginTop: spacing.small + 4, textAlign: 'center' },
  badgeRow: { flexDirection: 'row', justifyContent: 'center', gap: spacing.small + 4, marginTop: spacing.small },
  badge: { paddingHorizontal: spacing.medium, paddingVertical: 6, borderRadius: 16 },
  badgeText: { color: colors.white, fontWeight: 'bold', fontSize: 12 },
  sectionTitle: { marginBottom: spacing.small + 4, marginTop: spacing.small },
  statsLoading: { marginVertical: spacing.medium },
  statsRow: { flexDirection: 'row', gap: spacing.small + 4, marginBottom: spacing.large },
  statCard: { flex: 1, alignItems: 'center' },
  statIcon: { fontSize: 22 },
  statValue: { fontSize: 24, fontWeight: 'bold', marginTop: spacing.small },
  statLabel: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  infoRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: spacing.small + 4 },
  infoIcon: { fontSize: 18, marginRight: spacing.small + 4, color: colors.textSecondary },
  infoTextBox: { flex: 1 },
  infoLabel: { fontSize: 12, color: colors.textSecondary },
  infoValue: { fontSize: 15, fontWeight: '600', marginTop: 2 },
  emptyDeliveries: { alignItems: 'center', paddingVertical: spacing.large },
  emptyDeliveriesIcon: { fontSize: 40, opacity: 0.4 },
  emptyDeliveriesText: { color: colors.textSecondary, marginTop: spacing.small },
  deliveryRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small },
  deliveryIcon: { fontSize: 20, marginRight: spacing.small + 4 },
  deliveryTextBox: { flex: 1 },
  deliveryTitle: { fontWeight: '600', fontSize: 14 },
  deliverySubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  deliveryStatusPill: { paddingHorizontal: spacing.small + 4, paddingVertical: 4, borderRadius: 8 },
  deliveryStatusText: { fontSize: 11, fontWeight: 'bold' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionSheetDivider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600' },
});
