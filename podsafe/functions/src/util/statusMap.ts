/**
 * Status mapping between Business Central and PODSafe
 */

import { DeliveryStatus } from '../types';

/**
 * Map BC shipment status to PODSafe delivery status
 * 
 * BC Status values can be custom, these are common defaults:
 * - Open: Shipment created but not finalized
 * - Ready: Ready for pickup/delivery
 * - Posted: Finalized/completed shipment
 * - Cancelled: Cancelled shipment
 */
export function mapBcStatusToPodsafe(bcStatus?: string): DeliveryStatus {
  if (!bcStatus) {
    return 'PENDING';
  }

  const normalized = bcStatus.toLowerCase().trim();

  switch (normalized) {
    case 'open':
    case 'ready':
    case 'in transit':
    case 'shipped':
      return 'OUT_FOR_DELIVERY';

    case 'posted':
    case 'completed':
    case 'delivered':
      return 'DELIVERED';

    case 'cancelled':
    case 'canceled':
    case 'failed':
      return 'FAILED';

    case 'partial':
    case 'partially delivered':
    case 'partially shipped':
      return 'PARTIAL';

    default:
      return 'PENDING';
  }
}

/**
 * Map PODSafe status to BC-compatible status string
 * These may need to be customized based on BC configuration
 */
export function mapPodsafeStatusToBc(status: DeliveryStatus): string {
  switch (status) {
    case 'OUT_FOR_DELIVERY':
      return 'In Transit';
    case 'DELIVERED':
      return 'Delivered';
    case 'FAILED':
      return 'Failed';
    case 'PARTIAL':
      return 'Partially Delivered';
    case 'PENDING':
    default:
      return 'Pending';
  }
}

/**
 * Determine if a status change should trigger a BC push
 */
export function shouldPushStatusToBc(
  oldStatus: DeliveryStatus,
  newStatus: DeliveryStatus
): boolean {
  // Push when moving to a final state
  const finalStates: DeliveryStatus[] = ['DELIVERED', 'FAILED', 'PARTIAL'];
  
  return finalStates.includes(newStatus) && oldStatus !== newStatus;
}
