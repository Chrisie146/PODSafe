/**
 * Ported from lib/models/pod_model.dart (verified against source on 2026-06-22).
 *
 * Per the migration plan's Section 4 (Dual-POD Architecture Decision): this is the
 * SINGLE canonical POD shape (top-level `pods/{deliveryId}`). The other, abandoned
 * pipeline (lib/models/ocr_fields_model.dart's OcrFields/DetectionFlags/PodDocument,
 * writing to `companies/{companyId}/pods/{podId}`) is NOT ported as a separate
 * collection — its useful field structure is merged in here instead:
 * - OcrFields is already representable via PODRecord's existing ocrFields: Map field
 *   (OcrFields.toJson() shape) — no new type needed for that.
 * - DetectionFlags (hasSignature/hasStamp/ocrConfident/warnings/ocrConfidenceScore) is
 *   genuinely new and is added below as an embedded, optional `detectionFlags` field
 *   (not present on the Dart PODRecord — this is the "merge as embedded sub-object"
 *   the plan calls for). Written by DocumentIntake.tsx; PodCapture.tsx doesn't set it.
 */

export type PodStatus = 'pending' | 'signed' | 'missing';

export interface LocationData {
  latitude: number;
  longitude: number;
  address: string;
  accuracy?: number;
}

export interface DocumentMetadataEntry {
  type: string;
  timestamp: string;
}

/** New embedded sub-object — see file-level comment. Not present in the Dart model. */
export interface PodDetectionFlags {
  hasSignature: boolean;
  hasStamp: boolean;
  ocrConfident: boolean;
  warnings: string[];
  ocrConfidenceScore: number;
}

export interface PodRecord {
  id: string;
  companyId: string;
  driverId: string;
  deliveryId: string;
  customerName: string;
  invoiceNumber: string;
  status: PodStatus;
  timestamp: Date;
  location?: LocationData;
  signedBy?: string;
  signatureUrl?: string;
  photoUrl?: string;
  photoUrls?: string[];
  documentUrls?: string[];
  documentMetadata?: DocumentMetadataEntry[];
  pdfUrl?: string;
  metadata: Record<string, unknown>;
  createdAt: Date;
  updatedAt?: Date;

  ocrRawText?: string;
  ocrFields?: Record<string, unknown>;
  ocrConfidence?: number;
  detectionFlags?: PodDetectionFlags;
}
