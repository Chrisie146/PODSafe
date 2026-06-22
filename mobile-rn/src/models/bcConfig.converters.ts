import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { BcConfig } from './bcConfig';

/**
 * Ported from BCConfig.fromFirestore/toFirestore in lib/models/bc_config.dart
 * (verified against source on 2026-06-22).
 */
export function bcConfigFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): BcConfig {
  const data = doc.data() ?? {};

  return {
    companyId: doc.id,
    isEnabled: (data.isEnabled as boolean) ?? false,
    tenantId: data.tenantId,
    environment: (data.environment as string) ?? 'production',
    bcCompanyId: data.bcCompanyId,
    clientId: data.clientId,
    bcApiUrl: data.bcApiUrl,
    lastSyncedAt: data.lastSyncedAt?.toDate?.(),
    syncIntervalMinutes: (data.syncIntervalMinutes as number) ?? 15,
    autoCreateDeliveries: (data.autoCreateDeliveries as boolean) ?? false,
    autoAttachPODs: (data.autoAttachPODs as boolean) ?? true,
    lastSyncStatus: data.lastSyncStatus,
    lastSyncError: data.lastSyncError,
  };
}

export function bcConfigToFirestore(config: BcConfig): Record<string, unknown> {
  return {
    isEnabled: config.isEnabled,
    tenantId: config.tenantId ?? null,
    environment: config.environment,
    bcCompanyId: config.bcCompanyId ?? null,
    clientId: config.clientId ?? null,
    bcApiUrl: config.bcApiUrl ?? null,
    lastSyncedAt: config.lastSyncedAt ? firestore.Timestamp.fromDate(config.lastSyncedAt) : null,
    syncIntervalMinutes: config.syncIntervalMinutes,
    autoCreateDeliveries: config.autoCreateDeliveries,
    autoAttachPODs: config.autoAttachPODs,
    lastSyncStatus: config.lastSyncStatus ?? null,
    lastSyncError: config.lastSyncError ?? null,
    updatedAt: firestore.FieldValue.serverTimestamp(),
  };
}
