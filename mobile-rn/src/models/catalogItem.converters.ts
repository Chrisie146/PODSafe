import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { CatalogItem, itemCategoryFromString } from './catalogItem';

/**
 * Ported from CatalogItem.fromFirestore/fromMap/toMap in
 * lib/models/catalog_item_model.dart (verified against source on 2026-06-22).
 */
export function catalogItemFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): CatalogItem {
  const data = doc.data() ?? {};
  return catalogItemFromMap(data, doc.id);
}

export function catalogItemFromMap(map: Record<string, unknown>, id: string): CatalogItem {
  return {
    id,
    companyId: (map.companyId as string) ?? '',
    description: (map.description as string) ?? '',
    sku: map.sku as string | undefined,
    unit: map.unit as string | undefined,
    defaultQuantity: map.defaultQuantity != null ? Number(map.defaultQuantity) : undefined,
    unitPrice: map.unitPrice != null ? Number(map.unitPrice) : undefined,
    category: itemCategoryFromString(map.category as string | undefined),
    categoryId: map.categoryId as string | undefined,
    isActive: (map.isActive as boolean) ?? true,
    usageCount: Number(map.usageCount ?? 0),
    lastUsed: (map.lastUsed as FirebaseFirestoreTypes.Timestamp | undefined)?.toDate?.(),
    createdAt: (map.createdAt as FirebaseFirestoreTypes.Timestamp).toDate(),
    createdBy: (map.createdBy as string) ?? '',
    updatedAt: (map.updatedAt as FirebaseFirestoreTypes.Timestamp).toDate(),
    updatedBy: (map.updatedBy as string) ?? '',
  };
}

export function catalogItemToMap(item: CatalogItem): Record<string, unknown> {
  return {
    companyId: item.companyId,
    description: item.description,
    sku: item.sku ?? null,
    unit: item.unit ?? null,
    defaultQuantity: item.defaultQuantity ?? null,
    unitPrice: item.unitPrice ?? null,
    category: item.category,
    categoryId: item.categoryId ?? null,
    isActive: item.isActive,
    usageCount: item.usageCount,
    lastUsed: item.lastUsed ? firestore.Timestamp.fromDate(item.lastUsed) : null,
    createdAt: firestore.Timestamp.fromDate(item.createdAt),
    createdBy: item.createdBy,
    updatedAt: firestore.Timestamp.fromDate(item.updatedAt),
    updatedBy: item.updatedBy,
  };
}
