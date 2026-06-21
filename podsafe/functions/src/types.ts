/**
 * TypeScript Type Definitions for Business Central Integration
 */

import { Timestamp as FirebaseTimestamp } from 'firebase-admin/firestore';

/**
 * PODSafe delivery status
 */
export type DeliveryStatus = 'PENDING' | 'OUT_FOR_DELIVERY' | 'DELIVERED' | 'FAILED' | 'PARTIAL';

/**
 * Normalized delivery document in Firestore
 */
export interface DeliveryNormalized {
  companyId: string;                  // PODSafe company ID
  source: 'BusinessCentral';
  sourceId: string;                   // BC entity id (GUID)
  orderNumber: string;
  customer: {
    id?: string;
    name: string;
  };
  address: {
    line1: string;
    line2?: string;
    city: string;
    postalCode?: string;
    country?: string;
  };
  scheduledDate: string;              // ISO date string
  status: DeliveryStatus;
  driverId?: string;
  items: DeliveryItem[];
  sync: SyncMetadata;
  createdAt: FirebaseTimestamp;
  updatedAt: FirebaseTimestamp;
}

/**
 * Delivery line item
 */
export interface DeliveryItem {
  sku?: string;
  name?: string;
  qty: number;
  uom?: string;                       // Unit of measure
  traceId?: string;                   // BC line GUID
}

/**
 * Sync metadata for bidirectional sync
 */
export interface SyncMetadata {
  source: 'BusinessCentral';
  version?: string;                   // @odata.etag from BC
  lastPullAt?: FirebaseTimestamp;
  lastPushAt?: FirebaseTimestamp;
  lastPushError?: string;
}

/**
 * Proof of Delivery payload
 */
export interface PodPayload {
  completedAt: string;                // ISO datetime
  gpsLat?: number;
  gpsLng?: number;
  note?: string;
  files?: PodFile[];
  signature?: string;                 // Base64 or URL
}

/**
 * POD attachment file
 */
export interface PodFile {
  fileName: string;
  fileUrl: string;
  fileType: string;
  uploadedAt: string;
}

/**
 * Business Central integration configuration
 * Stored at: companies/{companyId}/integrations/businessCentral
 */
export interface BCIntegration {
  tenantId: string;                   // Azure AD tenant ID
  environment: 'Production' | 'Sandbox';
  companyId: string;                  // BC company GUID
  companyName?: string;
  connectedAt: FirebaseTimestamp;
  connectedBy: string;                // User ID who connected
  status: 'connected' | 'disconnected' | 'error';
  lastSyncAt?: FirebaseTimestamp;
  lastError?: string;
  tokenSecretId?: string;             // Reference to Secret Manager
}

/**
 * OAuth state parameter
 */
export interface OAuthState {
  companyId: string;                  // PODSafe company ID
  nonce: string;
  ts: number;                         // Timestamp
  redirectTo?: string;                // Optional redirect after auth
}

/**
 * OAuth token response from Microsoft
 */
export interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token?: string;
  id_token?: string;
  scope?: string;
}

/**
 * Decoded ID token claims
 */
export interface IdTokenClaims {
  tid: string;                        // Tenant ID
  oid: string;                        // Object ID (user)
  name?: string;
  email?: string;
  preferred_username?: string;
}

/**
 * Business Central Company response
 */
export interface BCCompany {
  id: string;                         // GUID
  systemVersion: string;
  name: string;
  displayName: string;
  businessProfileId?: string;
}

/**
 * Business Central Sales Shipment
 */
export interface BCSalesShipment {
  '@odata.etag': string;
  id: string;
  number: string;
  externalDocumentNumber?: string;
  orderNumber?: string;
  postingDate?: string;
  shipmentDate?: string;
  sellToCustomerNumber?: string;
  sellToCustomerName: string;
  shipToName?: string;
  shipToAddress?: string;
  shipToAddress2?: string;
  shipToCity?: string;
  shipToCountry?: string;
  shipToPostCode?: string;
  requestedDeliveryDate?: string;
  lastModifiedDateTime: string;
}

/**
 * Business Central Sales Shipment Line
 */
export interface BCSalesShipmentLine {
  id: string;
  documentId: string;                 // Parent shipment ID
  lineType: string;
  lineObjectNumber?: string;          // Item number
  description: string;
  unitOfMeasureCode?: string;
  quantity: number;
  unitPrice?: number;
  lineAmount?: number;
}

/**
 * Pull shipments request
 */
export interface PullShipmentsRequest {
  companyId: string;
  since?: string;                     // ISO datetime
  limit?: number;
}

/**
 * Pull shipments response
 */
export interface PullShipmentsResponse {
  success: boolean;
  created: number;
  updated: number;
  skipped: number;
  errors: string[];
}

/**
 * Push POD request
 */
export interface PushPodRequest {
  companyId: string;
  sourceId: string;                   // BC shipment ID
  status: DeliveryStatus;
  pod: PodPayload;
}

/**
 * Push POD response
 */
export interface PushPodResponse {
  success: boolean;
  message?: string;
  error?: string;
}

/**
 * HTTP error with retry info
 */
export interface RetryableError extends Error {
  statusCode?: number;
  retryAfter?: number;
  retryable: boolean;
}
