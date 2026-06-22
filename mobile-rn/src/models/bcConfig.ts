/**
 * Ported from lib/models/bc_config.dart (verified against source on 2026-06-22).
 */
export interface BcConfig {
  companyId: string;
  isEnabled: boolean;
  tenantId?: string;
  /** 'production' | 'sandbox' */
  environment: string;
  bcCompanyId?: string;
  clientId?: string;
  bcApiUrl?: string;
  lastSyncedAt?: Date;
  syncIntervalMinutes: number;
  autoCreateDeliveries: boolean;
  autoAttachPODs: boolean;
  /** 'success' | 'failed' | 'in-progress' */
  lastSyncStatus?: string;
  lastSyncError?: string;
}

export function defaultBcConfig(companyId: string): BcConfig {
  return {
    companyId,
    isEnabled: false,
    environment: 'production',
    syncIntervalMinutes: 15,
    autoCreateDeliveries: false,
    autoAttachPODs: true,
  };
}

/** Mirrors BCConfig.getApiEndpoint(). */
export function bcApiEndpoint(config: BcConfig, path: string): string {
  if (!config.bcApiUrl) {
    throw new Error('BC API URL not configured');
  }
  const baseUrl = config.bcApiUrl.endsWith('/') ? config.bcApiUrl : `${config.bcApiUrl}/`;
  const cleanPath = path.startsWith('/') ? path.substring(1) : path;
  return `${baseUrl}${cleanPath}`;
}

/** Mirrors BCConfig.isConfigured. */
export function isBcConfigured(config: BcConfig): boolean {
  return Boolean(config.tenantId && config.bcCompanyId && config.clientId && config.bcApiUrl);
}
