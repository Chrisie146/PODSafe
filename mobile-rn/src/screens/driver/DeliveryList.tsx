// expects: no route params. Reads the signed-in driver from useAuthStore.
// navigation: tapping a delivery card should push DeliveryDetails with { deliveryId: delivery.id }.
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/driver/delivery_list_screen.dart. The QR-code-for-delivered
 * action (PODTokenService + PODQRCodeDialog) and "Get Directions"/swipe-to-action gestures
 * are not ported here — they depend on services/widgets outside the delivery domain
 * (pod_token_service, url_launcher) that aren't part of this task's scope. The 4-tab
 * (All/Pending/In Transit/Delivered) layout is collapsed into a single filter row of
 * buttons + search box driving one list, which is equivalent UI behavior without needing
 * a tab navigator dependency.
 */

type StatusFilter = 'all' | DeliveryStatus;

const FILTERS: { key: StatusFilter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'inTransit', label: 'In Transit' },
  { key: 'delivered', label: 'Delivered' },
];

function statusColor(status: DeliveryStatus): string {
  switch (status) {
    case 'delivered':
      return colors.success;
    case 'inTransit':
      return colors.info;
    case 'pending':
      return colors.warning;
    default:
      return colors.error;
  }
}

function statusLabel(status: DeliveryStatus): string {
  switch (status) {
    case 'delivered':
      return 'Delivered';
    case 'inTransit':
      return 'In Transit';
    case 'pending':
      return 'Pending';
    default:
      return 'Unknown';
  }
}

export interface DeliveryListProps {
  onSelectDelivery?: (delivery: Delivery) => void;
}

export default function DeliveryList({ onSelectDelivery }: DeliveryListProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const deliveries = useDeliveryStore((s) => s.deliveries);
  const isLoading = useDeliveryStore((s) => s.isLoading);
  const loadDriverDeliveries = useDeliveryStore((s) => s.loadDriverDeliveries);

  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    if (currentUser) {
      loadDriverDeliveries(currentUser.id);
    }
  }, [currentUser, loadDriverDeliveries]);

  const handleRefresh = useCallback(() => {
    if (currentUser) {
      loadDriverDeliveries(currentUser.id);
    }
  }, [currentUser, loadDriverDeliveries]);

  const filteredDeliveries = useMemo(() => {
    let result = deliveries;
    if (statusFilter !== 'all') {
      result = result.filter((d) => d.status === statusFilter);
    }
    const query = searchQuery.trim().toLowerCase();
    if (query.length > 0) {
      result = result.filter(
        (d) =>
          d.customerName.toLowerCase().includes(query) ||
          d.customerAddress.toLowerCase().includes(query) ||
          d.invoiceNumber.toLowerCase().includes(query),
      );
    }
    return result;
  }, [deliveries, statusFilter, searchQuery]);

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.searchInput}
        placeholder="Search by customer or address..."
        value={searchQuery}
        onChangeText={setSearchQuery}
      />

      <View style={styles.filterRow}>
        {FILTERS.map((filter) => (
          <Pressable
            key={filter.key}
            style={[styles.filterChip, statusFilter === filter.key && styles.filterChipActive]}
            onPress={() => setStatusFilter(filter.key)}
          >
            <Text style={[styles.filterChipText, statusFilter === filter.key && styles.filterChipTextActive]}>
              {filter.label}
            </Text>
          </Pressable>
        ))}
      </View>

      {isLoading && deliveries.length === 0 ? (
        <ActivityIndicator style={styles.loadingIndicator} color={colors.primary} />
      ) : (
        <FlatList
          data={filteredDeliveries}
          keyExtractor={(item) => item.id}
          onRefresh={handleRefresh}
          refreshing={isLoading}
          contentContainerStyle={styles.listContent}
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Text style={textStyles.bodyMedium}>
                {searchQuery.trim().length > 0 ? 'No matching deliveries' : 'No deliveries yet'}
              </Text>
            </View>
          }
          renderItem={({ item }) => (
            <DeliveryCard delivery={item} onPress={() => onSelectDelivery?.(item)} />
          )}
        />
      )}
    </View>
  );
}

function DeliveryCard({ delivery, onPress }: { delivery: Delivery; onPress: () => void }) {
  const color = statusColor(delivery.status);
  return (
    <Pressable style={styles.card} onPress={onPress}>
      <View style={styles.cardHeaderRow}>
        <View style={[styles.statusIconBox, { borderColor: color, backgroundColor: `${color}1A` }]}>
          <Text style={{ color }}>●</Text>
        </View>
        <View style={styles.cardHeaderText}>
          <Text style={[textStyles.bodyLarge, styles.customerName]} numberOfLines={1}>
            {delivery.customerName}
          </Text>
          <Text style={textStyles.bodySmall}>INV: {delivery.invoiceNumber}</Text>
        </View>
        <View style={[styles.statusChip, { borderColor: color }]}>
          <Text style={[styles.statusChipText, { color }]}>{statusLabel(delivery.status)}</Text>
        </View>
      </View>

      <View style={styles.addressBox}>
        <Text style={textStyles.bodyMedium} numberOfLines={2}>
          {delivery.customerAddress}
        </Text>
      </View>

      <View style={styles.metaRow}>
        {delivery.orderNumber ? (
          <Text style={textStyles.bodySmall}>Order: {delivery.orderNumber}</Text>
        ) : null}
        <Text style={textStyles.bodySmall}>
          {delivery.scheduledDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
        </Text>
      </View>

      <View style={[styles.ctaButton, { backgroundColor: colors.primary }]}>
        <Text style={textStyles.buttonText}>{delivery.status === 'pending' ? 'START NOW' : 'CONTINUE'}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  searchInput: {
    backgroundColor: colors.card,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: colors.divider,
    margin: spacing.medium,
    marginBottom: spacing.small,
    padding: spacing.small + 4,
  },
  filterRow: {
    flexDirection: 'row',
    paddingHorizontal: spacing.medium,
    marginBottom: spacing.small,
    gap: spacing.small,
  },
  filterChip: {
    paddingHorizontal: spacing.small + 4,
    paddingVertical: 6,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: colors.divider,
  },
  filterChipActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  filterChipText: { fontSize: 13, color: colors.textSecondary, fontWeight: '600' },
  filterChipTextActive: { color: colors.white },
  loadingIndicator: { marginTop: spacing.xLarge },
  listContent: { padding: spacing.medium },
  emptyState: { padding: spacing.large, alignItems: 'center' },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
  },
  cardHeaderRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small },
  statusIconBox: {
    width: 36,
    height: 36,
    borderRadius: radii.borderRadius - 2,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.small,
  },
  cardHeaderText: { flex: 1 },
  customerName: { fontWeight: 'bold' },
  statusChip: {
    borderWidth: 1,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small,
    paddingVertical: 4,
  },
  statusChipText: { fontSize: 11, fontWeight: '600' },
  addressBox: {
    backgroundColor: colors.background,
    borderRadius: radii.borderRadius,
    padding: spacing.small,
    marginBottom: spacing.small,
  },
  metaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.small,
  },
  ctaButton: {
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.small + 4,
    alignItems: 'center',
  },
});
