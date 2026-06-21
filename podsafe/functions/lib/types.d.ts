import { Timestamp as FirebaseTimestamp } from 'firebase-admin/firestore';
export type DeliveryStatus = 'PENDING' | 'OUT_FOR_DELIVERY' | 'DELIVERED' | 'FAILED' | 'PARTIAL';
export interface DeliveryNormalized {
    companyId: string;
    source: 'BusinessCentral';
    sourceId: string;
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
    scheduledDate: string;
    status: DeliveryStatus;
    driverId?: string;
    items: DeliveryItem[];
    sync: SyncMetadata;
    createdAt: FirebaseTimestamp;
    updatedAt: FirebaseTimestamp;
}
export interface DeliveryItem {
    sku?: string;
    name?: string;
    qty: number;
    uom?: string;
    traceId?: string;
}
export interface SyncMetadata {
    source: 'BusinessCentral';
    version?: string;
    lastPullAt?: FirebaseTimestamp;
    lastPushAt?: FirebaseTimestamp;
    lastPushError?: string;
}
export interface PodPayload {
    completedAt: string;
    gpsLat?: number;
    gpsLng?: number;
    note?: string;
    files?: PodFile[];
    signature?: string;
}
export interface PodFile {
    fileName: string;
    fileUrl: string;
    fileType: string;
    uploadedAt: string;
}
export interface BCIntegration {
    tenantId: string;
    environment: 'Production' | 'Sandbox';
    companyId: string;
    companyName?: string;
    connectedAt: FirebaseTimestamp;
    connectedBy: string;
    status: 'connected' | 'disconnected' | 'error';
    lastSyncAt?: FirebaseTimestamp;
    lastError?: string;
    tokenSecretId?: string;
}
export interface OAuthState {
    companyId: string;
    nonce: string;
    ts: number;
    redirectTo?: string;
}
export interface TokenResponse {
    access_token: string;
    token_type: string;
    expires_in: number;
    refresh_token?: string;
    id_token?: string;
    scope?: string;
}
export interface IdTokenClaims {
    tid: string;
    oid: string;
    name?: string;
    email?: string;
    preferred_username?: string;
}
export interface BCCompany {
    id: string;
    systemVersion: string;
    name: string;
    displayName: string;
    businessProfileId?: string;
}
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
export interface BCSalesShipmentLine {
    id: string;
    documentId: string;
    lineType: string;
    lineObjectNumber?: string;
    description: string;
    unitOfMeasureCode?: string;
    quantity: number;
    unitPrice?: number;
    lineAmount?: number;
}
export interface PullShipmentsRequest {
    companyId: string;
    since?: string;
    limit?: number;
}
export interface PullShipmentsResponse {
    success: boolean;
    created: number;
    updated: number;
    skipped: number;
    errors: string[];
}
export interface PushPodRequest {
    companyId: string;
    sourceId: string;
    status: DeliveryStatus;
    pod: PodPayload;
}
export interface PushPodResponse {
    success: boolean;
    message?: string;
    error?: string;
}
export interface RetryableError extends Error {
    statusCode?: number;
    retryAfter?: number;
    retryable: boolean;
}
//# sourceMappingURL=types.d.ts.map