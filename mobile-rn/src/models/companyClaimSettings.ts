import { ClaimType, CustomFieldType } from './claim';

/**
 * Ported from lib/models/company_claim_settings.dart (verified against source on
 * 2026-06-21). Not one of the files explicitly listed in the claims-domain port plan,
 * but report_issue_screen.dart and claim_provider.dart both depend on it directly
 * (photo/signature requirements, approval workflow presets, per-claim-type custom
 * fields), so a minimal port is required for ReportIssue.tsx / useClaimStore.ts to be
 * meaningful rather than stubbed out. Only the fields actually read by the driver-facing
 * screens are included; admin-only settings-editor concerns (ERP config, fraud/pattern
 * detection thresholds, etc.) are included too since they're plain data read by
 * ClaimRepository.getCompanySettings, but no admin settings-editor UI is ported here.
 */

/** Workflow presets. */
export type ClaimWorkflowPreset = 'simple' | 'standard' | 'enterprise' | 'custom';

/** Approval role definition. */
export interface ApprovalRole {
  role: string;
  displayName: string;
  slaHours: number;
  canApprove: boolean;
  canReject: boolean;
  canRequestInfo: boolean;
  requiresSignature: boolean;
  specificUserIds?: string[];
}

/** Mirrors ClaimWorkflowPresetExtension.displayName. */
export function claimWorkflowPresetDisplayName(preset: ClaimWorkflowPreset): string {
  switch (preset) {
    case 'simple':
      return 'Simple (2 levels)';
    case 'standard':
      return 'Standard (3 levels)';
    case 'enterprise':
      return 'Enterprise (5 levels)';
    case 'custom':
      return 'Custom Workflow';
  }
}

export const ALL_CLAIM_WORKFLOW_PRESETS: ClaimWorkflowPreset[] = ['simple', 'standard', 'enterprise', 'custom'];

/** Mirrors ClaimWorkflowPresetExtension.getDefaultWorkflow(). */
export function defaultWorkflowFor(preset: ClaimWorkflowPreset): ApprovalRole[] {
  switch (preset) {
    case 'simple':
      return [
        { role: 'admin', displayName: 'Admin', slaHours: 24, canApprove: true, canReject: true, canRequestInfo: true, requiresSignature: false },
      ];
    case 'standard':
      return [
        { role: 'manager', displayName: 'Manager', slaHours: 24, canApprove: true, canReject: true, canRequestInfo: true, requiresSignature: false },
        { role: 'admin', displayName: 'Admin', slaHours: 24, canApprove: true, canReject: true, canRequestInfo: true, requiresSignature: false },
      ];
    case 'enterprise':
      return [
        { role: 'manager', displayName: 'Manager', slaHours: 24, canApprove: true, canReject: true, canRequestInfo: true, requiresSignature: false },
        { role: 'approver', displayName: 'Approver', slaHours: 24, canApprove: true, canReject: true, canRequestInfo: true, requiresSignature: false },
        { role: 'processor', displayName: 'Processor', slaHours: 24, canApprove: true, canReject: true, canRequestInfo: true, requiresSignature: false },
        { role: 'reviewer', displayName: 'Reviewer', slaHours: 24, canApprove: true, canReject: true, canRequestInfo: true, requiresSignature: false },
      ];
    case 'custom':
      return [];
  }
}

/** Custom field definition for company-specific data collection (template, not a value holder). */
export interface CustomFieldDefinition {
  id: string;
  label: string;
  type: CustomFieldType;
  required: boolean;
  dropdownOptions?: string[];
  placeholder?: string;
  helpText?: string;
  validationRegex?: string;
  errorMessage?: string;
  minValue?: number;
  maxValue?: number;
  maxLength?: number;
}

/** Company-specific claim configuration. Allows each company to customize their claims process. */
export interface CompanyClaimSettings {
  companyId: string;

  enabledClaimTypes: ClaimType[];

  minPhotosRequired: number;
  maxPhotosAllowed: number;
  photosMandatory: boolean;
  requirePhotoForImmediate: boolean;
  requirePhotoForDelayed: boolean;

  requireCustomerSignature: boolean;
  requireDriverSignature: boolean;

  claimFilingDeadlineDays?: number;
  defaultSlaHours: number;

  workflowPreset: ClaimWorkflowPreset;
  customWorkflows: Partial<Record<ClaimType, ApprovalRole[]>>;

  enableAutoApproval: boolean;
  autoApproveUnderAmount?: number;
  autoApproveTypes?: ClaimType[];

  customFieldsByType: Partial<Record<ClaimType, CustomFieldDefinition[]>>;

  enablePushNotifications: boolean;
  enableEmailNotifications: boolean;
  enableSMSNotifications: boolean;

  requiresERPSync: boolean;
  erpSystem?: string;
  erpConfig?: Record<string, unknown>;

  enableFraudDetection: boolean;
  fraudThresholdAmount?: number;
  fraudThresholdFrequency?: number;

  enablePatternDetection: boolean;
  recurringClaimThreshold?: number;

  allowDriverFiling: boolean;
  allowAdminFiling: boolean;
  allowCustomerPortal: boolean;
  enableComments: boolean;
  enableInternalNotes: boolean;

  claimIdPrefix: string;
  claimIdStartNumber: number;

  createdAt: Date;
  updatedAt: Date;
}

const DEFAULT_ENABLED_TYPES: ClaimType[] = ['damaged', 'shortage', 'wrongItems', 'returns', 'other'];

/** Builds the same defaults as the Dart `CompanyClaimSettings(companyId: ...)` constructor. */
export function defaultCompanyClaimSettings(companyId: string): CompanyClaimSettings {
  const now = new Date();
  return {
    companyId,
    enabledClaimTypes: DEFAULT_ENABLED_TYPES,
    minPhotosRequired: 1,
    maxPhotosAllowed: 10,
    photosMandatory: true,
    requirePhotoForImmediate: true,
    requirePhotoForDelayed: false,
    requireCustomerSignature: false,
    requireDriverSignature: false,
    claimFilingDeadlineDays: undefined,
    defaultSlaHours: 24,
    workflowPreset: 'standard',
    customWorkflows: {},
    enableAutoApproval: false,
    autoApproveUnderAmount: undefined,
    autoApproveTypes: undefined,
    customFieldsByType: {},
    enablePushNotifications: true,
    enableEmailNotifications: false,
    enableSMSNotifications: false,
    requiresERPSync: false,
    erpSystem: undefined,
    erpConfig: undefined,
    enableFraudDetection: false,
    fraudThresholdAmount: undefined,
    fraudThresholdFrequency: undefined,
    enablePatternDetection: true,
    recurringClaimThreshold: 3,
    allowDriverFiling: true,
    allowAdminFiling: true,
    allowCustomerPortal: false,
    enableComments: true,
    enableInternalNotes: true,
    claimIdPrefix: 'CLM',
    claimIdStartNumber: 1,
    createdAt: now,
    updatedAt: now,
  };
}

/** Helper: Check if claim type is enabled. */
export function isClaimTypeEnabled(settings: CompanyClaimSettings, type: ClaimType): boolean {
  return settings.enabledClaimTypes.includes(type);
}

/** Helper: Get workflow for claim type. */
export function getWorkflowForType(settings: CompanyClaimSettings, type: ClaimType): ApprovalRole[] {
  const custom = settings.customWorkflows[type];
  if (custom) {
    return custom;
  }
  return defaultWorkflowFor(settings.workflowPreset);
}

/** Helper: Get custom fields for claim type. */
export function getCustomFieldsForType(settings: CompanyClaimSettings, type: ClaimType): CustomFieldDefinition[] {
  return settings.customFieldsByType[type] ?? [];
}

/** Helper: Check if auto-approval applies. */
export function shouldAutoApprove(settings: CompanyClaimSettings, type: ClaimType, amount?: number): boolean {
  if (!settings.enableAutoApproval) {
    return false;
  }
  if (settings.autoApproveTypes && !settings.autoApproveTypes.includes(type)) {
    return false;
  }
  if (settings.autoApproveUnderAmount != null && amount != null) {
    return amount < settings.autoApproveUnderAmount;
  }
  return false;
}
