import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { Delivery, DeliveryItem, DeliveryStatus } from './delivery';

/**
 * Ported from Delivery.fromFirestore/toFirestore + DeliveryItem.fromMap/toMap in
 * lib/models/delivery_model.dart (verified against source on 2026-06-21).
 */
const VALID_STATUSES: DeliveryStatus[] = ['pending', 'inTransit', 'delivered', 'failed'];

function deliveryItemFromMap(map: Record<string, unknown>): DeliveryItem {
  return {
    description: (map.description as string) ?? '',
    quantity: Number(map.quantity ?? 0),
    unit: map.unit as string | undefined,
    unitPrice: map.unitPrice != null ? Number(map.unitPrice) : undefined,
    totalPrice: map.totalPrice != null ? Number(map.totalPrice) : undefined,
  };
}

function deliveryItemToMap(item: DeliveryItem): Record<string, unknown> {
  return {
    description: item.description,
    quantity: item.quantity,
    unit: item.unit ?? null,
    unitPrice: item.unitPrice ?? null,
    totalPrice: item.totalPrice ?? null,
  };
}

export function deliveryFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): Delivery {
  const data = doc.data() ?? {};
  const status = VALID_STATUSES.includes(data.status) ? (data.status as DeliveryStatus) : 'pending';

  return {
    id: doc.id,
    companyId: data.companyId ?? '',
    driverId: data.driverId ?? '',
    customerName: data.customerName ?? '',
    customerAddress: data.customerAddress ?? '',
    customerPhone: data.customerPhone,
    customerId: data.customerId,
    customerNumber: data.customerNumber,
    orderNumber: data.orderNumber,
    invoiceNumber: data.invoiceNumber ?? '',
    invoiceDate: data.invoiceDate?.toDate?.(),
    items: Array.isArray(data.items) ? data.items.map(deliveryItemFromMap) : [],
    invoiceTotal: data.invoiceTotal != null ? Number(data.invoiceTotal) : undefined,
    taxAmount: data.taxAmount != null ? Number(data.taxAmount) : undefined,
    discountAmount: data.discountAmount != null ? Number(data.discountAmount) : undefined,
    currency: data.currency ?? 'ZAR',
    vehicleUsed: data.vehicleUsed,
    isThirdPartyTransport: data.isThirdPartyTransport ?? false,
    thirdPartyProviderName: data.thirdPartyProviderName,
    thirdPartyDriverName: data.thirdPartyDriverName,
    thirdPartyDriverPhone: data.thirdPartyDriverPhone,
    thirdPartyVehicleInfo: data.thirdPartyVehicleInfo,
    uploadToken: data.uploadToken,
    thirdPartyDocs: Array.isArray(data.thirdPartyDocs) ? (data.thirdPartyDocs as string[]) : undefined,
    status,
    scheduledDate: data.scheduledDate?.toDate?.() ?? new Date(),
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    deliveredAt: data.deliveredAt?.toDate?.(),
    notes: data.notes,
    podId: data.podId,
  };
}

export function deliveryToFirestore(delivery: Delivery): Record<string, unknown> {
  return {
    companyId: delivery.companyId,
    driverId: delivery.driverId,
    customerName: delivery.customerName,
    customerAddress: delivery.customerAddress,
    customerPhone: delivery.customerPhone ?? null,
    customerId: delivery.customerId ?? null,
    customerNumber: delivery.customerNumber ?? null,
    orderNumber: delivery.orderNumber ?? null,
    invoiceNumber: delivery.invoiceNumber,
    invoiceDate: delivery.invoiceDate ? firestore.Timestamp.fromDate(delivery.invoiceDate) : null,
    items: delivery.items.map(deliveryItemToMap),
    invoiceTotal: delivery.invoiceTotal ?? null,
    taxAmount: delivery.taxAmount ?? null,
    discountAmount: delivery.discountAmount ?? null,
    currency: delivery.currency ?? 'ZAR',
    vehicleUsed: delivery.vehicleUsed ?? null,
    isThirdPartyTransport: delivery.isThirdPartyTransport,
    thirdPartyProviderName: delivery.thirdPartyProviderName ?? null,
    thirdPartyDriverName: delivery.thirdPartyDriverName ?? null,
    thirdPartyDriverPhone: delivery.thirdPartyDriverPhone ?? null,
    thirdPartyVehicleInfo: delivery.thirdPartyVehicleInfo ?? null,
    uploadToken: delivery.uploadToken ?? null,
    thirdPartyDocs: delivery.thirdPartyDocs ?? null,
    status: delivery.status,
    scheduledDate: firestore.Timestamp.fromDate(delivery.scheduledDate),
    createdAt: firestore.Timestamp.fromDate(delivery.createdAt),
    deliveredAt: delivery.deliveredAt ? firestore.Timestamp.fromDate(delivery.deliveredAt) : null,
    notes: delivery.notes ?? null,
    podId: delivery.podId ?? null,
  };
}
