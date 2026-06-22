// expects route.params: { deliveryId?: string } — deliveryId is optional, matching the
// Dart widget's constructor (see deviation note below).
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Image, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { launchCamera, launchImageLibrary } from 'react-native-image-picker';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { usePodStore } from '../../stores/usePodStore';
import PodPreviewCard from '../../components/PodPreviewCard';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/driver/document_intake_screen.dart (verified against source on
 * 2026-06-22).
 *
 * IMPORTANT CONTEXT: this screen is unreachable dead code in the current Flutter app —
 * it's registered at the named route `/driver/document-intake` but no button anywhere
 * navigates to it, and its companion PodController/PodRepository write to the abandoned
 * `companies/{companyId}/pods/{podId}` collection (see models/pod.ts's file-level
 * comment). The migration plan's Section 4 explicitly calls porting this screen's
 * OCR-capture-and-review UX "a genuinely good UX pattern worth keeping," retargeted at
 * the canonical `pods/{deliveryId}` pipeline — that retargeting is what
 * usePodStore's `intake*` slice does.
 *
 * Deviations from the Flutter source:
 * - `deliveryId` (optional route param, mirroring the Dart widget's already-existing but
 *   silently-ignored constructor parameter) is now actually used: if provided, it skips
 *   auto-matching and attaches OCR data directly to that delivery. This fixes a real gap
 *   in the source rather than replicating it — the parameter existed but nothing ever
 *   read it.
 * - "Review & Edit" fields are read-only here, matching the Dart source's actual
 *   behavior exactly: `_buildEditableField` renders an edit icon but has no onTap/
 *   GestureDetector at all, so tapping a field does nothing in production today either.
 * - The warnings box in PodPreviewCard only renders if the raw OCR text happens to
 *   contain the literal substring "warning" — also ported as-is; it's a pre-existing
 *   dead condition in pod_preview_card.dart, not something introduced here.
 */
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
    if (deliveryId) {
      loadDeliveryById(deliveryId);
    }
  }, [deliveryId, loadDeliveryById]);

  const delivery = deliveryId && selectedDelivery?.id === deliveryId ? selectedDelivery : null;

  const captureFromCamera = async () => {
    try {
      const response = await launchCamera({ mediaType: 'photo', quality: 0.8 });
      if (response.didCancel) return;
      const uri = response.assets?.[0]?.uri;
      if (uri) {
        setCapturedImage(uri);
        setShowOcrInput(true);
      }
    } catch (e) {
      Alert.alert('Error', `Failed to capture image: ${(e as Error).message}`);
    }
  };

  const pickFromGallery = async () => {
    try {
      const response = await launchImageLibrary({ mediaType: 'photo', quality: 0.8 });
      if (response.didCancel) return;
      const uri = response.assets?.[0]?.uri;
      if (uri) {
        setCapturedImage(uri);
        setShowOcrInput(true);
      }
    } catch (e) {
      Alert.alert('Error', `Failed to pick image: ${(e as Error).message}`);
    }
  };

  const parseOcrText = () => {
    const text = ocrTextInput.trim();
    if (text.length === 0) {
      Alert.alert('Missing Information', 'Please enter OCR text or paste invoice details');
      return;
    }
    parseIntakeOcrText(text);
    setShowOcrInput(false);
  };

  const uploadPod = async () => {
    if (!intakeOcrFields || !currentUser) {
      Alert.alert('Missing Information', 'Please capture and parse document first');
      return;
    }

    await uploadIntakeDocument({ companyId: currentUser.companyId, driverId: currentUser.id, delivery });

    if (usePodStore.getState().intakeState === 'success') {
      Alert.alert('Success', `Invoice captured successfully!\nLinked to delivery: ${usePodStore.getState().matchedDeliveryId}`, [
        {
          text: 'OK',
          onPress: () => {
            resetIntake();
            setOcrTextInput('');
            setShowOcrInput(false);
          },
        },
      ]);
    }
  };

  const startOver = () => {
    resetIntake();
    setOcrTextInput('');
    setShowOcrInput(false);
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {isLoading ? <ActivityIndicator color={colors.primary} style={styles.progress} /> : null}

      {/* Step 1: Capture */}
      <View style={styles.card}>
        <View style={styles.stepHeaderRow}>
          <View style={[styles.stepBadge, styles.stepBadgeBlue]}>
            <Text style={styles.stepBadgeText}>1</Text>
          </View>
          <Text style={[textStyles.heading3, styles.stepTitle]}>Capture Invoice Photo</Text>
        </View>
        <Text style={textStyles.bodySmall}>Take a photo of the invoice or delivery note for processing</Text>

        {capturedImageUri ? (
          <View>
            <Image source={{ uri: capturedImageUri }} style={styles.capturedImage} resizeMode="cover" />
            <Text style={styles.capturedLabel}>Photo captured ✓</Text>
          </View>
        ) : null}
      </View>

      {/* Step 2: OCR text input */}
      {showOcrInput ? (
        <View style={styles.card}>
          <View style={styles.stepHeaderRow}>
            <View style={[styles.stepBadge, styles.stepBadgeOrange]}>
              <Text style={styles.stepBadgeText}>2</Text>
            </View>
            <Text style={[textStyles.heading3, styles.stepTitle]}>Enter Invoice Details</Text>
          </View>
          <Text style={textStyles.bodySmall}>Paste the invoice text or manually enter key details below:</Text>

          <TextInput
            style={styles.ocrInput}
            multiline
            numberOfLines={6}
            placeholder={'Invoice Number: INV400098\nTotal Amount: R101,972.94\nSupplier: Meat Traders\nCustomer: Boxer Superstores'}
            value={ocrTextInput}
            onChangeText={setOcrTextInput}
            editable={!isLoading}
          />

          <Pressable style={styles.primaryButton} disabled={isLoading} onPress={parseOcrText}>
            <Text style={textStyles.buttonText}>✓ Parse Invoice Details</Text>
          </Pressable>
        </View>
      ) : null}

      {/* Step 3: Preview */}
      {intakeOcrFields ? (
        <PodPreviewCard fields={intakeOcrFields} flags={intakeDetectionFlags ?? undefined} onEdit={() => setShowOcrInput(true)} />
      ) : null}

      {intakeErrorMessage ? (
        <View style={styles.errorBox}>
          <Text style={styles.errorText}>{intakeErrorMessage}</Text>
        </View>
      ) : null}

      {matchedDeliveryId ? <Text style={styles.matchedText}>Linked to delivery: {matchedDeliveryId}</Text> : null}

      {!intakeOcrFields ? (
        <View>
          <Pressable style={styles.primaryButton} disabled={isLoading} onPress={captureFromCamera}>
            <Text style={textStyles.buttonText}>📷 Take Photo</Text>
          </Pressable>
          <Pressable style={[styles.secondaryButton, isLoading && styles.disabled]} disabled={isLoading} onPress={pickFromGallery}>
            <Text style={styles.secondaryButtonText}>🖼 Choose from Gallery</Text>
          </Pressable>
        </View>
      ) : (
        <View>
          <Pressable style={[styles.successButton, isLoading && styles.disabled]} disabled={isLoading} onPress={uploadPod}>
            <Text style={textStyles.buttonText}>{isLoading ? 'Uploading...' : '☁ Upload Invoice'}</Text>
          </Pressable>
          <Pressable style={[styles.secondaryButton, isLoading && styles.disabled]} disabled={isLoading} onPress={startOver}>
            <Text style={styles.secondaryButtonText}>↺ Start Over</Text>
          </Pressable>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  progress: { marginBottom: spacing.medium },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.medium, ...shadows.card },
  stepHeaderRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small + 4 },
  stepBadge: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  stepBadgeBlue: { backgroundColor: `${colors.info}33` },
  stepBadgeOrange: { backgroundColor: `${colors.warning}33` },
  stepBadgeText: { fontWeight: 'bold', color: colors.textPrimary },
  stepTitle: { flex: 1 },
  capturedImage: { height: 200, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, marginTop: spacing.medium },
  capturedLabel: { color: colors.success, fontWeight: '500', marginTop: spacing.small },
  ocrInput: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    padding: spacing.small + 4,
    marginTop: spacing.small + 4,
    minHeight: 120,
    textAlignVertical: 'top',
    backgroundColor: colors.background,
  },
  primaryButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, alignItems: 'center', paddingVertical: spacing.small + 8, marginTop: spacing.medium },
  secondaryButton: { borderWidth: 1, borderColor: colors.primary, borderRadius: radii.buttonRadius, alignItems: 'center', paddingVertical: spacing.small + 8, marginTop: spacing.small + 4 },
  secondaryButtonText: { color: colors.primary, fontWeight: '600' },
  successButton: { backgroundColor: colors.success, borderRadius: radii.buttonRadius, alignItems: 'center', paddingVertical: spacing.small + 8, marginTop: spacing.medium },
  disabled: { opacity: 0.5 },
  errorBox: { backgroundColor: `${colors.error}14`, borderWidth: 1, borderColor: `${colors.error}80`, borderRadius: radii.borderRadius, padding: spacing.small + 4, marginBottom: spacing.medium },
  errorText: { color: colors.error },
  matchedText: { color: colors.success, marginBottom: spacing.medium, textAlign: 'center' },
});
