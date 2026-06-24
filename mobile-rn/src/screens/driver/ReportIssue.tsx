// expects route.params: { deliveryId: string; isAtDeliverySite: boolean }
import React, { useEffect, useRef, useState } from 'react';
import { Alert, Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { Asset, launchCamera, launchImageLibrary } from 'react-native-image-picker';
import SignatureView, { SignatureViewRef } from 'react-native-signature-canvas';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { ApprovalLevel, Claim, ClaimType, CustomField, claimTypeDisplayText } from '../../models/claim';
import { CustomFieldDefinition } from '../../models/companyClaimSettings';
import { DeliveryItem } from '../../models/delivery';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { AppIcon, Card, FormField, LoadingState, PrimaryButton, Screen, SecondaryButton } from '../../components/ui';

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
      <Screen scroll={false}>
        <LoadingState title="Loading delivery details" />
      </Screen>
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
      <Screen scroll={false}>
        <LoadingState title="Submitting claim" />
      </Screen>
    );
  }

  return (
    <Screen scroll keyboardAvoiding contentContainerStyle={styles.content}>
      {isAtDeliverySite ? (
        <View style={styles.infoBanner}>
          <AppIcon name="location" size={20} color={colors.active} />
          <Text style={styles.infoBannerText}>Filing at delivery site - evidence will be stronger</Text>
        </View>
      ) : null}

      <Card style={styles.card}>
        <Text style={textStyles.heading3}>Delivery Information</Text>
        <View style={styles.divider} />
        <InfoRow label="Customer" value={delivery.customerName} />
        <InfoRow label="Address" value={delivery.customerAddress} />
        <InfoRow label="Invoice" value={delivery.invoiceNumber} />
        <InfoRow label="Delivery Date" value={`${delivery.scheduledDate.getDate()}/${delivery.scheduledDate.getMonth() + 1}/${delivery.scheduledDate.getFullYear()}`} />
      </Card>

      <Card style={styles.card}>
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
      </Card>

      {selectedType && customFields.length > 0 ? (
        <Card style={styles.card}>
          {customFields.map((field) => (
            <CustomFieldInput
              key={field.id}
              field={field}
              value={customFieldValues[field.id]}
              onChange={(value) => setCustomFieldValue(field.id, value)}
            />
          ))}
        </Card>
      ) : null}

      <Card style={styles.card}>
        <FormField
          label="Description *"
          accessibilityLabel="Issue description"
          accessibilityHint="Describe the delivery issue in detail"
          inputStyle={styles.multilineInput}
          placeholder="Describe the issue in detail..."
          multiline
          numberOfLines={4}
          value={description}
          onChangeText={setDescription}
        />
      </Card>

      <Card style={styles.card}>
        <Text style={textStyles.heading3}>Affected Items</Text>
        <View style={styles.divider} />
        {delivery.items.map((item, index) => {
          const isAffected = affectedItems.some((ai) => ai.description === item.description);
          return (
            <Pressable
              key={`${item.description}-${index}`}
              accessibilityRole="checkbox"
              accessibilityLabel={`Affected item: ${item.description}`}
              accessibilityState={{ checked: isAffected }}
              style={styles.checkboxRow}
              onPress={() => toggleAffectedItem(item)}
            >
              <View style={[styles.checkboxIcon, isAffected && styles.checkboxIconSelected]}>
                {isAffected ? <AppIcon name="check" size={16} color={colors.onPrimary} /> : null}
              </View>
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
      </Card>

      <Card style={styles.card}>
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
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={`Remove photo ${index + 1}`}
                  hitSlop={8}
                  style={styles.photoRemoveButton}
                  onPress={() => removePhoto(index)}
                >
                  <AppIcon name="close" size={14} color={colors.onPrimary} />
                </Pressable>
              </View>
            ))}
          </View>
        ) : null}

        <View style={styles.photoButtonRow}>
          <SecondaryButton
            label="Take photo"
            icon="camera"
            accessibilityLabel="Take a photo"
            style={styles.photoButton}
            disabled={!canAddMorePhotos}
            onPress={() => takePhoto('camera')}
          />
          <SecondaryButton
            label="Gallery"
            icon="image"
            accessibilityLabel="Choose a photo from the gallery"
            style={styles.photoButton}
            disabled={!canAddMorePhotos}
            onPress={() => takePhoto('gallery')}
          />
        </View>
      </Card>

      {needsSignature ? (
        <Card style={styles.card}>
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
          <SecondaryButton label="Clear signature" icon="close" onPress={() => signatureRef.current?.clearSignature()} style={styles.clearSignatureButton} />
        </Card>
      ) : null}

      <PrimaryButton label="Submit claim" icon="report" onPress={handleSubmitPress} style={styles.submitButton} />
    </Screen>
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
    <Pressable
      accessibilityRole="radio"
      accessibilityLabel={label}
      accessibilityState={{ selected }}
      style={[styles.chip, selected && styles.chipSelected]}
      onPress={onPress}
    >
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
        <FormField
          containerStyle={styles.customFieldRow}
          label={label}
          accessibilityLabel={label}
          helperText={field.helpText}
          placeholder={field.placeholder}
          value={(value as string) ?? ''}
          onChangeText={onChange}
        />
      );
    case 'number':
      return (
        <FormField
          containerStyle={styles.customFieldRow}
          label={label}
          accessibilityLabel={label}
          helperText={field.helpText}
          placeholder={field.placeholder}
          keyboardType="numeric"
          value={value != null ? String(value) : ''}
          onChangeText={onChange}
        />
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
        <Pressable
          accessibilityRole="checkbox"
          accessibilityLabel={label}
          accessibilityState={{ checked: Boolean(value) }}
          style={styles.checkboxRow}
          onPress={() => onChange(!value)}
        >
          <View style={[styles.checkboxIcon, Boolean(value) && styles.checkboxIconSelected]}>
            {value ? <AppIcon name="check" size={16} color={colors.onPrimary} /> : null}
          </View>
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
  content: { paddingBottom: spacing.xxLarge },
  infoBanner: {
    alignItems: 'center',
    backgroundColor: colors.activeMuted,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: colors.active,
    flexDirection: 'row',
    gap: spacing.small,
    padding: spacing.medium,
    marginBottom: spacing.medium,
  },
  infoBannerText: { color: colors.contentPrimary, flex: 1 },
  card: { gap: spacing.medium, marginBottom: spacing.medium },
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
  chipSelected: { backgroundColor: colors.activeMuted, borderColor: colors.active },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.active, fontWeight: '600' },
  multilineInput: { minHeight: 112, paddingTop: spacing.medium, textAlignVertical: 'top' },
  customFieldRow: { marginBottom: spacing.medium },
  checkboxRow: { alignItems: 'center', flexDirection: 'row', minHeight: 48, paddingVertical: spacing.small },
  checkboxIcon: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: 6,
    borderWidth: 1,
    height: 24,
    justifyContent: 'center',
    marginRight: spacing.small + 4,
    width: 24,
  },
  checkboxIconSelected: { backgroundColor: colors.active, borderColor: colors.active },
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
  photoButtonRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.medium },
  photoButton: { flex: 1 },
  signatureBox: {
    height: 150,
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    marginTop: spacing.small + 4,
    overflow: 'hidden',
  },
  clearSignatureButton: { alignSelf: 'flex-end', marginTop: spacing.small },
  submitButton: {
    marginTop: spacing.small,
  },
});
