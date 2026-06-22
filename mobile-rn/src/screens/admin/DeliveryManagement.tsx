import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Modal, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { hasAnyPermission, hasPermission } from '../../permissions/permissionService';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/delivery_management_screen.dart
 * (`DeliveryManagementMobile`, verified against source on 2026-06-22) — 4-tab
 * (All/Pending/Active/Completed) delivery list with search, an export/bulk-upload menu,
 * and a permission-gated "New Delivery" FAB.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the
 * >1000px desktop branch lands in Phase 4.
 *
 * Deviations from the Flutter source:
 * - Subscribes to all 4 tabs simultaneously via `DeliveryRepository` directly (extended
 *   this pass with optional `status`/`orderByScheduledDate` filters), matching Flutter's
 *   `TabBarView` eager-mount behavior — same precedent as DriverManagement.tsx.
 * - `PermissionBuilder`/`PermissionGuard` widgets become direct `hasPermission()`/
 *   `hasAnyPermission()` checks (no shared PermissionGuard RN component exists yet for
 *   this single use site — not worth building one until a second screen needs it).
 * - The export menu's "Download Template"/"Export All Deliveries" depend on
 *   `delivery_export_service.dart`, which the migration plan already flags as having a
 *   broken native stub deferred to Phase 6 — these stay honest "Coming Soon" alerts
 *   rather than a half-built implementation. "Bulk Upload CSV" still navigates to a
 *   `BulkUpload` route (not built yet either, but consistent with this phase's other
 *   forward-references like CreateDriver/PodDetails).
 * - Tab bar is a custom Pressable strip (house convention), not a tab-bar library.
 */
const TABS: { key: DeliveryStatus | null; label: string }[] = [
  { key: null, label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'inTransit', label: 'Active' },
  { key: 'delivered', label: 'Completed' },
];

interface DeliveryManagementProps {
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

const deliveryRepository = new DeliveryRepository();

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

function statusIcon(status: DeliveryStatus): string {
  switch (status) {
    case 'pending':
      return '⏳';
    case 'inTransit':
      return '🚚';
    case 'delivered':
      return '✓';
    case 'failed':
      return '✕';
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

export default function DeliveryManagement({ navigation }: DeliveryManagementProps) {
  const currentUser = useAuthStore((s) => s.currentUser);

  const [activeTab, setActiveTab] = useState<DeliveryStatus | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [showMenu, setShowMenu] = useState(false);
  const [deliveriesByTab, setDeliveriesByTab] = useState<Record<string, Delivery[] | null>>({
    all: null,
    pending: null,
    inTransit: null,
    delivered: null,
  });

  const canExport = hasAnyPermission(currentUser, ['deliveriesManage', 'financeExport']);
  const canCreate = hasPermission(currentUser, 'deliveriesManage');

  useEffect(() => {
    if (!currentUser) return;

    const unsubscribes = TABS.map(({ key }) =>
      deliveryRepository.subscribeToCompanyDeliveries(
        currentUser.companyId,
        (deliveries) => setDeliveriesByTab((prev) => ({ ...prev, [key ?? 'all']: deliveries })),
        () => setDeliveriesByTab((prev) => ({ ...prev, [key ?? 'all']: [] })),
        { status: key ?? undefined, orderByScheduledDate: true },
      ),
    );

    return () => unsubscribes.forEach((unsub) => unsub());
  }, [currentUser]);

  const activeDeliveries = deliveriesByTab[activeTab ?? 'all'];
  const q = searchQuery.trim().toLowerCase();
  const filteredDeliveries =
    activeDeliveries?.filter(
      (d) => q.length === 0 || d.customerName.toLowerCase().includes(q) || d.customerAddress.toLowerCase().includes(q) || d.invoiceNumber.toLowerCase().includes(q),
    ) ?? null;

  const comingSoon = (label: string) => {
    setShowMenu(false);
    Alert.alert(label, 'Coming Soon');
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>Delivery Management</Text>
        {canExport ? (
          <Pressable onPress={() => setShowMenu(true)}>
            <Text style={styles.headerBarIcon}>⬇</Text>
          </Pressable>
        ) : null}
      </View>

      <View style={styles.tabStrip}>
        {TABS.map((tab) => (
          <Pressable key={tab.label} style={[styles.tabButton, activeTab === tab.key && styles.tabButtonActive]} onPress={() => setActiveTab(tab.key)}>
            <Text style={[styles.tabButtonText, activeTab === tab.key && styles.tabButtonTextActive]}>{tab.label}</Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.searchBox}>
        <Text style={styles.searchIcon}>🔍</Text>
        <TextInput style={styles.searchInput} placeholder="Search by customer name, address, or invoice..." value={searchQuery} onChangeText={setSearchQuery} />
        {searchQuery.length > 0 ? (
          <Pressable onPress={() => setSearchQuery('')}>
            <Text style={styles.searchClear}>✕</Text>
          </Pressable>
        ) : null}
      </View>

      {filteredDeliveries === null ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : filteredDeliveries.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.emptyIcon}>🚚</Text>
          <Text style={styles.emptyText}>
            {searchQuery.length > 0 ? 'No matching deliveries' : activeTab === null ? 'No deliveries yet' : `No ${statusLabel(activeTab).toLowerCase()} deliveries`}
          </Text>
          {searchQuery.length === 0 ? <Text style={styles.emptyHint}>Tap + to create a new delivery</Text> : null}
        </View>
      ) : (
        <FlatList
          data={filteredDeliveries}
          keyExtractor={(delivery) => delivery.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => <DeliveryCard delivery={item} onPress={() => navigation.navigate('DeliveryDetails', { deliveryId: item.id })} />}
        />
      )}

      {canCreate ? (
        <Pressable style={styles.fab} onPress={() => navigation.navigate('CreateDelivery')}>
          <Text style={styles.fabIcon}>＋</Text>
          <Text style={styles.fabLabel}>New Delivery</Text>
        </Pressable>
      ) : null}

      <Modal visible={showMenu} transparent animationType="fade" onRequestClose={() => setShowMenu(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowMenu(false)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <ActionRow label="Bulk Upload CSV" icon="📤" onPress={() => { setShowMenu(false); navigation.navigate('BulkUpload'); }} />
            <ActionRow label="Download Template" icon="⬇" onPress={() => comingSoon('Download Template')} />
            <ActionRow label="Export All Deliveries" icon="📊" onPress={() => comingSoon('Export All Deliveries')} />
          </View>
        </Pressable>
      </Modal>
    </View>
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

function DeliveryCard({ delivery, onPress }: { delivery: Delivery; onPress: () => void }) {
  const color = statusColor(delivery.status);

  return (
    <Pressable style={[styles.card, shadows.card]} onPress={onPress}>
      <View style={styles.cardTopRow}>
        <View style={[styles.statusIconBox, { backgroundColor: `${color}1A` }]}>
          <Text style={[styles.statusIconText, { color }]}>{statusIcon(delivery.status)}</Text>
        </View>
        <View style={styles.cardTextBox}>
          <Text style={styles.cardName} numberOfLines={1}>
            {delivery.customerName}
          </Text>
          {delivery.customerNumber ? <Text style={styles.cardMeta}>Customer #: {delivery.customerNumber}</Text> : null}
          {delivery.orderNumber ? <Text style={styles.cardMeta}>Order: {delivery.orderNumber}</Text> : null}
          <Text style={styles.cardMeta}>Invoice: {delivery.invoiceNumber}</Text>
        </View>
        <View style={[styles.statusPill, { backgroundColor: color }]}>
          <Text style={styles.statusPillText}>{statusLabel(delivery.status)}</Text>
        </View>
      </View>

      <View style={styles.divider} />

      <View style={styles.cardRow}>
        <Text style={styles.cardRowIcon}>📍</Text>
        <Text style={styles.cardRowText} numberOfLines={1}>
          {delivery.customerAddress}
        </Text>
      </View>
      <View style={styles.cardRow}>
        <Text style={styles.cardRowIcon}>📅</Text>
        <Text style={styles.cardRowText}>{delivery.scheduledDate.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' })}</Text>
        <View style={styles.cardRowSpacer} />
        {delivery.items.length > 0 ? (
          <Text style={styles.cardRowText}>
            📦 {delivery.items.length} item{delivery.items.length > 1 ? 's' : ''}
          </Text>
        ) : null}
      </View>
      {delivery.vehicleUsed ? (
        <View style={styles.cardRow}>
          <Text style={styles.cardRowIcon}>🚙</Text>
          <Text style={styles.cardRowText}>Vehicle: {delivery.vehicleUsed}</Text>
        </View>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  headerBarIcon: { fontSize: 20, color: colors.white },
  tabStrip: { flexDirection: 'row', backgroundColor: colors.primary },
  tabButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.medium, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabButtonActive: { borderBottomColor: colors.white },
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
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.medium },
  cardTopRow: { flexDirection: 'row', alignItems: 'flex-start' },
  statusIconBox: { width: 44, height: 44, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  statusIconText: { fontSize: 20 },
  cardTextBox: { flex: 1, marginRight: spacing.small },
  cardName: { fontSize: 16, fontWeight: '600' },
  cardMeta: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  statusPill: { borderRadius: 12, paddingHorizontal: spacing.small + 4, paddingVertical: 6, alignSelf: 'flex-start' },
  statusPillText: { color: colors.white, fontSize: 12, fontWeight: 'bold' },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  cardRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small },
  cardRowIcon: { fontSize: 14, marginRight: spacing.small },
  cardRowText: { fontSize: 13, color: colors.textSecondary, flexShrink: 1 },
  cardRowSpacer: { flex: 1 },
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
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600' },
});
