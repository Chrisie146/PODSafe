// expects route.params: { deliveryId: string }
import React, { useEffect } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { DeliveryStatus } from '../../models/delivery';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the DRIVER variant of lib/screens/driver/delivery_details_screen.dart
 * (NOT the admin one under lib/screens/admin/).
 *
 * Deviations from the Flutter source:
 * - "Capture Proof of Delivery" navigates to PodCapture and "Report Issue" navigates to
 *   ReportIssue (isAtDeliverySite computed the same way as the Dart source: status ===
 *   'inTransit'), wired via the `navigation` prop added in DriverStack.tsx's wiring pass.
 * - "View QR Code" (PODTokenService + PODQRCodeDialog) is NOT ported onto this screen —
 *   it's reachable from PodCapture's post-submit success dialog instead, which is the
 *   only place a token reliably exists yet.
 * - The Flutter screen takes the full `Delivery` object as a constructor arg (passed by
 *   the caller's in-memory list); this component instead takes only `deliveryId` via
 *   route params and loads it through the store, which is the more robust pattern for
 *   deep-linking / process restarts and matches how DeliveryRepository.getDeliveryById
 *   is meant to be used.
 */

interface DeliveryDetailsProps {
  route: { params: { deliveryId: string } };
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

function statusIcon(status: DeliveryStatus): string {
  switch (status) {
    case 'delivered':
      return '✓';
    case 'inTransit':
      return '🚚';
    case 'pending':
      return '⏳';
    default:
      return '✕';
  }
}

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

function formatDateTime(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export default function DeliveryDetails({ route, navigation }: DeliveryDetailsProps) {
  const { deliveryId } = route.params;
  const selectedDelivery = useDeliveryStore((s) => s.selectedDelivery);
  const isLoading = useDeliveryStore((s) => s.isLoading);
  const errorMessage = useDeliveryStore((s) => s.errorMessage);
  const loadDeliveryById = useDeliveryStore((s) => s.loadDeliveryById);
  const updateDeliveryStatus = useDeliveryStore((s) => s.updateDeliveryStatus);

  useEffect(() => {
    loadDeliveryById(deliveryId);
  }, [deliveryId, loadDeliveryById]);

  const delivery = selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  if (isLoading && !delivery) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  if (!delivery) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>{errorMessage ?? 'Delivery not found'}</Text>
      </View>
    );
  }

  const color = statusColor(delivery.status);
  const canCapturePOD = delivery.status === 'pending' || delivery.status === 'inTransit';

  const handleStartDelivery = () => {
    updateDeliveryStatus(delivery.id, 'inTransit');
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.card}>
        <View style={styles.statusRow}>
          <Text style={[styles.statusIcon, { color }]}>{statusIcon(delivery.status)}</Text>
          <View style={styles.statusTextBox}>
            <Text style={textStyles.bodySmall}>Status</Text>
            <Text style={[textStyles.heading3]}>{statusLabel(delivery.status)}</Text>
          </View>
          <View style={[styles.invoiceBadge, { backgroundColor: `${color}1A` }]}>
            <Text style={[styles.invoiceBadgeText, { color }]}>{delivery.invoiceNumber}</Text>
          </View>
        </View>
      </View>

      <View style={styles.card}>
        <Text style={textStyles.heading3}>Customer Information</Text>
        <View style={styles.divider} />
        <InfoRow label="Name" value={delivery.customerName} />
        <InfoRow label="Phone" value={delivery.customerPhone ?? 'N/A'} />
      </View>

      <View style={styles.card}>
        <Text style={textStyles.heading3}>Delivery Information</Text>
        <View style={styles.divider} />
        <InfoRow label="Delivery Address" value={delivery.customerAddress} />
        <InfoRow label="Scheduled Time" value={formatDateTime(delivery.scheduledDate)} />
        {delivery.notes ? <InfoRow label="Notes" value={delivery.notes} /> : null}
      </View>

      <View style={styles.card}>
        <Text style={textStyles.heading3}>Items</Text>
        <View style={styles.divider} />
        {delivery.items.map((item, index) => (
          <View key={`${item.description}-${index}`} style={styles.itemRow}>
            <Text style={textStyles.bodyMedium}>{item.description}</Text>
            <Text style={textStyles.bodySmall}>
              Qty: {item.quantity}
              {item.unit ? ` ${item.unit}` : ''}
            </Text>
          </View>
        ))}
      </View>

      <View style={styles.actions}>
        {delivery.status === 'pending' ? (
          <ActionButton label="Start Delivery" color={colors.primary} onPress={handleStartDelivery} />
        ) : null}
        {canCapturePOD ? (
          <ActionButton
            label="Capture Proof of Delivery"
            color={colors.success}
            onPress={() => navigation.navigate('PodCapture', { deliveryId: delivery.id })}
          />
        ) : null}
        <ActionButton
          label="Report Issue"
          color={colors.warning}
          onPress={() => navigation.navigate('ReportIssue', { deliveryId: delivery.id, isAtDeliverySite: delivery.status === 'inTransit' })}
        />
      </View>
    </ScrollView>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={textStyles.bodySmall}>{label}</Text>
      <Text style={[textStyles.bodyMedium, styles.infoValue]}>{value}</Text>
    </View>
  );
}

function ActionButton({ label, color, onPress }: { label: string; color: string; onPress: () => void }) {
  return (
    <Pressable style={[styles.actionButton, { backgroundColor: color }]} onPress={onPress}>
      <Text style={textStyles.buttonText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.medium },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
  },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small + 4 },
  statusRow: { flexDirection: 'row', alignItems: 'center' },
  statusIcon: { fontSize: 28, marginRight: spacing.small + 4 },
  statusTextBox: { flex: 1 },
  invoiceBadge: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6 },
  invoiceBadgeText: { fontWeight: 'bold', fontSize: 12 },
  infoRow: { marginBottom: spacing.small + 4 },
  infoValue: { marginTop: 4, fontWeight: '500' },
  itemRow: { marginBottom: spacing.small + 4 },
  actions: { marginTop: spacing.small, gap: spacing.small + 4 },
  actionButton: {
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.medium,
    alignItems: 'center',
  },
});
