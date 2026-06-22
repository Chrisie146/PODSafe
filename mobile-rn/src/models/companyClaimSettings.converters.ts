import { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { ClaimType, CustomFieldType } from './claim';
import {
  ApprovalRole,
  CompanyClaimSettings,
  ClaimWorkflowPreset,
  CustomFieldDefinition,
  defaultCompanyClaimSettings,
} from './companyClaimSettings';

/**
 * Ported from company_claim_settings.dart's toMap()/fromMap() (verified against source
 * on 2026-06-21). Like claim.converters.ts, dates are ISO strings, not Timestamps.
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

const VALID_WORKFLOW_PRESETS: ClaimWorkflowPreset[] = ['simple', 'standard', 'enterprise', 'custom'];

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

function claimTypeOrOther(value: unknown): ClaimType {
  return enumOrDefault(value, VALID_CLAIM_TYPES, 'other');
}

function approvalRoleFromMap(map: Record<string, unknown>): ApprovalRole {
  return {
    role: (map.role as string) ?? '',
    displayName: (map.displayName as string) ?? '',
    slaHours: (map.slaHours as number) ?? 24,
    canApprove: (map.canApprove as boolean) ?? true,
    canReject: (map.canReject as boolean) ?? true,
    canRequestInfo: (map.canRequestInfo as boolean) ?? true,
    requiresSignature: (map.requiresSignature as boolean) ?? false,
    specificUserIds: map.specificUserIds != null ? [...(map.specificUserIds as string[])] : undefined,
  };
}

function approvalRoleToMap(role: ApprovalRole): Record<string, unknown> {
  return {
    role: role.role,
    displayName: role.displayName,
    slaHours: role.slaHours,
    canApprove: role.canApprove,
    canReject: role.canReject,
    canRequestInfo: role.canRequestInfo,
    requiresSignature: role.requiresSignature,
    specificUserIds: role.specificUserIds ?? null,
  };
}

function customFieldDefinitionFromMap(map: Record<string, unknown>): CustomFieldDefinition {
  return {
    id: (map.id as string) ?? '',
    label: (map.label as string) ?? '',
    type: enumOrDefault(map.type, VALID_CUSTOM_FIELD_TYPES, 'text'),
    required: (map.required as boolean) ?? false,
    dropdownOptions: map.dropdownOptions != null ? [...(map.dropdownOptions as string[])] : undefined,
    placeholder: map.placeholder as string | undefined,
    helpText: map.helpText as string | undefined,
    validationRegex: map.validationRegex as string | undefined,
    errorMessage: map.errorMessage as string | undefined,
    minValue: map.minValue as number | undefined,
    maxValue: map.maxValue as number | undefined,
    maxLength: map.maxLength as number | undefined,
  };
}

function customFieldDefinitionToMap(field: CustomFieldDefinition): Record<string, unknown> {
  return {
    id: field.id,
    label: field.label,
    type: field.type,
    required: field.required,
    dropdownOptions: field.dropdownOptions ?? null,
    placeholder: field.placeholder ?? null,
    helpText: field.helpText ?? null,
    validationRegex: field.validationRegex ?? null,
    errorMessage: field.errorMessage ?? null,
    minValue: field.minValue ?? null,
    maxValue: field.maxValue ?? null,
    maxLength: field.maxLength ?? null,
  };
}

/** Mirrors CompanyClaimSettings.fromMap(). */
export function companyClaimSettingsFromMap(map: Record<string, unknown>): CompanyClaimSettings {
  const fallback = defaultCompanyClaimSettings((map.companyId as string) ?? '');

  const customWorkflowsRaw = map.customWorkflows as Record<string, unknown[]> | undefined;
  const customWorkflows: CompanyClaimSettings['customWorkflows'] = {};
  if (customWorkflowsRaw) {
    for (const [key, value] of Object.entries(customWorkflowsRaw)) {
      customWorkflows[claimTypeOrOther(key)] = (value as Record<string, unknown>[]).map(approvalRoleFromMap);
    }
  }

  const customFieldsByTypeRaw = map.customFieldsByType as Record<string, unknown[]> | undefined;
  const customFieldsByType: CompanyClaimSettings['customFieldsByType'] = {};
  if (customFieldsByTypeRaw) {
    for (const [key, value] of Object.entries(customFieldsByTypeRaw)) {
      customFieldsByType[claimTypeOrOther(key)] = (value as Record<string, unknown>[]).map(customFieldDefinitionFromMap);
    }
  }

  return {
    companyId: (map.companyId as string) ?? '',
    enabledClaimTypes: Array.isArray(map.enabledClaimTypes)
      ? (map.enabledClaimTypes as unknown[]).map(claimTypeOrOther)
      : fallback.enabledClaimTypes,
    minPhotosRequired: (map.minPhotosRequired as number) ?? 1,
    maxPhotosAllowed: (map.maxPhotosAllowed as number) ?? 10,
    photosMandatory: (map.photosMandatory as boolean) ?? true,
    requirePhotoForImmediate: (map.requirePhotoForImmediate as boolean) ?? true,
    requirePhotoForDelayed: (map.requirePhotoForDelayed as boolean) ?? false,
    requireCustomerSignature: (map.requireCustomerSignature as boolean) ?? false,
    requireDriverSignature: (map.requireDriverSignature as boolean) ?? false,
    claimFilingDeadlineDays: map.claimFilingDeadlineDays as number | undefined,
    defaultSlaHours: (map.defaultSlaHours as number) ?? 24,
    workflowPreset: enumOrDefault(map.workflowPreset, VALID_WORKFLOW_PRESETS, 'standard'),
    customWorkflows,
    enableAutoApproval: (map.enableAutoApproval as boolean) ?? false,
    autoApproveUnderAmount: map.autoApproveUnderAmount != null ? Number(map.autoApproveUnderAmount) : undefined,
    autoApproveTypes: Array.isArray(map.autoApproveTypes) ? (map.autoApproveTypes as unknown[]).map(claimTypeOrOther) : undefined,
    customFieldsByType,
    enablePushNotifications: (map.enablePushNotifications as boolean) ?? true,
    enableEmailNotifications: (map.enableEmailNotifications as boolean) ?? false,
    enableSMSNotifications: (map.enableSMSNotifications as boolean) ?? false,
    requiresERPSync: (map.requiresERPSync as boolean) ?? false,
    erpSystem: map.erpSystem as string | undefined,
    erpConfig: map.erpConfig as Record<string, unknown> | undefined,
    enableFraudDetection: (map.enableFraudDetection as boolean) ?? false,
    fraudThresholdAmount: map.fraudThresholdAmount != null ? Number(map.fraudThresholdAmount) : undefined,
    fraudThresholdFrequency: map.fraudThresholdFrequency as number | undefined,
    enablePatternDetection: (map.enablePatternDetection as boolean) ?? true,
    recurringClaimThreshold: (map.recurringClaimThreshold as number) ?? 3,
    allowDriverFiling: (map.allowDriverFiling as boolean) ?? true,
    allowAdminFiling: (map.allowAdminFiling as boolean) ?? true,
    allowCustomerPortal: (map.allowCustomerPortal as boolean) ?? false,
    enableComments: (map.enableComments as boolean) ?? true,
    enableInternalNotes: (map.enableInternalNotes as boolean) ?? true,
    claimIdPrefix: (map.claimIdPrefix as string) ?? 'CLM',
    claimIdStartNumber: (map.claimIdStartNumber as number) ?? 1,
    createdAt: map.createdAt ? new Date(map.createdAt as string) : new Date(),
    updatedAt: map.updatedAt ? new Date(map.updatedAt as string) : new Date(),
  };
}

/** Mirrors CompanyClaimSettings.toMap(). */
export function companyClaimSettingsToMap(settings: CompanyClaimSettings): Record<string, unknown> {
  const customWorkflows: Record<string, unknown[]> = {};
  for (const [type, roles] of Object.entries(settings.customWorkflows)) {
    customWorkflows[type] = (roles ?? []).map(approvalRoleToMap);
  }

  const customFieldsByType: Record<string, unknown[]> = {};
  for (const [type, fields] of Object.entries(settings.customFieldsByType)) {
    customFieldsByType[type] = (fields ?? []).map(customFieldDefinitionToMap);
  }

  return {
    companyId: settings.companyId,
    enabledClaimTypes: settings.enabledClaimTypes,
    minPhotosRequired: settings.minPhotosRequired,
    maxPhotosAllowed: settings.maxPhotosAllowed,
    photosMandatory: settings.photosMandatory,
    requirePhotoForImmediate: settings.requirePhotoForImmediate,
    requirePhotoForDelayed: settings.requirePhotoForDelayed,
    requireCustomerSignature: settings.requireCustomerSignature,
    requireDriverSignature: settings.requireDriverSignature,
    claimFilingDeadlineDays: settings.claimFilingDeadlineDays ?? null,
    defaultSlaHours: settings.defaultSlaHours,
    workflowPreset: settings.workflowPreset,
    customWorkflows,
    enableAutoApproval: settings.enableAutoApproval,
    autoApproveUnderAmount: settings.autoApproveUnderAmount ?? null,
    autoApproveTypes: settings.autoApproveTypes ?? null,
    customFieldsByType,
    enablePushNotifications: settings.enablePushNotifications,
    enableEmailNotifications: settings.enableEmailNotifications,
    enableSMSNotifications: settings.enableSMSNotifications,
    requiresERPSync: settings.requiresERPSync,
    erpSystem: settings.erpSystem ?? null,
    erpConfig: settings.erpConfig ?? null,
    enableFraudDetection: settings.enableFraudDetection,
    fraudThresholdAmount: settings.fraudThresholdAmount ?? null,
    fraudThresholdFrequency: settings.fraudThresholdFrequency ?? null,
    enablePatternDetection: settings.enablePatternDetection,
    recurringClaimThreshold: settings.recurringClaimThreshold ?? null,
    allowDriverFiling: settings.allowDriverFiling,
    allowAdminFiling: settings.allowAdminFiling,
    allowCustomerPortal: settings.allowCustomerPortal,
    enableComments: settings.enableComments,
    enableInternalNotes: settings.enableInternalNotes,
    claimIdPrefix: settings.claimIdPrefix,
    claimIdStartNumber: settings.claimIdStartNumber,
    createdAt: settings.createdAt.toISOString(),
    updatedAt: settings.updatedAt.toISOString(),
  };
}

/** Mirrors CompanyClaimSettings.fromFirestore(doc). */
export function companyClaimSettingsFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): CompanyClaimSettings {
  return companyClaimSettingsFromMap(doc.data() ?? {});
}
