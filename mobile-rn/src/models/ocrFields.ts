/**
 * Ported from OcrFields in lib/models/ocr_fields_model.dart (verified against source on
 * 2026-06-22). DetectionFlags and PodDocument from the same Dart file are NOT ported —
 * see the file-level comment in models/pod.ts for the Section 4 consolidation decision
 * (DetectionFlags lives on PodRecord.detectionFlags instead; PodDocument's collection is
 * abandoned entirely).
 */
export interface OcrFields {
  supplier?: string;
  customer?: string;
  invoiceNo?: string;
  documentDate?: Date;
  branch?: string;
  site?: string;
  vatNo?: string;
  totalExcl?: number;
  totalVat?: number;
  totalIncl?: number;
  totalMassKg?: number;
  totalQty?: number;
  truckReg?: string;
  driverName?: string;
  receivedBy?: string;
  ocrRawText?: string;
}

/** Mirrors OcrFields.toJson(). */
export function ocrFieldsToJson(fields: OcrFields): Record<string, unknown> {
  return {
    supplier: fields.supplier ?? null,
    customer: fields.customer ?? null,
    invoiceNo: fields.invoiceNo ?? null,
    documentDate: fields.documentDate?.toISOString() ?? null,
    branch: fields.branch ?? null,
    site: fields.site ?? null,
    vatNo: fields.vatNo ?? null,
    totalExcl: fields.totalExcl ?? null,
    totalVat: fields.totalVat ?? null,
    totalIncl: fields.totalIncl ?? null,
    totalMassKg: fields.totalMassKg ?? null,
    totalQty: fields.totalQty ?? null,
    truckReg: fields.truckReg ?? null,
    driverName: fields.driverName ?? null,
    receivedBy: fields.receivedBy ?? null,
    ocrRawText: fields.ocrRawText ?? null,
  };
}
