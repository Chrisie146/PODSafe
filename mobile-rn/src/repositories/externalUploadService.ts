import firestore from '@react-native-firebase/firestore';
import { EnvironmentConfig } from '../config/environment';
import {
  ExternalDeliveryToken,
  externalDeliveryTokenToFirestore,
  generateExternalUploadToken,
} from '../models/externalDeliveryToken';

/**
 * Ported from lib/services/external_upload_service.dart (verified against source on
 * 2026-06-23) — scoped to create_delivery_screen.dart's actual usage (createUploadToken
 * + generateUploadLink for the third-party-transport flow). See models/
 * externalDeliveryToken.ts's class comment for what's deliberately not ported yet.
 *
 * Deviation: generateUploadLink() defaults to EnvironmentConfig.publicPodBaseUrl instead
 * of the Dart source's hardcoded `https://podsafe-92a3e.web.app` — that's the stale dev
 * project ID per vault "11 Environment and Native Setup", and this is the same kind of
 * public, unauthenticated, token-gated web route as the POD public-view link
 * (podTokenRepository.ts's podTokenPublicUrl()), so it reuses the same base URL config.
 */
const tokensRef = () => firestore().collection('external_delivery_tokens');

/** Mirrors ExternalUploadService.createUploadToken(). */
export async function createUploadToken(params: {
  deliveryId: string;
  companyId: string;
  providerName: string;
  providerContact?: string;
  expiryDays?: number;
}): Promise<ExternalDeliveryToken> {
  const id = generateExternalUploadToken(params.deliveryId);
  const createdAt = new Date();
  const expiresAt = params.expiryDays != null ? new Date(createdAt.getTime() + params.expiryDays * 86400000) : undefined;

  const token: ExternalDeliveryToken = {
    id,
    deliveryId: params.deliveryId,
    companyId: params.companyId,
    providerName: params.providerName,
    providerContact: params.providerContact,
    createdAt,
    expiresAt,
    isUsed: false,
    uploadedFiles: [],
  };

  await tokensRef().doc(id).set(externalDeliveryTokenToFirestore(token));
  await firestore().collection('deliveries').doc(params.deliveryId).update({ uploadToken: id });

  return token;
}

/** Mirrors ExternalUploadService.generateUploadLink(). */
export function generateUploadLink(token: string, baseUrl?: string): string {
  const base = baseUrl ?? EnvironmentConfig.publicPodBaseUrl;
  return `${base}/upload/${token}`;
}
