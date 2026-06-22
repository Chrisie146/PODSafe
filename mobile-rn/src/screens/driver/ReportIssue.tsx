// expects route.params: { deliveryId: string; isAtDeliverySite: boolean }
import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Asset, launchCamera, launchImageLibrary } from 'react-native-image-picker';
import SignatureView, { SignatureViewRef } from 'react-native-signature-canvas';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { ApprovalLevel, Claim, ClaimType, CustomField, claimTypeDisplayText } from '../../models/claim';
import { CustomFieldDefinition } from '../../models/companyClaimSettings';
import { DeliveryItem } from '../../models/delivery';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/driver/report_issue_screen.dart.
 *
 * Deviations from the Flutter source:
 * - Takes `deliveryId` via route params and loads the delivery through useDeliveryStore
 *   (matches DeliveryDetails.tsx's pattern), instead of receiving the full `Delivery`
 *   object as a constructor arg. `pod` is dropped entirely: the only call site
 *   (delivery_details_screen.dart) always passes `pod: null` with a "TODO: Get POD if
 *   exists" comment, so there is nothing real to port there yet.
 * - "Issue Type" and dropdown-type custom fields use a chip selector (Pressable row),
 *   not a native dropdown — no picker library is installed in this project, and this
 *   matches the house convention elsewhere of plain Pressable/chip UI instead of pulling
 *   in a new dependency for one widget (see MyClaims.tsx's STATUS_CHIPS).
 * - Validation messages use RN's built-in Alert instead of a SnackBar equivalent.
 * - Signature capture: submit calls signatureRef.readSignature(), whose onOK/onEmpty
 *   callback continues the submit flow (see handleSubmitPress/finishSubmit) — the
 *   library only exposes the signature data asynchronously through that callback.
 */

interface ReportIssueProps {
  route: { params: { deliveryId: string; isAtDeliverySite: boolean } };
  navigation: { goBack: () => void };
}

type AffectedItem = { description: string; quantity: number; unit?: string };

export default function ReportIssue({ route, navigation }: ReportIssueProps) {
  const { deliveryId, isAtDeliverySite } = route.params;
  const currentUser = useAuthStore((s) => s.currentUser);

  const selectedDelivery = useDeliveryStore((s) => s.selectedDelivery);
  const loadDeliveryById = useDeliveryStore((s) => s.loadDeliveryById);

  const companyId = useClaimStore((s) => s.companyId);
  const settings = useClaimStore((s) => s.settings);
  const initialize = useClaimStore((s) => s.initialize);
  const getEnabledClaimTypes = useClaimStore((s) => s.getEnabledClaimTypes);
  const getCustomFieldsForType = useClaimStore((s) => s.getCustomFieldsForType);
  const getWorkflowForType = useClaimStore((s) => s.getWorkflowForType);
  const generateClaimId = useClaimStore((s) => s.generateClaimId);
  const uploadPhoto = useClaimStore((s) => s.uploadPhoto);
  const uploadSignature = useClaimStore((s) => s.uploadSignature);
  const getCurrentLocation = useClaimStore((s) => s.getCurrentLocation);
  const calculateEvidenceQualityScore = useClaimStore((s) => s.calculateEvidenceQualityScore);
  const createClaim = useClaimStore((s) => s.createClaim);

  const [selectedType, setSelectedType] = useState<ClaimType | null>(null);
  const [description, setDescription] = useState('');
  const [photos, setPhotos] = useState<Asset[]>([]);
  const [customFieldValues, setCustomFieldValues] = useState<Record<string, unknown>>({});
  const [affectedItems, setAffectedItems] = useState<AffectedItem[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const signatureRef = useRef<SignatureViewRef>(null);

  useEffect(() => {
    loadDeliveryById(deliveryId);
  }, [deliveryId, loadDeliveryById]);

  useEffect(() => {
    if (!companyId && currentUser) {
      initialize(currentUser.companyId);
    }
  }, [companyId, currentUser, initialize]);

  const delivery = selectedDelivery?.id === deliveryId ? selectedDelivery : null;
  const enabledTypes = getEnabledClaimTypes();
  const customFields = selectedType ? getCustomFieldsForType(selectedType) : [];
  const needsSignature = isAtDeliverySite && (settings?.requireCustomerSignature ?? false);
  const maxPhotos = settings?.maxPhotosAllowed ?? 10;
  const canAddMorePhotos = photos.length < maxPhotos;

  if (!delivery) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.warning} />
      </View>
    );
  }

  const toggleAffectedItem = (item: DeliveryItem) => {
    setAffectedItems((prev) => {
      const exists = prev.some((ai) => ai.description === item.description);
      if (exists) {
        return prev.filter((ai) => ai.description !== item.description);
      }
      return [...prev, { description: item.description, quantity: item.quantity, unit: item.unit }];
    });
  };

  const takePhoto = async (source: 'camera' | 'gallery') => {
    try {
      const response =
        source === 'camera'
          ? await launchCamera({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 })
          : await launchImageLibrary({ mediaType: 'photo', maxWidth: 1920, maxHeight: 1080, quality: 0.8 });

      if (response.didCancel) return;
      const asset = response.assets?.[0];
      if (asset?.uri) {
        setPhotos((prev) => [...prev, asset]);
      }
    } catch (e) {
      Alert.alert('Error', `Failed to capture photo: ${(e as Error).message}`);
    }
  };

  const removePhoto = (index: number) => {
    setPhotos((prev) => prev.filter((_, i) => i !== index));
  };

  const setCustomFieldValue = (fieldId: string, value: unknown) => {
    setCustomFieldValues((prev) => ({ ...prev, [fieldId]: value }));
  };

  const validate = (): string | null => {
    if (!selectedType) return 'Please select an issue type';
    if (description.trim().length === 0) return 'Please describe the issue';

    for (const field of customFields) {
      const value = customFieldValues[field.id];
      if (field.required && (value === undefined || value === '')) {
        return `${field.label} is required`;
      }
      if (field.type === 'number' && value !== undefined && value !== '') {
        const num = Number(value);
        if (Number.isNaN(num)) return `${field.label} must be a valid number`;
        if (field.minValue != null && num < field.minValue) return `${field.label} minimum value is ${field.minValue}`;
        if (field.maxValue != null && num > field.maxValue) return `${field.label} maximum value is ${field.maxValue}`;
      }
    }

    if (settings?.photosMandatory && photos.length === 0) return 'At least one photo is required';
    if (settings?.minPhotosRequired && photos.length < settings.minPhotosRequired) {
      return `At least ${settings.minPhotosRequired} photos required`;
    }
    return null;
  };

  const handleSubmitPress = () => {
    const validationError = validate();
    if (validationError) {
      Alert.alert('Missing Information', validationError);
      return;
    }

    if (needsSignature) {
      signatureRef.current?.readSignature();
    } else {
      finishSubmit(undefined);
    }
  };

  const finishSubmit = async (signatureDataUrl: string | undefined) => {
    if (!currentUser || !delivery || !selectedType) return;

    if (needsSignature && !signatureDataUrl) {
      Alert.alert('Missing Information', 'Customer signature is required');
      return;
    }

    setIsSubmitting(true);
    try {
      const claimId = await generateClaimId();

      const photoUrls: string[] = [];
      for (let i = 0; i < photos.length; i++) {
        const photo = photos[i];
        if (!photo.uri) continue;
        const url = await uploadPhoto({
          claimId,
          fileUri: photo.uri,
          fileName: photo.fileName ?? `photo_${i + 1}_${Date.now()}.jpg`,
        });
        photoUrls.push(url);
      }

      let signatureUrl: string | undefined;
      if (signatureDataUrl) {
        signatureUrl = await uploadSignature({ claimId, signatureDataUrl, signatureType: 'customer' });
      }

      const gpsLocation = await getCurrentLocation();
      const workflow = getWorkflowForType(selectedType);
      const approvalChain: ApprovalLevel[] = workflow.map((role) => ({
        role: role.role,
        slaHours: role.slaHours,
        approved: false,
      }));

      const customFieldsPayload: CustomField[] = customFields.map((field) => ({
        id: field.id,
        label: field.label,
        type: field.type,
        required: field.required,
        value: customFieldValues[field.id],
      }));

      const now = new Date();

      const claim: Claim = {
        id: claimId,
        companyId: currentUser.companyId,
        type: selectedType,
        status: 'submitted',
        priority: 'medium',
        filingContext: isAtDeliverySite ? 'atDeliverySite' : 'afterDelivery',
        title: claimTypeDisplayText(selectedType),
        description,
        deliveryId: delivery.id,
        customerId: delivery.invoiceNumber,
        customerName: delivery.customerName,
        customerNumber: delivery.customerNumber,
        driverId: currentUser.id,
        driverName: currentUser.fullName,
        invoiceNumber: delivery.invoiceNumber,
        createdAt: now,
        updatedAt: now,
        deliveryDate: delivery.scheduledDate,
        filedBy: currentUser.id,
        filedByName: currentUser.fullName,
        filedByRole: 'driver',
        photoUrls,
        customerSignatureUrl: signatureUrl,
        gpsLocation,
        metadata: { orderNumber: delivery.orderNumber ?? delivery.id },
        documentUrls: [],
        documentMetadata: [],
        approvalChain,
        currentApprovalLevel: 0,
        customerAcknowledged: signatureUrl != null,
        filedAtDelivery: isAtDeliverySite ? now : undefined,
        driverEvidenceUrls: [],
        affectedItems,
        evidenceQualityScore: 5,
        hasAllRequiredEvidence: photoUrls.length >= (settings?.minPhotosRequired ?? 0),
        comments: [],
        statusHistory: [
          {
            status: 'submitted',
            timestamp: now,
            userId: currentUser.id,
            userName: currentUser.fullName,
            notes: 'Claim filed',
          },
        ],
        customFields: customFieldsPayload,
        isFraudulent: false,
        isEscalated: false,
        isRecurring: false,
        evidenceStatus: 'pending',
        photoCount: photoUrls.length,
        hasSignature: signatureUrl != null,
        hasDocuments: false,
      };

      claim.evidenceQualityScore = calculateEvidenceQualityScore(claim);

      const savedClaimId = await createClaim(claim);

      if (savedClaimId) {
        Alert.alert('Success', `Claim ${claimId} submitted successfully`, [{ text: 'OK', onPress: () => navigation.goBack() }]);
      } else {
        Alert.alert('Error', useClaimStore.getState().errorMessage ?? 'Failed to submit claim');
      }
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isSubmitting) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.warning} size="large" />
        <Text style={[textStyles.bodyMedium, styles.submittingText]}>Submitting claim...</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {isAtDeliverySite ? (
        <View style={styles.infoBanner}>
          <Text style={styles.infoBannerText}>📍 Filing at delivery site - evidence will be stronger</Text>
        </View>
      ) : null}

      <View style={styles.card}>
        <Text style={textStyles.heading3}>Delivery Information</Text>
        <View style={styles.divider} />
        <InfoRow label="Customer" value={delivery.customerName} />
        <InfoRow label="Address" value={delivery.customerAddress} />
        <InfoRow label="Invoice" value={delivery.invoiceNumber} />
        <InfoRow label="Delivery Date" value={`${delivery.scheduledDate.getDate()}/${delivery.scheduledDate.getMonth() + 1}/${delivery.scheduledDate.getFullYear()}`} />
      </View>

      <View style={styles.card}>
        <Text style={textStyles.bodyMedium}>Issue Type *</Text>
        <View style={styles.chipWrap}>
          {Array.from(new Set(enabledTypes)).map((type) => (
            <Chip
              key={type}
              label={claimTypeDisplayText(type)}
              selected={selectedType === type}
              onPress={() => {
                setSelectedType(type);
                setCustomFieldValues({});
              }}
            />
          ))}
        </View>
      </View>

      {selectedType && customFields.length > 0 ? (
        <View style={styles.card}>
          {customFields.map((field) => (
            <CustomFieldInput
              key={field.id}
              field={field}
              value={customFieldValues[field.id]}
              onChange={(value) => setCustomFieldValue(field.id, value)}
            />
          ))}
        </View>
      ) : null}

      <View style={styles.card}>
        <Text style={textStyles.bodyMedium}>Description *</Text>
        <TextInput
          style={styles.descriptionInput}
          placeholder="Describe the issue in detail..."
          multiline
          numberOfLines={4}
          value={description}
          onChangeText={setDescription}
        />
      </View>

      <View style={styles.card}>
        <Text style={textStyles.heading3}>Affected Items</Text>
        <View style={styles.divider} />
        {delivery.items.map((item, index) => {
          const isAffected = affectedItems.some((ai) => ai.description === item.description);
          return (
            <Pressable key={`${item.description}-${index}`} style={styles.checkboxRow} onPress={() => toggleAffectedItem(item)}>
              <Text style={styles.checkboxGlyph}>{isAffected ? '☑' : '☐'}</Text>
              <View style={styles.checkboxTextBox}>
                <Text style={textStyles.bodyMedium}>{item.description}</Text>
                <Text style={textStyles.bodySmall}>
                  Qty: {item.quantity}
                  {item.unit ? ` ${item.unit}` : ''}
                </Text>
              </View>
            </Pressable>
          );
        })}
      </View>

      <View style={styles.card}>
        <View style={styles.photosHeaderRow}>
          <Text style={textStyles.heading3}>
            Photos{settings?.photosMandatory ? ' *' : ''}
          </Text>
          <Text style={styles.photoCount}>
            {photos.length}/{maxPhotos}
          </Text>
        </View>
        {settings?.minPhotosRequired && settings.minPhotosRequired > 0 ? (
          <Text style={styles.photoHint}>Minimum {settings.minPhotosRequired} photo(s) required</Text>
        ) : null}

        {photos.length > 0 ? (
          <View style={styles.photoGrid}>
            {photos.map((photo, index) => (
              <View key={`${photo.uri}-${index}`} style={styles.photoThumb}>
                <Image source={{ uri: photo.uri }} style={styles.photoThumbImage} resizeMode="cover" />
                <Pressable style={styles.photoRemoveButton} onPress={() => removePhoto(index)}>
                  <Text style={styles.photoRemoveText}>✕</Text>
                </Pressable>
              </View>
            ))}
          </View>
        ) : null}

        <View style={styles.photoButtonRow}>
          <Pressable
            style={[styles.photoButton, !canAddMorePhotos && styles.photoButtonDisabled]}
            disabled={!canAddMorePhotos}
            onPress={() => takePhoto('camera')}
          >
            <Text style={styles.photoButtonText}>📷 Take Photo</Text>
          </Pressable>
          <Pressable
            style={[styles.photoButton, !canAddMorePhotos && styles.photoButtonDisabled]}
            disabled={!canAddMorePhotos}
            onPress={() => takePhoto('gallery')}
          >
            <Text style={styles.photoButtonText}>🖼 Gallery</Text>
          </Pressable>
        </View>
      </View>

      {needsSignature ? (
        <View style={styles.card}>
          <Text style={textStyles.heading3}>Customer Acknowledgment *</Text>
          <Text style={styles.photoHint}>Customer signature acknowledging the issue</Text>
          <View style={styles.signatureBox}>
            <SignatureView
              ref={signatureRef}
              onOK={(dataUrl) => finishSubmit(dataUrl)}
              onEmpty={() => Alert.alert('Missing Information', 'Customer signature is required')}
              descriptionText=""
              webStyle=".m-signature-pad--footer { display: none; margin: 0; }"
            />
          </View>
          <Pressable style={styles.clearSignatureButton} onPress={() => signatureRef.current?.clearSignature()}>
            <Text style={styles.clearSignatureText}>Clear</Text>
          </Pressable>
        </View>
      ) : null}

      <Pressable style={styles.submitButton} onPress={handleSubmitPress}>
        <Text style={textStyles.buttonText}>Submit Claim</Text>
      </Pressable>
    </ScrollView>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}:</Text>
      <Text style={[textStyles.bodyMedium, styles.infoValue]}>{value}</Text>
    </View>
  );
}

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function CustomFieldInput({
  field,
  value,
  onChange,
}: {
  field: CustomFieldDefinition;
  value: unknown;
  onChange: (value: unknown) => void;
}) {
  const label = field.label + (field.required ? ' *' : '');

  switch (field.type) {
    case 'text':
      return (
        <View style={styles.customFieldRow}>
          <Text style={textStyles.bodyMedium}>{label}</Text>
          <TextInput
            style={styles.customFieldInput}
            placeholder={field.placeholder}
            value={(value as string) ?? ''}
            onChangeText={onChange}
          />
          {field.helpText ? <Text style={styles.photoHint}>{field.helpText}</Text> : null}
        </View>
      );
    case 'number':
      return (
        <View style={styles.customFieldRow}>
          <Text style={textStyles.bodyMedium}>{label}</Text>
          <TextInput
            style={styles.customFieldInput}
            placeholder={field.placeholder}
            keyboardType="numeric"
            value={value != null ? String(value) : ''}
            onChangeText={onChange}
          />
          {field.helpText ? <Text style={styles.photoHint}>{field.helpText}</Text> : null}
        </View>
      );
    case 'dropdown':
      return (
        <View style={styles.customFieldRow}>
          <Text style={textStyles.bodyMedium}>{label}</Text>
          <View style={styles.chipWrap}>
            {(field.dropdownOptions ?? []).map((option) => (
              <Chip key={option} label={option} selected={value === option} onPress={() => onChange(option)} />
            ))}
          </View>
        </View>
      );
    case 'checkbox':
      return (
        <Pressable style={styles.checkboxRow} onPress={() => onChange(!value)}>
          <Text style={styles.checkboxGlyph}>{value ? '☑' : '☐'}</Text>
          <View style={styles.checkboxTextBox}>
            <Text style={textStyles.bodyMedium}>{label}</Text>
            {field.helpText ? <Text style={textStyles.bodySmall}>{field.helpText}</Text> : null}
          </View>
        </Pressable>
      );
    default:
      return null;
  }
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  submittingText: { marginTop: spacing.medium },
  infoBanner: {
    backgroundColor: `${colors.info}1A`,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: `${colors.info}66`,
    padding: spacing.medium,
    marginBottom: spacing.medium,
  },
  infoBannerText: { color: colors.info },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
    ...shadows.card,
  },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small + 4 },
  infoRow: { flexDirection: 'row', marginBottom: spacing.small },
  infoLabel: { width: 100, fontWeight: 'bold', color: colors.textSecondary },
  infoValue: { flex: 1 },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginTop: spacing.small },
  chip: {
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: 6,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.divider,
  },
  chipSelected: { backgroundColor: `${colors.warning}33`, borderColor: colors.warning },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.warning, fontWeight: '600' },
  descriptionInput: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    padding: spacing.small + 4,
    marginTop: spacing.small,
    minHeight: 100,
    textAlignVertical: 'top',
  },
  customFieldRow: { marginBottom: spacing.medium },
  customFieldInput: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    padding: spacing.small + 4,
    marginTop: spacing.small,
  },
  checkboxRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small },
  checkboxGlyph: { fontSize: 20, marginRight: spacing.small + 4, color: colors.warning },
  checkboxTextBox: { flex: 1 },
  photosHeaderRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  photoCount: { color: colors.textSecondary },
  photoHint: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginTop: spacing.medium },
  photoThumb: { width: 100, height: 100, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.divider },
  photoThumbImage: { width: '100%', height: '100%' },
  photoRemoveButton: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: colors.error,
    borderRadius: 10,
    width: 20,
    height: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  photoRemoveText: { color: colors.white, fontSize: 12, fontWeight: 'bold' },
  photoButtonRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.medium },
  photoButton: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.warning,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.small + 4,
    alignItems: 'center',
  },
  photoButtonDisabled: { opacity: 0.4 },
  photoButtonText: { color: colors.warning, fontWeight: '600' },
  signatureBox: {
    height: 150,
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    marginTop: spacing.small + 4,
    overflow: 'hidden',
  },
  clearSignatureButton: { alignSelf: 'flex-end', marginTop: spacing.small },
  clearSignatureText: { color: colors.textSecondary },
  submitButton: {
    backgroundColor: colors.warning,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.medium,
    alignItems: 'center',
    marginTop: spacing.small,
    ...shadows.button,
  },
});
