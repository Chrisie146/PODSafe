import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  AppHeader,
  AppIcon,
  AppModal,
  Card,
  EmptyState,
  ErrorState,
  IconButton,
  LoadingState,
  PrimaryButton,
  Screen,
  SecondaryButton,
  StatusChip,
} from '../../components/ui';
import FirebaseStorageImage from '../../components/FirebaseStorageImage';
import LocationMapWidget from '../../components/LocationMapWidget';
import { PodRecord } from '../../models/pod';
import {
  downloadImage,
  downloadMultipleImages,
} from '../../repositories/podImageDownloadService';
import { PodPdfService } from '../../repositories/podPdfService';
import { PodRepository } from '../../repositories/podRepository';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

interface PodDetailsProps {
  route: { params: { deliveryId: string } };
  navigation: { goBack: () => void };
}

interface EvidenceImage {
  label: string;
  url: string;
  icon: 'signature' | 'camera' | 'file' | 'shield';
}

const podRepository = new PodRepository();
const podPdfService = new PodPdfService();

function formatDateTime(value: Date): string {
  return `${value.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })} at ${value.toLocaleTimeString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  })}`;
}

function photoUrls(pod: PodRecord): string[] {
  return pod.photoUrls ?? (pod.photoUrl ? [pod.photoUrl] : []);
}

function evidenceImages(
  pod: PodRecord,
  stampPhotoUrl?: string,
): EvidenceImage[] {
  const images: EvidenceImage[] = [];
  if (pod.signatureUrl)
    images.push({
      label: 'Signature',
      url: pod.signatureUrl,
      icon: 'signature',
    });
  if (stampPhotoUrl)
    images.push({
      label: 'Customer stamp',
      url: stampPhotoUrl,
      icon: 'shield',
    });
  photoUrls(pod).forEach((url, index, all) =>
    images.push({
      label:
        all.length === 1 ? 'Delivery photo' : `Delivery photo ${index + 1}`,
      url,
      icon: 'camera',
    }),
  );
  (pod.documentUrls ?? []).forEach((url, index) =>
    images.push({
      label: pod.documentMetadata?.[index]?.type ?? `Document ${index + 1}`,
      url,
      icon: 'file',
    }),
  );
  return images;
}

export default function PodDetails({ route, navigation }: PodDetailsProps) {
  const { deliveryId } = route.params;
  const selectedDelivery = useDeliveryStore(state => state.selectedDelivery);
  const deliveryLoading = useDeliveryStore(state => state.isLoading);
  const loadDeliveryById = useDeliveryStore(state => state.loadDeliveryById);
  const [pod, setPod] = useState<PodRecord | null | undefined>(undefined);
  const [podError, setPodError] = useState<string | null>(null);
  const [downloadOpen, setDownloadOpen] = useState(false);
  const [generatingReport, setGeneratingReport] = useState(false);
  const [expandedImage, setExpandedImage] = useState<EvidenceImage | null>(
    null,
  );

  const loadProof = useCallback(() => {
    setPod(undefined);
    setPodError(null);
    podRepository
      .getPodById(deliveryId)
      .then(setPod)
      .catch((error: Error) => {
        setPodError(error.message || 'The proof record could not be loaded.');
        setPod(null);
      });
  }, [deliveryId]);

  useEffect(() => {
    loadDeliveryById(deliveryId);
    loadProof();
  }, [deliveryId, loadDeliveryById, loadProof]);

  const delivery =
    selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  const downloadReport = async () => {
    setDownloadOpen(false);
    setGeneratingReport(true);
    try {
      const reportUrl = await podPdfService.generatePodPdf(deliveryId);
      await downloadImage(reportUrl);
      Alert.alert(
        'Report downloaded',
        'The proof of delivery report is ready.',
      );
    } catch (error) {
      Alert.alert('Report unavailable', (error as Error).message);
    } finally {
      setGeneratingReport(false);
    }
  };

  const downloadAllEvidence = async (images: EvidenceImage[]) => {
    setDownloadOpen(false);
    try {
      await downloadMultipleImages(
        Object.fromEntries(images.map(image => [image.label, image.url])),
        deliveryId,
      );
      Alert.alert(
        'Evidence downloaded',
        `${images.length} evidence file${
          images.length === 1 ? '' : 's'
        } downloaded.`,
      );
    } catch (error) {
      Alert.alert('Download unavailable', (error as Error).message);
    }
  };

  const downloadOne = async (image: EvidenceImage) => {
    setDownloadOpen(false);
    try {
      await downloadImage(image.url);
      Alert.alert('Evidence downloaded', `${image.label} is ready.`);
    } catch (error) {
      Alert.alert('Download unavailable', (error as Error).message);
    }
  };

  if (pod === undefined) {
    return (
      <Screen>
        <LoadingState
          title="Loading proof details"
          message="Retrieving the delivery evidence."
        />
      </Screen>
    );
  }

  if (pod === null) {
    return (
      <Screen>
        <AppHeader title="Proof details" onBack={navigation.goBack} />
        {podError ? (
          <ErrorState
            title="Proof details unavailable"
            message={podError}
            actionLabel="Try again"
            onAction={loadProof}
          />
        ) : (
          <EmptyState
            title="No proof of delivery"
            message="This delivery does not have a recorded proof yet."
            icon="signature"
          />
        )}
      </Screen>
    );
  }

  const stampPhotoUrl =
    typeof pod.metadata.stampPhotoUrl === 'string'
      ? pod.metadata.stampPhotoUrl
      : undefined;
  const notes =
    typeof pod.metadata.notes === 'string' ? pod.metadata.notes : undefined;
  const images = evidenceImages(pod, stampPhotoUrl);
  const photos = photoUrls(pod);
  const documents = pod.documentUrls ?? [];

  return (
    <Screen style={styles.screen} contentContainerStyle={styles.screenContent}>
      <AppHeader
        title="Proof details"
        subtitle={
          delivery ? `Invoice ${delivery.invoiceNumber}` : `Proof ${pod.id}`
        }
        onBack={navigation.goBack}
        right={
          <IconButton
            icon="download"
            accessibilityLabel="Download proof"
            onPress={() => setDownloadOpen(true)}
          />
        }
      />
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <Card style={styles.summary}>
          <View style={styles.summaryTop}>
            <View style={styles.summaryIcon}>
              <AppIcon name="check" size={26} color={colors.verified} />
            </View>
            <View style={styles.summaryCopy}>
              <Text style={textStyles.heading3}>Evidence captured</Text>
              <Text style={textStyles.bodySmall}>
                {formatDateTime(pod.timestamp)}
              </Text>
            </View>
            <StatusChip label="Verified delivery" tone="success" icon="check" />
          </View>
          <View style={styles.summaryMeta}>
            <Meta
              icon="user"
              label="Receiver"
              value={pod.signedBy ?? 'Not specified'}
            />
            <Meta
              icon="clipboard"
              label="Customer"
              value={delivery?.customerName ?? pod.customerName}
            />
          </View>
        </Card>

        <Section title="Evidence checklist">
          <View style={styles.checklist}>
            <EvidenceStatus
              icon="signature"
              label="Signature"
              available={Boolean(pod.signatureUrl)}
            />
            <EvidenceStatus
              icon="camera"
              label="Photos"
              available={photos.length > 0}
              detail={photos.length ? `${photos.length} attached` : undefined}
            />
            <EvidenceStatus
              icon="file"
              label="Documents"
              available={documents.length > 0}
              detail={
                documents.length ? `${documents.length} attached` : undefined
              }
            />
            <EvidenceStatus
              icon="location"
              label="Location"
              available={Boolean(pod.location)}
            />
          </View>
        </Section>

        {delivery ? (
          <Section title="Delivery summary">
            <InfoCard
              rows={[
                ['Customer', delivery.customerName],
                ['Address', delivery.customerAddress],
                ['Invoice', delivery.invoiceNumber],
                ['Completed', formatDateTime(pod.timestamp)],
              ]}
            />
          </Section>
        ) : deliveryLoading ? (
          <LoadingState
            title="Loading delivery summary"
            message="Retrieving the related delivery."
          />
        ) : null}

        {pod.signatureUrl ? (
          <Section title="Customer signature">
            <EvidenceCard
              image={{
                label: 'Signature',
                url: pod.signatureUrl,
                icon: 'signature',
              }}
              mode="contain"
              onOpen={setExpandedImage}
            />
          </Section>
        ) : null}

        {photos.length ? (
          <Section title={`Delivery photos (${photos.length})`}>
            <ScrollView
              horizontal
              contentContainerStyle={styles.gallery}
              showsHorizontalScrollIndicator={false}
            >
              {photos.map((url, index) => (
                <EvidenceCard
                  key={url}
                  compact
                  image={{
                    label:
                      photos.length === 1
                        ? 'Delivery photo'
                        : `Delivery photo ${index + 1}`,
                    url,
                    icon: 'camera',
                  }}
                  mode="cover"
                  onOpen={setExpandedImage}
                />
              ))}
            </ScrollView>
          </Section>
        ) : null}

        {documents.length ? (
          <Section title={`Scanned documents (${documents.length})`}>
            <View style={styles.evidenceList}>
              {documents.map((url, index) => (
                <EvidenceCard
                  key={url}
                  image={{
                    label:
                      pod.documentMetadata?.[index]?.type ??
                      `Document ${index + 1}`,
                    url,
                    icon: 'file',
                  }}
                  mode="contain"
                  onOpen={setExpandedImage}
                />
              ))}
            </View>
          </Section>
        ) : null}

        {stampPhotoUrl ? (
          <Section title="Customer stamp">
            <EvidenceCard
              image={{
                label: 'Customer stamp',
                url: stampPhotoUrl,
                icon: 'shield',
              }}
              mode="cover"
              onOpen={setExpandedImage}
            />
          </Section>
        ) : null}

        {pod.location ? (
          <Section title="Location evidence">
            <Card style={styles.locationCard}>
              <View style={styles.locationHeading}>
                <AppIcon name="location" size={22} color={colors.active} />
                <View style={styles.summaryCopy}>
                  <Text style={textStyles.label}>
                    Recorded delivery location
                  </Text>
                  <Text style={textStyles.bodySmall}>
                    {pod.location.address ||
                      'Coordinates captured with the proof.'}
                  </Text>
                </View>
              </View>
              <LocationMapWidget
                latitude={pod.location.latitude}
                longitude={pod.location.longitude}
                accuracy={pod.location.accuracy}
                address={pod.location.address}
              />
            </Card>
          </Section>
        ) : null}

        {notes ? (
          <Section title="Delivery notes">
            <Card>
              <Text style={textStyles.bodyMedium}>{notes}</Text>
            </Card>
          </Section>
        ) : null}
      </ScrollView>

      <AppModal
        visible={downloadOpen}
        title="Download evidence"
        onClose={() => setDownloadOpen(false)}
        footer={
          <PrimaryButton
            label="Download PDF report"
            icon="download"
            loading={generatingReport}
            onPress={downloadReport}
          />
        }
      >
        <View style={styles.downloadContent}>
          <Text style={textStyles.bodyMedium}>
            Create a formal PDF report or save individual evidence files.
          </Text>
          {images.length ? (
            <SecondaryButton
              label={`Download all evidence (${images.length})`}
              icon="download"
              onPress={() => downloadAllEvidence(images)}
            />
          ) : null}
          <ScrollView
            style={styles.downloadList}
            contentContainerStyle={styles.downloadListContent}
          >
            {images.map(image => (
              <SecondaryButton
                key={image.label}
                label={`Download ${image.label}`}
                icon={image.icon}
                onPress={() => downloadOne(image)}
              />
            ))}
          </ScrollView>
        </View>
      </AppModal>

      <Modal
        visible={Boolean(expandedImage)}
        transparent
        animationType="fade"
        onRequestClose={() => setExpandedImage(null)}
      >
        <View style={styles.imageModal}>
          <View style={styles.imageModalHeader}>
            <Text
              numberOfLines={1}
              style={[textStyles.heading3, styles.imageModalTitle]}
            >
              {expandedImage?.label}
            </Text>
            <IconButton
              icon="close"
              color={colors.onPrimary}
              accessibilityLabel="Close evidence image"
              onPress={() => setExpandedImage(null)}
            />
          </View>
          {expandedImage ? (
            <FirebaseStorageImage
              imageUrl={expandedImage.url}
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

function Meta({
  icon,
  label,
  value,
}: {
  icon: 'user' | 'clipboard';
  label: string;
  value: string;
}) {
  return (
    <View style={styles.meta}>
      <AppIcon name={icon} size={16} color={colors.contentSecondary} />
      <View style={styles.summaryCopy}>
        <Text style={textStyles.labelSmall}>{label}</Text>
        <Text numberOfLines={1} style={textStyles.bodyMedium}>
          {value}
        </Text>
      </View>
    </View>
  );
}

function EvidenceStatus({
  icon,
  label,
  available,
  detail,
}: {
  icon: 'signature' | 'camera' | 'file' | 'location';
  label: string;
  available: boolean;
  detail?: string;
}) {
  return (
    <View style={styles.checkItem}>
      <View
        style={[
          styles.checkIcon,
          available ? styles.checkIconAvailable : styles.checkIconMissing,
        ]}
      >
        <AppIcon
          name={available ? 'check' : icon}
          size={18}
          color={available ? colors.verified : colors.contentSecondary}
        />
      </View>
      <View style={styles.summaryCopy}>
        <Text style={textStyles.label}>{label}</Text>
        <Text style={textStyles.bodySmall}>
          {available ? detail ?? 'Captured' : 'Not captured'}
        </Text>
      </View>
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

function EvidenceCard({
  image,
  mode,
  compact = false,
  onOpen,
}: {
  image: EvidenceImage;
  mode: 'cover' | 'contain';
  compact?: boolean;
  onOpen: (image: EvidenceImage) => void;
}) {
  return (
    <Card
      padding="none"
      style={[styles.evidenceCard, compact && styles.evidenceCardCompact]}
    >
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Open ${image.label}`}
        onPress={() => onOpen(image)}
        style={styles.evidencePressable}
      >
        <View
          style={[styles.evidenceImage, compact && styles.evidenceImageCompact]}
        >
          <FirebaseStorageImage
            imageUrl={image.url}
            resizeMode={mode}
            style={styles.imageFill}
          />
        </View>
        <View style={styles.evidenceFooter}>
          <View style={styles.evidenceFooterCopy}>
            <AppIcon
              name={image.icon}
              size={18}
              color={colors.contentSecondary}
            />
            <Text numberOfLines={1} style={textStyles.label}>
              {image.label}
            </Text>
          </View>
          <AppIcon name="eye" size={18} color={colors.active} />
        </View>
      </Pressable>
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
  summary: { gap: spacing.medium },
  summaryTop: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
  },
  summaryIcon: {
    alignItems: 'center',
    backgroundColor: colors.verifiedMuted,
    borderRadius: 24,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  summaryCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  summaryMeta: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.medium,
    paddingTop: spacing.medium,
  },
  meta: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    gap: spacing.small,
    minWidth: 180,
  },
  section: { gap: spacing.small },
  checklist: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  checkItem: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    flex: 1,
    flexDirection: 'row',
    gap: spacing.small,
    minWidth: 155,
    padding: spacing.small,
  },
  checkIcon: {
    alignItems: 'center',
    borderRadius: 18,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  checkIconAvailable: { backgroundColor: colors.verifiedMuted },
  checkIconMissing: { backgroundColor: colors.surfaceMuted },
  infoCard: { gap: 0 },
  infoRow: {
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.xs,
    paddingVertical: spacing.small,
  },
  infoValue: { color: colors.contentPrimary },
  gallery: { gap: spacing.small },
  evidenceList: { gap: spacing.small },
  evidenceCard: { overflow: 'hidden' },
  evidenceCardCompact: { width: 248 },
  evidencePressable: { width: '100%' },
  evidenceImage: {
    backgroundColor: colors.surfaceMuted,
    height: 240,
    overflow: 'hidden',
  },
  evidenceImageCompact: { height: 190 },
  imageFill: { height: '100%', width: '100%' },
  evidenceFooter: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
    justifyContent: 'space-between',
    padding: spacing.small,
  },
  evidenceFooterCopy: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    gap: spacing.small,
    minWidth: 0,
  },
  locationCard: { gap: spacing.medium },
  locationHeading: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
  },
  downloadContent: { gap: spacing.medium },
  downloadList: { maxHeight: 260 },
  downloadListContent: { gap: spacing.small },
  imageModal: { backgroundColor: colors.shell, flex: 1 },
  imageModalHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
    padding: spacing.medium,
  },
  imageModalTitle: { color: colors.onPrimary, flex: 1 },
  fullImage: { flex: 1, width: '100%' },
});
