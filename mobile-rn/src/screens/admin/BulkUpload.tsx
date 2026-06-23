import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { pick, types } from '@react-native-documents/picker';
import { useAuthStore } from '../../stores/useAuthStore';
import { AuthRepository } from '../../repositories/authRepository';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { getDeliveryCsvTemplate, ImportError, parseDeliveryCsv } from '../../repositories/bulkImportService';
import { exportToCSV } from '../../repositories/csvExportService';
import { EditableDelivery } from '../../models/editableDelivery';
import { DeliveryItem } from '../../models/delivery';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/bulk_upload_screen.dart (verified against source on
 * 2026-06-22) — CSV-based bulk delivery import: download a template, upload a CSV,
 * review/edit/validate in a table, then import selected rows.
 *
 * Deviations from the Flutter source:
 * - File picking/CSV reading/template download follow the same conventions as
 *   CustomerImport.tsx (@react-native-documents/picker + fetch().text(), exportToCSV's
 *   share sheet instead of a silent platform download).
 * - The scheduled-date cell is a plain `YYYY-MM-DD` text field instead of a native date
 *   picker — no date-picker package is installed anywhere in this project yet, and a
 *   single low-traffic edit field doesn't justify adding one (see vault risk register's
 *   general caution on new dependencies); re-parsed and re-validated on change.
 * - Only the same subset of columns the Dart table exposes is editable here (customer
 *   name/address/phone, invoice number, scheduled date, driver email, items, notes) —
 *   the rest of ParsedDelivery's fields (customerNumber, orderNumber, invoiceDate,
 *   invoiceTotal, taxAmount, discountAmount) pass through unedited from the CSV, same as
 *   the Dart source.
 */
const ROWS_PER_PAGE = 50;

interface DeliveryDraft {
  description: string;
  quantity: string;
  unit: string;
}

const authRepository = new AuthRepository();
const deliveryRepository = new DeliveryRepository();

export default function BulkUpload() {
  const currentUser = useAuthStore((s) => s.currentUser);

  const [editableDeliveries, setEditableDeliveries] = useState<EditableDelivery[] | null>(null);
  const [fileErrors, setFileErrors] = useState<ImportError[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [fileName, setFileName] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(0);
  const [driverEmailToId, setDriverEmailToId] = useState<Record<string, string>>({});
  const [driversLoaded, setDriversLoaded] = useState(false);
  const [existingInvoices, setExistingInvoices] = useState<string[]>([]);
  const [itemsEditorDelivery, setItemsEditorDelivery] = useState<EditableDelivery | null>(null);
  const [errorsModalDelivery, setErrorsModalDelivery] = useState<EditableDelivery | null>(null);
  const [showHelp, setShowHelp] = useState(false);

  useEffect(() => {
    if (!currentUser) return;

    authRepository
      .getUsersByCompany(currentUser.companyId, { role: 'driver' })
      .then((drivers) => {
        const map: Record<string, string> = {};
        drivers.forEach((d) => {
          map[d.email.toLowerCase()] = d.id;
        });
        setDriverEmailToId(map);
        setDriversLoaded(true);
      })
      .catch(() => setDriversLoaded(true));

    deliveryRepository.getExistingInvoiceNumbers(currentUser.companyId).then(setExistingInvoices).catch(() => setExistingInvoices([]));
  }, [currentUser]);

  const revalidateAll = (list: EditableDelivery[]) => {
    list.forEach((d) => d.validate(existingInvoices, list));
    setEditableDeliveries([...list]);
  };

  const pickFile = async () => {
    try {
      const [result] = await pick({ type: types.csv });
      if (!result) return;

      setIsLoading(true);
      setFileName(result.name ?? 'deliveries.csv');
      setEditableDeliveries(null);
      setFileErrors([]);

      const response = await fetch(result.uri);
      const csvContent = await response.text();
      const parseResult = parseDeliveryCsv(csvContent);

      const editableList = parseResult.validDeliveries.map((parsed) => EditableDelivery.fromParsed(parsed));
      editableList.forEach((d) => d.validate(existingInvoices, editableList));

      setEditableDeliveries(editableList);
      setFileErrors(parseResult.errors);
      setIsLoading(false);
      setCurrentPage(0);

      const validCount = editableList.filter((d) => d.isValid).length;
      const errorCount = editableList.filter((d) => d.hasErrors).length + parseResult.errors.length;
      const warningCount = editableList.reduce((total, d) => total + d.warnings.length, 0);
      Alert.alert('File Parsed', `Parsed ${editableList.length} rows: ${validCount} valid, ${errorCount} errors, ${warningCount} warnings`);
    } catch (e) {
      setIsLoading(false);
      Alert.alert('Error', `Error reading file: ${(e as Error).message}`);
    }
  };

  const downloadTemplate = async () => {
    try {
      const { headers, rows } = getDeliveryCsvTemplate();
      await exportToCSV('podsafe_delivery_template', headers, rows);
      Alert.alert('Success', 'Template downloaded successfully');
    } catch (e) {
      Alert.alert('Error', `Error downloading template: ${(e as Error).message}`);
    }
  };

  const toggleAllSelections = (selected: boolean) => {
    if (!editableDeliveries) return;
    editableDeliveries.forEach((d) => {
      if (!d.isRemoved && d.isValid) d.isSelected = selected;
    });
    setEditableDeliveries([...editableDeliveries]);
  };

  const toggleRemoved = (delivery: EditableDelivery) => {
    if (!editableDeliveries) return;
    delivery.isRemoved = !delivery.isRemoved;
    if (delivery.isRemoved) delivery.isSelected = false;
    revalidateAll(editableDeliveries);
  };

  const updateRow = (delivery: EditableDelivery, mutate: (d: EditableDelivery) => void, shouldRevalidate: boolean) => {
    if (!editableDeliveries) return;
    mutate(delivery);
    delivery.isEdited = true;
    if (shouldRevalidate) {
      delivery.validate(existingInvoices, editableDeliveries);
    }
    setEditableDeliveries([...editableDeliveries]);
  };

  const handleImport = async () => {
    if (!editableDeliveries || !currentUser) return;
    const selectedValid = editableDeliveries.filter((d) => d.isSelected && d.isValid && !d.isRemoved);

    if (selectedValid.length === 0) {
      Alert.alert('Notice', 'No valid deliveries selected for import');
      return;
    }

    Alert.alert('Confirm Import', `Import ${selectedValid.length} selected deliveries?\n\nThis will create new delivery records in the database.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Import',
        onPress: async () => {
          setIsImporting(true);
          try {
            const deliveries = selectedValid.map((d) => {
              const driverId = d.driverEmail && driversLoaded ? driverEmailToId[d.driverEmail.toLowerCase()] ?? 'unassigned' : 'unassigned';
              return d.toDelivery({ companyId: currentUser.companyId, driverId });
            });

            const importedCount = deliveries.length;
            await deliveryRepository.createDeliveries(deliveries);

            setIsImporting(false);
            setEditableDeliveries(null);
            setFileName(null);
            setFileErrors([]);
            Alert.alert('Import Complete', `Successfully imported ${importedCount} deliveries!`);
          } catch (e) {
            setIsImporting(false);
            Alert.alert('Error', `Error importing deliveries: ${(e as Error).message}`);
          }
        },
      },
    ]);
  };

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  if (!editableDeliveries) {
    return (
      <ScrollView style={styles.container} contentContainerStyle={styles.uploadPromptContent}>
        <Text style={styles.uploadIcon}>📤</Text>
        <Text style={textStyles.heading2}>Upload CSV File</Text>
        <Text style={[textStyles.bodyMedium, styles.uploadSubtitle]}>Import multiple deliveries at once from a CSV file</Text>

        <View style={styles.uploadButtonRow}>
          <Pressable style={styles.secondaryButton} onPress={downloadTemplate}>
            <Text style={styles.secondaryButtonText}>⬇ Download Template</Text>
          </Pressable>
          <Pressable style={styles.primaryButton} onPress={pickFile}>
            <Text style={textStyles.buttonText}>📁 Choose CSV File</Text>
          </Pressable>
        </View>

        <View style={[styles.infoCard, shadows.card]}>
          <Text style={styles.infoCardTitle}>CSV Format Requirements:</Text>
          <Text style={textStyles.bodySmall}>• Required: customerName, customerAddress, invoiceNumber, scheduledDate</Text>
          <Text style={textStyles.bodySmall}>• Date format: YYYY-MM-DD (e.g., 2025-10-17)</Text>
          <Text style={textStyles.bodySmall}>• Optional: customerPhone, driverEmail, notes, items</Text>
          <Text style={styles.infoCardOptional}>Up to 10 items per delivery</Text>
        </View>
      </ScrollView>
    );
  }

  const activeDeliveries = editableDeliveries.filter((d) => !d.isRemoved);
  const totalCount = editableDeliveries.length;
  const selectedCount = activeDeliveries.filter((d) => d.isSelected).length;
  const validCount = activeDeliveries.filter((d) => d.isValid).length;
  const errorCount = activeDeliveries.filter((d) => d.hasErrors).length + fileErrors.length;
  const warningCount = activeDeliveries.reduce((total, d) => total + d.warnings.length, 0);
  const removedCount = editableDeliveries.length - activeDeliveries.length;

  const totalPages = Math.max(1, Math.ceil(activeDeliveries.length / ROWS_PER_PAGE));
  const startIndex = currentPage * ROWS_PER_PAGE;
  const endIndex = Math.min(startIndex + ROWS_PER_PAGE, activeDeliveries.length);
  const pageDeliveries = activeDeliveries.slice(startIndex, endIndex);

  return (
    <View style={styles.container}>
      <View style={[styles.summaryCard, errorCount > 0 ? styles.summaryCardError : styles.summaryCardOk]}>
        <View style={styles.summaryHeaderRow}>
          <Text style={styles.summaryIcon}>{errorCount > 0 ? '⚠' : '✓'}</Text>
          <View style={styles.summaryTextBox}>
            <Text style={styles.summaryTitle}>{fileName ?? 'CSV File'}</Text>
            <Text style={styles.summarySubtitle}>
              {totalCount} rows • {validCount} valid • {errorCount} errors • {warningCount} warnings
            </Text>
            {removedCount > 0 ? <Text style={styles.removedText}>{removedCount} rows removed</Text> : null}
          </View>
          <Pressable onPress={() => setShowHelp(true)}>
            <Text style={styles.helpIcon}>❓</Text>
          </Pressable>
        </View>

        <View style={styles.actionsRow}>
          <Pressable style={styles.smallButton} onPress={pickFile}>
            <Text style={styles.smallButtonText}>📁 Choose New File</Text>
          </Pressable>
        </View>

        <Pressable style={styles.selectAllRow} onPress={() => toggleAllSelections(!(selectedCount === validCount && validCount > 0))}>
          <Text style={styles.checkboxGlyph}>{selectedCount === validCount && validCount > 0 ? '☑' : '☐'}</Text>
          <Text style={textStyles.bodySmall}>Select all valid rows</Text>
        </Pressable>

        {validCount > 0 ? (
          <Pressable style={styles.importButton} disabled={isImporting} onPress={handleImport}>
            {isImporting ? <ActivityIndicator color={colors.white} size="small" /> : null}
            <Text style={textStyles.buttonText}>{isImporting ? 'Importing...' : `⬆ Import Selected (${selectedCount})`}</Text>
          </Pressable>
        ) : null}
      </View>

      {fileErrors.length > 0 ? (
        <View style={styles.fileErrorsBox}>
          <Text style={styles.fileErrorsTitle}>File Errors:</Text>
          {fileErrors.map((error, i) => (
            <Text key={i} style={styles.fileErrorText}>
              • {error.message}
            </Text>
          ))}
        </View>
      ) : null}

      <ScrollView horizontal>
        <View style={styles.table}>
          <View style={styles.tableHeaderRow}>
            <Text style={[styles.headerCell, styles.colCheckbox]} />
            <Text style={[styles.headerCell, styles.colRow]}>Row</Text>
            <Text style={[styles.headerCell, styles.colName]}>Customer</Text>
            <Text style={[styles.headerCell, styles.colAddress]}>Address</Text>
            <Text style={[styles.headerCell, styles.colPhone]}>Phone</Text>
            <Text style={[styles.headerCell, styles.colInvoice]}>Invoice #</Text>
            <Text style={[styles.headerCell, styles.colDate]}>Date</Text>
            <Text style={[styles.headerCell, styles.colDriver]}>Driver Email</Text>
            <Text style={[styles.headerCell, styles.colItems]}>Items</Text>
            <Text style={[styles.headerCell, styles.colNotes]}>Notes</Text>
            <Text style={[styles.headerCell, styles.colActions]}>Actions</Text>
          </View>

          <ScrollView>
            {pageDeliveries.map((delivery) => (
              <DeliveryRow
                key={delivery.rowNumber}
                delivery={delivery}
                onChange={updateRow}
                onRemove={() => toggleRemoved(delivery)}
                onShowErrors={() => setErrorsModalDelivery(delivery)}
                onEditItems={() => setItemsEditorDelivery(delivery)}
                onToggleSelect={() => {
                  delivery.isSelected = !delivery.isSelected;
                  setEditableDeliveries([...editableDeliveries]);
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
            Page {currentPage + 1} of {totalPages} (showing {startIndex + 1}-{endIndex} of {activeDeliveries.length})
          </Text>
          <Pressable disabled={currentPage >= totalPages - 1} onPress={() => setCurrentPage((p) => p + 1)}>
            <Text style={[styles.pageArrow, currentPage >= totalPages - 1 && styles.pageArrowDisabled]}>›</Text>
          </Pressable>
        </View>
      ) : null}

      {errorsModalDelivery ? (
        <Modal visible transparent animationType="fade" onRequestClose={() => setErrorsModalDelivery(null)}>
          <View style={styles.modalBackdrop}>
            <View style={[styles.modalCard, shadows.card]}>
              <Text style={textStyles.heading3}>Row #{errorsModalDelivery.rowNumber} - Issues</Text>
              {errorsModalDelivery.errors.length > 0 ? (
                <>
                  <Text style={styles.issuesLabelError}>Errors:</Text>
                  {errorsModalDelivery.errors.map((e, i) => (
                    <Text key={i} style={styles.issueTextError}>
                      • {e.message}
                    </Text>
                  ))}
                </>
              ) : null}
              {errorsModalDelivery.warnings.length > 0 ? (
                <>
                  <Text style={styles.issuesLabelWarning}>Warnings:</Text>
                  {errorsModalDelivery.warnings.map((w, i) => (
                    <Text key={i} style={styles.issueTextWarning}>
                      • {w.message}
                    </Text>
                  ))}
                </>
              ) : null}
              <Pressable style={styles.modalCloseButton} onPress={() => setErrorsModalDelivery(null)}>
                <Text style={textStyles.buttonText}>Close</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      ) : null}

      {itemsEditorDelivery ? (
        <ItemsEditorModal
          delivery={itemsEditorDelivery}
          onClose={() => setItemsEditorDelivery(null)}
          onSave={(items) => {
            updateRow(itemsEditorDelivery, (d) => (d.items = items), true);
            setItemsEditorDelivery(null);
          }}
        />
      ) : null}

      <Modal visible={showHelp} transparent animationType="fade" onRequestClose={() => setShowHelp(false)}>
        <View style={styles.modalBackdrop}>
          <ScrollView style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Bulk Upload Help</Text>
            <Text style={styles.helpSectionLabel}>How to use bulk upload:</Text>
            <Text style={styles.helpLine}>1. Download the CSV template</Text>
            <Text style={styles.helpLine}>2. Fill in your delivery data</Text>
            <Text style={styles.helpLine}>3. Upload the CSV file</Text>
            <Text style={styles.helpLine}>4. Review and edit data in the table</Text>
            <Text style={styles.helpLine}>5. Select rows to import</Text>
            <Text style={styles.helpLine}>6. Tap "Import Selected"</Text>
            <Text style={styles.helpSectionLabel}>Editing Features:</Text>
            <Text style={styles.helpLine}>• Tap any cell to edit</Text>
            <Text style={styles.helpLine}>• Edit the date as YYYY-MM-DD</Text>
            <Text style={styles.helpLine}>• Tap items count to edit line items</Text>
            <Text style={styles.helpLine}>• Red rows have errors (cannot import)</Text>
            <Text style={styles.helpLine}>• Orange rows have warnings (can still import)</Text>
            <Text style={styles.helpLine}>• Blue rows have been edited</Text>
            <Text style={styles.helpLine}>• Use checkbox to select/deselect rows</Text>
            <Text style={styles.helpLine}>• Tap trash icon to remove from import</Text>
            <Pressable style={styles.modalCloseButton} onPress={() => setShowHelp(false)}>
              <Text style={textStyles.buttonText}>Close</Text>
            </Pressable>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

function DeliveryRow({
  delivery,
  onChange,
  onRemove,
  onShowErrors,
  onEditItems,
  onToggleSelect,
}: {
  delivery: EditableDelivery;
  onChange: (delivery: EditableDelivery, mutate: (d: EditableDelivery) => void, revalidate: boolean) => void;
  onRemove: () => void;
  onShowErrors: () => void;
  onEditItems: () => void;
  onToggleSelect: () => void;
}) {
  const rowStyle = delivery.hasErrors
    ? styles.rowError
    : delivery.hasWarnings
      ? styles.rowWarning
      : delivery.isEdited
        ? styles.rowEdited
        : styles.rowDefault;

  const [dateText, setDateText] = useState(delivery.scheduledDate.toISOString().slice(0, 10));

  return (
    <View style={[styles.tableRow, rowStyle]}>
      <Pressable style={styles.colCheckbox} disabled={!delivery.isValid} onPress={onToggleSelect}>
        <Text style={styles.checkboxGlyph}>{delivery.isSelected ? '☑' : '☐'}</Text>
      </Pressable>
      <View style={styles.colRow}>
        {delivery.hasErrors ? <Text style={styles.rowIconError}>!</Text> : delivery.hasWarnings ? <Text style={styles.rowIconWarning}>!</Text> : null}
        <Text style={styles.rowNumberText}>#{delivery.rowNumber}</Text>
      </View>
      <TextInput
        style={[styles.cellInput, styles.colName, delivery.errors.some((e) => e.field === 'customerName') && styles.cellInputError]}
        value={delivery.customerName}
        onChangeText={(value) => onChange(delivery, (d) => (d.customerName = value), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colAddress, delivery.errors.some((e) => e.field === 'customerAddress') && styles.cellInputError]}
        value={delivery.customerAddress}
        onChangeText={(value) => onChange(delivery, (d) => (d.customerAddress = value), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colPhone]}
        value={delivery.customerPhone ?? ''}
        onChangeText={(value) => onChange(delivery, (d) => (d.customerPhone = value || undefined), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colInvoice, delivery.errors.some((e) => e.field === 'invoiceNumber') && styles.cellInputError]}
        value={delivery.invoiceNumber}
        onChangeText={(value) => onChange(delivery, (d) => (d.invoiceNumber = value), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colDate, delivery.errors.some((e) => e.field === 'scheduledDate') && styles.cellInputError]}
        value={dateText}
        onChangeText={(value) => {
          setDateText(value);
          const parsed = new Date(value);
          if (!Number.isNaN(parsed.getTime())) {
            onChange(delivery, (d) => (d.scheduledDate = parsed), true);
          }
        }}
        placeholder="YYYY-MM-DD"
      />
      <TextInput
        style={[styles.cellInput, styles.colDriver]}
        value={delivery.driverEmail ?? ''}
        onChangeText={(value) => onChange(delivery, (d) => (d.driverEmail = value || undefined), true)}
      />
      <Pressable style={styles.colItems} onPress={onEditItems}>
        <Text style={styles.itemsLinkText}>{delivery.items.length} items</Text>
      </Pressable>
      <TextInput
        style={[styles.cellInput, styles.colNotes]}
        value={delivery.notes ?? ''}
        onChangeText={(value) => onChange(delivery, (d) => (d.notes = value || undefined), false)}
      />
      <View style={[styles.colActions, styles.actionsCell]}>
        {delivery.hasErrors || delivery.hasWarnings ? (
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

function ItemsEditorModal({
  delivery,
  onClose,
  onSave,
}: {
  delivery: EditableDelivery;
  onClose: () => void;
  onSave: (items: DeliveryItem[]) => void;
}) {
  const [items, setItems] = useState<DeliveryDraft[]>(
    delivery.items.map((item) => ({ description: item.description, quantity: String(item.quantity), unit: item.unit ?? 'pcs' })),
  );

  const addItem = () => setItems((prev) => [...prev, { description: '', quantity: '1', unit: 'pcs' }]);
  const removeItem = (index: number) => setItems((prev) => prev.filter((_, i) => i !== index));
  const updateItem = (index: number, patch: Partial<DeliveryDraft>) =>
    setItems((prev) => prev.map((item, i) => (i === index ? { ...item, ...patch } : item)));

  const handleSave = () => {
    const deliveryItems: DeliveryItem[] = items
      .filter((item) => item.description.trim().length > 0)
      .map((item) => ({ description: item.description.trim(), quantity: Number(item.quantity) || 1, unit: item.unit.trim() || undefined }));
    onSave(deliveryItems);
  };

  return (
    <Modal visible transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.modalCard, shadows.card, styles.itemsModalCard]}>
          <Text style={textStyles.heading3}>Edit Items - Row #{delivery.rowNumber}</Text>
          <ScrollView style={styles.itemsList}>
            {items.map((item, index) => (
              <View key={index} style={styles.itemRow}>
                <TextInput
                  style={[styles.cellInput, styles.itemDescriptionInput]}
                  placeholder="Description"
                  value={item.description}
                  onChangeText={(value) => updateItem(index, { description: value })}
                />
                <TextInput
                  style={[styles.cellInput, styles.itemQtyInput]}
                  placeholder="Qty"
                  value={item.quantity}
                  onChangeText={(value) => updateItem(index, { quantity: value })}
                  keyboardType="numeric"
                />
                <TextInput
                  style={[styles.cellInput, styles.itemUnitInput]}
                  placeholder="Unit"
                  value={item.unit}
                  onChangeText={(value) => updateItem(index, { unit: value })}
                />
                <Pressable onPress={() => removeItem(index)}>
                  <Text style={styles.actionIconDelete}>🗑</Text>
                </Pressable>
              </View>
            ))}
          </ScrollView>
          <Pressable style={styles.smallButton} onPress={addItem}>
            <Text style={styles.smallButtonText}>+ Add Item</Text>
          </Pressable>
          <View style={styles.itemsModalActions}>
            <Pressable style={styles.secondaryButton} onPress={onClose}>
              <Text style={styles.secondaryButtonText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.modalCloseButton} onPress={handleSave}>
              <Text style={textStyles.buttonText}>Save</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  uploadPromptContent: { alignItems: 'center', padding: spacing.large },
  uploadIcon: { fontSize: 64, marginTop: spacing.large, marginBottom: spacing.medium },
  uploadSubtitle: { textAlign: 'center', marginTop: spacing.medium, color: colors.textSecondary, maxWidth: 400 },
  uploadButtonRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  primaryButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  secondaryButton: { borderWidth: 1, borderColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  secondaryButtonText: { color: colors.primary, fontWeight: '600' },
  infoCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginTop: spacing.large, maxWidth: 500, width: '100%' },
  infoCardTitle: { fontWeight: 'bold', marginBottom: spacing.small },
  infoCardOptional: { fontSize: 12, color: colors.textSecondary, marginTop: spacing.medium },
  summaryCard: { padding: spacing.medium },
  summaryCardError: { backgroundColor: `${colors.error}14` },
  summaryCardOk: { backgroundColor: `${colors.success}14` },
  summaryHeaderRow: { flexDirection: 'row', alignItems: 'center' },
  summaryIcon: { fontSize: 20, marginRight: spacing.small + 4 },
  summaryTextBox: { flex: 1 },
  summaryTitle: { fontWeight: 'bold' },
  summarySubtitle: { fontSize: 12, marginTop: 2 },
  removedText: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  helpIcon: { fontSize: 18 },
  actionsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginTop: spacing.medium },
  smallButton: { borderWidth: 1, borderColor: colors.primary, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, alignSelf: 'flex-start' },
  smallButtonText: { color: colors.primary, fontSize: 12, fontWeight: '600' },
  selectAllRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginTop: spacing.medium },
  checkboxGlyph: { fontSize: 18, color: colors.primary },
  importButton: {
    flexDirection: 'row',
    gap: spacing.small,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.small + 4,
    marginTop: spacing.medium,
  },
  fileErrorsBox: { backgroundColor: `${colors.error}1A`, padding: spacing.medium },
  fileErrorsTitle: { color: colors.error, fontWeight: 'bold' },
  fileErrorText: { color: colors.error, marginTop: 4 },
  table: { width: 1260 },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.divider, paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small },
  headerCell: { fontWeight: 'bold', fontSize: 12 },
  tableRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small, paddingHorizontal: spacing.small, borderBottomWidth: 1, borderBottomColor: colors.divider },
  rowDefault: { backgroundColor: colors.card },
  rowError: { backgroundColor: `${colors.error}14` },
  rowWarning: { backgroundColor: `${colors.warning}14` },
  rowEdited: { backgroundColor: `${colors.info}14` },
  colCheckbox: { width: 36, alignItems: 'center' },
  colRow: { width: 50, flexDirection: 'row', alignItems: 'center' },
  colName: { width: 130 },
  colAddress: { width: 170 },
  colPhone: { width: 110 },
  colInvoice: { width: 110 },
  colDate: { width: 100 },
  colDriver: { width: 150 },
  colItems: { width: 80, alignItems: 'center', justifyContent: 'center' },
  colNotes: { width: 130 },
  colActions: { width: 70 },
  rowNumberText: { fontSize: 12 },
  rowIconError: { color: colors.error, fontWeight: 'bold', marginRight: 2 },
  rowIconWarning: { color: colors.warning, fontWeight: 'bold', marginRight: 2 },
  cellInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 4, fontSize: 12, marginRight: spacing.small },
  cellInputError: { borderColor: colors.error },
  itemsLinkText: { color: colors.primary, fontSize: 12, fontWeight: '600' },
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
  modalCloseButton: { marginTop: spacing.large, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, paddingHorizontal: spacing.large },
  helpSectionLabel: { fontWeight: 'bold', marginTop: spacing.medium },
  helpLine: { marginTop: 4, color: colors.textSecondary, fontSize: 13 },
  itemsModalCard: { maxWidth: 480 },
  itemsList: { maxHeight: 280, marginTop: spacing.medium },
  itemRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small },
  itemDescriptionInput: { flex: 3 },
  itemQtyInput: { flex: 1 },
  itemUnitInput: { flex: 1 },
  itemsModalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.medium, marginTop: spacing.medium },
});
