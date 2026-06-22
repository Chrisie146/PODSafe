import { Platform } from 'react-native';
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import Geolocation, { GeoPosition } from 'react-native-geolocation-service';
import { PERMISSIONS, RESULTS, check, request } from 'react-native-permissions';
import { Claim, ClaimComment, ClaimStatus, ClaimType } from '../models/claim';
import { claimFromFirestore, claimToMap } from '../models/claim.converters';
import { CompanyClaimSettings, defaultCompanyClaimSettings } from '../models/companyClaimSettings';
import { companyClaimSettingsFromFirestore, companyClaimSettingsToMap } from '../models/companyClaimSettings.converters';

/**
 * Ported from lib/services/claim_service.dart (verified against source on 2026-06-21),
 * following the constructor-injected repository pattern from deliveryRepository.ts /
 * chatRepository.ts.
 *
 * SCOPE: only the driver-facing methods are ported in this pass (view own claims, file a
 * new claim, view claim detail, add a comment, upload evidence captured at filing time,
 * GPS capture, evidence quality scoring, claim ID generation, company settings lookup).
 *
 * Intentionally SKIPPED as admin-only (Phase 3 will need these later):
 * - getClaimsPendingAction (approval-queue stream keyed by reviewer role)
 * - updateClaimStatus / approveClaimLevel / rejectClaim / resolveClaim / closeClaim
 *   (the approval workflow state machine)
 * - getClaimAnalytics (admin reporting aggregation)
 * - updateCompanySettings (admin settings editor — getCompanySettings IS ported since
 *   driver screens need read access to settings to know required photos/signature/etc.)
 * - detectFraudPattern / detectRecurringPattern (admin-side fraud/pattern detection used
 *   when triaging claims, not when filing them)
 * - updateEvidenceStatus (manual evidence-status override — not called by either
 *   create_claim_form.dart or upload_evidence_form.dart, the two Phase 3 screens that
 *   needed this file reopened; add it when a screen actually needs it).
 * - createClaimWithoutEvidence / uploadEvidenceToClaim / getClaimsPendingEvidence ARE now
 *   ported below (added when porting create_claim_form.dart / upload_evidence_form.dart),
 *   despite the note above predating them — driver's `createClaim` still always uploads
 *   evidence inline before creating the claim document (report_issue_screen.dart never
 *   calls the delayed-evidence methods), but these three are the admin "file now, attach
 *   evidence later" workflow.
 * - calculateEvidenceQualityScore IS ported (pure function, needed by createClaim's
 *   caller to populate evidenceQualityScore on submission, mirroring
 *   report_issue_screen.dart's _submitClaim)
 *
 * Deviations from the Flutter source:
 * - uploadPhoto/uploadSignature take a `{ uri, fileName }` pair instead of a Dart `File`,
 *   since RN's image-picker/signature libraries hand back URIs, and storage.putFile()
 *   accepts a URI string directly (no separate File type needed on RN).
 * - getCurrentLocation uses react-native-geolocation-service instead of Geolocator,
 *   wrapped in a Promise (the package's API is callback-based).
 */
export class ClaimRepository {
  constructor(
    private firestoreInstance: FirebaseFirestoreTypes.Module = firestore(),
    private storageInstance: ReturnType<typeof storage> = storage(),
  ) {}

  private claimsRef(companyId: string) {
    return this.firestoreInstance.collection('companies').doc(companyId).collection('claims');
  }

  /** Mirrors getClaimsStream(). Returns an unsubscribe function. */
  subscribeToClaims(
    companyId: string,
    onChange: (claims: Claim[]) => void,
    onError?: (error: Error) => void,
    filters?: {
      status?: ClaimStatus;
      type?: ClaimType;
      driverId?: string;
      customerId?: string;
      startDate?: Date;
      endDate?: Date;
    },
  ): () => void {
    let query: FirebaseFirestoreTypes.Query = this.claimsRef(companyId).orderBy('createdAt', 'desc');

    if (filters?.status) {
      query = query.where('status', '==', filters.status);
    }
    if (filters?.type) {
      query = query.where('type', '==', filters.type);
    }
    if (filters?.driverId) {
      query = query.where('driverId', '==', filters.driverId);
    }
    if (filters?.customerId) {
      query = query.where('customerId', '==', filters.customerId);
    }
    if (filters?.startDate) {
      query = query.where('createdAt', '>=', filters.startDate.toISOString());
    }
    if (filters?.endDate) {
      query = query.where('createdAt', '<=', filters.endDate.toISOString());
    }

    return query.onSnapshot(
      (snapshot) => onChange(snapshot.docs.map(claimFromFirestore)),
      (error) => onError?.(error as unknown as Error),
    );
  }

  /** Mirrors getClaim(). Returns null if not found or on error (matches Dart's swallow-and-return-null). */
  async getClaim(companyId: string, claimId: string): Promise<Claim | null> {
    try {
      const doc = await this.claimsRef(companyId).doc(claimId).get();
      if (!doc.exists()) return null;
      return claimFromFirestore(doc);
    } catch {
      return null;
    }
  }

  /** Mirrors createClaim(). Assigns a generated doc id and sets createdAt/updatedAt to now. */
  async createClaim(claim: Claim): Promise<string> {
    const claimRef = this.claimsRef(claim.companyId).doc();
    const now = new Date();
    const claimWithId: Claim = { ...claim, id: claimRef.id, createdAt: now, updatedAt: now };

    await claimRef.set(claimToMap(claimWithId));
    return claimRef.id;
  }

  /** Mirrors updateClaim(). */
  async updateClaim(companyId: string, claim: Claim): Promise<void> {
    await this.claimsRef(companyId)
      .doc(claim.id)
      .update(claimToMap({ ...claim, updatedAt: new Date() }));
  }

  /** Mirrors updateClaimStatus(): read-modify-write, appending a StatusHistoryEntry. */
  async updateClaimStatus(params: {
    companyId: string;
    claimId: string;
    newStatus: ClaimStatus;
    userId: string;
    userName: string;
    notes?: string;
    metadata?: Record<string, unknown>;
  }): Promise<void> {
    const { companyId, claimId, newStatus, userId, userName, notes, metadata } = params;
    const claim = await this.getClaim(companyId, claimId);
    if (!claim) {
      throw new Error('Claim not found');
    }

    const updatedClaim: Claim = {
      ...claim,
      status: newStatus,
      statusHistory: [...claim.statusHistory, { status: newStatus, timestamp: new Date(), userId, userName, notes, metadata }],
    };

    await this.updateClaim(companyId, updatedClaim);
  }

  /** Mirrors addComment(): read-modify-write the comments array onto the claim. */
  async addComment(params: { companyId: string; claimId: string; comment: ClaimComment }): Promise<void> {
    const { companyId, claimId, comment } = params;
    const claim = await this.getClaim(companyId, claimId);
    if (!claim) {
      throw new Error('Claim not found');
    }

    const updatedClaim: Claim = {
      ...claim,
      comments: [...claim.comments, comment],
      updatedAt: new Date(),
    };

    await this.updateClaim(companyId, updatedClaim);
  }

  /** Mirrors uploadPhoto(). `fileUri` is a local file URI from image-picker. */
  async uploadPhoto(params: { companyId: string; claimId: string; fileUri: string; fileName: string }): Promise<string> {
    const { companyId, claimId, fileUri, fileName } = params;
    const path = `companies/${companyId}/claims/${claimId}/photos/${fileName}`;
    const ref = this.storageInstance.ref(path);
    await ref.putFile(fileUri);
    return await ref.getDownloadURL();
  }

  /**
   * Mirrors uploadSignature(). The Dart source writes the signature bytes to a temp file
   * (Directory.systemTemp + File.writeAsBytes) before uploading via putFile. RN's
   * signature-canvas library hands back a base64 PNG data URL directly, so this uploads
   * via Storage's putString(..., 'data_url') instead — same result, no temp file or
   * react-native-fs dependency needed.
   */
  async uploadSignature(params: {
    companyId: string;
    claimId: string;
    signatureDataUrl: string;
    signatureType: 'customer' | 'driver';
  }): Promise<string> {
    const { companyId, claimId, signatureDataUrl, signatureType } = params;
    const path = `companies/${companyId}/claims/${claimId}/signatures/${signatureType}_signature.png`;
    const ref = this.storageInstance.ref(path);
    await ref.putString(signatureDataUrl, 'data_url');
    return await ref.getDownloadURL();
  }

  /**
   * Mirrors getCurrentLocation(): best-effort GPS read, returns {} on any failure or
   * denied permission (matches the Dart catch-all / empty-map fallback).
   */
  async getCurrentLocation(): Promise<Record<string, unknown>> {
    try {
      const permission = Platform.OS === 'ios' ? PERMISSIONS.IOS.LOCATION_WHEN_IN_USE : PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION;
      let status = await check(permission);
      if (status === RESULTS.DENIED) {
        status = await request(permission);
      }
      if (status !== RESULTS.GRANTED && status !== RESULTS.LIMITED) {
        return {};
      }

      const position = await new Promise<GeoPosition>((resolve, reject) => {
        Geolocation.getCurrentPosition(resolve, reject, { enableHighAccuracy: true });
      });

      return {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy,
        timestamp: new Date().toISOString(),
      };
    } catch {
      return {};
    }
  }

  /** Mirrors generateClaimId(): per-company-per-year counter via a Firestore transaction. */
  async generateClaimId(companyId: string): Promise<string> {
    try {
      const settings = await this.getCompanySettings(companyId);
      const prefix = settings.claimIdPrefix;
      const year = new Date().getFullYear();

      const counterRef = this.firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('claimCounters')
        .doc(year.toString());

      const nextNumber = await this.firestoreInstance.runTransaction(async (transaction) => {
        const counterDoc = await transaction.get(counterRef);

        let value: number;
        if (!counterDoc.exists()) {
          value = settings.claimIdStartNumber;
          transaction.set(counterRef, { count: value });
        } else {
          value = ((counterDoc.data()?.count as number) ?? 0) + 1;
          transaction.update(counterRef, { count: value });
        }
        return value;
      });

      return `${prefix}-${year}-${nextNumber.toString().padStart(4, '0')}`;
    } catch {
      // Fallback to timestamp-based ID, matching the Dart catch block.
      return `CLM-${Date.now()}`;
    }
  }

  /** Mirrors calculateEvidenceQualityScore() — pure function, no I/O. */
  calculateEvidenceQualityScore(claim: Claim): number {
    let score = 0;

    if (claim.photoUrls.length >= 3) {
      score += 4;
    } else if (claim.photoUrls.length >= 2) {
      score += 3;
    } else if (claim.photoUrls.length > 0) {
      score += 2;
    }

    if (Object.keys(claim.gpsLocation).length > 0) {
      score += 2;
    }

    if (claim.customerSignatureUrl) {
      score += 2;
    }

    if (claim.filingContext === 'atDeliverySite') {
      score += 1;
    }

    const hoursSinceFiled = (Date.now() - claim.createdAt.getTime()) / (1000 * 60 * 60);
    if (hoursSinceFiled <= 24) {
      score += 1;
    }

    return Math.min(10, Math.max(0, score));
  }

  /**
   * Mirrors getCompanySettings(): reads `companies/{companyId}/settings/claims`, creating
   * and persisting the default document if none exists (same as the Dart service).
   */
  async getCompanySettings(companyId: string): Promise<CompanyClaimSettings> {
    try {
      const doc = await this.firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('claims')
        .get();

      if (doc.exists()) {
        return companyClaimSettingsFromFirestore(doc);
      }

      const defaults = defaultCompanyClaimSettings(companyId);
      await this.firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('claims')
        .set(companyClaimSettingsToMap(defaults));
      return defaults;
    } catch {
      return defaultCompanyClaimSettings(companyId);
    }
  }

  /** Mirrors updateCompanySettings(): full-document overwrite, same as the Dart source. */
  async updateCompanySettings(settings: CompanyClaimSettings): Promise<void> {
    await this.firestoreInstance
      .collection('companies')
      .doc(settings.companyId)
      .collection('settings')
      .doc('claims')
      .set(companyClaimSettingsToMap(settings));
  }

  /** Mirrors createClaimWithoutEvidence(): files a claim with evidenceStatus forced to 'pending'. */
  async createClaimWithoutEvidence(companyId: string, claim: Claim): Promise<string> {
    const claimRef = this.claimsRef(companyId).doc();
    const claimWithId: Claim = { ...claim, id: claimRef.id, evidenceStatus: 'pending' };
    await claimRef.set(claimToMap(claimWithId));
    return claimRef.id;
  }

  /**
   * Mirrors uploadEvidenceToClaim(): attaches photos/signature/documents captured after
   * the claim was already filed. Takes local file URIs / a signature data URL directly
   * instead of the Dart source's web-vs-native byte-normalization branching (RN's
   * image-picker and signature-canvas libraries always hand back a URI or data URL).
   * Per-item upload failures are logged and skipped, matching the Dart source's
   * catch-and-continue loop rather than failing the whole batch.
   */
  async uploadEvidenceToClaim(params: {
    companyId: string;
    claimId: string;
    photoUris?: string[];
    signatureDataUrl?: string;
    documentUris?: string[];
  }): Promise<void> {
    const { companyId, claimId, photoUris, signatureDataUrl, documentUris } = params;
    const claimRef = this.claimsRef(companyId).doc(claimId);
    const doc = await claimRef.get();
    if (!doc.exists()) {
      throw new Error('Claim not found');
    }

    const claim = claimFromFirestore(doc);
    const photoUrls = [...claim.photoUrls];
    let hasSignature = claim.hasSignature;
    let hasDocuments = claim.hasDocuments;
    let photoCount = claim.photoCount;

    if (photoUris?.length) {
      for (let i = 0; i < photoUris.length; i++) {
        try {
          const fileName = `photo_${Date.now()}_${i}.jpg`;
          const ref = this.storageInstance.ref(`companies/${companyId}/claims/${claimId}/photos/${fileName}`);
          await ref.putFile(photoUris[i]);
          photoUrls.push(await ref.getDownloadURL());
          photoCount++;
        } catch (e) {
          console.warn(`[ClaimRepository] Error uploading photo ${i}: ${(e as Error).message}`);
        }
      }
    }

    if (signatureDataUrl) {
      try {
        const ref = this.storageInstance.ref(`companies/${companyId}/claims/${claimId}/signature_${Date.now()}.png`);
        await ref.putString(signatureDataUrl, 'data_url');
        const url = await ref.getDownloadURL();
        await claimRef.update({ customerSignatureUrl: url });
        hasSignature = true;
      } catch (e) {
        console.warn(`[ClaimRepository] Error uploading signature: ${(e as Error).message}`);
      }
    }

    if (documentUris?.length) {
      for (let i = 0; i < documentUris.length; i++) {
        try {
          const fileName = `document_${Date.now()}_${i}`;
          const ref = this.storageInstance.ref(`companies/${companyId}/claims/${claimId}/documents/${fileName}`);
          await ref.putFile(documentUris[i]);
        } catch (e) {
          console.warn(`[ClaimRepository] Error uploading document ${i}: ${(e as Error).message}`);
        }
      }
      hasDocuments = true;
    }

    await claimRef.update({
      photoUrls,
      photoCount,
      hasSignature,
      hasDocuments,
      evidenceStatus: 'received',
      evidenceReceivedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }

  /** Mirrors getClaimsPendingEvidence(). Returns an unsubscribe function. */
  subscribeToClaimsPendingEvidence(companyId: string, onChange: (claims: Claim[]) => void, onError?: (error: Error) => void): () => void {
    return this.claimsRef(companyId)
      .where('evidenceStatus', '==', 'pending')
      .orderBy('createdAt', 'desc')
      .onSnapshot(
        (snapshot) => onChange(snapshot.docs.map(claimFromFirestore)),
        (error) => onError?.(error as unknown as Error),
      );
  }
}
