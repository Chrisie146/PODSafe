import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { FlatList, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { AppIcon, Card, EmptyState, LoadingState, PrimaryButton, Screen, SearchField, StatusChip } from '../../components/ui';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

type StatusFilter = 'all' | DeliveryStatus;

const filters: { key: StatusFilter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'inTransit', label: 'In transit' },
  { key: 'delivered', label: 'Delivered' },
];

const statusTone: Record<DeliveryStatus, 'success' | 'info' | 'warning' | 'error'> = {
  delivered: 'success',
  inTransit: 'info',
  pending: 'warning',
  failed: 'error',
};

const statusLabel: Record<DeliveryStatus, string> = {
  delivered: 'Delivered',
  inTransit: 'In transit',
  pending: 'Pending',
  failed: 'Failed',
};

const statusIcon: Record<DeliveryStatus, 'check' | 'truck' | 'calendar' | 'alert'> = {
  delivered: 'check',
  inTransit: 'truck',
  pending: 'calendar',
  failed: 'alert',
};

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

  const loadDeliveries = useCallback(() => {
    if (currentUser) {
      return loadDriverDeliveries(currentUser.id);
    }
    return Promise.resolve();
  }, [currentUser, loadDriverDeliveries]);

  useEffect(() => {
    loadDeliveries();
  }, [loadDeliveries]);

  const filteredDeliveries = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    return deliveries.filter((delivery) => {
      const matchingStatus = statusFilter === 'all' || delivery.status === statusFilter;
      const matchingSearch = !query
        || delivery.customerName.toLowerCase().includes(query)
        || delivery.customerAddress.toLowerCase().includes(query)
        || delivery.invoiceNumber.toLowerCase().includes(query);
      return matchingStatus && matchingSearch;
    });
  }, [deliveries, searchQuery, statusFilter]);

  if (isLoading && deliveries.length === 0) {
    return <Screen><LoadingState title="Loading deliveries" /></Screen>;
  }

  return (
    <Screen contentContainerStyle={styles.screenContent}>
      <View style={styles.toolbar}>
        <SearchField value={searchQuery} onChangeText={setSearchQuery} placeholder="Search customer, address, or invoice" />
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterRow}>
          {filters.map((filter) => {
            const selected = statusFilter === filter.key;
            return (
              <Pressable
                key={filter.key}
                accessibilityRole="button"
                accessibilityLabel={`Filter deliveries by ${filter.label}`}
                accessibilityState={{ selected }}
                onPress={() => setStatusFilter(filter.key)}
                style={({ pressed }) => [styles.filterButton, selected && styles.filterButtonSelected, pressed && styles.filterButtonPressed]}
              >
                <Text style={[styles.filterButtonText, selected && styles.filterButtonTextSelected]}>{filter.label}</Text>
              </Pressable>
            );
          })}
        </ScrollView>
      </View>

      <FlatList
        data={filteredDeliveries}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
        onRefresh={loadDeliveries}
        refreshing={isLoading}
        ListHeaderComponent={<Text style={[textStyles.heading3, styles.resultCount]}>{filteredDeliveries.length} delivery{filteredDeliveries.length === 1 ? '' : 'ies'}</Text>}
        ListEmptyComponent={<EmptyState title={searchQuery.trim() ? 'No matching deliveries' : 'No deliveries assigned'} message={searchQuery.trim() ? 'Try another customer, address, or invoice number.' : 'New delivery work will appear here when it is assigned to you.'} icon="clipboard" />}
        renderItem={({ item }) => <DeliveryCard delivery={item} onSelect={() => onSelectDelivery?.(item)} />}
      />
    </Screen>
  );
}

function DeliveryCard({ delivery, onSelect }: { delivery: Delivery; onSelect: () => void }) {
  const actionLabel = delivery.status === 'pending' ? 'View delivery' : delivery.status === 'inTransit' ? 'Continue delivery' : 'Review delivery';
  return (
    <Card style={styles.card}>
      <View style={styles.cardHeader}>
        <View style={styles.deliveryIdentity}>
          <View style={styles.iconSurface}><AppIcon name={statusIcon[delivery.status]} size={22} color={colors.shell} /></View>
          <View style={styles.identityText}>
            <Text numberOfLines={1} style={textStyles.heading3}>{delivery.customerName}</Text>
            <Text style={textStyles.bodySmall}>Invoice {delivery.invoiceNumber}</Text>
          </View>
        </View>
        <StatusChip label={statusLabel[delivery.status]} tone={statusTone[delivery.status]} />
      </View>
      <View style={styles.addressRow}>
        <AppIcon name="location" size={18} color={colors.contentSecondary} />
        <Text numberOfLines={2} style={[textStyles.bodyMedium, styles.address]}>{delivery.customerAddress}</Text>
      </View>
      <View style={styles.metaRow}>
        {delivery.orderNumber ? <Text style={textStyles.bodySmall}>Order {delivery.orderNumber}</Text> : <Text style={textStyles.bodySmall}>No order reference</Text>}
        <Text style={textStyles.bodySmall}>{delivery.scheduledDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</Text>
      </View>
      <PrimaryButton label={actionLabel} icon="arrowRight" onPress={onSelect} />
    </Card>
  );
}

const styles = StyleSheet.create({
  screenContent: { paddingHorizontal: 0 },
  toolbar: { gap: spacing.small, paddingHorizontal: spacing.medium, paddingTop: spacing.medium },
  filterRow: { gap: spacing.small, paddingRight: spacing.medium },
  filterButton: { alignItems: 'center', backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.inputRadius, borderWidth: 1, justifyContent: 'center', minHeight: 48, paddingHorizontal: spacing.medium },
  filterButtonSelected: { backgroundColor: colors.shell, borderColor: colors.shell },
  filterButtonPressed: { opacity: 0.84 },
  filterButtonText: { ...textStyles.label, color: colors.contentSecondary },
  filterButtonTextSelected: { color: colors.onPrimary },
  listContent: { flexGrow: 1, padding: spacing.medium },
  resultCount: { marginBottom: spacing.medium },
  card: { gap: spacing.medium, marginBottom: spacing.medium },
  cardHeader: { alignItems: 'flex-start', flexDirection: 'row', gap: spacing.small, justifyContent: 'space-between' },
  deliveryIdentity: { alignItems: 'center', flex: 1, flexDirection: 'row', gap: spacing.small },
  iconSurface: { alignItems: 'center', backgroundColor: colors.surfaceMuted, borderRadius: radii.inputRadius, height: 44, justifyContent: 'center', width: 44 },
  identityText: { flex: 1, gap: spacing.xs },
  addressRow: { alignItems: 'flex-start', flexDirection: 'row', gap: spacing.small },
  address: { flex: 1 },
  metaRow: { flexDirection: 'row', justifyContent: 'space-between' },
});
