/**
 * Ported from lib/models/catalog_item_model.dart (verified against source on 2026-06-22).
 */
export type ItemCategory =
  | 'general'
  | 'furniture'
  | 'officeSupplies'
  | 'electronics'
  | 'documents'
  | 'bulkGoods'
  | 'equipment'
  | 'other';

const CATEGORY_DISPLAY_NAMES: Record<ItemCategory, string> = {
  general: 'General Items',
  furniture: 'Furniture',
  officeSupplies: 'Office Supplies',
  electronics: 'Electronics',
  documents: 'Documents',
  bulkGoods: 'Bulk Goods',
  equipment: 'Equipment',
  other: 'Other',
};

const CATEGORY_ICONS: Record<ItemCategory, string> = {
  general: '📦',
  furniture: '🪑',
  officeSupplies: '💼',
  electronics: '🖥️',
  documents: '📋',
  bulkGoods: '🚚',
  equipment: '⚙️',
  other: '📦',
};

const ALL_ITEM_CATEGORIES: ItemCategory[] = ['general', 'furniture', 'officeSupplies', 'electronics', 'documents', 'bulkGoods', 'equipment', 'other'];

/** Mirrors ItemCategory.displayName. */
export function itemCategoryDisplayName(category: ItemCategory): string {
  return CATEGORY_DISPLAY_NAMES[category];
}

/** Mirrors ItemCategory.icon. */
export function itemCategoryIcon(category: ItemCategory): string {
  return CATEGORY_ICONS[category];
}

/** Mirrors ItemCategory.fromString(). */
export function itemCategoryFromString(value: string | null | undefined): ItemCategory {
  if (value == null) return 'general';
  return ALL_ITEM_CATEGORIES.includes(value as ItemCategory) ? (value as ItemCategory) : 'general';
}

export interface CatalogItem {
  id: string;
  companyId: string;
  description: string;
  sku?: string;
  unit?: string;
  defaultQuantity?: number;
  unitPrice?: number;
  /** Deprecated: use categoryId instead. */
  category: ItemCategory;
  categoryId?: string;
  isActive: boolean;
  usageCount: number;
  lastUsed?: Date;
  createdAt: Date;
  createdBy: string;
  updatedAt: Date;
  updatedBy: string;
}

/** Mirrors CatalogItem.isPopular (used 50+ times). */
export function isCatalogItemPopular(item: CatalogItem): boolean {
  return item.usageCount >= 50;
}

/** Mirrors CatalogItem.isTrending (used 10+ times in the last 30 days). */
export function isCatalogItemTrending(item: CatalogItem): boolean {
  if (!item.lastUsed) return false;
  const daysSinceLastUse = (Date.now() - item.lastUsed.getTime()) / (1000 * 60 * 60 * 24);
  return item.usageCount >= 10 && daysSinceLastUse <= 30;
}

/** Mirrors CatalogItem.isNew (created within 7 days). */
export function isCatalogItemNew(item: CatalogItem): boolean {
  const daysSinceCreation = (Date.now() - item.createdAt.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceCreation <= 7;
}

/** Mirrors CatalogItem.displayText. */
export function catalogItemDisplayText(item: CatalogItem): string {
  return `${item.description}${item.unit ? ` (${item.unit})` : ''}`;
}

/** Mirrors CatalogItem.formattedPrice. */
export function catalogItemFormattedPrice(item: CatalogItem): string {
  return item.unitPrice == null ? 'No price' : `R ${item.unitPrice.toFixed(2)}`;
}
