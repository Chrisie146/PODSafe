import React, { useEffect, useState } from 'react';
import {
  Alert,
  Image,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import Share, { Social } from 'react-native-share';
import {
  AppIcon,
  AppIconName,
  AppHeader,
  Card,
  ErrorState,
  IconButton,
  LoadingState,
  PrimaryButton,
  Screen,
  SecondaryButton,
  StatusChip,
} from '../../components/ui';
import { DeliveryStatus } from '../../models/delivery';
import { PodRecord } from '../../models/pod';
import { PodRepository } from '../../repositories/podRepository';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

interface DeliveryDetailsProps {
  route: { params: { deliveryId: string } };
  navigation: {
    navigate: (screen: string, params?: Record<string, unknown>) => void;
    goBack: () => void;
  };
}

type StatusTone = 'info' | 'warning' | 'success' | 'error';

const STATUS: Record<
  DeliveryStatus,
  { label: string; tone: StatusTone; icon: AppIconName }
> = {
  pending: { label: 'Pending', tone: 'warning', icon: 'calendar' },
  inTransit: { label: 'In transit', tone: 'info', icon: 'truck' },
  delivered: { label: 'Delivered', tone: 'success', icon: 'check' },
  failed: { label: 'Failed', tone: 'error', icon: 'alert' },
};

const podRepository = new PodRepository();

function formatDate(date: Date): string {
  return date.toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });
}

function formatDateTime(date: Date): string {
  return `${date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })} at ${date.toLocaleTimeString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  })}`;
}

/** Evidence-first admin delivery review. */
export default function DeliveryDetails({
  route,
  navigation,
}: DeliveryDetailsProps) {
  const { deliveryId } = route.params;
  const selectedDelivery = useDeliveryStore(state => state.selectedDelivery);
  const isLoading = useDeliveryStore(state => state.isLoading);
  const errorMessage = useDeliveryStore(state => state.errorMessage);
  const loadDeliveryById = useDeliveryStore(state => state.loadDeliveryById);
  const deleteDelivery = useDeliveryStore(state => state.deleteDelivery);
  const driverUser = useUserManagementStore(state => state.selectedUser);
  const loadUserById = useUserManagementStore(state => state.loadUserById);
  const [pod, setPod] = useState<PodRecord | null | undefined>(undefined);
  const [fullScreenImage, setFullScreenImage] = useState<string | null>(null);

  const delivery =
    selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  useEffect(() => {
    loadDeliveryById(deliveryId);
  }, [deliveryId, loadDeliveryById]);
  useEffect(() => {
    if (!delivery) return;
    if (!delivery.isThirdPartyTransport) loadUserById(delivery.driverId);
    if (delivery.status !== 'delivered') {
      setPod(null);
      return;
    }
    setPod(undefined);
    podRepository
      .getPodById(delivery.id)
      .then(setPod)
      .catch(() => setPod(null));
  }, [delivery, loadUserById]);

  const handleDelete = () =>
    Alert.alert('Delete delivery', 'This cannot be undone.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          if (await deleteDelivery(deliveryId)) navigation.goBack();
          else
            Alert.alert(
              'Unable to delete',
              useDeliveryStore.getState().errorMessage ?? 'Try again.',
            );
        },
      },
    ]);
  const copyLink = (token: string) => {
    Clipboard.setString(`https://podsafe.app/upload/${token}`);
    Alert.alert('Link copied', 'The external upload link is ready to share.');
  };
  const shareLink = async (token: string) => {
    try {
      await Share.shareSingle({
        social: Social.Whatsapp,
        message: `https://podsafe.app/upload/${token}`,
      });
    } catch (error) {
      Alert.alert('Unable to share', (error as Error).message);
    }
  };

  if (isLoading)
    return (
      <Screen>
        <LoadingState
          title="Loading delivery details"
          message="Retrieving the delivery record."
        />
      </Screen>
    );
  if (!delivery)
    return (
      <Screen>
        <ErrorState
          title="Delivery unavailable"
          message={errorMessage ?? 'The requested delivery could not be found.'}
          onAction={() => loadDeliveryById(deliveryId)}
        />
      </Screen>
    );

  const status = STATUS[delivery.status];
  return (
    <Screen style={styles.screen} contentContainerStyle={styles.screenContent}>
      <AppHeader
        title="Delivery details"
        subtitle={`Invoice ${delivery.invoiceNumber}`}
        onBack={navigation.goBack}
        right={
          <>
            <IconButton
              icon="edit"
              accessibilityLabel="Edit delivery"
              onPress={() =>
                navigation.navigate('CreateDelivery', {
                  deliveryId: delivery.id,
                })
              }
            />
            <IconButton
              icon="trash"
              accessibilityLabel="Delete delivery"
              color={colors.critical}
              onPress={handleDelete}
            />
          </>
        }
      />
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.hero}>
          <View style={styles.heroCopy}>
            <Text style={textStyles.heading2}>{delivery.customerName}</Text>
            <Text style={textStyles.bodyMedium}>
              {delivery.customerAddress}
            </Text>
          </View>
          <StatusChip
            label={status.label}
            tone={status.tone}
            icon={status.icon}
          />
        </View>
        <Section title="Customer">
          <InfoCard
            rows={[
              ['Address', delivery.customerAddress],
              ['Phone', delivery.customerPhone ?? 'Not provided'],
              ['Customer number', delivery.customerNumber ?? 'Not recorded'],
            ]}
          />
        </Section>
        <Section title="Schedule and references">
          <InfoCard
            rows={[
              ['Invoice', delivery.invoiceNumber],
              ['Order', delivery.orderNumber ?? 'Not recorded'],
              ['Scheduled', formatDate(delivery.scheduledDate)],
              ['Created', formatDateTime(delivery.createdAt)],
              ...(delivery.deliveredAt
                ? [
                    ['Delivered', formatDateTime(delivery.deliveredAt)] as [
                      string,
                      string,
                    ],
                  ]
                : []),
            ]}
          />
        </Section>
        {delivery.isThirdPartyTransport ? (
          <Section title="External transport">
            <Card style={styles.transportCard}>
              <View style={styles.transportHeading}>
                <AppIcon name="truck" size={22} color={colors.contentPrimary} />
                <Text style={textStyles.heading3}>
                  {delivery.thirdPartyProviderName ?? 'Transport provider'}
                </Text>
              </View>
              <InfoCard
                rows={[
                  ['Driver', delivery.thirdPartyDriverName ?? 'Not assigned'],
                  ['Phone', delivery.thirdPartyDriverPhone ?? 'Not provided'],
                  ['Vehicle', delivery.thirdPartyVehicleInfo ?? 'Not recorded'],
                ]}
              />
              {delivery.uploadToken ? (
                <View style={styles.uploadActions}>
                  <Text style={textStyles.label}>External POD upload</Text>
                  <Text
                    selectable
                    style={styles.uploadLink}
                  >{`https://podsafe.app/upload/${delivery.uploadToken}`}</Text>
                  <View style={styles.actionRow}>
                    <SecondaryButton
                      label="Copy link"
                      icon="copy"
                      onPress={() => copyLink(delivery.uploadToken!)}
                    />
                    <SecondaryButton
                      label="Share link"
                      icon="link"
                      onPress={() => shareLink(delivery.uploadToken!)}
                    />
                  </View>
                </View>
              ) : null}
              {delivery.thirdPartyDocs?.length ? (
                <View style={styles.documents}>
                  <Text style={textStyles.label}>Uploaded documents</Text>
                  <View style={styles.thumbnailRow}>
                    {delivery.thirdPartyDocs.map(url => (
                      <IconButton
                        key={url}
                        icon="image"
                        accessibilityLabel="Open uploaded document"
                        onPress={() => setFullScreenImage(url)}
                      />
                    ))}
                  </View>
                </View>
              ) : null}
            </Card>
          </Section>
        ) : (
          <Section title="Assigned driver">
            {driverUser ? (
              <InfoCard
                rows={[
                  ['Driver', driverUser.fullName],
                  ['Email', driverUser.email ?? 'Not recorded'],
                  [
                    'Vehicle',
                    driverUser.vehicleInfo ??
                      delivery.vehicleUsed ??
                      'Not assigned',
                  ],
                ]}
              />
            ) : (
              <LoadingState
                title="Loading driver"
                message="Retrieving assignment details."
              />
            )}
          </Section>
        )}
        <Section title={`Delivery items (${delivery.items.length})`}>
          <View style={styles.itemList}>
            {delivery.items.map((item, index) => (
              <Card
                key={`${item.description}-${index}`}
                style={styles.itemCard}
              >
                <View style={styles.quantity}>
                  <Text style={textStyles.label}>{item.quantity}</Text>
                </View>
                <View style={styles.itemCopy}>
                  <Text style={textStyles.label}>{item.description}</Text>
                  <Text style={textStyles.bodySmall}>
                    {[
                      item.unit,
                      item.unitPrice != null
                        ? `R${item.unitPrice.toFixed(2)} each`
                        : undefined,
                    ]
                      .filter(Boolean)
                      .join(' / ') || 'No unit or price recorded'}
                  </Text>
                </View>
              </Card>
            ))}
          </View>
        </Section>
        {delivery.notes ? (
          <Section title="Notes">
            <Card>
              <Text style={textStyles.bodyMedium}>{delivery.notes}</Text>
            </Card>
          </Section>
        ) : null}
        {delivery.status === 'delivered' ? (
          <Section title="Proof of delivery">
            {pod === undefined ? (
              <LoadingState
                title="Loading proof"
                message="Retrieving the evidence record."
              />
            ) : pod ? (
              <Card style={styles.proofCard}>
                <View style={styles.proofIcon}>
                  <AppIcon name="signature" size={26} color={colors.verified} />
                </View>
                <View style={styles.itemCopy}>
                  <Text style={textStyles.heading3}>Evidence available</Text>
                  <Text style={textStyles.bodySmall}>
                    Review signature, photos, and location evidence.
                  </Text>
                </View>
                <PrimaryButton
                  label="Open proof"
                  icon="arrowRight"
                  onPress={() =>
                    navigation.navigate('PodDetails', {
                      deliveryId: delivery.id,
                    })
                  }
                />
              </Card>
            ) : (
              <Card style={styles.proofCard}>
                <AppIcon name="alert" size={26} color={colors.attention} />
                <Text style={textStyles.bodyMedium}>
                  No proof has been recorded for this delivery yet.
                </Text>
              </Card>
            )}
          </Section>
        ) : null}
      </ScrollView>
      <Modal
        visible={Boolean(fullScreenImage)}
        transparent
        animationType="fade"
        onRequestClose={() => setFullScreenImage(null)}
      >
        <View style={styles.imageModal}>
          <View style={styles.imageModalHeader}>
            <Text style={[textStyles.heading3, { color: colors.onPrimary }]}>
              Uploaded document
            </Text>
            <IconButton
              icon="close"
              accessibilityLabel="Close document"
              color={colors.onPrimary}
              onPress={() => setFullScreenImage(null)}
            />
          </View>
          {fullScreenImage ? (
            <Image
              source={{ uri: fullScreenImage }}
              resizeMode="contain"
              style={styles.fullImage}
            />
          ) : null}
        </View>
      </Modal>
    </Screen>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.section}>
      <Text style={textStyles.heading3}>{title}</Text>
      {children}
    </View>
  );
}
function InfoCard({ rows }: { rows: Array<[string, string]> }) {
  return (
    <Card style={styles.infoCard}>
      {rows.map(([label, value]) => (
        <View key={label} style={styles.infoRow}>
          <Text style={textStyles.labelSmall}>{label}</Text>
          <Text selectable style={[textStyles.bodyMedium, styles.infoValue]}>
            {value}
          </Text>
        </View>
      ))}
    </Card>
  );
}

const styles = StyleSheet.create({
  screen: { backgroundColor: colors.canvas },
  screenContent: { flex: 1, paddingHorizontal: 0 },
  content: {
    gap: spacing.large,
    padding: spacing.medium,
    paddingBottom: spacing.xxLarge,
  },
  hero: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.medium,
    justifyContent: 'space-between',
  },
  heroCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  section: { gap: spacing.small },
  infoCard: { gap: 0 },
  infoRow: {
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.xs,
    paddingVertical: spacing.small,
  },
  infoValue: { color: colors.contentPrimary },
  transportCard: { gap: spacing.medium },
  transportHeading: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
  },
  uploadActions: { gap: spacing.small },
  uploadLink: {
    ...textStyles.bodySmall,
    backgroundColor: colors.surfaceMuted,
    borderRadius: spacing.xs,
    color: colors.shell,
    padding: spacing.small,
  },
  actionRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  documents: { gap: spacing.small },
  thumbnailRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  itemList: { gap: spacing.small },
  itemCard: { alignItems: 'center', flexDirection: 'row', gap: spacing.small },
  quantity: {
    alignItems: 'center',
    backgroundColor: colors.activeMuted,
    borderRadius: 18,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  itemCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  proofCard: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.medium,
  },
  proofIcon: {
    alignItems: 'center',
    backgroundColor: colors.verifiedMuted,
    borderRadius: 20,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  imageModal: { backgroundColor: colors.shell, flex: 1 },
  imageModalHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: spacing.medium,
  },
  fullImage: { flex: 1, width: '100%' },
});
