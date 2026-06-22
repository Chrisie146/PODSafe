import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Asset, launchImageLibrary } from 'react-native-image-picker';
import SignatureView, { SignatureViewRef } from 'react-native-signature-canvas';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { Claim, claimTypeDisplayText } from '../../models/claim';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/upload_evidence_form.dart (verified against source on
 * 2026-06-22) — companion to CreateClaimForm.tsx: lets an admin attach photos/signature
 * to a claim that was previously filed without evidence.
 *
 * Deviations from the Flutter source:
 * - "Claims Pending Evidence" dropdown becomes a tappable picker field + a Modal list
 *   (house convention, same pattern as CreateClaimForm.tsx's delivery picker), backed by
 *   useClaimStore.subscribeToPendingEvidence/pendingEvidenceClaims (added this pass) in
 *   place of the Dart screen's own cached-stream-on-the-provider trick.
 * - Max 5 photos enforced the same way as the Dart source (silently caps additions past
 *   5 rather than erroring).
 * - Signature capture uses react-native-signature-canvas inline (no modal needed here —
 *   the Dart source's AlertDialog is flattened into the form itself since there's no
 *   competing scroll content above it, unlike CreateClaimForm's longer form).
 */
const MAX_PHOTOS = 5;

export default function UploadEvidenceForm() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const companyId = useClaimStore((s) => s.companyId);
  const pendingEvidenceClaims = useClaimStore((s) => s.pendingEvidenceClaims);
  const initialize = useClaimStore((s) => s.initialize);
  const subscribeToPendingEvidence = useClaimStore((s) => s.subscribeToPendingEvidence);
  const uploadEvidenceToClaim = useClaimStore((s) => s.uploadEvidenceToClaim);

  const [selectedClaim, setSelectedClaim] = useState<Claim | null>(null);
  const [showClaimModal, setShowClaimModal] = useState(false);
  const [photos, setPhotos] = useState<Asset[]>([]);
  const [signatureDataUrl, setSignatureDataUrl] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);

  const signatureRef = useRef<SignatureViewRef>(null);

  useEffect(() => {
    if (currentUser && companyId !== currentUser.companyId) {
      initialize(currentUser.companyId);
    }
  }, [currentUser, companyId, initialize]);

  useEffect(() => {
    if (companyId) {
      subscribeToPendingEvidence(companyId);
    }
  }, [companyId, subscribeToPendingEvidence]);

  const pickPhotos = async () => {
    try {
      const remaining = MAX_PHOTOS - photos.length;
      if (remaining <= 0) return;

      const response = await launchImageLibrary({ mediaType: 'photo', selectionLimit: remaining, maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      if (response.didCancel) return;
      const assets = (response.assets ?? []).slice(0, remaining);
      setPhotos((prev) => [...prev, ...assets]);
    } catch (e) {
      Alert.alert('Error', `Error picking photos: ${(e as Error).message}`);
    }
  };

  const removePhoto = (index: number) => setPhotos((prev) => prev.filter((_, i) => i !== index));

  const resetForm = () => {
    setSelectedClaim(null);
    setPhotos([]);
    setSignatureDataUrl(null);
    signatureRef.current?.clearSignature();
  };

  const handleUpload = async () => {
    if (!selectedClaim) {
      Alert.alert('Notice', 'Please select a claim');
      return;
    }
    if (photos.length === 0 && !signatureDataUrl) {
      Alert.alert('Notice', 'Please add photos or signature');
      return;
    }

    setIsUploading(true);
    try {
      const ok = await uploadEvidenceToClaim({
        claimId: selectedClaim.id,
        photoUris: photos.length > 0 ? photos.map((p) => p.uri).filter((uri): uri is string => Boolean(uri)) : undefined,
        signatureDataUrl: signatureDataUrl ?? undefined,
      });

      if (!ok) {
        throw new Error(useClaimStore.getState().errorMessage ?? 'Failed to upload evidence');
      }

      Alert.alert('Success', 'Evidence uploaded successfully');
      resetForm();
    } catch (e) {
      Alert.alert('Error', `Error uploading evidence: ${(e as Error).message}`);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={textStyles.heading2}>Upload Evidence to Claims</Text>
      <Text style={styles.subtitle}>Select a claim pending evidence and upload photos or signature</Text>

      <Text style={styles.fieldLabel}>Claims Pending Evidence</Text>
      {pendingEvidenceClaims.length === 0 ? (
        <View style={styles.disabledField}>
          <Text style={styles.disabledFieldText}>No claims pending evidence</Text>
        </View>
      ) : (
        <Pressable style={styles.pickerField} onPress={() => setShowClaimModal(true)}>
          <Text style={selectedClaim ? styles.pickerFieldText : styles.pickerFieldPlaceholder}>
            {selectedClaim ? `${selectedClaim.id} - ${selectedClaim.customerName} (${claimTypeDisplayText(selectedClaim.type)})` : 'Select a claim to upload evidence'}
          </Text>
        </Pressable>
      )}
      <Text style={styles.helperText}>{pendingEvidenceClaims.length} claim(s) pending evidence</Text>

      {selectedClaim ? (
        <View style={[styles.card, shadows.card]}>
          <View style={styles.claimCardHeaderRow}>
            <Text style={textStyles.heading3}>Claim Details</Text>
            <View style={styles.pendingBadge}>
              <Text style={styles.pendingBadgeText}>Pending Evidence</Text>
            </View>
          </View>
          <InfoRow label="Claim ID" value={selectedClaim.id} />
          <InfoRow label="Customer" value={selectedClaim.customerName} />
          <InfoRow label="Type" value={claimTypeDisplayText(selectedClaim.type)} />
          <InfoRow label="Description" value={selectedClaim.description} />
          <InfoRow label="Filing Date" value={selectedClaim.createdAt.toLocaleString()} />
        </View>
      ) : null}

      <Text style={[textStyles.heading3, styles.sectionTitle]}>Photos</Text>
      {photos.length === 0 ? (
        <View style={styles.emptyEvidenceBox}>
          <Text style={styles.emptyEvidenceIcon}>🖼</Text>
          <Text style={styles.emptyEvidenceText}>No photos selected</Text>
          <Pressable style={styles.primaryButton} onPress={pickPhotos}>
            <Text style={textStyles.buttonText}>＋ Add Photos</Text>
          </Pressable>
          <Text style={styles.helperTextCenter}>Up to {MAX_PHOTOS} photos (JPEG/PNG)</Text>
        </View>
      ) : (
        <View>
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
          {photos.length < MAX_PHOTOS ? (
            <Pressable style={[styles.primaryButton, styles.addMoreButton]} onPress={pickPhotos}>
              <Text style={textStyles.buttonText}>＋ Add More Photos ({MAX_PHOTOS - photos.length} left)</Text>
            </Pressable>
          ) : null}
        </View>
      )}

      <Text style={[textStyles.heading3, styles.sectionTitle]}>Signature</Text>
      {signatureDataUrl ? (
        <View>
          <Image source={{ uri: signatureDataUrl }} style={styles.signaturePreview} resizeMode="contain" />
          <Pressable style={[styles.primaryButton, styles.addMoreButton]} onPress={() => setSignatureDataUrl(null)}>
            <Text style={textStyles.buttonText}>↺ Recapture Signature</Text>
          </Pressable>
        </View>
      ) : (
        <View style={styles.emptyEvidenceBox}>
          <Text style={styles.emptyEvidenceIcon}>✎</Text>
          <Text style={styles.emptyEvidenceText}>No signature captured</Text>
          <View style={styles.signatureBox}>
            <SignatureView
              ref={signatureRef}
              onOK={(dataUrl) => setSignatureDataUrl(dataUrl)}
              onEmpty={() => Alert.alert('Notice', 'Please draw a signature first')}
              descriptionText=""
              webStyle=".m-signature-pad--footer { display: none; margin: 0; }"
            />
          </View>
          <Pressable style={styles.primaryButton} onPress={() => signatureRef.current?.readSignature()}>
            <Text style={textStyles.buttonText}>✎ Capture Signature</Text>
          </Pressable>
        </View>
      )}

      <View style={styles.buttonRow}>
        <Pressable style={styles.clearButton} disabled={isUploading} onPress={resetForm}>
          <Text style={styles.clearButtonText}>Clear</Text>
        </Pressable>
        <Pressable style={styles.uploadButton} disabled={isUploading} onPress={handleUpload}>
          {isUploading ? <ActivityIndicator color={colors.white} size="small" /> : null}
          <Text style={textStyles.buttonText}>{isUploading ? 'Uploading...' : 'Upload Evidence'}</Text>
        </Pressable>
      </View>

      <ClaimPickerModal
        visible={showClaimModal}
        claims={pendingEvidenceClaims}
        onSelect={(claim) => {
          setSelectedClaim(claim);
          setShowClaimModal(false);
        }}
        onClose={() => setShowClaimModal(false)}
      />
    </ScrollView>
  );
}

function ClaimPickerModal({
  visible,
  claims,
  onSelect,
  onClose,
}: {
  visible: boolean;
  claims: Claim[];
  onSelect: (claim: Claim) => void;
  onClose: () => void;
}) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Select Claim</Text>
          <ScrollView style={styles.claimModalList}>
            {claims.map((claim) => (
              <Pressable key={claim.id} style={styles.claimModalRow} onPress={() => onSelect(claim)}>
                <Text style={textStyles.bodyMedium}>
                  {claim.id} - {claim.customerName}
                </Text>
                <Text style={textStyles.bodySmall}>{claimTypeDisplayText(claim.type)}</Text>
              </Pressable>
            ))}
          </ScrollView>
          <Pressable style={styles.modalCloseButton} onPress={onClose}>
            <Text style={textStyles.buttonText}>Close</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
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

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.large, paddingBottom: spacing.xLarge },
  subtitle: { fontSize: 13, color: colors.textSecondary, marginTop: 4, marginBottom: spacing.large },
  fieldLabel: { fontWeight: '600', fontSize: 14, color: colors.textPrimary, marginBottom: spacing.small },
  disabledField: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.medium, backgroundColor: colors.card },
  disabledFieldText: { fontSize: 13, color: colors.textSecondary, fontStyle: 'italic' },
  pickerField: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.card },
  pickerFieldText: { color: colors.textPrimary },
  pickerFieldPlaceholder: { color: colors.textSecondary },
  helperText: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  helperTextCenter: { fontSize: 12, color: colors.textSecondary, marginTop: spacing.small, textAlign: 'center' },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginTop: spacing.large },
  claimCardHeaderRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.small + 4 },
  pendingBadge: { backgroundColor: `${colors.warning}33`, borderRadius: 12, paddingHorizontal: spacing.small + 4, paddingVertical: 4 },
  pendingBadgeText: { color: colors.warning, fontWeight: '600', fontSize: 12 },
  infoRow: { flexDirection: 'row', marginBottom: spacing.small },
  infoLabel: { width: 100, fontWeight: 'bold', color: colors.textSecondary },
  infoValue: { flex: 1 },
  sectionTitle: { marginTop: spacing.large, marginBottom: spacing.small + 4 },
  emptyEvidenceBox: {
    width: '100%',
    alignItems: 'center',
    padding: spacing.large,
    borderWidth: 2,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    backgroundColor: colors.card,
  },
  emptyEvidenceIcon: { fontSize: 40, opacity: 0.4 },
  emptyEvidenceText: { color: colors.textSecondary, marginTop: spacing.small, marginBottom: spacing.medium },
  primaryButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4 },
  addMoreButton: { marginTop: spacing.medium, alignSelf: 'flex-start' },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  photoThumb: { width: 90, height: 90, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.divider },
  photoThumbImage: { width: '100%', height: '100%' },
  photoRemoveButton: { position: 'absolute', top: 4, right: 4, backgroundColor: colors.error, borderRadius: 10, width: 20, height: 20, alignItems: 'center', justifyContent: 'center' },
  photoRemoveText: { color: colors.white, fontSize: 12, fontWeight: 'bold' },
  signaturePreview: { height: 200, width: '100%', borderRadius: radii.borderRadius, backgroundColor: colors.white, borderWidth: 1, borderColor: colors.divider },
  signatureBox: { height: 200, width: '100%', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.white, marginBottom: spacing.medium },
  buttonRow: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.medium, marginTop: spacing.xLarge },
  clearButton: { paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4, alignItems: 'center' },
  clearButtonText: { color: colors.textSecondary, fontWeight: '600' },
  uploadButton: {
    flexDirection: 'row',
    gap: spacing.small,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.small + 4,
  },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '80%' },
  claimModalList: { maxHeight: 320, marginTop: spacing.medium },
  claimModalRow: { paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  modalCloseButton: { marginTop: spacing.large, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
});
