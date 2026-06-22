import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { ClaimType, ALL_CLAIM_TYPES, claimTypeDisplayText } from '../../models/claim';
import { ClaimWorkflowPreset, ALL_CLAIM_WORKFLOW_PRESETS, claimWorkflowPresetDisplayName, defaultWorkflowFor } from '../../models/companyClaimSettings';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/claim_settings_screen.dart
 * (`ClaimSettingsMobile`, verified against source on 2026-06-22) — admin configuration
 * screen for company-wide claim policy (claim types, approval workflow, evidence
 * requirements, automation rules, filing/notification features).
 *
 * This is Group A — a responsive-split screen (`ClaimSettingsScreen` switches to
 * `ClaimSettingsDesktop` above 900px in the Dart source). Per the Phase 3 scope, only the
 * mobile path is ported this pass; the >900px desktop branch lands in Phase 4 as a
 * `useWindowDimensions()` check wrapping this component, same as every other Group A
 * screen.
 *
 * Deviations from the Flutter source:
 * - The 6-tab `TabBar`/`TabBarView` becomes a custom horizontal Pressable tab strip +
 *   conditional content (house convention — no tab-bar library installed).
 * - `RadioListTile` (workflow preset) becomes a custom radio row (Pressable + glyph),
 *   `FilterChip` (claim types / auto-approve types) becomes the existing Chip pattern,
 *   `SwitchListTile` becomes a `SwitchRow` helper (same shape as BcSettings.tsx's
 *   SwitchTile).
 * - Settings are loaded once into local form state on first successful fetch (mirroring
 *   the Dart source's initState-only `_loadSettings()` — it never re-syncs from a live
 *   stream while the form is open, so in-progress edits aren't clobbered by unrelated
 *   store updates).
 * - Added `claimRepository.updateCompanySettings()` / `useClaimStore.updateSettings()`
 *   this pass — the admin settings-write path didn't exist yet (only the driver-facing
 *   read path, `getCompanySettings`, had been ported).
 */
const TABS = ['General', 'Claim Types', 'Workflow', 'Requirements', 'Automation', 'Features'] as const;
type TabName = (typeof TABS)[number];

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

export default function ClaimSettings() {
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
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  const previewNumber = (parseInt(claimIdStartNumber, 10) || 1).toString().padStart(4, '0');

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>Claim Settings</Text>
        <Pressable style={styles.saveButton} disabled={isSaving} onPress={handleSave}>
          {isSaving ? <ActivityIndicator color={colors.white} size="small" /> : <Text style={textStyles.buttonText}>💾 Save</Text>}
        </Pressable>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabStrip} contentContainerStyle={styles.tabStripContent}>
        {TABS.map((tab) => (
          <Pressable key={tab} style={[styles.tabButton, activeTab === tab && styles.tabButtonActive]} onPress={() => setActiveTab(tab)}>
            <Text style={[styles.tabButtonText, activeTab === tab && styles.tabButtonTextActive]}>{tab}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        {activeTab === 'General' ? (
          <>
            <SectionHeader title="Claim ID Configuration" subtitle="Customize how claim IDs are generated" />
            <View style={[styles.card, shadows.card]}>
              <FieldInput
                label="Claim ID Prefix"
                placeholder="CLM"
                helperText="Prefix for claim IDs (e.g., CLM, CLAIM, ISS)"
                value={claimIdPrefix}
                onChangeText={(v) => setClaimIdPrefix(v.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5))}
              />
              <FieldInput
                label="Starting Number"
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
            </View>

            <SectionHeader title="Time Limits" subtitle="Configure deadlines and SLAs" />
            <View style={[styles.card, shadows.card]}>
              <FieldInput label="Default SLA (hours)" placeholder="24" suffix="hours" keyboardType="numeric" value={slaHours} onChangeText={(v) => setSlaHours(v.replace(/\D/g, ''))} />
              <FieldInput
                label="Filing Deadline (days)"
                placeholder="Leave empty for no deadline"
                helperText="Max days after delivery to file claim (optional)"
                suffix="days"
                keyboardType="numeric"
                value={filingDeadlineDays}
                onChangeText={(v) => setFilingDeadlineDays(v.replace(/\D/g, ''))}
              />
            </View>
          </>
        ) : null}

        {activeTab === 'Claim Types' ? (
          <>
            <SectionHeader title="Enabled Claim Types" subtitle="Select which claim types drivers can submit" />
            <View style={[styles.card, shadows.card]}>
              <Text style={styles.countText}>
                Selected: {selectedClaimTypes.size} of {ALL_CLAIM_TYPES.length}
              </Text>
              <View style={styles.chipWrap}>
                {ALL_CLAIM_TYPES.map((type) => (
                  <Chip key={type} label={claimTypeDisplayText(type)} selected={selectedClaimTypes.has(type)} onPress={() => toggleClaimType(type)} />
                ))}
              </View>
              <View style={styles.buttonRow}>
                <Pressable style={styles.textButton} onPress={() => setSelectedClaimTypes(new Set(ALL_CLAIM_TYPES))}>
                  <Text style={styles.textButtonLabel}>☑ Select All</Text>
                </Pressable>
                <Pressable style={styles.textButton} onPress={() => setSelectedClaimTypes(new Set())}>
                  <Text style={styles.textButtonLabel}>☐ Clear All</Text>
                </Pressable>
              </View>
            </View>
            <View style={styles.warningBanner}>
              <Text style={styles.warningBannerText}>⚠ Drivers can only file claims for enabled types. At least one type must be selected.</Text>
            </View>
          </>
        ) : null}

        {activeTab === 'Workflow' ? (
          <>
            <SectionHeader title="Approval Workflow" subtitle="Configure how claims are reviewed and approved" />
            <View style={[styles.card, shadows.card]}>
              <Text style={styles.cardTitle}>Workflow Preset</Text>
              {ALL_CLAIM_WORKFLOW_PRESETS.map((preset) => (
                <RadioRow
                  key={preset}
                  title={claimWorkflowPresetDisplayName(preset)}
                  subtitle={workflowPresetDescription(preset)}
                  selected={workflowPreset === preset}
                  onPress={() => setWorkflowPreset(preset)}
                />
              ))}
            </View>

            {workflowPreset !== 'custom' ? (
              <View style={[styles.card, shadows.card]}>
                <Text style={styles.cardTitle}>ℹ Workflow Levels</Text>
                {defaultWorkflowFor(workflowPreset).map((role, index) => (
                  <View key={role.role} style={styles.workflowStepRow}>
                    <View style={styles.workflowStepBadge}>
                      <Text style={styles.workflowStepBadgeText}>{index + 1}</Text>
                    </View>
                    <View style={styles.workflowStepTextBox}>
                      <Text style={styles.workflowStepTitle}>{role.displayName}</Text>
                      <Text style={styles.workflowStepSubtitle}>SLA: {role.slaHours} hours</Text>
                    </View>
                    <Text style={styles.workflowStepCheck}>✓</Text>
                  </View>
                ))}
              </View>
            ) : (
              <View style={[styles.card, shadows.card, styles.emptyStateCard]}>
                <Text style={styles.emptyStateIcon}>🛠</Text>
                <Text style={styles.emptyStateTitle}>Custom Workflow Builder</Text>
                <Text style={styles.emptyStateSubtitle}>Custom workflow configuration will be available in a future update</Text>
              </View>
            )}
          </>
        ) : null}

        {activeTab === 'Requirements' ? (
          <>
            <SectionHeader title="Photo Requirements" subtitle="Configure photo evidence requirements" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Photos Mandatory" subtitle="Require at least one photo" value={photosMandatory} onValueChange={setPhotosMandatory} />
              <SwitchRow title="Require Photo for Immediate Claims" subtitle="Filed at delivery site" value={requirePhotoImmediate} onValueChange={setRequirePhotoImmediate} />
              <SwitchRow title="Require Photo for Delayed Claims" subtitle="Filed after delivery" value={requirePhotoDelayed} onValueChange={setRequirePhotoDelayed} />
              <View style={styles.divider} />
              <FieldInput label="Minimum Photos Required" placeholder="1" suffix="photos" keyboardType="numeric" value={minPhotosRequired} onChangeText={(v) => setMinPhotosRequired(v.replace(/\D/g, ''))} />
              <FieldInput label="Maximum Photos Allowed" placeholder="10" suffix="photos" keyboardType="numeric" value={maxPhotosAllowed} onChangeText={(v) => setMaxPhotosAllowed(v.replace(/\D/g, ''))} />
            </View>

            <SectionHeader title="Signature Requirements" subtitle="Configure signature requirements" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Require Customer Signature" subtitle="Customer must sign claim form" value={requireCustomerSignature} onValueChange={setRequireCustomerSignature} />
              <SwitchRow title="Require Driver Signature" subtitle="Driver must sign claim form" value={requireDriverSignature} onValueChange={setRequireDriverSignature} />
            </View>
          </>
        ) : null}

        {activeTab === 'Automation' ? (
          <>
            <SectionHeader title="Auto-Approval Rules" subtitle="Automatically approve claims meeting criteria" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Enable Auto-Approval" subtitle="Automatically approve eligible claims" value={enableAutoApproval} onValueChange={setEnableAutoApproval} />
              {enableAutoApproval ? (
                <>
                  <View style={styles.divider} />
                  <FieldInput
                    label="Auto-Approve Under Amount"
                    placeholder="Leave empty for no limit"
                    helperText="Claims below this amount will be auto-approved"
                    prefix="R"
                    keyboardType="decimal-pad"
                    value={autoApproveAmount}
                    onChangeText={setAutoApproveAmount}
                  />
                  <Text style={styles.cardTitle}>Auto-Approve Claim Types:</Text>
                  <View style={styles.chipWrap}>
                    {Array.from(selectedClaimTypes).map((type) => (
                      <Chip key={type} label={claimTypeDisplayText(type)} selected={autoApproveTypes.has(type)} onPress={() => toggleAutoApproveType(type)} />
                    ))}
                  </View>
                </>
              ) : null}
            </View>

            <SectionHeader title="Fraud Detection" subtitle="Detect potentially fraudulent claims" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Enable Fraud Detection" subtitle="Flag suspicious claim patterns" value={enableFraudDetection} onValueChange={setEnableFraudDetection} />
              {enableFraudDetection ? (
                <>
                  <View style={styles.divider} />
                  <FieldInput label="High-Value Threshold" placeholder="e.g., 1000" helperText="Flag claims above this amount" prefix="R" keyboardType="decimal-pad" value={fraudAmount} onChangeText={setFraudAmount} />
                  <FieldInput
                    label="Frequency Threshold"
                    placeholder="e.g., 5"
                    helperText="Flag if driver files X claims per month"
                    suffix="claims/month"
                    keyboardType="numeric"
                    value={fraudFrequency}
                    onChangeText={(v) => setFraudFrequency(v.replace(/\D/g, ''))}
                  />
                </>
              ) : null}
            </View>

            <SectionHeader title="Pattern Detection" subtitle="Identify recurring claim patterns" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Enable Pattern Detection" subtitle="Detect recurring issues" value={enablePatternDetection} onValueChange={setEnablePatternDetection} />
              {enablePatternDetection ? (
                <>
                  <View style={styles.divider} />
                  <FieldInput
                    label="Recurring Claim Threshold"
                    placeholder="3"
                    helperText="Same issue X times = pattern (notify management)"
                    suffix="occurrences"
                    keyboardType="numeric"
                    value={recurringThreshold}
                    onChangeText={(v) => setRecurringThreshold(v.replace(/\D/g, ''))}
                  />
                </>
              ) : null}
            </View>
          </>
        ) : null}

        {activeTab === 'Features' ? (
          <>
            <SectionHeader title="Filing Permissions" subtitle="Control who can file claims" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Allow Driver Filing" subtitle="Drivers can file claims via mobile app" value={allowDriverFiling} onValueChange={setAllowDriverFiling} />
              <SwitchRow title="Allow Admin Filing" subtitle="Admins can file claims on behalf of drivers" value={allowAdminFiling} onValueChange={setAllowAdminFiling} />
              <SwitchRow title="Customer Portal" subtitle="Customers can view/file claims (coming soon)" value={allowCustomerPortal} onValueChange={() => {}} disabled />
            </View>

            <SectionHeader title="Communication Features" subtitle="Enable collaboration features" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Enable Comments" subtitle="Users can add comments to claims" value={enableComments} onValueChange={setEnableComments} />
              <SwitchRow title="Enable Internal Notes" subtitle="Admin-only internal notes" value={enableInternalNotes} onValueChange={setEnableInternalNotes} />
            </View>

            <SectionHeader title="Notifications" subtitle="Configure notification channels" />
            <View style={[styles.card, shadows.card]}>
              <SwitchRow title="Push Notifications" subtitle="In-app notifications" value={enablePushNotifications} onValueChange={setEnablePushNotifications} />
              <SwitchRow title="Email Notifications" subtitle="Send email updates" value={enableEmailNotifications} onValueChange={setEnableEmailNotifications} />
              <SwitchRow title="SMS Notifications" subtitle="Send SMS alerts (additional charges apply)" value={enableSMSNotifications} onValueChange={setEnableSMSNotifications} />
            </View>
          </>
        ) : null}
      </ScrollView>
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
        <TextInput style={styles.fieldInput} placeholder={placeholder} keyboardType={keyboardType} value={value} onChangeText={onChangeText} />
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
      <Switch value={value} onValueChange={onValueChange} disabled={disabled} />
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

function RadioRow({ title, subtitle, selected, onPress }: { title: string; subtitle: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={styles.radioRow} onPress={onPress}>
      <Text style={styles.radioGlyph}>{selected ? '◉' : '○'}</Text>
      <View style={styles.radioTextBox}>
        <Text style={styles.radioTitle}>{title}</Text>
        <Text style={styles.radioSubtitle}>{subtitle}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.card,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.medium,
    borderBottomWidth: 1,
    borderBottomColor: colors.divider,
  },
  saveButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 4,
    minWidth: 90,
  },
  tabStrip: { backgroundColor: colors.card, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tabStripContent: { paddingHorizontal: spacing.medium, gap: spacing.small },
  tabButton: { paddingHorizontal: spacing.medium, paddingVertical: spacing.medium, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabButtonActive: { borderBottomColor: colors.primary },
  tabButtonText: { color: colors.textSecondary, fontWeight: '600' },
  tabButtonTextActive: { color: colors.primary },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  sectionHeader: { marginBottom: spacing.small + 4 },
  sectionHeaderTitle: { fontSize: 18, fontWeight: 'bold', color: colors.textPrimary },
  sectionHeaderSubtitle: { fontSize: 13, color: colors.textSecondary, marginTop: 2 },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  cardTitle: { fontWeight: 'bold', fontSize: 14, marginTop: spacing.small, marginBottom: spacing.small },
  countText: { color: colors.textSecondary, fontSize: 13, marginBottom: spacing.small + 4 },
  fieldGroup: { marginBottom: spacing.medium },
  fieldLabel: { fontWeight: '600', fontSize: 13, color: colors.textPrimary, marginBottom: spacing.small },
  fieldInputRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  fieldInput: { flex: 1, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  fieldAffix: { color: colors.textSecondary, fontSize: 13 },
  fieldHelperText: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  previewBox: { backgroundColor: `${colors.info}1A`, borderRadius: radii.borderRadius, padding: spacing.small + 4, marginTop: spacing.small },
  previewText: { color: colors.info, fontWeight: 'bold' },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  buttonRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.medium },
  textButton: { paddingVertical: spacing.small },
  textButtonLabel: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  warningBanner: { backgroundColor: `${colors.warning}1A`, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: `${colors.warning}66`, padding: spacing.medium },
  warningBannerText: { color: colors.warning, fontSize: 13 },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  switchRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4 },
  switchRowTextBox: { flex: 1, marginRight: spacing.small },
  switchRowTitle: { fontWeight: '500', fontSize: 14 },
  switchRowSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  radioRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: spacing.small + 4 },
  radioGlyph: { fontSize: 18, color: colors.primary, marginRight: spacing.small + 4, marginTop: 2 },
  radioTextBox: { flex: 1 },
  radioTitle: { fontWeight: '600', fontSize: 14 },
  radioSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  workflowStepRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small + 4 },
  workflowStepBadge: { width: 32, height: 32, borderRadius: 16, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  workflowStepBadgeText: { color: colors.white, fontWeight: 'bold' },
  workflowStepTextBox: { flex: 1 },
  workflowStepTitle: { fontWeight: 'bold' },
  workflowStepSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  workflowStepCheck: { color: colors.success, fontSize: 18 },
  emptyStateCard: { alignItems: 'center', paddingVertical: spacing.large },
  emptyStateIcon: { fontSize: 40, opacity: 0.4 },
  emptyStateTitle: { fontWeight: 'bold', fontSize: 16, color: colors.textSecondary, marginTop: spacing.small + 4 },
  emptyStateSubtitle: { color: colors.textSecondary, textAlign: 'center', marginTop: spacing.small },
});
