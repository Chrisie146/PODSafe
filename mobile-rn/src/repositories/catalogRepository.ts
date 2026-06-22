import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { CatalogItem, ItemCategory } from '../models/catalogItem';
import { catalogItemFromFirestore, catalogItemToMap } from '../models/catalogItem.converters';

/**
 * Ported from lib/services/item_catalog_service.dart (verified against source on
 * 2026-06-22), following the constructor-injected repository pattern from
 * deliveryRepository.ts/claimRepository.ts. CatalogProvider's own logic (search/filter/
 * sort state, popular/trending/new derived lists) is UI state and belongs in
 * useCatalogStore.ts, not here — this repository mirrors ItemCatalogService 1:1, which
 * is the real Firestore-backed layer the Dart provider delegates to.
 */
export class CatalogRepository {
  constructor(private firestoreInstance: FirebaseFirestoreTypes.Module = firestore()) {}

  private catalogRef(companyId: string) {
    return this.firestoreInstance.collection('companies').doc(companyId).collection('itemCatalog');
  }

  /** Mirrors getCatalogItems(): active items, sorted by usage count descending. */
  async getCatalogItems(companyId: string): Promise<CatalogItem[]> {
    const snapshot = await this.catalogRef(companyId).where('isActive', '==', true).get();
    const items = snapshot.docs.map(catalogItemFromFirestore);
    items.sort((a, b) => b.usageCount - a.usageCount);
    return items;
  }

  /** Mirrors getCatalogItemsByCategory(). */
  async getCatalogItemsByCategory(companyId: string, category: ItemCategory): Promise<CatalogItem[]> {
    const snapshot = await this.catalogRef(companyId).where('isActive', '==', true).where('category', '==', category).get();
    const items = snapshot.docs.map(catalogItemFromFirestore);
    items.sort((a, b) => b.usageCount - a.usageCount);
    return items;
  }

  /** Mirrors getPopularItems(). */
  async getPopularItems(companyId: string, limit = 10): Promise<CatalogItem[]> {
    const snapshot = await this.catalogRef(companyId).where('isActive', '==', true).get();
    const items = snapshot.docs.map(catalogItemFromFirestore);
    items.sort((a, b) => b.usageCount - a.usageCount);
    return items.slice(0, limit);
  }

  /** Mirrors searchItems(): client-side filter + relevance sort (exact > startsWith > usage). */
  async searchItems(companyId: string, query: string): Promise<CatalogItem[]> {
    const snapshot = await this.catalogRef(companyId).where('isActive', '==', true).get();
    const allItems = snapshot.docs.map(catalogItemFromFirestore);

    const queryLower = query.toLowerCase();
    const filtered = allItems.filter((item) => {
      const descLower = item.description.toLowerCase();
      const unitLower = item.unit?.toLowerCase() ?? '';
      return descLower.includes(queryLower) || unitLower.includes(queryLower);
    });

    filtered.sort((a, b) => {
      const aDesc = a.description.toLowerCase();
      const bDesc = b.description.toLowerCase();

      if (aDesc === queryLower && bDesc !== queryLower) return -1;
      if (bDesc === queryLower && aDesc !== queryLower) return 1;
      if (aDesc.startsWith(queryLower) && !bDesc.startsWith(queryLower)) return -1;
      if (bDesc.startsWith(queryLower) && !aDesc.startsWith(queryLower)) return 1;

      return b.usageCount - a.usageCount;
    });

    return filtered;
  }

  /** Mirrors getCatalogItem(). */
  async getCatalogItem(companyId: string, itemId: string): Promise<CatalogItem | null> {
    const doc = await this.catalogRef(companyId).doc(itemId).get();
    return doc.exists() ? catalogItemFromFirestore(doc) : null;
  }

  /** Mirrors createCatalogItem(): rejects on duplicate description. */
  async createCatalogItem(companyId: string, item: CatalogItem): Promise<string> {
    const existing = await this.checkDuplicateDescription(companyId, item.description);
    if (existing) {
      throw new Error(`An item with this description already exists: "${existing.description}"`);
    }

    const docRef = await this.catalogRef(companyId).add(catalogItemToMap(item));
    return docRef.id;
  }

  /** Mirrors updateCatalogItem(): rejects on duplicate description (excluding itself). */
  async updateCatalogItem(companyId: string, itemId: string, item: CatalogItem): Promise<void> {
    const existing = await this.checkDuplicateDescription(companyId, item.description, itemId);
    if (existing) {
      throw new Error(`An item with this description already exists: "${existing.description}"`);
    }

    await this.catalogRef(companyId).doc(itemId).update(catalogItemToMap(item));
  }

  /** Mirrors deleteCatalogItem(): soft delete by marking inactive. */
  async deleteCatalogItem(companyId: string, itemId: string, userId: string): Promise<void> {
    await this.catalogRef(companyId).doc(itemId).update({
      isActive: false,
      updatedAt: firestore.Timestamp.now(),
      updatedBy: userId,
    });
  }

  /** Mirrors permanentlyDeleteCatalogItem(). */
  async permanentlyDeleteCatalogItem(companyId: string, itemId: string): Promise<void> {
    await this.catalogRef(companyId).doc(itemId).delete();
  }

  /** Mirrors incrementUsageCount(): non-critical, failure is swallowed. */
  async incrementUsageCount(companyId: string, itemId: string): Promise<void> {
    try {
      await this.catalogRef(companyId).doc(itemId).update({
        usageCount: firestore.FieldValue.increment(1),
        lastUsed: firestore.Timestamp.now(),
      });
    } catch {
      // Non-critical, mirrors the Dart source's warning-only log.
    }
  }

  /** Mirrors batchIncrementUsageCount(). */
  async batchIncrementUsageCount(companyId: string, itemIds: string[]): Promise<void> {
    try {
      const batch = this.firestoreInstance.batch();
      const now = firestore.Timestamp.now();
      for (const itemId of itemIds) {
        batch.update(this.catalogRef(companyId).doc(itemId), { usageCount: firestore.FieldValue.increment(1), lastUsed: now });
      }
      await batch.commit();
    } catch {
      // Non-critical, mirrors the Dart source's warning-only log.
    }
  }

  /** Mirrors _checkDuplicateDescription(). */
  private async checkDuplicateDescription(companyId: string, description: string, excludeItemId?: string): Promise<CatalogItem | null> {
    try {
      const snapshot = await this.catalogRef(companyId).where('description', '==', description).where('isActive', '==', true).limit(1).get();
      if (snapshot.docs.length === 0) return null;

      const item = catalogItemFromFirestore(snapshot.docs[0]);
      if (excludeItemId != null && item.id === excludeItemId) return null;
      return item;
    } catch {
      return null;
    }
  }

  /** Mirrors getCatalogStats(). */
  async getCatalogStats(companyId: string): Promise<{
    totalItems: number;
    activeItems: number;
    inactiveItems: number;
    totalUsage: number;
    averageUsage: number;
    categoryCounts: Record<string, number>;
  }> {
    const snapshot = await this.catalogRef(companyId).get();

    let totalItems = 0;
    let activeItems = 0;
    let totalUsage = 0;
    const categoryCounts: Record<string, number> = {};

    snapshot.docs.forEach((doc) => {
      const item = catalogItemFromFirestore(doc);
      totalItems += 1;
      if (item.isActive) {
        activeItems += 1;
        totalUsage += item.usageCount;
        categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
      }
    });

    return {
      totalItems,
      activeItems,
      inactiveItems: totalItems - activeItems,
      totalUsage,
      averageUsage: activeItems > 0 ? totalUsage / activeItems : 0,
      categoryCounts,
    };
  }

  /** Mirrors streamCatalogItems(). Returns an unsubscribe function. */
  subscribeToCatalogItems(companyId: string, onChange: (items: CatalogItem[]) => void, onError?: (error: Error) => void): () => void {
    return this.catalogRef(companyId)
      .where('isActive', '==', true)
      .orderBy('usageCount', 'desc')
      .onSnapshot(
        (snapshot) => onChange(snapshot.docs.map(catalogItemFromFirestore)),
        (error) => onError?.(error as unknown as Error),
      );
  }

  /** Mirrors bulkImportItems(). */
  async bulkImportItems(
    companyId: string,
    userId: string,
    items: Array<Record<string, unknown>>,
  ): Promise<{ success: number; errors: string[]; total: number }> {
    const batch = this.firestoreInstance.batch();
    const now = new Date();
    let successCount = 0;
    const errors: string[] = [];

    items.forEach((itemData, i) => {
      try {
        const description = String(itemData.description ?? '').trim();
        if (description.length === 0) {
          errors.push(`Row ${i + 1}: Description is required`);
          return;
        }

        const catalogItem: CatalogItem = {
          id: '',
          companyId,
          description,
          unit: itemData.unit != null ? String(itemData.unit).trim() : undefined,
          defaultQuantity: itemData.defaultQuantity != null ? parseFloat(String(itemData.defaultQuantity)) : undefined,
          unitPrice: itemData.unitPrice != null ? parseFloat(String(itemData.unitPrice)) : undefined,
          category: (itemData.category as ItemCategory) ?? 'general',
          isActive: true,
          usageCount: 0,
          createdAt: now,
          createdBy: userId,
          updatedAt: now,
          updatedBy: userId,
        };

        const docRef = this.catalogRef(companyId).doc();
        batch.set(docRef, catalogItemToMap(catalogItem));
        successCount += 1;
      } catch (e) {
        errors.push(`Row ${i + 1}: ${(e as Error).message}`);
      }
    });

    await batch.commit();
    return { success: successCount, errors, total: items.length };
  }
}
