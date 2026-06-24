import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Image, Pressable, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { useThemeStore } from '../../stores/useThemeStore';
import { pickLogoImage, uploadAppLogo, uploadCompanyLogo } from '../../repositories/fileUploadService';
import { backupAllData } from '../../repositories/comprehensiveBackupService';
import { getOnboardingDebugData, resetOnboarding } from '../../repositories/onboardingService';
import { ALL_USER_ROLES, UserRole, userRoleDisplayName } from '../../models/user';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import {
  AppIcon,
  AppIconName,
  AppModal,
  Card,
  FormField,
  PrimaryButton,
  SecondaryButton,
} from '../../components/ui';

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
 * - Slider becomes a +/- stepper row (no slider library installed).
 *
 * UI/UX Refresh Phase 5: rebuilt on the shared primitives (Card/FormField/AppModal/
 * PrimaryButton) and the SVG AppIcon pack; the redundant in-screen navy header bar was
 * dropped in favour of the navigator header, and the global Save action moved to a
 * persistent footer. Behaviour, Firestore writes, validation, and store calls unchanged.
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
        <Text style={textStyles.bodyMedium}>Please log in</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <Card padding="spacious" style={[styles.brandCard, { backgroundColor: `${primaryColor}1A`, borderColor: `${primaryColor}33` }]}>
          <View style={[styles.brandLogo, { borderColor: `${primaryColor}33` }]}>
            {companyLogoUrl ? <Image source={{ uri: companyLogoUrl }} style={styles.brandLogoImage} /> : <AppIcon name="image" size={30} color={primaryColor} />}
          </View>
          <View style={styles.brandTextBox}>
            <Text style={styles.brandName}>{companyName || 'Company Name'}</Text>
            <Text style={styles.brandSubtitle}>{companyEmail || 'No email set'}</Text>
            <Text style={[styles.brandAppName, { color: primaryColor }]}>{appName}</Text>
          </View>
          <View style={[styles.brandColorSwatch, { backgroundColor: primaryColor }]} />
        </Card>

        <SectionHeader title="Company Settings" />
        <SettingCard loading={isLoadingCompanyInfo}>
          <SettingRow icon="home" title="Company Information" subtitle="Update company name, logo, contact details" onPress={() => setShowCompanyInfo(true)} />
          <Divider />
          <SettingRow icon="image" title="Branding & Theme" subtitle="Customize app colors, logos, and branding" onPress={() => setShowBrandingTheme(true)} />
          <Divider />
          <SettingRow icon="location" title="Business Address" subtitle="Update business location and service areas" onPress={() => setShowCompanyInfo(true)} />
        </SettingCard>

        <SectionHeader title="User Management" />
        <SettingCard>
          <SettingRow icon="user" title="Register New User" subtitle="Add a new user to the system" onPress={() => setShowRegisterUser(true)} />
          <Divider />
          <SettingRow icon="shield" title="Role Permissions" subtitle="Manage user roles and access permissions" onPress={() => setShowRolePermissions(true)} />
          <Divider />
          <SettingRow icon="lock" title="Access Control" subtitle="Set up multi-factor authentication and access policies" onPress={() => showComingSoon('Access Control')} />
        </SettingCard>

        <SectionHeader title="Role Permissions" />
        <SettingCard>
          <Text style={textStyles.bodyMedium}>Configure what each user role can access and do in the system. Changes take effect immediately.</Text>
          <PrimaryButton label="Manage Role Permissions" icon="shield" onPress={() => setShowRolePermissions(true)} style={styles.fullWidthButton} />
        </SettingCard>

        <SectionHeader title="Delivery Settings" />
        <SettingCard>
          <SettingRow icon="calendar" title="Delivery Time Windows" subtitle="Configure default delivery time slots and scheduling" onPress={() => showComingSoon('Delivery Time Windows')} />
          <Divider />
          <SettingRow icon="truck" title="Delivery Status Workflow" subtitle="Customize delivery status options and transitions" onPress={() => showComingSoon('Delivery Status Workflow')} />
          <Divider />
          <SettingRow icon="map" title="Route Optimization" subtitle="Configure route planning and optimization settings" onPress={() => showComingSoon('Route Optimization')} />
        </SettingCard>

        <SectionHeader title="Notification Settings" />
        <SettingCard>
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
        </SettingCard>

        <SectionHeader title="Security Settings" />
        <SettingCard>
          <Text style={styles.subheading}>Password Requirements</Text>
          <StepperRow label="Minimum Password Length" value={passwordMinLength} min={6} max={20} onChange={setPasswordMinLength} />
          <SwitchRow label="Require Special Characters" subtitle="Passwords must include !@#$%^&*" value={requireSpecialCharacters} onChange={setRequireSpecialCharacters} />
          <Divider />
          <Text style={styles.subheading}>Session & Access</Text>
          <StepperRow label="Session Timeout (minutes)" value={sessionTimeoutMinutes} min={5} max={120} step={5} onChange={setSessionTimeoutMinutes} />
          <SwitchRow label="Two-Factor Authentication" subtitle="Require 2FA for admin accounts" value={enableTwoFactorAuth} onChange={setEnableTwoFactorAuth} />
          <SwitchRow label="Audit Logging" subtitle="Log all user actions for compliance" value={logAllUserActions} onChange={setLogAllUserActions} />
        </SettingCard>

        <SectionHeader title="Integration Settings" />
        <SettingCard>
          <SettingRow icon="download" title="ABServe Integration" subtitle="Import deliveries from ABServe ERP system" onPress={() => navigation.navigate('AbaserveImport')} />
          <Divider />
          <SettingRow icon="link" title="Business Central Integration" subtitle="Configure Microsoft Dynamics 365 Business Central connection" onPress={() => navigation.navigate('BcSettings')} />
          <Divider />
          <SettingRow icon="key" title="Third-party APIs" subtitle="Connect with external services and APIs" onPress={() => setShowApiSettings(true)} />
          <Divider />
          <SettingRow icon="activity" title="Webhooks" subtitle="Configure webhooks for event notifications" onPress={() => setShowWebhookSettings(true)} />
        </SettingCard>

        <SectionHeader title="System Settings" />
        <SettingCard>
          <SettingRow icon="message" title="Language & Localization" subtitle="Set default language and regional preferences" onPress={() => showComingSoon('Language & Localization')} />
          <Divider />
          <SettingRow icon="calendar" title="Timezone Settings" subtitle="Configure system timezone and date formats" onPress={() => showComingSoon('Timezone Settings')} />
          <Divider />
          <SettingRow icon="copy" title="Data Backup" subtitle="Schedule automatic backups and retention policies" onPress={() => showComingSoon('Data Backup')} />
        </SettingCard>

        <SectionHeader title="Driver Settings" />
        <SettingCard loading={isLoadingDriverSettings}>
          <SwitchRow label="GPS Tracking" subtitle="Enable real-time GPS tracking for drivers" value={gpsTrackingEnabled} onChange={setGpsTrackingEnabled} icon="location" />
          {gpsTrackingEnabled ? (
            <View style={styles.nestedSection}>
              <FrequencySelector label="Update Frequency" value={gpsUpdateFrequency} options={['15', '30', '60', '120']} unit="seconds" onChange={setGpsUpdateFrequency} />
              <SwitchRow label="Privacy Mode" subtitle="Limit GPS data collection when not on delivery" value={gpsPrivacyMode} onChange={setGpsPrivacyMode} icon="eye" />
            </View>
          ) : null}
          <Divider />
          <SwitchRow label="Require Delivery Photos" subtitle="Drivers must capture photos for each delivery" value={requireDeliveryPhotos} onChange={setRequireDeliveryPhotos} icon="camera" />
          <Divider />
          <SwitchRow label="Require Signature Photos" subtitle="Capture photos of customer signatures" value={requireSignaturePhotos} onChange={setRequireSignaturePhotos} icon="signature" />
          <Divider />
          <SwitchRow label="Require Location Photos" subtitle="Photos showing delivery location context" value={requireLocationPhotos} onChange={setRequireLocationPhotos} icon="map" />
          <Divider />
          <SwitchRow label="Offline Mode" subtitle="Allow drivers to work without network coverage" value={offlineModeEnabled} onChange={setOfflineModeEnabled} icon="wifiOff" />
          {offlineModeEnabled ? (
            <View style={styles.nestedSection}>
              <FrequencySelector label="Sync Frequency" value={syncFrequency} options={['5', '15', '30', '60']} unit="minutes" onChange={setSyncFrequency} />
              <SwitchRow label="Auto-sync on Network" subtitle="Automatically sync data when network is available" value={autoSyncOnNetwork} onChange={setAutoSyncOnNetwork} icon="activity" />
            </View>
          ) : null}
        </SettingCard>

        <SectionHeader title="Claim Settings" />
        <SettingCard>
          <SettingRow icon="clipboard" title="Claim Workflows" subtitle="Configure claim approval processes and requirements" onPress={() => showComingSoon('Claim Workflows')} />
          <Divider />
          <SettingRow icon="file" title="Required Documentation" subtitle="Set documentation requirements for claims" onPress={() => showComingSoon('Required Documentation')} />
          <Divider />
          <SettingRow icon="activity" title="Claim Processing" subtitle="Configure claim processing timeframes and SLAs" onPress={() => showComingSoon('Claim Processing')} />
        </SettingCard>

        <SectionHeader title="Data & Backups" />
        <SettingCard>
          <SettingRow icon="download" title="Backup All Data" subtitle="Create a full backup of company data (manual)" onPress={handleBackup} />
        </SettingCard>

        <SectionHeader title="Debug & Testing" />
        <SettingCard>
          <SettingRow icon="activity" title="Reset Onboarding" subtitle="Reset onboarding status to test the onboarding flow" onPress={handleResetOnboarding} />
          <Divider />
          <SettingRow icon="info" title="Onboarding Debug Info" subtitle="View current onboarding status and data" onPress={handleShowOnboardingDebug} />
        </SettingCard>
      </ScrollView>

      <View style={styles.footer}>
        <PrimaryButton
          label={isSaving ? 'Saving...' : 'Save All Settings'}
          icon="check"
          loading={isSaving}
          disabled={isSaving}
          onPress={handleSaveAll}
        />
      </View>

      <AppModal visible={!!backupMessage} title="Backup in progress" dismissable={false} onClose={() => {}}>
        <View style={styles.backupBody}>
          <ActivityIndicator color={colors.active} />
          <Text style={[textStyles.bodyMedium, styles.backupMessageText]}>{backupMessage}</Text>
        </View>
      </AppModal>

      <AppModal
        visible={showCompanyInfo}
        title="Company Information"
        onClose={() => setShowCompanyInfo(false)}
        footer={
          <View style={styles.modalActionsRow}>
            <SecondaryButton label="Cancel" onPress={() => setShowCompanyInfo(false)} style={styles.modalActionButton} />
            <PrimaryButton label={isSaving ? 'Saving...' : 'Save'} loading={isSaving} disabled={isSaving} onPress={handleSaveCompanyInfoOnly} style={styles.modalActionButton} />
          </View>
        }
      >
        <ScrollView style={styles.modalScroll} contentContainerStyle={styles.modalScrollContent} showsVerticalScrollIndicator={false}>
          <LogoUploadRow logoUrl={companyLogoUrl} onUpload={handleUploadCompanyLogo} />
          <FormField label="Company Name" value={companyName} onChangeText={setCompanyName} />
          <FormField label="Email Address" value={companyEmail} onChangeText={setCompanyEmail} keyboardType="email-address" autoCapitalize="none" />
          <FormField label="Phone Number" value={companyPhone} onChangeText={setCompanyPhone} keyboardType="phone-pad" />
          <FormField label="Business Address" value={companyAddress} onChangeText={setCompanyAddress} multiline />
          <FormField label="Website" value={companyWebsite} onChangeText={setCompanyWebsite} keyboardType="url" autoCapitalize="none" />
          <FormField label="Company Registration Number" value={companyRegistration} onChangeText={setCompanyRegistration} />
          <FormField label="Tax Number" value={taxNumber} onChangeText={setTaxNumber} />
          <FormField label="Company Description" value={companyDescription} onChangeText={setCompanyDescription} multiline />
        </ScrollView>
      </AppModal>

      <AppModal
        visible={showBrandingTheme}
        title="Branding & Theme"
        onClose={() => setShowBrandingTheme(false)}
        footer={
          <View style={styles.modalActionsRow}>
            <SecondaryButton label="Cancel" onPress={() => setShowBrandingTheme(false)} style={styles.modalActionButton} />
            <PrimaryButton label={isSaving ? 'Saving...' : 'Save'} loading={isSaving} disabled={isSaving} onPress={handleSaveBrandingAndClose} style={styles.modalActionButton} />
          </View>
        }
      >
        <ScrollView style={styles.modalScroll} contentContainerStyle={styles.modalScrollContent} showsVerticalScrollIndicator={false}>
          <FormField label="App Name" value={appName} onChangeText={setAppName} />
          <LogoUploadRow logoUrl={appLogoUrl} onUpload={handleUploadAppLogo} label="Upload App Logo" />
          <Text style={[textStyles.label, styles.themeColorsLabel]}>Theme Colors</Text>
          <ColorPickerRow label="Primary Color" color={primaryColor} onSelect={setPrimaryColor} />
          <ColorPickerRow label="Accent Color" color={accentColor} onSelect={setAccentColor} />
          <ColorPickerRow label="Warning Color" color={warningColor} onSelect={setWarningColor} />
          <ColorPickerRow label="Success Color" color={successColor} onSelect={setSuccessColor} />
        </ScrollView>
      </AppModal>

      <AppModal
        visible={showRegisterUser}
        title="Register New User"
        onClose={() => setShowRegisterUser(false)}
        footer={
          <View style={styles.modalActionsRow}>
            <SecondaryButton label="Cancel" onPress={() => setShowRegisterUser(false)} style={styles.modalActionButton} />
            <PrimaryButton label={isRegisteringUser ? 'Registering...' : 'Register'} loading={isRegisteringUser} disabled={isRegisteringUser} onPress={handleRegisterUser} style={styles.modalActionButton} />
          </View>
        }
      >
        <View style={styles.modalScrollContent}>
          <FormField label="Email" value={regEmail} onChangeText={setRegEmail} keyboardType="email-address" autoCapitalize="none" />
          <FormField label="Password" value={regPassword} onChangeText={setRegPassword} secureTextEntry />
          <FormField label="Display Name" value={regDisplayName} onChangeText={setRegDisplayName} />
          <Text style={[textStyles.label, styles.roleLabel]}>Role</Text>
          <View style={styles.roleChipRow}>
            {ALL_USER_ROLES.map((role) => (
              <Chip key={role} label={userRoleDisplayName(role)} selected={regRole === role} onPress={() => setRegRole(role)} />
            ))}
          </View>
        </View>
      </AppModal>

      <AppModal
        visible={showRolePermissions}
        title="Role Permissions Management"
        onClose={() => setShowRolePermissions(false)}
        footer={
          <View style={styles.modalActionsRow}>
            <SecondaryButton label="Cancel" onPress={() => setShowRolePermissions(false)} style={styles.modalActionButton} />
            <PrimaryButton label="Save Changes" onPress={handleSaveRolePermissions} style={styles.modalActionButton} />
          </View>
        }
      >
        <Text style={[textStyles.bodyMedium, styles.permissionsIntro]}>Configure permissions for each role. Toggle to grant access.</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View>
            <View style={styles.permissionsHeaderRow}>
              <Text style={[styles.permissionsHeaderCell, styles.permissionsNameCol]}>Permission</Text>
              {PERMISSION_ROLE_COLUMNS.map((role) => (
                <Text key={role} style={[styles.permissionsHeaderCell, styles.permissionsRoleCol]}>
                  {userRoleDisplayName(role)}
                </Text>
              ))}
            </View>
            <ScrollView style={styles.permissionsBody} showsVerticalScrollIndicator={false}>
              {AVAILABLE_PERMISSIONS.map((permission) => (
                <View key={permission} style={styles.permissionsRow}>
                  <Text style={[textStyles.bodySmall, styles.permissionsNameCol]}>{formatPermissionName(permission)}</Text>
                  {PERMISSION_ROLE_COLUMNS.map((role) => {
                    const granted = rolePermissions[role].has(permission);
                    return (
                      <Pressable
                        key={role}
                        accessibilityRole="checkbox"
                        accessibilityState={{ checked: granted }}
                        accessibilityLabel={`${formatPermissionName(permission)} for ${userRoleDisplayName(role)}`}
                        style={styles.permissionsRoleCol}
                        onPress={() => togglePermission(role, permission, !granted)}
                      >
                        <View style={[styles.permissionBox, granted && styles.permissionBoxChecked]}>
                          {granted ? <AppIcon name="check" size={14} color={colors.onPrimary} /> : null}
                        </View>
                      </Pressable>
                    );
                  })}
                </View>
              ))}
            </ScrollView>
          </View>
        </ScrollView>
      </AppModal>

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

function SettingCard({ children, loading }: { children: React.ReactNode; loading?: boolean }) {
  if (loading) {
    return (
      <Card style={styles.cardLoading}>
        <ActivityIndicator color={colors.active} />
      </Card>
    );
  }
  return <Card>{children}</Card>;
}

function Divider() {
  return <View style={styles.divider} />;
}

function SettingRow({ icon, title, subtitle, onPress }: { icon: AppIconName; title: string; subtitle: string; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" style={styles.settingRow} onPress={onPress}>
      <AppIcon name={icon} size={20} color={colors.shell} />
      <View style={styles.settingTextBox}>
        <Text style={styles.settingTitle}>{title}</Text>
        <Text style={styles.settingSubtitle}>{subtitle}</Text>
      </View>
      <AppIcon name="chevronRight" size={20} color={colors.contentSecondary} />
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
  icon?: AppIconName;
}) {
  return (
    <View style={styles.switchRow}>
      {icon ? <AppIcon name={icon} size={20} color={colors.shell} /> : null}
      <View style={styles.settingTextBox}>
        <Text style={styles.settingTitle}>{label}</Text>
        {subtitle ? <Text style={styles.settingSubtitle}>{subtitle}</Text> : null}
      </View>
      <Switch value={value} onValueChange={onChange} trackColor={{ true: colors.active, false: colors.border }} />
    </View>
  );
}

function StepperRow({ label, value, min, max, step = 1, onChange }: { label: string; value: number; min: number; max: number; step?: number; onChange: (value: number) => void }) {
  return (
    <View style={styles.stepperRow}>
      <Text style={[textStyles.bodyMedium, styles.stepperLabel]}>{label}</Text>
      <View style={styles.stepperControls}>
        <Pressable accessibilityRole="button" accessibilityLabel={`Decrease ${label}`} style={styles.stepperButton} onPress={() => onChange(Math.max(min, value - step))}>
          <AppIcon name="minus" size={18} color={colors.shell} />
        </Pressable>
        <Text style={styles.stepperValue}>{value}</Text>
        <Pressable accessibilityRole="button" accessibilityLabel={`Increase ${label}`} style={styles.stepperButton} onPress={() => onChange(Math.min(max, value + step))}>
          <AppIcon name="plus" size={18} color={colors.shell} />
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
      <View style={styles.chipRow}>
        {options.map((option) => (
          <Chip key={option} label={option} selected={value === option} onPress={() => onChange(option)} />
        ))}
      </View>
    </View>
  );
}

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" accessibilityState={{ selected }} style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function LogoUploadRow({ logoUrl, onUpload, label = 'Upload Logo' }: { logoUrl?: string; onUpload: () => void; label?: string }) {
  return (
    <View style={styles.logoUploadRow}>
      <View style={styles.logoPreview}>
        {logoUrl ? <Image source={{ uri: logoUrl }} style={styles.brandLogoImage} /> : <AppIcon name="image" size={26} color={colors.shell} />}
      </View>
      <SecondaryButton label={label} icon="upload" onPress={onUpload} style={styles.logoUploadButton} />
    </View>
  );
}

const QUICK_COLORS = [colors.primary, '#2196F3', '#4CAF50', '#E57373', '#FFA726', '#9C27B0', '#009688', '#3F51B5'];

function ColorPickerRow({ label, color, onSelect }: { label: string; color: string; onSelect: (color: string) => void }) {
  const [open, setOpen] = useState(false);
  return (
    <View>
      <Pressable accessibilityRole="button" style={styles.colorRow} onPress={() => setOpen((v) => !v)}>
        <Text style={[textStyles.bodyMedium, styles.colorRowLabel]}>{label}</Text>
        <View style={[styles.colorSwatch, { backgroundColor: color }]} />
      </Pressable>
      {open ? (
        <View style={styles.colorOptionsRow}>
          {QUICK_COLORS.map((c) => (
            <Pressable
              key={c}
              accessibilityRole="button"
              accessibilityLabel={`Select color ${c}`}
              style={[styles.colorOption, { backgroundColor: c }, color === c && styles.colorOptionSelected]}
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

function InfoModal({ visible, onClose, title, body, noteTitle, note }: { visible: boolean; onClose: () => void; title: string; body: string; noteTitle: string; note: string }) {
  return (
    <AppModal
      visible={visible}
      title={title}
      onClose={onClose}
      footer={<PrimaryButton label="Close" onPress={onClose} />}
    >
      <Text style={[textStyles.bodyMedium, styles.infoModalBody]}>{body}</Text>
      <View style={styles.infoNoteBox}>
        <View style={styles.infoNoteHeader}>
          <AppIcon name="info" size={18} color={colors.active} />
          <Text style={styles.infoNoteTitle}>{noteTitle}</Text>
        </View>
        <Text style={styles.infoNoteText}>{note}</Text>
      </View>
    </AppModal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.canvas },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.canvas },
  content: { padding: spacing.medium, paddingBottom: spacing.large, gap: spacing.small },
  footer: {
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    padding: spacing.medium,
  },
  brandCard: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small },
  brandLogo: { width: 64, height: 64, borderRadius: radii.cardRadius, borderWidth: 1, backgroundColor: colors.surface, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  brandLogoImage: { width: '100%', height: '100%' },
  brandTextBox: { flex: 1, marginLeft: spacing.medium },
  brandName: { ...textStyles.heading3, fontSize: 16 },
  brandSubtitle: { ...textStyles.bodySmall, marginTop: 2 },
  brandAppName: { ...textStyles.labelSmall, fontWeight: '600', marginTop: 2 },
  brandColorSwatch: { width: 44, height: 44, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.border },
  sectionHeader: { marginTop: spacing.medium, marginBottom: spacing.xs, color: colors.shell },
  cardLoading: { alignItems: 'center', paddingVertical: spacing.large },
  divider: { height: StyleSheet.hairlineWidth, backgroundColor: colors.border, marginVertical: spacing.xs },
  settingRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium, paddingVertical: spacing.small + 4 },
  switchRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium, paddingVertical: spacing.small + 4 },
  settingTextBox: { flex: 1 },
  settingTitle: { ...textStyles.label },
  settingSubtitle: { ...textStyles.bodySmall, marginTop: 2 },
  subheading: { ...textStyles.label, fontWeight: '700', marginBottom: spacing.xs, marginTop: spacing.xs },
  stepperRow: { marginBottom: spacing.small },
  stepperLabel: { marginBottom: spacing.small },
  stepperControls: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  stepperButton: { width: 40, height: 40, borderRadius: radii.borderRadius, backgroundColor: colors.activeMuted, alignItems: 'center', justifyContent: 'center' },
  stepperValue: { ...textStyles.heading3, minWidth: 36, textAlign: 'center' },
  frequencyRow: { marginVertical: spacing.xs },
  frequencyLabel: { marginBottom: spacing.small },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderWidth: 1, borderColor: colors.border, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.surface },
  chipSelected: { backgroundColor: colors.activeMuted, borderColor: colors.active },
  chipText: { ...textStyles.bodySmall, color: colors.contentSecondary },
  chipTextSelected: { color: colors.shell, fontWeight: '600' },
  nestedSection: { paddingLeft: spacing.large + 12, paddingRight: spacing.small },
  fullWidthButton: { marginTop: spacing.medium },
  modalScroll: { maxHeight: 460 },
  modalScrollContent: { gap: spacing.medium },
  modalActionsRow: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.small },
  modalActionButton: { minWidth: 110 },
  logoUploadRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  logoPreview: { width: 56, height: 56, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surfaceMuted, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  logoUploadButton: { flex: 1 },
  themeColorsLabel: { fontWeight: '700', marginTop: spacing.small },
  colorRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderWidth: 1, borderColor: colors.border, borderRadius: radii.borderRadius, padding: spacing.medium },
  colorRowLabel: { fontWeight: '500' },
  colorSwatch: { width: 32, height: 32, borderRadius: 8, borderWidth: 1, borderColor: colors.border },
  colorOptionsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginTop: spacing.small },
  colorOption: { width: 36, height: 36, borderRadius: 8, borderWidth: 1, borderColor: colors.border },
  colorOptionSelected: { borderWidth: 2, borderColor: colors.shell },
  roleLabel: { marginTop: spacing.xs },
  roleChipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  permissionsIntro: { marginBottom: spacing.medium },
  permissionsHeaderRow: { flexDirection: 'row', backgroundColor: colors.surfaceMuted, borderRadius: radii.borderRadius, paddingVertical: spacing.small },
  permissionsHeaderCell: { ...textStyles.labelSmall, color: colors.contentPrimary, fontWeight: '700', textAlign: 'center' },
  permissionsNameCol: { width: 160, paddingHorizontal: spacing.small, textAlign: 'left' },
  permissionsRoleCol: { width: 88, alignItems: 'center', justifyContent: 'center' },
  permissionsBody: { maxHeight: 320 },
  permissionsRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: colors.border },
  permissionBox: { width: 22, height: 22, borderRadius: 6, borderWidth: 1, borderColor: colors.border, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surface },
  permissionBoxChecked: { backgroundColor: colors.active, borderColor: colors.active },
  infoModalBody: { marginBottom: spacing.medium, lineHeight: 20 },
  infoNoteBox: { backgroundColor: colors.activeMuted, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.active, padding: spacing.medium },
  infoNoteHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginBottom: spacing.xs },
  infoNoteTitle: { ...textStyles.label, color: colors.active, fontWeight: '700' },
  infoNoteText: { ...textStyles.bodySmall, color: colors.contentSecondary },
  backupBody: { alignItems: 'center', gap: spacing.medium, paddingVertical: spacing.small },
  backupMessageText: { textAlign: 'center' },
});
