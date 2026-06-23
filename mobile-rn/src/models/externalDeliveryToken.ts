import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import SHA256 from 'crypto-js/sha256';

/**
 * Ported from lib/models/external_delivery_token.dart (verified against source on
 * 2026-06-23) — scoped to what create_delivery_screen.dart actually needs
 * (createUploadToken/generateUploadLink). `getToken`/`uploadDocuments`/
 * `uploadDocumentsWeb`/`revokeToken`/`getDeliveryForToken` from
 * external_upload_service.dart are NOT ported yet — those back the actual upload flow
 * for lib/screens/external/upload_screen.dart (`/upload/:token`), a separate
 * not-yet-built public route, not this admin screen.
 *
 * Deviation: token generation uses crypto-js's SHA256 instead of Dart's
 * `Random.secure()` + base64Url, matching the precedent already set by
 * podTokenRepository.ts's generateToken() for the near-identical PODAccessToken case.
 */
export interface ExternalDeliveryToken {
  id: string;
  deliveryId: string;
  companyId: string;
  providerName: string;
  providerContact?: string;
  createdAt: Date;
  expiresAt?: Date;
  isUsed: boolean;
  uploadedFiles: string[];
  uploadedAt?: Date;
  uploadNotes?: string;
}

/** Mirrors ExternalDeliveryToken.generateToken(). */
export function generateExternalUploadToken(deliveryId: string): string {
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 1_000_000_000);
  return SHA256(`${deliveryId}-${timestamp}-${random}`).toString().substring(0, 32);
}

/** Mirrors ExternalDeliveryToken.isValid(). */
export function isExternalUploadTokenValid(token: ExternalDeliveryToken): boolean {
  if (token.isUsed) return false;
  if (token.expiresAt && new Date() > token.expiresAt) return false;
  return true;
}

export function externalDeliveryTokenFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): ExternalDeliveryToken {
  const data = doc.data() ?? {};
  return {
    id: doc.id,
    deliveryId: data.deliveryId ?? '',
    companyId: data.companyId ?? '',
    providerName: data.providerName ?? '',
    providerContact: data.providerContact ?? undefined,
    createdAt: (data.createdAt as FirebaseFirestoreTypes.Timestamp)?.toDate() ?? new Date(),
    expiresAt: (data.expiresAt as FirebaseFirestoreTypes.Timestamp | undefined)?.toDate(),
    isUsed: data.isUsed ?? false,
    uploadedFiles: Array.isArray(data.uploadedFiles) ? data.uploadedFiles : [],
    uploadedAt: (data.uploadedAt as FirebaseFirestoreTypes.Timestamp | undefined)?.toDate(),
    uploadNotes: data.uploadNotes ?? undefined,
  };
}

export function externalDeliveryTokenToFirestore(token: Omit<ExternalDeliveryToken, 'id'>): Record<string, unknown> {
  return {
    deliveryId: token.deliveryId,
    companyId: token.companyId,
    providerName: token.providerName,
    providerContact: token.providerContact ?? null,
    createdAt: firestore.Timestamp.fromDate(token.createdAt),
    expiresAt: token.expiresAt ? firestore.Timestamp.fromDate(token.expiresAt) : null,
    isUsed: token.isUsed,
    uploadedFiles: token.uploadedFiles,
    uploadedAt: token.uploadedAt ? firestore.Timestamp.fromDate(token.uploadedAt) : null,
    uploadNotes: token.uploadNotes ?? null,
  };
}
