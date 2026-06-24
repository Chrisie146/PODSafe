import React, { useEffect, useState } from 'react';
import { Alert, Image, ScrollView, StyleSheet, Text, View } from 'react-native';
import { launchCamera, launchImageLibrary } from 'react-native-image-picker';
import { AppIcon, Card, ErrorState, FormField, LoadingState, PrimaryButton, Screen, SecondaryButton, StatusChip, SuccessButton } from '../../components/ui';
import PodPreviewCard from '../../components/PodPreviewCard';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { usePodStore } from '../../stores/usePodStore';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

interface DocumentIntakeProps {
  route: { params?: { deliveryId?: string } };
}

export default function DocumentIntake({ route }: DocumentIntakeProps) {
  const deliveryId = route.params?.deliveryId;
  const currentUser = useAuthStore((s) => s.currentUser);
  const selectedDelivery = useDeliveryStore((s) => s.selectedDelivery);
  const loadDeliveryById = useDeliveryStore((s) => s.loadDeliveryById);
  const intakeState = usePodStore((s) => s.intakeState);
  const intakeErrorMessage = usePodStore((s) => s.intakeErrorMessage);
  const capturedImageUri = usePodStore((s) => s.capturedImageUri);
  const intakeOcrFields = usePodStore((s) => s.intakeOcrFields);
  const intakeDetectionFlags = usePodStore((s) => s.intakeDetectionFlags);
  const matchedDeliveryId = usePodStore((s) => s.matchedDeliveryId);
  const setCapturedImage = usePodStore((s) => s.setCapturedImage);
  const parseIntakeOcrText = usePodStore((s) => s.parseIntakeOcrText);
  const uploadIntakeDocument = usePodStore((s) => s.uploadIntakeDocument);
  const resetIntake = usePodStore((s) => s.resetIntake);
  const [ocrTextInput, setOcrTextInput] = useState('');
  const [showOcrInput, setShowOcrInput] = useState(false);
  const isLoading = intakeState === 'capturing' || intakeState === 'parsingOcr' || intakeState === 'uploading';

  useEffect(() => {
    if (deliveryId) loadDeliveryById(deliveryId);
  }, [deliveryId, loadDeliveryById]);

  const delivery = deliveryId && selectedDelivery?.id === deliveryId ? selectedDelivery : null;
  const capture = async (fromGallery: boolean) => {
    try {
      const response = fromGallery ? await launchImageLibrary({ mediaType: 'photo', quality: 0.8 }) : await launchCamera({ mediaType: 'photo', quality: 0.8 });
      const uri = response.assets?.[0]?.uri;
      if (!response.didCancel && uri) {
        setCapturedImage(uri);
        setShowOcrInput(true);
      }
    } catch (error) {
      Alert.alert('Document unavailable', `The image could not be selected: ${(error as Error).message}`);
    }
  };
  const parseOcrText = () => {
    const text = ocrTextInput.trim();
    if (!text) {
      Alert.alert('Invoice details required', 'Paste or enter invoice details before continuing.');
      return;
    }
    parseIntakeOcrText(text);
    setShowOcrInput(false);
  };
  const uploadPod = async () => {
    if (!intakeOcrFields || !currentUser) return;
    await uploadIntakeDocument({ companyId: currentUser.companyId, driverId: currentUser.id, delivery });
    if (usePodStore.getState().intakeState === 'success') {
      Alert.alert('Invoice captured', `The document is linked to delivery ${usePodStore.getState().matchedDeliveryId ?? 'record'}.`, [{ text: 'Done', onPress: startOver }]);
    }
  };
  const startOver = () => {
    resetIntake();
    setOcrTextInput('');
    setShowOcrInput(false);
  };

  if (isLoading && !capturedImageUri) return <Screen><LoadingState title="Preparing document intake" /></Screen>;

  return (
    <Screen contentContainerStyle={styles.screen}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={styles.intro}><Text style={textStyles.heading2}>Document intake</Text><Text style={textStyles.bodyMedium}>Capture and review invoice data for the canonical POD record.</Text></View>
        <Card style={styles.card}>
          <StepHeader number="1" title="Capture invoice or delivery note" complete={Boolean(capturedImageUri)} />
          <Text style={textStyles.bodySmall}>Use a clear, well-lit photo so the invoice data can be reviewed before it is linked.</Text>
          {capturedImageUri ? <View style={styles.previewWrap}><Image source={{ uri: capturedImageUri }} style={styles.preview} resizeMode="cover" /><StatusChip label="Photo captured" tone="success" icon="check" /></View> : <View style={styles.emptyPreview}><AppIcon name="camera" size={32} color={colors.contentSecondary} /><Text style={textStyles.bodySmall}>No document image selected</Text></View>}
          {!intakeOcrFields ? <View style={styles.actions}><PrimaryButton label="Take photo" icon="camera" disabled={isLoading} onPress={() => capture(false)} /><SecondaryButton label="Choose from gallery" icon="image" disabled={isLoading} onPress={() => capture(true)} /></View> : null}
        </Card>

        {showOcrInput ? <Card style={styles.card}><StepHeader number="2" title="Review invoice details" complete={Boolean(intakeOcrFields)} /><FormField label="Invoice text" multiline numberOfLines={7} value={ocrTextInput} onChangeText={setOcrTextInput} editable={!isLoading} placeholder={'Invoice Number: INV400098\nTotal Amount: R101,972.94\nSupplier: Meat Traders'} helperText="Paste the extracted text or enter the key invoice fields." /><PrimaryButton label="Parse invoice details" icon="clipboard" loading={isLoading} onPress={parseOcrText} /></Card> : null}

        {intakeOcrFields ? <View style={styles.previewCard}><PodPreviewCard fields={intakeOcrFields} flags={intakeDetectionFlags ?? undefined} onEdit={() => setShowOcrInput(true)} /></View> : null}
        {matchedDeliveryId ? <StatusChip label={`Linked to delivery ${matchedDeliveryId}`} tone="success" icon="check" /> : null}
        {intakeErrorMessage ? <ErrorState title="Document intake needs attention" message={intakeErrorMessage} onAction={startOver} /> : null}

        {intakeOcrFields ? <View style={styles.actions}><SuccessButton label="Upload invoice" icon="upload" loading={isLoading} onPress={uploadPod} /><SecondaryButton label="Start over" icon="close" disabled={isLoading} onPress={startOver} /></View> : null}
      </ScrollView>
    </Screen>
  );
}

function StepHeader({ number, title, complete }: { number: string; title: string; complete: boolean }) {
  return <View style={styles.stepHeader}><View style={styles.stepNumber}><Text style={styles.stepNumberText}>{number}</Text></View><Text style={styles.stepTitle}>{title}</Text><StatusChip label={complete ? 'Complete' : 'In progress'} tone={complete ? 'success' : 'info'} icon={complete ? 'check' : undefined} /></View>;
}

const styles = StyleSheet.create({
  screen: { paddingHorizontal: 0 },
  content: { gap: spacing.medium, padding: spacing.medium, paddingBottom: spacing.xxLarge },
  intro: { gap: spacing.xs },
  card: { gap: spacing.medium },
  stepHeader: { alignItems: 'center', flexDirection: 'row', gap: spacing.small },
  stepNumber: { alignItems: 'center', backgroundColor: colors.activeMuted, borderRadius: 16, height: 32, justifyContent: 'center', width: 32 },
  stepNumberText: { ...textStyles.label, color: colors.shell },
  stepTitle: { ...textStyles.heading3, flex: 1 },
  previewWrap: { gap: spacing.small },
  preview: { borderColor: colors.border, borderRadius: radii.inputRadius, borderWidth: 1, height: 220, width: '100%' },
  emptyPreview: { alignItems: 'center', backgroundColor: colors.surfaceMuted, borderRadius: radii.inputRadius, gap: spacing.small, justifyContent: 'center', minHeight: 160, padding: spacing.medium },
  actions: { gap: spacing.small },
  previewCard: { overflow: 'hidden' },
});
