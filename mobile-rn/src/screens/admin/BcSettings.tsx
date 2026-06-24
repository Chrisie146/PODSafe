import React, { useEffect, useState } from 'react';
import { Alert, Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useBcStore } from '../../stores/useBcStore';
import { BcConfig } from '../../models/bcConfig';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { Screen, Card, FormField, PrimaryButton, SecondaryButton, IconButton, LoadingState, AppIcon } from '../../components/ui';

/**
 * Ported from lib/screens/admin/bc_settings_screen.dart (verified against source on
 * 2026-06-22) — admin configuration screen for the Business Central integration.
 *
 * Deviations from the Flutter source:
 * - Environment and sync-interval "dropdowns" use chip selectors (house convention —
 *   no picker library installed, see MyClaims.tsx's STATUS_CHIPS).
 * - Bug fix: the Dart source's "Test Connection" flow builds a BCConfig missing
 *   isEnabled/syncIntervalMinutes/autoCreateDeliveries/autoAttachPODs (they silently
 *   fall back to the model's constructor defaults), then writes it with a plain `.set()`
 *   (no merge) — meaning every "Test Connection" tap quietly resets those four saved
 *   settings back to their defaults, regardless of what's actually saved or shown on
 *   screen. This port saves the full current form state via the same merge-write path
 *   `saveConfig()` already uses, so testing a connection can no longer corrupt saved
 *   settings.
 * - Client secret is never persisted to Firestore here either (matches the Dart
 *   source/BCConfig model — there's no clientSecret field on the model at all).
 *
 * UI/UX Refresh Phase 5: rebuilt on the shared primitives (Screen/Card/FormField/
 * PrimaryButton); emoji section/button glyphs replaced with SVG icons. Behaviour,
 * validation, and store calls unchanged.
 */
const DEFAULT_BC_API_URL = 'https://api.businesscentral.dynamics.com/v2.0';
const ENVIRONMENTS = ['production', 'sandbox'];
const SYNC_INTERVALS = [5, 10, 15, 30, 60];

export default function BcSettings() {
  const currentUser = useAuthStore((s) => s.currentUser);
  const config = useBcStore((s) => s.config);
  const isLoading = useBcStore((s) => s.isLoading);
  const isTesting = useBcStore((s) => s.isTesting);
  const loadConfig = useBcStore((s) => s.loadConfig);
  const saveConfig = useBcStore((s) => s.saveConfig);
  const testConnection = useBcStore((s) => s.testConnection);

  const [isEnabled, setIsEnabled] = useState(false);
  const [tenantId, setTenantId] = useState('');
  const [clientId, setClientId] = useState('');
  const [clientSecret, setClientSecret] = useState('');
  const [obscureSecret, setObscureSecret] = useState(true);
  const [bcCompanyId, setBcCompanyId] = useState('');
  const [bcApiUrl, setBcApiUrl] = useState(DEFAULT_BC_API_URL);
  const [environment, setEnvironment] = useState('production');
  const [syncIntervalMinutes, setSyncIntervalMinutes] = useState(15);
  const [autoCreateDeliveries, setAutoCreateDeliveries] = useState(false);
  const [autoAttachPODs, setAutoAttachPODs] = useState(true);

  const [isSaving, setIsSaving] = useState(false);
  const [testResult, setTestResult] = useState<string | null>(null);
  const [testSuccess, setTestSuccess] = useState<boolean | null>(null);

  useEffect(() => {
    if (currentUser) {
      loadConfig(currentUser.companyId);
    }
  }, [currentUser, loadConfig]);

  useEffect(() => {
    if (!config) return;
    setIsEnabled(config.isEnabled);
    setTenantId(config.tenantId ?? '');
    setBcCompanyId(config.bcCompanyId ?? '');
    setClientId(config.clientId ?? '');
    setBcApiUrl(config.bcApiUrl || DEFAULT_BC_API_URL);
    setEnvironment(config.environment || 'production');
    setSyncIntervalMinutes(config.syncIntervalMinutes);
    setAutoCreateDeliveries(config.autoCreateDeliveries);
    setAutoAttachPODs(config.autoAttachPODs);
  }, [config]);

  const buildConfigFromForm = (): BcConfig | null => {
    if (!currentUser) return null;
    return {
      companyId: currentUser.companyId,
      isEnabled,
      tenantId: tenantId.trim(),
      environment,
      bcCompanyId: bcCompanyId.trim(),
      clientId: clientId.trim(),
      bcApiUrl: bcApiUrl.trim(),
      syncIntervalMinutes,
      autoCreateDeliveries,
      autoAttachPODs,
    };
  };

  const validate = (): string | null => {
    if (tenantId.trim().length === 0) return 'Tenant ID is required';
    if (clientId.trim().length === 0) return 'Client ID is required';
    if (bcCompanyId.trim().length === 0) return 'Company ID is required';
    if (bcApiUrl.trim().length === 0) return 'API URL is required';
    if (!bcApiUrl.trim().startsWith('http')) return 'Please enter a valid URL';
    return null;
  };

  const handleSave = async () => {
    const validationError = validate();
    if (validationError) {
      Alert.alert('Missing Information', validationError);
      return;
    }

    const formConfig = buildConfigFromForm();
    if (!formConfig) return;

    setIsSaving(true);
    try {
      await saveConfig(formConfig);
      Alert.alert('Success', 'Configuration saved successfully');
    } catch (e) {
      Alert.alert('Error', `Error saving configuration: ${(e as Error).message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleTestConnection = async () => {
    const validationError = validate();
    if (validationError) {
      Alert.alert('Missing Information', validationError);
      return;
    }

    if (clientSecret.trim().length === 0) {
      Alert.alert('Missing Information', 'Client Secret is required to test connection');
      return;
    }

    const formConfig = buildConfigFromForm();
    if (!formConfig) return;

    setTestResult(null);
    setTestSuccess(null);

    try {
      // Save the full current form state first (Cloud Function reads it from Firestore) —
      // see the file-level comment for why this uses the merge-write save path.
      await saveConfig(formConfig);

      const success = await testConnection(clientSecret.trim());
      setTestSuccess(success);
      setTestResult(
        success
          ? 'Connection successful.\n\nYour Business Central credentials are valid and the API is accessible.'
          : 'Connection failed.\n\nPlease check:\n• Tenant ID is correct\n• Client ID is correct\n• Client Secret is correct\n• BC API URL is correct\n• Azure AD app has BC API permissions',
      );
    } catch (e) {
      setTestSuccess(false);
      setTestResult(`Error: ${(e as Error).message}`);
    }
  };

  if (isLoading) {
    return (
      <Screen>
        <LoadingState title="Loading configuration" />
      </Screen>
    );
  }

  return (
    <Screen scroll keyboardAvoiding contentContainerStyle={styles.content}>
      <Card padding="spacious" style={styles.headerCard}>
        <View style={styles.headerRow}>
          <View style={styles.headerTextBox}>
            <Text style={textStyles.heading3}>Microsoft Dynamics 365 Business Central</Text>
            <Text style={styles.headerSubtitle}>Sync sales orders, customers, and delivery status in real-time</Text>
          </View>
          <Switch
            value={isEnabled}
            onValueChange={setIsEnabled}
            trackColor={{ true: colors.active, false: colors.border }}
          />
        </View>
      </Card>

      <Card padding="spacious" style={styles.section}>
        <View style={styles.sectionHeader}>
          <AppIcon name="settings" size={20} color={colors.shell} />
          <Text style={textStyles.heading3}>Connection Settings</Text>
        </View>

        <FormField label="Azure AD Tenant ID *" placeholder="Your Azure Active Directory tenant ID" value={tenantId} onChangeText={setTenantId} autoCapitalize="none" />
        <FormField label="Client ID (Application ID) *" placeholder="Azure AD application client ID" value={clientId} onChangeText={setClientId} autoCapitalize="none" />

        <FormField
          label="Client Secret"
          placeholder="Azure AD application client secret"
          secureTextEntry={obscureSecret}
          value={clientSecret}
          onChangeText={setClientSecret}
          autoCapitalize="none"
          helperText="Client secret is not stored. Enter only when testing connection."
          rightAccessory={
            <IconButton
              icon="eye"
              accessibilityLabel={obscureSecret ? 'Show client secret' : 'Hide client secret'}
              onPress={() => setObscureSecret((prev) => !prev)}
              color={obscureSecret ? colors.contentSecondary : colors.active}
            />
          }
        />

        <FormField label="Business Central Company ID *" placeholder="BC company GUID" value={bcCompanyId} onChangeText={setBcCompanyId} autoCapitalize="none" />
        <FormField
          label="BC API Base URL *"
          placeholder="https://api.businesscentral.dynamics.com/v2.0/{tenant-id}/{environment}"
          value={bcApiUrl}
          onChangeText={setBcApiUrl}
          autoCapitalize="none"
          helperText="For trial: https://api.businesscentral.dynamics.com/v2.0/229fde23-1706-429c-8976-f70cf00cd16e/Sandbox"
        />

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>Environment</Text>
          <View style={styles.chipRow}>
            {ENVIRONMENTS.map((env) => (
              <Chip key={env} label={env} selected={environment === env} onPress={() => setEnvironment(env)} />
            ))}
          </View>
        </View>
      </Card>

      <Card padding="spacious" style={styles.section}>
        <View style={styles.sectionHeader}>
          <AppIcon name="activity" size={20} color={colors.shell} />
          <Text style={textStyles.heading3}>Sync Settings</Text>
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>Sync Interval</Text>
          <View style={styles.chipRow}>
            {SYNC_INTERVALS.map((interval) => (
              <Chip
                key={interval}
                label={`${interval} minutes`}
                selected={syncIntervalMinutes === interval}
                onPress={() => setSyncIntervalMinutes(interval)}
              />
            ))}
          </View>
        </View>

        <SwitchTile
          title="Auto-create Deliveries from Sales Orders"
          subtitle="Automatically create delivery tasks when new sales orders are detected"
          value={autoCreateDeliveries}
          onValueChange={setAutoCreateDeliveries}
        />
        <SwitchTile
          title="Auto-attach PODs to Invoices"
          subtitle="Automatically attach proof of delivery PDFs to BC invoices"
          value={autoAttachPODs}
          onValueChange={setAutoAttachPODs}
        />
      </Card>

      {testResult ? (
        <View style={[styles.testResultBox, testSuccess ? styles.testResultSuccess : styles.testResultFailure]}>
          <AppIcon name={testSuccess ? 'check' : 'alert'} size={20} color={testSuccess ? colors.verified : colors.critical} />
          <Text style={styles.testResultText}>{testResult}</Text>
        </View>
      ) : null}

      <View style={styles.buttonRow}>
        <SecondaryButton
          label={isTesting ? 'Testing...' : 'Test Connection'}
          icon="link"
          loading={isTesting}
          disabled={isTesting || isSaving}
          onPress={handleTestConnection}
          style={styles.actionButton}
        />
        <PrimaryButton
          label={isSaving ? 'Saving...' : 'Save Configuration'}
          icon="check"
          loading={isSaving}
          disabled={isTesting || isSaving}
          onPress={handleSave}
          style={styles.actionButton}
        />
      </View>
    </Screen>
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

function SwitchTile({
  title,
  subtitle,
  value,
  onValueChange,
}: {
  title: string;
  subtitle: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
}) {
  return (
    <View style={styles.switchTile}>
      <View style={styles.switchTileTextBox}>
        <Text style={styles.switchTileTitle}>{title}</Text>
        <Text style={styles.switchTileSubtitle}>{subtitle}</Text>
      </View>
      <Switch value={value} onValueChange={onValueChange} trackColor={{ true: colors.active, false: colors.border }} />
    </View>
  );
}

const styles = StyleSheet.create({
  content: { paddingVertical: spacing.medium, gap: spacing.medium },
  headerCard: {},
  headerRow: { flexDirection: 'row', alignItems: 'center' },
  headerTextBox: { flex: 1, marginRight: spacing.small },
  headerSubtitle: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: spacing.xs },
  section: { gap: spacing.small },
  sectionHeader: { alignItems: 'center', flexDirection: 'row', gap: spacing.small, marginBottom: spacing.xs },
  fieldGroup: { marginTop: spacing.small },
  fieldLabel: { ...textStyles.label, marginBottom: spacing.small },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: {
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: 6,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  chipSelected: { backgroundColor: colors.activeMuted, borderColor: colors.active },
  chipText: { ...textStyles.bodySmall, color: colors.contentSecondary },
  chipTextSelected: { color: colors.shell, fontWeight: '600' },
  switchTile: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surfaceMuted,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.small + 4,
    marginTop: spacing.small + 4,
  },
  switchTileTextBox: { flex: 1, marginRight: spacing.small },
  switchTileTitle: { ...textStyles.label },
  switchTileSubtitle: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: spacing.xs },
  testResultBox: {
    alignItems: 'flex-start',
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.small,
    padding: spacing.medium,
  },
  testResultSuccess: { backgroundColor: colors.verifiedMuted, borderColor: colors.verified },
  testResultFailure: { backgroundColor: colors.criticalMuted, borderColor: colors.critical },
  testResultText: { ...textStyles.bodyMedium, flex: 1 },
  buttonRow: { flexDirection: 'row', gap: spacing.medium },
  actionButton: { flex: 1 },
});
