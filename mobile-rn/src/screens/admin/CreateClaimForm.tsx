import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Asset, launchImageLibrary } from 'react-native-image-picker';
import SignatureView, { SignatureViewRef } from 'react-native-signature-canvas';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { Claim, ClaimType, ALL_CLAIM_TYPES, claimTypeDisplayText } from '../../models/claim';
import { Delivery } from '../../models/delivery';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/create_claim_form.dart (verified against source on
 * 2026-06-22) — admin form for filing a claim without evidence up front, with optional
 * "capture evidence now" toggles for photos/signature.
 *
 * Deviations from the Flutter source:
 * - Claim Type and Delivery "dropdowns" become a chip selector / modal picker (house
 *   convention — see ReportIssue.tsx's Chip pattern and BulkItemCreation.tsx's modal
 *   picker for a long option list).
 * - Photo picking uses react-native-image-picker's launchImageLibrary with
 *   selectionLimit: 0 (unlimited) instead of Dart's pickMultiImage; signature capture
 *   uses react-native-signature-canvas inside a Modal (Cancel/Clear/Save), mirroring the
 *   Dart source's AlertDialog with the same three actions.
 * - `driverName` is faithfully hardcoded to the literal string 'Driver' on the created
 *   claim, exactly matching the Dart source's `_createClaim()` — this looks like an
 *   oversight upstream (the real driver name is never looked up), but it's not flagged in
 *   the Phase 3 inventory as a fix-it item, so it's ported as-is rather than silently
 *   changed.
 * - Evidence upload uses claimRepository.uploadEvidenceToClaim (added this pass) via
 *   useClaimStore, passing local photo URIs / a signature data URL directly instead of
 *   the Dart source's in-memory byte-map normalization (RN's pickers already hand back
 *   URIs).
 */
interface CreateClaimFormProps {
  onClaimCreated?: () => void;
}

export default function CreateClaimForm({ onClaimCreated }: CreateClaimFormProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const deliveries = useDeliveryStore((s) => s.deliveries);
  const loadCompanyDeliveries = useDeliveryStore((s) => s.loadCompanyDeliveries);
  const createClaimWithoutEvidence = useClaimStore((s) => s.createClaimWithoutEvidence);
  const uploadEvidenceToClaim = useClaimStore((s) => s.uploadEvidenceToClaim);

  const [selectedType, setSelectedType] = useState<ClaimType | null>(null);
  const [selectedDelivery, setSelectedDelivery] = useState<Delivery | null>(null);
  const [showDeliveryModal, setShowDeliveryModal] = useState(false);
  const [description, setDescription] = useState('');
  const [selectedItemIndices, setSelectedItemIndices] = useState<Set<number>>(new Set());

  const [takePhotosNow, setTakePhotosNow] = useState(false);
  const [getSignatureNow, setGetSignatureNow] = useState(false);
  const [photos, setPhotos] = useState<Asset[]>([]);
  const [signatureDataUrl, setSignatureDataUrl] = useState<string | null>(null);
  const [showSignatureModal, setShowSignatureModal] = useState(false);

  const [isCreating, setIsCreating] = useState(false);

  const signatureRef = useRef<SignatureViewRef>(null);

  useEffect(() => {
    if (currentUser) {
      loadCompanyDeliveries(currentUser.companyId);
    }
  }, [currentUser, loadCompanyDeliveries]);

  const sortedDeliveries = [...deliveries].sort((a, b) => b.id.localeCompare(a.id));

  const resetForm = () => {
    setSelectedType(null);
    setSelectedDelivery(null);
    setDescription('');
    setSelectedItemIndices(new Set());
    setTakePhotosNow(false);
    setGetSignatureNow(false);
    setPhotos([]);
    setSignatureDataUrl(null);
  };

  const toggleItem = (index: number) => {
    setSelectedItemIndices((prev) => {
      const next = new Set(prev);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  };

  const pickPhotos = async () => {
    try {
      const response = await launchImageLibrary({ mediaType: 'photo', selectionLimit: 0, maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      if (response.didCancel) return;
      const assets = response.assets ?? [];
      setPhotos((prev) => [...prev, ...assets]);
    } catch (e) {
      Alert.alert('Error', `Error picking photos: ${(e as Error).message}`);
    }
  };

  const removePhoto = (index: number) => setPhotos((prev) => prev.filter((_, i) => i !== index));

  const handleCreateClaim = async () => {
    if (!currentUser) return;

    if (!selectedType) {
      Alert.alert('Notice', 'Please select a claim type');
      return;
    }
    if (!selectedDelivery) {
      Alert.alert('Notice', 'Please select a delivery');
      return;
    }
    if (description.trim().length === 0) {
      Alert.alert('Notice', 'Please fill in all required fields');
      return;
    }

    setIsCreating(true);
    try {
      const now = new Date();
      const affectedItems = Array.from(selectedItemIndices)
        .filter((i) => i >= 0 && i < selectedDelivery.items.length)
        .map((i) => {
          const item = selectedDelivery.items[i];
          return { description: item.description, quantity: item.quantity, unit: item.unit };
        });

      const newClaim: Claim = {
        id: '',
        companyId: currentUser.companyId,
        type: selectedType,
        status: 'submitted',
        priority: 'medium',
        filingContext: 'afterDelivery',
        title: claimTypeDisplayText(selectedType),
        description: description.trim(),
        deliveryId: selectedDelivery.id,
        customerId: selectedDelivery.customerId ?? '',
        customerName: selectedDelivery.customerName,
        customerNumber: selectedDelivery.customerNumber,
        driverId: selectedDelivery.driverId,
        driverName: 'Driver',
        invoiceNumber: selectedDelivery.invoiceNumber,
        createdAt: now,
        updatedAt: now,
        deliveryDate: now,
        filedBy: currentUser.id,
        filedByName: currentUser.fullName,
        filedByRole: currentUser.role,
        photoUrls: [],
        gpsLocation: {},
        metadata: {},
        documentUrls: [],
        documentMetadata: [],
        approvalChain: [],
        currentApprovalLevel: 0,
        driverEvidenceUrls: [],
        affectedItems,
        evidenceQualityScore: 5,
        hasAllRequiredEvidence: false,
        comments: [],
        statusHistory: [],
        customFields: [],
        isFraudulent: false,
        isEscalated: false,
        isRecurring: false,
        evidenceStatus: 'pending',
        photoCount: 0,
        hasSignature: false,
        hasDocuments: false,
      };

      const claimId = await createClaimWithoutEvidence(newClaim);
      if (!claimId) {
        throw new Error(useClaimStore.getState().errorMessage ?? 'Failed to create claim');
      }

      if (takePhotosNow && photos.length > 0) {
        await uploadEvidenceToClaim({
          claimId,
          photoUris: photos.map((p) => p.uri).filter((uri): uri is string => Boolean(uri)),
          signatureDataUrl: getSignatureNow && signatureDataUrl ? signatureDataUrl : undefined,
        });
      } else if (getSignatureNow && signatureDataUrl) {
        await uploadEvidenceToClaim({ claimId, signatureDataUrl });
      }

      Alert.alert('Success', `Claim created successfully: ${claimId}`);
      resetForm();
      onClaimCreated?.();
    } catch (e) {
      Alert.alert('Error', `Error creating claim: ${(e as Error).message}`);
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.headerRow}>
        <Text style={styles.headerIcon}>⊕</Text>
        <View style={styles.headerTextBox}>
          <Text style={textStyles.heading2}>Create New Claim</Text>
          <Text style={styles.headerSubtitle}>Create a claim without evidence - upload photos and signatures later</Text>
        </View>
      </View>

      <Text style={styles.fieldLabel}>Claim Type *</Text>
      <View style={styles.chipWrap}>
        {ALL_CLAIM_TYPES.map((type) => (
          <Chip key={type} label={claimTypeDisplayText(type)} selected={selectedType === type} onPress={() => setSelectedType(type)} />
        ))}
      </View>

      <Text style={styles.fieldLabel}>Delivery *</Text>
      {sortedDeliveries.length === 0 ? (
        <View style={styles.disabledField}>
          <Text style={styles.disabledFieldText}>No deliveries available — create a delivery first in Delivery Management</Text>
        </View>
      ) : (
        <Pressable style={styles.pickerField} onPress={() => setShowDeliveryModal(true)}>
          <Text style={selectedDelivery ? styles.pickerFieldText : styles.pickerFieldPlaceholder}>
            {selectedDelivery ? `${selectedDelivery.id} - ${selectedDelivery.customerName} (${selectedDelivery.items.length} items)` : 'Choose a delivery...'}
          </Text>
        </Pressable>
      )}

      <Text style={styles.fieldLabel}>Description *</Text>
      <TextInput
        style={styles.descriptionInput}
        placeholder="Describe the issue or claim reason..."
        multiline
        numberOfLines={3}
        value={description}
        onChangeText={setDescription}
      />

      <Text style={styles.fieldLabel}>Affected Items (Optional)</Text>
      {!selectedDelivery || selectedDelivery.items.length === 0 ? (
        <View style={styles.disabledField}>
          <Text style={styles.disabledFieldText}>Select a delivery to see its items</Text>
        </View>
      ) : (
        <View style={styles.itemsCard}>
          {selectedDelivery.items.map((item, index) => (
            <Pressable key={`${item.description}-${index}`} style={styles.checkboxRow} onPress={() => toggleItem(index)}>
              <Text style={styles.checkboxGlyph}>{selectedItemIndices.has(index) ? '☑' : '☐'}</Text>
              <View style={styles.checkboxTextBox}>
                <Text style={textStyles.bodyMedium}>{item.description}</Text>
                <Text style={textStyles.bodySmall}>
                  Qty: {item.quantity}
                  {item.unit ? ` ${item.unit}` : ''}
                </Text>
              </View>
            </Pressable>
          ))}
          {selectedItemIndices.size > 0 ? <Text style={styles.itemsSelectedHint}>{selectedItemIndices.size} item(s) selected</Text> : null}
        </View>
      )}

      <View style={styles.infoBanner}>
        <Text style={styles.infoBannerText}>ℹ️ Evidence is optional now - you can upload it later</Text>
      </View>

      <Pressable style={styles.checkboxRow} onPress={() => setTakePhotosNow((v) => !v)}>
        <Text style={styles.checkboxGlyph}>{takePhotosNow ? '☑' : '☐'}</Text>
        <Text style={textStyles.bodyMedium}>📷 Take Photos Now?</Text>
      </Pressable>
      {takePhotosNow ? (
        <View style={styles.evidenceSection}>
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
          <Pressable style={styles.secondaryButton} onPress={pickPhotos}>
            <Text style={styles.secondaryButtonText}>{photos.length > 0 ? '📷 Add More Photos' : '📷 Pick Photos'}</Text>
          </Pressable>
        </View>
      ) : null}

      <Pressable style={styles.checkboxRow} onPress={() => setGetSignatureNow((v) => !v)}>
        <Text style={styles.checkboxGlyph}>{getSignatureNow ? '☑' : '☐'}</Text>
        <Text style={textStyles.bodyMedium}>✎ Get Signature Now?</Text>
      </Pressable>
      {getSignatureNow ? (
        <View style={styles.evidenceSection}>
          {signatureDataUrl ? (
            <View>
              <Image source={{ uri: signatureDataUrl }} style={styles.signaturePreview} resizeMode="contain" />
              <View style={styles.buttonRow}>
                <Pressable style={styles.secondaryButton} onPress={() => setSignatureDataUrl(null)}>
                  <Text style={styles.secondaryButtonText}>Clear</Text>
                </Pressable>
                <Pressable style={styles.secondaryButton} onPress={() => setShowSignatureModal(true)}>
                  <Text style={styles.secondaryButtonText}>Re-capture</Text>
                </Pressable>
              </View>
            </View>
          ) : (
            <Pressable style={styles.secondaryButton} onPress={() => setShowSignatureModal(true)}>
              <Text style={styles.secondaryButtonText}>✎ Capture Signature</Text>
            </Pressable>
          )}
        </View>
      ) : null}

      <View style={styles.buttonRow}>
        <Pressable style={styles.clearButton} disabled={isCreating} onPress={resetForm}>
          <Text style={styles.clearButtonText}>✕ Clear</Text>
        </Pressable>
        <Pressable style={styles.createButton} disabled={isCreating} onPress={handleCreateClaim}>
          {isCreating ? <ActivityIndicator color={colors.white} size="small" /> : null}
          <Text style={textStyles.buttonText}>{isCreating ? 'Creating...' : '+ Create Claim'}</Text>
        </Pressable>
      </View>

      <Modal visible={showDeliveryModal} transparent animationType="fade" onRequestClose={() => setShowDeliveryModal(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Select Delivery</Text>
            <ScrollView style={styles.deliveryModalList}>
              {sortedDeliveries.map((delivery) => (
                <Pressable
                  key={delivery.id}
                  style={styles.deliveryModalRow}
                  onPress={() => {
                    setSelectedDelivery(delivery);
                    setSelectedItemIndices(new Set());
                    setShowDeliveryModal(false);
                  }}
                >
                  <Text style={textStyles.bodyMedium}>
                    {delivery.id} - {delivery.customerName}
                  </Text>
                  <Text style={textStyles.bodySmall}>{delivery.items.length} items</Text>
                </Pressable>
              ))}
            </ScrollView>
            <Pressable style={styles.modalCloseButton} onPress={() => setShowDeliveryModal(false)}>
              <Text style={textStyles.buttonText}>Close</Text>
            </Pressable>
          </View>
        </View>
      </Modal>

      <Modal visible={showSignatureModal} transparent animationType="fade" onRequestClose={() => setShowSignatureModal(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Capture Signature</Text>
            <View style={styles.signatureModalBox}>
              <SignatureView
                ref={signatureRef}
                onOK={(dataUrl) => {
                  setSignatureDataUrl(dataUrl);
                  setShowSignatureModal(false);
                }}
                onEmpty={() => Alert.alert('Notice', 'Please draw a signature first')}
                descriptionText=""
                webStyle=".m-signature-pad--footer { display: none; margin: 0; }"
              />
            </View>
            <View style={styles.buttonRow}>
              <Pressable style={styles.secondaryButton} onPress={() => setShowSignatureModal(false)}>
                <Text style={styles.secondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.secondaryButton} onPress={() => signatureRef.current?.clearSignature()}>
                <Text style={styles.secondaryButtonText}>Clear</Text>
              </Pressable>
              <Pressable style={styles.createButton} onPress={() => signatureRef.current?.readSignature()}>
                <Text style={textStyles.buttonText}>Save</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </ScrollView>
  );
}

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.large, paddingBottom: spacing.xLarge },
  headerRow: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: spacing.large },
  headerIcon: { fontSize: 28, color: colors.primary, marginRight: spacing.medium },
  headerTextBox: { flex: 1 },
  headerSubtitle: { fontSize: 13, color: colors.textSecondary, marginTop: 4 },
  fieldLabel: { fontWeight: '600', fontSize: 14, color: colors.textPrimary, marginTop: spacing.medium, marginBottom: spacing.small },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.card, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  disabledField: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.medium, backgroundColor: colors.card },
  disabledFieldText: { fontSize: 13, color: colors.textSecondary, fontStyle: 'italic' },
  pickerField: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.card },
  pickerFieldText: { color: colors.textPrimary },
  pickerFieldPlaceholder: { color: colors.textSecondary },
  descriptionInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, minHeight: 90, textAlignVertical: 'top', backgroundColor: colors.card },
  itemsCard: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, backgroundColor: colors.card, padding: spacing.small },
  checkboxRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4 },
  checkboxGlyph: { fontSize: 20, marginRight: spacing.small + 4, color: colors.primary },
  checkboxTextBox: { flex: 1 },
  itemsSelectedHint: { fontSize: 12, fontWeight: '600', color: colors.info, backgroundColor: `${colors.info}1A`, borderRadius: 4, padding: spacing.small, marginTop: spacing.small },
  infoBanner: { backgroundColor: `${colors.info}1A`, borderRadius: radii.borderRadius, padding: spacing.medium, marginTop: spacing.large },
  infoBannerText: { color: colors.info, fontSize: 13 },
  evidenceSection: { marginTop: spacing.small, marginLeft: spacing.large + spacing.small, marginBottom: spacing.small },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginBottom: spacing.small + 4 },
  photoThumb: { width: 90, height: 90, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.divider },
  photoThumbImage: { width: '100%', height: '100%' },
  photoRemoveButton: { position: 'absolute', top: 4, right: 4, backgroundColor: colors.error, borderRadius: 10, width: 20, height: 20, alignItems: 'center', justifyContent: 'center' },
  photoRemoveText: { color: colors.white, fontSize: 12, fontWeight: 'bold' },
  signaturePreview: { height: 150, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, backgroundColor: colors.white },
  buttonRow: { flexDirection: 'row', gap: spacing.small + 4, marginTop: spacing.small + 4 },
  secondaryButton: { borderWidth: 1, borderColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, alignItems: 'center' },
  secondaryButtonText: { color: colors.primary, fontWeight: '600' },
  clearButton: { flex: 1, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, alignItems: 'center', marginTop: spacing.large },
  clearButtonText: { color: colors.textSecondary, fontWeight: '600' },
  createButton: {
    flex: 1,
    flexDirection: 'row',
    gap: spacing.small,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.small + 4,
    marginTop: spacing.large,
  },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '80%' },
  deliveryModalList: { maxHeight: 320, marginTop: spacing.medium },
  deliveryModalRow: { paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  modalCloseButton: { marginTop: spacing.large, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  signatureModalBox: { height: 220, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.white, marginTop: spacing.medium },
});
