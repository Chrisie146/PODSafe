import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Image, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Asset, launchImageLibrary } from 'react-native-image-picker';
import { useAuthStore } from '../../stores/useAuthStore';
import { useVehicleStore } from '../../stores/useVehicleStore';
import { Vehicle, VehicleStatus } from '../../models/vehicle';
import { normalizeRegistration } from '../../utils/vehicleUtils';
import FirebaseStorageImage from '../../components/FirebaseStorageImage';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/vehicle_management_screen.dart (verified against source on
 * 2026-06-23). Companion route is VehicleManagementDesktop.tsx — an explicit-choice pair
 * (two distinct routes, caller picks explicitly, no auto-switch breakpoint; see vault
 * Inventory note).
 *
 * Deviations from the Flutter source:
 * - The card's PopupMenuButton (Edit/Delete) + the details AlertDialog collapse into one
 *   bottom-sheet Modal reached by tapping the card (house convention, same pattern as
 *   DriverDetails.tsx's "PopupMenuButton -> Modal action list" note).
 * - `CreateVehicleScreen` (a separate pushed Navigator route in Dart) becomes a Modal here
 *   (same convention as UserManagement.tsx's Create/EditUserModal), not a new stack route.
 * - Per-photo upload retry UI is simplified to one aggregate "Uploading photo X of Y..."
 *   status line + a single end-of-save notice listing failure count, instead of Dart's
 *   per-file inline retry button — the vehicle save itself still succeeds independently of
 *   individual photo failures, so re-opening Edit and re-adding a failed photo is the retry
 *   path. Max photos, image-only picking, and the save pipeline itself are faithful.
 */
const MAX_PHOTOS = 2;
const STATUS_OPTIONS: VehicleStatus[] = ['active', 'maintenance', 'inactive'];

function statusColor(status: VehicleStatus): string {
  switch (status) {
    case 'active':
      return colors.success;
    case 'maintenance':
      return colors.warning;
    case 'inactive':
      return colors.textSecondary;
  }
}

function statusLabel(status: VehicleStatus): string {
  switch (status) {
    case 'active':
      return 'Active';
    case 'maintenance':
      return 'Maintenance';
    case 'inactive':
      return 'Inactive';
  }
}

/** Mirrors _isImageUrl(): path-extension check with a raw-string fallback if URL parsing fails. */
function isImageUrl(url: string): boolean {
  let path = url;
  try {
    path = new URL(url).pathname;
  } catch {
    // fall through to raw-string match below
  }
  return /\.(png|jpe?g|gif|webp)$/i.test(path) || /\.(png|jpe?g|gif|webp)/i.test(url.toLowerCase());
}

export default function VehicleManagement() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const vehicles = useVehicleStore((s) => s.vehicles);
  const isLoading = useVehicleStore((s) => s.isLoading);
  const subscribeForCompany = useVehicleStore((s) => s.subscribeForCompany);
  const deleteVehicle = useVehicleStore((s) => s.deleteVehicle);
  const removeDocument = useVehicleStore((s) => s.removeDocument);
  const deleteDocumentByUrl = useVehicleStore((s) => s.deleteDocumentByUrl);

  const [selectedVehicle, setSelectedVehicle] = useState<Vehicle | null>(null);
  const [formVehicle, setFormVehicle] = useState<Vehicle | null | undefined>(undefined);
  const [fullScreenImageUrl, setFullScreenImageUrl] = useState<string | null>(null);

  useEffect(() => {
    if (currentUser) {
      subscribeForCompany(currentUser.companyId);
    }
  }, [currentUser, subscribeForCompany]);

  const handleDeleteVehicle = (vehicle: Vehicle) => {
    Alert.alert('Delete Vehicle', `Are you sure you want to delete ${vehicle.registration}? This action cannot be undone.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteVehicle(vehicle.id);
            setSelectedVehicle(null);
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  const handleDeleteDocument = (vehicle: Vehicle, docUrl: string) => {
    Alert.alert('Delete Photo', 'Are you sure you want to delete this photo?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteDocumentByUrl(docUrl);
            await removeDocument(vehicle.id, docUrl);
            setSelectedVehicle((prev) => (prev && prev.id === vehicle.id ? { ...prev, documents: (prev.documents ?? []).filter((d) => d !== docUrl) } : prev));
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Error: No company ID</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {isLoading && vehicles.length === 0 ? (
        <ActivityIndicator style={styles.loadingIndicator} color={colors.primary} />
      ) : vehicles.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.emptyIcon}>🚙</Text>
          <Text style={textStyles.bodyMedium}>No vehicles yet</Text>
        </View>
      ) : (
        <FlatList
          data={vehicles}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => <VehicleCard vehicle={item} onPress={() => setSelectedVehicle(item)} />}
        />
      )}

      <Pressable style={styles.fab} onPress={() => setFormVehicle(null)}>
        <Text style={styles.fabIcon}>🚙+</Text>
        <Text style={styles.fabLabel}>Add Vehicle</Text>
      </Pressable>

      {selectedVehicle ? (
        <VehicleDetailsModal
          vehicle={selectedVehicle}
          onClose={() => setSelectedVehicle(null)}
          onEdit={() => {
            setFormVehicle(selectedVehicle);
            setSelectedVehicle(null);
          }}
          onDelete={() => handleDeleteVehicle(selectedVehicle)}
          onDeleteDocument={(docUrl) => handleDeleteDocument(selectedVehicle, docUrl)}
          onViewImage={(url) => setFullScreenImageUrl(url)}
        />
      ) : null}

      {formVehicle !== undefined ? <VehicleFormModal vehicle={formVehicle} onClose={() => setFormVehicle(undefined)} /> : null}

      <Modal visible={fullScreenImageUrl != null} transparent animationType="fade" onRequestClose={() => setFullScreenImageUrl(null)}>
        <View style={styles.imageModalBackdrop}>
          <View style={styles.imageModalHeader}>
            <Text style={styles.imageModalTitle}>Photo</Text>
            <Pressable onPress={() => setFullScreenImageUrl(null)}>
              <Text style={styles.imageModalCloseText}>✕</Text>
            </Pressable>
          </View>
          {fullScreenImageUrl ? <FirebaseStorageImage imageUrl={fullScreenImageUrl} resizeMode="contain" style={styles.fullScreenImage} /> : null}
        </View>
      </Modal>
    </View>
  );
}

function VehicleCard({ vehicle, onPress }: { vehicle: Vehicle; onPress: () => void }) {
  const firstImage = (vehicle.documents ?? []).find(isImageUrl);
  return (
    <Pressable style={[styles.card, shadows.card]} onPress={onPress}>
      {firstImage ? (
        <FirebaseStorageImage imageUrl={firstImage} style={styles.cardThumb} resizeMode="cover" />
      ) : (
        <View style={[styles.cardThumb, styles.cardThumbFallback, { backgroundColor: vehicle.status === 'active' ? colors.success : colors.warning }]}>
          <Text style={styles.cardThumbIcon}>🚙</Text>
        </View>
      )}
      <View style={styles.cardBody}>
        <Text style={textStyles.bodyLarge}>{vehicle.registration}</Text>
        <Text style={textStyles.bodySmall}>
          {[vehicle.make, vehicle.model].filter(Boolean).join(' ') || 'No make/model'}
          {vehicle.licensePlate ? ` • ${vehicle.licensePlate}` : ''}
          {` • ${vehicle.totalDeliveries} deliveries`}
        </Text>
        <View style={[styles.statusBadge, { backgroundColor: `${statusColor(vehicle.status)}1A` }]}>
          <Text style={[styles.statusBadgeText, { color: statusColor(vehicle.status) }]}>{statusLabel(vehicle.status)}</Text>
        </View>
      </View>
      <Text style={styles.chevron}>›</Text>
    </Pressable>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={[textStyles.bodyMedium, styles.detailValue]}>{value}</Text>
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

function VehicleDetailsModal({
  vehicle,
  onClose,
  onEdit,
  onDelete,
  onDeleteDocument,
  onViewImage,
}: {
  vehicle: Vehicle;
  onClose: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onDeleteDocument: (docUrl: string) => void;
  onViewImage: (url: string) => void;
}) {
  const documents = vehicle.documents ?? [];
  return (
    <Modal visible transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.sheetBackdrop}>
        <View style={[styles.sheetCard, shadows.card]}>
          <ScrollView>
            <View style={styles.sheetHeaderRow}>
              <Text style={textStyles.heading2}>{vehicle.registration}</Text>
              <Pressable onPress={onClose}>
                <Text style={styles.closeGlyph}>✕</Text>
              </Pressable>
            </View>
            <View style={[styles.statusBadge, styles.detailStatusBadge, { backgroundColor: `${statusColor(vehicle.status)}1A` }]}>
              <Text style={[styles.statusBadgeText, { color: statusColor(vehicle.status) }]}>{statusLabel(vehicle.status)}</Text>
            </View>
            <View style={styles.divider} />

            <DetailRow label="Make" value={vehicle.make || 'Not specified'} />
            <DetailRow label="Model" value={vehicle.model || 'Not specified'} />
            <DetailRow label="Color" value={vehicle.color || 'Not specified'} />
            <DetailRow label="License Plate" value={vehicle.licensePlate || 'Not specified'} />
            <DetailRow label="Total Deliveries" value={String(vehicle.totalDeliveries)} />
            <DetailRow label="Last Used" value={vehicle.lastUsedAt ? vehicle.lastUsedAt.toLocaleString() : 'Never'} />
            {vehicle.notes ? <DetailRow label="Notes" value={vehicle.notes} /> : null}

            {documents.length > 0 ? (
              <>
                <View style={styles.sectionSpacer} />
                <Text style={textStyles.heading3}>Photos</Text>
                <View style={styles.photoGrid}>
                  {documents.map((url) => (
                    <View key={url} style={styles.photoThumb}>
                      <Pressable onPress={() => onViewImage(url)}>
                        {isImageUrl(url) ? (
                          <FirebaseStorageImage imageUrl={url} style={styles.photoThumbImage} resizeMode="cover" />
                        ) : (
                          <View style={[styles.photoThumbImage, styles.photoThumbFallback]}>
                            <Text>📄</Text>
                          </View>
                        )}
                      </Pressable>
                      <Pressable style={styles.photoRemoveButton} onPress={() => onDeleteDocument(url)}>
                        <Text style={styles.photoRemoveText}>✕</Text>
                      </Pressable>
                    </View>
                  ))}
                </View>
              </>
            ) : null}

            <View style={styles.sectionSpacer} />
            <Pressable style={styles.modalPrimaryButton} onPress={onEdit}>
              <Text style={textStyles.buttonText}>✎ Edit Vehicle</Text>
            </Pressable>
            <Pressable style={[styles.modalOutlinedButton, styles.deleteButton]} onPress={onDelete}>
              <Text style={styles.deleteButtonText}>🗑 Delete Vehicle</Text>
            </Pressable>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

function VehicleFormModal({ vehicle, onClose }: { vehicle: Vehicle | null; onClose: () => void }) {
  const createVehicleAction = useVehicleStore((s) => s.createVehicle);
  const updateVehicleAction = useVehicleStore((s) => s.updateVehicle);
  const uploadDocument = useVehicleStore((s) => s.uploadDocument);
  const setDocuments = useVehicleStore((s) => s.setDocuments);
  const appendDocuments = useVehicleStore((s) => s.appendDocuments);

  const [registration, setRegistration] = useState(vehicle?.registration ?? '');
  const [make, setMake] = useState(vehicle?.make ?? '');
  const [model, setModel] = useState(vehicle?.model ?? '');
  const [color, setColor] = useState(vehicle?.color ?? '');
  const [licensePlate, setLicensePlate] = useState(vehicle?.licensePlate ?? '');
  const [status, setStatus] = useState<VehicleStatus>(vehicle?.status ?? 'active');
  const [notes, setNotes] = useState(vehicle?.notes ?? '');
  const [photos, setPhotos] = useState<Asset[]>([]);
  const [isSaving, setIsSaving] = useState(false);
  const [uploadStatus, setUploadStatus] = useState<string | null>(null);

  const pickPhotos = async () => {
    const remaining = MAX_PHOTOS - photos.length;
    if (remaining <= 0) return;
    try {
      const response = await launchImageLibrary({ mediaType: 'photo', selectionLimit: remaining, maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
      if (response.didCancel) return;
      setPhotos((prev) => [...prev, ...(response.assets ?? []).slice(0, remaining)]);
    } catch (e) {
      Alert.alert('Error', `Error picking photos: ${(e as Error).message}`);
    }
  };

  const removePhoto = (index: number) => setPhotos((prev) => prev.filter((_, i) => i !== index));

  const handleSave = async () => {
    if (registration.trim().length === 0) {
      Alert.alert('Missing Information', 'Please enter a registration number');
      return;
    }

    setIsSaving(true);
    try {
      const params = {
        registration: normalizeRegistration(registration),
        make: make.trim() || undefined,
        model: model.trim() || undefined,
        color: color.trim() || undefined,
        licensePlate: licensePlate.trim() || undefined,
        status,
        notes: notes.trim() || undefined,
      };

      let vehicleId: string;
      if (vehicle) {
        await updateVehicleAction(vehicle, params);
        vehicleId = vehicle.id;
      } else {
        vehicleId = await createVehicleAction(params);
      }

      if (photos.length > 0) {
        const urls: string[] = [];
        let failedCount = 0;
        for (let i = 0; i < photos.length; i++) {
          const photo = photos[i];
          if (!photo.uri) continue;
          setUploadStatus(`Uploading photo ${i + 1} of ${photos.length}...`);
          try {
            urls.push(await uploadDocument(vehicleId, photo.uri, photo.fileName ?? `vehicle_photo_${i + 1}.jpg`));
          } catch {
            failedCount += 1;
          }
        }
        setUploadStatus(null);
        if (urls.length > 0) {
          if (vehicle) {
            await appendDocuments(vehicleId, urls);
          } else {
            await setDocuments(vehicleId, urls);
          }
        }
        if (failedCount > 0) {
          Alert.alert('Notice', `Vehicle saved, but ${failedCount} photo(s) failed to upload.`);
        }
      }

      Alert.alert('Success', vehicle ? 'Vehicle updated successfully' : 'Vehicle created successfully');
      onClose();
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    } finally {
      setIsSaving(false);
      setUploadStatus(null);
    }
  };

  return (
    <Modal visible transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <ScrollView style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>{vehicle ? 'Edit Vehicle' : 'Add Vehicle'}</Text>

          <Text style={styles.fieldLabel}>Registration *</Text>
          <TextInput style={styles.input} value={registration} onChangeText={setRegistration} autoCapitalize="characters" />

          <Text style={styles.fieldLabel}>Make</Text>
          <TextInput style={styles.input} value={make} onChangeText={setMake} />

          <Text style={styles.fieldLabel}>Model</Text>
          <TextInput style={styles.input} value={model} onChangeText={setModel} />

          <Text style={styles.fieldLabel}>Color</Text>
          <TextInput style={styles.input} value={color} onChangeText={setColor} />

          <Text style={styles.fieldLabel}>License Plate</Text>
          <TextInput style={styles.input} value={licensePlate} onChangeText={setLicensePlate} autoCapitalize="characters" />

          <Text style={styles.fieldLabel}>Status</Text>
          <View style={styles.chipWrap}>
            {STATUS_OPTIONS.map((s) => (
              <Chip key={s} label={statusLabel(s)} selected={status === s} onPress={() => setStatus(s)} />
            ))}
          </View>

          <Text style={styles.fieldLabel}>Notes</Text>
          <TextInput style={[styles.input, styles.notesInput]} value={notes} onChangeText={setNotes} multiline numberOfLines={3} />

          <Text style={[styles.fieldLabel, styles.sectionTitle]}>Photos (max {MAX_PHOTOS})</Text>
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
          {photos.length < MAX_PHOTOS ? (
            <Pressable style={[styles.modalOutlinedButton, styles.addPhotoButton]} onPress={pickPhotos}>
              <Text style={styles.modalOutlinedText}>＋ Add Photo</Text>
            </Pressable>
          ) : null}
          {uploadStatus ? <Text style={styles.helperText}>{uploadStatus}</Text> : null}

          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} disabled={isSaving} onPress={onClose}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.modalPrimaryButton} disabled={isSaving} onPress={handleSave}>
              {isSaving ? <ActivityIndicator color={colors.white} size="small" /> : <Text style={textStyles.buttonText}>Save</Text>}
            </Pressable>
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  emptyIcon: { fontSize: 40, opacity: 0.4, marginBottom: spacing.small },
  loadingIndicator: { marginTop: spacing.xLarge },
  listContent: { padding: spacing.medium, paddingBottom: spacing.xLarge * 3 },
  card: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.small + 4 },
  cardThumb: { width: 48, height: 48, borderRadius: radii.borderRadius, marginRight: spacing.medium },
  cardThumbFallback: { alignItems: 'center', justifyContent: 'center' },
  cardThumbIcon: { fontSize: 22 },
  cardBody: { flex: 1 },
  statusBadge: { alignSelf: 'flex-start', borderRadius: 10, paddingHorizontal: spacing.small, paddingVertical: 2, marginTop: spacing.small },
  statusBadgeText: { fontSize: 11, fontWeight: '600' },
  chevron: { fontSize: 20, color: colors.textSecondary },
  fab: {
    position: 'absolute',
    right: spacing.large,
    bottom: spacing.large,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small,
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 4,
    ...shadows.button,
  },
  fabIcon: { color: colors.white, fontSize: 16 },
  fabLabel: { color: colors.white, fontWeight: '600' },
  sheetBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  sheetCard: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.large, maxHeight: '90%' },
  sheetHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  detailStatusBadge: { marginTop: spacing.small },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  detailRow: { flexDirection: 'row', marginBottom: spacing.small + 4 },
  detailLabel: { width: 120, fontWeight: '600', color: colors.textSecondary },
  detailValue: { flex: 1 },
  sectionSpacer: { height: spacing.medium },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  photoThumb: { width: 90, height: 90, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.divider },
  photoThumbImage: { width: '100%', height: '100%' },
  photoThumbFallback: { alignItems: 'center', justifyContent: 'center' },
  photoRemoveButton: { position: 'absolute', top: 4, right: 4, backgroundColor: colors.error, borderRadius: 10, width: 20, height: 20, alignItems: 'center', justifyContent: 'center' },
  photoRemoveText: { color: colors.white, fontSize: 12, fontWeight: 'bold' },
  modalPrimaryButton: { alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedButton: { alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedText: { color: colors.textPrimary, fontWeight: '600' },
  deleteButton: { borderColor: colors.error },
  deleteButtonText: { color: colors.error, fontWeight: '600' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '85%' },
  fieldLabel: { fontWeight: '600', marginTop: spacing.medium, marginBottom: spacing.small },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  notesInput: { minHeight: 70, textAlignVertical: 'top' },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  sectionTitle: { marginTop: spacing.large },
  addPhotoButton: { alignSelf: 'flex-start', paddingHorizontal: spacing.large },
  helperText: { fontSize: 12, color: colors.textSecondary, marginTop: spacing.small },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalSecondaryButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius, borderWidth: 1, borderColor: colors.divider },
  modalSecondaryText: { color: colors.textSecondary, fontWeight: '600' },
  imageModalBackdrop: { flex: 1, backgroundColor: 'black' },
  imageModalHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: spacing.medium },
  imageModalTitle: { color: colors.white, fontSize: 17, fontWeight: '600' },
  imageModalCloseText: { color: colors.white, fontSize: 28 },
  fullScreenImage: { flex: 1 },
});
