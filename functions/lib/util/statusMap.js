"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.mapBcStatusToPodsafe = mapBcStatusToPodsafe;
exports.mapPodsafeStatusToBc = mapPodsafeStatusToBc;
exports.shouldPushStatusToBc = shouldPushStatusToBc;
function mapBcStatusToPodsafe(bcStatus) {
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
function mapPodsafeStatusToBc(status) {
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
function shouldPushStatusToBc(oldStatus, newStatus) {
    const finalStates = ['DELIVERED', 'FAILED', 'PARTIAL'];
    return finalStates.includes(newStatus) && oldStatus !== newStatus;
}
//# sourceMappingURL=statusMap.js.map