import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import SHA256 from 'crypto-js/sha256';
import { EnvironmentConfig } from '../config/environment';

/**
 * Ported from lib/models/pod_access_token.dart + lib/services/pod_token_service.dart
 * (verified against source on 2026-06-22), following the constructor-injected
 * repository pattern from claimRepository.ts/deliveryRepository.ts rather than the
 * hardcoded-singleton pattern the Flutter service used.
 *
 * Deviation: token generation uses crypto-js's SHA256 instead of Dart's `crypto`
 * package — same algorithm, same 32-character truncated hex output.
 */
export interface PodAccessToken {
  deliveryId: string;
  token: string;
  createdAt: Date;
  expiresAt?: Date;
  isActive: boolean;
  accessCount: number;
}

/** Mirrors PODAccessToken.generateToken(). */
function generateToken(deliveryId: string): string {
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 1_000_000_000);
  const input = `${deliveryId}-${timestamp}-${random}`;
  return SHA256(input).toString().substring(0, 32);
}

/** Mirrors PODAccessToken.create(). */
function createToken(deliveryId: string, expiryDays?: number): PodAccessToken {
  const createdAt = new Date();
  const expiresAt = expiryDays != null ? new Date(createdAt.getTime() + expiryDays * 24 * 60 * 60 * 1000) : undefined;
  return {
    deliveryId,
    token: generateToken(deliveryId),
    createdAt,
    expiresAt,
    isActive: true,
    accessCount: 0,
  };
}

/** Mirrors PODAccessToken.isValid. */
export function isPodTokenValid(token: PodAccessToken): boolean {
  if (!token.isActive) return false;
  if (token.expiresAt && new Date() > token.expiresAt) return false;
  return true;
}

/** Mirrors PODAccessToken.getPublicUrl(). */
export function podTokenPublicUrl(token: PodAccessToken, baseUrl?: string): string {
  const base = baseUrl ?? EnvironmentConfig.publicPodBaseUrl;
  return `${base}/pod/${token.deliveryId}?token=${token.token}`;
}

function tokenFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): PodAccessToken {
  const data = doc.data() ?? {};
  return {
    deliveryId: data.deliveryId ?? '',
    token: data.token ?? '',
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    expiresAt: data.expiresAt?.toDate?.(),
    isActive: data.isActive ?? true,
    accessCount: data.accessCount ?? 0,
  };
}

function tokenToFirestore(token: PodAccessToken): Record<string, unknown> {
  return {
    deliveryId: token.deliveryId,
    token: token.token,
    createdAt: firestore.Timestamp.fromDate(token.createdAt),
    expiresAt: token.expiresAt ? firestore.Timestamp.fromDate(token.expiresAt) : null,
    isActive: token.isActive,
    accessCount: token.accessCount,
  };
}

export class PodTokenRepository {
  constructor(private firestoreInstance: FirebaseFirestoreTypes.Module = firestore()) {}

  private tokensRef() {
    return this.firestoreInstance.collection('pod_tokens');
  }

  /** Mirrors createToken(): reuses an existing valid token for the delivery if one exists. */
  async createToken(deliveryId: string, expiryDays = 90): Promise<PodAccessToken> {
    const existing = await this.tokensRef().where('deliveryId', '==', deliveryId).where('isActive', '==', true).limit(1).get();

    if (existing.docs.length > 0) {
      const existingToken = tokenFromFirestore(existing.docs[0]);
      if (isPodTokenValid(existingToken)) {
        return existingToken;
      }
    }

    const token = createToken(deliveryId, expiryDays);
    await this.tokensRef().doc(token.token).set(tokenToFirestore(token));
    return token;
  }

  /** Mirrors validateToken(): returns the delivery ID if the token is valid, else null. */
  async validateToken(token: string): Promise<string | null> {
    try {
      const doc = await this.tokensRef().doc(token).get();
      if (!doc.exists()) return null;

      const tokenData = tokenFromFirestore(doc);
      if (!isPodTokenValid(tokenData)) return null;

      await this.incrementAccessCount(token);
      return tokenData.deliveryId;
    } catch {
      return null;
    }
  }

  /** Mirrors getTokenByDeliveryId(). */
  async getTokenByDeliveryId(deliveryId: string): Promise<PodAccessToken | null> {
    try {
      const result = await this.tokensRef().where('deliveryId', '==', deliveryId).where('isActive', '==', true).limit(1).get();
      if (result.docs.length === 0) return null;
      return tokenFromFirestore(result.docs[0]);
    } catch {
      return null;
    }
  }

  /** Mirrors deactivateToken(). */
  async deactivateToken(token: string): Promise<void> {
    await this.tokensRef().doc(token).update({
      isActive: false,
      deactivatedAt: firestore.FieldValue.serverTimestamp(),
    });
  }

  /** Mirrors deactivateAllTokensForDelivery(). */
  async deactivateAllTokensForDelivery(deliveryId: string): Promise<void> {
    const tokens = await this.tokensRef().where('deliveryId', '==', deliveryId).where('isActive', '==', true).get();

    const batch = this.firestoreInstance.batch();
    tokens.docs.forEach((doc) => {
      batch.update(doc.ref, { isActive: false, deactivatedAt: firestore.FieldValue.serverTimestamp() });
    });
    await batch.commit();
  }

  /** Mirrors cleanupExpiredTokens() (admin function). Returns the number deactivated. */
  async cleanupExpiredTokens(): Promise<number> {
    const tokens = await this.tokensRef().where('isActive', '==', true).get();

    let deactivated = 0;
    const batch = this.firestoreInstance.batch();
    tokens.docs.forEach((doc) => {
      const token = tokenFromFirestore(doc);
      if (!isPodTokenValid(token)) {
        batch.update(doc.ref, { isActive: false, deactivatedAt: firestore.Timestamp.now() });
        deactivated += 1;
      }
    });
    await batch.commit();
    return deactivated;
  }

  /** Mirrors _incrementAccessCount(): non-critical, failure is swallowed. */
  private async incrementAccessCount(token: string): Promise<void> {
    try {
      await this.tokensRef().doc(token).update({
        accessCount: firestore.FieldValue.increment(1),
        lastAccessedAt: firestore.FieldValue.serverTimestamp(),
      });
    } catch {
      // Non-critical, mirrors the Dart source's warning-only log.
    }
  }
}
