import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { DocumentMetadataEntry, LocationData, PodDetectionFlags, PodRecord, PodStatus } from './pod';

/**
 * Ported from PODRecord.fromFirestore/toFirestore + LocationData.fromMap/toMap in
 * lib/models/pod_model.dart (verified against source on 2026-06-22).
 */
const VALID_STATUSES: PodStatus[] = ['pending', 'signed', 'missing'];

function locationFromMap(map: Record<string, unknown>): LocationData {
  return {
    latitude: Number(map.latitude ?? 0),
    longitude: Number(map.longitude ?? 0),
    address: (map.address as string) ?? '',
    accuracy: map.accuracy != null ? Number(map.accuracy) : undefined,
  };
}

function locationToMap(location: LocationData): Record<string, unknown> {
  return {
    latitude: location.latitude,
    longitude: location.longitude,
    address: location.address,
    accuracy: location.accuracy ?? null,
  };
}

function detectionFlagsFromMap(map: Record<string, unknown>): PodDetectionFlags {
  return {
    hasSignature: Boolean(map.hasSignature),
    hasStamp: Boolean(map.hasStamp),
    ocrConfident: Boolean(map.ocrConfident),
    warnings: Array.isArray(map.warnings) ? (map.warnings as string[]) : [],
    ocrConfidenceScore: Number(map.ocrConfidenceScore ?? 0.5),
  };
}

function detectionFlagsToMap(flags: PodDetectionFlags): Record<string, unknown> {
  return {
    hasSignature: flags.hasSignature,
    hasStamp: flags.hasStamp,
    ocrConfident: flags.ocrConfident,
    warnings: flags.warnings,
    ocrConfidenceScore: flags.ocrConfidenceScore,
  };
}

export function podFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): PodRecord {
  const data = doc.data() ?? {};
  const status = VALID_STATUSES.includes(data.status) ? (data.status as PodStatus) : 'pending';

  return {
    id: doc.id,
    companyId: data.companyId ?? '',
    driverId: data.driverId ?? '',
    deliveryId: data.deliveryId ?? '',
    customerName: data.customerName ?? '',
    invoiceNumber: data.invoiceNumber ?? '',
    status,
    timestamp: data.timestamp?.toDate?.() ?? new Date(),
    location: data.location != null ? locationFromMap(data.location) : undefined,
    signedBy: data.signedBy,
    signatureUrl: data.signatureUrl,
    photoUrl: data.photoUrl,
    photoUrls: Array.isArray(data.photoUrls) ? (data.photoUrls as string[]) : undefined,
    documentUrls: Array.isArray(data.documentUrls) ? (data.documentUrls as string[]) : undefined,
    documentMetadata: Array.isArray(data.documentMetadata) ? (data.documentMetadata as DocumentMetadataEntry[]) : undefined,
    pdfUrl: data.pdfUrl,
    metadata: data.metadata ?? {},
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    updatedAt: data.updatedAt?.toDate?.(),
    ocrRawText: data.ocrRawText,
    ocrFields: data.ocrFields ?? undefined,
    ocrConfidence: data.ocrConfidence != null ? Number(data.ocrConfidence) : undefined,
    detectionFlags: data.detectionFlags != null ? detectionFlagsFromMap(data.detectionFlags) : undefined,
  };
}

export function podToFirestore(pod: PodRecord): Record<string, unknown> {
  return {
    companyId: pod.companyId,
    driverId: pod.driverId,
    deliveryId: pod.deliveryId,
    customerName: pod.customerName,
    invoiceNumber: pod.invoiceNumber,
    status: pod.status,
    timestamp: firestore.Timestamp.fromDate(pod.timestamp),
    location: pod.location ? locationToMap(pod.location) : null,
    signedBy: pod.signedBy ?? null,
    signatureUrl: pod.signatureUrl ?? null,
    photoUrl: pod.photoUrl ?? null,
    photoUrls: pod.photoUrls ?? null,
    documentUrls: pod.documentUrls ?? null,
    documentMetadata: pod.documentMetadata ?? null,
    pdfUrl: pod.pdfUrl ?? null,
    metadata: pod.metadata,
    createdAt: firestore.Timestamp.fromDate(pod.createdAt),
    updatedAt: pod.updatedAt ? firestore.Timestamp.fromDate(pod.updatedAt) : null,
    ocrRawText: pod.ocrRawText ?? null,
    ocrFields: pod.ocrFields ?? null,
    ocrConfidence: pod.ocrConfidence ?? null,
    detectionFlags: pod.detectionFlags ? detectionFlagsToMap(pod.detectionFlags) : null,
  };
}
