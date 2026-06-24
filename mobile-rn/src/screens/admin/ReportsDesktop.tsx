import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { COLUMNS, LOADERS, ReportType, SUMMARY_CARDS } from './Reports';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/reports_desktop.dart (verified against source on 2026-06-23).
 *
 * Deliberately reuses Reports.tsx's report loaders (`LOADERS`), summary-card configs
 * (`SUMMARY_CARDS`), and table column configs (`COLUMNS`) rather than re-deriving 5 new
 * Firestore aggregation pipelines from this Dart file. Confirmed by direct read that
 * `reports_desktop.dart`'s summary-stat keys (total/completed/pending/inTransit/
 * completionRate/onTimeRate/... for every one of the 5 report types) are byte-identical to
 * `reports_screen.dart`'s mobile variant already ported in Reports.tsx — same near-duplicate
 * pattern as bulk_upload_screen.dart/abaserve_import_screen.dart, which converged onto one
 * shared bulkImportService.ts. The one real difference (this Dart file queries ALL deliveries
 * and filters dates client-side, vs. the mobile file's server-side range query) is an
 * implementation detail with the same output shape — not worth a second pipeline.
 *
 * Layout-only port of the desktop-specific chrome: 220px sidebar (gradient header + 5 nav
 * items) instead of the mobile screen's horizontal chip row, plus an AppBar Date Range picker
 * (Modal with two `YYYY-MM-DD` inputs, same precedent as Reports.tsx/ClaimsDashboard.tsx — no
 * native date-range-picker library installed) instead of Reports.tsx's calendar-icon-triggered
 * version of the same modal.
 */
const SIDEBAR_ITEMS: { key: ReportType; label: string; icon: string }[] = [
  { key: 'delivery', label: 'Deliveries', icon: '🚚' },
  { key: 'driver', label: 'Drivers', icon: '🧑' },
  { key: 'claims', label: 'Claims', icon: '📋' },
  { key: 'customers', label: 'Customers', icon: '🏢' },
  { key: 'pod', label: 'PODs', icon: '🧾' },
];

const REPORT_TITLES: Record<ReportType, string> = {
  delivery: 'Delivery Report',
  driver: 'Driver Report',
  claims: 'Claims Report',
  customers: 'Customer Report',
  pod: 'POD Report',
};

function formatDateLabel(date: Date): string {
  return date.toLocaleDateString(undefined, { month: 'short', day: '2-digit', year: 'numeric' });
}

export default function ReportsDesktop() {
  const currentUser = useAuthStore((s) => s.currentUser);

  const [selectedReport, setSelectedReport] = useState<ReportType>('delivery');
  const [startDate, setStartDate] = useState(new Date(Date.now() - 7 * 86400000));
  const [endDate, setEndDate] = useState(new Date());
  const [isLoading, setIsLoading] = useState(false);
  const [reportData, setReportData] = useState<Record<string, unknown>[]>([]);
  const [summaryStats, setSummaryStats] = useState<Record<string, unknown>>({});
  const [showDateModal, setShowDateModal] = useState(false);
  const [dateStartText, setDateStartText] = useState('');
  const [dateEndText, setDateEndText] = useState('');

  const loadReport = useCallback(async () => {
    if (!currentUser) return;
    setIsLoading(true);
    try {
      const { data, summary } = await LOADERS[selectedReport](currentUser.companyId, startDate, endDate);
      setReportData(data);
      setSummaryStats(summary);
    } catch {
      setReportData([]);
      setSummaryStats({});
    } finally {
      setIsLoading(false);
    }
  }, [currentUser, selectedReport, startDate, endDate]);

  useEffect(() => {
    loadReport();
  }, [loadReport]);

  const applyDateRange = () => {
    const start = new Date(dateStartText);
    const end = new Date(dateEndText);
    if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime())) {
      setStartDate(start);
      setEndDate(end);
    }
    setShowDateModal(false);
  };

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Please log in</Text>
      </View>
    );
  }

  const columns = COLUMNS[selectedReport];
  const summaryCards = SUMMARY_CARDS[selectedReport];
  const tableWidth = columns.reduce((sum, c) => sum + c.width + spacing.small, 0);

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={[textStyles.heading3, { color: colors.onPrimary }]}>Reports</Text>
        <View style={styles.headerBarActions}>
          <Pressable onPress={loadReport}>
            <Text style={styles.headerBarIcon}>↻</Text>
          </Pressable>
          <Pressable
            onPress={() => {
              setDateStartText(startDate.toISOString().slice(0, 10));
              setDateEndText(endDate.toISOString().slice(0, 10));
              setShowDateModal(true);
            }}
          >
            <Text style={styles.headerBarIcon}>📅</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.body}>
        <View style={styles.sidebar}>
          <View style={styles.sidebarHeader}>
            <Text style={styles.sidebarHeaderIcon}>📊</Text>
            <Text style={[textStyles.heading3, styles.sidebarHeaderTitle]}>Reports</Text>
            <Text style={styles.sidebarHeaderSubtitle}>Business Analytics</Text>
          </View>
          {SIDEBAR_ITEMS.map((item) => {
            const isSelected = selectedReport === item.key;
            return (
              <Pressable key={item.key} style={[styles.sidebarItem, isSelected && styles.sidebarItemSelected]} onPress={() => setSelectedReport(item.key)}>
                <View style={[styles.sidebarItemIconBox, isSelected && styles.sidebarItemIconBoxSelected]}>
                  <Text style={styles.sidebarItemIcon}>{item.icon}</Text>
                </View>
                <Text style={[styles.sidebarItemLabel, isSelected && styles.sidebarItemLabelSelected]}>{item.label}</Text>
                {isSelected ? <View style={styles.sidebarItemIndicator} /> : null}
              </Pressable>
            );
          })}
        </View>

        <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
          <Text style={textStyles.heading2}>{REPORT_TITLES[selectedReport]}</Text>
          <Text style={styles.dateRangeSubtitle}>
            Showing data from {formatDateLabel(startDate)} to {formatDateLabel(endDate)}
          </Text>

          {isLoading ? (
            <ActivityIndicator color={colors.primary} style={styles.loadingIndicator} />
          ) : (
            <>
              <Text style={[textStyles.heading3, styles.overviewTitle]}>Overview</Text>
              <View style={styles.summaryGrid}>
                {summaryCards.map((card) => (
                  <View key={card.key} style={[styles.summaryCard, { backgroundColor: `${card.color}1A`, borderColor: `${card.color}4D` }]}>
                    <Text style={styles.summaryLabel}>{card.label}</Text>
                    <Text style={[styles.summaryValue, { color: card.color }]}>
                      {card.format ? card.format(summaryStats[card.key]) : String(summaryStats[card.key] ?? 0)}
                    </Text>
                  </View>
                ))}
              </View>

              {reportData.length === 0 ? (
                <View style={[styles.card, shadows.card, styles.emptyState]}>
                  <Text style={styles.emptyStateIcon}>📭</Text>
                  <Text style={styles.emptyStateText}>No data available</Text>
                </View>
              ) : (
                <ScrollView horizontal>
                  <View style={[styles.card, shadows.card, styles.tableCard, { width: tableWidth }]}>
                    <View style={styles.tableHeaderRow}>
                      {columns.map((col) => (
                        <Text key={col.label} style={[styles.tableHeaderCell, { width: col.width }]}>
                          {col.label}
                        </Text>
                      ))}
                    </View>
                    {reportData.map((row, index) => (
                      <View key={index} style={[styles.tableRow, index % 2 === 1 && styles.tableRowAlt]}>
                        {columns.map((col) => (
                          <View key={col.label} style={[styles.tableCell, { width: col.width }]}>
                            {col.render(row)}
                          </View>
                        ))}
                      </View>
                    ))}
                  </View>
                </ScrollView>
              )}
            </>
          )}
        </ScrollView>
      </View>

      <Modal visible={showDateModal} transparent animationType="fade" onRequestClose={() => setShowDateModal(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Date Range</Text>
            <Text style={styles.fieldLabel}>Start Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateStartText} onChangeText={setDateStartText} />
            <Text style={styles.fieldLabel}>End Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateEndText} onChangeText={setDateEndText} />
            <View style={styles.modalButtonRow}>
              <Pressable style={styles.modalSecondaryButton} onPress={() => setShowDateModal(false)}>
                <Text style={styles.modalSecondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalPrimaryButton} onPress={applyDateRange}>
                <Text style={textStyles.buttonText}>Apply</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.medium,
  },
  headerBarActions: { flexDirection: 'row', gap: spacing.medium },
  headerBarIcon: { fontSize: 18, color: colors.white },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 220, backgroundColor: colors.card, borderRightWidth: 1, borderRightColor: colors.divider },
  sidebarHeader: { padding: spacing.large, backgroundColor: colors.primary },
  sidebarHeaderIcon: { fontSize: 28 },
  sidebarHeaderTitle: { color: colors.white, marginTop: spacing.small },
  sidebarHeaderSubtitle: { color: 'rgba(255,255,255,0.8)', fontSize: 12, marginTop: 2 },
  sidebarItem: { flexDirection: 'row', alignItems: 'center', marginHorizontal: spacing.small, marginTop: spacing.small, padding: spacing.small + 4, borderRadius: radii.borderRadius },
  sidebarItemSelected: { backgroundColor: `${colors.primary}1A`, borderWidth: 1, borderColor: colors.primary },
  sidebarItemIconBox: { width: 32, height: 32, borderRadius: 6, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center' },
  sidebarItemIconBoxSelected: { backgroundColor: `${colors.primary}33` },
  sidebarItemIcon: { fontSize: 15 },
  sidebarItemLabel: { flex: 1, marginLeft: spacing.small + 4, fontSize: 14, fontWeight: '500', color: colors.textPrimary },
  sidebarItemLabelSelected: { fontWeight: '600', color: colors.primary },
  sidebarItemIndicator: { width: 3, height: 24, borderRadius: 2, backgroundColor: colors.primary },
  content: { flex: 1 },
  contentInner: { padding: spacing.large, paddingBottom: spacing.xLarge },
  dateRangeSubtitle: { color: colors.textSecondary, marginTop: 4, marginBottom: spacing.small },
  loadingIndicator: { marginTop: spacing.xLarge },
  overviewTitle: { marginTop: spacing.small },
  summaryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small + 4, marginTop: spacing.small, marginBottom: spacing.medium },
  summaryCard: { width: 190, borderRadius: radii.borderRadius, borderWidth: 1, padding: spacing.small + 4 },
  summaryLabel: { fontSize: 12, color: colors.textSecondary },
  summaryValue: { fontSize: 20, fontWeight: 'bold', marginTop: 4 },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium },
  emptyState: { alignItems: 'center', paddingVertical: spacing.large },
  emptyStateIcon: { fontSize: 40, opacity: 0.4 },
  emptyStateText: { color: colors.textSecondary, marginTop: spacing.small },
  tableCard: { padding: 0, overflow: 'hidden' },
  tableHeaderRow: { flexDirection: 'row', backgroundColor: `${colors.primary}1A`, paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small },
  tableHeaderCell: { fontWeight: 'bold', fontSize: 12, paddingRight: spacing.small },
  tableRow: { flexDirection: 'row', paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tableRowAlt: { backgroundColor: colors.background },
  tableCell: { paddingRight: spacing.small, justifyContent: 'center' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 360 },
  fieldLabel: { fontWeight: '600', fontSize: 13, marginTop: spacing.medium, marginBottom: spacing.small },
  dateInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  modalButtonRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalSecondaryButton: { flex: 1, alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  modalSecondaryButtonText: { color: colors.textSecondary, fontWeight: '600' },
  modalPrimaryButton: { flex: 1, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
});
