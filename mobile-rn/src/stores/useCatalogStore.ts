import { create } from 'zustand';
import { CatalogItem, ItemCategory, isCatalogItemNew, isCatalogItemTrending, itemCategoryDisplayName } from '../models/catalogItem';
import { CatalogRepository } from '../repositories/catalogRepository';

/**
 * Replaces lib/providers/catalog_provider.dart's CatalogProvider (ChangeNotifier).
 * Faithfully ports its filter/search/sort state machine, including the quirk that
 * `sortItems()` sorts the current filtered list in place rather than being remembered
 * across subsequent filter/search changes (those always rebuild from the unfiltered
 * `items` list) — same behavior as the Dart source.
 */
const catalogRepository = new CatalogRepository();

export type SortOption = 'usageCount' | 'description' | 'dateCreated' | 'category';

/** Mirrors SortOptionExtension.displayName. */
export function sortOptionDisplayName(option: SortOption): string {
  switch (option) {
    case 'usageCount':
      return 'Most Used';
    case 'description':
      return 'Description (A-Z)';
    case 'dateCreated':
      return 'Recently Added';
    case 'category':
      return 'Category';
  }
}

interface CatalogState {
  companyId: string | null;
  allItems: CatalogItem[];
  items: CatalogItem[];
  isLoading: boolean;
  errorMessage: string | null;
  searchQuery: string;
  selectedCategory: ItemCategory | null;
  hasItems: boolean;

  popularItems: () => CatalogItem[];
  trendingItems: () => CatalogItem[];
  newItems: () => CatalogItem[];
  getItemsByCategory: (category: ItemCategory) => CatalogItem[];
  getItemById: (itemId: string) => CatalogItem | null;
  descriptionExists: (description: string, excludeItemId?: string) => boolean;

  initialize: (companyId: string) => Promise<void>;
  loadCatalog: (companyId: string) => Promise<void>;
  search: (companyId: string, query: string) => Promise<void>;
  filterByCategory: (category: ItemCategory | null) => void;
  clearFilters: () => void;
  sortItems: (sortBy: SortOption) => void;
  clearError: () => void;

  addItem: (companyId: string, item: CatalogItem) => Promise<string>;
  updateItem: (companyId: string, itemId: string, item: CatalogItem) => Promise<void>;
  deleteItem: (companyId: string, itemId: string, userId: string) => Promise<void>;
  incrementUsage: (companyId: string, itemId: string) => Promise<void>;
  batchIncrementUsage: (companyId: string, itemIds: string[]) => Promise<void>;
  getStats: (companyId: string) => ReturnType<CatalogRepository['getCatalogStats']>;
  bulkImport: (companyId: string, userId: string, items: Array<Record<string, unknown>>) => ReturnType<CatalogRepository['bulkImportItems']>;
}

function applyFilters(allItems: CatalogItem[], selectedCategory: ItemCategory | null, searchQuery: string): CatalogItem[] {
  let filtered = allItems;
  if (selectedCategory != null) {
    filtered = filtered.filter((item) => item.category === selectedCategory);
  }
  if (searchQuery.length > 0) {
    const q = searchQuery.toLowerCase();
    filtered = filtered.filter((item) => item.description.toLowerCase().includes(q) || (item.unit?.toLowerCase() ?? '').includes(q));
  }
  return filtered;
}

function filterByCategoryOnly(items: CatalogItem[], selectedCategory: ItemCategory | null): CatalogItem[] {
  if (selectedCategory == null) return items;
  return items.filter((item) => item.category === selectedCategory);
}

export const useCatalogStore = create<CatalogState>((set, get) => ({
  companyId: null,
  allItems: [],
  items: [],
  isLoading: false,
  errorMessage: null,
  searchQuery: '',
  selectedCategory: null,
  hasItems: false,

  popularItems: () => [...get().allItems].sort((a, b) => b.usageCount - a.usageCount).slice(0, 10),

  trendingItems: () =>
    get()
      .allItems.filter(isCatalogItemTrending)
      .sort((a, b) => b.usageCount - a.usageCount),

  newItems: () =>
    get()
      .allItems.filter(isCatalogItemNew)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),

  getItemsByCategory: (category) => get().allItems.filter((item) => item.category === category),

  getItemById: (itemId) => get().allItems.find((item) => item.id === itemId) ?? null,

  descriptionExists: (description, excludeItemId) =>
    get().allItems.some((item) => item.description.toLowerCase() === description.toLowerCase() && item.id !== excludeItemId),

  initialize: async (companyId) => {
    const { companyId: currentCompanyId, allItems } = get();
    if (currentCompanyId === companyId && allItems.length > 0) {
      return;
    }
    set({ companyId });
    await get().loadCatalog(companyId);
  },

  loadCatalog: async (companyId) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const allItems = await catalogRepository.getCatalogItems(companyId);
      const { selectedCategory, searchQuery } = get();
      let items = applyFilters(allItems, selectedCategory, searchQuery);
      if (items.length > 0) {
        items = [...items].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      }
      set({ allItems, items, hasItems: allItems.length > 0, isLoading: false });
    } catch (e) {
      set({ errorMessage: (e as Error).message, isLoading: false });
    }
  },

  search: async (companyId, query) => {
    set({ searchQuery: query });
    const { allItems, selectedCategory } = get();

    if (query.length === 0) {
      set({ items: filterByCategoryOnly(allItems, selectedCategory) });
      return;
    }

    try {
      const results = await catalogRepository.searchItems(companyId, query);
      set({ items: filterByCategoryOnly(results, selectedCategory) });
    } catch (e) {
      set({ errorMessage: (e as Error).message });
    }
  },

  filterByCategory: (category) => {
    set({ selectedCategory: category });
    const { allItems, searchQuery } = get();
    set({ items: applyFilters(allItems, category, searchQuery) });
  },

  clearFilters: () => {
    set({ searchQuery: '', selectedCategory: null });
    const { allItems } = get();
    set({ items: applyFilters(allItems, null, '') });
  },

  sortItems: (sortBy) => {
    set((state) => {
      const sorted = [...state.items];
      switch (sortBy) {
        case 'usageCount':
          sorted.sort((a, b) => b.usageCount - a.usageCount);
          break;
        case 'description':
          sorted.sort((a, b) => a.description.localeCompare(b.description));
          break;
        case 'dateCreated':
          sorted.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
          break;
        case 'category':
          sorted.sort((a, b) => itemCategoryDisplayName(a.category).localeCompare(itemCategoryDisplayName(b.category)));
          break;
      }
      return { items: sorted };
    });
  },

  clearError: () => set({ errorMessage: null }),

  addItem: async (companyId, item) => {
    try {
      const itemId = await catalogRepository.createCatalogItem(companyId, item);
      await get().loadCatalog(companyId);
      return itemId;
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      throw e;
    }
  },

  updateItem: async (companyId, itemId, item) => {
    try {
      await catalogRepository.updateCatalogItem(companyId, itemId, item);
      await get().loadCatalog(companyId);
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      throw e;
    }
  },

  deleteItem: async (companyId, itemId, userId) => {
    try {
      await catalogRepository.deleteCatalogItem(companyId, itemId, userId);
      set((state) => {
        const allItems = state.allItems.filter((item) => item.id !== itemId);
        return { allItems, items: applyFilters(allItems, state.selectedCategory, state.searchQuery) };
      });
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      throw e;
    }
  },

  incrementUsage: async (companyId, itemId) => {
    try {
      await catalogRepository.incrementUsageCount(companyId, itemId);
      set((state) => {
        const now = new Date();
        const allItems = state.allItems.map((item) => (item.id === itemId ? { ...item, usageCount: item.usageCount + 1, lastUsed: now } : item));
        return { allItems, items: applyFilters(allItems, state.selectedCategory, state.searchQuery) };
      });
    } catch (e) {
      console.warn(`Failed to increment usage: ${(e as Error).message}`);
    }
  },

  batchIncrementUsage: async (companyId, itemIds) => {
    try {
      await catalogRepository.batchIncrementUsageCount(companyId, itemIds);
      set((state) => {
        const now = new Date();
        const idSet = new Set(itemIds);
        const allItems = state.allItems.map((item) => (idSet.has(item.id) ? { ...item, usageCount: item.usageCount + 1, lastUsed: now } : item));
        return { allItems, items: applyFilters(allItems, state.selectedCategory, state.searchQuery) };
      });
    } catch (e) {
      console.warn(`Failed to batch increment usage: ${(e as Error).message}`);
    }
  },

  getStats: (companyId) => catalogRepository.getCatalogStats(companyId),

  bulkImport: async (companyId, userId, items) => {
    try {
      const result = await catalogRepository.bulkImportItems(companyId, userId, items);
      await get().loadCatalog(companyId);
      return result;
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      throw e;
    }
  },
}));
