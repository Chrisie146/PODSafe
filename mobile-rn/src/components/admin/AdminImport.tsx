import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import {
  AppIcon,
  Card,
  IconButton,
  LoadingState,
  PrimaryButton,
  SecondaryButton,
  StatusChip,
} from '../ui';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

interface ImportLandingProps {
  title: string;
  description: string;
  requirements: string[];
  note?: string;
  onDownloadTemplate: () => void;
  onChooseFile: () => void;
}

/** Shared import entry state for CSV delivery sources. */
export function AdminImportLanding({
  title,
  description,
  requirements,
  note,
  onDownloadTemplate,
  onChooseFile,
}: ImportLandingProps) {
  return (
    <View style={styles.landing}>
      <View style={styles.landingIcon}>
        <AppIcon name="upload" size={32} color={colors.active} />
      </View>
      <Text style={textStyles.heading2}>{title}</Text>
      <Text style={styles.landingDescription}>{description}</Text>
      <View style={styles.landingActions}>
        <SecondaryButton
          label="Download template"
          icon="download"
          onPress={onDownloadTemplate}
        />
        <PrimaryButton
          label="Choose CSV file"
          icon="file"
          onPress={onChooseFile}
        />
      </View>
      <Card style={styles.requirements}>
        <Text style={textStyles.heading3}>Before you import</Text>
        <View style={styles.requirementList}>
          {requirements.map(requirement => (
            <View key={requirement} style={styles.requirement}>
              <AppIcon name="check" size={18} color={colors.verified} />
              <Text style={textStyles.bodyMedium}>{requirement}</Text>
            </View>
          ))}
        </View>
        {note ? <Text style={textStyles.bodySmall}>{note}</Text> : null}
      </Card>
    </View>
  );
}

interface ImportReviewSummaryProps {
  fileName: string;
  totalCount: number;
  validCount: number;
  errorCount: number;
  warningCount: number;
  removedCount: number;
  selectedCount: number;
  isImporting: boolean;
  allValidSelected: boolean;
  onChooseNewFile: () => void;
  onToggleAll: () => void;
  onImport: () => void;
  onHelp: () => void;
}

/** Shared parse/validation summary for CSV review tables. */
export function AdminImportReviewSummary({
  fileName,
  totalCount,
  validCount,
  errorCount,
  warningCount,
  removedCount,
  selectedCount,
  isImporting,
  allValidSelected,
  onChooseNewFile,
  onToggleAll,
  onImport,
  onHelp,
}: ImportReviewSummaryProps) {
  const reviewTone = errorCount
    ? 'error'
    : warningCount
    ? 'warning'
    : 'success';
  const reviewLabel = errorCount
    ? 'Review errors'
    : warningCount
    ? 'Review warnings'
    : 'Ready to import';
  return (
    <Card style={styles.summary}>
      <View style={styles.summaryHeader}>
        <View style={styles.summaryIcon}>
          <AppIcon
            name={errorCount ? 'alert' : 'file'}
            size={24}
            color={errorCount ? colors.critical : colors.active}
          />
        </View>
        <View style={styles.summaryCopy}>
          <Text numberOfLines={1} style={textStyles.heading3}>
            {fileName}
          </Text>
          <Text style={textStyles.bodySmall}>{totalCount} rows parsed</Text>
        </View>
        <IconButton
          icon="info"
          accessibilityLabel="Import help"
          onPress={onHelp}
        />
      </View>
      <View style={styles.statuses}>
        <StatusChip label={`${validCount} valid`} tone="success" icon="check" />
        <StatusChip
          label={`${errorCount} errors`}
          tone={errorCount ? 'error' : 'neutral'}
          icon={errorCount ? 'alert' : undefined}
        />
        <StatusChip
          label={`${warningCount} warnings`}
          tone={warningCount ? 'warning' : 'neutral'}
          icon={warningCount ? 'alert' : undefined}
        />
      </View>
      {removedCount ? (
        <Text style={textStyles.bodySmall}>
          {removedCount} row{removedCount === 1 ? '' : 's'} removed from this
          import.
        </Text>
      ) : null}
      <StatusChip
        label={reviewLabel}
        tone={reviewTone}
        icon={reviewTone === 'success' ? 'check' : 'alert'}
      />
      <View style={styles.summaryActions}>
        <SecondaryButton
          label="Choose new file"
          icon="upload"
          onPress={onChooseNewFile}
        />
        <SecondaryButton
          label={allValidSelected ? 'Clear valid rows' : 'Select valid rows'}
          icon={allValidSelected ? 'close' : 'check'}
          onPress={onToggleAll}
        />
        <PrimaryButton
          label={`Import selected (${selectedCount})`}
          icon="upload"
          loading={isImporting}
          disabled={selectedCount === 0}
          onPress={onImport}
        />
      </View>
    </Card>
  );
}

export function AdminImportLoading({ title }: { title: string }) {
  return (
    <View style={styles.loading}>
      <LoadingState
        title={title}
        message="Reading the CSV and validating delivery rows."
      />
    </View>
  );
}

const styles = StyleSheet.create({
  landing: {
    alignItems: 'center',
    flexGrow: 1,
    gap: spacing.medium,
    justifyContent: 'center',
    padding: spacing.large,
  },
  landingIcon: {
    alignItems: 'center',
    backgroundColor: colors.activeMuted,
    borderRadius: 28,
    height: 64,
    justifyContent: 'center',
    width: 64,
  },
  landingDescription: {
    ...textStyles.bodyMedium,
    maxWidth: 520,
    textAlign: 'center',
  },
  landingActions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.small,
    justifyContent: 'center',
  },
  requirements: { gap: spacing.medium, maxWidth: 560, width: '100%' },
  requirementList: { gap: spacing.small },
  requirement: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
  },
  summary: { gap: spacing.medium, margin: spacing.medium },
  summaryHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
  },
  summaryIcon: {
    alignItems: 'center',
    backgroundColor: colors.activeMuted,
    borderRadius: 20,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  summaryCopy: { flex: 1, minWidth: 0 },
  statuses: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  summaryActions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.small,
  },
  loading: { flex: 1, justifyContent: 'center' },
});
