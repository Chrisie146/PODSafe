import React, { useEffect } from 'react';
import { Linking, StyleSheet, Text, View } from 'react-native';
import { AppIcon, Card, ErrorState, LoadingState, PrimaryButton, Screen, SecondaryButton, StatusChip, SuccessButton } from '../../components/ui';
import { DeliveryStatus } from '../../models/delivery';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

interface DeliveryDetailsProps {
  route: { params: { deliveryId: string } };
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
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

const statusIcon: Record<DeliveryStatus, 'check' | 'truck' | 'calendar' | 'alert'> = {
  delivered: 'check',
  inTransit: 'truck',
  pending: 'calendar',
  failed: 'alert',
};

function formatDateTime(date: Date): string {
  return date.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
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
    return <Screen><LoadingState title="Loading delivery" /></Screen>;
  }

  if (!delivery) {
    return <Screen><ErrorState title="Delivery unavailable" message={errorMessage ?? 'This delivery could not be loaded.'} onAction={() => loadDeliveryById(deliveryId)} /></Screen>;
  }

  const canCapturePOD = delivery.status === 'pending' || delivery.status === 'inTransit';
  const proofCaptured = delivery.status === 'delivered' && Boolean(delivery.podId);
  const openDestination = async () => {
    const query = encodeURIComponent(delivery.customerAddress);
    try {
      await Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${query}`);
    } catch {
      return;
    }
  };
  return (
    <Screen scroll contentContainerStyle={styles.content}>
      <Card style={styles.statusCard}>
        <View style={styles.statusTopRow}>
          <View style={styles.statusIdentity}>
            <View style={styles.statusIconSurface}><AppIcon name={statusIcon[delivery.status]} size={28} color={colors.shell} /></View>
            <View style={styles.statusCopy}>
              <Text style={textStyles.labelSmall}>Delivery status</Text>
              <Text style={textStyles.heading2}>{statusLabel[delivery.status]}</Text>
            </View>
          </View>
          <StatusChip label={`Invoice ${delivery.invoiceNumber}`} tone={statusTone[delivery.status]} />
        </View>
        <Text style={textStyles.bodyMedium}>{delivery.customerName}</Text>
        <Text style={textStyles.bodySmall}>{delivery.customerAddress}</Text>
      </Card>

      <InfoSection title="Customer" icon="user">
        <InfoRow label="Name" value={delivery.customerName} />
        <InfoRow label="Phone" value={delivery.customerPhone ?? 'Not provided'} />
      </InfoSection>

      <InfoSection title="Delivery details" icon="location">
        <InfoRow label="Address" value={delivery.customerAddress} />
        <InfoRow label="Scheduled" value={formatDateTime(delivery.scheduledDate)} />
        {delivery.notes ? <InfoRow label="Instructions" value={delivery.notes} /> : null}
        <SecondaryButton label="Open destination in maps" icon="map" onPress={openDestination} />
      </InfoSection>

      <InfoSection title="Items" icon="package">
        {delivery.items.map((item, index) => (
          <View key={`${item.description}-${index}`} style={styles.itemRow}>
            <Text style={textStyles.label}>{item.description}</Text>
            <Text style={textStyles.bodySmall}>Quantity {item.quantity}{item.unit ? ` ${item.unit}` : ''}</Text>
          </View>
        ))}
      </InfoSection>

      <InfoSection title="Proof checklist" icon="clipboard">
        <ProofChecklistItem
          label="Delivery in progress"
          message="Start the delivery before capturing proof."
          complete={delivery.status === 'inTransit' || delivery.status === 'delivered'}
        />
        <ProofChecklistItem
          label="Photos, signature and location"
          message="Capture all required evidence before submitting proof."
          complete={proofCaptured}
        />
      </InfoSection>

      <View style={styles.actions}>
        {delivery.status === 'pending' ? <PrimaryButton label="Start delivery" icon="truck" onPress={() => updateDeliveryStatus(delivery.id, 'inTransit')} /> : null}
        {canCapturePOD ? <SuccessButton label="Capture proof of delivery" icon="camera" onPress={() => navigation.navigate('PodCapture', { deliveryId: delivery.id })} /> : null}
        <SecondaryButton label="Report an issue" icon="alert" onPress={() => navigation.navigate('ReportIssue', { deliveryId: delivery.id, isAtDeliverySite: delivery.status === 'inTransit' })} />
      </View>
    </Screen>
  );
}

function InfoSection({ title, icon, children }: { title: string; icon: 'user' | 'location' | 'package' | 'clipboard'; children: React.ReactNode }) {
  return (
    <Card style={styles.section}>
      <View style={styles.sectionHeader}><AppIcon name={icon} size={20} color={colors.shell} /><Text style={textStyles.heading3}>{title}</Text></View>
      <View style={styles.sectionContent}>{children}</View>
    </Card>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return <View style={styles.infoRow}><Text style={textStyles.labelSmall}>{label}</Text><Text style={textStyles.bodyMedium}>{value}</Text></View>;
}

function ProofChecklistItem({ label, message, complete }: { label: string; message: string; complete: boolean }) {
  return (
    <View style={styles.proofRow}>
      <View style={[styles.proofIcon, complete && styles.proofIconComplete]}><AppIcon name={complete ? 'check' : 'camera'} size={20} color={complete ? colors.shell : colors.contentSecondary} /></View>
      <View style={styles.proofCopy}>
        <Text style={textStyles.label}>{label}</Text>
        <Text style={textStyles.bodySmall}>{message}</Text>
      </View>
      <StatusChip label={complete ? 'Complete' : 'Required'} tone={complete ? 'success' : 'warning'} />
    </View>
  );
}

const styles = StyleSheet.create({
  content: { gap: spacing.medium, paddingBottom: spacing.xxLarge },
  statusCard: { gap: spacing.small },
  statusTopRow: { alignItems: 'flex-start', flexDirection: 'row', gap: spacing.small, justifyContent: 'space-between' },
  statusIdentity: { alignItems: 'center', flex: 1, flexDirection: 'row', gap: spacing.small },
  statusIconSurface: { alignItems: 'center', backgroundColor: colors.surfaceMuted, borderRadius: 24, height: 48, justifyContent: 'center', width: 48 },
  statusCopy: { flex: 1 },
  section: { gap: spacing.medium },
  sectionHeader: { alignItems: 'center', flexDirection: 'row', gap: spacing.small },
  sectionContent: { gap: spacing.medium },
  infoRow: { gap: spacing.xs },
  itemRow: { borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth, gap: spacing.xs, paddingBottom: spacing.medium },
  proofRow: { alignItems: 'center', flexDirection: 'row', gap: spacing.small },
  proofIcon: { alignItems: 'center', backgroundColor: colors.surfaceMuted, borderRadius: 20, height: 40, justifyContent: 'center', width: 40 },
  proofIconComplete: { backgroundColor: colors.verifiedMuted },
  proofCopy: { flex: 1, gap: spacing.xs },
  actions: { gap: spacing.small },
});
