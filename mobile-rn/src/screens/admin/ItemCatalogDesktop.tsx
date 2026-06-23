import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useCatalogStore, SortOption, sortOptionDisplayName } from '../../stores/useCatalogStore';
import {
  CatalogItem,
  ItemCategory,
  catalogItemFormattedPrice,
  isCatalogItemNew,
  isCatalogItemPopular,
  itemCategoryDisplayName,
  itemCategoryIcon,
} from '../../models/catalogItem';
import { exportCatalogItems } from '../../repositories/csvExportService';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const ALL_CATEGORIES: ItemCategory[] = ['general', 'furniture', 'officeSupplies', 'electronics', 'documents', 'bulkGoods', 'equipment', 'other'];
const ALL_SORT_OPTIONS: SortOption[] = ['dateCreated', 'usageCount', 'description', 'category'];

const COLS = {
  checkbox: { width: 36 },
  index: { width: 36 },
  item: { width: 240 },
  sku: { width: 100 },
  category: { width: 140 },
  unit: { width: 90 },
  qty: { width: 90 },
  price: { width: 90 },
  used: { width: 90 },
  actions: { width: 80 },
};
const TABLE_WIDTH = Object.values(COLS).reduce((sum, c) => sum + c.width, 0);

/**
 * Ported from lib/screens/admin/item_catalog_desktop.dart (verified against source on
 * 2026-06-23). Desktop-only, zero admin mobile equivalent (confirmed via vault Inventory).
 * Registered in AdminStack.tsx, same as ChatListDesktop.tsx — AdminWebRoutes.tsx/index.web.js
 * don't exist yet.
 *
 * Skips `item_category_model.dart`/`item_category_service.dart` entirely — confirmed by grep
 * to have zero consumers anywhere in `lib/` (not even this screen), genuinely dead code that
 * was never wired to anything. `ManageCategoriesDialog`'s "customizations" are an in-memory
 * `static final Map` in the Dart source (comment: "in a real app, this would be saved to
 * Firestore") — ported faithfully as decorative, not fixed, consistent with the Role
 * Permissions / Notification Settings precedent in the Risk Register.
 *
 * Two real bugs found and fixed (not faithfully ported):
 * 1. `_exportToCsv()` built a CSV string and only showed a SnackBar, never wrote/shared it —
 *    wired for real via the new `exportCatalogItems()`.
 * 2. `_duplicateItem()` built a copy with `id: ''` and passed it into the *same* add/edit
 *    dialog as `item:`, which decides create-vs-update by `widget.item == null` — so Duplicate
 *    always took the UPDATE branch and called `updateItem(companyId, '', ...)` with an empty
 *    document ID, which would fail every time. Fixed by keeping "is this a duplicate" a
 *    separate concept from "is this an edit": duplicating seeds the CREATE form with the
 *    source item's values instead of masquerading as an edit of a real document.
 *
 * Also fixed: the Dart table's rows have no tap handler and no selection checkboxes at all —
 * `_isMultiSelectMode`/`_selectedItemIds`/`_toggleItemSelection`/`_selectAllItems` are built
 * but never wired to anything in `_buildItemsTable`, and `_buildDetailPanel` reads
 * `_selectedItemIds` (never `_selectedItem`, which `_selectItem()` sets but nothing calls) —
 * so multi-select, bulk actions, and the detail panel are all unreachable in production.
 * Since this table is written fresh (no DataTable equivalent here), it's built working:
 * a checkbox column drives multi-select, and a plain row press opens the detail panel.
 *
 * Keyboard shortcuts (Ctrl+F/Ctrl+A/Esc/F5) are dropped — same scope-trim as
 * VehicleManagementDesktop.tsx (see Risk Register #14): no hardware-keyboard listener without
 * a new native module, and every action remains reachable via on-screen buttons.
 */
export default function ItemCatalogDesktop({ navigation }: { navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void } }) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const items = useCatalogStore((s) => s.items);
  const isLoading = useCatalogStore((s) => s.isLoading);
  const initialize = useCatalogStore((s) => s.initialize);
  const search = useCatalogStore((s) => s.search);
  const filterByCategory = useCatalogStore((s) => s.filterByCategory);
  const clearFilters = useCatalogStore((s) => s.clearFilters);
  const sortItems = useCatalogStore((s) => s.sortItems);
  const deleteItem = useCatalogStore((s) => s.deleteItem);
  const updateItem = useCatalogStore((s) => s.updateItem);
  const getItemById = useCatalogStore((s) => s.getItemById);

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<ItemCategory | null>(null);
  const [sortBy, setSortBy] = useState<SortOption>('dateCreated');
  const [showFilters, setShowFilters] = useState(true);
  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [selectedItem, setSelectedItem] = useState<CatalogItem | null>(null);
  const [formItem, setFormItem] = useState<CatalogItem | null | undefined>(undefined);
  const [duplicateSeed, setDuplicateSeed] = useState<CatalogItem | undefined>(undefined);
  const [showCategoryManager, setShowCategoryManager] = useState(false);
  const [showBulkCategoryModal, setShowBulkCategoryModal] = useState(false);

  useEffect(() => {
    if (currentUser) initialize(currentUser.companyId);
  }, [currentUser, initialize]);

  const stats = useMemo(() => {
    const total = items.length;
    const active = items.filter((i) => i.isActive).length;
    const categories = new Set(items.map((i) => i.categoryId ?? i.category)).size;
    return { total, active, categories };
  }, [items]);

  const allSelected = items.length > 0 && items.every((i) => selectedIds.has(i.id));

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Error: No company ID</Text>
      </View>
    );
  }

  const handleSearch = (query: string) => {
    setSearchQuery(query);
    search(currentUser.companyId, query);
  };

  const handleFilterByCategory = (category: ItemCategory | null) => {
    setSelectedCategory(category);
    filterByCategory(category);
  };

  const handleSort = (option: SortOption) => {
    setSortBy(option);
    sortItems(option);
  };

  const handleClearFilters = () => {
    setSearchQuery('');
    setSelectedCategory(null);
    clearFilters();
  };

  const toggleSelectOne = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleSelectAll = () => {
    setSelectedIds(allSelected ? new Set() : new Set(items.map((i) => i.id)));
  };

  const handleExportCsv = async () => {
    try {
      await exportCatalogItems(items);
    } catch (e) {
      Alert.alert('Error', `Failed to export: ${(e as Error).message}`);
    }
  };

  const handleDeleteItem = (item: CatalogItem) => {
    Alert.alert('Delete Item', `Are you sure you want to delete "${item.description}"?\n\nThis will remove it from the catalog, but won't affect existing deliveries.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteItem(currentUser.companyId, item.id, currentUser.id);
            setSelectedItem((prev) => (prev?.id === item.id ? null : prev));
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  const handleBulkDelete = () => {
    const count = selectedIds.size;
    Alert.alert('Delete Selected Items', `Are you sure you want to delete ${count} item${count === 1 ? '' : 's'}? This action cannot be undone.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            for (const id of selectedIds) {
              await deleteItem(currentUser.companyId, id, currentUser.id);
            }
            setSelectedIds(new Set());
            setIsMultiSelectMode(false);
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  const handleBulkCategoryChange = async (category: ItemCategory) => {
    setShowBulkCategoryModal(false);
    try {
      for (const id of selectedIds) {
        const item = getItemById(id);
        if (item) await updateItem(currentUser.companyId, id, { ...item, category });
      }
      setSelectedIds(new Set());
      setIsMultiSelectMode(false);
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    }
  };

  const handleDuplicate = (item: CatalogItem) => {
    setDuplicateSeed({ ...item, description: `${item.description} (Copy)`, usageCount: 0 });
    setFormItem(null);
    setSelectedItem(null);
  };

  const closeForm = () => {
    setFormItem(undefined);
    setDuplicateSeed(undefined);
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading3}>Item Catalog Management</Text>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => setShowFilters((p) => !p)}>
            <Text style={styles.headerBarAction}>🔍</Text>
          </Pressable>
          <Pressable onPress={() => setIsMultiSelectMode((p) => !p)}>
            <Text style={styles.headerBarAction}>{isMultiSelectMode ? '☑' : '☐'}</Text>
          </Pressable>
          <Pressable onPress={handleExportCsv}>
            <Text style={styles.headerBarAction}>⬇</Text>
          </Pressable>
          <Pressable style={styles.headerBarButton} onPress={() => setFormItem(null)}>
            <Text style={styles.headerBarButtonText}>+ Add Item</Text>
          </Pressable>
          <Pressable style={[styles.headerBarButton, styles.headerBarButtonSuccess]} onPress={() => navigation.navigate('BulkItemCreation')}>
            <Text style={styles.headerBarButtonText}>📦 Bulk Create</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.body}>
        {showFilters ? (
          <View style={styles.sidebar}>
            <ScrollView contentContainerStyle={styles.sidebarContent}>
              <View style={styles.sidebarHeaderRow}>
                <Text style={styles.sidebarTitle}>Filters</Text>
                <Pressable onPress={handleClearFilters}>
                  <Text style={styles.sidebarClear}>Clear</Text>
                </Pressable>
              </View>
              <View style={styles.divider} />

              <Text style={styles.sidebarLabel}>Search Items</Text>
              <TextInput style={styles.input} placeholder="Search by description or SKU..." value={searchQuery} onChangeText={handleSearch} />

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Category</Text>
              <View style={styles.chipWrap}>
                <Chip label="All Categories" selected={selectedCategory === null} onPress={() => handleFilterByCategory(null)} />
                {ALL_CATEGORIES.map((category) => (
                  <Chip
                    key={category}
                    label={`${itemCategoryIcon(category)} ${itemCategoryDisplayName(category)}`}
                    selected={selectedCategory === category}
                    onPress={() => handleFilterByCategory(category)}
                  />
                ))}
              </View>

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Sort By</Text>
              {ALL_SORT_OPTIONS.map((option) => (
                <Pressable key={option} style={styles.sortOptionRow} onPress={() => handleSort(option)}>
                  <Text style={styles.sortOptionGlyph}>{sortBy === option ? '◉' : '○'}</Text>
                  <Text style={styles.sortOptionLabel}>{sortOptionDisplayName(option)}</Text>
                </Pressable>
              ))}

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Quick Actions</Text>
              <Pressable style={styles.modalOutlinedButton} onPress={() => setShowCategoryManager(true)}>
                <Text style={styles.modalOutlinedText}>🏷 Manage Categories</Text>
              </Pressable>
            </ScrollView>
          </View>
        ) : null}

        <View style={styles.mainArea}>
          <View style={styles.statsBar}>
            <MiniStat label="Total Items" value={stats.total} icon="📦" color={colors.info} />
            <MiniStat label="Active Items" value={stats.active} icon="✓" color={colors.success} />
            <MiniStat label="Categories" value={stats.categories} icon="🏷" color={colors.primary} />
          </View>

          {isMultiSelectMode && selectedIds.size > 0 ? (
            <View style={styles.bulkBar}>
              <Text style={styles.bulkBarText}>
                {selectedIds.size} item{selectedIds.size === 1 ? '' : 's'} selected
              </Text>
              <Pressable
                onPress={() => {
                  setSelectedIds(new Set());
                  setIsMultiSelectMode(false);
                }}
              >
                <Text style={styles.bulkBarAction}>Clear</Text>
              </Pressable>
              <Pressable onPress={() => setShowBulkCategoryModal(true)}>
                <Text style={styles.bulkBarAction}>Change Category</Text>
              </Pressable>
              <Pressable onPress={handleBulkDelete}>
                <Text style={[styles.bulkBarAction, { color: colors.error }]}>Delete</Text>
              </Pressable>
            </View>
          ) : null}

          <View style={styles.contentRow}>
            <View style={styles.tableSection}>
              {isLoading && items.length === 0 ? (
                <ActivityIndicator color={colors.primary} style={styles.loadingIndicator} />
              ) : items.length === 0 ? (
                <View style={styles.centered}>
                  <Text style={styles.emptyIcon}>📦</Text>
                  <Text style={textStyles.heading3}>No catalog items yet</Text>
                  <Text style={[textStyles.bodyMedium, styles.emptySubtitle]}>Create your first item to get started</Text>
                  <Pressable style={styles.modalPrimaryButton} onPress={() => setFormItem(null)}>
                    <Text style={textStyles.buttonText}>+ Add First Item</Text>
                  </Pressable>
                </View>
              ) : (
                <ScrollView horizontal>
                  <View style={{ minWidth: TABLE_WIDTH }}>
                    <View style={styles.tableHeaderRow}>
                      {isMultiSelectMode ? (
                        <Pressable style={[styles.tableHeaderCell, COLS.checkbox]} onPress={toggleSelectAll}>
                          <Text style={styles.tableHeaderText}>{allSelected ? '☑' : '☐'}</Text>
                        </Pressable>
                      ) : null}
                      <View style={[styles.tableHeaderCell, COLS.index]}>
                        <Text style={styles.tableHeaderText}>#</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.item]}>
                        <Text style={styles.tableHeaderText}>Item</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.sku]}>
                        <Text style={styles.tableHeaderText}>SKU</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.category]}>
                        <Text style={styles.tableHeaderText}>Category</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.unit]}>
                        <Text style={styles.tableHeaderText}>Unit</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.qty]}>
                        <Text style={styles.tableHeaderText}>Default Qty</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.price]}>
                        <Text style={styles.tableHeaderText}>Price</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.used]}>
                        <Text style={styles.tableHeaderText}>Used</Text>
                      </View>
                      <View style={[styles.tableHeaderCell, COLS.actions]}>
                        <Text style={styles.tableHeaderText}>Actions</Text>
                      </View>
                    </View>
                    <ScrollView style={styles.tableBody}>
                      {items.map((item, index) => (
                        <CatalogRow
                          key={item.id}
                          item={item}
                          index={index}
                          isMultiSelectMode={isMultiSelectMode}
                          isSelected={selectedIds.has(item.id)}
                          isActiveRow={selectedItem?.id === item.id}
                          onToggleSelect={() => toggleSelectOne(item.id)}
                          onPress={() => setSelectedItem(item)}
                          onEdit={() => setFormItem(item)}
                          onDelete={() => handleDeleteItem(item)}
                        />
                      ))}
                    </ScrollView>
                  </View>
                </ScrollView>
              )}
            </View>

            {selectedItem ? (
              <DetailPanel
                item={selectedItem}
                onClose={() => setSelectedItem(null)}
                onEdit={() => setFormItem(selectedItem)}
                onDuplicate={() => handleDuplicate(selectedItem)}
                onDelete={() => handleDeleteItem(selectedItem)}
              />
            ) : null}
          </View>
        </View>
      </View>

      {formItem !== undefined ? (
        <CatalogItemFormModal companyId={currentUser.companyId} userId={currentUser.id} item={formItem} duplicateSeed={duplicateSeed} onClose={closeForm} />
      ) : null}

      <CategoryManagerModal visible={showCategoryManager} onClose={() => setShowCategoryManager(false)} />

      <BulkCategoryModal visible={showBulkCategoryModal} onClose={() => setShowBulkCategoryModal(false)} onApply={handleBulkCategoryChange} />
    </View>
  );
}

function MiniStat({ label, value, icon, color }: { label: string; value: number; icon: string; color: string }) {
  return (
    <View style={[styles.statCard, shadows.card]}>
      <View style={[styles.statIconBox, { backgroundColor: `${color}1A` }]}>
        <Text style={[styles.statIcon, { color }]}>{icon}</Text>
      </View>
      <View>
        <Text style={styles.statLabel}>{label}</Text>
        <Text style={styles.statValue}>{value}</Text>
      </View>
    </View>
  );
}

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function CatalogRow({
  item,
  index,
  isMultiSelectMode,
  isSelected,
  isActiveRow,
  onToggleSelect,
  onPress,
  onEdit,
  onDelete,
}: {
  item: CatalogItem;
  index: number;
  isMultiSelectMode: boolean;
  isSelected: boolean;
  isActiveRow: boolean;
  onToggleSelect: () => void;
  onPress: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <Pressable style={[styles.tableRow, isActiveRow && styles.tableRowActive]} onPress={isMultiSelectMode ? onToggleSelect : onPress}>
      {isMultiSelectMode ? (
        <View style={[styles.tableCell, COLS.checkbox]}>
          <Text>{isSelected ? '☑' : '☐'}</Text>
        </View>
      ) : null}
      <View style={[styles.tableCell, COLS.index]}>
        <Text style={styles.tableCellText}>{index + 1}</Text>
      </View>
      <View style={[styles.tableCell, COLS.item]}>
        <Text style={styles.tableCellTextBold} numberOfLines={1}>
          {item.description}
        </Text>
        {isCatalogItemPopular(item) || isCatalogItemNew(item) ? (
          <View style={styles.badgeRow}>
            {isCatalogItemPopular(item) ? (
              <View style={[styles.badge, styles.badgePopular]}>
                <Text style={styles.badgeText}>POPULAR</Text>
              </View>
            ) : null}
            {isCatalogItemNew(item) ? (
              <View style={[styles.badge, styles.badgeNew]}>
                <Text style={styles.badgeText}>NEW</Text>
              </View>
            ) : null}
          </View>
        ) : null}
      </View>
      <View style={[styles.tableCell, COLS.sku]}>
        <Text style={styles.tableCellText}>{item.sku ?? '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.category]}>
        <Text style={styles.tableCellText}>
          {itemCategoryIcon(item.category)} {itemCategoryDisplayName(item.category)}
        </Text>
      </View>
      <View style={[styles.tableCell, COLS.unit]}>
        <Text style={styles.tableCellText}>{item.unit ?? '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.qty]}>
        <Text style={styles.tableCellText}>{item.defaultQuantity ?? '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.price]}>
        <Text style={styles.tableCellText}>{item.unitPrice != null ? catalogItemFormattedPrice(item) : '-'}</Text>
      </View>
      <View style={[styles.tableCell, COLS.used]}>
        <Text style={[styles.tableCellText, { color: item.usageCount > 0 ? colors.success : colors.textSecondary }]}>{item.usageCount}×</Text>
      </View>
      <View style={[styles.tableCell, COLS.actions, styles.actionsCell]}>
        <Pressable onPress={onEdit}>
          <Text style={styles.actionIcon}>✎</Text>
        </Pressable>
        <Pressable onPress={onDelete}>
          <Text style={[styles.actionIcon, { color: colors.error }]}>🗑</Text>
        </Pressable>
      </View>
    </Pressable>
  );
}

function DetailRow({ label, value, valueColor }: { label: string; value: string; valueColor?: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={[styles.detailValue, valueColor ? { color: valueColor } : null]}>{value}</Text>
    </View>
  );
}

function DetailPanel({
  item,
  onClose,
  onEdit,
  onDuplicate,
  onDelete,
}: {
  item: CatalogItem;
  onClose: () => void;
  onEdit: () => void;
  onDuplicate: () => void;
  onDelete: () => void;
}) {
  const totalValue = item.unitPrice != null && item.defaultQuantity != null ? `R ${(item.unitPrice * item.defaultQuantity).toFixed(2)}` : 'N/A';

  return (
    <View style={styles.detailPanel}>
      <View style={styles.detailPanelHeader}>
        <Text style={styles.detailPanelTitle}>Item Details</Text>
        <Pressable onPress={onClose}>
          <Text style={styles.closeGlyph}>✕</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.detailPanelContent}>
        <View style={styles.imagePlaceholder}>
          <Text style={styles.imagePlaceholderIcon}>📦</Text>
        </View>

        <Text style={textStyles.heading3}>{item.description}</Text>
        <Text style={styles.detailSubtitle}>SKU: {item.sku ?? 'N/A'}</Text>

        <Text style={styles.detailSectionTitle}>Pricing</Text>
        <DetailRow label="Unit Price" value={item.unitPrice != null ? catalogItemFormattedPrice(item) : 'No price'} />
        <DetailRow label="Default Quantity" value={item.defaultQuantity?.toString() ?? 'N/A'} />
        <DetailRow label="Total Value" value={totalValue} />

        <Text style={styles.detailSectionTitle}>Stock Information</Text>
        <DetailRow label="Default Quantity" value={item.defaultQuantity?.toString() ?? 'N/A'} />
        <DetailRow label="Usage Count" value={String(item.usageCount)} />
        <DetailRow label="Status" value={item.isActive ? 'Active' : 'Inactive'} valueColor={item.isActive ? colors.success : colors.textSecondary} />

        <Text style={styles.detailSectionTitle}>Category</Text>
        <DetailRow label="Category" value={itemCategoryDisplayName(item.category)} />

        <View style={styles.detailActionsRow}>
          <Pressable style={styles.modalOutlinedButton} onPress={onEdit}>
            <Text style={styles.modalOutlinedText}>✎ Edit Item</Text>
          </Pressable>
          <Pressable style={styles.modalOutlinedButton} onPress={onDuplicate}>
            <Text style={styles.modalOutlinedText}>⧉ Duplicate</Text>
          </Pressable>
        </View>
        <Pressable style={[styles.modalOutlinedButton, styles.deleteButton]} onPress={onDelete}>
          <Text style={styles.deleteButtonText}>🗑 Delete Item</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

function CatalogItemFormModal({
  companyId,
  userId,
  item,
  duplicateSeed,
  onClose,
}: {
  companyId: string;
  userId: string;
  item: CatalogItem | null;
  duplicateSeed?: CatalogItem;
  onClose: () => void;
}) {
  const addItem = useCatalogStore((s) => s.addItem);
  const updateItem = useCatalogStore((s) => s.updateItem);
  const seed = item ?? duplicateSeed;

  const [description, setDescription] = useState(seed?.description ?? '');
  const [sku, setSku] = useState(seed?.sku ?? '');
  const [category, setCategory] = useState<ItemCategory>(seed?.category ?? 'general');
  const [quantity, setQuantity] = useState(seed?.defaultQuantity?.toString() ?? '');
  const [unit, setUnit] = useState(seed?.unit ?? '');
  const [price, setPrice] = useState(seed?.unitPrice?.toFixed(2) ?? '');
  const [isSaving, setIsSaving] = useState(false);

  const handleSave = async () => {
    if (description.trim().length === 0) {
      Alert.alert('Missing Information', 'Please enter description');
      return;
    }

    setIsSaving(true);
    try {
      const now = new Date();
      const catalogItem: CatalogItem = {
        id: item?.id ?? '',
        companyId,
        description: description.trim(),
        sku: sku.trim() || undefined,
        unit: unit.trim() || undefined,
        defaultQuantity: quantity.trim() ? Number(quantity.trim()) : undefined,
        unitPrice: price.trim() ? Number(price.trim()) : undefined,
        category,
        isActive: true,
        usageCount: item?.usageCount ?? 0,
        lastUsed: item?.lastUsed,
        createdAt: item?.createdAt ?? now,
        createdBy: item?.createdBy ?? userId,
        updatedAt: now,
        updatedBy: userId,
      };

      if (item == null) {
        await addItem(companyId, catalogItem);
      } else {
        await updateItem(companyId, item.id, catalogItem);
      }

      Alert.alert('Success', item == null ? 'Item added successfully' : 'Item updated successfully');
      onClose();
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Modal visible transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.formModalBackdrop}>
        <ScrollView style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>{item == null ? 'Add Catalog Item' : 'Edit Catalog Item'}</Text>

          <Text style={styles.fieldLabel}>Description *</Text>
          <TextInput style={styles.input} value={description} onChangeText={setDescription} />

          <Text style={styles.fieldLabel}>SKU / Part Number</Text>
          <TextInput style={styles.input} value={sku} onChangeText={setSku} placeholder="Optional" />

          <Text style={styles.fieldLabel}>Category *</Text>
          <View style={styles.chipWrap}>
            {ALL_CATEGORIES.map((c) => (
              <Chip key={c} label={`${itemCategoryIcon(c)} ${itemCategoryDisplayName(c)}`} selected={category === c} onPress={() => setCategory(c)} />
            ))}
          </View>

          <View style={styles.fieldRow}>
            <View style={styles.fieldHalf}>
              <Text style={styles.fieldLabel}>Default Quantity</Text>
              <TextInput style={styles.input} value={quantity} onChangeText={setQuantity} keyboardType="numeric" />
            </View>
            <View style={styles.fieldHalf}>
              <Text style={styles.fieldLabel}>Unit</Text>
              <TextInput style={styles.input} value={unit} onChangeText={setUnit} placeholder="e.g., boxes, pallets" />
            </View>
          </View>

          <Text style={styles.fieldLabel}>Unit Price (Optional)</Text>
          <TextInput style={styles.input} value={price} onChangeText={setPrice} keyboardType="decimal-pad" placeholder="R 0.00" />

          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} disabled={isSaving} onPress={onClose}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.modalPrimaryButton} disabled={isSaving} onPress={handleSave}>
              {isSaving ? <ActivityIndicator color={colors.white} size="small" /> : <Text style={textStyles.buttonText}>{item == null ? 'Add Item' : 'Save Changes'}</Text>}
            </Pressable>
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

function BulkCategoryModal({ visible, onClose, onApply }: { visible: boolean; onClose: () => void; onApply: (category: ItemCategory) => void }) {
  const [selected, setSelected] = useState<ItemCategory | null>(null);

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.formModalBackdrop}>
        <View style={[styles.modalCard, styles.smallModalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Change Category</Text>
          <Text style={[textStyles.bodyMedium, styles.modalHint]}>Select a new category for the selected items:</Text>
          <View style={styles.chipWrap}>
            {ALL_CATEGORIES.map((c) => (
              <Chip key={c} label={`${itemCategoryIcon(c)} ${itemCategoryDisplayName(c)}`} selected={selected === c} onPress={() => setSelected(c)} />
            ))}
          </View>
          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} onPress={onClose}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable
              style={[styles.modalPrimaryButton, selected == null && styles.modalPrimaryButtonDisabled]}
              disabled={selected == null}
              onPress={() => selected && onApply(selected)}
            >
              <Text style={textStyles.buttonText}>Change Category</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

function CategoryManagerModal({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.formModalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Manage Categories</Text>
          <Text style={[textStyles.bodyMedium, styles.modalHint]}>Customize category names and icons for your company</Text>
          <ScrollView style={styles.categoryManagerList}>
            {ALL_CATEGORIES.map((c) => (
              <View key={c} style={styles.categoryManagerRow}>
                <Text style={styles.categoryManagerIcon}>{itemCategoryIcon(c)}</Text>
                <Text style={styles.categoryManagerName}>{itemCategoryDisplayName(c)}</Text>
              </View>
            ))}
          </ScrollView>
          <Pressable style={styles.modalPrimaryButton} onPress={onClose}>
            <Text style={textStyles.buttonText}>Close</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyIcon: { fontSize: 56, opacity: 0.3, marginBottom: spacing.medium },
  emptySubtitle: { color: colors.textSecondary, marginBottom: spacing.large },
  loadingIndicator: { marginTop: spacing.xLarge },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.medium,
  },
  headerBarRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  headerBarAction: { color: colors.white, fontSize: 18 },
  headerBarButton: { paddingHorizontal: spacing.medium, paddingVertical: spacing.small, borderRadius: radii.buttonRadius, backgroundColor: colors.white },
  headerBarButtonSuccess: { backgroundColor: colors.success },
  headerBarButtonText: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 280, borderRightWidth: 1, borderRightColor: colors.divider, backgroundColor: colors.card },
  sidebarContent: { padding: spacing.medium },
  sidebarHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  sidebarTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary },
  sidebarClear: { color: colors.primary, fontWeight: '600' },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small },
  sidebarLabel: { fontWeight: '600', color: colors.textSecondary, marginBottom: spacing.small },
  sidebarSectionSpacer: { marginTop: spacing.large },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  sortOptionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small },
  sortOptionGlyph: { fontSize: 16, marginRight: spacing.small, color: colors.primary, width: 20 },
  sortOptionLabel: { fontSize: 14, color: colors.textPrimary },
  modalOutlinedButton: { alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedText: { color: colors.textPrimary, fontWeight: '600' },
  mainArea: { flex: 1 },
  statsBar: { flexDirection: 'row', gap: spacing.medium, padding: spacing.medium },
  statCard: { flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium },
  statIconBox: { width: 40, height: 40, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  statIcon: { fontSize: 18 },
  statLabel: { fontSize: 12, color: colors.textSecondary },
  statValue: { fontSize: 20, fontWeight: 'bold', color: colors.textPrimary, marginTop: 2 },
  bulkBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.large,
    backgroundColor: `${colors.primary}14`,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 4,
    marginHorizontal: spacing.medium,
    borderRadius: radii.borderRadius,
  },
  bulkBarText: { flex: 1, fontWeight: '600', color: colors.textPrimary },
  bulkBarAction: { fontWeight: '600', color: colors.primary },
  contentRow: { flex: 1, flexDirection: 'row' },
  tableSection: { flex: 1, margin: spacing.medium, backgroundColor: colors.card, borderRadius: radii.cardRadius, overflow: 'hidden' },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.background, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableHeaderCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small + 4, justifyContent: 'center' },
  tableHeaderText: { fontSize: 12, fontWeight: '700', color: colors.textSecondary },
  tableBody: { flex: 1 },
  tableRow: { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: colors.divider, minHeight: 56 },
  tableRowActive: { backgroundColor: `${colors.primary}0F` },
  tableCell: { paddingHorizontal: spacing.small, paddingVertical: spacing.small, justifyContent: 'center' },
  tableCellText: { fontSize: 13, color: colors.textPrimary },
  tableCellTextBold: { fontSize: 13, fontWeight: '700', color: colors.textPrimary },
  badgeRow: { flexDirection: 'row', gap: 4, marginTop: 2 },
  badge: { borderRadius: 4, paddingHorizontal: 6, paddingVertical: 1 },
  badgePopular: { backgroundColor: '#FFC107' },
  badgeNew: { backgroundColor: colors.warning },
  badgeText: { fontSize: 9, color: colors.white, fontWeight: '700' },
  actionsCell: { flexDirection: 'row', gap: spacing.medium },
  actionIcon: { fontSize: 16, color: colors.textPrimary },
  detailPanel: { width: 350, borderLeftWidth: 1, borderLeftColor: colors.divider, backgroundColor: colors.card, marginVertical: spacing.medium, marginRight: spacing.medium, borderRadius: radii.cardRadius, overflow: 'hidden' },
  detailPanelHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: spacing.medium, backgroundColor: colors.background, borderBottomWidth: 1, borderBottomColor: colors.divider },
  detailPanelTitle: { fontWeight: '700', fontSize: 15, color: colors.textPrimary },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  detailPanelContent: { padding: spacing.medium },
  imagePlaceholder: { height: 160, borderRadius: radii.borderRadius, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', marginBottom: spacing.medium },
  imagePlaceholderIcon: { fontSize: 48, opacity: 0.3 },
  detailSubtitle: { color: colors.textSecondary, marginTop: spacing.small, marginBottom: spacing.medium },
  detailSectionTitle: { fontWeight: '700', color: colors.primary, marginTop: spacing.medium, marginBottom: spacing.small },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4 },
  detailLabel: { color: colors.textSecondary },
  detailValue: { fontWeight: '600', color: colors.textPrimary },
  detailActionsRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.large },
  deleteButton: { borderColor: colors.error, marginTop: spacing.small },
  deleteButtonText: { color: colors.error, fontWeight: '600' },
  formModalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 500, maxHeight: '85%' },
  smallModalCard: { maxHeight: undefined },
  modalHint: { color: colors.textSecondary, marginTop: spacing.small, marginBottom: spacing.medium },
  fieldLabel: { fontWeight: '600', marginTop: spacing.medium, marginBottom: spacing.small },
  fieldRow: { flexDirection: 'row', gap: spacing.medium },
  fieldHalf: { flex: 1 },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalPrimaryButton: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  modalPrimaryButtonDisabled: { opacity: 0.5 },
  modalSecondaryButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius, borderWidth: 1, borderColor: colors.divider },
  modalSecondaryText: { color: colors.textSecondary, fontWeight: '600' },
  categoryManagerList: { maxHeight: 320, marginVertical: spacing.medium },
  categoryManagerRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  categoryManagerIcon: { fontSize: 18, marginRight: spacing.medium },
  categoryManagerName: { fontSize: 14, color: colors.textPrimary },
});
