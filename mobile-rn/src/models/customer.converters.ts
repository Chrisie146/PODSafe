import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { Customer, CustomerStats, CustomerType } from './customer';

/**
 * Ported from Customer.fromFirestore/toFirestore + CustomerStats.fromMap/toMap in
 * lib/models/customer_model.dart (verified against source on 2026-06-22).
 */
const VALID_CUSTOMER_TYPES: CustomerType[] = ['business', 'residential'];

function customerStatsFromMap(map: Record<string, unknown>): CustomerStats {
  return {
    totalDeliveries: Number(map.totalDeliveries ?? 0),
    lastDelivery: (map.lastDelivery as FirebaseFirestoreTypes.Timestamp | undefined)?.toDate?.(),
    firstDelivery: (map.firstDelivery as FirebaseFirestoreTypes.Timestamp | undefined)?.toDate?.(),
  };
}

function customerStatsToMap(stats: CustomerStats): Record<string, unknown> {
  return {
    totalDeliveries: stats.totalDeliveries,
    lastDelivery: stats.lastDelivery ? firestore.Timestamp.fromDate(stats.lastDelivery) : null,
    firstDelivery: stats.firstDelivery ? firestore.Timestamp.fromDate(stats.firstDelivery) : null,
  };
}

export function customerFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): Customer {
  const data = doc.data() ?? {};
  const customerType = VALID_CUSTOMER_TYPES.includes(data.customerType) ? (data.customerType as CustomerType) : 'business';

  return {
    id: doc.id,
    companyId: data.companyId ?? '',
    customerNumber: data.customerNumber ?? '',
    name: data.name ?? '',
    address: data.address ?? '',
    contactPerson: data.contactPerson,
    phone: data.phone,
    email: data.email,
    deliveryInstructions: data.deliveryInstructions,
    accountNumber: data.accountNumber,
    customerType,
    stats: data.stats != null ? customerStatsFromMap(data.stats) : { totalDeliveries: 0 },
    isActive: data.isActive ?? true,
    isFavorite: data.isFavorite ?? false,
    tags: Array.isArray(data.tags) ? (data.tags as string[]) : [],
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    updatedAt: data.updatedAt?.toDate?.() ?? new Date(),
  };
}

export function customerToFirestore(customer: Customer): Record<string, unknown> {
  return {
    companyId: customer.companyId,
    customerNumber: customer.customerNumber,
    name: customer.name,
    address: customer.address,
    contactPerson: customer.contactPerson ?? null,
    phone: customer.phone ?? null,
    email: customer.email ?? null,
    deliveryInstructions: customer.deliveryInstructions ?? null,
    accountNumber: customer.accountNumber ?? null,
    customerType: customer.customerType,
    stats: customerStatsToMap(customer.stats),
    isActive: customer.isActive,
    isFavorite: customer.isFavorite,
    tags: customer.tags,
    createdAt: firestore.Timestamp.fromDate(customer.createdAt),
    updatedAt: firestore.Timestamp.fromDate(customer.updatedAt),
  };
}
