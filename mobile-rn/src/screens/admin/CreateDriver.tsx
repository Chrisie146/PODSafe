import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/create_driver_screen.dart (verified against source on
 * 2026-06-22) — was blocked on Phase 5's `createUser` callable, now unblocked (deployed
 * and live, see vault "08 Backend Gap Fix Tracker").
 *
 * Deviations from the Flutter source:
 * - Edit mode takes only `driverId` via route params and loads the full user doc through
 *   useUserManagementStore (loadUserById/selectedUser), instead of requiring the caller to
 *   pass a driverData map — same deep-link/refresh-safety precedent as DriverDetails.tsx.
 * - The `createUser` callable doesn't accept licenseNumber/vehicleInfo, so those are
 *   patched in a second, targeted Firestore write immediately after creation
 *   (patchUserFields), mirroring the Dart source's own two-step create-then-update
 *   sequence rather than extending the already-deployed callable's contract.
 */
interface CreateDriverProps {
  route: { params?: { driverId?: string } };
  navigation: { goBack: () => void };
}

export default function CreateDriver({ route, navigation }: CreateDriverProps) {
  const driverId = route.params?.driverId;
  const isEditing = !!driverId;

  const currentUser = useAuthStore((s) => s.currentUser);
  const selectedUser = useUserManagementStore((s) => s.selectedUser);
  const loadUserById = useUserManagementStore((s) => s.loadUserById);
  const createUser = useUserManagementStore((s) => s.createUser);
  const updateUser = useUserManagementStore((s) => s.updateUser);
  const patchUserFields = useUserManagementStore((s) => s.patchUserFields);

  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [password, setPassword] = useState('');
  const [obscurePassword, setObscurePassword] = useState(true);
  const [licenseNumber, setLicenseNumber] = useState('');
  const [vehicleInfo, setVehicleInfo] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [isLoadingDriver, setIsLoadingDriver] = useState(isEditing);

  useEffect(() => {
    if (driverId) {
      loadUserById(driverId);
    }
  }, [driverId, loadUserById]);

  useEffect(() => {
    if (isEditing && selectedUser) {
      setFullName(selectedUser.fullName);
      setEmail(selectedUser.email);
      setPhoneNumber(selectedUser.phoneNumber ?? '');
      setLicenseNumber(selectedUser.licenseNumber ?? '');
      setVehicleInfo(selectedUser.vehicleInfo ?? '');
      setIsLoadingDriver(false);
    }
  }, [isEditing, selectedUser]);

  const validate = (): string | null => {
    if (fullName.trim().length === 0) return 'Please enter driver name';
    if (email.trim().length === 0) return 'Please enter email address';
    if (!email.includes('@')) return 'Please enter a valid email';
    if (!isEditing) {
      if (password.trim().length === 0) return 'Please enter a password for the new driver';
      if (password.trim().length < 6) return 'Password must be at least 6 characters';
    }
    return null;
  };

  const handleSave = async () => {
    const validationError = validate();
    if (validationError) {
      Alert.alert('Notice', validationError);
      return;
    }

    setIsSaving(true);
    try {
      if (!isEditing) {
        if (!currentUser) throw new Error('Company ID not found. Please log in again.');

        const result = await createUser({
          email: email.trim(),
          password: password.trim(),
          fullName: fullName.trim(),
          companyId: currentUser.companyId,
          role: 'driver',
          phoneNumber: phoneNumber.trim() || undefined,
        });

        const patch: Record<string, unknown> = {};
        if (licenseNumber.trim()) patch.licenseNumber = licenseNumber.trim();
        if (vehicleInfo.trim()) patch.vehicleInfo = vehicleInfo.trim();
        if (Object.keys(patch).length > 0) {
          await patchUserFields(result.uid, patch);
        }

        Alert.alert('Success', `Driver created successfully: ${result.email}`);
      } else if (selectedUser) {
        await updateUser({
          ...selectedUser,
          fullName: fullName.trim(),
          phoneNumber: phoneNumber.trim() || undefined,
          licenseNumber: licenseNumber.trim() || undefined,
          vehicleInfo: vehicleInfo.trim() || undefined,
        });
        Alert.alert('Success', 'Driver updated successfully!');
      }
      navigation.goBack();
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoadingDriver) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {!isEditing ? (
        <View style={[styles.infoCard, shadows.card]}>
          <Text style={styles.infoIcon}>ℹ️</Text>
          <Text style={styles.infoText}>The driver will receive login credentials at the provided email.</Text>
        </View>
      ) : null}

      <Text style={[textStyles.heading3, styles.sectionTitle]}>Personal Information</Text>
      <TextInput style={styles.input} placeholder="Full Name" value={fullName} onChangeText={setFullName} />
      <TextInput
        style={[styles.input, isEditing && styles.inputDisabled]}
        placeholder="Email Address"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
        editable={!isEditing}
      />
      <TextInput style={styles.input} placeholder="Phone Number (Optional)" value={phoneNumber} onChangeText={setPhoneNumber} keyboardType="phone-pad" />

      {!isEditing ? (
        <>
          <Text style={[textStyles.heading3, styles.sectionTitle]}>Account Information</Text>
          <View style={styles.passwordRow}>
            <TextInput
              style={[styles.input, styles.passwordInput]}
              placeholder="Password"
              value={password}
              onChangeText={setPassword}
              secureTextEntry={obscurePassword}
            />
            <Pressable style={styles.passwordToggle} onPress={() => setObscurePassword((v) => !v)}>
              <Text style={styles.passwordToggleText}>{obscurePassword ? '👁' : '🙈'}</Text>
            </Pressable>
          </View>
        </>
      ) : null}

      <Text style={[textStyles.heading3, styles.sectionTitle]}>Driver Details</Text>
      <TextInput style={styles.input} placeholder="License Number (Optional)" value={licenseNumber} onChangeText={setLicenseNumber} />
      <TextInput
        style={[styles.input, styles.multiline]}
        placeholder="Vehicle Information (Optional), e.g. White Ford Transit, Plate: ABC-1234"
        value={vehicleInfo}
        onChangeText={setVehicleInfo}
        multiline
        numberOfLines={2}
      />

      <Pressable style={styles.saveButton} disabled={isSaving} onPress={handleSave}>
        {isSaving ? <ActivityIndicator color={colors.white} /> : <Text style={textStyles.buttonText}>{isEditing ? 'Update Driver' : 'Create Driver'}</Text>}
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  content: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  infoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: `${colors.info}1A`,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
  },
  infoIcon: { fontSize: 18, marginRight: spacing.small + 4 },
  infoText: { flex: 1, color: colors.info, fontSize: 13 },
  sectionTitle: { marginTop: spacing.medium, marginBottom: spacing.small + 4 },
  input: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 4,
    marginBottom: spacing.medium,
    backgroundColor: colors.card,
  },
  inputDisabled: { backgroundColor: colors.divider, color: colors.textSecondary },
  multiline: { minHeight: 60, textAlignVertical: 'top' },
  passwordRow: { flexDirection: 'row', alignItems: 'center' },
  passwordInput: { flex: 1 },
  passwordToggle: { position: 'absolute', right: spacing.medium },
  passwordToggleText: { fontSize: 18 },
  saveButton: {
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.medium,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: spacing.medium,
    minHeight: 48,
  },
});
