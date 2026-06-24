import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Image, Modal, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { useThemeStore } from '../../stores/useThemeStore';
import { pickLogoImage, uploadAppLogo, uploadCompanyLogo } from '../../repositories/fileUploadService';
import { backupAllData } from '../../repositories/comprehensiveBackupService';
import { getOnboardingDebugData, resetOnboarding } from '../../repositories/onboardingService';
import { ALL_USER_ROLES, UserRole, userRoleDisplayName } from '../../models/user';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/admin_settings_screen.dart (verified against source on
 * 2026-06-23) — the largest remaining Group B screen (2328 lines). Depends on this
 * session's FileUploadService/ComprehensiveBackupService/OnboardingService ports plus a
 * new useThemeStore (replacing ThemeProvider, which turned out to genuinely not exist in
 * RN yet despite the vault's "all 8 stores" claim — re-verified against `src/stores/`).
 *
 * Deviations from the Flutter source:
 * - "Register New User" used Firebase Auth's client-side createUserWithEmailAndPassword
 *   directly, which signs the *calling admin* out of their own session — the exact bug
 *   AuthRepository's class comment already documents and that create_driver_screen.dart
 *   was historically blocked on. Fixed here to go through the same Phase 5 `createUser`
 *   Cloud Function via useUserManagementStore.createUser(), like CreateDriver.tsx.
 * - Its role dropdown offered 'user'/'supervisor', neither of which is a real role
 *   anywhere else in the app (UserRole/PermissionService only know admin/manager/
 *   logistics/accountant/filing_clerk/driver) — the createUser callable would reject
 *   either with invalid-argument. Fixed to use the real ALL_USER_ROLES list.
 * - Notification Settings and Security Settings are ported faithfully as pure local
 *   state with zero Firestore persistence, exactly matching the Dart source: `_saveSettings()`
 *   there only ever calls `_saveDriverSettings`/`_saveCompanyInformation`/
 *   `_saveBrandingSettings` — these two sections' toggles/sliders silently reset on every
 *   reload today. Not fixed (a real product decision about what these should persist to,
 *   beyond this port's scope) — flagged in the vault risk register instead.
 * - Role Permissions matrix is also ported faithfully as write-only: `grep`-confirmed
 *   zero readers of `companies/{companyId}/settings/role_permissions` anywhere in
 *   `lib/`/`functions/src/` — real enforcement is PermissionService's static role map.
 *   The matrix never loads previously-saved values either (same as Dart); both are
 *   pre-existing gaps, not introduced here.
 * - "Coming soon"/"under development" placeholder items (Delivery Time Windows, Route
 *   Optimization, Language & Localization, Timezone Settings, the System-Settings
 *   "Data Backup" stub distinct from the real backup below, Claim Workflows, Required
 *   Documentation, Claim Processing, Access Control, Third-party APIs, Webhooks) are
 *   ported as simple Alert.alert()s, same as the Dart source's SnackBars/dialogs.
 * - Modal dialogs replace Dart's AlertDialogs; Switch (RN built-in) replaces
 *   SwitchListTile; Slider becomes a +/- stepper row (no slider library installed).
 */
interface AdminSettingsProps {
  navigation: { goBack: () => void; navigate: (screen: string) => void };
}

const ROLE_PERMISSIONS_DEFAULT: Record<UserRole, Set<string>> = {
  admin: new Set([
    'view_deliveries', 'create_deliveries', 'edit_deliveries', 'delete_deliveries',
    'view_drivers', 'manage_drivers', 'view_analytics', 'manage_settings',
    'view_chats', 'send_messages', 'manage_users', 'view_reports',
  ]),
  manager: new Set(['view_deliveries', 'create_deliveries', 'edit_deliveries', 'view_drivers', 'view_analytics', 'view_chats', 'send_messages', 'view_reports']),
  logistics: new Set(['view_deliveries', 'create_deliveries', 'edit_deliveries', 'view_drivers', 'view_analytics', 'view_chats', 'send_messages']),
  accountant: new Set(['view_deliveries', 'view_analytics', 'view_reports']),
  filing_clerk: new Set(['view_deliveries', 'edit_deliveries', 'view_reports']),
  driver: new Set(['view_deliveries', 'view_chats', 'send_messages']),
};

const AVAILABLE_PERMISSIONS = [
  'view_deliveries', 'create_deliveries', 'edit_deliveries', 'delete_deliveries',
  'view_drivers', 'manage_drivers', 'view_analytics', 'manage_settings',
  'view_chats', 'send_messages', 'manage_users', 'view_reports',
];

const PERMISSION_ROLE_COLUMNS: UserRole[] = ['admin', 'manager', 'logistics', 'accountant', 'filing_clerk', 'driver'];

function formatPermissionName(permission: string): string {
  return permission.split('_').map((word) => word[0].toUpperCase() + word.slice(1)).join(' ');
}

function showComingSoon(feature: string) {
  Alert.alert(feature, `${feature} settings coming soon!`);
}

export default function AdminSettings({ navigation }: AdminSettingsProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const createUser = useUserManagementStore((s) => s.createUser);

  const appName = useThemeStore((s) => s.appName);
  const appLogoUrl = useThemeStore((s) => s.appLogoUrl);
  const primaryColor = useThemeStore((s) => s.primaryColor);
  const accentColor = useThemeStore((s) => s.accentColor);
  const warningColor = useThemeStore((s) => s.warningColor);
  const successColor = useThemeStore((s) => s.successColor);
  const loadBrandingSettings = useThemeStore((s) => s.loadBrandingSettings);
  const saveBrandingSettings = useThemeStore((s) => s.saveBrandingSettings);
  const setAppName = useThemeStore((s) => s.setAppName);
  const setAppLogoUrl = useThemeStore((s) => s.setAppLogoUrl);
  const setPrimaryColor = useThemeStore((s) => s.setPrimaryColor);
  const setAccentColor = useThemeStore((s) => s.setAccentColor);
  const setWarningColor = useThemeStore((s) => s.setWarningColor);
  const setSuccessColor = useThemeStore((s) => s.setSuccessColor);

  const [isLoadingDriverSettings, setIsLoadingDriverSettings] = useState(true);
  const [isLoadingCompanyInfo, setIsLoadingCompanyInfo] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  // Driver settings
  const [gpsTrackingEnabled, setGpsTrackingEnabled] = useState(true);
  const [gpsUpdateFrequency, setGpsUpdateFrequency] = useState('30');
  const [gpsPrivacyMode, setGpsPrivacyMode] = useState(false);
  const [requireDeliveryPhotos, setRequireDeliveryPhotos] = useState(true);
  const [requireSignaturePhotos, setRequireSignaturePhotos] = useState(true);
  const [requireLocationPhotos, setRequireLocationPhotos] = useState(false);
  const [offlineModeEnabled, setOfflineModeEnabled] = useState(true);
  const [syncFrequency, setSyncFrequency] = useState('15');
  const [autoSyncOnNetwork, setAutoSyncOnNetwork] = useState(true);

  // Company information
  const [companyName, setCompanyName] = useState('');
  const [companyEmail, setCompanyEmail] = useState('');
  const [companyPhone, setCompanyPhone] = useState('');
  const [companyAddress, setCompanyAddress] = useState('');
  const [companyWebsite, setCompanyWebsite] = useState('');
  const [companyRegistration, setCompanyRegistration] = useState('');
  const [taxNumber, setTaxNumber] = useState('');
  const [companyDescription, setCompanyDescription] = useState('');
  const [companyLogoUrl, setCompanyLogoUrl] = useState<string | undefined>(undefined);

  // Notification settings (decorative — see deviation note)
  const [emailNotificationsEnabled, setEmailNotificationsEnabled] = useState(true);
  const [smsNotificationsEnabled, setSmsNotificationsEnabled] = useState(true);
  const [pushNotificationsEnabled, setPushNotificationsEnabled] = useState(true);
  const [notifyOnDeliveryComplete, setNotifyOnDeliveryComplete] = useState(true);
  const [notifyOnDeliveryFailed, setNotifyOnDeliveryFailed] = useState(true);
  const [notifyOnNewClaim, setNotifyOnNewClaim] = useState(true);
  const [notifyAdminsOnIssues, setNotifyAdminsOnIssues] = useState(true);

  // Security settings (decorative — see deviation note)
  const [passwordMinLength, setPasswordMinLength] = useState(8);
  const [requireSpecialCharacters, setRequireSpecialCharacters] = useState(true);
  const [sessionTimeoutMinutes, setSessionTimeoutMinutes] = useState(30);
  const [enableTwoFactorAuth, setEnableTwoFactorAuth] = useState(false);
  const [logAllUserActions, setLogAllUserActions] = useState(true);

  // Role permissions (write-only — see deviation note)
  const [rolePermissions, setRolePermissions] = useState(ROLE_PERMISSIONS_DEFAULT);

  // Modals
  const [showCompanyInfo, setShowCompanyInfo] = useState(false);
  const [showBrandingTheme, setShowBrandingTheme] = useState(false);
  const [showRegisterUser, setShowRegisterUser] = useState(false);
  const [showRolePermissions, setShowRolePermissions] = useState(false);
  const [showApiSettings, setShowApiSettings] = useState(false);
  const [showWebhookSettings, setShowWebhookSettings] = useState(false);

  // Register-user form
  const [regEmail, setRegEmail] = useState('');
  const [regPassword, setRegPassword] = useState('');
  const [regDisplayName, setRegDisplayName] = useState('');
  const [regRole, setRegRole] = useState<UserRole>('driver');
  const [isRegisteringUser, setIsRegisteringUser] = useState(false);

  useEffect(() => {
    if (!currentUser) return;
    loadDriverSettings(currentUser.companyId);
    loadCompanyInformation(currentUser.companyId);
    loadBrandingSettings(currentUser.companyId);
  }, [currentUser, loadBrandingSettings]);

  const loadDriverSettings = async (companyId: string) => {
    setIsLoadingDriverSettings(true);
    try {
      const doc = await firestore().collection('companies').doc(companyId).collection('settings').doc('driver').get();
      if (doc.exists()) {
        const data = doc.data() ?? {};
        setGpsTrackingEnabled(data.gpsTrackingEnabled ?? true);
        setGpsUpdateFrequency(data.gpsUpdateFrequency ?? '30');
        setGpsPrivacyMode(data.gpsPrivacyMode ?? false);
        setRequireDeliveryPhotos(data.requireDeliveryPhotos ?? true);
        setRequireSignaturePhotos(data.requireSignaturePhotos ?? true);
        setRequireLocationPhotos(data.requireLocationPhotos ?? false);
        setOfflineModeEnabled(data.offlineModeEnabled ?? true);
        setSyncFrequency(data.syncFrequency ?? '15');
        setAutoSyncOnNetwork(data.autoSyncOnNetwork ?? true);
      }
    } catch {
      // Mirrors Dart: keep default values on error.
    } finally {
      setIsLoadingDriverSettings(false);
    }
  };

  const loadCompanyInformation = async (companyId: string) => {
    setIsLoadingCompanyInfo(true);
    try {
      const doc = await firestore().collection('companies').doc(companyId).get();
      if (doc.exists()) {
        const data = doc.data() ?? {};
        setCompanyName(data.name ?? '');
        setCompanyEmail(data.email ?? '');
        setCompanyPhone(data.phone ?? '');
        setCompanyAddress(data.address ?? '');
        setCompanyWebsite(data.website ?? '');
        setCompanyRegistration(data.registrationNumber ?? '');
        setTaxNumber(data.taxNumber ?? '');
        setCompanyDescription(data.description ?? '');
        setCompanyLogoUrl(data.logoUrl ?? undefined);
      }
    } catch {
      // Mirrors Dart: keep empty/default values on error.
    } finally {
      setIsLoadingCompanyInfo(false);
    }
  };

  const saveDriverSettings = async (companyId: string, userId: string) => {
    await firestore().collection('companies').doc(companyId).collection('settings').doc('driver').set({
      gpsTrackingEnabled,
      gpsUpdateFrequency,
      gpsPrivacyMode,
      requireDeliveryPhotos,
      requireSignaturePhotos,
      requireLocationPhotos,
      offlineModeEnabled,
      syncFrequency,
      autoSyncOnNetwork,
      updatedAt: firestore.FieldValue.serverTimestamp(),
      updatedBy: userId,
    });
  };

  const saveCompanyInformation = async (companyId: string, userId: string) => {
    await firestore().collection('companies').doc(companyId).update({
      name: companyName,
      email: companyEmail,
      phone: companyPhone,
      address: companyAddress,
      website: companyWebsite,
      registrationNumber: companyRegistration,
      taxNumber,
      description: companyDescription,
      logoUrl: companyLogoUrl ?? null,
      updatedAt: firestore.FieldValue.serverTimestamp(),
      updatedBy: userId,
    });
  };

  /** Mirrors the top app-bar "Save" button's `_saveSettings()` — saves everything at once. */
  const handleSaveAll = async () => {
    if (!currentUser) return;
    setIsSaving(true);
    try {
      await Promise.all([
        saveDriverSettings(currentUser.companyId, currentUser.id),
        saveCompanyInformation(currentUser.companyId, currentUser.id),
        saveBrandingSettings(currentUser.companyId, currentUser.id),
      ]);
      Alert.alert('Success', 'All settings saved successfully!');
      setIsSaving(false);
      navigation.goBack();
    } catch (e) {
      setIsSaving(false);
      Alert.alert('Error', `Failed to save settings: ${(e as Error).message}`);
    }
  };

  const handleSaveCompanyInfoOnly = async () => {
    if (!currentUser) return;
    setIsSaving(true);
    try {
      await saveCompanyInformation(currentUser.companyId, currentUser.id);
      setIsSaving(false);
      setShowCompanyInfo(false);
      Alert.alert('Success', 'Company information updated successfully');
    } catch (e) {
      setIsSaving(false);
      Alert.alert('Error', `Failed to update company information: ${(e as Error).message}`);
    }
  };

  /** Mirrors the Branding & Theme dialog's own "Save" button, which calls the same full `_saveSettings()`. */
  const handleSaveBrandingAndClose = async () => {
    await handleSaveAll();
    setShowBrandingTheme(false);
  };

  const handleUploadCompanyLogo = async () => {
    if (!currentUser) return;
    const fileUri = await pickLogoImage();
    if (!fileUri) return;
    const logoUrl = await uploadCompanyLogo(currentUser.companyId, fileUri);
    if (logoUrl) {
      setCompanyLogoUrl(logoUrl);
      Alert.alert('Success', 'Logo uploaded successfully');
    } else {
      Alert.alert('Error', 'Failed to upload logo');
    }
  };

  const handleUploadAppLogo = async () => {
    if (!currentUser) return;
    const fileUri = await pickLogoImage();
    if (!fileUri) return;
    const logoUrl = await uploadAppLogo(currentUser.companyId, fileUri);
    if (logoUrl) {
      setAppLogoUrl(logoUrl);
      Alert.alert('Success', 'Logo uploaded successfully! Tap Save to keep changes.');
    } else {
      Alert.alert('Error', 'Failed to upload logo');
    }
  };

  const handleRegisterUser = async () => {
    if (!currentUser) return;
    if (!regEmail.trim() || !regPassword.trim() || !regDisplayName.trim()) {
      Alert.alert('Notice', 'Please fill in all fields');
      return;
    }

    setIsRegisteringUser(true);
    try {
      const result = await createUser({
        email: regEmail.trim(),
        password: regPassword.trim(),
        fullName: regDisplayName.trim(),
        companyId: currentUser.companyId,
        role: regRole,
      });
      setRegEmail('');
      setRegPassword('');
      setRegDisplayName('');
      setRegRole('driver');
      setShowRegisterUser(false);
      Alert.alert('Success', `User registered successfully: ${result.email}`);
    } catch (e) {
      Alert.alert('Error', `Failed to register user: ${(e as Error).message}`);
    } finally {
      setIsRegisteringUser(false);
    }
  };

  const handleSaveRolePermissions = async () => {
    if (!currentUser) return;
    try {
      const permissions: Record<string, string[]> = {};
      PERMISSION_ROLE_COLUMNS.forEach((role) => {
        permissions[role] = Array.from(rolePermissions[role]);
      });
      await firestore().collection('companies').doc(currentUser.companyId).collection('settings').doc('role_permissions').set({
        permissions,
        updatedAt: firestore.FieldValue.serverTimestamp(),
        updatedBy: currentUser.id,
      });
      setShowRolePermissions(false);
      Alert.alert('Success', 'Role permissions updated successfully');
    } catch (e) {
      Alert.alert('Error', `Failed to save role permissions: ${(e as Error).message}`);
    }
  };

  const togglePermission = (role: UserRole, permission: string, granted: boolean) => {
    setRolePermissions((prev) => {
      const next = { ...prev, [role]: new Set(prev[role]) };
      if (granted) next[role].add(permission);
      else next[role].delete(permission);
      return next;
    });
  };

  const handleBackup = () => {
    if (!currentUser) return;
    Alert.alert('Backup All Data', 'This will create a full backup of the company data and share it. Continue?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Continue',
        onPress: () => runBackup(currentUser.companyId),
      },
    ]);
  };

  const [backupMessage, setBackupMessage] = useState<string | null>(null);
  const runBackup = async (companyId: string) => {
    setBackupMessage('Initializing backup...');
    try {
      await backupAllData(companyId, setBackupMessage);
      setBackupMessage(null);
      Alert.alert('Backup Complete', 'Backup completed successfully!');
    } catch (e) {
      setBackupMessage(null);
      Alert.alert('Error', (e as Error).message);
    }
  };

  const handleResetOnboarding = async () => {
    await resetOnboarding();
    Alert.alert('Done', 'Onboarding reset! Restart the app to see onboarding again.');
  };

  const handleShowOnboardingDebug = async () => {
    const debugData = await getOnboardingDebugData();
    Alert.alert('Onboarding Debug Info', Object.entries(debugData).map(([key, value]) => `${key}: ${value}`).join('\n'));
  };

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text>Please log in</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={[textStyles.heading2, { color: colors.onPrimary }]}>⚙️ Settings</Text>
        {isSaving ? (
          <ActivityIndicator color={colors.white} />
        ) : (
          <Pressable onPress={handleSaveAll}>
            <Text style={styles.headerSaveText}>Save</Text>
          </Pressable>
        )}
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <View style={[styles.brandCard, { backgroundColor: `${primaryColor}1A` }]}>
          <View style={[styles.brandLogo, { borderColor: `${primaryColor}33` }]}>
            {companyLogoUrl ? <Image source={{ uri: companyLogoUrl }} style={styles.brandLogoImage} /> : <Text style={styles.brandLogoIcon}>🏢</Text>}
          </View>
          <View style={styles.brandTextBox}>
            <Text style={styles.brandName}>{companyName || 'Company Name'}</Text>
            <Text style={styles.brandSubtitle}>{companyEmail || 'No email set'}</Text>
            <Text style={[styles.brandAppName, { color: primaryColor }]}>{appName}</Text>
          </View>
          <View style={[styles.brandColorSwatch, { backgroundColor: primaryColor }]}>
            <Text style={styles.brandColorIcon}>🎨</Text>
          </View>
        </View>

        <SectionHeader title="Company Settings" />
        <Card loading={isLoadingCompanyInfo}>
          <SettingRow icon="🏢" title="Company Information" subtitle="Update company name, logo, contact details" onPress={() => setShowCompanyInfo(true)} />
          <Divider />
          <SettingRow icon="🎨" title="Branding & Theme" subtitle="Customize app colors, logos, and branding" onPress={() => setShowBrandingTheme(true)} />
          <Divider />
          <SettingRow icon="📍" title="Business Address" subtitle="Update business location and service areas" onPress={() => setShowCompanyInfo(true)} />
        </Card>

        <SectionHeader title="User Management" />
        <Card>
          <SettingRow icon="👤" title="Register New User" subtitle="Add a new user to the system" onPress={() => setShowRegisterUser(true)} />
          <Divider />
          <SettingRow icon="🛡️" title="Role Permissions" subtitle="Manage user roles and access permissions" onPress={() => setShowRolePermissions(true)} />
          <Divider />
          <SettingRow icon="🔒" title="Access Control" subtitle="Set up multi-factor authentication and access policies" onPress={() => showComingSoon('Access Control')} />
        </Card>

        <SectionHeader title="Role Permissions" />
        <Card>
          <Text style={textStyles.bodyMedium}>Configure what each user role can access and do in the system. Changes take effect immediately.</Text>
          <Pressable style={styles.fullWidthButton} onPress={() => setShowRolePermissions(true)}>
            <Text style={textStyles.buttonText}>Manage Role Permissions</Text>
          </Pressable>
        </Card>

        <SectionHeader title="Delivery Settings" />
        <Card>
          <SettingRow icon="🕐" title="Delivery Time Windows" subtitle="Configure default delivery time slots and scheduling" onPress={() => showComingSoon('Delivery Time Windows')} />
          <Divider />
          <SettingRow icon="🚚" title="Delivery Status Workflow" subtitle="Customize delivery status options and transitions" onPress={() => showComingSoon('Delivery Status Workflow')} />
          <Divider />
          <SettingRow icon="🗺️" title="Route Optimization" subtitle="Configure route planning and optimization settings" onPress={() => showComingSoon('Route Optimization')} />
        </Card>

        <SectionHeader title="Notification Settings" />
        <Card>
          <Text style={styles.subheading}>Notification Channels</Text>
          <SwitchRow label="Email Notifications" subtitle="Enable email alerts for important events" value={emailNotificationsEnabled} onChange={setEmailNotificationsEnabled} />
          <SwitchRow label="SMS Notifications" subtitle="Enable SMS alerts for urgent updates" value={smsNotificationsEnabled} onChange={setSmsNotificationsEnabled} />
          <SwitchRow label="Push Notifications" subtitle="Enable in-app push notifications" value={pushNotificationsEnabled} onChange={setPushNotificationsEnabled} />
          <Divider />
          <Text style={styles.subheading}>Event Notifications</Text>
          <SwitchRow label="Delivery Completed" subtitle="Notify on successful delivery" value={notifyOnDeliveryComplete} onChange={setNotifyOnDeliveryComplete} />
          <SwitchRow label="Delivery Failed" subtitle="Alert when delivery fails" value={notifyOnDeliveryFailed} onChange={setNotifyOnDeliveryFailed} />
          <SwitchRow label="New Claim Received" subtitle="Notify on new claim submissions" value={notifyOnNewClaim} onChange={setNotifyOnNewClaim} />
          <SwitchRow label="Admin Issues" subtitle="Alert admins on critical issues" value={notifyAdminsOnIssues} onChange={setNotifyAdminsOnIssues} />
        </Card>

        <SectionHeader title="Security Settings" />
        <Card>
          <Text style={styles.subheading}>Password Requirements</Text>
          <StepperRow label="Minimum Password Length" value={passwordMinLength} min={6} max={20} onChange={setPasswordMinLength} />
          <SwitchRow label="Require Special Characters" subtitle="Passwords must include !@#$%^&*" value={requireSpecialCharacters} onChange={setRequireSpecialCharacters} />
          <Divider />
          <Text style={styles.subheading}>Session & Access</Text>
          <StepperRow label="Session Timeout (minutes)" value={sessionTimeoutMinutes} min={5} max={120} step={5} onChange={setSessionTimeoutMinutes} />
          <SwitchRow label="Two-Factor Authentication" subtitle="Require 2FA for admin accounts" value={enableTwoFactorAuth} onChange={setEnableTwoFactorAuth} />
          <SwitchRow label="Audit Logging" subtitle="Log all user actions for compliance" value={logAllUserActions} onChange={setLogAllUserActions} />
        </Card>

        <SectionHeader title="Integration Settings" />
        <Card>
          <SettingRow icon="🔄" title="ABServe Integration" subtitle="Import deliveries from ABServe ERP system" onPress={() => navigation.navigate('AbaserveImport')} />
          <Divider />
          <SettingRow icon="🏢" title="Business Central Integration" subtitle="Configure Microsoft Dynamics 365 Business Central connection" onPress={() => navigation.navigate('BcSettings')} />
          <Divider />
          <SettingRow icon="☁️" title="Third-party APIs" subtitle="Connect with external services and APIs" onPress={() => setShowApiSettings(true)} />
          <Divider />
          <SettingRow icon="🪝" title="Webhooks" subtitle="Configure webhooks for event notifications" onPress={() => setShowWebhookSettings(true)} />
        </Card>

        <SectionHeader title="System Settings" />
        <Card>
          <SettingRow icon="🌐" title="Language & Localization" subtitle="Set default language and regional preferences" onPress={() => showComingSoon('Language & Localization')} />
          <Divider />
          <SettingRow icon="🕐" title="Timezone Settings" subtitle="Configure system timezone and date formats" onPress={() => showComingSoon('Timezone Settings')} />
          <Divider />
          <SettingRow icon="💾" title="Data Backup" subtitle="Schedule automatic backups and retention policies" onPress={() => showComingSoon('Data Backup')} />
        </Card>

        <SectionHeader title="Driver Settings" />
        <Card loading={isLoadingDriverSettings}>
          <SwitchRow label="GPS Tracking" subtitle="Enable real-time GPS tracking for drivers" value={gpsTrackingEnabled} onChange={setGpsTrackingEnabled} icon="📍" />
          {gpsTrackingEnabled ? (
            <View style={styles.nestedSection}>
              <FrequencySelector label="Update Frequency" value={gpsUpdateFrequency} options={['15', '30', '60', '120']} unit="seconds" onChange={setGpsUpdateFrequency} />
              <SwitchRow label="Privacy Mode" subtitle="Limit GPS data collection when not on delivery" value={gpsPrivacyMode} onChange={setGpsPrivacyMode} icon="🕵️" />
            </View>
          ) : null}
          <Divider />
          <SwitchRow label="Require Delivery Photos" subtitle="Drivers must capture photos for each delivery" value={requireDeliveryPhotos} onChange={setRequireDeliveryPhotos} icon="📷" />
          <Divider />
          <SwitchRow label="Require Signature Photos" subtitle="Capture photos of customer signatures" value={requireSignaturePhotos} onChange={setRequireSignaturePhotos} icon="✍️" />
          <Divider />
          <SwitchRow label="Require Location Photos" subtitle="Photos showing delivery location context" value={requireLocationPhotos} onChange={setRequireLocationPhotos} icon="🗺️" />
          <Divider />
          <SwitchRow label="Offline Mode" subtitle="Allow drivers to work without network coverage" value={offlineModeEnabled} onChange={setOfflineModeEnabled} icon="📴" />
          {offlineModeEnabled ? (
            <View style={styles.nestedSection}>
              <FrequencySelector label="Sync Frequency" value={syncFrequency} options={['5', '15', '30', '60']} unit="minutes" onChange={setSyncFrequency} />
              <SwitchRow label="Auto-sync on Network" subtitle="Automatically sync data when network is available" value={autoSyncOnNetwork} onChange={setAutoSyncOnNetwork} icon="🔄" />
            </View>
          ) : null}
        </Card>

        <SectionHeader title="Claim Settings" />
        <Card>
          <SettingRow icon="📋" title="Claim Workflows" subtitle="Configure claim approval processes and requirements" onPress={() => showComingSoon('Claim Workflows')} />
          <Divider />
          <SettingRow icon="📎" title="Required Documentation" subtitle="Set documentation requirements for claims" onPress={() => showComingSoon('Required Documentation')} />
          <Divider />
          <SettingRow icon="⏱️" title="Claim Processing" subtitle="Configure claim processing timeframes and SLAs" onPress={() => showComingSoon('Claim Processing')} />
        </Card>

        <SectionHeader title="Data & Backups" />
        <Card>
          <SettingRow icon="☁️" title="Backup All Data" subtitle="Create a full backup of company data (manual)" onPress={handleBackup} />
        </Card>

        <SectionHeader title="Debug & Testing" />
        <Card>
          <SettingRow icon="🔄" title="Reset Onboarding" subtitle="Reset onboarding status to test the onboarding flow" onPress={handleResetOnboarding} />
          <Divider />
          <SettingRow icon="ℹ️" title="Onboarding Debug Info" subtitle="View current onboarding status and data" onPress={handleShowOnboardingDebug} />
        </Card>
      </ScrollView>

      {backupMessage ? (
        <Modal visible transparent animationType="fade">
          <View style={styles.modalBackdrop}>
            <View style={[styles.modalCard, shadows.card, styles.backupModalCard]}>
              <ActivityIndicator color={colors.primary} />
              <Text style={[textStyles.bodyMedium, styles.backupMessageText]}>{backupMessage}</Text>
            </View>
          </View>
        </Modal>
      ) : null}

      <Modal visible={showCompanyInfo} transparent animationType="fade" onRequestClose={() => setShowCompanyInfo(false)}>
        <View style={styles.modalBackdrop}>
          <ScrollView style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Company Information</Text>
            <Pressable style={styles.logoUploadRow} onPress={handleUploadCompanyLogo}>
              <View style={styles.logoPreview}>
                {companyLogoUrl ? <Image source={{ uri: companyLogoUrl }} style={styles.brandLogoImage} /> : <Text style={styles.brandLogoIcon}>🏢</Text>}
              </View>
              <Text style={styles.uploadLinkText}>📤 Upload Logo</Text>
            </Pressable>
            <LabeledInput label="Company Name" value={companyName} onChangeText={setCompanyName} />
            <LabeledInput label="Email Address" value={companyEmail} onChangeText={setCompanyEmail} keyboardType="email-address" />
            <LabeledInput label="Phone Number" value={companyPhone} onChangeText={setCompanyPhone} keyboardType="phone-pad" />
            <LabeledInput label="Business Address" value={companyAddress} onChangeText={setCompanyAddress} multiline />
            <LabeledInput label="Website" value={companyWebsite} onChangeText={setCompanyWebsite} keyboardType="url" />
            <LabeledInput label="Company Registration Number" value={companyRegistration} onChangeText={setCompanyRegistration} />
            <LabeledInput label="Tax Number" value={taxNumber} onChangeText={setTaxNumber} />
            <LabeledInput label="Company Description" value={companyDescription} onChangeText={setCompanyDescription} multiline />
            <View style={styles.modalActionsRow}>
              <Pressable style={styles.secondaryButton} onPress={() => setShowCompanyInfo(false)}>
                <Text style={styles.secondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalCloseButton} disabled={isSaving} onPress={handleSaveCompanyInfoOnly}>
                {isSaving ? <ActivityIndicator color={colors.white} /> : <Text style={textStyles.buttonText}>Save</Text>}
              </Pressable>
            </View>
          </ScrollView>
        </View>
      </Modal>

      <Modal visible={showBrandingTheme} transparent animationType="fade" onRequestClose={() => setShowBrandingTheme(false)}>
        <View style={styles.modalBackdrop}>
          <ScrollView style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Branding & Theme</Text>
            <LabeledInput label="App Name" value={appName} onChangeText={setAppName} />
            <Pressable style={styles.logoUploadRow} onPress={handleUploadAppLogo}>
              <View style={styles.logoPreview}>
                {appLogoUrl ? <Image source={{ uri: appLogoUrl }} style={styles.brandLogoImage} /> : <Text style={styles.brandLogoIcon}>🖼️</Text>}
              </View>
              <Text style={styles.uploadLinkText}>📤 Upload App Logo</Text>
            </Pressable>
            <Text style={[textStyles.bodySmall, styles.themeColorsLabel]}>Theme Colors</Text>
            <ColorPickerRow label="Primary Color" color={primaryColor} onSelect={setPrimaryColor} />
            <ColorPickerRow label="Accent Color" color={accentColor} onSelect={setAccentColor} />
            <ColorPickerRow label="Warning Color" color={warningColor} onSelect={setWarningColor} />
            <ColorPickerRow label="Success Color" color={successColor} onSelect={setSuccessColor} />
            <View style={styles.modalActionsRow}>
              <Pressable style={styles.secondaryButton} onPress={() => setShowBrandingTheme(false)}>
                <Text style={styles.secondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalCloseButton} disabled={isSaving} onPress={handleSaveBrandingAndClose}>
                {isSaving ? <ActivityIndicator color={colors.white} /> : <Text style={textStyles.buttonText}>Save</Text>}
              </Pressable>
            </View>
          </ScrollView>
        </View>
      </Modal>

      <Modal visible={showRegisterUser} transparent animationType="fade" onRequestClose={() => setShowRegisterUser(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Register New User</Text>
            <LabeledInput label="Email" value={regEmail} onChangeText={setRegEmail} keyboardType="email-address" autoCapitalize="none" />
            <LabeledInput label="Password" value={regPassword} onChangeText={setRegPassword} secureTextEntry />
            <LabeledInput label="Display Name" value={regDisplayName} onChangeText={setRegDisplayName} />
            <Text style={[textStyles.bodySmall, styles.roleLabel]}>Role</Text>
            <View style={styles.roleChipRow}>
              {ALL_USER_ROLES.map((role) => (
                <Pressable key={role} style={[styles.roleChip, regRole === role && styles.roleChipSelected]} onPress={() => setRegRole(role)}>
                  <Text style={[styles.roleChipText, regRole === role && styles.roleChipTextSelected]}>{userRoleDisplayName(role)}</Text>
                </Pressable>
              ))}
            </View>
            <View style={styles.modalActionsRow}>
              <Pressable style={styles.secondaryButton} onPress={() => setShowRegisterUser(false)}>
                <Text style={styles.secondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalCloseButton} disabled={isRegisteringUser} onPress={handleRegisterUser}>
                {isRegisteringUser ? <ActivityIndicator color={colors.white} /> : <Text style={textStyles.buttonText}>Register</Text>}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={showRolePermissions} transparent animationType="fade" onRequestClose={() => setShowRolePermissions(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, shadows.card, styles.permissionsModalCard]}>
            <Text style={textStyles.heading3}>Role Permissions Management</Text>
            <Text style={[textStyles.bodyMedium, styles.permissionsIntro]}>Configure permissions for each role. Toggle to grant access.</Text>
            <ScrollView horizontal>
              <View>
                <View style={styles.permissionsHeaderRow}>
                  <Text style={[styles.permissionsHeaderCell, styles.permissionsNameCol]}>Permission</Text>
                  {PERMISSION_ROLE_COLUMNS.map((role) => (
                    <Text key={role} style={[styles.permissionsHeaderCell, styles.permissionsRoleCol]}>
                      {userRoleDisplayName(role)}
                    </Text>
                  ))}
                </View>
                <ScrollView style={styles.permissionsBody}>
                  {AVAILABLE_PERMISSIONS.map((permission) => (
                    <View key={permission} style={styles.permissionsRow}>
                      <Text style={[textStyles.bodySmall, styles.permissionsNameCol]}>{formatPermissionName(permission)}</Text>
                      {PERMISSION_ROLE_COLUMNS.map((role) => (
                        <Pressable
                          key={role}
                          style={styles.permissionsRoleCol}
                          onPress={() => togglePermission(role, permission, !rolePermissions[role].has(permission))}
                        >
                          <Text style={styles.checkboxGlyph}>{rolePermissions[role].has(permission) ? '☑' : '☐'}</Text>
                        </Pressable>
                      ))}
                    </View>
                  ))}
                </ScrollView>
              </View>
            </ScrollView>
            <View style={styles.modalActionsRow}>
              <Pressable style={styles.secondaryButton} onPress={() => setShowRolePermissions(false)}>
                <Text style={styles.secondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalCloseButton} onPress={handleSaveRolePermissions}>
                <Text style={textStyles.buttonText}>Save Changes</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <InfoModal
        visible={showApiSettings}
        onClose={() => setShowApiSettings(false)}
        title="Third-party API Settings"
        body={'Configure connections to external APIs and services, including Google Maps, SMS gateways, email services, payment processors, and custom ERP systems.'}
        noteTitle="Coming Soon"
        note="API management interface will be available in a future update. For now, API keys can be configured directly in environment variables."
      />

      <InfoModal
        visible={showWebhookSettings}
        onClose={() => setShowWebhookSettings(false)}
        title="Webhook Settings"
        body={'Configure webhooks to receive real-time notifications for delivery status changes, new assignments, POD submissions, driver location updates, and system alerts.'}
        noteTitle="Under Development"
        note="Webhook configuration is currently being developed. Basic webhook support is available through Firebase Cloud Functions."
      />
    </View>
  );
}

function SectionHeader({ title }: { title: string }) {
  return <Text style={[textStyles.heading3, styles.sectionHeader]}>{title}</Text>;
}

function Card({ children, loading }: { children: React.ReactNode; loading?: boolean }) {
  if (loading) {
    return (
      <View style={[styles.card, shadows.card, styles.cardLoading]}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }
  return <View style={[styles.card, shadows.card]}>{children}</View>;
}

function Divider() {
  return <View style={styles.divider} />;
}

function SettingRow({ icon, title, subtitle, onPress }: { icon: string; title: string; subtitle: string; onPress: () => void }) {
  return (
    <Pressable style={styles.settingRow} onPress={onPress}>
      <Text style={styles.settingIcon}>{icon}</Text>
      <View style={styles.settingTextBox}>
        <Text style={styles.settingTitle}>{title}</Text>
        <Text style={styles.settingSubtitle}>{subtitle}</Text>
      </View>
      <Text style={styles.chevron}>›</Text>
    </Pressable>
  );
}

function SwitchRow({
  label,
  subtitle,
  value,
  onChange,
  icon,
}: {
  label: string;
  subtitle?: string;
  value: boolean;
  onChange: (value: boolean) => void;
  icon?: string;
}) {
  return (
    <View style={styles.switchRow}>
      {icon ? <Text style={styles.settingIcon}>{icon}</Text> : null}
      <View style={styles.settingTextBox}>
        <Text style={styles.settingTitle}>{label}</Text>
        {subtitle ? <Text style={styles.settingSubtitle}>{subtitle}</Text> : null}
      </View>
      <Switch value={value} onValueChange={onChange} trackColor={{ true: colors.primary }} />
    </View>
  );
}

function StepperRow({ label, value, min, max, step = 1, onChange }: { label: string; value: number; min: number; max: number; step?: number; onChange: (value: number) => void }) {
  return (
    <View style={styles.stepperRow}>
      <Text style={[textStyles.bodyMedium, styles.stepperLabel]}>{label}</Text>
      <View style={styles.stepperControls}>
        <Pressable style={styles.stepperButton} onPress={() => onChange(Math.max(min, value - step))}>
          <Text style={styles.stepperButtonText}>−</Text>
        </Pressable>
        <Text style={styles.stepperValue}>{value}</Text>
        <Pressable style={styles.stepperButton} onPress={() => onChange(Math.min(max, value + step))}>
          <Text style={styles.stepperButtonText}>+</Text>
        </Pressable>
      </View>
    </View>
  );
}

function FrequencySelector({ label, value, options, unit, onChange }: { label: string; value: string; options: string[]; unit: string; onChange: (value: string) => void }) {
  return (
    <View style={styles.frequencyRow}>
      <Text style={[textStyles.bodySmall, styles.frequencyLabel]}>
        {label}: {value} {unit}
      </Text>
      <View style={styles.frequencyChipRow}>
        {options.map((option) => (
          <Pressable key={option} style={[styles.frequencyChip, value === option && styles.frequencyChipSelected]} onPress={() => onChange(option)}>
            <Text style={[styles.frequencyChipText, value === option && styles.frequencyChipTextSelected]}>{option}</Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

const QUICK_COLORS = [colors.primary, '#2196F3', '#4CAF50', '#E57373', '#FFA726', '#9C27B0', '#009688', '#3F51B5'];

function ColorPickerRow({ label, color, onSelect }: { label: string; color: string; onSelect: (color: string) => void }) {
  const [open, setOpen] = useState(false);
  return (
    <View>
      <Pressable style={styles.colorRow} onPress={() => setOpen((v) => !v)}>
        <Text style={[textStyles.bodyMedium, styles.colorRowLabel]}>{label}</Text>
        <View style={[styles.colorSwatch, { backgroundColor: color }]} />
      </Pressable>
      {open ? (
        <View style={styles.colorOptionsRow}>
          {QUICK_COLORS.map((c) => (
            <Pressable
              key={c}
              style={[styles.colorOption, { backgroundColor: c }]}
              onPress={() => {
                onSelect(c);
                setOpen(false);
              }}
            />
          ))}
        </View>
      ) : null}
    </View>
  );
}

function LabeledInput({
  label,
  value,
  onChangeText,
  ...rest
}: {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
} & React.ComponentProps<typeof TextInput>) {
  return (
    <View style={styles.labeledInput}>
      <Text style={styles.inputLabel}>{label}</Text>
      <TextInput style={styles.input} value={value} onChangeText={onChangeText} {...rest} />
    </View>
  );
}

function InfoModal({ visible, onClose, title, body, noteTitle, note }: { visible: boolean; onClose: () => void; title: string; body: string; noteTitle: string; note: string }) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>{title}</Text>
          <Text style={[textStyles.bodyMedium, styles.infoModalBody]}>{body}</Text>
          <View style={[styles.infoNoteBox, shadows.card]}>
            <Text style={styles.infoNoteTitle}>ℹ️ {noteTitle}</Text>
            <Text style={styles.infoNoteText}>{note}</Text>
          </View>
          <Pressable style={styles.modalCloseButton} onPress={onClose}>
            <Text style={textStyles.buttonText}>Close</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.medium,
  },
  headerSaveText: { color: colors.white, fontWeight: 'bold', fontSize: 16 },
  content: { padding: spacing.large, paddingBottom: spacing.xLarge },
  brandCard: { flexDirection: 'row', alignItems: 'center', borderRadius: radii.cardRadius, padding: spacing.large, marginBottom: spacing.large },
  brandLogo: { width: 70, height: 70, borderRadius: radii.cardRadius, borderWidth: 2, backgroundColor: colors.white, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  brandLogoImage: { width: '100%', height: '100%' },
  brandLogoIcon: { fontSize: 32 },
  brandTextBox: { flex: 1, marginLeft: spacing.large },
  brandName: { fontSize: 17, fontWeight: 'bold' },
  brandSubtitle: { fontSize: 13, color: colors.textSecondary, marginTop: 2 },
  brandAppName: { fontSize: 13, fontWeight: '600', marginTop: 2 },
  brandColorSwatch: { width: 48, height: 48, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center' },
  brandColorIcon: { fontSize: 20 },
  sectionHeader: { marginTop: spacing.large, marginBottom: spacing.medium, color: colors.primary },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium },
  cardLoading: { alignItems: 'center', paddingVertical: spacing.xLarge },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small },
  settingRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4 },
  switchRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4 },
  settingIcon: { fontSize: 20, marginRight: spacing.medium, width: 28, textAlign: 'center' },
  settingTextBox: { flex: 1 },
  settingTitle: { fontWeight: '600', fontSize: 14 },
  settingSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  chevron: { fontSize: 22, color: colors.textSecondary },
  subheading: { fontWeight: 'bold', fontSize: 15, marginBottom: spacing.small },
  stepperRow: { marginBottom: spacing.medium },
  stepperLabel: { marginBottom: spacing.small },
  stepperControls: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  stepperButton: { width: 36, height: 36, borderRadius: 18, backgroundColor: `${colors.primary}1A`, alignItems: 'center', justifyContent: 'center' },
  stepperButtonText: { fontSize: 20, color: colors.primary, fontWeight: 'bold' },
  stepperValue: { fontWeight: 'bold', fontSize: 16, minWidth: 36, textAlign: 'center' },
  frequencyRow: { marginVertical: spacing.small },
  frequencyLabel: { marginBottom: spacing.small },
  frequencyChipRow: { flexDirection: 'row', gap: spacing.small },
  frequencyChip: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6 },
  frequencyChipSelected: { backgroundColor: colors.primary, borderColor: colors.primary },
  frequencyChipText: { fontSize: 12, color: colors.textSecondary },
  frequencyChipTextSelected: { color: colors.white, fontWeight: '600' },
  nestedSection: { paddingLeft: spacing.large + 16, paddingRight: spacing.small },
  fullWidthButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.medium, alignItems: 'center', marginTop: spacing.medium },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 480, maxHeight: '85%' },
  permissionsModalCard: { maxWidth: 700 },
  logoUploadRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium, marginBottom: spacing.large },
  logoPreview: { width: 56, height: 56, borderRadius: 28, backgroundColor: `${colors.primary}1A`, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  uploadLinkText: { color: colors.primary, fontWeight: '600' },
  labeledInput: { marginBottom: spacing.medium },
  inputLabel: { fontSize: 12, color: colors.textSecondary, marginBottom: 4 },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  modalActionsRow: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.medium, marginTop: spacing.large },
  secondaryButton: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4 },
  secondaryButtonText: { color: colors.textSecondary, fontWeight: '600' },
  modalCloseButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4, alignItems: 'center', minWidth: 80 },
  themeColorsLabel: { fontWeight: 'bold', marginBottom: spacing.small },
  colorRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.medium, marginBottom: spacing.small },
  colorRowLabel: { fontWeight: '500' },
  colorSwatch: { width: 32, height: 32, borderRadius: 8, borderWidth: 1, borderColor: colors.divider },
  colorOptionsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginBottom: spacing.medium },
  colorOption: { width: 36, height: 36, borderRadius: 8, borderWidth: 1, borderColor: colors.divider },
  roleLabel: { marginBottom: spacing.small },
  roleChipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginBottom: spacing.medium },
  roleChip: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6 },
  roleChipSelected: { backgroundColor: colors.primary, borderColor: colors.primary },
  roleChipText: { fontSize: 12, color: colors.textSecondary },
  roleChipTextSelected: { color: colors.white, fontWeight: '600' },
  permissionsIntro: { marginVertical: spacing.medium },
  permissionsHeaderRow: { flexDirection: 'row', backgroundColor: colors.divider, paddingVertical: spacing.small },
  permissionsHeaderCell: { fontWeight: 'bold', fontSize: 12, textAlign: 'center' },
  permissionsNameCol: { width: 160, paddingHorizontal: spacing.small, textAlign: 'left' },
  permissionsRoleCol: { width: 90, alignItems: 'center', justifyContent: 'center' },
  permissionsBody: { maxHeight: 320 },
  permissionsRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  checkboxGlyph: { fontSize: 18, color: colors.primary },
  infoModalBody: { marginVertical: spacing.medium, lineHeight: 20 },
  infoNoteBox: { backgroundColor: `${colors.info}14`, borderRadius: radii.cardRadius, padding: spacing.medium },
  infoNoteTitle: { fontWeight: 'bold', color: colors.info, marginBottom: spacing.small },
  infoNoteText: { color: colors.info, fontSize: 13 },
  backupModalCard: { alignItems: 'center', maxWidth: 320 },
  backupMessageText: { marginTop: spacing.medium, textAlign: 'center' },
});
