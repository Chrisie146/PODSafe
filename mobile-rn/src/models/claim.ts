/**
 * Ported from lib/models/claim_model.dart (verified against source on 2026-06-21).
 *
 * IMPORTANT: Claim dates are stored as ISO strings in Firestore (toMap/fromMap in the
 * Flutter model), NOT as Firestore Timestamps — claim.converters.ts preserves that exact
 * behavior so this stays read/write compatible with existing Firestore documents. Do not
 * "fix" this to use Timestamp.fromDate/toDate the way user.converters.ts does.
 */

/** Configurable claim types - companies can enable/disable as needed. */
export type ClaimType =
  | 'damaged' // Damaged goods
  | 'shortage' // Short delivered (quantity)
  | 'shortWeight' // Short weight (weight discrepancy)
  | 'missing' // Missing items
  | 'wrongItems' // Wrong products delivered
  | 'returns' // Customer returns stock
  | 'priceError' // Pricing discrepancies
  | 'lateDelivery' // Delivery was late
  | 'didNotDeliver' // Driver couldn't complete delivery
  | 'qualityIssue' // Product quality problem
  | 'temperatureIssue' // Cold chain breach
  | 'packagingIssue' // Packaging damaged/incorrect
  | 'expiryIssue' // Expiry date problem
  | 'serviceIssue' // Service quality issue
  | 'other'; // Custom/other

export const ALL_CLAIM_TYPES: ClaimType[] = [
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

/** Claim status through its lifecycle. */
export type ClaimStatus =
  | 'draft' // Being created, not submitted
  | 'submitted' // Filed, awaiting assignment
  | 'pendingReview' // Assigned, awaiting initial review
  | 'investigating' // Under investigation
  | 'pendingDriverResponse' // Waiting for driver to respond
  | 'driverResponded' // Driver has responded
  | 'pendingApproval' // Awaiting manager/approver decision
  | 'pendingSecondApproval' // Multiple approval levels
  | 'pendingProcessing' // Approved, awaiting processing (credit note, etc.)
  | 'processing' // Being processed
  | 'pendingFinalReview' // Final review before closure
  | 'approved' // Claim approved
  | 'rejected' // Claim rejected
  | 'resolved' // Resolved/completed
  | 'closed' // Closed and archived
  | 'cancelled' // Cancelled by submitter
  | 'disputed'; // Customer/driver disputes decision

export const ALL_CLAIM_STATUSES: ClaimStatus[] = [
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

/** Priority levels. */
export type ClaimPriority = 'low' | 'medium' | 'high' | 'urgent';

/** How the claim was filed. */
export type ClaimFilingContext =
  | 'atDeliverySite' // Filed by driver at customer location (immediate)
  | 'afterDelivery' // Filed later (delayed - admin or driver)
  | 'systemGenerated' // Auto-created by system
  | 'customerPortal'; // Filed by customer through portal

/** Resolution type. */
export type ClaimResolution =
  | 'creditIssued' // Credit note issued to customer
  | 'debitDriver' // Driver charged/invoiced
  | 'refund' // Refund issued
  | 'replacement' // Replacement delivery scheduled
  | 'adjustment' // Price adjustment
  | 'noAction' // No action taken
  | 'other'; // Custom resolution

/** Custom field types for flexible data collection. */
export type CustomFieldType =
  | 'text'
  | 'number'
  | 'date'
  | 'dropdown'
  | 'checkbox'
  | 'photo'
  | 'signature'
  | 'file';

/** Custom field definition (value attached to a specific claim). */
export interface CustomField {
  id: string;
  label: string;
  type: CustomFieldType;
  required: boolean;
  dropdownOptions?: string[];
  placeholder?: string;
  validationRegex?: string;
  value?: unknown;
}

/** Approval level in workflow. */
export interface ApprovalLevel {
  role: string; // 'manager', 'approver', 'processor', etc.
  userId?: string; // Specific user if assigned
  userName?: string;
  actionDate?: Date;
  notes?: string;
  approved: boolean;
  signatureUrl?: string;
  slaHours: number; // SLA for this level
}

/** Status history entry for audit trail. */
export interface StatusHistoryEntry {
  status: ClaimStatus;
  timestamp: Date;
  userId: string;
  userName: string;
  notes?: string;
  metadata?: Record<string, unknown>;
}

/** Comment on a claim. */
export interface ClaimComment {
  id: string;
  userId: string;
  userName: string;
  userRole: string;
  comment: string;
  timestamp: Date;
  attachmentUrls: string[];
  isInternal: boolean; // Internal notes vs customer-visible
}

/** Main Claim model - flexible and configurable. */
export interface Claim {
  id: string;
  companyId: string;

  // Basic claim info
  type: ClaimType;
  status: ClaimStatus;
  priority: ClaimPriority;
  filingContext: ClaimFilingContext;
  title: string;
  description: string;

  // Related entities
  deliveryId: string;
  podId?: string;
  customerId: string;
  customerName: string;
  customerNumber?: string; // Customer number (e.g., BOX001, ACME999)
  customerAccountNumber?: string;
  driverId: string;
  driverName: string;

  // Financial
  invoiceNumber?: string;
  claimAmount?: number;
  creditNoteNumber?: string;
  debitNoteNumber?: string;

  // Dates
  createdAt: Date;
  updatedAt: Date;
  resolvedAt?: Date;
  dueDate?: Date;
  deliveryDate: Date;

  // Filed by
  filedBy: string;
  filedByName: string;
  filedByRole: string;

  // Evidence (flexible for different claim types)
  photoUrls: string[];
  customerSignatureUrl?: string;
  driverSignatureUrl?: string;
  gpsLocation: Record<string, unknown>;
  metadata: Record<string, unknown>; // Flexible key-value storage

  // Scanned documents
  documentUrls: string[];
  documentMetadata: Record<string, unknown>[]; // Metadata like type, uploadedBy, uploadedAt

  // Approval workflow
  approvalChain: ApprovalLevel[];
  currentApprovalLevel: number;

  // For immediate claims (at delivery site)
  customerAcknowledged?: boolean;
  filedAtDelivery?: Date;

  // For delayed claims (after delivery)
  driverNotified?: boolean;
  driverResponded?: boolean;
  driverResponse?: string;
  driverEvidenceUrls: string[];
  daysAfterDelivery?: number;

  // Items affected
  affectedItems: Record<string, unknown>[];

  // Investigation
  investigatedBy?: string;
  investigatorName?: string;
  investigationNotes?: string;
  investigationDate?: Date;

  // Resolution
  resolution?: ClaimResolution;
  resolutionNotes?: string;
  resolvedBy?: string;
  resolvedByName?: string;

  // Quality metrics
  evidenceQualityScore: number; // 1-10
  hasAllRequiredEvidence: boolean;

  // Comments and history
  comments: ClaimComment[];
  statusHistory: StatusHistoryEntry[];

  // Custom fields (company-specific)
  customFields: CustomField[];

  // Integration
  externalSystemId?: string;
  externalSystemData?: Record<string, unknown>;

  // Flags
  isFraudulent: boolean;
  isEscalated: boolean;
  isRecurring: boolean; // Pattern detection
  recurringClaimGroupId?: string;

  // Evidence tracking (for delayed evidence submission)
  evidenceStatus: string; // pending, received, complete
  evidenceReceivedAt?: Date;
  photoCount: number; // Number of photos attached
  hasSignature: boolean; // Has signature?
  hasDocuments: boolean; // Has documents?
}

/** Helper: Get status display text. Ported from Claim.statusDisplayText. */
export function claimStatusDisplayText(status: ClaimStatus): string {
  switch (status) {
    case 'draft':
      return 'Draft';
    case 'submitted':
      return 'Submitted';
    case 'pendingReview':
      return 'Pending Review';
    case 'investigating':
      return 'Investigating';
    case 'pendingDriverResponse':
      return 'Awaiting Driver Response';
    case 'driverResponded':
      return 'Driver Responded';
    case 'pendingApproval':
      return 'Pending Approval';
    case 'pendingSecondApproval':
      return 'Pending Final Approval';
    case 'pendingProcessing':
      return 'Pending Processing';
    case 'processing':
      return 'Processing';
    case 'pendingFinalReview':
      return 'Pending Final Review';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'resolved':
      return 'Resolved';
    case 'closed':
      return 'Closed';
    case 'cancelled':
      return 'Cancelled';
    case 'disputed':
      return 'Disputed';
  }
}

/** Helper: Get type display text. Ported from Claim.typeDisplayText. */
export function claimTypeDisplayText(type: ClaimType): string {
  switch (type) {
    case 'damaged':
      return 'Damaged Goods';
    case 'shortage':
      return 'Short Delivered';
    case 'shortWeight':
      return 'Short Weight';
    case 'missing':
      return 'Missing Items';
    case 'wrongItems':
      return 'Wrong Items';
    case 'returns':
      return 'Returns';
    case 'priceError':
      return 'Price Error';
    case 'lateDelivery':
      return 'Late Delivery';
    case 'didNotDeliver':
      return 'Did Not Deliver';
    case 'qualityIssue':
      return 'Quality Issue';
    case 'temperatureIssue':
      return 'Temperature Issue';
    case 'packagingIssue':
      return 'Packaging Issue';
    case 'expiryIssue':
      return 'Expiry Issue';
    case 'serviceIssue':
      return 'Service Issue';
    case 'other':
      return 'Other';
  }
}

/** Helper: Is SLA breached? Ported from Claim.isSlaBreached. */
export function isClaimSlaBreached(claim: Claim): boolean {
  if (!claim.dueDate) {
    return false;
  }
  return new Date() > claim.dueDate;
}

/** Helper: Days since filed. Ported from Claim.daysSinceFiled. */
export function daysSinceClaimFiled(claim: Claim): number {
  const diffMs = new Date().getTime() - claim.createdAt.getTime();
  return Math.floor(diffMs / (1000 * 60 * 60 * 24));
}

const PENDING_ACTION_STATUSES: ClaimStatus[] = [
  'pendingReview',
  'pendingDriverResponse',
  'pendingApproval',
  'pendingSecondApproval',
  'pendingProcessing',
  'pendingFinalReview',
];

/** Helper: Is pending action? Ported from Claim.isPendingAction. */
export function isClaimPendingAction(claim: Claim): boolean {
  return PENDING_ACTION_STATUSES.includes(claim.status);
}
