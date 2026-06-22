import { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import {
  ApprovalLevel,
  Claim,
  ClaimComment,
  ClaimFilingContext,
  ClaimPriority,
  ClaimResolution,
  ClaimStatus,
  ClaimType,
  CustomField,
  CustomFieldType,
  StatusHistoryEntry,
} from './claim';

/**
 * Ported from claim_model.dart's toMap()/fromMap() (verified against source on
 * 2026-06-21). The Flutter model stores all dates as ISO8601 strings, not Firestore
 * Timestamps, while still tolerating legacy documents where a field happens to be a
 * Timestamp (`map['x'] is Timestamp ? ... : DateTime.parse(...)`). This file preserves
 * both behaviors exactly: claimToMap() always writes ISO strings, claimFromMap() accepts
 * either a Firestore Timestamp-like value (anything with a toDate() method) or a string.
 */

const VALID_CLAIM_TYPES: ClaimType[] = [
  'damaged',
  'shortage',
  'shortWeight',
  'missing',
  'wrongItems',
  'returns',
  'priceError',
  'lateDelivery',
  'didNotDeliver',
  'qualityIssue',
  'temperatureIssue',
  'packagingIssue',
  'expiryIssue',
  'serviceIssue',
  'other',
];

const VALID_CLAIM_STATUSES: ClaimStatus[] = [
  'draft',
  'submitted',
  'pendingReview',
  'investigating',
  'pendingDriverResponse',
  'driverResponded',
  'pendingApproval',
  'pendingSecondApproval',
  'pendingProcessing',
  'processing',
  'pendingFinalReview',
  'approved',
  'rejected',
  'resolved',
  'closed',
  'cancelled',
  'disputed',
];

const VALID_CLAIM_PRIORITIES: ClaimPriority[] = ['low', 'medium', 'high', 'urgent'];

const VALID_FILING_CONTEXTS: ClaimFilingContext[] = [
  'atDeliverySite',
  'afterDelivery',
  'systemGenerated',
  'customerPortal',
];

const VALID_RESOLUTIONS: ClaimResolution[] = [
  'creditIssued',
  'debitDriver',
  'refund',
  'replacement',
  'adjustment',
  'noAction',
  'other',
];

const VALID_CUSTOM_FIELD_TYPES: CustomFieldType[] = [
  'text',
  'number',
  'date',
  'dropdown',
  'checkbox',
  'photo',
  'signature',
  'file',
];

function enumOrDefault<T extends string>(value: unknown, valid: T[], fallback: T): T {
  return valid.includes(value as T) ? (value as T) : fallback;
}

/** Mirrors the `map['x'] is Timestamp ? ... .toDate() : DateTime.parse(map['x'])` pattern. */
function parseDate(value: unknown): Date | undefined {
  if (value === null || value === undefined) {
    return undefined;
  }
  if (typeof value === 'object' && value !== null && typeof (value as { toDate?: unknown }).toDate === 'function') {
    return (value as FirebaseFirestoreTypes.Timestamp).toDate();
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? undefined : parsed;
  }
  return undefined;
}

function parseDateOr(value: unknown, fallback: () => Date): Date {
  return parseDate(value) ?? fallback();
}

function customFieldFromMap(map: Record<string, unknown>): CustomField {
  return {
    id: (map.id as string) ?? '',
    label: (map.label as string) ?? '',
    type: enumOrDefault(map.type, VALID_CUSTOM_FIELD_TYPES, 'text'),
    required: (map.required as boolean) ?? false,
    dropdownOptions: map.dropdownOptions != null ? ([...(map.dropdownOptions as string[])]) : undefined,
    placeholder: map.placeholder as string | undefined,
    validationRegex: map.validationRegex as string | undefined,
    value: map.value,
  };
}

function customFieldToMap(field: CustomField): Record<string, unknown> {
  return {
    id: field.id,
    label: field.label,
    type: field.type,
    required: field.required,
    dropdownOptions: field.dropdownOptions ?? null,
    placeholder: field.placeholder ?? null,
    validationRegex: field.validationRegex ?? null,
    value: field.value ?? null,
  };
}

function approvalLevelFromMap(map: Record<string, unknown>): ApprovalLevel {
  return {
    role: (map.role as string) ?? '',
    userId: map.userId as string | undefined,
    userName: map.userName as string | undefined,
    actionDate: parseDate(map.actionDate),
    notes: map.notes as string | undefined,
    approved: (map.approved as boolean) ?? false,
    signatureUrl: map.signatureUrl as string | undefined,
    slaHours: (map.slaHours as number) ?? 24,
  };
}

function approvalLevelToMap(level: ApprovalLevel): Record<string, unknown> {
  return {
    role: level.role,
    userId: level.userId ?? null,
    userName: level.userName ?? null,
    actionDate: level.actionDate ? level.actionDate.toISOString() : null,
    notes: level.notes ?? null,
    approved: level.approved,
    signatureUrl: level.signatureUrl ?? null,
    slaHours: level.slaHours,
  };
}

function statusHistoryEntryFromMap(map: Record<string, unknown>): StatusHistoryEntry {
  return {
    status: enumOrDefault(map.status, VALID_CLAIM_STATUSES, 'submitted'),
    timestamp: parseDateOr(map.timestamp, () => new Date()),
    userId: (map.userId as string) ?? '',
    userName: (map.userName as string) ?? '',
    notes: map.notes as string | undefined,
    metadata: map.metadata as Record<string, unknown> | undefined,
  };
}

function statusHistoryEntryToMap(entry: StatusHistoryEntry): Record<string, unknown> {
  return {
    status: entry.status,
    timestamp: entry.timestamp.toISOString(),
    userId: entry.userId,
    userName: entry.userName,
    notes: entry.notes ?? null,
    metadata: entry.metadata ?? null,
  };
}

function claimCommentFromMap(map: Record<string, unknown>): ClaimComment {
  return {
    id: (map.id as string) ?? '',
    userId: (map.userId as string) ?? '',
    userName: (map.userName as string) ?? '',
    userRole: (map.userRole as string) ?? '',
    comment: (map.comment as string) ?? '',
    timestamp: parseDateOr(map.timestamp, () => new Date()),
    attachmentUrls: map.attachmentUrls ? [...(map.attachmentUrls as string[])] : [],
    isInternal: (map.isInternal as boolean) ?? false,
  };
}

function claimCommentToMap(comment: ClaimComment): Record<string, unknown> {
  return {
    id: comment.id,
    userId: comment.userId,
    userName: comment.userName,
    userRole: comment.userRole,
    comment: comment.comment,
    timestamp: comment.timestamp.toISOString(),
    attachmentUrls: comment.attachmentUrls,
    isInternal: comment.isInternal,
  };
}

/** Mirrors Claim.fromMap(). `map` is a plain object (already includes `id` if from Firestore). */
export function claimFromMap(map: Record<string, unknown>): Claim {
  return {
    id: (map.id as string) ?? '',
    companyId: (map.companyId as string) ?? '',
    type: enumOrDefault(map.type, VALID_CLAIM_TYPES, 'other'),
    status: enumOrDefault(map.status, VALID_CLAIM_STATUSES, 'submitted'),
    priority: enumOrDefault(map.priority, VALID_CLAIM_PRIORITIES, 'medium'),
    filingContext: enumOrDefault(map.filingContext, VALID_FILING_CONTEXTS, 'afterDelivery'),
    title: (map.title as string) ?? '',
    description: (map.description as string) ?? '',
    deliveryId: (map.deliveryId as string) ?? '',
    podId: map.podId as string | undefined,
    customerId: (map.customerId as string) ?? '',
    customerName: (map.customerName as string) ?? '',
    customerNumber: map.customerNumber as string | undefined,
    customerAccountNumber: map.customerAccountNumber as string | undefined,
    driverId: (map.driverId as string) ?? '',
    driverName: (map.driverName as string) ?? '',
    invoiceNumber: map.invoiceNumber as string | undefined,
    claimAmount: map.claimAmount != null ? Number(map.claimAmount) : undefined,
    creditNoteNumber: map.creditNoteNumber as string | undefined,
    debitNoteNumber: map.debitNoteNumber as string | undefined,
    createdAt: parseDateOr(map.createdAt, () => new Date()),
    updatedAt: parseDateOr(map.updatedAt, () => new Date()),
    resolvedAt: parseDate(map.resolvedAt),
    dueDate: parseDate(map.dueDate),
    deliveryDate: parseDateOr(map.deliveryDate, () => new Date()),
    filedBy: (map.filedBy as string) ?? '',
    filedByName: (map.filedByName as string) ?? '',
    filedByRole: (map.filedByRole as string) ?? '',
    photoUrls: map.photoUrls ? [...(map.photoUrls as string[])] : [],
    customerSignatureUrl: map.customerSignatureUrl as string | undefined,
    driverSignatureUrl: map.driverSignatureUrl as string | undefined,
    gpsLocation: (map.gpsLocation as Record<string, unknown>) ?? {},
    metadata: (map.metadata as Record<string, unknown>) ?? {},
    documentUrls: map.documentUrls ? [...(map.documentUrls as string[])] : [],
    documentMetadata: map.documentMetadata
      ? (map.documentMetadata as Record<string, unknown>[]).map(d => ({ ...d }))
      : [],
    approvalChain: map.approvalChain
      ? (map.approvalChain as Record<string, unknown>[]).map(approvalLevelFromMap)
      : [],
    currentApprovalLevel: (map.currentApprovalLevel as number) ?? 0,
    customerAcknowledged: map.customerAcknowledged as boolean | undefined,
    filedAtDelivery: parseDate(map.filedAtDelivery),
    driverNotified: map.driverNotified as boolean | undefined,
    driverResponded: map.driverResponded as boolean | undefined,
    driverResponse: map.driverResponse as string | undefined,
    driverEvidenceUrls: map.driverEvidenceUrls ? [...(map.driverEvidenceUrls as string[])] : [],
    daysAfterDelivery: map.daysAfterDelivery as number | undefined,
    affectedItems: map.affectedItems
      ? (map.affectedItems as Record<string, unknown>[]).map(i => ({ ...i }))
      : [],
    investigatedBy: map.investigatedBy as string | undefined,
    investigatorName: map.investigatorName as string | undefined,
    investigationNotes: map.investigationNotes as string | undefined,
    investigationDate: parseDate(map.investigationDate),
    resolution: map.resolution != null ? enumOrDefault(map.resolution, VALID_RESOLUTIONS, 'other') : undefined,
    resolutionNotes: map.resolutionNotes as string | undefined,
    resolvedBy: map.resolvedBy as string | undefined,
    resolvedByName: map.resolvedByName as string | undefined,
    evidenceQualityScore: (map.evidenceQualityScore as number) ?? 5,
    hasAllRequiredEvidence: (map.hasAllRequiredEvidence as boolean) ?? false,
    comments: Array.isArray(map.comments) ? (map.comments as Record<string, unknown>[]).map(claimCommentFromMap) : [],
    statusHistory: Array.isArray(map.statusHistory)
      ? (map.statusHistory as Record<string, unknown>[]).map(statusHistoryEntryFromMap)
      : [],
    customFields: Array.isArray(map.customFields)
      ? (map.customFields as Record<string, unknown>[]).map(customFieldFromMap)
      : [],
    externalSystemId: map.externalSystemId as string | undefined,
    externalSystemData: map.externalSystemData as Record<string, unknown> | undefined,
    isFraudulent: (map.isFraudulent as boolean) ?? false,
    isEscalated: (map.isEscalated as boolean) ?? false,
    isRecurring: (map.isRecurring as boolean) ?? false,
    recurringClaimGroupId: map.recurringClaimGroupId as string | undefined,
    evidenceStatus: (map.evidenceStatus as string) ?? 'pending',
    evidenceReceivedAt: parseDate(map.evidenceReceivedAt),
    photoCount: (map.photoCount as number) ?? 0,
    hasSignature: (map.hasSignature as boolean) ?? false,
    hasDocuments: (map.hasDocuments as boolean) ?? false,
  };
}

/** Mirrors Claim.toMap(). Dates are always serialized as ISO8601 strings (not Timestamps). */
export function claimToMap(claim: Claim): Record<string, unknown> {
  return {
    id: claim.id,
    companyId: claim.companyId,
    type: claim.type,
    status: claim.status,
    priority: claim.priority,
    filingContext: claim.filingContext,
    title: claim.title,
    description: claim.description,
    deliveryId: claim.deliveryId,
    podId: claim.podId ?? null,
    customerId: claim.customerId,
    customerName: claim.customerName,
    customerNumber: claim.customerNumber ?? null,
    customerAccountNumber: claim.customerAccountNumber ?? null,
    driverId: claim.driverId,
    driverName: claim.driverName,
    invoiceNumber: claim.invoiceNumber ?? null,
    claimAmount: claim.claimAmount ?? null,
    creditNoteNumber: claim.creditNoteNumber ?? null,
    debitNoteNumber: claim.debitNoteNumber ?? null,
    createdAt: claim.createdAt.toISOString(),
    updatedAt: claim.updatedAt.toISOString(),
    resolvedAt: claim.resolvedAt ? claim.resolvedAt.toISOString() : null,
    dueDate: claim.dueDate ? claim.dueDate.toISOString() : null,
    deliveryDate: claim.deliveryDate.toISOString(),
    filedBy: claim.filedBy,
    filedByName: claim.filedByName,
    filedByRole: claim.filedByRole,
    photoUrls: claim.photoUrls,
    customerSignatureUrl: claim.customerSignatureUrl ?? null,
    driverSignatureUrl: claim.driverSignatureUrl ?? null,
    gpsLocation: claim.gpsLocation,
    metadata: claim.metadata,
    documentUrls: claim.documentUrls,
    documentMetadata: claim.documentMetadata,
    approvalChain: claim.approvalChain.map(approvalLevelToMap),
    currentApprovalLevel: claim.currentApprovalLevel,
    customerAcknowledged: claim.customerAcknowledged ?? null,
    filedAtDelivery: claim.filedAtDelivery ? claim.filedAtDelivery.toISOString() : null,
    driverNotified: claim.driverNotified ?? null,
    driverResponded: claim.driverResponded ?? null,
    driverResponse: claim.driverResponse ?? null,
    driverEvidenceUrls: claim.driverEvidenceUrls,
    daysAfterDelivery: claim.daysAfterDelivery ?? null,
    affectedItems: claim.affectedItems,
    investigatedBy: claim.investigatedBy ?? null,
    investigatorName: claim.investigatorName ?? null,
    investigationNotes: claim.investigationNotes ?? null,
    investigationDate: claim.investigationDate ? claim.investigationDate.toISOString() : null,
    resolution: claim.resolution ?? null,
    resolutionNotes: claim.resolutionNotes ?? null,
    resolvedBy: claim.resolvedBy ?? null,
    resolvedByName: claim.resolvedByName ?? null,
    evidenceQualityScore: claim.evidenceQualityScore,
    hasAllRequiredEvidence: claim.hasAllRequiredEvidence,
    comments: claim.comments.map(claimCommentToMap),
    statusHistory: claim.statusHistory.map(statusHistoryEntryToMap),
    customFields: claim.customFields.map(customFieldToMap),
    externalSystemId: claim.externalSystemId ?? null,
    externalSystemData: claim.externalSystemData ?? null,
    isFraudulent: claim.isFraudulent,
    isEscalated: claim.isEscalated,
    isRecurring: claim.isRecurring,
    recurringClaimGroupId: claim.recurringClaimGroupId ?? null,
    evidenceStatus: claim.evidenceStatus,
    evidenceReceivedAt: claim.evidenceReceivedAt ? claim.evidenceReceivedAt.toISOString() : null,
    photoCount: claim.photoCount,
    hasSignature: claim.hasSignature,
    hasDocuments: claim.hasDocuments,
  };
}

/** Mirrors Claim.fromFirestore(doc). */
export function claimFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): Claim {
  const data = doc.data() ?? {};
  return claimFromMap({ ...data, id: doc.id });
}
