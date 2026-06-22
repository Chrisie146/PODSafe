// expects: no route params. Reads the signed-in driver from useAuthStore.
import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/driver/dashboard_screen.dart. Only the "Deliveries" tab
 * content is ported here (stats + pending + completed-capped-3) — the Dart source's
 * "Claims" TabBarView tab duplicates my_claims_screen.dart with a simpler inline list;
 * MyClaims.tsx is reachable from DriverStack's header instead, rather than porting that
 * redundant second claims UI. Likewise not ported: the map-view toggle
 * (DeliveryMapWidget), card/list view toggle, swipe-to-start-delivery gestures, and the
 * delivery options bottom sheet (Get Directions / Call Customer, the latter already a
 * "coming soon" stub in the Dart source) — DriverStack.tsx wires plain tap navigation
 * instead, which reaches the same destinations (PodCapture, DeliveryDetails,
 * DeliveryList) without that extra interaction surface.
 */

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
      return 'Failed';
  }
}

function formatDate(date: Date): string {
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

export interface DashboardProps {
  onSelectDelivery?: (delivery: Delivery) => void;
  onViewAllDeliveries?: () => void;
}

export default function Dashboard({ onSelectDelivery, onViewAllDeliveries }: DashboardProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const deliveries = useDeliveryStore((s) => s.deliveries);
  const isLoading = useDeliveryStore((s) => s.isLoading);
  const loadDriverDeliveries = useDeliveryStore((s) => s.loadDriverDeliveries);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const loadData = useCallback(() => {
    if (currentUser) {
      loadDriverDeliveries(currentUser.id);
    }
  }, [currentUser, loadDriverDeliveries]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleRefresh = useCallback(() => {
    setIsRefreshing(true);
    loadData();
    setIsRefreshing(false);
  }, [loadData]);

  const pendingDeliveries = deliveries.filter((d) => d.status !== 'delivered' && d.status !== 'failed');
  const completedDeliveries = deliveries.filter((d) => d.status === 'delivered');
  const completed = completedDeliveries.length;
  const pending = deliveries.length - completed;

  return (
    <View style={styles.container}>
      <View style={styles.statsCard}>
        <Text style={textStyles.heading3}>Today&apos;s Progress</Text>
        <View style={styles.statsRow}>
          <StatItem label="Total Deliveries" value={deliveries.length} color={colors.info} />
          <StatItem label="Completed" value={completed} color={colors.success} />
          <StatItem label="Pending" value={pending} color={colors.warning} />
        </View>
      </View>

      {isLoading && deliveries.length === 0 ? (
        <ActivityIndicator style={styles.loadingIndicator} color={colors.primary} />
      ) : (
        <FlatList
          data={pendingDeliveries}
          keyExtractor={(item) => item.id}
          refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={handleRefresh} colors={[colors.primary]} />}
          contentContainerStyle={styles.listContent}
          ListHeaderComponent={
            <Text style={[textStyles.heading3, styles.sectionHeader]}>
              {pendingDeliveries.length > 0 ? `${pendingDeliveries.length} Pending` : 'All Caught Up'}
            </Text>
          }
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Text style={textStyles.bodyMedium}>No pending deliveries at the moment</Text>
            </View>
          }
          renderItem={({ item, index }) => (
            <PendingDeliveryCard delivery={item} isNext={index === 0} onPress={() => onSelectDelivery?.(item)} />
          )}
          ListFooterComponent={
            completedDeliveries.length > 0 ? (
              <View style={styles.completedSection}>
                <View style={styles.completedHeaderRow}>
                  <Text style={textStyles.heading3}>Completed ({completedDeliveries.length})</Text>
                  {onViewAllDeliveries ? (
                    <Pressable onPress={onViewAllDeliveries}>
                      <Text style={styles.viewAllText}>View All</Text>
                    </Pressable>
                  ) : null}
                </View>
                {completedDeliveries.slice(0, 3).map((delivery) => (
                  <CompletedDeliveryCard key={delivery.id} delivery={delivery} onPress={() => onSelectDelivery?.(delivery)} />
                ))}
              </View>
            ) : null
          }
        />
      )}
    </View>
  );
}

function StatItem({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <View style={styles.statItem}>
      <View style={[styles.statBadge, { backgroundColor: `${color}1A` }]}>
        <Text style={[styles.statValue, { color }]}>{value}</Text>
      </View>
      <Text style={textStyles.bodySmall}>{label}</Text>
    </View>
  );
}

function PendingDeliveryCard({ delivery, isNext, onPress }: { delivery: Delivery; isNext: boolean; onPress: () => void }) {
  const color = statusColor(delivery.status);
  return (
    <Pressable style={[styles.card, isNext && styles.cardNext]} onPress={onPress}>
      <View style={styles.cardHeaderRow}>
        {isNext ? (
          <View style={styles.nextBadge}>
            <Text style={styles.nextBadgeText}>NEXT UP</Text>
          </View>
        ) : null}
        <Text style={[textStyles.heading3, styles.customerName]} numberOfLines={2}>
          {delivery.customerName}
        </Text>
        <View style={[styles.statusChip, { borderColor: color }]}>
          <Text style={[styles.statusChipText, { color }]}>{statusLabel(delivery.status)}</Text>
        </View>
      </View>

      <View style={styles.addressBox}>
        <Text style={textStyles.bodyMedium} numberOfLines={2}>
          {delivery.customerAddress}
        </Text>
      </View>

      <Text style={[textStyles.bodySmall, styles.invoiceText]}>
        INV: {delivery.invoiceNumber}
        {delivery.items.length > 0 ? ` • ${delivery.items.length} items` : ''}
      </Text>

      <View style={[styles.ctaButton, { backgroundColor: colors.primary }]}>
        <Text style={textStyles.buttonText}>{isNext ? 'START DELIVERY' : 'BEGIN DELIVERY'}</Text>
      </View>
    </Pressable>
  );
}

function CompletedDeliveryCard({ delivery, onPress }: { delivery: Delivery; onPress: () => void }) {
  return (
    <Pressable style={styles.completedCard} onPress={onPress}>
      <Text style={textStyles.bodyMedium}>{delivery.customerName}</Text>
      <Text style={textStyles.bodySmall}>
        INV: {delivery.invoiceNumber} • {formatDate(delivery.scheduledDate)}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  loadingIndicator: { marginTop: spacing.xLarge },
  listContent: { padding: spacing.medium },
  sectionHeader: { marginBottom: spacing.small },
  emptyState: { padding: spacing.large, alignItems: 'center' },
  statsCard: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    margin: spacing.medium,
    padding: spacing.medium,
  },
  statsRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: spacing.medium },
  statItem: { alignItems: 'center', flex: 1 },
  statBadge: {
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
    marginBottom: spacing.small / 2,
  },
  statValue: { fontSize: 20, fontWeight: 'bold' },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
  },
  cardNext: { borderWidth: 2, borderColor: colors.primary },
  cardHeaderRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small },
  nextBadge: {
    backgroundColor: colors.primary,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small,
    paddingVertical: 4,
    marginRight: spacing.small,
  },
  nextBadgeText: { color: colors.white, fontSize: 11, fontWeight: 'bold' },
  customerName: { flex: 1 },
  statusChip: {
    borderWidth: 1,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small,
    paddingVertical: 4,
  },
  statusChipText: { fontSize: 12, fontWeight: '600' },
  addressBox: {
    backgroundColor: colors.background,
    borderRadius: radii.borderRadius,
    padding: spacing.small,
    marginBottom: spacing.small,
  },
  invoiceText: { marginBottom: spacing.medium },
  ctaButton: {
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.medium,
    alignItems: 'center',
  },
  completedSection: { marginTop: spacing.large },
  completedHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.small },
  viewAllText: { color: colors.primary, fontWeight: '600' },
  completedCard: {
    backgroundColor: colors.card,
    borderRadius: radii.borderRadius,
    padding: spacing.medium,
    marginBottom: spacing.small,
  },
});
