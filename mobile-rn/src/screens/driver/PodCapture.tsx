import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { useEffect, useRef, useState } from 'react';
import { Alert, Image, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Asset, launchCamera } from 'react-native-image-picker';
import SignatureView, { SignatureViewRef } from 'react-native-signature-canvas';
import { AppIcon, Card, ErrorState, FormField, IconButton, LoadingState, PrimaryButton, Screen, SecondaryButton, StatusChip, SuccessButton } from '../../components/ui';
import PodQrCodeDialog from '../../components/PodQrCodeDialog';
import { ocrFieldsToJson } from '../../models/ocrFields';
import { PodAccessToken } from '../../repositories/podTokenRepository';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { usePodStore } from '../../stores/usePodStore';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const MAX_DOCUMENTS = 4;

interface PodCaptureProps {
  route: { params: { deliveryId: string } };
  navigation: { goBack: () => void };
}

interface DocumentEntry {
  uri: string;
  type: string;
}

interface PodDraft {
  signatureDataUrl: string | null;
  receiverName: string;
  photos: Asset[];
  documents: DocumentEntry[];
  stampPhoto: Asset | null;
  notes: string;
}

type LocationState = 'idle' | 'checking' | 'verified' | 'unavailable';

export default function PodCapture({ route, navigation }: PodCaptureProps) {
  const { deliveryId } = route.params;
  const currentUser = useAuthStore((s) => s.currentUser);
  const selectedDelivery = useDeliveryStore((s) => s.selectedDelivery);
  const isDeliveryLoading = useDeliveryStore((s) => s.isLoading);
  const loadDeliveryById = useDeliveryStore((s) => s.loadDeliveryById);
  const getCurrentLocation = usePodStore((s) => s.getCurrentLocation);
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
  const [isSavingDraft, setIsSavingDraft] = useState(false);
  const [locationState, setLocationState] = useState<LocationState>('idle');
  const [ocrRawText, setOcrRawText] = useState<string | null>(null);
  const [ocrFields, setOcrFields] = useState<ReturnType<typeof parseOcrFields> | null>(null);
  const [ocrConfidence, setOcrConfidence] = useState<number | null>(null);
  const [isExtractingOcr, setIsExtractingOcr] = useState(false);
  const [qrToken, setQrToken] = useState<PodAccessToken | null>(null);
  const signatureRef = useRef<SignatureViewRef>(null);
  const draftKey = `podsafe:pod-draft:${deliveryId}`;

  useEffect(() => {
    const initialize = async () => {
      await loadDeliveryById(deliveryId);
      try {
        const value = await AsyncStorage.getItem(draftKey);
        if (!value) return;
        const draft = JSON.parse(value) as PodDraft;
        setSignatureDataUrl(draft.signatureDataUrl);
        setReceiverName(draft.receiverName);
        setPhotos(draft.photos);
        setDocuments(draft.documents);
        setStampPhoto(draft.stampPhoto);
        setNotes(draft.notes);
      } catch {
        // A stale or malformed local draft must not block POD capture.
      }
    };
    initialize();
  }, [deliveryId, draftKey, loadDeliveryById]);

  const delivery = selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  const extractOcrFromPhoto = async (uri: string) => {
    setIsExtractingOcr(true);
    try {
      const text = await runOcr(uri);
      setOcrRawText(text);
      if (!text) return;
      const fields = parseOcrFields(text);
      setOcrFields(fields);
      const filledFields = [fields.invoiceNo, fields.supplier, fields.customer, fields.totalIncl, fields.driverName].filter(Boolean).length;
      setOcrConfidence(Math.min(0.6 + 0.08 * filledFields, 0.95));
    } catch (error) {
      Alert.alert('OCR unavailable', `Invoice details could not be extracted: ${(error as Error).message}`);
    } finally {
      setIsExtractingOcr(false);
    }
  };

  const takePhoto = async () => {
    try {
      const response = await launchCamera({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      const asset = response.assets?.[0];
      if (!response.didCancel && asset?.uri) {
        setPhotos((current) => [...current, asset]);
        await extractOcrFromPhoto(asset.uri);
      }
    } catch (error) {
      Alert.alert('Camera unavailable', `Delivery photo could not be captured: ${(error as Error).message}`);
    }
  };

  const chooseDocumentType = (): Promise<string | null> => new Promise((resolve) => {
    Alert.alert('Document type', 'What are you scanning?', [
      { text: 'Invoice', onPress: () => resolve('Invoice') },
      { text: 'Delivery note', onPress: () => resolve('Delivery Note') },
      { text: 'Cancel', style: 'cancel', onPress: () => resolve(null) },
    ]);
  });

  const scanDocument = async () => {
    if (documents.length >= MAX_DOCUMENTS) {
      Alert.alert('Document limit reached', `You can attach up to ${MAX_DOCUMENTS} documents.`);
      return;
    }
    try {
      const response = await launchCamera({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      const asset = response.assets?.[0];
      if (response.didCancel || !asset?.uri) return;
      const type = await chooseDocumentType();
      if (!type) return;
      setDocuments((current) => [...current, { uri: asset.uri!, type }]);
      await extractOcrFromPhoto(asset.uri);
    } catch (error) {
      Alert.alert('Scanner unavailable', `Document could not be captured: ${(error as Error).message}`);
    }
  };

  const takeStampPhoto = async () => {
    try {
      const response = await launchCamera({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      const asset = response.assets?.[0];
      if (!response.didCancel && asset?.uri) setStampPhoto(asset);
    } catch (error) {
      Alert.alert('Camera unavailable', `Customer stamp could not be captured: ${(error as Error).message}`);
    }
  };

  const verifyLocation = async () => {
    setLocationState('checking');
    const location = await getCurrentLocation();
    setLocationState(location ? 'verified' : 'unavailable');
  };

  const saveDraft = async () => {
    setIsSavingDraft(true);
    try {
      await AsyncStorage.setItem(draftKey, JSON.stringify({ signatureDataUrl, receiverName, photos, documents, stampPhoto, notes } satisfies PodDraft));
      Alert.alert('Draft saved', 'Your current proof details are saved on this device.');
    } catch {
      Alert.alert('Draft not saved', 'This device could not save the current POD draft.');
    } finally {
      setIsSavingDraft(false);
    }
  };

  const canSubmit = Boolean(signatureDataUrl && receiverName.trim() && photos.length && documents.length) && !isSubmitting;
  const handleSubmit = async () => {
    if (!currentUser || !delivery || !signatureDataUrl || isSubmitting) return;
    setIsSubmitting(true);
    try {
      await submitPod({
        delivery,
        driverId: currentUser.id,
        companyId: currentUser.companyId,
        signatureDataUrl,
        receiverName: receiverName.trim(),
        notes: notes.trim(),
        photoUris: photos.map((photo) => photo.uri!).filter(Boolean),
        documents,
        stampPhotoUri: stampPhoto?.uri,
        ocrRawText: ocrRawText ?? undefined,
        ocrFields: ocrFields ? ocrFieldsToJson(ocrFields) : undefined,
        ocrConfidence: ocrConfidence ?? undefined,
      });
      await AsyncStorage.removeItem(draftKey);
      Alert.alert('Proof submitted', 'The delivery evidence is saved and ready for review.', [
        { text: 'View QR code', onPress: handleViewQrCode },
        { text: 'Done', onPress: navigation.goBack },
      ]);
    } catch (error) {
      Alert.alert('Submission failed', `Proof could not be submitted: ${(error as Error).message}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleViewQrCode = async () => {
    const token = await getAccessToken(deliveryId);
    if (token) setQrToken(token);
    else Alert.alert('QR code unavailable', 'The public access code is still being generated. Try again shortly.');
  };

  if (!delivery) {
    return <Screen>{isDeliveryLoading ? <LoadingState title="Loading POD capture" /> : <ErrorState title="Delivery unavailable" message="Return to the delivery list and try again." onAction={navigation.goBack} />}</Screen>;
  }

  if (isSubmitting) return <Screen><LoadingState title="Submitting proof of delivery" message="Uploading evidence and confirming the delivery location." /></Screen>;

  const steps = [
    { label: 'Photos', complete: photos.length > 0 },
    { label: 'Signature', complete: Boolean(signatureDataUrl && receiverName.trim()) },
    { label: 'Location', complete: locationState === 'verified' },
  ];

  return (
    <Screen contentContainerStyle={styles.screen}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <View style={styles.intro}>
          <Text style={textStyles.heading2}>Capture proof of delivery</Text>
          <Text style={textStyles.bodyMedium}>{delivery.customerName}</Text>
          <Text style={textStyles.bodySmall}>Invoice {delivery.invoiceNumber}</Text>
        </View>

        <View style={styles.stepRow} accessibilityLabel="POD capture progress">
          {steps.map((step, index) => <View key={step.label} style={styles.stepItem}><StatusChip label={`${index + 1}. ${step.label}`} tone={step.complete ? 'success' : 'neutral'} icon={step.complete ? 'check' : undefined} /></View>)}
        </View>

        <CaptureCard title="1. Delivery photos" description="Add at least one clear photo of the completed delivery." icon="camera" required complete={photos.length > 0}>
          {photos.length ? <MediaPreview assets={photos.map((photo) => ({ uri: photo.uri!, label: 'Delivery photo' }))} onRemove={(index) => setPhotos((current) => current.filter((_, photoIndex) => photoIndex !== index))} /> : null}
          <PrimaryButton label={photos.length ? 'Add another photo' : 'Take delivery photo'} icon="camera" onPress={takePhoto} />
          {photos.length ? <SecondaryButton label="Remove all photos" onPress={() => setPhotos([])} /> : null}
          <OcrState isExtracting={isExtractingOcr} hasFields={Boolean(ocrFields)} confidence={ocrConfidence} />
        </CaptureCard>

        <CaptureCard title="2. Recipient signature" description="Enter the receiver’s name and capture their signature." icon="signature" required complete={Boolean(signatureDataUrl && receiverName.trim())}>
          <FormField label="Receiver name" value={receiverName} onChangeText={setReceiverName} placeholder="Name of the person receiving the delivery" error={!receiverName.trim() ? 'Required before submission.' : undefined} />
          {signatureDataUrl ? <View style={styles.signatureResult}><Image source={{ uri: signatureDataUrl }} resizeMode="contain" style={styles.signaturePreview} /><SecondaryButton label="Clear and redo signature" onPress={() => { setSignatureDataUrl(null); signatureRef.current?.clearSignature(); }} /></View> : <><View style={styles.signatureBox}><SignatureView ref={signatureRef} onOK={setSignatureDataUrl} onEmpty={() => Alert.alert('Signature required', 'Ask the receiver to sign before capturing.')} descriptionText="" webStyle=".m-signature-pad--footer { display: none; margin: 0; }" /></View><View style={styles.inlineButtons}><SecondaryButton label="Clear" onPress={() => signatureRef.current?.clearSignature()} style={styles.halfButton} /><PrimaryButton label="Capture signature" onPress={() => signatureRef.current?.readSignature()} style={styles.halfButton} /></View></>}
        </CaptureCard>

        <CaptureCard title="3. Delivery documents" description="Scan at least one invoice or delivery note. Up to four documents can be attached." icon="file" required complete={documents.length > 0}>
          {documents.length ? <MediaPreview assets={documents.map((document) => ({ uri: document.uri, label: document.type }))} onRemove={(index) => setDocuments((current) => current.filter((_, documentIndex) => documentIndex !== index))} /> : null}
          <PrimaryButton label={documents.length ? 'Scan another document' : 'Scan document'} icon="file" disabled={documents.length >= MAX_DOCUMENTS} onPress={scanDocument} />
          {documents.length ? <SecondaryButton label="Remove all documents" onPress={() => setDocuments([])} /> : null}
          <Text style={textStyles.bodySmall}>{documents.length} of {MAX_DOCUMENTS} documents attached</Text>
        </CaptureCard>

        <CaptureCard title="4. Location confirmation" description="Confirm your location before submitting. Location is recorded again during submission." icon="location" complete={locationState === 'verified'}>
          <StatusChip label={locationState === 'verified' ? 'Location verified' : locationState === 'checking' ? 'Checking location' : locationState === 'unavailable' ? 'Location unavailable' : 'Location not confirmed'} tone={locationState === 'verified' ? 'success' : locationState === 'unavailable' ? 'warning' : 'neutral'} icon={locationState === 'verified' ? 'check' : locationState === 'unavailable' ? 'alert' : 'location'} />
          <SecondaryButton label={locationState === 'checking' ? 'Checking location' : 'Verify current location'} icon="location" loading={locationState === 'checking'} onPress={verifyLocation} />
          {locationState === 'unavailable' ? <Text style={textStyles.bodySmall}>Location permission or signal needs attention. You can still submit, and the app will retry location capture.</Text> : null}
        </CaptureCard>

        <CaptureCard title="Optional evidence" description="Add a customer stamp or helpful notes when they are available." icon="clipboard">
          {stampPhoto ? <MediaPreview assets={[{ uri: stampPhoto.uri!, label: 'Customer stamp' }]} onRemove={() => setStampPhoto(null)} /> : null}
          <SecondaryButton label={stampPhoto ? 'Retake customer stamp' : 'Take customer stamp photo'} icon="camera" onPress={takeStampPhoto} />
          <FormField label="Delivery notes" multiline numberOfLines={4} value={notes} onChangeText={setNotes} placeholder="Add any useful delivery notes" />
        </CaptureCard>
      </ScrollView>

      <View style={styles.submitBar}>
        <View style={styles.submitStatus}><AppIcon name={canSubmit ? 'check' : 'alert'} size={18} color={canSubmit ? colors.verified : colors.contentSecondary} /><Text style={textStyles.bodySmall}>{canSubmit ? 'Required evidence is complete.' : 'Photo, signature, receiver name, and document are required.'}</Text></View>
        <View style={styles.submitActions}><SecondaryButton label="Save draft" loading={isSavingDraft} onPress={saveDraft} style={styles.submitSecondary} /><SuccessButton label="Submit POD" icon="check" disabled={!canSubmit} onPress={handleSubmit} style={styles.submitPrimary} /></View>
      </View>

      {qrToken ? <PodQrCodeDialog visible token={qrToken} onClose={() => setQrToken(null)} /> : null}
    </Screen>
  );
}

function CaptureCard({ title, description, icon, required = false, complete = false, children }: { title: string; description: string; icon: 'camera' | 'signature' | 'file' | 'location' | 'clipboard'; required?: boolean; complete?: boolean; children: React.ReactNode }) {
  return <Card style={styles.captureCard}><View style={styles.captureHeader}><View style={styles.captureTitle}><AppIcon name={icon} size={22} color={colors.shell} /><View style={styles.captureCopy}><Text style={textStyles.heading3}>{title}</Text><Text style={textStyles.bodySmall}>{description}</Text></View></View>{required ? <StatusChip label={complete ? 'Complete' : 'Required'} tone={complete ? 'success' : 'warning'} icon={complete ? 'check' : 'alert'} /> : null}</View><View style={styles.captureContent}>{children}</View></Card>;
}

function MediaPreview({ assets, onRemove }: { assets: { uri: string; label: string }[]; onRemove: (index: number) => void }) {
  return <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.mediaRow}>{assets.map((asset, index) => <View key={`${asset.uri}-${index}`} style={styles.mediaItem}><Image source={{ uri: asset.uri }} style={styles.mediaImage} resizeMode="cover" /><Text numberOfLines={1} style={styles.mediaLabel}>{asset.label}</Text><IconButton icon="close" accessibilityLabel={`Remove ${asset.label}`} onPress={() => onRemove(index)} style={styles.removeMedia} /></View>)}</ScrollView>;
}

function OcrState({ isExtracting, hasFields, confidence }: { isExtracting: boolean; hasFields: boolean; confidence: number | null }) {
  if (!isExtracting && !hasFields) return null;
  return <View style={styles.ocrState}><AppIcon name={isExtracting ? 'activity' : 'check'} size={18} color={isExtracting ? colors.active : colors.verified} /><Text style={textStyles.bodySmall}>{isExtracting ? 'Extracting invoice details…' : `Invoice details extracted${confidence != null ? ` (${Math.round(confidence * 100)}% confidence)` : ''}`}</Text></View>;
}

const styles = StyleSheet.create({
  screen: { paddingHorizontal: 0 },
  content: { gap: spacing.medium, padding: spacing.medium, paddingBottom: spacing.large },
  intro: { gap: spacing.xs },
  stepRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  stepItem: { flexGrow: 1 },
  captureCard: { gap: spacing.medium },
  captureHeader: { alignItems: 'flex-start', flexDirection: 'row', gap: spacing.small, justifyContent: 'space-between' },
  captureTitle: { flex: 1, flexDirection: 'row', gap: spacing.small },
  captureCopy: { flex: 1, gap: spacing.xs },
  captureContent: { gap: spacing.medium },
  signatureBox: { backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.inputRadius, borderWidth: 1, height: 210, overflow: 'hidden' },
  signatureResult: { gap: spacing.medium },
  signaturePreview: { backgroundColor: colors.surface, borderColor: colors.verified, borderRadius: radii.inputRadius, borderWidth: 1, height: 180, width: '100%' },
  inlineButtons: { flexDirection: 'row', gap: spacing.small },
  halfButton: { flex: 1 },
  mediaRow: { gap: spacing.small },
  mediaItem: { position: 'relative', width: 128 },
  mediaImage: { backgroundColor: colors.surfaceMuted, borderRadius: radii.inputRadius, height: 96, width: 128 },
  mediaLabel: { ...textStyles.labelSmall, marginTop: spacing.xs },
  removeMedia: { backgroundColor: colors.surface, borderColor: colors.border, borderWidth: 1, position: 'absolute', right: spacing.xs, top: spacing.xs },
  ocrState: { alignItems: 'center', backgroundColor: colors.verifiedMuted, borderRadius: radii.inputRadius, flexDirection: 'row', gap: spacing.small, padding: spacing.small },
  submitBar: { backgroundColor: colors.surface, borderTopColor: colors.border, borderTopWidth: 1, gap: spacing.small, padding: spacing.medium },
  submitStatus: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  submitActions: { flexDirection: 'row', gap: spacing.small },
  submitSecondary: { flex: 1 },
  submitPrimary: { flex: 1 },
});
