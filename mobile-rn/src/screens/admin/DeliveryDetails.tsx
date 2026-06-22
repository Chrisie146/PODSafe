// expects route.params: { deliveryId: string }
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Image, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import Share, { Social } from 'react-native-share';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { PodRepository } from '../../repositories/podRepository';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { PodRecord } from '../../models/pod';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the ADMIN variant of lib/screens/admin/delivery_details_screen.dart
 * (verified against source on 2026-06-22) — NOT the driver variant under
 * lib/screens/driver/, which is a separate, already-ported component.
 *
 * Deviations from the Flutter source:
 * - Takes only `deliveryId` via route params and loads through useDeliveryStore
 *   (loadDeliveryById/selectedDelivery), same robustness argument as DriverDetails.tsx
 *   and the driver variant of this screen, instead of requiring the caller to pass the
 *   full Delivery object.
 * - Driver info uses useUserManagementStore.loadUserById/selectedUser instead of an
 *   inline Firestore read.
 * - Bug fix: "Copy Link" and "Share via WhatsApp" were no-op buttons in the Dart source
 *   (TODO comments, snackbar falsely claims success) — flagged in the Phase 3 inventory
 *   as dead/misleading UI. This port wires them for real: Copy Link uses
 *   @react-native-clipboard/clipboard's Clipboard.setString(), and Share uses
 *   react-native-share's shareSingle({ social: Social.WHATSAPP }), surfacing a real error
 *   if WhatsApp isn't installed rather than a false "coming soon" success toast.
 * - Third-party document thumbnails open a full-screen Modal image viewer (pinch-zoom via
 *   PinchGestureHandler is not wired — plain Image with resizeMode="contain" — since no
 *   gesture-handler viewer is installed yet; this is a acceptable a degraded-but-honest
 *   equivalent of the Dart source's InteractiveViewer pinch-to-zoom).
 * - "View POD" navigates to a `PodDetails` route that doesn't exist yet — pod_details_screen
 *   needs FirebaseStorageImage/LocationMapWidget/PodImageDownloadService/
 *   PodPdfGeneratorService, none ported yet, so this is a forward reference like
 *   DriverDetails.tsx's CreateDriver navigation.
 */
interface DeliveryDetailsProps {
  route: { params: { deliveryId: string } };
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void; goBack: () => void };
}

const podRepository = new PodRepository();

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

function statusText(status: DeliveryStatus): string {
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

function formatLongDate(date: Date): string {
  return date.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
}

function formatDateTime(date: Date): string {
  const d = date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  const t = date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  return `${d} • ${t}`;
}

export default function DeliveryDetails({ route, navigation }: DeliveryDetailsProps) {
  const { deliveryId } = route.params;
  const selectedDelivery = useDeliveryStore((s) => s.selectedDelivery);
  const isLoading = useDeliveryStore((s) => s.isLoading);
  const loadDeliveryById = useDeliveryStore((s) => s.loadDeliveryById);
  const deleteDelivery = useDeliveryStore((s) => s.deleteDelivery);

  const driverUser = useUserManagementStore((s) => s.selectedUser);
  const loadUserById = useUserManagementStore((s) => s.loadUserById);

  const [pod, setPod] = useState<PodRecord | null | undefined>(undefined);
  const [fullScreenImage, setFullScreenImage] = useState<string | null>(null);

  useEffect(() => {
    loadDeliveryById(deliveryId);
  }, [deliveryId, loadDeliveryById]);

  const delivery: Delivery | null = selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  useEffect(() => {
    if (!delivery) return;
    if (!delivery.isThirdPartyTransport) {
      loadUserById(delivery.driverId);
    }
    if (delivery.status === 'delivered') {
      podRepository.getPodById(delivery.id).then(setPod);
    } else {
      setPod(null);
    }
  }, [delivery, loadUserById]);

  const handleCopyLink = (uploadToken: string) => {
    Clipboard.setString(`https://podsafe.app/upload/${uploadToken}`);
    Alert.alert('Copied', 'Link copied to clipboard');
  };

  const handleShareWhatsApp = async (uploadToken: string) => {
    try {
      await Share.shareSingle({
        social: Social.Whatsapp,
        message: `https://podsafe.app/upload/${uploadToken}`,
      });
    } catch (e) {
      Alert.alert('Error', `Could not open WhatsApp: ${(e as Error).message}`);
    }
  };

  const handleDelete = () => {
    Alert.alert('Delete Delivery', 'Are you sure you want to delete this delivery? This action cannot be undone.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          const ok = await deleteDelivery(deliveryId);
          if (ok) {
            Alert.alert('Success', 'Delivery deleted successfully');
            navigation.goBack();
          } else {
            Alert.alert('Error', 'Error deleting delivery');
          }
        },
      },
    ]);
  };

  if (isLoading || !delivery) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => navigation.goBack()}>
          <Text style={styles.headerBarAction}>‹ Back</Text>
        </Pressable>
        <Text style={textStyles.heading3}>Delivery Details</Text>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => navigation.navigate('CreateDelivery', { deliveryId: delivery.id })}>
            <Text style={styles.headerBarAction}>✎</Text>
          </Pressable>
          <Pressable onPress={handleDelete}>
            <Text style={styles.headerBarAction}>🗑</Text>
          </Pressable>
        </View>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        <View style={styles.statusBadgeRow}>
          <View style={[styles.statusBadge, { borderColor: statusColor(delivery.status), backgroundColor: `${statusColor(delivery.status)}1A` }]}>
            <Text style={[styles.statusBadgeIcon, { color: statusColor(delivery.status) }]}>{statusIcon(delivery.status)}</Text>
            <Text style={[styles.statusBadgeText, { color: statusColor(delivery.status) }]}>{statusText(delivery.status)}</Text>
          </View>
        </View>

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Customer Information</Text>
        <View style={[styles.card, shadows.card]}>
          <InfoRow label="Name" value={delivery.customerName} />
          <InfoRow label="Address" value={delivery.customerAddress} />
          {delivery.customerPhone ? <InfoRow label="Phone" value={delivery.customerPhone} /> : null}
        </View>

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Information</Text>
        <View style={[styles.card, shadows.card]}>
          {delivery.orderNumber ? <InfoRow label="Order Number" value={delivery.orderNumber} /> : null}
          <InfoRow label="Invoice Number" value={delivery.invoiceNumber} />
          {delivery.vehicleUsed ? <InfoRow label="Vehicle Used" value={delivery.vehicleUsed} /> : null}
          <InfoRow label="Scheduled Date" value={formatLongDate(delivery.scheduledDate)} />
          <InfoRow label="Created" value={formatDateTime(delivery.createdAt)} />
          {delivery.deliveredAt ? <InfoRow label="Delivered" value={formatDateTime(delivery.deliveredAt)} /> : null}
        </View>

        {delivery.isThirdPartyTransport ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Third-Party Transport</Text>
            <View style={[styles.card, shadows.card, styles.thirdPartyCard]}>
              <View style={styles.thirdPartyHeaderRow}>
                <Text style={styles.thirdPartyHeaderIcon}>🚚</Text>
                <Text style={styles.thirdPartyHeaderText}>External Transport Provider</Text>
              </View>
              <View style={styles.divider} />
              <InfoRow label="Provider" value={delivery.thirdPartyProviderName ?? 'N/A'} />
              {delivery.thirdPartyDriverName ? <InfoRow label="Driver" value={delivery.thirdPartyDriverName} /> : null}
              {delivery.thirdPartyDriverPhone ? <InfoRow label="Phone" value={delivery.thirdPartyDriverPhone} /> : null}
              {delivery.thirdPartyVehicleInfo ? <InfoRow label="Vehicle" value={delivery.thirdPartyVehicleInfo} /> : null}

              {delivery.uploadToken ? (
                <>
                  <View style={styles.divider} />
                  <Text style={styles.uploadLinkLabel}>🔗 Upload Link</Text>
                  <View style={styles.uploadLinkBox}>
                    <Text selectable style={styles.uploadLinkText}>{`https://podsafe.app/upload/${delivery.uploadToken}`}</Text>
                  </View>
                  <View style={styles.uploadLinkButtonRow}>
                    <Pressable style={styles.primaryButton} onPress={() => handleCopyLink(delivery.uploadToken!)}>
                      <Text style={textStyles.buttonText}>📋 Copy Link</Text>
                    </Pressable>
                    <Pressable style={styles.secondaryButton} onPress={() => handleShareWhatsApp(delivery.uploadToken!)}>
                      <Text style={styles.secondaryButtonText}>↗ Share</Text>
                    </Pressable>
                  </View>
                </>
              ) : null}

              {delivery.thirdPartyDocs && delivery.thirdPartyDocs.length > 0 ? (
                <>
                  <View style={styles.divider} />
                  <Text style={styles.docsUploadedLabel}>✓ Documents Uploaded ({delivery.thirdPartyDocs.length})</Text>
                  <View style={styles.thumbnailRow}>
                    {delivery.thirdPartyDocs.map((url) => (
                      <Pressable key={url} onPress={() => setFullScreenImage(url)}>
                        <Image source={{ uri: url }} style={styles.thumbnail} resizeMode="cover" />
                      </Pressable>
                    ))}
                  </View>
                </>
              ) : null}
            </View>
          </>
        ) : (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Driver Information</Text>
            {!driverUser ? (
              <ActivityIndicator color={colors.primary} style={styles.statsLoading} />
            ) : (
              <View style={[styles.card, shadows.card]}>
                <InfoRow label="Name" value={driverUser.fullName} />
                {driverUser.email ? <InfoRow label="Email" value={driverUser.email} /> : null}
                {driverUser.vehicleInfo ? <InfoRow label="Vehicle Registration" value={driverUser.vehicleInfo} /> : null}
              </View>
            )}
          </>
        )}

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Items ({delivery.items.length})</Text>
        {delivery.items.map((item, i) => (
          <View key={i} style={[styles.card, shadows.card, styles.itemRow]}>
            <View style={styles.itemQtyBadge}>
              <Text style={styles.itemQtyText}>{item.quantity}</Text>
            </View>
            <View style={styles.itemTextBox}>
              <Text style={styles.itemDescription}>{item.description}</Text>
              {item.unit ? <Text style={styles.itemUnit}>Unit: {item.unit}</Text> : null}
            </View>
          </View>
        ))}

        {delivery.notes ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Notes</Text>
            <View style={[styles.card, shadows.card]}>
              <Text style={styles.notesText}>{delivery.notes}</Text>
            </View>
          </>
        ) : null}

        {delivery.status === 'delivered' ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Proof of Delivery</Text>
            {pod === undefined ? (
              <ActivityIndicator color={colors.primary} style={styles.statsLoading} />
            ) : pod ? (
              <Pressable style={[styles.card, shadows.card, styles.podRow]} onPress={() => navigation.navigate('PodDetails', { deliveryId: delivery.id })}>
                <Text style={styles.podIcon}>🧾</Text>
                <View style={styles.podTextBox}>
                  <Text style={styles.podTitle}>POD Available</Text>
                  <Text style={styles.podSubtitle}>Tap to view signature, photo, and GPS</Text>
                </View>
                <Text style={styles.podChevron}>›</Text>
              </Pressable>
            ) : (
              <View style={[styles.card, shadows.card, styles.podRow]}>
                <Text style={styles.podIconMuted}>ⓘ</Text>
                <Text style={styles.podSubtitle}>No POD available for this delivery</Text>
              </View>
            )}
          </>
        ) : null}
      </ScrollView>

      <Modal visible={fullScreenImage != null} transparent animationType="fade" onRequestClose={() => setFullScreenImage(null)}>
        <View style={styles.imageModalBackdrop}>
          {fullScreenImage ? <Image source={{ uri: fullScreenImage }} style={styles.fullScreenImage} resizeMode="contain" /> : null}
          <Pressable style={styles.imageModalClose} onPress={() => setFullScreenImage(null)}>
            <Text style={styles.imageModalCloseText}>✕</Text>
          </Pressable>
        </View>
      </Modal>
    </View>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
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
  statusBadgeRow: { alignItems: 'center', marginBottom: spacing.large },
  statusBadge: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, borderWidth: 2, borderRadius: 24, paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4 },
  statusBadgeIcon: { fontSize: 18 },
  statusBadgeText: { fontWeight: 'bold', fontSize: 16 },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  sectionTitle: { marginBottom: spacing.small + 4 },
  infoRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: spacing.small },
  infoLabel: { width: 120, color: colors.textSecondary, fontWeight: '500' },
  infoValue: { flex: 1, fontWeight: '600' },
  thirdPartyCard: { backgroundColor: `${colors.warning}0D` },
  thirdPartyHeaderRow: { flexDirection: 'row', alignItems: 'center' },
  thirdPartyHeaderIcon: { fontSize: 18, marginRight: spacing.small },
  thirdPartyHeaderText: { fontSize: 16, fontWeight: 'bold', color: colors.warning },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  uploadLinkLabel: { fontWeight: 'bold', fontSize: 14, marginBottom: spacing.small },
  uploadLinkBox: { backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4 },
  uploadLinkText: { fontSize: 12, fontFamily: 'monospace' },
  uploadLinkButtonRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.small + 4 },
  primaryButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  secondaryButton: { borderWidth: 1, borderColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  secondaryButtonText: { color: colors.primary, fontWeight: '600' },
  docsUploadedLabel: { fontWeight: 'bold', color: colors.success, marginBottom: spacing.small },
  thumbnailRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  thumbnail: { width: 80, height: 80, borderRadius: 8, borderWidth: 1, borderColor: colors.divider },
  statsLoading: { marginVertical: spacing.medium },
  itemRow: { flexDirection: 'row', alignItems: 'center' },
  itemQtyBadge: { width: 36, height: 36, borderRadius: 18, backgroundColor: `${colors.primary}1A`, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  itemQtyText: { color: colors.primary, fontWeight: 'bold' },
  itemTextBox: { flex: 1 },
  itemDescription: { fontWeight: '600' },
  itemUnit: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  notesText: { fontSize: 15 },
  podRow: { flexDirection: 'row', alignItems: 'center' },
  podIcon: { fontSize: 28, color: colors.success, marginRight: spacing.medium },
  podIconMuted: { fontSize: 28, color: colors.divider, marginRight: spacing.medium },
  podTextBox: { flex: 1 },
  podTitle: { fontSize: 16, fontWeight: '600' },
  podSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  podChevron: { fontSize: 22, color: colors.textSecondary },
  imageModalBackdrop: { flex: 1, backgroundColor: 'black', alignItems: 'center', justifyContent: 'center' },
  fullScreenImage: { width: '100%', height: '100%' },
  imageModalClose: { position: 'absolute', top: 16, right: 16, padding: spacing.small },
  imageModalCloseText: { color: colors.white, fontSize: 28 },
});
