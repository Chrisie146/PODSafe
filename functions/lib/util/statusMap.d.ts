import { DeliveryStatus } from '../types';
export declare function mapBcStatusToPodsafe(bcStatus?: string): DeliveryStatus;
export declare function mapPodsafeStatusToBc(status: DeliveryStatus): string;
export declare function shouldPushStatusToBc(oldStatus: DeliveryStatus, newStatus: DeliveryStatus): boolean;
//# sourceMappingURL=statusMap.d.ts.map