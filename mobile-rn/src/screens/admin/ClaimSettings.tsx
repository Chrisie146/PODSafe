import React, { useEffect, useState } from 'react';
import { Alert, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import {
  AppHeader,
  AppIcon,
  Card,
  EmptyState,
  LoadingState,
  PrimaryButton,
} from '../../components/ui';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { ClaimType, ALL_CLAIM_TYPES, claimTypeDisplayText } from '../../models/claim';
import { ClaimWorkflowPreset, ALL_CLAIM_WORKFLOW_PRESETS, claimWorkflowPresetDisplayName, defaultWorkflowFor } from '../../models/companyClaimSettings';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/claim_settings_screen.dart
 * (`ClaimSettingsMobile`, verified against source on 2026-06-22) — admin configuration
 * screen for company-wide claim policy.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the >900px
 * desktop branch lands in Phase 4.
 *
 * Deviations from the Flutter source:
 * - 6-tab `TabBar` → custom horizontal tab strip + conditional content.
 * - `RadioListTile`/`FilterChip`/`SwitchListTile` → custom radio rows, Chip pattern, and a
 *   `SwitchRow` helper.
 * - Settings seed local form state once on first fetch (mirrors the Dart initState-only load).
 * - Added `updateCompanySettings()`/`updateSettings()` for the admin settings-write path.
 *
 * UI/UX refresh (Operations Precision): the custom navy header, emoji save/select/check/
 * info/warning/radio/tool glyphs are replaced with the shared AppHeader, SVG AppIcon, Card,
 * EmptyState, and button primitives, plus a fixed bottom save bar. Semantic tokens only.
 */
const TABS = ['General', 'Claim Types', 'Workflow', 'Requirements', 'Automation', 'Features'] as const;
type TabName = (typeof TABS)[number];

interface ClaimSettingsProps {
  navigation: { goBack: () => void };
}

function workflowPresetDescription(preset: ClaimWorkflowPreset): string {
  switch (preset) {
    case 'simple':
      return 'Direct admin approval (fastest)';
    case 'standard':
      return 'Manager → Admin (recommended)';
    case 'enterprise':
      return 'Manager → Approver → Processor → Reviewer';
    case 'custom':
      return 'Build your own workflow';
  }
}

export default function ClaimSettings({ navigation }: ClaimSettingsProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const settings = useClaimStore((s) => s.settings);
  const isLoadingSettings = useClaimStore((s) => s.isLoadingSettings);
  const initialize = useClaimStore((s) => s.initialize);
  const updateSettings = useClaimStore((s) => s.updateSettings);

  const [activeTab, setActiveTab] = useState<TabName>('General');
  const [hasSeeded, setHasSeeded] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  const [claimIdPrefix, setClaimIdPrefix] = useState('CLM');
  const [claimIdStartNumber, setClaimIdStartNumber] = useState('1');
  const [slaHours, setSlaHours] = useState('24');
  const [filingDeadlineDays, setFilingDeadlineDays] = useState('');

  const [selectedClaimTypes, setSelectedClaimTypes] = useState<Set<ClaimType>>(new Set());
  const [workflowPreset, setWorkflowPreset] = useState<ClaimWorkflowPreset>('standard');

  const [photosMandatory, setPhotosMandatory] = useState(true);
  const [requirePhotoImmediate, setRequirePhotoImmediate] = useState(true);
  const [requirePhotoDelayed, setRequirePhotoDelayed] = useState(false);
  const [requireCustomerSignature, setRequireCustomerSignature] = useState(false);
  const [requireDriverSignature, setRequireDriverSignature] = useState(false);
  const [minPhotosRequired, setMinPhotosRequired] = useState('1');
  const [maxPhotosAllowed, setMaxPhotosAllowed] = useState('10');

  const [enableAutoApproval, setEnableAutoApproval] = useState(false);
  const [autoApproveAmount, setAutoApproveAmount] = useState('');
  const [autoApproveTypes, setAutoApproveTypes] = useState<Set<ClaimType>>(new Set());
  const [enableFraudDetection, setEnableFraudDetection] = useState(false);
  const [fraudAmount, setFraudAmount] = useState('');
  const [fraudFrequency, setFraudFrequency] = useState('');
  const [enablePatternDetection, setEnablePatternDetection] = useState(true);
  const [recurringThreshold, setRecurringThreshold] = useState('3');

  const [allowDriverFiling, setAllowDriverFiling] = useState(true);
  const [allowAdminFiling, setAllowAdminFiling] = useState(true);
  const [allowCustomerPortal, setAllowCustomerPortal] = useState(false);
  const [enableComments, setEnableComments] = useState(true);
  const [enableInternalNotes, setEnableInternalNotes] = useState(true);
  const [enablePushNotifications, setEnablePushNotifications] = useState(true);
  const [enableEmailNotifications, setEnableEmailNotifications] = useState(false);
  const [enableSMSNotifications, setEnableSMSNotifications] = useState(false);

  useEffect(() => {
    if (currentUser) {
      initialize(currentUser.companyId);
    }
  }, [currentUser, initialize]);

  useEffect(() => {
    if (!settings || hasSeeded) return;
    setHasSeeded(true);
    setClaimIdPrefix(settings.claimIdPrefix);
    setClaimIdStartNumber(String(settings.claimIdStartNumber));
    setSlaHours(String(settings.defaultSlaHours));
    setFilingDeadlineDays(settings.claimFilingDeadlineDays?.toString() ?? '');
    setSelectedClaimTypes(new Set(settings.enabledClaimTypes));
    setWorkflowPreset(settings.workflowPreset);
    setPhotosMandatory(settings.photosMandatory);
    setRequirePhotoImmediate(settings.requirePhotoForImmediate);
    setRequirePhotoDelayed(settings.requirePhotoForDelayed);
    setRequireCustomerSignature(settings.requireCustomerSignature);
    setRequireDriverSignature(settings.requireDriverSignature);
    setMinPhotosRequired(String(settings.minPhotosRequired));
    setMaxPhotosAllowed(String(settings.maxPhotosAllowed));
    setEnableAutoApproval(settings.enableAutoApproval);
    setAutoApproveAmount(settings.autoApproveUnderAmount?.toString() ?? '');
    setAutoApproveTypes(new Set(settings.autoApproveTypes ?? []));
    setEnableFraudDetection(settings.enableFraudDetection);
    setFraudAmount(settings.fraudThresholdAmount?.toString() ?? '');
    setFraudFrequency(settings.fraudThresholdFrequency?.toString() ?? '');
    setEnablePatternDetection(settings.enablePatternDetection);
    setRecurringThreshold(settings.recurringClaimThreshold?.toString() ?? '3');
    setAllowDriverFiling(settings.allowDriverFiling);
    setAllowAdminFiling(settings.allowAdminFiling);
    setAllowCustomerPortal(settings.allowCustomerPortal);
    setEnableComments(settings.enableComments);
    setEnableInternalNotes(settings.enableInternalNotes);
    setEnablePushNotifications(settings.enablePushNotifications);
    setEnableEmailNotifications(settings.enableEmailNotifications);
    setEnableSMSNotifications(settings.enableSMSNotifications);
  }, [settings, hasSeeded]);

  const toggleClaimType = (type: ClaimType) => {
    setSelectedClaimTypes((prev) => {
      const next = new Set(prev);
      if (next.has(type)) next.delete(type);
      else next.add(type);
      return next;
    });
  };

  const toggleAutoApproveType = (type: ClaimType) => {
    setAutoApproveTypes((prev) => {
      const next = new Set(prev);
      if (next.has(type)) next.delete(type);
      else next.add(type);
      return next;
    });
  };

  const handleSave = async () => {
    if (!settings) return;
    setIsSaving(true);
    try {
      const ok = await updateSettings({
        ...settings,
        enabledClaimTypes: Array.from(selectedClaimTypes),
        workflowPreset,
        photosMandatory,
        requirePhotoForImmediate: requirePhotoImmediate,
        requirePhotoForDelayed: requirePhotoDelayed,
        requireCustomerSignature,
        requireDriverSignature,
        minPhotosRequired: parseInt(minPhotosRequired, 10) || 1,
        maxPhotosAllowed: parseInt(maxPhotosAllowed, 10) || 10,
        defaultSlaHours: parseInt(slaHours, 10) || 24,
        claimFilingDeadlineDays: filingDeadlineDays.length > 0 ? parseInt(filingDeadlineDays, 10) : undefined,
        enableAutoApproval,
        autoApproveUnderAmount: autoApproveAmount.length > 0 ? parseFloat(autoApproveAmount) : undefined,
        autoApproveTypes: autoApproveTypes.size > 0 ? Array.from(autoApproveTypes) : undefined,
        enablePushNotifications,
        enableEmailNotifications,
        enableSMSNotifications,
        enableFraudDetection,
        fraudThresholdAmount: fraudAmount.length > 0 ? parseFloat(fraudAmount) : undefined,
        fraudThresholdFrequency: fraudFrequency.length > 0 ? parseInt(fraudFrequency, 10) : undefined,
        enablePatternDetection,
        recurringClaimThreshold: recurringThreshold.length > 0 ? parseInt(recurringThreshold, 10) : 3,
        allowDriverFiling,
        allowAdminFiling,
        allowCustomerPortal,
        enableComments,
        enableInternalNotes,
        claimIdPrefix: claimIdPrefix.length > 0 ? claimIdPrefix : 'CLM',
        claimIdStartNumber: parseInt(claimIdStartNumber, 10) || 1,
        updatedAt: new Date(),
      });

      if (ok) {
        Alert.alert('Success', 'Settings saved successfully');
      } else {
        Alert.alert('Error', useClaimStore.getState().errorMessage ?? 'Error saving settings');
      }
    } finally {
      setIsSaving(false);
    }
  };

  if (!settings && isLoadingSettings) {
    return (
      <View style={styles.container}>
        <AppHeader title="Claim settings" onBack={navigation.goBack} />
        <LoadingState title="Loading settings" message="Retrieving claim policy configuration." />
      </View>
    );
  }

  const previewNumber = (parseInt(claimIdStartNumber, 10) || 1).toString().padStart(4, '0');

  return (
    <View style={styles.container}>
      <AppHeader title="Claim settings" onBack={navigation.goBack} />

      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabStrip} contentContainerStyle={styles.tabStripContent}>
        {TABS.map((tab) => (
          <Pressable
            key={tab}
            accessibilityRole="tab"
            accessibilityState={{ selected: activeTab === tab }}
            style={[styles.tabButton, activeTab === tab && styles.tabButtonActive]}
            onPress={() => setActiveTab(tab)}
          >
            <Text style={[styles.tabButtonText, activeTab === tab && styles.tabButtonTextActive]}>{tab}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        {activeTab === 'General' ? (
          <>
            <SectionHeader title="Claim ID configuration" subtitle="Customize how claim IDs are generated" />
            <Card style={styles.card}>
              <FieldInput
                label="Claim ID prefix"
                placeholder="CLM"
                helperText="Prefix for claim IDs (e.g., CLM, CLAIM, ISS)"
                value={claimIdPrefix}
                onChangeText={(v) => setClaimIdPrefix(v.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5))}
              />
              <FieldInput
                label="Starting number"
                placeholder="1"
                helperText="First claim number (e.g., CLM-0001)"
                keyboardType="numeric"
                value={claimIdStartNumber}
                onChangeText={(v) => setClaimIdStartNumber(v.replace(/\D/g, ''))}
              />
              <View style={styles.previewBox}>
                <Text style={styles.previewText}>
                  Preview: {claimIdPrefix.length > 0 ? claimIdPrefix : 'CLM'}-{previewNumber}
                </Text>
              </View>
            </Card>

            <SectionHeader title="Time limits" subtitle="Configure deadlines and SLAs" />
            <Card style={styles.card}>
              <FieldInput label="Default SLA (hours)" placeholder="24" suffix="hours" keyboardType="numeric" value={slaHours} onChangeText={(v) => setSlaHours(v.replace(/\D/g, ''))} />
              <FieldInput
                label="Filing deadline (days)"
                placeholder="Leave empty for no deadline"
                helperText="Max days after delivery to file claim (optional)"
                suffix="days"
                keyboardType="numeric"
                value={filingDeadlineDays}
                onChangeText={(v) => setFilingDeadlineDays(v.replace(/\D/g, ''))}
              />
            </Card>
          </>
        ) : null}

        {activeTab === 'Claim Types' ? (
          <>
            <SectionHeader title="Enabled claim types" subtitle="Select which claim types drivers can submit" />
            <Card style={styles.card}>
              <Text style={styles.countText}>
                Selected: {selectedClaimTypes.size} of {ALL_CLAIM_TYPES.length}
              </Text>
              <View style={styles.chipWrap}>
                {ALL_CLAIM_TYPES.map((type) => (
                  <Chip key={type} label={claimTypeDisplayText(type)} selected={selectedClaimTypes.has(type)} onPress={() => toggleClaimType(type)} />
                ))}
              </View>
              <View style={styles.buttonRow}>
                <TextAction icon="check" label="Select all" onPress={() => setSelectedClaimTypes(new Set(ALL_CLAIM_TYPES))} />
                <TextAction icon="close" label="Clear all" onPress={() => setSelectedClaimTypes(new Set())} />
              </View>
            </Card>
            <View style={styles.warningBanner}>
              <AppIcon name="alert" size={18} color={colors.attention} />
              <Text style={styles.warningBannerText}>Drivers can only file claims for enabled types. At least one type must be selected.</Text>
            </View>
          </>
        ) : null}

        {activeTab === 'Workflow' ? (
          <>
            <SectionHeader title="Approval workflow" subtitle="Configure how claims are reviewed and approved" />
            <Card style={styles.card}>
              <Text style={styles.cardTitle}>Workflow preset</Text>
              {ALL_CLAIM_WORKFLOW_PRESETS.map((preset) => (
                <RadioRow
                  key={preset}
                  title={claimWorkflowPresetDisplayName(preset)}
                  subtitle={workflowPresetDescription(preset)}
                  selected={workflowPreset === preset}
                  onPress={() => setWorkflowPreset(preset)}
                />
              ))}
            </Card>

            {workflowPreset !== 'custom' ? (
              <Card style={styles.card}>
                <View style={styles.cardTitleRow}>
                  <AppIcon name="info" size={18} color={colors.shell} />
                  <Text style={styles.cardTitle}>Workflow levels</Text>
                </View>
                {defaultWorkflowFor(workflowPreset).map((role, index) => (
                  <View key={role.role} style={styles.workflowStepRow}>
                    <View style={styles.workflowStepBadge}>
                      <Text style={styles.workflowStepBadgeText}>{index + 1}</Text>
                    </View>
                    <View style={styles.workflowStepTextBox}>
                      <Text style={styles.workflowStepTitle}>{role.displayName}</Text>
                      <Text style={styles.workflowStepSubtitle}>SLA: {role.slaHours} hours</Text>
                    </View>
                    <AppIcon name="check" size={18} color={colors.verified} />
                  </View>
                ))}
              </Card>
            ) : (
              <Card style={styles.card}>
                <EmptyState
                  icon="settings"
                  title="Custom workflow builder"
                  message="Custom workflow configuration will be available in a future update."
                />
              </Card>
            )}
          </>
        ) : null}

        {activeTab === 'Requirements' ? (
          <>
            <SectionHeader title="Photo requirements" subtitle="Configure photo evidence requirements" />
            <Card style={styles.card}>
              <SwitchRow title="Photos mandatory" subtitle="Require at least one photo" value={photosMandatory} onValueChange={setPhotosMandatory} />
              <SwitchRow title="Require photo for immediate claims" subtitle="Filed at delivery site" value={requirePhotoImmediate} onValueChange={setRequirePhotoImmediate} />
              <SwitchRow title="Require photo for delayed claims" subtitle="Filed after delivery" value={requirePhotoDelayed} onValueChange={setRequirePhotoDelayed} />
              <View style={styles.divider} />
              <FieldInput label="Minimum photos required" placeholder="1" suffix="photos" keyboardType="numeric" value={minPhotosRequired} onChangeText={(v) => setMinPhotosRequired(v.replace(/\D/g, ''))} />
              <FieldInput label="Maximum photos allowed" placeholder="10" suffix="photos" keyboardType="numeric" value={maxPhotosAllowed} onChangeText={(v) => setMaxPhotosAllowed(v.replace(/\D/g, ''))} />
            </Card>

            <SectionHeader title="Signature requirements" subtitle="Configure signature requirements" />
            <Card style={styles.card}>
              <SwitchRow title="Require customer signature" subtitle="Customer must sign claim form" value={requireCustomerSignature} onValueChange={setRequireCustomerSignature} />
              <SwitchRow title="Require driver signature" subtitle="Driver must sign claim form" value={requireDriverSignature} onValueChange={setRequireDriverSignature} />
            </Card>
          </>
        ) : null}

        {activeTab === 'Automation' ? (
          <>
            <SectionHeader title="Auto-approval rules" subtitle="Automatically approve claims meeting criteria" />
            <Card style={styles.card}>
              <SwitchRow title="Enable auto-approval" subtitle="Automatically approve eligible claims" value={enableAutoApproval} onValueChange={setEnableAutoApproval} />
              {enableAutoApproval ? (
                <>
                  <View style={styles.divider} />
                  <FieldInput
                    label="Auto-approve under amount"
                    placeholder="Leave empty for no limit"
                    helperText="Claims below this amount will be auto-approved"
                    prefix="R"
                    keyboardType="decimal-pad"
                    value={autoApproveAmount}
                    onChangeText={setAutoApproveAmount}
                  />
                  <Text style={styles.cardTitle}>Auto-approve claim types</Text>
                  <View style={styles.chipWrap}>
                    {Array.from(selectedClaimTypes).map((type) => (
                      <Chip key={type} label={claimTypeDisplayText(type)} selected={autoApproveTypes.has(type)} onPress={() => toggleAutoApproveType(type)} />
                    ))}
                  </View>
                </>
              ) : null}
            </Card>

            <SectionHeader title="Fraud detection" subtitle="Detect potentially fraudulent claims" />
            <Card style={styles.card}>
              <SwitchRow title="Enable fraud detection" subtitle="Flag suspicious claim patterns" value={enableFraudDetection} onValueChange={setEnableFraudDetection} />
              {enableFraudDetection ? (
                <>
                  <View style={styles.divider} />
                  <FieldInput label="High-value threshold" placeholder="e.g., 1000" helperText="Flag claims above this amount" prefix="R" keyboardType="decimal-pad" value={fraudAmount} onChangeText={setFraudAmount} />
                  <FieldInput
                    label="Frequency threshold"
                    placeholder="e.g., 5"
                    helperText="Flag if driver files X claims per month"
                    suffix="claims/month"
                    keyboardType="numeric"
                    value={fraudFrequency}
                    onChangeText={(v) => setFraudFrequency(v.replace(/\D/g, ''))}
                  />
                </>
              ) : null}
            </Card>

            <SectionHeader title="Pattern detection" subtitle="Identify recurring claim patterns" />
            <Card style={styles.card}>
              <SwitchRow title="Enable pattern detection" subtitle="Detect recurring issues" value={enablePatternDetection} onValueChange={setEnablePatternDetection} />
              {enablePatternDetection ? (
                <>
                  <View style={styles.divider} />
                  <FieldInput
                    label="Recurring claim threshold"
                    placeholder="3"
                    helperText="Same issue X times = pattern (notify management)"
                    suffix="occurrences"
                    keyboardType="numeric"
                    value={recurringThreshold}
                    onChangeText={(v) => setRecurringThreshold(v.replace(/\D/g, ''))}
                  />
                </>
              ) : null}
            </Card>
          </>
        ) : null}

        {activeTab === 'Features' ? (
          <>
            <SectionHeader title="Filing permissions" subtitle="Control who can file claims" />
            <Card style={styles.card}>
              <SwitchRow title="Allow driver filing" subtitle="Drivers can file claims via mobile app" value={allowDriverFiling} onValueChange={setAllowDriverFiling} />
              <SwitchRow title="Allow admin filing" subtitle="Admins can file claims on behalf of drivers" value={allowAdminFiling} onValueChange={setAllowAdminFiling} />
              <SwitchRow title="Customer portal" subtitle="Customers can view/file claims (coming soon)" value={allowCustomerPortal} onValueChange={() => {}} disabled />
            </Card>

            <SectionHeader title="Communication features" subtitle="Enable collaboration features" />
            <Card style={styles.card}>
              <SwitchRow title="Enable comments" subtitle="Users can add comments to claims" value={enableComments} onValueChange={setEnableComments} />
              <SwitchRow title="Enable internal notes" subtitle="Admin-only internal notes" value={enableInternalNotes} onValueChange={setEnableInternalNotes} />
            </Card>

            <SectionHeader title="Notifications" subtitle="Configure notification channels" />
            <Card style={styles.card}>
              <SwitchRow title="Push notifications" subtitle="In-app notifications" value={enablePushNotifications} onValueChange={setEnablePushNotifications} />
              <SwitchRow title="Email notifications" subtitle="Send email updates" value={enableEmailNotifications} onValueChange={setEnableEmailNotifications} />
              <SwitchRow title="SMS notifications" subtitle="Send SMS alerts (additional charges apply)" value={enableSMSNotifications} onValueChange={setEnableSMSNotifications} />
            </Card>
          </>
        ) : null}
      </ScrollView>

      <View style={styles.bottomBar}>
        <PrimaryButton label="Save settings" icon="check" loading={isSaving} onPress={handleSave} />
      </View>
    </View>
  );
}

function SectionHeader({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <View style={styles.sectionHeader}>
      <Text style={styles.sectionHeaderTitle}>{title}</Text>
      <Text style={styles.sectionHeaderSubtitle}>{subtitle}</Text>
    </View>
  );
}

function TextAction({ icon, label, onPress }: { icon: 'check' | 'close'; label: string; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} style={styles.textButton} onPress={onPress}>
      <AppIcon name={icon} size={16} color={colors.shell} />
      <Text style={styles.textButtonLabel}>{label}</Text>
    </Pressable>
  );
}

function FieldInput({
  label,
  placeholder,
  helperText,
  prefix,
  suffix,
  keyboardType,
  value,
  onChangeText,
}: {
  label: string;
  placeholder: string;
  helperText?: string;
  prefix?: string;
  suffix?: string;
  keyboardType?: 'numeric' | 'decimal-pad';
  value: string;
  onChangeText: (text: string) => void;
}) {
  return (
    <View style={styles.fieldGroup}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <View style={styles.fieldInputRow}>
        {prefix ? <Text style={styles.fieldAffix}>{prefix}</Text> : null}
        <TextInput
          style={styles.fieldInput}
          placeholder={placeholder}
          placeholderTextColor={colors.contentSecondary}
          accessibilityLabel={label}
          keyboardType={keyboardType}
          value={value}
          onChangeText={onChangeText}
        />
        {suffix ? <Text style={styles.fieldAffix}>{suffix}</Text> : null}
      </View>
      {helperText ? <Text style={styles.fieldHelperText}>{helperText}</Text> : null}
    </View>
  );
}

function SwitchRow({
  title,
  subtitle,
  value,
  onValueChange,
  disabled,
}: {
  title: string;
  subtitle: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <View style={styles.switchRow}>
      <View style={styles.switchRowTextBox}>
        <Text style={styles.switchRowTitle}>{title}</Text>
        <Text style={styles.switchRowSubtitle}>{subtitle}</Text>
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        disabled={disabled}
        trackColor={{ true: colors.shell, false: colors.border }}
        thumbColor={colors.surface}
      />
    </View>
  );
}

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      style={[styles.chip, selected && styles.chipSelected]}
      onPress={onPress}
    >
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function RadioRow({ title, subtitle, selected, onPress }: { title: string; subtitle: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="radio" accessibilityState={{ selected }} style={styles.radioRow} onPress={onPress}>
      <View style={[styles.radioOuter, selected && styles.radioOuterSelected]}>{selected ? <View style={styles.radioInner} /> : null}</View>
      <View style={styles.radioTextBox}>
        <Text style={styles.radioTitle}>{title}</Text>
        <Text style={styles.radioSubtitle}>{subtitle}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.canvas },
  tabStrip: { backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border, flexGrow: 0 },
  tabStripContent: { paddingHorizontal: spacing.medium, gap: spacing.small },
  tabButton: { paddingHorizontal: spacing.medium, paddingVertical: spacing.medium, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabButtonActive: { borderBottomColor: colors.shell },
  tabButtonText: { ...textStyles.label, color: colors.contentSecondary },
  tabButtonTextActive: { color: colors.shell },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  sectionHeader: { marginBottom: spacing.small + 4 },
  sectionHeaderTitle: { ...textStyles.heading3 },
  sectionHeaderSubtitle: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 2 },
  card: { marginBottom: spacing.large },
  cardTitle: { ...textStyles.label, fontWeight: '700', marginTop: spacing.small, marginBottom: spacing.small },
  cardTitleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginBottom: spacing.small },
  countText: { ...textStyles.bodySmall, color: colors.contentSecondary, marginBottom: spacing.small + 4 },
  fieldGroup: { marginBottom: spacing.medium },
  fieldLabel: { ...textStyles.label, marginBottom: spacing.small },
  fieldInputRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  fieldInput: { flex: 1, ...textStyles.bodyLarge, borderWidth: 1, borderColor: colors.border, borderRadius: radii.inputRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, minHeight: 48, backgroundColor: colors.surface },
  fieldAffix: { ...textStyles.bodySmall, color: colors.contentSecondary },
  fieldHelperText: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 4 },
  previewBox: { backgroundColor: colors.activeMuted, borderRadius: radii.inputRadius, padding: spacing.small + 4, marginTop: spacing.small },
  previewText: { ...textStyles.label, color: colors.shell, fontWeight: '700' },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.inputRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
  chipSelected: { backgroundColor: colors.activeMuted, borderColor: colors.shell },
  chipText: { ...textStyles.bodySmall, color: colors.contentSecondary },
  chipTextSelected: { color: colors.shell, fontWeight: '600' },
  buttonRow: { flexDirection: 'row', gap: spacing.large, marginTop: spacing.medium },
  textButton: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, paddingVertical: spacing.small },
  textButtonLabel: { ...textStyles.labelSmall, color: colors.shell },
  warningBanner: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, backgroundColor: colors.attentionMuted, borderRadius: radii.inputRadius, borderWidth: 1, borderColor: colors.attention, padding: spacing.medium },
  warningBannerText: { ...textStyles.bodySmall, color: colors.contentPrimary, flex: 1 },
  divider: { height: 1, backgroundColor: colors.border, marginVertical: spacing.medium },
  switchRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4 },
  switchRowTextBox: { flex: 1, marginRight: spacing.small },
  switchRowTitle: { ...textStyles.bodyMedium, fontWeight: '500' },
  switchRowSubtitle: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 2 },
  radioRow: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.small + 4, paddingVertical: spacing.small + 4 },
  radioOuter: { width: 20, height: 20, borderRadius: 10, borderWidth: 2, borderColor: colors.border, alignItems: 'center', justifyContent: 'center', marginTop: 2 },
  radioOuterSelected: { borderColor: colors.shell },
  radioInner: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.shell },
  radioTextBox: { flex: 1 },
  radioTitle: { ...textStyles.label },
  radioSubtitle: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 2 },
  workflowStepRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small + 4, marginBottom: spacing.small + 4 },
  workflowStepBadge: { width: 32, height: 32, borderRadius: 16, backgroundColor: colors.shell, alignItems: 'center', justifyContent: 'center' },
  workflowStepBadgeText: { color: colors.onPrimary, fontWeight: '700' },
  workflowStepTextBox: { flex: 1 },
  workflowStepTitle: { ...textStyles.label, fontWeight: '700' },
  workflowStepSubtitle: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 2 },
  bottomBar: { padding: spacing.medium, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border },
});
