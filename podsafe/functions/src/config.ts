/**
 * Business Central Integration Configuration
 * Environment variables and constants
 */

import * as functions from 'firebase-functions';

export const config = {
  // OAuth Configuration - loaded lazily from functions.config() at runtime
  get bcOAuthAuthority() {
    return process.env.BC_OAUTH_AUTHORITY || functions.config().bc?.oauth_authority || 'https://login.microsoftonline.com/common';
  },
  get bcClientId() {
    return process.env.BC_CLIENT_ID || functions.config().bc?.client_id || '';
  },
  get bcClientSecret() {
    return process.env.BC_CLIENT_SECRET || functions.config().bc?.client_secret || '';
  },
  get bcRedirectUri() {
    return process.env.BC_REDIRECT_URI || functions.config().bc?.redirect_uri || 'https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback';
  },
  get bcScope() {
    return process.env.BC_SCOPE || functions.config().bc?.scope || 'https://api.businesscentral.dynamics.com/.default offline_access';
  },
  
  // API Configuration
  bcApiBaseUrl: 'https://api.businesscentral.dynamics.com/v2.0',
  
  // GCP Configuration
  gcpProjectId: process.env.GCP_PROJECT_ID || process.env.GCLOUD_PROJECT || '',
  
  // Security
  sessionSecret: process.env.SESSION_SECRET || 'change-me-in-production',
  
  // Retry Configuration
  maxRetries: 3,
  retryDelay: 1000, // ms
  backoffMultiplier: 2,
} as const;

/**
 * Validate required environment variables
 */
export function validateConfig(): void {
  const required = [
    'bcClientId',
    'bcClientSecret',
    'bcRedirectUri',
  ];
  
  const missing = required.filter(key => !config[key as keyof typeof config]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required configuration: ${missing.join(', ')}`);
  }
}

/**
 * Get tenant-specific token endpoint
 */
export function getTokenEndpoint(tenantId: string = 'common'): string {
  return `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;
}

/**
 * Get BC API URL for tenant/company
 */
export function getBcApiUrl(tenantId: string, environment: 'Production' | 'Sandbox' = 'Production'): string {
  return `${config.bcApiBaseUrl}/${tenantId}/${environment}/api/v2.0`;
}
