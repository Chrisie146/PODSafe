import React, { useCallback, useEffect, useState } from 'react';
import { FlatList, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { AppIcon, Card, EmptyState, LoadingState, PrimaryButton, Screen, StatusChip } from '../../components/ui';

export interface DashboardProps {
  onSelectDelivery?: (delivery: Delivery) => void;
  onViewAllDeliveries?: () => void;
}

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

function formatDate(date: Date): string {
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function formatScheduledTime(date: Date): string {
  return date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}

export default function Dashboard({ onSelectDelivery, onViewAllDeliveries }: DashboardProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const deliveries = useDeliveryStore((s) => s.deliveries);
  const isLoading = useDeliveryStore((s) => s.isLoading);
  const loadDriverDeliveries = useDeliveryStore((s) => s.loadDriverDeliveries);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const loadData = useCallback(async () => {
    if (currentUser) {
      await loadDriverDeliveries(currentUser.id);
    }
  }, [currentUser, loadDriverDeliveries]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleRefresh = useCallback(async () => {
    setIsRefreshing(true);
    await loadData();
    setIsRefreshing(false);
  }, [loadData]);

  const activeDeliveries = deliveries.filter((delivery) => delivery.status === 'pending' || delivery.status === 'inTransit');
  const completedDeliveries = deliveries.filter((delivery) => delivery.status === 'delivered');
  const nextDelivery = activeDeliveries[0];

  if (isLoading && deliveries.length === 0) {
    return <Screen><LoadingState title="Loading today’s route" /></Screen>;
  }

  return (
    <Screen contentContainerStyle={styles.screenContent}>
      <FlatList
        data={activeDeliveries.slice(nextDelivery ? 1 : 0)}
        keyExtractor={(item) => item.id}
        refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={handleRefresh} colors={[colors.active]} />}
        contentContainerStyle={styles.listContent}
        ListHeaderComponent={(
          <>
            <View style={styles.intro}>
              <Text style={textStyles.heading2}>Today’s route</Text>
              <Text style={textStyles.bodyMedium}>Keep your evidence complete at every stop.</Text>
            </View>

            <Card style={styles.progressCard}>
              <View style={styles.progressHeader}>
                <View>
                  <Text style={textStyles.labelSmall}>Delivery progress</Text>
                  <Text style={styles.progressValue}>{completedDeliveries.length} of {deliveries.length} completed</Text>
                </View>
                <AppIcon name="truck" size={28} color={colors.active} />
              </View>
              <View accessibilityLabel={`${completedDeliveries.length} of ${deliveries.length} deliveries completed`} style={styles.progressTrack}>
                <View style={[styles.progressFill, { width: `${deliveries.length ? (completedDeliveries.length / deliveries.length) * 100 : 0}%` }]} />
              </View>
              <View style={styles.metricRow}>
                <Metric label="Active" value={activeDeliveries.length} tone="info" />
                <Metric label="Completed" value={completedDeliveries.length} tone="success" />
                <Metric label="Total" value={deliveries.length} tone="neutral" />
              </View>
            </Card>

            {nextDelivery ? (
              <View style={styles.nextSection}>
                <View style={styles.sectionHeader}>
                  <Text style={textStyles.heading3}>Next stop</Text>
                  <StatusChip label="Priority" tone="info" icon="truck" />
                </View>
                <DeliveryCard delivery={nextDelivery} primary routePosition={completedDeliveries.length + 1} onSelect={() => onSelectDelivery?.(nextDelivery)} />
              </View>
            ) : (
              <EmptyState title="Route complete" message="There are no active deliveries assigned to you right now." icon="check" />
            )}

            {activeDeliveries.length > 1 ? <Text style={[textStyles.heading3, styles.sectionTitle]}>Later today</Text> : null}
          </>
        )}
        renderItem={({ item, index }) => <DeliveryCard delivery={item} routePosition={completedDeliveries.length + index + 2} onSelect={() => onSelectDelivery?.(item)} />}
        ListEmptyComponent={
          completedDeliveries.length > 0 ? (
            <View style={styles.completedSection}>
              <View style={styles.sectionHeader}>
                <Text style={textStyles.heading3}>Completed</Text>
                {onViewAllDeliveries ? <PrimaryButton label="View all deliveries" onPress={onViewAllDeliveries} style={styles.viewAllButton} /> : null}
              </View>
              {completedDeliveries.slice(0, 3).map((delivery) => <CompletedDeliveryRow key={delivery.id} delivery={delivery} onSelect={() => onSelectDelivery?.(delivery)} />)}
            </View>
          ) : null
        }
        ListFooterComponent={
          completedDeliveries.length > 0 && activeDeliveries.length > 0 ? (
            <View style={styles.completedSection}>
              <View style={styles.sectionHeader}>
                <Text style={textStyles.heading3}>Completed</Text>
                {onViewAllDeliveries ? <PrimaryButton label="View all deliveries" onPress={onViewAllDeliveries} style={styles.viewAllButton} /> : null}
              </View>
              {completedDeliveries.slice(0, 3).map((delivery) => <CompletedDeliveryRow key={delivery.id} delivery={delivery} onSelect={() => onSelectDelivery?.(delivery)} />)}
            </View>
          ) : null
        }
      />
      {nextDelivery ? (
        <View style={styles.fixedAction}>
          <PrimaryButton label="Open next delivery" icon="arrowRight" onPress={() => onSelectDelivery?.(nextDelivery)} />
        </View>
      ) : null}
    </Screen>
  );
}

function Metric({ label, value, tone }: { label: string; value: number; tone: 'neutral' | 'info' | 'success' }) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricValue}>{value}</Text>
      <StatusChip label={label} tone={tone} />
    </View>
  );
}

function DeliveryCard({ delivery, primary = false, routePosition, onSelect }: { delivery: Delivery; primary?: boolean; routePosition?: number; onSelect: () => void }) {
  const actionLabel = delivery.status === 'inTransit' ? 'Continue delivery' : 'View delivery';
  return (
    <Card style={[styles.deliveryCard, primary && styles.primaryDeliveryCard]}>
      <View style={styles.deliveryCardHeader}>
        {routePosition ? <View accessibilityLabel={`Route stop ${routePosition}`} style={styles.stopNumber}><Text style={styles.stopNumberText}>{routePosition}</Text></View> : null}
        <View style={styles.deliverySummary}>
          <Text numberOfLines={2} style={textStyles.heading3}>{delivery.customerName}</Text>
          <Text numberOfLines={2} style={textStyles.bodySmall}>{delivery.customerAddress}</Text>
        </View>
        <StatusChip label={statusLabel[delivery.status]} tone={statusTone[delivery.status]} />
      </View>
      <View style={styles.deliveryMeta}>
        <View style={styles.metaItem}><AppIcon name="file" size={16} color={colors.contentSecondary} /><Text style={textStyles.bodySmall}>Invoice {delivery.invoiceNumber}</Text></View>
        <View style={styles.metaItem}><AppIcon name="package" size={16} color={colors.contentSecondary} /><Text style={textStyles.bodySmall}>{delivery.items.length} item{delivery.items.length === 1 ? '' : 's'}</Text></View>
        <View style={styles.metaItem}><AppIcon name="calendar" size={16} color={colors.contentSecondary} /><Text style={textStyles.bodySmall}>Scheduled {formatScheduledTime(delivery.scheduledDate)}</Text></View>
      </View>
      {!primary ? <PrimaryButton label={actionLabel} icon="arrowRight" onPress={onSelect} /> : null}
    </Card>
  );
}

function CompletedDeliveryRow({ delivery, onSelect }: { delivery: Delivery; onSelect: () => void }) {
  return (
    <Card padding="compact" style={styles.completedCard}>
      <View style={styles.completedText}>
        <Text numberOfLines={1} style={textStyles.label}>{delivery.customerName}</Text>
        <Text style={textStyles.bodySmall}>Invoice {delivery.invoiceNumber} · {formatDate(delivery.scheduledDate)}</Text>
      </View>
      <PrimaryButton label="View" onPress={onSelect} style={styles.compactAction} />
    </Card>
  );
}

const styles = StyleSheet.create({
  screenContent: { paddingHorizontal: 0 },
  listContent: { paddingBottom: spacing.xxLarge + 72, paddingHorizontal: spacing.medium, paddingVertical: spacing.medium },
  intro: { gap: spacing.xs, marginBottom: spacing.medium },
  progressCard: { gap: spacing.medium },
  progressHeader: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' },
  progressValue: { ...textStyles.heading3, marginTop: spacing.xs },
  progressTrack: { backgroundColor: colors.surfaceMuted, borderRadius: radii.inputRadius, height: 8, overflow: 'hidden' },
  progressFill: { backgroundColor: colors.verified, borderRadius: radii.inputRadius, height: '100%' },
  metricRow: { flexDirection: 'row', gap: spacing.small },
  metric: { flex: 1, gap: spacing.xs },
  metricValue: { ...textStyles.heading3 },
  nextSection: { marginTop: spacing.large },
  sectionHeader: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', marginBottom: spacing.small },
  sectionTitle: { marginBottom: spacing.small, marginTop: spacing.large },
  deliveryCard: { gap: spacing.medium, marginBottom: spacing.medium },
  primaryDeliveryCard: { borderColor: colors.active, borderWidth: 2 },
  deliveryCardHeader: { alignItems: 'flex-start', flexDirection: 'row', gap: spacing.small, justifyContent: 'space-between' },
  stopNumber: { alignItems: 'center', backgroundColor: colors.shell, borderRadius: 18, height: 36, justifyContent: 'center', width: 36 },
  stopNumberText: { ...textStyles.label, color: colors.onPrimary },
  deliverySummary: { flex: 1, gap: spacing.xs },
  deliveryMeta: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium },
  metaItem: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  completedSection: { marginTop: spacing.large },
  completedCard: { alignItems: 'center', flexDirection: 'row', gap: spacing.small, marginBottom: spacing.small },
  completedText: { flex: 1, gap: spacing.xs },
  compactAction: { paddingHorizontal: spacing.medium },
  viewAllButton: { paddingHorizontal: spacing.medium },
  fixedAction: { backgroundColor: colors.canvas, borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, padding: spacing.medium },
});
