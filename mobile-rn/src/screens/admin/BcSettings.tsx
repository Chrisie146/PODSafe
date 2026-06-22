import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useBcStore } from '../../stores/useBcStore';
import { BcConfig } from '../../models/bcConfig';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

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
          ? 'Connection successful! ✓\n\nYour Business Central credentials are valid and the API is accessible.'
          : 'Connection failed ✗\n\nPlease check:\n• Tenant ID is correct\n• Client ID is correct\n• Client Secret is correct\n• BC API URL is correct\n• Azure AD app has BC API permissions',
      );
    } catch (e) {
      setTestSuccess(false);
      setTestResult(`Error: ${(e as Error).message}`);
    }
  };

  if (isLoading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={[styles.headerCard, shadows.card]}>
        <View style={styles.headerRow}>
          <View style={styles.headerTextBox}>
            <Text style={textStyles.heading3}>Microsoft Dynamics 365 Business Central</Text>
            <Text style={styles.headerSubtitle}>Sync sales orders, customers, and delivery status in real-time</Text>
          </View>
          <Switch value={isEnabled} onValueChange={setIsEnabled} />
        </View>
      </View>

      <View style={[styles.section, shadows.card]}>
        <Text style={textStyles.heading3}>⚙ Connection Settings</Text>

        <FormField label="Azure AD Tenant ID *" placeholder="Your Azure Active Directory tenant ID" value={tenantId} onChangeText={setTenantId} />
        <FormField label="Client ID (Application ID) *" placeholder="Azure AD application client ID" value={clientId} onChangeText={setClientId} />

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>Client Secret</Text>
          <View style={styles.secretRow}>
            <TextInput
              style={[styles.input, styles.secretInput]}
              placeholder="Azure AD application client secret"
              secureTextEntry={obscureSecret}
              value={clientSecret}
              onChangeText={setClientSecret}
            />
            <Pressable style={styles.secretToggle} onPress={() => setObscureSecret((prev) => !prev)}>
              <Text>{obscureSecret ? '👁' : '🙈'}</Text>
            </Pressable>
          </View>
          <Text style={styles.helperText}>Note: Client secret is not stored. Enter only when testing connection.</Text>
        </View>

        <FormField label="Business Central Company ID *" placeholder="BC company GUID" value={bcCompanyId} onChangeText={setBcCompanyId} />
        <FormField
          label="BC API Base URL *"
          placeholder="https://api.businesscentral.dynamics.com/v2.0/{tenant-id}/{environment}"
          value={bcApiUrl}
          onChangeText={setBcApiUrl}
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
      </View>

      <View style={[styles.section, shadows.card]}>
        <Text style={textStyles.heading3}>🔄 Sync Settings</Text>

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
      </View>

      {testResult ? (
        <View style={[styles.testResultBox, testSuccess ? styles.testResultSuccess : styles.testResultFailure]}>
          <Text style={[styles.testResultText, { color: testSuccess ? colors.success : colors.error }]}>{testResult}</Text>
        </View>
      ) : null}

      <View style={styles.buttonRow}>
        <Pressable style={[styles.actionButton, styles.testButton]} disabled={isTesting || isSaving} onPress={handleTestConnection}>
          {isTesting ? <ActivityIndicator color={colors.white} size="small" /> : null}
          <Text style={textStyles.buttonText}>{isTesting ? 'Testing...' : '📡 Test Connection'}</Text>
        </Pressable>
        <Pressable style={[styles.actionButton, styles.saveButton]} disabled={isTesting || isSaving} onPress={handleSave}>
          {isSaving ? <ActivityIndicator color={colors.white} size="small" /> : null}
          <Text style={textStyles.buttonText}>{isSaving ? 'Saving...' : '💾 Save Configuration'}</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

function FormField({
  label,
  placeholder,
  value,
  onChangeText,
  helperText,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChangeText: (text: string) => void;
  helperText?: string;
}) {
  return (
    <View style={styles.fieldGroup}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput style={styles.input} placeholder={placeholder} value={value} onChangeText={onChangeText} />
      {helperText ? <Text style={styles.helperText}>{helperText}</Text> : null}
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
      <Switch value={value} onValueChange={onValueChange} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  headerCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.large },
  headerRow: { flexDirection: 'row', alignItems: 'center' },
  headerTextBox: { flex: 1, marginRight: spacing.small },
  headerSubtitle: { color: colors.textSecondary, marginTop: 4, fontSize: 13 },
  section: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.medium },
  fieldGroup: { marginTop: spacing.medium },
  fieldLabel: { fontWeight: '600', marginBottom: spacing.small, color: colors.textPrimary },
  input: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: spacing.small + 4,
    backgroundColor: colors.background,
  },
  helperText: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  secretRow: { flexDirection: 'row', alignItems: 'center' },
  secretInput: { flex: 1 },
  secretToggle: { paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: {
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: 6,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.divider,
  },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  switchTile: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.background,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: colors.divider,
    padding: spacing.small + 4,
    marginTop: spacing.small + 4,
  },
  switchTileTextBox: { flex: 1, marginRight: spacing.small },
  switchTileTitle: { fontWeight: '500', fontSize: 14 },
  switchTileSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  testResultBox: { borderRadius: radii.borderRadius, borderWidth: 1, padding: spacing.medium, marginBottom: spacing.medium },
  testResultSuccess: { backgroundColor: `${colors.success}14`, borderColor: colors.success },
  testResultFailure: { backgroundColor: `${colors.error}14`, borderColor: colors.error },
  testResultText: { fontWeight: '500' },
  buttonRow: { flexDirection: 'row', gap: spacing.medium },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    gap: spacing.small,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.medium,
  },
  testButton: { backgroundColor: colors.info },
  saveButton: { backgroundColor: colors.primary },
});
