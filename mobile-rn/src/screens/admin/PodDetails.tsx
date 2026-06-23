// expects route.params: { deliveryId: string }
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { PodRepository } from '../../repositories/podRepository';
import { PodPdfService } from '../../repositories/podPdfService';
import { downloadImage, downloadMultipleImages } from '../../repositories/podImageDownloadService';
import { PodRecord } from '../../models/pod';
import FirebaseStorageImage from '../../components/FirebaseStorageImage';
import LocationMapWidget from '../../components/LocationMapWidget';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/pod_details_screen.dart (verified against source on
 * 2026-06-23).
 *
 * Deviations from the Flutter source:
 * - Takes only `deliveryId` via route params and loads the POD through
 *   `podRepository.getPodById` plus `useDeliveryStore.loadDeliveryById`, same robustness
 *   argument as DeliveryDetails.tsx/DriverDetails.tsx, instead of requiring the caller to
 *   pass the already-fetched POD map.
 * - `_loadDriverInfo`/`_loadVehicleInfo`/`_loadCompanyInfo` and their state are NOT
 *   ported: in the Dart source they are used exclusively inside `_downloadPODReport()`'s
 *   client-side PDF data assembly, never in `build()`. PDF generation is now server-side
 *   (the `generatePodPdf` Cloud Function, built task #10) which re-derives all of that
 *   itself from `deliveryId`, so none of that loading logic is needed here.
 * - `notes`/`stampPhotoUrl`/`receiverName` are read from `pod.metadata`/`pod.signedBy`
 *   (no typed top-level fields for the first two — see PodViewer.tsx's identical
 *   deviation note).
 * - Header: native stack header is hidden (`headerShown: false` in AdminStack.tsx) in
 *   favor of one single custom header bar, following AdminDashboard's precedent rather
 *   than the double-header pattern already present in earlier screens like
 *   DeliveryDetails.tsx/PodViewer.tsx.
 * - Share button stays a faithful no-op "Coming Soon" stub, matching the Dart source's
 *   SnackBar (which also doesn't actually share anything).
 * - "Download as PDF Report" calls the server-side `generatePodPdf` callable via
 *   `PodPdfService` instead of assembling/rendering a PDF client-side.
 * - Full-screen image viewer is a `Modal` (no pinch-zoom — `InteractiveViewer`'s RN
 *   equivalent isn't installed) instead of pushing a new route, same degraded-but-honest
 *   pattern as DeliveryDetails.tsx's image viewer.
 * - Individual photo/document thumbnails are themselves tappable to open full-screen
 *   (matching DeliveryDetails.tsx's thirdPartyDocs thumbnails), in addition to the
 *   Dart source's explicit "View Full Size" buttons — the Dart source only wires a
 *   full-screen button for the *first* delivery photo when there are several.
 */
interface PodDetailsProps {
  route: { params: { deliveryId: string } };
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void; goBack: () => void };
}

interface ImageOption {
  label: string;
  url: string;
}

interface FullScreenImage {
  url: string;
  title: string;
}

const podRepository = new PodRepository();
const podPdfService = new PodPdfService();

function formatFullDateTime(date: Date): string {
  const dateStr = date.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
  const timeStr = date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  return `${dateStr} • ${timeStr}`;
}

function resolvePhotoUrls(pod: PodRecord): string[] {
  if (pod.photoUrls !== undefined) return pod.photoUrls;
  return pod.photoUrl ? [pod.photoUrl] : [];
}

function buildImageOptions(pod: PodRecord, stampPhotoUrl: string | undefined): ImageOption[] {
  const options: ImageOption[] = [];
  if (pod.signatureUrl) options.push({ label: 'Signature', url: pod.signatureUrl });
  if (stampPhotoUrl) options.push({ label: 'Stamp Photo', url: stampPhotoUrl });

  const photoUrls = resolvePhotoUrls(pod);
  photoUrls.forEach((url, i) => {
    options.push({ label: photoUrls.length === 1 ? 'Delivery Photo' : `Delivery Photo ${i + 1}`, url });
  });

  const documentUrls = pod.documentUrls ?? [];
  documentUrls.forEach((url, i) => {
    const docType = pod.documentMetadata?.[i]?.type ?? 'Document';
    options.push({ label: documentUrls.length === 1 ? docType : `${docType} ${i + 1}`, url });
  });

  return options;
}

export default function PodDetails({ route, navigation }: PodDetailsProps) {
  const { deliveryId } = route.params;
  const selectedDelivery = useDeliveryStore((s) => s.selectedDelivery);
  const isLoadingDelivery = useDeliveryStore((s) => s.isLoading);
  const loadDeliveryById = useDeliveryStore((s) => s.loadDeliveryById);

  const [pod, setPod] = useState<PodRecord | null | undefined>(undefined);
  const [showDownloadOptions, setShowDownloadOptions] = useState(false);
  const [isGeneratingPdf, setIsGeneratingPdf] = useState(false);
  const [fullScreenImage, setFullScreenImage] = useState<FullScreenImage | null>(null);

  useEffect(() => {
    loadDeliveryById(deliveryId);
    podRepository.getPodById(deliveryId).then(setPod);
  }, [deliveryId, loadDeliveryById]);

  const delivery = selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  if (pod === undefined || pod === null) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  const signatureUrl = pod.signatureUrl;
  const photoUrls = resolvePhotoUrls(pod);
  const documentUrls = pod.documentUrls ?? [];
  const documentMetadata = pod.documentMetadata ?? [];
  const stampPhotoUrl = pod.metadata.stampPhotoUrl as string | undefined;
  const notes = pod.metadata.notes as string | undefined;
  const receiverName = pod.signedBy;
  const imageOptions = buildImageOptions(pod, stampPhotoUrl);

  const handleShare = () => {
    Alert.alert('Share', 'Share feature coming soon!');
  };

  const handleOpenDownloadOptions = () => {
    if (imageOptions.length === 0) {
      Alert.alert('No Images', 'No images available to download');
      return;
    }
    setShowDownloadOptions(true);
  };

  const handleDownloadPdfReport = async () => {
    setShowDownloadOptions(false);
    setIsGeneratingPdf(true);
    try {
      const pdfUrl = await podPdfService.generatePodPdf(deliveryId);
      await downloadImage(pdfUrl);
      Alert.alert('Success', 'PDF report downloaded successfully!');
    } catch (e) {
      Alert.alert('Error', `Error generating PDF: ${(e as Error).message}`);
    } finally {
      setIsGeneratingPdf(false);
    }
  };

  const handleDownloadAllImages = async () => {
    setShowDownloadOptions(false);
    try {
      const images = Object.fromEntries(imageOptions.map((o) => [o.label, o.url]));
      await downloadMultipleImages(images, deliveryId);
      Alert.alert('Success', `All ${imageOptions.length} images downloaded successfully!`);
    } catch (e) {
      Alert.alert('Error', `Error downloading images: ${(e as Error).message}`);
    }
  };

  const handleDownloadSingleImage = async (option: ImageOption) => {
    setShowDownloadOptions(false);
    try {
      await downloadImage(option.url);
      Alert.alert('Success', `${option.label} downloaded successfully!`);
    } catch (e) {
      Alert.alert('Error', `Error downloading image: ${(e as Error).message}`);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => navigation.goBack()}>
          <Text style={styles.headerBarAction}>‹ Back</Text>
        </Pressable>
        <Text style={textStyles.heading3}>POD Details</Text>
        <View style={styles.headerBarRight}>
          <Pressable onPress={handleShare}>
            <Text style={styles.headerBarAction}>↗</Text>
          </Pressable>
          <Pressable onPress={handleOpenDownloadOptions}>
            <Text style={styles.headerBarAction}>⬇</Text>
          </Pressable>
        </View>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        <View style={styles.statusBadgeRow}>
          <View style={styles.statusBadge}>
            <Text style={styles.statusBadgeIcon}>✓</Text>
            <Text style={styles.statusBadgeText}>Delivered Successfully</Text>
          </View>
        </View>

        {delivery ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Information</Text>
            <View style={[styles.card, shadows.card]}>
              <InfoRow label="Customer" value={delivery.customerName} />
              <InfoRow label="Address" value={delivery.customerAddress} />
              <InfoRow label="Phone" value={delivery.customerPhone ?? 'N/A'} />
              <InfoRow label="Receiver" value={receiverName ?? 'Not specified'} />
            </View>
          </>
        ) : isLoadingDelivery ? (
          <ActivityIndicator color={colors.primary} style={styles.sectionLoading} />
        ) : null}

        <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Time</Text>
        <View style={[styles.card, shadows.card]}>
          <InfoRow label="Completed At" value={formatFullDateTime(pod.timestamp)} />
        </View>

        {pod.location ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>GPS Location</Text>
            <View style={[styles.card, shadows.card]}>
              <InfoRow label="Latitude" value={String(pod.location.latitude)} />
              <InfoRow label="Longitude" value={String(pod.location.longitude)} />
              <InfoRow label="Accuracy" value={`${pod.location.accuracy != null ? pod.location.accuracy.toFixed(1) : 'N/A'} meters`} />
            </View>
            <View style={styles.mapSpacer}>
              <LocationMapWidget
                latitude={pod.location.latitude}
                longitude={pod.location.longitude}
                accuracy={pod.location.accuracy}
                address={pod.location.address}
              />
            </View>
          </>
        ) : null}

        {signatureUrl ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Customer Signature</Text>
            <View style={[styles.card, shadows.card]}>
              <Pressable onPress={() => setFullScreenImage({ url: signatureUrl, title: 'Signature' })}>
                <View style={[styles.imageBox, styles.signatureImageBox]}>
                  <FirebaseStorageImage imageUrl={signatureUrl} resizeMode="contain" style={styles.imageFill} />
                </View>
              </Pressable>
              <ViewFullSizeButton onPress={() => setFullScreenImage({ url: signatureUrl, title: 'Signature' })} />
            </View>
          </>
        ) : null}

        {photoUrls.length > 0 ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Photo{photoUrls.length > 1 ? 's' : ''}</Text>
            <View style={[styles.card, shadows.card]}>
              {photoUrls.length === 1 ? (
                <Pressable onPress={() => setFullScreenImage({ url: photoUrls[0], title: 'Photo' })}>
                  <View style={[styles.imageBox, styles.singlePhotoImageBox]}>
                    <FirebaseStorageImage imageUrl={photoUrls[0]} resizeMode="cover" style={styles.imageFill} />
                  </View>
                </Pressable>
              ) : (
                <ScrollView horizontal contentContainerStyle={styles.photoScrollRow}>
                  {photoUrls.map((url, i) => (
                    <Pressable key={url} onPress={() => setFullScreenImage({ url, title: `Photo ${i + 1}` })}>
                      <View style={[styles.imageBox, styles.photoThumb, i < photoUrls.length - 1 ? styles.photoThumbSpacing : null]}>
                        <FirebaseStorageImage imageUrl={url} resizeMode="cover" style={styles.imageFill} />
                      </View>
                    </Pressable>
                  ))}
                </ScrollView>
              )}
              <View style={styles.photoFooterRow}>
                <ViewFullSizeButton label="View First Photo Full Size" onPress={() => setFullScreenImage({ url: photoUrls[0], title: 'Photo' })} />
                {photoUrls.length > 1 ? <Text style={styles.photoHint}>Scroll horizontally to view all {photoUrls.length} photos</Text> : null}
              </View>
            </View>
          </>
        ) : null}

        {documentUrls.length > 0 ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Scanned Documents ({documentUrls.length})</Text>
            <View style={[styles.card, shadows.card]}>
              <View style={styles.docsHeaderRow}>
                <Text style={styles.docsHeaderIcon}>📑</Text>
                <Text style={styles.docsHeaderText}>High-quality scanned documents</Text>
              </View>
              {documentUrls.map((url, i) => {
                const docType = documentMetadata[i]?.type ?? 'Document';
                return (
                  <View key={url} style={i > 0 ? styles.docSpacing : null}>
                    <View style={styles.docTypeBadge}>
                      <Text style={styles.docTypeBadgeText}>🏷 {docType}</Text>
                    </View>
                    <Pressable onPress={() => setFullScreenImage({ url, title: docType })}>
                      <View style={[styles.imageBox, styles.docImageBox]}>
                        <FirebaseStorageImage imageUrl={url} resizeMode="contain" style={styles.imageFill} />
                      </View>
                    </Pressable>
                    <ViewFullSizeButton label={`View ${docType} Full Size`} onPress={() => setFullScreenImage({ url, title: docType })} />
                  </View>
                );
              })}
            </View>
          </>
        ) : null}

        {stampPhotoUrl ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Customer Stamp</Text>
            <View style={[styles.card, shadows.card, styles.stampCard]}>
              <View style={styles.docsHeaderRow}>
                <Text style={styles.docsHeaderIcon}>🧾</Text>
                <Text style={styles.docsHeaderText}>Corporate Store Receipt Stamp</Text>
              </View>
              <Pressable onPress={() => setFullScreenImage({ url: stampPhotoUrl, title: 'Stamp Photo' })}>
                <View style={[styles.imageBox, styles.stampImageBox]}>
                  <FirebaseStorageImage imageUrl={stampPhotoUrl} resizeMode="cover" style={styles.imageFill} />
                </View>
              </Pressable>
              <ViewFullSizeButton onPress={() => setFullScreenImage({ url: stampPhotoUrl, title: 'Stamp Photo' })} />
            </View>
          </>
        ) : null}

        {notes ? (
          <>
            <Text style={[textStyles.heading3, styles.sectionTitle]}>Delivery Notes</Text>
            <View style={[styles.card, shadows.card]}>
              <Text style={styles.notesText}>{notes}</Text>
            </View>
          </>
        ) : null}
      </ScrollView>

      <Modal visible={showDownloadOptions} transparent animationType="fade" onRequestClose={() => setShowDownloadOptions(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowDownloadOptions(false)}>
          <ScrollView style={[styles.actionSheet, shadows.card]} contentContainerStyle={styles.actionSheetContent}>
            <Text style={styles.actionSheetTitle}>Download Options</Text>

            <Pressable style={styles.pdfOption} onPress={handleDownloadPdfReport} disabled={isGeneratingPdf}>
              {isGeneratingPdf ? (
                <ActivityIndicator color={colors.info} style={styles.pdfOptionIcon} />
              ) : (
                <Text style={styles.pdfOptionIcon}>📄</Text>
              )}
              <View style={styles.pdfOptionTextBox}>
                <Text style={styles.pdfOptionTitle}>Download as PDF Report</Text>
                <Text style={styles.pdfOptionSubtitle}>All details, images & signature in one file</Text>
              </View>
            </Pressable>

            <View style={styles.divider} />
            <Text style={styles.actionSheetCaption}>Or Download Individual Items</Text>
            <View style={styles.divider} />

            <Pressable style={styles.actionRow} onPress={handleDownloadAllImages}>
              <Text style={styles.actionRowGlyph}>⬇</Text>
              <Text style={styles.actionRowLabel}>Download All Images</Text>
            </Pressable>

            {imageOptions.map((option) => (
              <Pressable key={option.label} style={styles.actionRow} onPress={() => handleDownloadSingleImage(option)}>
                <Text style={styles.actionRowGlyph}>🖼</Text>
                <Text style={styles.actionRowLabel}>Download {option.label}</Text>
              </Pressable>
            ))}
          </ScrollView>
        </Pressable>
      </Modal>

      <Modal visible={fullScreenImage != null} transparent animationType="fade" onRequestClose={() => setFullScreenImage(null)}>
        <View style={styles.imageModalBackdrop}>
          <View style={styles.imageModalHeader}>
            <Text style={styles.imageModalTitle}>{fullScreenImage?.title}</Text>
            <Pressable onPress={() => setFullScreenImage(null)}>
              <Text style={styles.imageModalCloseText}>✕</Text>
            </Pressable>
          </View>
          {fullScreenImage ? (
            <FirebaseStorageImage imageUrl={fullScreenImage.url} resizeMode="contain" style={styles.fullScreenImage} />
          ) : null}
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

function ViewFullSizeButton({ label = 'View Full Size', onPress }: { label?: string; onPress: () => void }) {
  return (
    <Pressable style={styles.viewFullSizeButton} onPress={onPress}>
      <Text style={styles.viewFullSizeText}>⛶ {label}</Text>
    </Pressable>
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
  statusBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small,
    borderWidth: 2,
    borderColor: colors.success,
    backgroundColor: `${colors.success}1A`,
    borderRadius: 24,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.small + 4,
  },
  statusBadgeIcon: { fontSize: 18, color: colors.success },
  statusBadgeText: { fontWeight: 'bold', fontSize: 16, color: colors.success },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  sectionTitle: { marginBottom: spacing.small + 4 },
  sectionLoading: { marginBottom: spacing.large },
  infoRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: spacing.small },
  infoLabel: { width: 120, color: colors.textSecondary, fontWeight: '500' },
  infoValue: { flex: 1, fontWeight: '600' },
  mapSpacer: { marginBottom: spacing.large },
  imageBox: { width: '100%', backgroundColor: colors.background, borderRadius: 8, borderWidth: 1, borderColor: colors.divider, overflow: 'hidden' },
  signatureImageBox: { height: 200 },
  singlePhotoImageBox: { height: 250 },
  stampImageBox: { height: 250 },
  imageFill: { width: '100%', height: '100%' },
  viewFullSizeButton: { alignSelf: 'flex-start', marginTop: spacing.small + 4 },
  viewFullSizeText: { color: colors.primary, fontWeight: '600' },
  photoScrollRow: { gap: 0 },
  photoThumb: { width: 250, height: 250 },
  photoThumbSpacing: { marginRight: spacing.small },
  photoFooterRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: spacing.medium, marginTop: spacing.small },
  photoHint: { color: colors.textSecondary, fontSize: 13 },
  docsHeaderRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.medium },
  docsHeaderIcon: { fontSize: 18, marginRight: spacing.small },
  docsHeaderText: { color: colors.textSecondary, fontStyle: 'italic' },
  docSpacing: { marginTop: spacing.medium },
  docTypeBadge: {
    alignSelf: 'flex-start',
    backgroundColor: `${colors.primary}1A`,
    borderRadius: 6,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small - 2,
    marginBottom: spacing.small,
  },
  docTypeBadgeText: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  docImageBox: { height: 300, borderColor: colors.primary, borderWidth: 2 },
  stampCard: { backgroundColor: `${colors.info}0D` },
  notesText: { fontSize: 15 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  actionSheet: { backgroundColor: colors.card, borderRadius: radii.cardRadius, width: '100%', maxWidth: 360, maxHeight: '80%' },
  actionSheetContent: { padding: spacing.medium },
  actionSheetTitle: { ...textStyles.heading3, marginBottom: spacing.medium },
  actionSheetCaption: { color: colors.textSecondary, fontSize: 12, textAlign: 'center', marginVertical: spacing.small },
  pdfOption: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: `${colors.info}1A`,
    borderWidth: 2,
    borderColor: colors.info,
    borderRadius: radii.borderRadius,
    padding: spacing.medium,
  },
  pdfOptionIcon: { fontSize: 24, marginRight: spacing.medium, width: 28, textAlign: 'center' },
  pdfOptionTextBox: { flex: 1 },
  pdfOptionTitle: { fontWeight: 'bold', fontSize: 15 },
  pdfOptionSubtitle: { color: colors.textSecondary, fontSize: 12, marginTop: 2 },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowGlyph: { fontSize: 16, color: colors.primary, marginRight: spacing.medium, width: 20, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600', flex: 1 },
  imageModalBackdrop: { flex: 1, backgroundColor: 'black' },
  imageModalHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: spacing.medium },
  imageModalTitle: { color: colors.white, fontSize: 17, fontWeight: '600' },
  imageModalCloseText: { color: colors.white, fontSize: 28 },
  fullScreenImage: { flex: 1 },
});
