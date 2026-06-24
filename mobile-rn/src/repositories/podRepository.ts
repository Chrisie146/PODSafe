import { Platform } from 'react-native';
import firestore, {
  FirebaseFirestoreTypes,
} from '@react-native-firebase/firestore';
import storage from '@react-native-firebase/storage';
import TextRecognition from '@react-native-ml-kit/text-recognition';
import Geolocation from 'react-native-geolocation-service';
import { PERMISSIONS, RESULTS, check, request } from 'react-native-permissions';
import { Delivery } from '../models/delivery';
import { deliveryFromFirestore } from '../models/delivery.converters';
import { LocationData, PodRecord } from '../models/pod';
import { podFromFirestore, podToFirestore } from '../models/pod.converters';
import { OcrFields } from '../models/ocrFields';

/**
 * Ported from lib/screens/driver/pod_capture_screen.dart's upload/Firestore/location
 * logic (verified against source on 2026-06-22), plus the auto-match piece of
 * lib/services/pod_repository.dart, following the constructor-injected repository
 * pattern established by deliveryRepository.ts/claimRepository.ts.
 *
 * Per the migration plan's Section 4, this is the ONE canonical POD repository — see
 * models/pod.ts's file-level comment. tryAutoMatchDelivery/attachOcrData exist to retarget
 * DocumentIntake.tsx's OCR-review flow onto this same `pods/{deliveryId}` collection
 * instead of the abandoned `companies/{companyId}/pods/{podId}` shape.
 *
 * Deviations from the Flutter source:
 * - `_uploadToStorage`'s single dynamic-typed (Uint8List | String) method is split into
 *   `uploadFile` (local file URI, via putFile) and `uploadSignature` (base64 data URL
 *   from react-native-signature-canvas, via putString) — same split already used in
 *   claimRepository.ts, and cleaner than RN's lack of a Dart-style dynamic dispatch.
 * - tryAutoMatchDelivery now queries the top-level `deliveries` collection filtered by
 *   companyId (matching deliveryRepository.ts and how deliveries are actually stored
 *   everywhere else in the app), instead of pod_repository.dart's
 *   `companies/{companyId}/deliveries` subcollection query — that subcollection is never
 *   written to by anything else in the codebase, so the original query could never have
 *   matched in production. This is a fix, not a faithful replication of a no-op bug.
 */
export class PodRepository {
  constructor(
    private firestoreInstance: FirebaseFirestoreTypes.Module = firestore(),
    private storageInstance: ReturnType<typeof storage> = storage(),
  ) {}

  private podsRef() {
    return this.firestoreInstance.collection('pods');
  }

  /** Mirrors _uploadToStorage() for local file URIs (photos, documents, stamp photo). */
  async uploadFile(path: string, fileUri: string): Promise<string> {
    const contentType = path.endsWith('.png') ? 'image/png' : 'image/jpeg';
    const ref = this.storageInstance.ref(path);
    await ref.putFile(fileUri, {
      contentType,
      cacheControl: 'public, max-age=31536000',
    });
    return ref.getDownloadURL();
  }

  /** Mirrors _uploadToStorage() for the signature PNG, captured as a base64 data URL. */
  async uploadSignature(
    deliveryId: string,
    signatureDataUrl: string,
  ): Promise<string> {
    const path = `pods/${deliveryId}/signature_${Date.now()}.png`;
    const ref = this.storageInstance.ref(path);
    await ref.putString(signatureDataUrl, 'data_url', {
      contentType: 'image/png',
      cacheControl: 'public, max-age=31536000',
    });
    return ref.getDownloadURL();
  }

  /** Mirrors _getCurrentLocation(). Returns undefined on any failure or denied permission. */
  async getCurrentLocation(): Promise<LocationData | undefined> {
    try {
      const permission =
        Platform.OS === 'ios'
          ? PERMISSIONS.IOS.LOCATION_WHEN_IN_USE
          : PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION;
      let status = await check(permission);
      if (status === RESULTS.DENIED) {
        status = await request(permission);
      }
      if (status !== RESULTS.GRANTED && status !== RESULTS.LIMITED) {
        return undefined;
      }

      const position = await new Promise<{
        latitude: number;
        longitude: number;
        accuracy: number;
      }>((resolve, reject) => {
        Geolocation.getCurrentPosition(pos => resolve(pos.coords), reject, {
          enableHighAccuracy: true,
        });
      });

      // NOTE: address is intentionally left blank — the Dart source never reverse-geocodes
      // here either. Real reverse-geocoding lands in Phase 6 (locationRepository.ts).
      return {
        latitude: position.latitude,
        longitude: position.longitude,
        address: '',
        accuracy: position.accuracy,
      };
    } catch {
      return undefined;
    }
  }

  /** Mirrors the OCR-extraction call to ML Kit's text recognizer. */
  async runOcr(imageUri: string): Promise<string> {
    const result = await TextRecognition.recognize(imageUri);
    return result.text;
  }

  /** Mirrors the Firestore write in _submitPOD(): `pods/{deliveryId}`, doc id = deliveryId. */
  async createPod(pod: PodRecord): Promise<void> {
    await this.podsRef().doc(pod.deliveryId).set(podToFirestore(pod));
  }

  async getPodById(deliveryId: string): Promise<PodRecord | null> {
    const doc = await this.podsRef().doc(deliveryId).get();
    return doc.exists() ? podFromFirestore(doc) : null;
  }

  /** Mirrors pod_viewer_screen.dart's `_getPODsStream` (companyId + optional `since` date filter, ordered by timestamp desc). */
  subscribeToCompanyPods(
    companyId: string,
    onChange: (pods: PodRecord[]) => void,
    onError?: (error: Error) => void,
    filters?: { since?: Date },
  ): () => void {
    let query: FirebaseFirestoreTypes.Query = this.podsRef()
      .where('companyId', '==', companyId)
      .orderBy('timestamp', 'desc');
    if (filters?.since) {
      query = query.where(
        'timestamp',
        '>=',
        firestore.Timestamp.fromDate(filters.since),
      );
    }

    let fallbackUnsubscribe: (() => void) | null = null;
    const unsubscribe = query.onSnapshot(
      snapshot => onChange(snapshot.docs.map(podFromFirestore)),
      error => {
        const errorCode = (error as unknown as { code?: string }).code;
        const needsIndexFallback =
          errorCode === 'failed-precondition' ||
          String(error).toLowerCase().includes('index');
        if (!needsIndexFallback) {
          onError?.(error as unknown as Error);
          return;
        }

        // Match the normal query without requiring a deployed company/timestamp index.
        fallbackUnsubscribe = this.podsRef()
          .where('companyId', '==', companyId)
          .onSnapshot(
            snapshot => {
              let pods = snapshot.docs.map(podFromFirestore);
              if (filters?.since)
                pods = pods.filter(pod => pod.timestamp >= filters.since!);
              pods.sort(
                (left, right) =>
                  right.timestamp.getTime() - left.timestamp.getTime(),
              );
              onChange(pods);
            },
            fallbackError => onError?.(fallbackError as unknown as Error),
          );
      },
    );

    return () => {
      unsubscribe();
      fallbackUnsubscribe?.();
    };
  }

  /**
   * Mirrors tryAutoMatchDelivery(): matches on invoiceNumber, then filters by date
   * (±2 days) and branch/site — see class-level deviation note for the collection-path fix.
   */
  async tryAutoMatchDelivery(
    companyId: string,
    fields: OcrFields,
  ): Promise<string | null> {
    try {
      if (!fields.invoiceNo || !fields.documentDate) {
        return null;
      }

      const snapshot = await this.firestoreInstance
        .collection('deliveries')
        .where('companyId', '==', companyId)
        .where('invoiceNumber', '==', fields.invoiceNo)
        .get();

      if (snapshot.docs.length === 0) {
        return null;
      }

      const targetDate = fields.documentDate;
      const deliveries: Delivery[] = snapshot.docs.map(deliveryFromFirestore);

      for (const delivery of deliveries) {
        const daysDiff = Math.abs(
          (delivery.scheduledDate.getTime() - targetDate.getTime()) /
            (1000 * 60 * 60 * 24),
        );
        if (daysDiff > 2) continue;

        const branchMatches =
          (fields.branch != null &&
            delivery.id.toLowerCase().includes(fields.branch.toLowerCase())) ||
          (fields.site != null &&
            delivery.customerAddress
              .toLowerCase()
              .includes(fields.site.toLowerCase()));

        if (branchMatches) {
          return delivery.id;
        }
      }

      return null;
    } catch {
      return null;
    }
  }

  /**
   * Merges OCR-derived data onto the canonical pod doc for DocumentIntake.tsx's review
   * flow. Creates the doc with sensible pending defaults if it doesn't exist yet — does
   * NOT mark the delivery as delivered (that's PodCapture.tsx's job, on real signature
   * + photo + document capture).
   */
  async attachOcrData(params: {
    deliveryId: string;
    companyId: string;
    driverId: string;
    delivery: Delivery;
    ocrRawText: string;
    ocrFields: Record<string, unknown>;
    ocrConfidence: number;
    detectionFlags: PodRecord['detectionFlags'];
  }): Promise<void> {
    const {
      deliveryId,
      companyId,
      driverId,
      delivery,
      ocrRawText,
      ocrFields,
      ocrConfidence,
      detectionFlags,
    } = params;
    const existing = await this.getPodById(deliveryId);

    const pod: PodRecord = existing ?? {
      id: deliveryId,
      companyId,
      driverId,
      deliveryId,
      customerName: delivery.customerName,
      invoiceNumber: delivery.invoiceNumber,
      status: 'pending',
      timestamp: new Date(),
      metadata: {},
      createdAt: new Date(),
    };

    await this.createPod({
      ...pod,
      ocrRawText,
      ocrFields,
      ocrConfidence,
      detectionFlags,
      updatedAt: new Date(),
    });
  }
}
