import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { OcrFields } from '../models/ocrFields';
import { PodDetectionFlags } from '../models/pod';
import { colors, radii, spacing, shadows } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

/**
 * Ported from lib/widgets/pod_preview_card.dart (verified against source on 2026-06-22).
 * Reusable preview of extracted OCR fields — used by DocumentIntake.tsx now; the
 * `isCompact` variant is for the admin POD review dashboard, ported here too since it's
 * the same source file (that screen itself lands in Phase 3).
 */
interface PodPreviewCardProps {
  fields: OcrFields;
  flags?: PodDetectionFlags;
  onEdit?: () => void;
  isCompact?: boolean;
}

export default function PodPreviewCard({ fields, flags, onEdit, isCompact = false }: PodPreviewCardProps) {
  if (isCompact) {
    return <CompactCard fields={fields} flags={flags} />;
  }
  return <FullCard fields={fields} flags={flags} onEdit={onEdit} />;
}

function FullCard({ fields, flags, onEdit }: { fields: OcrFields; flags?: PodDetectionFlags; onEdit?: () => void }) {
  const showWarnings = fields.ocrRawText?.toLowerCase().includes('warning') === true;
  const warnings: string[] = [];
  if (!fields.invoiceNo) warnings.push('Invoice number missing');
  if (fields.totalIncl == null) warnings.push('Total amount not found');
  if (!fields.documentDate) warnings.push('Date not detected');
  if (!fields.supplier) warnings.push('Supplier name missing');

  return (
    <View style={[styles.card, shadows.card]}>
      <View style={styles.header}>
        <View style={styles.headerIcon}>
          <Text style={styles.headerIconText}>✓</Text>
        </View>
        <Text style={[textStyles.heading3, styles.headerTitle]}>Invoice Details Extracted</Text>
        {flags?.ocrConfident ? <Text style={styles.verifiedIcon}>✔️</Text> : null}
      </View>

      <View style={styles.body}>
        <FieldRow label="Invoice Number" value={fields.invoiceNo} />
        <FieldRow label="Date" value={fields.documentDate?.toLocaleDateString()} />
        <FieldRow label="Total Amount" value={fields.totalIncl != null ? `R${fields.totalIncl.toFixed(2)}` : undefined} />
        <FieldRow label="Tax Amount" value={fields.totalVat != null ? `R${fields.totalVat.toFixed(2)}` : undefined} />

        <View style={styles.divider} />
        <Text style={styles.sectionLabel}>Additional Information</Text>
        <FieldRow label="Supplier" value={fields.supplier} />
        <FieldRow label="Customer" value={fields.customer} />
        <FieldRow label="Branch/Site" value={fields.branch} />
        <FieldRow label="Vehicle Registration" value={fields.truckReg} />
        <FieldRow label="Driver Name" value={fields.driverName} />

        {fields.totalQty != null || fields.totalMassKg != null ? (
          <>
            <View style={styles.divider} />
            <Text style={styles.sectionLabel}>Delivery Details</Text>
            {fields.totalQty != null ? <FieldRow label="Quantity" value={`${fields.totalQty} items`} /> : null}
            {fields.totalMassKg != null ? <FieldRow label="Total Weight" value={`${fields.totalMassKg.toFixed(2)} kg`} /> : null}
          </>
        ) : null}

        {flags ? (
          <>
            <View style={styles.divider} />
            <QualityIndicators flags={flags} />
          </>
        ) : null}

        {showWarnings && warnings.length > 0 ? <WarningsBox warnings={warnings} /> : null}
      </View>

      {onEdit ? (
        <Pressable style={styles.editButton} onPress={onEdit}>
          <Text style={textStyles.buttonText}>✎ Edit Details</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

function CompactCard({ fields, flags }: { fields: OcrFields; flags?: PodDetectionFlags }) {
  return (
    <View style={[styles.compactCard, shadows.card]}>
      <View style={styles.compactHeaderRow}>
        <View style={styles.compactHeaderText}>
          <Text style={styles.compactInvoice}>{fields.invoiceNo ?? 'Invoice #'}</Text>
          <Text style={styles.compactSupplier}>{fields.supplier ?? 'Unknown Supplier'}</Text>
        </View>
        {flags?.ocrConfident ? <Text style={styles.compactCheck}>✓</Text> : null}
      </View>
      <View style={styles.compactFooterRow}>
        <Text style={styles.compactAmount}>{fields.totalIncl != null ? `R${fields.totalIncl.toFixed(2)}` : 'R0.00'}</Text>
        <Text style={styles.compactDate}>{fields.documentDate?.toLocaleDateString() ?? 'Date N/A'}</Text>
      </View>
    </View>
  );
}

function FieldRow({ label, value }: { label: string; value?: string }) {
  const detected = value != null && value.length > 0;
  return (
    <View style={styles.fieldRow}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <Text style={[styles.fieldValue, !detected && styles.fieldValueMuted]} numberOfLines={1}>
        {detected ? value : '(Not detected)'}
      </Text>
    </View>
  );
}

function QualityIndicators({ flags }: { flags: PodDetectionFlags }) {
  return (
    <View style={styles.qualityBox}>
      <Text style={styles.qualityTitle}>Extraction Quality</Text>
      <View style={styles.qualityRow}>
        <QualityMetric label="Confidence" value={`${(flags.ocrConfidenceScore * 100).toFixed(0)}%`} isGood={flags.ocrConfidenceScore >= 0.85} />
        <QualityMetric label="Signature" value={flags.hasSignature ? 'Yes' : 'No'} isGood={flags.hasSignature} />
        <QualityMetric label="Stamp" value={flags.hasStamp ? 'Yes' : 'No'} isGood={flags.hasStamp} />
      </View>
    </View>
  );
}

function QualityMetric({ label, value, isGood }: { label: string; value: string; isGood: boolean }) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={[styles.metricValue, { color: isGood ? colors.success : colors.warning }]}>
        {isGood ? '✓' : 'ℹ'} {value}
      </Text>
    </View>
  );
}

function WarningsBox({ warnings }: { warnings: string[] }) {
  return (
    <View style={styles.warningsBox}>
      <Text style={styles.warningsTitle}>⚠ Review Recommended</Text>
      {warnings.map((warning) => (
        <Text key={warning} style={styles.warningItem}>
          • {warning}
        </Text>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, overflow: 'hidden', marginBottom: spacing.medium },
  header: { flexDirection: 'row', alignItems: 'center', padding: spacing.medium, backgroundColor: `${colors.info}1A` },
  headerIcon: { width: 32, height: 32, borderRadius: 16, backgroundColor: colors.info, alignItems: 'center', justifyContent: 'center' },
  headerIconText: { color: colors.white, fontWeight: 'bold' },
  headerTitle: { flex: 1, marginLeft: spacing.small + 4 },
  verifiedIcon: { fontSize: 18 },
  body: { padding: spacing.medium },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  sectionLabel: { fontSize: 12, fontWeight: 'bold', color: colors.textSecondary, marginBottom: spacing.small + 4 },
  fieldRow: { marginBottom: spacing.small + 4 },
  fieldLabel: { fontSize: 11, color: colors.textSecondary, fontWeight: '500' },
  fieldValue: { fontSize: 13, fontWeight: '500', color: colors.textPrimary, marginTop: 2 },
  fieldValueMuted: { fontWeight: 'normal', color: colors.textSecondary },
  qualityBox: { backgroundColor: `${colors.info}14`, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: `${colors.info}66`, padding: spacing.small + 4 },
  qualityTitle: { fontSize: 12, fontWeight: 'bold', color: colors.info, marginBottom: spacing.small },
  qualityRow: { flexDirection: 'row', gap: spacing.medium },
  metric: { flex: 1 },
  metricLabel: { fontSize: 10, color: colors.textSecondary },
  metricValue: { fontSize: 11, fontWeight: '500', marginTop: 2 },
  warningsBox: { backgroundColor: `${colors.warning}14`, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: `${colors.warning}80`, padding: spacing.small + 4, marginTop: spacing.medium },
  warningsTitle: { fontSize: 12, fontWeight: 'bold', color: colors.warning, marginBottom: spacing.small },
  warningItem: { fontSize: 11, color: colors.warning, marginBottom: 2 },
  editButton: { backgroundColor: colors.warning, alignItems: 'center', paddingVertical: spacing.small + 4, margin: spacing.medium, borderRadius: radii.buttonRadius },
  compactCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.small + 4 },
  compactHeaderRow: { flexDirection: 'row', alignItems: 'flex-start' },
  compactHeaderText: { flex: 1 },
  compactInvoice: { fontWeight: 'bold', fontSize: 14, color: colors.textPrimary },
  compactSupplier: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  compactCheck: { color: colors.success, fontSize: 18 },
  compactFooterRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: spacing.small },
  compactAmount: { fontWeight: 'bold', fontSize: 12, color: colors.textPrimary },
  compactDate: { fontSize: 11, color: colors.textSecondary },
});
