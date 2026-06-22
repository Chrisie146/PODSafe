import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { Vehicle, VehicleStatus } from './vehicle';
import { normalizeRegistration } from '../utils/vehicleUtils';

/**
 * Ported from Vehicle.fromFirestore/toFirestore in lib/models/vehicle_model.dart
 * (verified against source on 2026-06-22).
 */
const VALID_STATUSES: VehicleStatus[] = ['active', 'inactive', 'maintenance'];

export function vehicleFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): Vehicle {
  const data = doc.data() ?? {};
  const status = VALID_STATUSES.includes(data.status) ? (data.status as VehicleStatus) : 'active';

  return {
    id: doc.id,
    companyId: data.companyId ?? '',
    registration: normalizeRegistration(data.registration ?? ''),
    make: data.make,
    model: data.model,
    color: data.color,
    licensePlate: data.licensePlate,
    status,
    totalDeliveries: data.totalDeliveries ?? 0,
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    lastUsedAt: data.lastUsedAt?.toDate?.(),
    notes: data.notes,
    documents: Array.isArray(data.documents) ? (data.documents as string[]) : undefined,
  };
}

export function vehicleToFirestore(vehicle: Vehicle): Record<string, unknown> {
  return {
    companyId: vehicle.companyId,
    registration: vehicle.registration,
    make: vehicle.make ?? null,
    model: vehicle.model ?? null,
    color: vehicle.color ?? null,
    licensePlate: vehicle.licensePlate ?? null,
    status: vehicle.status,
    totalDeliveries: vehicle.totalDeliveries,
    createdAt: firestore.Timestamp.fromDate(vehicle.createdAt),
    lastUsedAt: vehicle.lastUsedAt ? firestore.Timestamp.fromDate(vehicle.lastUsedAt) : null,
    notes: vehicle.notes ?? null,
    documents: vehicle.documents ?? null,
  };
}
