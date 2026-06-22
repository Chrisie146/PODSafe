import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import { useAuthStore } from '../../stores/useAuthStore';
import { useCatalogStore } from '../../stores/useCatalogStore';
import { CatalogItem, ItemCategory, itemCategoryDisplayName, itemCategoryIcon } from '../../models/catalogItem';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/bulk_item_creation_screen.dart (verified against source
 * on 2026-06-22) — a spreadsheet-style bulk catalog-item-creation table (add rows
 * manually or paste from clipboard, validate, select valid rows, create).
 *
 * Deviations from the Flutter source:
 * - `EditableItem`/`ItemValidationError`/`ItemValidationWarning` are kept inline in this
 *   file rather than split into models/, mirroring the Dart source's own structure
 *   (unlike EditableCustomer, which the Dart source already split into its own file).
 * - Category uses a modal chip-picker instead of a DropdownButton (house convention) —
 *   a row of 8 inline chips wouldn't fit a ~120px table cell, so tapping the cell opens
 *   a modal listing all categories as chips, same Modal pattern used elsewhere for
 *   dialogs/bottom-sheets.
 * - "Add Rows" PopupMenuButton becomes 3 plain buttons + a paste button, matching
 *   CustomerCreation.tsx's precedent.
 */
const ROWS_PER_PAGE = 50;
const ALL_CATEGORIES: ItemCategory[] = ['general', 'furniture', 'officeSupplies', 'electronics', 'documents', 'bulkGoods', 'equipment', 'other'];

interface ItemValidationIssue {
  field: string;
  message: string;
}

class EditableItem {
  rowNumber: number;
  description: string;
  sku?: string;
  category: ItemCategory;
  unit?: string;
  defaultQuantity?: number;
  unitPrice?: number;

  isSelected: boolean;
  isRemoved: boolean;
  isEdited: boolean;
  errors: ItemValidationIssue[];
  warnings: ItemValidationIssue[];

  constructor(params: {
    rowNumber: number;
    description: string;
    sku?: string;
    category?: ItemCategory;
    unit?: string;
    defaultQuantity?: number;
    unitPrice?: number;
  }) {
    this.rowNumber = params.rowNumber;
    this.description = params.description;
    this.sku = params.sku;
    this.category = params.category ?? 'general';
    this.unit = params.unit;
    this.defaultQuantity = params.defaultQuantity;
    this.unitPrice = params.unitPrice;
    this.isSelected = false;
    this.isRemoved = false;
    this.isEdited = false;
    this.errors = [];
    this.warnings = [];
  }

  get isValid(): boolean {
    return this.errors.length === 0;
  }

  get hasErrors(): boolean {
    return this.errors.length > 0;
  }

  get hasWarnings(): boolean {
    return this.warnings.length > 0;
  }

  /** Mirrors EditableItem.validate(). */
  validate(existingSKUs: string[] = []): void {
    this.errors = [];
    this.warnings = [];

    if (this.description.trim().length === 0) {
      this.errors.push({ field: 'description', message: 'Description is required' });
    }

    if (this.sku && this.sku.length > 0 && existingSKUs.includes(this.sku)) {
      this.warnings.push({ field: 'sku', message: 'This SKU already exists in catalog' });
    }

    if (!this.unit || this.unit.length === 0) {
      this.warnings.push({ field: 'unit', message: 'Unit not specified' });
    }

    if (this.defaultQuantity == null || this.defaultQuantity === 0) {
      this.warnings.push({ field: 'quantity', message: 'Default quantity not set' });
    }

    if (this.unitPrice != null && this.unitPrice < 0) {
      this.errors.push({ field: 'price', message: 'Price cannot be negative' });
    }
  }

  /** Mirrors EditableItem.toCatalogItem(). */
  toCatalogItem(companyId: string, userId: string): CatalogItem {
    const now = new Date();
    return {
      id: '',
      companyId,
      description: this.description.trim(),
      sku: this.sku?.trim() || undefined,
      unit: this.unit?.trim() || undefined,
      defaultQuantity: this.defaultQuantity ?? 0,
      unitPrice: this.unitPrice,
      category: this.category,
      isActive: true,
      usageCount: 0,
      createdAt: now,
      createdBy: userId,
      updatedAt: now,
      updatedBy: userId,
    };
  }
}

function createBlankItem(rowNumber: number): EditableItem {
  return new EditableItem({ rowNumber, description: '' });
}

function parseCategory(categoryStr: string): ItemCategory {
  const lower = categoryStr.toLowerCase().trim();
  const match = ALL_CATEGORIES.find((c) => c.toLowerCase().includes(lower) || itemCategoryDisplayName(c).toLowerCase().includes(lower));
  return match ?? 'general';
}

export default function BulkItemCreation() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const allItems = useCatalogStore((s) => s.allItems);
  const initialize = useCatalogStore((s) => s.initialize);
  const addItem = useCatalogStore((s) => s.addItem);

  const [isInitialized, setIsInitialized] = useState(false);
  const [editableItems, setEditableItems] = useState<EditableItem[]>([]);
  const [existingSKUs, setExistingSKUs] = useState<Set<string>>(new Set());
  const [isCreating, setIsCreating] = useState(false);
  const [currentPage, setCurrentPage] = useState(0);
  const [errorsModalItem, setErrorsModalItem] = useState<EditableItem | null>(null);
  const [categoryModalItem, setCategoryModalItem] = useState<EditableItem | null>(null);
  const [showHelp, setShowHelp] = useState(false);

  useEffect(() => {
    if (!currentUser) return;
    initialize(currentUser.companyId).then(() => {
      setIsInitialized(true);
      setEditableItems([createBlankItem(1), createBlankItem(2), createBlankItem(3)]);
    });
  }, [currentUser, initialize]);

  useEffect(() => {
    setExistingSKUs(new Set(allItems.filter((i) => i.sku).map((i) => i.sku as string)));
  }, [allItems]);

  const revalidateAll = (list: EditableItem[]) => {
    const skus = Array.from(existingSKUs);
    list.forEach((i) => i.validate(skus));
    setEditableItems([...list]);
  };

  const addRows = (count: number) => {
    const maxRow = editableItems.reduce((max, i) => Math.max(max, i.rowNumber), 0);
    const newRows = Array.from({ length: count }, (_, i) => createBlankItem(maxRow + i + 1));
    const updated = [...editableItems, ...newRows];
    setEditableItems(updated);
    setCurrentPage(Math.ceil(updated.length / ROWS_PER_PAGE) - 1);
  };

  const pasteFromClipboard = async () => {
    try {
      const text = await Clipboard.getString();
      if (!text) {
        Alert.alert('Notice', 'No text in clipboard');
        return;
      }

      const lines = text.split('\n').filter((line) => line.trim().length > 0);
      if (lines.length === 0) {
        Alert.alert('Notice', 'No data found in clipboard');
        return;
      }

      const rows = lines.map((line) => (line.includes('\t') ? line.split('\t') : line.split(',')).map((p) => p.trim()));
      const maxRow = editableItems.reduce((max, i) => Math.max(max, i.rowNumber), 0);

      const newItems = rows.map(
        (row, i) =>
          new EditableItem({
            rowNumber: maxRow + i + 1,
            description: row[0] ?? '',
            sku: row[1] || undefined,
            category: parseCategory(row[2] ?? ''),
            unit: row[3] || undefined,
            defaultQuantity: row[4] ? Number(row[4]) || undefined : undefined,
            unitPrice: row[5] ? Number(row[5]) || undefined : undefined,
          }),
      );

      const updated = [...editableItems, ...newItems];
      setCurrentPage(Math.ceil(updated.length / ROWS_PER_PAGE) - 1);
      revalidateAll(updated);
      Alert.alert('Success', `✓ Pasted ${newItems.length} rows from clipboard`);
    } catch (e) {
      Alert.alert('Error', `Error pasting data: ${(e as Error).message}`);
    }
  };

  const toggleAllSelections = (selected: boolean) => {
    editableItems.forEach((i) => {
      if (!i.isRemoved && i.isValid) i.isSelected = selected;
    });
    setEditableItems([...editableItems]);
  };

  const removeRow = (item: EditableItem) => {
    const updated = editableItems.filter((i) => i.rowNumber !== item.rowNumber);
    revalidateAll(updated);
  };

  const updateRow = (item: EditableItem, mutate: (i: EditableItem) => void, shouldRevalidate: boolean) => {
    mutate(item);
    item.isEdited = true;
    if (shouldRevalidate) {
      item.validate(Array.from(existingSKUs));
    }
    setEditableItems([...editableItems]);
  };

  const handleCreateItems = async () => {
    if (!currentUser) return;
    const selectedValid = editableItems.filter((i) => i.isSelected && i.isValid && !i.isRemoved);

    if (selectedValid.length === 0) {
      Alert.alert('Notice', 'No valid items selected for creation');
      return;
    }

    Alert.alert('Confirm Creation', `Create ${selectedValid.length} new catalog items?\n\nThis will add new items to the product catalog.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Create',
        onPress: async () => {
          setIsCreating(true);
          try {
            for (const item of selectedValid) {
              await addItem(currentUser.companyId, item.toCatalogItem(currentUser.companyId, currentUser.id));
            }

            const createdCount = selectedValid.length;
            setEditableItems([createBlankItem(1), createBlankItem(2), createBlankItem(3)]);
            setCurrentPage(0);
            Alert.alert('Creation Complete', `Successfully created ${createdCount} items!`);
          } catch (e) {
            Alert.alert('Error', `Error creating items: ${(e as Error).message}`);
          } finally {
            setIsCreating(false);
          }
        },
      },
    ]);
  };

  if (!isInitialized) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
        <Text style={[textStyles.bodyMedium, styles.loadingText]}>Loading catalog...</Text>
      </View>
    );
  }

  const totalCount = editableItems.length;
  const selectedCount = editableItems.filter((i) => i.isSelected && !i.isRemoved).length;
  const validCount = editableItems.filter((i) => i.isValid && !i.isRemoved).length;
  const errorCount = editableItems.filter((i) => i.hasErrors && !i.isRemoved).length;
  const warningCount = editableItems.filter((i) => !i.isRemoved).reduce((total, i) => total + i.warnings.length, 0);

  const totalPages = Math.max(1, Math.ceil(totalCount / ROWS_PER_PAGE));
  const startIndex = currentPage * ROWS_PER_PAGE;
  const endIndex = Math.min(startIndex + ROWS_PER_PAGE, totalCount);
  const pageItems = editableItems.slice(startIndex, endIndex);

  return (
    <View style={styles.container}>
      <View style={[styles.summaryCard, errorCount > 0 ? styles.summaryCardError : styles.summaryCardOk]}>
        <View style={styles.summaryHeaderRow}>
          <Text style={styles.summaryIcon}>{errorCount > 0 ? '⚠' : '✓'}</Text>
          <View style={styles.summaryTextBox}>
            <Text style={styles.summaryTitle}>New Catalog Items</Text>
            <Text style={styles.summarySubtitle}>
              {totalCount} rows • {validCount} valid • {errorCount} errors • {warningCount} warnings
            </Text>
          </View>
          <Pressable onPress={() => setShowHelp(true)}>
            <Text style={styles.helpIcon}>❓</Text>
          </Pressable>
        </View>

        <View style={styles.actionsRow}>
          <Pressable style={styles.smallButton} onPress={() => addRows(1)}>
            <Text style={styles.smallButtonText}>+1 Row</Text>
          </Pressable>
          <Pressable style={styles.smallButton} onPress={() => addRows(5)}>
            <Text style={styles.smallButtonText}>+5 Rows</Text>
          </Pressable>
          <Pressable style={styles.smallButton} onPress={() => addRows(10)}>
            <Text style={styles.smallButtonText}>+10 Rows</Text>
          </Pressable>
          <Pressable style={styles.smallButton} onPress={pasteFromClipboard}>
            <Text style={styles.smallButtonText}>📋 Paste</Text>
          </Pressable>
        </View>

        <Pressable style={styles.selectAllRow} onPress={() => toggleAllSelections(!(selectedCount === validCount && validCount > 0))}>
          <Text style={styles.checkboxGlyph}>{selectedCount === validCount && validCount > 0 ? '☑' : '☐'}</Text>
          <Text style={textStyles.bodySmall}>Select all valid rows</Text>
        </Pressable>

        {validCount > 0 ? (
          <Pressable style={styles.createButton} disabled={isCreating} onPress={handleCreateItems}>
            {isCreating ? <ActivityIndicator color={colors.white} size="small" /> : null}
            <Text style={textStyles.buttonText}>{isCreating ? 'Creating...' : `✓ Create Selected (${selectedCount})`}</Text>
          </Pressable>
        ) : null}
      </View>

      <ScrollView horizontal>
        <View style={styles.table}>
          <View style={styles.tableHeaderRow}>
            <Text style={[styles.headerCell, styles.colCheckbox]} />
            <Text style={[styles.headerCell, styles.colRow]}>Row</Text>
            <Text style={[styles.headerCell, styles.colDescription]}>Description</Text>
            <Text style={[styles.headerCell, styles.colSku]}>SKU</Text>
            <Text style={[styles.headerCell, styles.colCategory]}>Category</Text>
            <Text style={[styles.headerCell, styles.colUnit]}>Unit</Text>
            <Text style={[styles.headerCell, styles.colQty]}>Default Qty</Text>
            <Text style={[styles.headerCell, styles.colPrice]}>Unit Price</Text>
            <Text style={[styles.headerCell, styles.colActions]}>Actions</Text>
          </View>

          <ScrollView>
            {pageItems.map((item) => (
              <ItemRow
                key={item.rowNumber}
                item={item}
                onChange={updateRow}
                onRemove={() => removeRow(item)}
                onShowErrors={() => setErrorsModalItem(item)}
                onPickCategory={() => setCategoryModalItem(item)}
                onToggleSelect={() => {
                  item.isSelected = !item.isSelected;
                  setEditableItems([...editableItems]);
                }}
              />
            ))}
          </ScrollView>
        </View>
      </ScrollView>

      {totalPages > 1 ? (
        <View style={styles.paginationRow}>
          <Pressable disabled={currentPage === 0} onPress={() => setCurrentPage((p) => p - 1)}>
            <Text style={[styles.pageArrow, currentPage === 0 && styles.pageArrowDisabled]}>‹</Text>
          </Pressable>
          <Text style={styles.pageText}>
            Page {currentPage + 1} of {totalPages} (showing {startIndex + 1}-{endIndex} of {totalCount})
          </Text>
          <Pressable disabled={currentPage >= totalPages - 1} onPress={() => setCurrentPage((p) => p + 1)}>
            <Text style={[styles.pageArrow, currentPage >= totalPages - 1 && styles.pageArrowDisabled]}>›</Text>
          </Pressable>
        </View>
      ) : null}

      {errorsModalItem ? (
        <Modal visible transparent animationType="fade" onRequestClose={() => setErrorsModalItem(null)}>
          <View style={styles.modalBackdrop}>
            <View style={[styles.modalCard, shadows.card]}>
              <Text style={textStyles.heading3}>Row #{errorsModalItem.rowNumber} - Issues</Text>
              {errorsModalItem.errors.length > 0 ? (
                <>
                  <Text style={styles.issuesLabelError}>Errors:</Text>
                  {errorsModalItem.errors.map((e, i) => (
                    <Text key={i} style={styles.issueTextError}>
                      • {e.message}
                    </Text>
                  ))}
                </>
              ) : null}
              {errorsModalItem.warnings.length > 0 ? (
                <>
                  <Text style={styles.issuesLabelWarning}>Warnings:</Text>
                  {errorsModalItem.warnings.map((w, i) => (
                    <Text key={i} style={styles.issueTextWarning}>
                      • {w.message}
                    </Text>
                  ))}
                </>
              ) : null}
              <Pressable style={styles.modalCloseButton} onPress={() => setErrorsModalItem(null)}>
                <Text style={textStyles.buttonText}>Close</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      ) : null}

      {categoryModalItem ? (
        <Modal visible transparent animationType="fade" onRequestClose={() => setCategoryModalItem(null)}>
          <View style={styles.modalBackdrop}>
            <View style={[styles.modalCard, shadows.card]}>
              <Text style={textStyles.heading3}>Row #{categoryModalItem.rowNumber} - Category</Text>
              <View style={styles.categoryModalChipRow}>
                {ALL_CATEGORIES.map((cat) => (
                  <Pressable
                    key={cat}
                    style={[styles.categoryModalChip, categoryModalItem.category === cat && styles.typeChipSelected]}
                    onPress={() => {
                      updateRow(categoryModalItem, (i) => (i.category = cat), false);
                      setCategoryModalItem(null);
                    }}
                  >
                    <Text style={[styles.typeChipText, categoryModalItem.category === cat && styles.typeChipTextSelected]}>
                      {itemCategoryIcon(cat)} {itemCategoryDisplayName(cat)}
                    </Text>
                  </Pressable>
                ))}
              </View>
              <Pressable style={styles.modalCloseButton} onPress={() => setCategoryModalItem(null)}>
                <Text style={textStyles.buttonText}>Close</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      ) : null}

      <Modal visible={showHelp} transparent animationType="fade" onRequestClose={() => setShowHelp(false)}>
        <View style={styles.modalBackdrop}>
          <ScrollView style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Item Creation Help</Text>
            <Text style={styles.helpSectionLabel}>How to create items:</Text>
            <Text style={styles.helpLine}>1. Add rows manually or paste from clipboard</Text>
            <Text style={styles.helpLine}>2. Fill in item data in the table</Text>
            <Text style={styles.helpLine}>3. Review validation results</Text>
            <Text style={styles.helpLine}>4. Select rows to create</Text>
            <Text style={styles.helpLine}>5. Tap "Create Selected"</Text>
            <Text style={styles.helpSectionLabel}>Quick Entry:</Text>
            <Text style={styles.helpLine}>• Tap "+1/+5/+10 Rows" to add blank rows</Text>
            <Text style={styles.helpLine}>• Paste multi-row data: [Description][Tab][SKU][Tab][Category]...</Text>
            <Text style={styles.helpSectionLabel}>Visual Indicators:</Text>
            <Text style={styles.helpLine}>• Red rows have errors (cannot create)</Text>
            <Text style={styles.helpLine}>• Orange rows have warnings (can still create)</Text>
            <Text style={styles.helpLine}>• Blue rows have been edited</Text>
            <Text style={styles.helpSectionLabel}>Required Fields:</Text>
            <Text style={styles.helpLine}>• Description (required for all items)</Text>
            <Text style={styles.helpLine}>• Everything else is optional</Text>
            <Pressable style={styles.modalCloseButton} onPress={() => setShowHelp(false)}>
              <Text style={textStyles.buttonText}>Close</Text>
            </Pressable>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

function ItemRow({
  item,
  onChange,
  onRemove,
  onShowErrors,
  onPickCategory,
  onToggleSelect,
}: {
  item: EditableItem;
  onChange: (item: EditableItem, mutate: (i: EditableItem) => void, revalidate: boolean) => void;
  onRemove: () => void;
  onShowErrors: () => void;
  onPickCategory: () => void;
  onToggleSelect: () => void;
}) {
  const rowStyle = item.hasErrors ? styles.rowError : item.hasWarnings ? styles.rowWarning : item.isEdited ? styles.rowEdited : styles.rowDefault;

  return (
    <View style={[styles.tableRow, rowStyle]}>
      <Pressable style={styles.colCheckbox} disabled={!item.isValid} onPress={onToggleSelect}>
        <Text style={styles.checkboxGlyph}>{item.isSelected ? '☑' : '☐'}</Text>
      </Pressable>
      <View style={styles.colRow}>
        {item.hasErrors ? <Text style={styles.rowIconError}>!</Text> : item.hasWarnings ? <Text style={styles.rowIconWarning}>!</Text> : null}
        <Text style={styles.rowNumberText}>#{item.rowNumber}</Text>
      </View>
      <TextInput
        style={[styles.cellInput, styles.colDescription, item.errors.some((e) => e.field === 'description') && styles.cellInputError]}
        value={item.description}
        onChangeText={(value) => onChange(item, (i) => (i.description = value), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colSku]}
        value={item.sku ?? ''}
        onChangeText={(value) => onChange(item, (i) => (i.sku = value || undefined), true)}
      />
      <Pressable style={[styles.colCategory, styles.categoryCell]} onPress={onPickCategory}>
        <Text style={styles.categoryCellText}>
          {itemCategoryIcon(item.category)} {itemCategoryDisplayName(item.category)}
        </Text>
      </Pressable>
      <TextInput
        style={[styles.cellInput, styles.colUnit]}
        value={item.unit ?? ''}
        onChangeText={(value) => onChange(item, (i) => (i.unit = value || undefined), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colQty]}
        keyboardType="numeric"
        value={item.defaultQuantity?.toString() ?? ''}
        onChangeText={(value) => onChange(item, (i) => (i.defaultQuantity = value === '' ? undefined : Number(value) || undefined), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colPrice, item.errors.some((e) => e.field === 'price') && styles.cellInputError]}
        keyboardType="numeric"
        value={item.unitPrice?.toFixed(2) ?? ''}
        onChangeText={(value) => onChange(item, (i) => (i.unitPrice = value === '' ? undefined : Number(value)), true)}
      />
      <View style={[styles.colActions, styles.actionsCell]}>
        {item.hasErrors || item.hasWarnings ? (
          <Pressable onPress={onShowErrors}>
            <Text style={styles.actionIcon}>ℹ️</Text>
          </Pressable>
        ) : null}
        <Pressable onPress={onRemove}>
          <Text style={styles.actionIconDelete}>🗑</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  loadingText: { marginTop: spacing.medium },
  summaryCard: { padding: spacing.medium },
  summaryCardError: { backgroundColor: `${colors.error}14` },
  summaryCardOk: { backgroundColor: `${colors.success}14` },
  summaryHeaderRow: { flexDirection: 'row', alignItems: 'center' },
  summaryIcon: { fontSize: 20, marginRight: spacing.small + 4 },
  summaryTextBox: { flex: 1 },
  summaryTitle: { fontWeight: 'bold' },
  summarySubtitle: { fontSize: 12, marginTop: 2 },
  helpIcon: { fontSize: 18 },
  actionsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginTop: spacing.medium },
  smallButton: { borderWidth: 1, borderColor: colors.primary, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6 },
  smallButtonText: { color: colors.primary, fontSize: 12, fontWeight: '600' },
  selectAllRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginTop: spacing.medium },
  checkboxGlyph: { fontSize: 18, color: colors.primary },
  createButton: {
    flexDirection: 'row',
    gap: spacing.small,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.small + 4,
    marginTop: spacing.medium,
  },
  table: { width: 1180 },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.divider, paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small },
  headerCell: { fontWeight: 'bold', fontSize: 12 },
  tableRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.small,
    paddingHorizontal: spacing.small,
    borderBottomWidth: 1,
    borderBottomColor: colors.divider,
  },
  rowDefault: { backgroundColor: colors.card },
  rowError: { backgroundColor: `${colors.error}14` },
  rowWarning: { backgroundColor: `${colors.warning}14` },
  rowEdited: { backgroundColor: `${colors.info}14` },
  colCheckbox: { width: 36, alignItems: 'center' },
  colRow: { width: 50, flexDirection: 'row', alignItems: 'center' },
  colDescription: { width: 200 },
  colSku: { width: 120 },
  colCategory: { width: 140 },
  colUnit: { width: 90 },
  colQty: { width: 110 },
  colPrice: { width: 110 },
  colActions: { width: 70 },
  rowNumberText: { fontSize: 12 },
  rowIconError: { color: colors.error, fontWeight: 'bold', marginRight: 2 },
  rowIconWarning: { color: colors.warning, fontWeight: 'bold', marginRight: 2 },
  cellInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 4, fontSize: 12, marginRight: spacing.small },
  cellInputError: { borderColor: colors.error },
  categoryCell: { borderWidth: 1, borderColor: colors.divider, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 6, marginRight: spacing.small },
  categoryCellText: { fontSize: 12, color: colors.textPrimary },
  categoryModalChipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginTop: spacing.medium },
  categoryModalChip: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6 },
  typeChipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  typeChipText: { fontSize: 12, color: colors.textSecondary },
  typeChipTextSelected: { color: colors.primary, fontWeight: '600' },
  actionsCell: { flexDirection: 'row', gap: spacing.small },
  actionIcon: { fontSize: 16 },
  actionIconDelete: { fontSize: 16, color: colors.error },
  paginationRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.medium, padding: spacing.medium },
  pageArrow: { fontSize: 24, color: colors.primary, paddingHorizontal: spacing.small },
  pageArrowDisabled: { color: colors.divider },
  pageText: { fontSize: 12, fontWeight: '600' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '80%' },
  issuesLabelError: { color: colors.error, fontWeight: 'bold', marginTop: spacing.medium },
  issueTextError: { color: colors.error, marginTop: 4 },
  issuesLabelWarning: { color: colors.warning, fontWeight: 'bold', marginTop: spacing.medium },
  issueTextWarning: { color: colors.warning, marginTop: 4 },
  modalCloseButton: { marginTop: spacing.large, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  helpSectionLabel: { fontWeight: 'bold', marginTop: spacing.medium },
  helpLine: { marginTop: 4, color: colors.textSecondary, fontSize: 13 },
});
