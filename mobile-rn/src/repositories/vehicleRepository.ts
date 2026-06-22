import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import { Vehicle, VehicleStatus } from '../models/vehicle';
import { vehicleFromFirestore } from '../models/vehicle.converters';

/**
 * NEW repository — there is no Dart service/repository to port from. Both
 * lib/screens/admin/vehicle_management_screen.dart and vehicle_management_desktop.dart
 * inline identical raw `FirebaseFirestore.instance.collection('companies').doc(companyId)
 * .collection('vehicles')` CRUD independently (verified against both files directly on
 * 2026-06-22) — this repository is that logic extracted into one shared place, the same
 * kind of improvement the migration plan calls for with customerRepository.ts.
 *
 * The Storage upload/delete piece mirrors lib/services/vehicle_document_service.dart,
 * which IS a real, shared Dart service (used by both screens via Provider) — that part
 * is a faithful port, not new logic.
 *
 * Deviation: vehicle_document_service.dart's uploadFile() branches on whether
 * file_picker gave it a local path or raw bytes (the bytes branch is a web-only
 * file_picker behavior). This repository's uploadDocument() only takes a local file URI
 * — the mobile/native path covered by this phase. The web/RNW equivalent (Phase 4) will
 * need its own bytes-based variant.
 */
export class VehicleRepository {
  constructor(
    private firestoreInstance: FirebaseFirestoreTypes.Module = firestore(),
    private storageInstance: ReturnType<typeof storage> = storage(),
  ) {}

  private vehiclesRef(companyId: string) {
    return this.firestoreInstance.collection('companies').doc(companyId).collection('vehicles');
  }

  /** Mirrors the `_vehiclesStream` setup in both vehicle screens. Returns an unsubscribe function. */
  subscribeToVehicles(companyId: string, onChange: (vehicles: Vehicle[]) => void, onError?: (error: Error) => void): () => void {
    return this.vehiclesRef(companyId)
      .orderBy('createdAt', 'desc')
      .onSnapshot(
        (snapshot) => onChange(snapshot.docs.map(vehicleFromFirestore)),
        (error) => onError?.(error as unknown as Error),
      );
  }

  async getVehicleById(companyId: string, vehicleId: string): Promise<Vehicle | null> {
    const doc = await this.vehiclesRef(companyId).doc(vehicleId).get();
    return doc.exists() ? vehicleFromFirestore(doc) : null;
  }

  /** Mirrors _saveVehicle()'s create branch. */
  async createVehicle(
    companyId: string,
    params: {
      registration: string;
      make?: string;
      model?: string;
      color?: string;
      licensePlate?: string;
      status: VehicleStatus;
      notes?: string;
    },
  ): Promise<string> {
    const docRef = await this.vehiclesRef(companyId).add({
      companyId,
      registration: params.registration.trim(),
      make: params.make?.trim() || null,
      model: params.model?.trim() || null,
      color: params.color?.trim() || null,
      licensePlate: params.licensePlate?.trim() || null,
      status: params.status,
      notes: params.notes?.trim() || null,
      totalDeliveries: 0,
      createdAt: firestore.FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /** Mirrors _saveVehicle()'s update branch — lastUsedAt is preserved, not modified. */
  async updateVehicle(
    companyId: string,
    vehicle: Vehicle,
    params: {
      registration: string;
      make?: string;
      model?: string;
      color?: string;
      licensePlate?: string;
      status: VehicleStatus;
      notes?: string;
    },
  ): Promise<void> {
    await this.vehiclesRef(companyId)
      .doc(vehicle.id)
      .update({
        companyId,
        registration: params.registration.trim(),
        make: params.make?.trim() || null,
        model: params.model?.trim() || null,
        color: params.color?.trim() || null,
        licensePlate: params.licensePlate?.trim() || null,
        status: params.status,
        notes: params.notes?.trim() || null,
        lastUsedAt: vehicle.lastUsedAt ? firestore.Timestamp.fromDate(vehicle.lastUsedAt) : null,
      });
  }

  /** Mirrors _deleteVehicle(). */
  async deleteVehicle(companyId: string, vehicleId: string): Promise<void> {
    await this.vehiclesRef(companyId).doc(vehicleId).delete();
  }

  /** Mirrors the `documents` array overwrite after upload on vehicle creation. */
  async setDocuments(companyId: string, vehicleId: string, documentUrls: string[]): Promise<void> {
    await this.vehiclesRef(companyId).doc(vehicleId).update({ documents: documentUrls });
  }

  /** Mirrors the merged-array update after upload when editing an existing vehicle. */
  async appendDocuments(companyId: string, vehicleId: string, newUrls: string[]): Promise<void> {
    await this.vehiclesRef(companyId)
      .doc(vehicleId)
      .update({ documents: firestore.FieldValue.arrayUnion(...newUrls) });
  }

  /** Mirrors the `documents` arrayRemove call when a document is deleted from a vehicle. */
  async removeDocument(companyId: string, vehicleId: string, docUrl: string): Promise<void> {
    await this.vehiclesRef(companyId)
      .doc(vehicleId)
      .update({ documents: firestore.FieldValue.arrayRemove(docUrl) });
  }

  /** Mirrors VehicleDocumentService.uploadFile() for a local file URI (mobile/native path). */
  async uploadDocument(params: {
    companyId: string;
    vehicleId: string;
    fileUri: string;
    fileName: string;
    onProgress?: (progress: number) => void;
  }): Promise<string> {
    const { companyId, vehicleId, fileUri, fileName, onProgress } = params;
    const storagePath = `companies/${companyId}/vehicles/${vehicleId}/documents/${Date.now()}_${fileName}`;
    const ref = this.storageInstance.ref(storagePath);

    const task = ref.putFile(fileUri);
    if (onProgress) {
      task.on('state_changed', (snapshot) => {
        const total = snapshot.totalBytes > 0 ? snapshot.totalBytes : 1;
        onProgress(Math.min(Math.max(snapshot.bytesTransferred / total, 0), 1));
      });
    }

    await task;
    return ref.getDownloadURL();
  }

  /** Mirrors VehicleDocumentService.deleteByUrl(). */
  async deleteDocumentByUrl(url: string): Promise<void> {
    const ref = this.storageInstance.refFromURL(url);
    await ref.delete();
  }
}
