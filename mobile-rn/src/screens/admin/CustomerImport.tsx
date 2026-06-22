import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { pick, types } from '@react-native-documents/picker';
import { useAuthStore } from '../../stores/useAuthStore';
import { useCustomerStore } from '../../stores/useCustomerStore';
import { EditableCustomer } from '../../models/editableCustomer';
import { CustomerType } from '../../models/customer';
import { ImportError, ParsedCustomer, parseCustomerCsv } from '../../repositories/customerImportService';
import { exportToCSV } from '../../repositories/csvExportService';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/customer_import_screen.dart (verified against source on
 * 2026-06-22) — CSV-based bulk customer import: download a template, upload a CSV,
 * review/edit/validate in a table, then import selected rows.
 *
 * Deviations from the Flutter source:
 * - File picking uses @react-native-documents/picker (the actively-maintained successor
 *   to the now-deprecated react-native-document-picker) instead of file_picker; reading
 *   the picked file's text content uses RN's built-in fetch() against the returned URI
 *   (`(await fetch(uri)).text()`), avoiding a need for react-native-fs for one read.
 * - Customer Type uses a chip selector instead of a DropdownButton (house convention).
 * - "Add Rows"/wide-table layout notes from CustomerCreation.tsx apply here too — see
 *   that file's class-level comment.
 */
const ROWS_PER_PAGE = 50;
const CUSTOMER_TYPES: CustomerType[] = ['business', 'residential'];

export default function CustomerImport() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const customers = useCustomerStore((s) => s.customers);
  const initialize = useCustomerStore((s) => s.initialize);
  const importCustomers = useCustomerStore((s) => s.importCustomers);

  const [isInitialized, setIsInitialized] = useState(false);
  const [editableCustomers, setEditableCustomers] = useState<EditableCustomer[] | null>(null);
  const [fileErrors, setFileErrors] = useState<ImportError[]>([]);
  const [existingNumbers, setExistingNumbers] = useState<Set<string>>(new Set());
  const [isLoading, setIsLoading] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [fileName, setFileName] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(0);
  const [errorsModalCustomer, setErrorsModalCustomer] = useState<EditableCustomer | null>(null);
  const [showHelp, setShowHelp] = useState(false);

  useEffect(() => {
    if (!currentUser) return;
    initialize(currentUser.companyId).then(() => setIsInitialized(true));
  }, [currentUser, initialize]);

  useEffect(() => {
    setExistingNumbers(new Set(customers.map((c) => c.customerNumber)));
  }, [customers]);

  const revalidateAll = (list: EditableCustomer[]) => {
    const existing = Array.from(existingNumbers);
    list.forEach((c) => c.validate(existing, list));
    setEditableCustomers([...list]);
  };

  const pickFile = async () => {
    try {
      const [result] = await pick({ type: types.csv });
      if (!result) return;

      setIsLoading(true);
      setFileName(result.name ?? 'customers.csv');
      setEditableCustomers(null);
      setFileErrors([]);

      const response = await fetch(result.uri);
      const csvContent = await response.text();
      const parseResult = parseCustomerCsv(csvContent);

      const editableList = parseResult.validCustomers.map((parsed) => EditableCustomer.fromParsed(parsed));
      const existing = Array.from(existingNumbers);
      editableList.forEach((c) => c.validate(existing, editableList));

      setEditableCustomers(editableList);
      setFileErrors(parseResult.errors);
      setIsLoading(false);
      setCurrentPage(0);

      const validCount = editableList.filter((c) => c.isValid).length;
      const errorCount = editableList.filter((c) => c.hasErrors).length + parseResult.errors.length;
      const warningCount = editableList.reduce((total, c) => total + c.warnings.length, 0);
      Alert.alert('File Parsed', `Parsed ${editableList.length} rows: ${validCount} valid, ${errorCount} errors, ${warningCount} warnings`);
    } catch (e) {
      setIsLoading(false);
      Alert.alert('Error', `Error reading file: ${(e as Error).message}`);
    }
  };

  const downloadTemplate = async () => {
    try {
      const headers = [
        'Customer Number',
        'Customer Name',
        'Address',
        'Contact Person',
        'Phone',
        'Email',
        'Delivery Instructions',
        'Account Number',
        'Customer Type',
        'Tags',
        'Active',
      ];
      const rows = [
        [
          'BOX001',
          'Boxer Superstore',
          '123 Main Street, Cape Town, 8001',
          'John Smith',
          '+27 21 123 4567',
          'john@boxer.co.za',
          'Use loading dock at rear',
          'ACC-12345',
          'business',
          'retail, priority',
          'true',
        ],
        [
          'PICK001',
          'Pick n Pay Rondebosch',
          '456 Main Road, Rondebosch, 7700',
          'Jane Doe',
          '+27 21 987 6543',
          'jane@pnp.co.za',
          'Deliver before 8am',
          'ACC-67890',
          'business',
          'retail',
          'true',
        ],
      ];

      await exportToCSV('customer_import_template', headers, rows);
      Alert.alert('Success', '✓ Template downloaded successfully');
    } catch (e) {
      Alert.alert('Error', `Error downloading template: ${(e as Error).message}`);
    }
  };

  const toggleAllSelections = (selected: boolean) => {
    if (!editableCustomers) return;
    editableCustomers.forEach((c) => {
      if (!c.isRemoved && c.isValid) c.isSelected = selected;
    });
    setEditableCustomers([...editableCustomers]);
  };

  const toggleRemoved = (customer: EditableCustomer) => {
    if (!editableCustomers) return;
    customer.isRemoved = !customer.isRemoved;
    if (customer.isRemoved) customer.isSelected = false;
    revalidateAll(editableCustomers);
  };

  const updateRow = (customer: EditableCustomer, mutate: (c: EditableCustomer) => void, shouldRevalidate: boolean) => {
    if (!editableCustomers) return;
    mutate(customer);
    customer.isEdited = true;
    if (shouldRevalidate) {
      customer.validate(Array.from(existingNumbers), editableCustomers);
    }
    setEditableCustomers([...editableCustomers]);
  };

  const handleImport = async () => {
    if (!editableCustomers || !currentUser) return;
    const selectedValid = editableCustomers.filter((c) => c.isSelected && c.isValid && !c.isRemoved);

    if (selectedValid.length === 0) {
      Alert.alert('Notice', 'No valid customers selected for import');
      return;
    }

    Alert.alert('Confirm Import', `Import ${selectedValid.length} selected customers?\n\nThis will create new customer records in the database.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Import',
        onPress: async () => {
          setIsImporting(true);
          try {
            const parsedCustomers = selectedValid.map(
              (c) =>
                new ParsedCustomer({
                  rowNumber: 0,
                  customerNumber: c.customerNumber,
                  name: c.name,
                  address: c.address,
                  contactPerson: c.contactPerson,
                  phone: c.phone,
                  email: c.email,
                  deliveryInstructions: c.deliveryInstructions,
                  accountNumber: c.accountNumber,
                  customerType: c.customerType,
                  tags: c.tags,
                  isActive: c.isActive,
                }),
            );

            const importedCount = selectedValid.length;
            await importCustomers(parsedCustomers);

            setIsImporting(false);
            setEditableCustomers(null);
            setFileName(null);
            setFileErrors([]);
            Alert.alert('Import Complete', `Successfully imported ${importedCount} customers!`);
          } catch (e) {
            setIsImporting(false);
            Alert.alert('Error', `Error importing customers: ${(e as Error).message}`);
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

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  if (!editableCustomers) {
    return (
      <ScrollView style={styles.container} contentContainerStyle={styles.uploadPromptContent}>
        <Text style={styles.uploadIcon}>📤</Text>
        <Text style={textStyles.heading2}>Import Customers</Text>
        <Text style={[textStyles.bodyMedium, styles.uploadSubtitle]}>
          Upload a CSV file with your customer data. Review and edit before importing.
        </Text>

        <View style={styles.uploadButtonRow}>
          <Pressable style={styles.secondaryButton} onPress={downloadTemplate}>
            <Text style={styles.secondaryButtonText}>⬇ Download Template</Text>
          </Pressable>
          <Pressable style={styles.primaryButton} onPress={pickFile}>
            <Text style={textStyles.buttonText}>📁 Choose CSV File</Text>
          </Pressable>
        </View>

        <View style={[styles.infoCard, shadows.card]}>
          <Text style={styles.infoCardTitle}>Required Columns:</Text>
          <Text style={textStyles.bodySmall}>• Customer Number - Unique identifier</Text>
          <Text style={textStyles.bodySmall}>• Customer Name - Full name</Text>
          <Text style={textStyles.bodySmall}>• Address - Complete address</Text>
          <Text style={styles.infoCardOptional}>
            Optional: Contact Person, Phone, Email, Delivery Instructions, Account Number, Customer Type, Tags, Active
          </Text>
        </View>
      </ScrollView>
    );
  }

  const activeCustomers = editableCustomers.filter((c) => !c.isRemoved);
  const totalCount = editableCustomers.length;
  const selectedCount = activeCustomers.filter((c) => c.isSelected).length;
  const validCount = activeCustomers.filter((c) => c.isValid).length;
  const errorCount = activeCustomers.filter((c) => c.hasErrors).length + fileErrors.length;
  const warningCount = activeCustomers.reduce((total, c) => total + c.warnings.length, 0);
  const removedCount = editableCustomers.length - activeCustomers.length;

  const totalPages = Math.max(1, Math.ceil(activeCustomers.length / ROWS_PER_PAGE));
  const startIndex = currentPage * ROWS_PER_PAGE;
  const endIndex = Math.min(startIndex + ROWS_PER_PAGE, activeCustomers.length);
  const pageCustomers = activeCustomers.slice(startIndex, endIndex);

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
          <Pressable style={styles.createButton} disabled={isImporting} onPress={handleImport}>
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
                onRemove={() => toggleRemoved(customer)}
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
            Page {currentPage + 1} of {totalPages} (showing {startIndex + 1}-{endIndex} of {activeCustomers.length})
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
            <Text style={textStyles.heading3}>Customer Import Help</Text>
            <Text style={styles.helpSectionLabel}>How to use customer import:</Text>
            <Text style={styles.helpLine}>1. Download the CSV template</Text>
            <Text style={styles.helpLine}>2. Fill in your customer data</Text>
            <Text style={styles.helpLine}>3. Upload the CSV file</Text>
            <Text style={styles.helpLine}>4. Review and edit data in the table</Text>
            <Text style={styles.helpLine}>5. Select rows to import</Text>
            <Text style={styles.helpLine}>6. Tap "Import Selected"</Text>
            <Text style={styles.helpSectionLabel}>Editing Features:</Text>
            <Text style={styles.helpLine}>• Tap any cell to edit</Text>
            <Text style={styles.helpLine}>• Select customer type from chips</Text>
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
  fileErrorsBox: { backgroundColor: `${colors.error}1A`, padding: spacing.medium },
  fileErrorsTitle: { color: colors.error, fontWeight: 'bold' },
  fileErrorText: { color: colors.error, marginTop: 4 },
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
