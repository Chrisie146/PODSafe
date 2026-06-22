// expects route.params: { deliveryId: string }
import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Asset, launchCamera } from 'react-native-image-picker';
import SignatureView, { SignatureViewRef } from 'react-native-signature-canvas';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { usePodStore } from '../../stores/usePodStore';
import { PodAccessToken } from '../../repositories/podTokenRepository';
import { ocrFieldsToJson } from '../../models/ocrFields';
import PodQrCodeDialog from '../../components/PodQrCodeDialog';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/driver/pod_capture_screen.dart (verified against source on
 * 2026-06-22) — the primary driver POD capture flow.
 *
 * Deviations from the Flutter source:
 * - Takes `deliveryId` via route params and loads the delivery through
 *   useDeliveryStore, matching DeliveryDetails.tsx/ReportIssue.tsx's established pattern.
 * - "Scan Document" is degraded to a plain camera capture (no auto-edge-detection or
 *   multi-page scanning) — see the migration plan's Risk Register #1: no mature bare-CLI
 *   document-scanner package exists yet; this ships a working capture path now rather
 *   than blocking Phase 2 on that spike.
 * - Bug fix: the Dart source's "Take Stamp Photo" button (_takeStampPhoto) actually adds
 *   the photo to the regular delivery-photos list and never sets `_stampPhotoFile`, so the
 *   "Customer Stamp" feature is permanently non-functional there (stampPhotoUrl is always
 *   null in production). This port wires the stamp photo to its own state correctly, and
 *   skips running OCR on it (it's a corporate stamp, not invoice text).
 * - Success flow uses Alert with action buttons instead of a custom AlertDialog; "View QR
 *   Code" opens PodQrCodeDialog. Navigating back relies on the delivery list's live
 *   Firestore listener to reflect the status change, instead of Dart's pop-with-result.
 * - Receiver name "required" validation in the Dart source is dead code (a
 *   TextFormField validator with no surrounding Form ever calls .validate()) — the real
 *   gate is canSubmit(), which is what's ported here.
 */

const MAX_DOCUMENTS = 4;

interface PodCaptureProps {
  route: { params: { deliveryId: string } };
  navigation: { goBack: () => void };
}

interface DocumentEntry {
  uri: string;
  type: string;
}

export default function PodCapture({ route, navigation }: PodCaptureProps) {
  const { deliveryId } = route.params;
  const currentUser = useAuthStore((s) => s.currentUser);
  const selectedDelivery = useDeliveryStore((s) => s.selectedDelivery);
  const loadDeliveryById = useDeliveryStore((s) => s.loadDeliveryById);

  const runOcr = usePodStore((s) => s.runOcr);
  const parseOcrFields = usePodStore((s) => s.parseOcrFields);
  const submitPod = usePodStore((s) => s.submitPod);
  const getAccessToken = usePodStore((s) => s.getAccessToken);

  const [signatureDataUrl, setSignatureDataUrl] = useState<string | null>(null);
  const [receiverName, setReceiverName] = useState('');
  const [photos, setPhotos] = useState<Asset[]>([]);
  const [documents, setDocuments] = useState<DocumentEntry[]>([]);
  const [stampPhoto, setStampPhoto] = useState<Asset | null>(null);
  const [notes, setNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [ocrRawText, setOcrRawText] = useState<string | null>(null);
  const [ocrFields, setOcrFields] = useState<ReturnType<typeof parseOcrFields> | null>(null);
  const [ocrConfidence, setOcrConfidence] = useState<number | null>(null);
  const [isExtractingOcr, setIsExtractingOcr] = useState(false);

  const [qrToken, setQrToken] = useState<PodAccessToken | null>(null);

  const signatureRef = useRef<SignatureViewRef>(null);

  useEffect(() => {
    loadDeliveryById(deliveryId);
  }, [deliveryId, loadDeliveryById]);

  const delivery = selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  if (!delivery) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  const extractOcrFromPhoto = async (uri: string) => {
    setIsExtractingOcr(true);
    try {
      const text = await runOcr(uri);
      setOcrRawText(text);
      if (text.length > 0) {
        const fields = parseOcrFields(text);
        setOcrFields(fields);

        let filledFields = 0;
        if (fields.invoiceNo) filledFields++;
        if (fields.supplier) filledFields++;
        if (fields.customer) filledFields++;
        if (fields.totalIncl != null) filledFields++;
        if (fields.driverName) filledFields++;
        setOcrConfidence(Math.min(0.6 + 0.08 * filledFields, 0.95));
      }
    } catch (e) {
      Alert.alert('OCR Notice', `OCR extraction failed: ${(e as Error).message}`);
    } finally {
      setIsExtractingOcr(false);
    }
  };

  const takePhoto = async () => {
    try {
      const response = await launchCamera({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      if (response.didCancel) return;
      const asset = response.assets?.[0];
      if (asset?.uri) {
        setPhotos((prev) => [...prev, asset]);
        await extractOcrFromPhoto(asset.uri);
      }
    } catch (e) {
      Alert.alert('Error', `Failed to capture photo: ${(e as Error).message}`);
    }
  };

  const removeAllPhotos = () => setPhotos([]);
  const removePhoto = (index: number) => setPhotos((prev) => prev.filter((_, i) => i !== index));

  const pickDocumentType = (): Promise<string | null> =>
    new Promise((resolve) => {
      Alert.alert('Document Type', 'What type of document is this?', [
        { text: 'Invoice', onPress: () => resolve('Invoice') },
        { text: 'Delivery Note', onPress: () => resolve('Delivery Note') },
        { text: 'Cancel', style: 'cancel', onPress: () => resolve(null) },
      ]);
    });

  const scanDocument = async () => {
    if (documents.length >= MAX_DOCUMENTS) {
      Alert.alert('Limit Reached', `Maximum ${MAX_DOCUMENTS} documents allowed`);
      return;
    }

    try {
      const response = await launchCamera({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      if (response.didCancel) return;
      const asset = response.assets?.[0];
      if (!asset?.uri) return;

      const docType = await pickDocumentType();
      if (!docType) return;

      setDocuments((prev) => [...prev, { uri: asset.uri!, type: docType }]);
      await extractOcrFromPhoto(asset.uri);
    } catch (e) {
      Alert.alert('Error', `Failed to scan document: ${(e as Error).message}`);
    }
  };

  const removeAllDocuments = () => setDocuments([]);
  const removeDocument = (index: number) => setDocuments((prev) => prev.filter((_, i) => i !== index));

  const takeStampPhoto = async () => {
    try {
      const response = await launchCamera({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      if (response.didCancel) return;
      const asset = response.assets?.[0];
      if (asset?.uri) {
        setStampPhoto(asset);
      }
    } catch (e) {
      Alert.alert('Error', `Failed to capture stamp photo: ${(e as Error).message}`);
    }
  };

  const canSubmit = signatureDataUrl != null && photos.length > 0 && documents.length > 0 && receiverName.trim().length > 0 && !isSubmitting;

  const handleSubmit = async () => {
    if (!currentUser || isSubmitting) return;

    setIsSubmitting(true);
    try {
      await submitPod({
        delivery,
        driverId: currentUser.id,
        companyId: currentUser.companyId,
        signatureDataUrl: signatureDataUrl!,
        receiverName: receiverName.trim(),
        notes: notes.trim(),
        photoUris: photos.map((p) => p.uri!).filter(Boolean),
        documents,
        stampPhotoUri: stampPhoto?.uri,
        ocrRawText: ocrRawText ?? undefined,
        ocrFields: ocrFields ? ocrFieldsToJson(ocrFields) : undefined,
        ocrConfidence: ocrConfidence ?? undefined,
      });

      Alert.alert('Success!', 'Proof of delivery has been submitted successfully.', [
        { text: 'View QR Code', onPress: handleViewQrCode },
        { text: 'Done', onPress: () => navigation.goBack() },
      ]);
    } catch (e) {
      Alert.alert('Error', `Failed to submit POD: ${(e as Error).message}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleViewQrCode = async () => {
    const token = await getAccessToken(deliveryId);
    if (token) {
      setQrToken(token);
    } else {
      Alert.alert('Notice', 'QR code is being generated. Please try again in a moment.');
    }
  };

  if (isSubmitting) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.success} size="large" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.infoBanner}>
        <Text style={styles.infoBannerText}>ℹ️ Complete all steps to submit proof of delivery</Text>
      </View>

      {/* 1. Signature */}
      <View style={styles.card}>
        <Text style={textStyles.heading3}>1. Customer Signature</Text>
        <Text style={textStyles.bodySmall}>Customer: {delivery.customerName}</Text>

        <TextInput
          style={styles.input}
          placeholder="Name of person signing/receiving delivery"
          value={receiverName}
          onChangeText={setReceiverName}
        />

        {signatureDataUrl ? (
          <View>
            <Image source={{ uri: signatureDataUrl }} style={styles.signaturePreview} resizeMode="contain" />
            <Pressable
              style={styles.secondaryButton}
              onPress={() => {
                setSignatureDataUrl(null);
                signatureRef.current?.clearSignature();
              }}
            >
              <Text style={styles.secondaryButtonText}>Clear & Redo</Text>
            </Pressable>
          </View>
        ) : (
          <View>
            <View style={styles.signatureBox}>
              <SignatureView
                ref={signatureRef}
                onOK={(dataUrl) => setSignatureDataUrl(dataUrl)}
                onEmpty={() => Alert.alert('Missing Signature', 'Please draw your signature first')}
                descriptionText=""
                webStyle=".m-signature-pad--footer { display: none; margin: 0; }"
              />
            </View>
            <View style={styles.buttonRow}>
              <Pressable style={styles.secondaryButton} onPress={() => signatureRef.current?.clearSignature()}>
                <Text style={styles.secondaryButtonText}>Clear</Text>
              </Pressable>
              <Pressable style={styles.primaryButton} onPress={() => signatureRef.current?.readSignature()}>
                <Text style={textStyles.buttonText}>Capture Signature</Text>
              </Pressable>
            </View>
          </View>
        )}
      </View>

      {/* 2. Photo */}
      <View style={styles.card}>
        <Text style={textStyles.heading3}>2. Delivery Photo</Text>

        {photos.length > 0 ? (
          <View>
            <Image source={{ uri: photos[0].uri }} style={styles.mainPreview} resizeMode="cover" />
            <View style={styles.buttonRow}>
              <Pressable style={styles.secondaryButton} onPress={takePhoto}>
                <Text style={styles.secondaryButtonText}>Add Another Photo</Text>
              </Pressable>
              <Pressable style={styles.secondaryButton} onPress={removeAllPhotos}>
                <Text style={styles.secondaryButtonText}>Remove All</Text>
              </Pressable>
            </View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.thumbRow}>
              {photos.map((photo, index) => (
                <View key={`${photo.uri}-${index}`} style={styles.thumbWrap}>
                  <Image source={{ uri: photo.uri }} style={styles.thumb} resizeMode="cover" />
                  <Pressable style={styles.thumbRemove} onPress={() => removePhoto(index)}>
                    <Text style={styles.thumbRemoveText}>✕</Text>
                  </Pressable>
                </View>
              ))}
            </ScrollView>
          </View>
        ) : (
          <Pressable style={styles.captureBox} onPress={takePhoto}>
            <Text style={textStyles.buttonText}>📷 Take Photo</Text>
          </Pressable>
        )}

        {photos.length > 0 ? (
          <View style={[styles.ocrBanner, ocrFields ? styles.ocrBannerSuccess : styles.ocrBannerInfo]}>
            {isExtractingOcr ? (
              <ActivityIndicator size="small" color={colors.info} />
            ) : (
              <Text style={styles.ocrBannerIcon}>{ocrFields ? '✓' : 'ℹ️'}</Text>
            )}
            <Text style={[styles.ocrBannerText, ocrFields ? styles.ocrBannerTextSuccess : styles.ocrBannerTextInfo]}>
              {isExtractingOcr
                ? 'Extracting invoice data...'
                : ocrFields
                  ? `Invoice data extracted (${ocrConfidence != null ? (ocrConfidence * 100).toFixed(0) : '0'}% confidence)`
                  : 'Ready to extract invoice data'}
            </Text>
          </View>
        ) : null}
      </View>

      {/* 3. Documents */}
      <View style={styles.card}>
        <View style={styles.headerRow}>
          <View style={styles.headerTextBox}>
            <Text style={textStyles.heading3}>3. Scanned Documents *</Text>
            <Text style={styles.italicHint}>Scan Invoice or Delivery Note (Required)</Text>
          </View>
          {documents.length > 0 ? (
            <View style={styles.countBadge}>
              <Text style={styles.countBadgeText}>
                {documents.length}/{MAX_DOCUMENTS}
              </Text>
            </View>
          ) : null}
        </View>

        {documents.length > 0 ? (
          <View>
            <Image source={{ uri: documents[0].uri }} style={styles.mainPreview} resizeMode="contain" />
            <View style={styles.docTypeBadge}>
              <Text style={styles.docTypeBadgeText}>{documents[0].type}</Text>
            </View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.thumbRow}>
              {documents.map((doc, index) => (
                <View key={`${doc.uri}-${index}`} style={styles.thumbWrap}>
                  <Image source={{ uri: doc.uri }} style={styles.thumb} resizeMode="cover" />
                  <Text style={styles.thumbLabel} numberOfLines={1}>
                    {doc.type}
                  </Text>
                  <Pressable style={styles.thumbRemove} onPress={() => removeDocument(index)}>
                    <Text style={styles.thumbRemoveText}>✕</Text>
                  </Pressable>
                </View>
              ))}
            </ScrollView>
            <View style={styles.buttonRow}>
              {documents.length < MAX_DOCUMENTS ? (
                <Pressable style={styles.secondaryButton} onPress={scanDocument}>
                  <Text style={styles.secondaryButtonText}>Scan Another</Text>
                </Pressable>
              ) : null}
              <Pressable style={styles.secondaryButton} onPress={removeAllDocuments}>
                <Text style={[styles.secondaryButtonText, styles.dangerText]}>Remove All</Text>
              </Pressable>
            </View>
          </View>
        ) : (
          <View>
            <Pressable style={styles.captureBox} onPress={scanDocument}>
              <Text style={textStyles.buttonText}>📄 Scan Document</Text>
            </Pressable>
            <Text style={styles.italicHintCenter}>Capture a clear photo of the document</Text>
          </View>
        )}
      </View>

      {/* 4. Stamp (optional) */}
      <View style={styles.card}>
        <Text style={textStyles.heading3}>4. Customer Stamp (Optional)</Text>
        <Text style={styles.italicHint}>For corporate customers like Checkers, Boxer, Pick n Pay</Text>

        {stampPhoto ? (
          <View>
            <Image source={{ uri: stampPhoto.uri }} style={styles.mainPreview} resizeMode="cover" />
            <View style={styles.buttonRow}>
              <Pressable style={styles.secondaryButton} onPress={() => setStampPhoto(null)}>
                <Text style={styles.secondaryButtonText}>Remove</Text>
              </Pressable>
              <Pressable style={styles.secondaryButton} onPress={takeStampPhoto}>
                <Text style={styles.secondaryButtonText}>Retake</Text>
              </Pressable>
            </View>
          </View>
        ) : (
          <View>
            <Pressable style={styles.captureBoxSmall} onPress={takeStampPhoto}>
              <Text style={textStyles.buttonText}>Take Stamp Photo</Text>
            </Pressable>
            <Text style={styles.italicHintCenter}>Skip if not applicable</Text>
          </View>
        )}
      </View>

      {/* 5. Notes */}
      <View style={styles.card}>
        <Text style={textStyles.heading3}>5. Additional Notes (Optional)</Text>
        <TextInput style={styles.notesInput} multiline numberOfLines={4} placeholder="Enter any additional notes..." value={notes} onChangeText={setNotes} />
      </View>

      <Pressable style={[styles.submitButton, !canSubmit && styles.submitButtonDisabled]} disabled={!canSubmit} onPress={handleSubmit}>
        <Text style={textStyles.buttonText}>✓ Submit POD</Text>
      </Pressable>
      {!canSubmit ? <Text style={styles.submitHint}>Please capture both signature and photo to submit</Text> : null}

      {qrToken ? <PodQrCodeDialog visible token={qrToken} onClose={() => setQrToken(null)} /> : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  infoBanner: {
    backgroundColor: `${colors.info}1A`,
    borderRadius: radii.borderRadius,
    padding: spacing.medium,
    marginBottom: spacing.large,
  },
  infoBannerText: { color: colors.info },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
    ...shadows.card,
  },
  headerRow: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between' },
  headerTextBox: { flex: 1 },
  italicHint: { fontSize: 12, color: colors.textSecondary, fontStyle: 'italic', marginTop: 2 },
  italicHintCenter: { fontSize: 12, color: colors.textSecondary, fontStyle: 'italic', textAlign: 'center', marginTop: spacing.small },
  countBadge: { backgroundColor: colors.success, borderRadius: 12, paddingHorizontal: spacing.small, paddingVertical: 4 },
  countBadgeText: { color: colors.white, fontWeight: 'bold', fontSize: 12 },
  input: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    padding: spacing.small + 4,
    marginTop: spacing.medium,
    marginBottom: spacing.medium,
    backgroundColor: colors.background,
  },
  notesInput: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    padding: spacing.small + 4,
    marginTop: spacing.small + 4,
    minHeight: 100,
    textAlignVertical: 'top',
  },
  signatureBox: { height: 200, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.white },
  signaturePreview: { height: 200, borderWidth: 1, borderColor: colors.success, borderRadius: radii.borderRadius, backgroundColor: colors.white },
  mainPreview: { height: 200, width: '100%', borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.success, marginTop: spacing.small + 4 },
  captureBox: {
    height: 200,
    borderRadius: radii.borderRadius,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.divider,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: spacing.small + 4,
  },
  captureBoxSmall: {
    height: 100,
    borderRadius: radii.borderRadius,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.divider,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: spacing.small + 4,
  },
  buttonRow: { flexDirection: 'row', justifyContent: 'space-evenly', gap: spacing.small, marginTop: spacing.small + 4 },
  primaryButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  secondaryButton: { paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, alignItems: 'center' },
  secondaryButtonText: { color: colors.primary, fontWeight: '600' },
  dangerText: { color: colors.error },
  thumbRow: { marginTop: spacing.small + 4 },
  thumbWrap: { marginRight: spacing.small, width: 100 },
  thumb: { width: 100, height: 70, borderRadius: radii.borderRadius, backgroundColor: colors.divider },
  thumbLabel: { fontSize: 10, color: colors.textSecondary, marginTop: 2 },
  thumbRemove: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: 10,
    width: 20,
    height: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  thumbRemoveText: { color: colors.white, fontSize: 12 },
  docTypeBadge: { alignSelf: 'flex-start', backgroundColor: `${colors.primary}1A`, borderRadius: 6, paddingHorizontal: spacing.small + 4, paddingVertical: 4, marginTop: spacing.small },
  docTypeBadgeText: { color: colors.primary, fontWeight: '600', fontSize: 12 },
  ocrBanner: { flexDirection: 'row', alignItems: 'center', borderRadius: radii.borderRadius, padding: spacing.small + 4, marginTop: spacing.medium, borderWidth: 1 },
  ocrBannerInfo: { backgroundColor: `${colors.info}1A`, borderColor: `${colors.info}80` },
  ocrBannerSuccess: { backgroundColor: `${colors.success}1A`, borderColor: `${colors.success}80` },
  ocrBannerIcon: { marginRight: spacing.small },
  ocrBannerText: { fontSize: 12, fontWeight: '600' },
  ocrBannerTextInfo: { color: colors.info },
  ocrBannerTextSuccess: { color: colors.success },
  submitButton: {
    backgroundColor: colors.success,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.medium,
    alignItems: 'center',
    marginTop: spacing.medium,
    ...shadows.button,
  },
  submitButtonDisabled: { opacity: 0.5 },
  submitHint: { color: colors.error, fontSize: 12, textAlign: 'center', marginTop: spacing.small + 4 },
});
