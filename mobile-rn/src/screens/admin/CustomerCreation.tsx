import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import { useAuthStore } from '../../stores/useAuthStore';
import { useCustomerStore } from '../../stores/useCustomerStore';
import { EditableCustomer } from '../../models/editableCustomer';
import { CustomerType } from '../../models/customer';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/customer_creation_screen.dart (verified against source
 * on 2026-06-22) — a spreadsheet-style bulk customer-creation table (add rows manually
 * or paste from clipboard, validate, select valid rows, create).
 *
 * Deviations from the Flutter source:
 * - The "Add Rows" PopupMenuButton becomes 3 plain buttons (Add 1/5/10) — no menu/
 *   picker library installed, and a 3-item popup isn't worth a new dependency.
 * - Customer Type uses a chip selector instead of a DropdownButton (house convention).
 * - This table is genuinely not mobile-optimized in the Dart source either — it's a
 *   fixed-width (1400px in Dart) horizontally-scrolling table with no separate mobile
 *   layout, so this port keeps the same "wide table, scroll sideways" structure rather
 *   than inventing a more mobile-friendly redesign the source doesn't have.
 */
const ROWS_PER_PAGE = 50;
const CUSTOMER_TYPES: CustomerType[] = ['business', 'residential'];

function createBlankCustomer(rowNumber: number): EditableCustomer {
  return new EditableCustomer({ rowNumber, customerNumber: '', name: '', address: '' });
}

export default function CustomerCreation() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const customers = useCustomerStore((s) => s.customers);
  const initialize = useCustomerStore((s) => s.initialize);
  const createCustomers = useCustomerStore((s) => s.createCustomers);

  const [isInitialized, setIsInitialized] = useState(false);
  const [editableCustomers, setEditableCustomers] = useState<EditableCustomer[]>([]);
  const [existingNumbers, setExistingNumbers] = useState<Set<string>>(new Set());
  const [isCreating, setIsCreating] = useState(false);
  const [currentPage, setCurrentPage] = useState(0);
  const [errorsModalCustomer, setErrorsModalCustomer] = useState<EditableCustomer | null>(null);
  const [showHelp, setShowHelp] = useState(false);

  useEffect(() => {
    if (!currentUser) return;
    initialize(currentUser.companyId).then(() => {
      setIsInitialized(true);
      setEditableCustomers([createBlankCustomer(1), createBlankCustomer(2), createBlankCustomer(3)]);
    });
  }, [currentUser, initialize]);

  useEffect(() => {
    setExistingNumbers(new Set(customers.map((c) => c.customerNumber)));
  }, [customers]);

  const revalidateAll = (list: EditableCustomer[]) => {
    const existing = Array.from(existingNumbers);
    list.forEach((c) => c.validate(existing, list));
    setEditableCustomers([...list]);
  };

  const addRows = (count: number) => {
    const maxRow = editableCustomers.reduce((max, c) => Math.max(max, c.rowNumber), 0);
    const newRows = Array.from({ length: count }, (_, i) => createBlankCustomer(maxRow + i + 1));
    const updated = [...editableCustomers, ...newRows];
    setEditableCustomers(updated);
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
      const maxRow = editableCustomers.reduce((max, c) => Math.max(max, c.rowNumber), 0);

      const newCustomers = rows.map(
        (row, i) =>
          new EditableCustomer({
            rowNumber: maxRow + i + 1,
            customerNumber: row[0] ?? '',
            name: row[1] ?? '',
            address: row[2] ?? '',
            contactPerson: row[3] || undefined,
            phone: row[4] || undefined,
            email: row[5] || undefined,
          }),
      );

      const updated = [...editableCustomers, ...newCustomers];
      setCurrentPage(Math.ceil(updated.length / ROWS_PER_PAGE) - 1);
      revalidateAll(updated);
      Alert.alert('Success', `✓ Pasted ${newCustomers.length} rows from clipboard`);
    } catch (e) {
      Alert.alert('Error', `Error pasting data: ${(e as Error).message}`);
    }
  };

  const toggleAllSelections = (selected: boolean) => {
    editableCustomers.forEach((c) => {
      if (!c.isRemoved && c.isValid) c.isSelected = selected;
    });
    setEditableCustomers([...editableCustomers]);
  };

  const removeRow = (customer: EditableCustomer) => {
    const updated = editableCustomers.filter((c) => c.rowNumber !== customer.rowNumber);
    revalidateAll(updated);
  };

  const updateRow = (customer: EditableCustomer, mutate: (c: EditableCustomer) => void, shouldRevalidate: boolean) => {
    mutate(customer);
    customer.isEdited = true;
    if (shouldRevalidate) {
      customer.validate(Array.from(existingNumbers), editableCustomers);
    }
    setEditableCustomers([...editableCustomers]);
  };

  const handleCreateCustomers = async () => {
    if (!currentUser) return;
    const selectedValid = editableCustomers.filter((c) => c.isSelected && c.isValid && !c.isRemoved);

    if (selectedValid.length === 0) {
      Alert.alert('Notice', 'No valid customers selected for creation');
      return;
    }

    Alert.alert('Confirm Creation', `Create ${selectedValid.length} new customers?\n\nThis will add new customer records to the database.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Create',
        onPress: async () => {
          setIsCreating(true);
          try {
            const customersToCreate = selectedValid.map((c) => c.toCustomer(currentUser.companyId));
            await createCustomers(customersToCreate);

            const createdCount = selectedValid.length;
            setEditableCustomers([createBlankCustomer(1), createBlankCustomer(2), createBlankCustomer(3)]);
            setCurrentPage(0);
            Alert.alert('Creation Complete', `Successfully created ${createdCount} customers!`);
          } catch (e) {
            Alert.alert('Error', `Error creating customers: ${(e as Error).message}`);
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
        <Text style={[textStyles.bodyMedium, styles.loadingText]}>Loading customers...</Text>
      </View>
    );
  }

  const totalCount = editableCustomers.length;
  const selectedCount = editableCustomers.filter((c) => c.isSelected && !c.isRemoved).length;
  const validCount = editableCustomers.filter((c) => c.isValid && !c.isRemoved).length;
  const errorCount = editableCustomers.filter((c) => c.hasErrors && !c.isRemoved).length;
  const warningCount = editableCustomers.filter((c) => !c.isRemoved).reduce((total, c) => total + c.warnings.length, 0);

  const totalPages = Math.max(1, Math.ceil(totalCount / ROWS_PER_PAGE));
  const startIndex = currentPage * ROWS_PER_PAGE;
  const endIndex = Math.min(startIndex + ROWS_PER_PAGE, totalCount);
  const pageCustomers = editableCustomers.slice(startIndex, endIndex);

  return (
    <View style={styles.container}>
      <View style={[styles.summaryCard, errorCount > 0 ? styles.summaryCardError : styles.summaryCardOk]}>
        <View style={styles.summaryHeaderRow}>
          <Text style={styles.summaryIcon}>{errorCount > 0 ? '⚠' : '✓'}</Text>
          <View style={styles.summaryTextBox}>
            <Text style={styles.summaryTitle}>New Customers</Text>
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
          <Pressable style={styles.createButton} disabled={isCreating} onPress={handleCreateCustomers}>
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
            <Text style={[styles.headerCell, styles.colNumber]}>Cust. #</Text>
            <Text style={[styles.headerCell, styles.colName]}>Name</Text>
            <Text style={[styles.headerCell, styles.colAddress]}>Address</Text>
            <Text style={[styles.headerCell, styles.colPhone]}>Phone</Text>
            <Text style={[styles.headerCell, styles.colEmail]}>Email</Text>
            <Text style={[styles.headerCell, styles.colContact]}>Contact</Text>
            <Text style={[styles.headerCell, styles.colType]}>Type</Text>
            <Text style={[styles.headerCell, styles.colActions]}>Actions</Text>
          </View>

          <ScrollView>
            {pageCustomers.map((customer) => (
              <CustomerRow
                key={customer.rowNumber}
                customer={customer}
                onChange={updateRow}
                onRemove={() => removeRow(customer)}
                onShowErrors={() => setErrorsModalCustomer(customer)}
                onToggleSelect={() => {
                  customer.isSelected = !customer.isSelected;
                  setEditableCustomers([...editableCustomers]);
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

      {errorsModalCustomer ? (
        <Modal visible transparent animationType="fade" onRequestClose={() => setErrorsModalCustomer(null)}>
          <View style={styles.modalBackdrop}>
            <View style={[styles.modalCard, shadows.card]}>
              <Text style={textStyles.heading3}>Row #{errorsModalCustomer.rowNumber} - Issues</Text>
              {errorsModalCustomer.errors.length > 0 ? (
                <>
                  <Text style={styles.issuesLabelError}>Errors:</Text>
                  {errorsModalCustomer.errors.map((e, i) => (
                    <Text key={i} style={styles.issueTextError}>
                      • {e.message}
                    </Text>
                  ))}
                </>
              ) : null}
              {errorsModalCustomer.warnings.length > 0 ? (
                <>
                  <Text style={styles.issuesLabelWarning}>Warnings:</Text>
                  {errorsModalCustomer.warnings.map((w, i) => (
                    <Text key={i} style={styles.issueTextWarning}>
                      • {w.message}
                    </Text>
                  ))}
                </>
              ) : null}
              <Pressable style={styles.modalCloseButton} onPress={() => setErrorsModalCustomer(null)}>
                <Text style={textStyles.buttonText}>Close</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      ) : null}

      <Modal visible={showHelp} transparent animationType="fade" onRequestClose={() => setShowHelp(false)}>
        <View style={styles.modalBackdrop}>
          <ScrollView style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Customer Creation Help</Text>
            <Text style={styles.helpSectionLabel}>How to create customers:</Text>
            <Text style={styles.helpLine}>1. Add rows manually or paste from clipboard</Text>
            <Text style={styles.helpLine}>2. Fill in customer data in the table</Text>
            <Text style={styles.helpLine}>3. Review validation results</Text>
            <Text style={styles.helpLine}>4. Select rows to create</Text>
            <Text style={styles.helpLine}>5. Tap "Create Selected"</Text>
            <Text style={styles.helpSectionLabel}>Quick Entry:</Text>
            <Text style={styles.helpLine}>• Tap "+1/+5/+10 Rows" to add blank rows</Text>
            <Text style={styles.helpLine}>• Paste multi-row data: [Cust #][Tab][Name][Tab][Address]...</Text>
            <Text style={styles.helpSectionLabel}>Visual Indicators:</Text>
            <Text style={styles.helpLine}>• Red rows have errors (cannot create)</Text>
            <Text style={styles.helpLine}>• Orange rows have warnings (can still create)</Text>
            <Text style={styles.helpLine}>• Blue rows have been edited</Text>
            <Pressable style={styles.modalCloseButton} onPress={() => setShowHelp(false)}>
              <Text style={textStyles.buttonText}>Close</Text>
            </Pressable>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

function CustomerRow({
  customer,
  onChange,
  onRemove,
  onShowErrors,
  onToggleSelect,
}: {
  customer: EditableCustomer;
  onChange: (customer: EditableCustomer, mutate: (c: EditableCustomer) => void, revalidate: boolean) => void;
  onRemove: () => void;
  onShowErrors: () => void;
  onToggleSelect: () => void;
}) {
  const rowStyle = customer.hasErrors
    ? styles.rowError
    : customer.hasWarnings
      ? styles.rowWarning
      : customer.isEdited
        ? styles.rowEdited
        : styles.rowDefault;

  return (
    <View style={[styles.tableRow, rowStyle]}>
      <Pressable style={styles.colCheckbox} disabled={!customer.isValid} onPress={onToggleSelect}>
        <Text style={styles.checkboxGlyph}>{customer.isSelected ? '☑' : '☐'}</Text>
      </Pressable>
      <View style={styles.colRow}>
        {customer.hasErrors ? <Text style={styles.rowIconError}>!</Text> : customer.hasWarnings ? <Text style={styles.rowIconWarning}>!</Text> : null}
        <Text style={styles.rowNumberText}>#{customer.rowNumber}</Text>
      </View>
      <TextInput
        style={[styles.cellInput, styles.colNumber, customer.errors.some((e) => e.field === 'customerNumber') && styles.cellInputError]}
        value={customer.customerNumber}
        onChangeText={(value) => onChange(customer, (c) => (c.customerNumber = value), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colName, customer.errors.some((e) => e.field === 'name') && styles.cellInputError]}
        value={customer.name}
        onChangeText={(value) => onChange(customer, (c) => (c.name = value), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colAddress, customer.errors.some((e) => e.field === 'address') && styles.cellInputError]}
        value={customer.address}
        onChangeText={(value) => onChange(customer, (c) => (c.address = value), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colPhone]}
        value={customer.phone ?? ''}
        onChangeText={(value) => onChange(customer, (c) => (c.phone = value || undefined), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colEmail]}
        value={customer.email ?? ''}
        onChangeText={(value) => onChange(customer, (c) => (c.email = value || undefined), true)}
      />
      <TextInput
        style={[styles.cellInput, styles.colContact]}
        value={customer.contactPerson ?? ''}
        onChangeText={(value) => onChange(customer, (c) => (c.contactPerson = value || undefined), false)}
      />
      <View style={[styles.colType, styles.typeChipRow]}>
        {CUSTOMER_TYPES.map((type) => (
          <Pressable
            key={type}
            style={[styles.typeChip, customer.customerType === type && styles.typeChipSelected]}
            onPress={() => onChange(customer, (c) => (c.customerType = type), false)}
          >
            <Text style={[styles.typeChipText, customer.customerType === type && styles.typeChipTextSelected]}>{type === 'business' ? 'Biz' : 'Res'}</Text>
          </Pressable>
        ))}
      </View>
      <View style={[styles.colActions, styles.actionsCell]}>
        {customer.hasErrors || customer.hasWarnings ? (
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
  table: { width: 1080 },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: colors.divider, paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small },
  headerCell: { fontWeight: 'bold', fontSize: 12 },
  tableRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small, paddingHorizontal: spacing.small, borderBottomWidth: 1, borderBottomColor: colors.divider },
  rowDefault: { backgroundColor: colors.card },
  rowError: { backgroundColor: `${colors.error}14` },
  rowWarning: { backgroundColor: `${colors.warning}14` },
  rowEdited: { backgroundColor: `${colors.info}14` },
  colCheckbox: { width: 36, alignItems: 'center' },
  colRow: { width: 50, flexDirection: 'row', alignItems: 'center' },
  colNumber: { width: 110 },
  colName: { width: 130 },
  colAddress: { width: 170 },
  colPhone: { width: 110 },
  colEmail: { width: 130 },
  colContact: { width: 110 },
  colType: { width: 110 },
  colActions: { width: 70 },
  rowNumberText: { fontSize: 12 },
  rowIconError: { color: colors.error, fontWeight: 'bold', marginRight: 2 },
  rowIconWarning: { color: colors.warning, fontWeight: 'bold', marginRight: 2 },
  cellInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 4, fontSize: 12, marginRight: spacing.small },
  cellInputError: { borderColor: colors.error },
  typeChipRow: { flexDirection: 'row', gap: 4 },
  typeChip: { borderWidth: 1, borderColor: colors.divider, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 4 },
  typeChipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  typeChipText: { fontSize: 11, color: colors.textSecondary },
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
