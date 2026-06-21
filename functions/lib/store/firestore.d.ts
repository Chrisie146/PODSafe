import * as admin from 'firebase-admin';
import { BCIntegration, DeliveryNormalized } from '../types';
export declare class TokenVault {
    saveRefreshToken(companyId: string, refreshToken: string): Promise<string>;
    loadRefreshToken(secretId: string): Promise<string | null>;
    deleteRefreshToken(secretId: string): Promise<void>;
}
export declare function getBcIntegration(companyId: string): Promise<BCIntegration | null>;
export declare function saveBcIntegration(companyId: string, integration: Partial<BCIntegration>): Promise<void>;
export declare function deleteBcIntegration(companyId: string): Promise<void>;
export declare function upsertDelivery(delivery: DeliveryNormalized): Promise<'created' | 'updated' | 'skipped'>;
export declare function getDeliveryBySourceId(companyId: string, sourceId: string): Promise<DeliveryNormalized | null>;
export declare function updateDeliverySync(companyId: string, sourceId: string, syncUpdate: Partial<DeliveryNormalized['sync']>): Promise<void>;
export declare function getDeliveries(companyId: string, limit?: number, startAfter?: admin.firestore.DocumentSnapshot): Promise<DeliveryNormalized[]>;
//# sourceMappingURL=firestore.d.ts.map