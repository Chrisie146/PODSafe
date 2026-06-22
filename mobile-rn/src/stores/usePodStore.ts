import { create } from 'zustand';
import { Delivery } from '../models/delivery';
import { DocumentMetadataEntry, LocationData, PodDetectionFlags, PodRecord } from '../models/pod';
import { OcrFields, ocrFieldsToJson } from '../models/ocrFields';
import { PodRepository } from '../repositories/podRepository';
import { PodTokenRepository, PodAccessToken } from '../repositories/podTokenRepository';
import { OcrParser } from '../repositories/ocrParser';
import { DeliveryRepository } from '../repositories/deliveryRepository';

/**
 * Replaces lib/providers/pod_provider.dart (POD viewer/listing, not yet ported — Phase 3)
 * and lib/services/pod_controller.dart's PodController, merged into one store per the
 * migration plan's Section 4 (one canonical POD pipeline, one store).
 *
 * Two distinct slices, matching the two screens that consume this store:
 * - PodCapture.tsx (the primary capture flow) keeps its own local component state for
 *   the multi-photo/document/signature/notes form fields (pod_capture_screen.dart never
 *   used a controller either — it's plain widget State), and calls the thin action
 *   wrappers below (uploadPhoto/uploadDocument/uploadStampPhoto/uploadSignature/
 *   getCurrentLocation/runOcr/submitPod) directly. This mirrors the pattern already
 *   established in ReportIssue.tsx for form-heavy screens.
 * - DocumentIntake.tsx uses the `intake*` state-machine slice below, which IS a faithful
 *   port of PodController's PodState enum + fields (captureFromCamera/pickFromGallery/
 *   parseOcrText/uploadIntakeDocument/resetIntake).
 */

const podRepository = new PodRepository();
const podTokenRepository = new PodTokenRepository();
const deliveryRepository = new DeliveryRepository();
const ocrParser = new OcrParser();

export type PodCaptureState = 'idle' | 'capturing' | 'parsingOcr' | 'ready' | 'uploading' | 'success' | 'error';

interface SubmitPodParams {
  delivery: Delivery;
  driverId: string;
  companyId: string;
  signatureDataUrl: string;
  receiverName: string;
  notes: string;
  photoUris: string[];
  documents: Array<{ uri: string; type: string }>;
  stampPhotoUri?: string;
  ocrRawText?: string;
  ocrFields?: Record<string, unknown>;
  ocrConfidence?: number;
}

interface PodState {
  // --- PodCapture.tsx thin action wrappers ---
  uploadPhoto: (deliveryId: string, index: number, fileUri: string) => Promise<string>;
  uploadDocument: (deliveryId: string, index: number, fileUri: string) => Promise<string>;
  uploadStampPhoto: (deliveryId: string, fileUri: string) => Promise<string>;
  getCurrentLocation: () => Promise<LocationData | undefined>;
  runOcr: (imageUri: string) => Promise<string>;
  parseOcrFields: (text: string) => OcrFields;
  submitPod: (params: SubmitPodParams) => Promise<string>;
  getAccessToken: (deliveryId: string) => Promise<PodAccessToken | null>;

  // --- DocumentIntake.tsx state machine (ports PodController/PodState) ---
  intakeState: PodCaptureState;
  intakeErrorMessage: string | null;
  capturedImageUri: string | null;
  intakeOcrFields: OcrFields | null;
  intakeDetectionFlags: PodDetectionFlags | null;
  matchedDeliveryId: string | null;

  setCapturedImage: (uri: string) => void;
  parseIntakeOcrText: (ocrText: string) => void;
  uploadIntakeDocument: (params: { companyId: string; driverId: string; delivery: Delivery | null }) => Promise<void>;
  resetIntake: () => void;
}

/** Mirrors PodController._detectSignature(). */
function detectSignature(text: string): boolean {
  const lower = text.toLowerCase();
  return lower.includes('signature') || lower.includes('signed') || lower.includes('signed by');
}

/** Mirrors PodController._detectStamp(). */
function detectStamp(text: string): boolean {
  const lower = text.toLowerCase();
  return lower.includes('stamp') || lower.includes('received') || lower.includes('approved');
}

/** Mirrors PodController._validateOcr(). */
function validateOcr(fields: OcrFields): string[] {
  const warnings: string[] = [];
  if (!fields.invoiceNo) warnings.push('Invoice number not found');
  if (fields.totalIncl == null) warnings.push('Total amount not found');

  if (!fields.documentDate) {
    warnings.push('Document date not found');
  } else {
    const now = new Date();
    const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const oneYearAgo = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
    if (fields.documentDate > oneDayFromNow) {
      warnings.push('Document date is in the future');
    } else if (fields.documentDate < oneYearAgo) {
      warnings.push('Document date is older than 1 year');
    }
  }

  if (fields.totalExcl != null && fields.totalVat != null && fields.totalIncl != null) {
    if (Math.abs(fields.totalExcl + fields.totalVat - fields.totalIncl) > 1.0) {
      warnings.push('Totals mismatch: Excl + VAT ≠ Incl');
    }
  }

  return warnings;
}

export const usePodStore = create<PodState>((set, get) => ({
  uploadPhoto: (deliveryId, index, fileUri) =>
    podRepository.uploadFile(`pods/${deliveryId}/photos/photo_${index}${Date.now()}.jpg`, fileUri),

  uploadDocument: (deliveryId, index, fileUri) =>
    podRepository.uploadFile(`pods/${deliveryId}/documents/doc_${index}${Date.now()}.jpg`, fileUri),

  uploadStampPhoto: (deliveryId, fileUri) => podRepository.uploadFile(`pods/${deliveryId}/stamp_photo_${Date.now()}.jpg`, fileUri),

  getCurrentLocation: () => podRepository.getCurrentLocation(),

  runOcr: (imageUri) => podRepository.runOcr(imageUri),

  parseOcrFields: (text) => ocrParser.parseText(text),

  submitPod: async (params) => {
    const { delivery, driverId, companyId, signatureDataUrl, receiverName, notes, photoUris, documents, stampPhotoUri } = params;

    const location = await podRepository.getCurrentLocation();
    const signatureUrl = await podRepository.uploadSignature(delivery.id, signatureDataUrl);

    const photoUrls: string[] = [];
    for (let i = 0; i < photoUris.length; i++) {
      photoUrls.push(await get().uploadPhoto(delivery.id, i, photoUris[i]));
    }

    const documentUrls: string[] = [];
    const documentMetadata: DocumentMetadataEntry[] = [];
    for (let i = 0; i < documents.length; i++) {
      documentUrls.push(await get().uploadDocument(delivery.id, i, documents[i].uri));
      documentMetadata.push({ type: documents[i].type, timestamp: new Date().toISOString() });
    }

    const stampPhotoUrl = stampPhotoUri ? await get().uploadStampPhoto(delivery.id, stampPhotoUri) : undefined;

    const pod: PodRecord = {
      id: delivery.id,
      companyId,
      driverId,
      deliveryId: delivery.id,
      customerName: delivery.customerName,
      invoiceNumber: delivery.invoiceNumber,
      status: 'signed',
      timestamp: new Date(),
      location,
      signedBy: receiverName,
      signatureUrl,
      photoUrl: photoUrls[0],
      photoUrls,
      documentUrls,
      documentMetadata,
      pdfUrl: undefined,
      metadata: { receiverName, notes, customerNumber: delivery.customerNumber, orderNumber: delivery.orderNumber, customerAddress: delivery.customerAddress, stampPhotoUrl },
      createdAt: new Date(),
      ocrRawText: params.ocrRawText,
      ocrFields: params.ocrFields,
      ocrConfidence: params.ocrConfidence,
    };

    await podRepository.createPod(pod);
    await deliveryRepository.linkPODToDelivery(delivery.id, delivery.id);

    podTokenRepository.createToken(delivery.id, 90).catch(() => {
      // Fire-and-forget, mirrors the Dart source's Future.microtask swallow-on-failure.
    });

    return delivery.id;
  },

  getAccessToken: (deliveryId) => podTokenRepository.getTokenByDeliveryId(deliveryId),

  intakeState: 'idle',
  intakeErrorMessage: null,
  capturedImageUri: null,
  intakeOcrFields: null,
  intakeDetectionFlags: null,
  matchedDeliveryId: null,

  setCapturedImage: (uri) => set({ capturedImageUri: uri, intakeState: 'ready', intakeErrorMessage: null }),

  parseIntakeOcrText: (ocrText) => {
    set({ intakeState: 'parsingOcr' });
    try {
      const fields = ocrParser.parseText(ocrText);
      const flags: PodDetectionFlags = {
        hasSignature: detectSignature(ocrText),
        hasStamp: detectStamp(ocrText),
        ocrConfident: ocrText.length > 0,
        warnings: validateOcr(fields),
        ocrConfidenceScore: 0.75,
      };
      set({ intakeOcrFields: fields, intakeDetectionFlags: flags, intakeState: 'ready' });
    } catch (e) {
      set({ intakeState: 'error', intakeErrorMessage: `Failed to parse OCR: ${(e as Error).message}` });
    }
  },

  uploadIntakeDocument: async ({ companyId, driverId, delivery }) => {
    const { capturedImageUri, intakeOcrFields, intakeDetectionFlags } = get();
    if (!capturedImageUri || !intakeOcrFields || !intakeDetectionFlags) {
      set({ intakeState: 'error', intakeErrorMessage: 'Missing image or OCR data' });
      return;
    }

    set({ intakeState: 'uploading', intakeErrorMessage: null });
    try {
      const matchedDeliveryId = delivery?.id ?? (await podRepository.tryAutoMatchDelivery(companyId, intakeOcrFields));

      if (!matchedDeliveryId) {
        set({
          intakeState: 'error',
          intakeErrorMessage: 'Could not match this document to a delivery. Open Document Intake from a specific delivery to link it manually.',
        });
        return;
      }

      const targetDelivery = delivery ?? (await deliveryRepository.getDeliveryById(matchedDeliveryId));
      if (!targetDelivery) {
        set({ intakeState: 'error', intakeErrorMessage: 'Matched delivery could not be loaded' });
        return;
      }

      await podRepository.attachOcrData({
        deliveryId: matchedDeliveryId,
        companyId,
        driverId,
        delivery: targetDelivery,
        ocrRawText: intakeOcrFields.ocrRawText ?? '',
        ocrFields: ocrFieldsToJson(intakeOcrFields),
        ocrConfidence: intakeDetectionFlags.ocrConfidenceScore,
        detectionFlags: intakeDetectionFlags,
      });

      set({ matchedDeliveryId, intakeState: 'success' });
    } catch (e) {
      set({ intakeState: 'error', intakeErrorMessage: `Failed to upload POD: ${(e as Error).message}` });
    }
  },

  resetIntake: () =>
    set({
      intakeState: 'idle',
      intakeErrorMessage: null,
      capturedImageUri: null,
      intakeOcrFields: null,
      intakeDetectionFlags: null,
      matchedDeliveryId: null,
    }),
}));
