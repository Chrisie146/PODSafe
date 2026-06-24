import React, { useEffect, useMemo, useState } from 'react';
import { Alert, FlatList, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { AdminShell } from '../../components/admin/AdminShell';
import {
  AppIcon,
  Card,
  EmptyState,
  FormField,
  IconButton,
  LoadingState,
  PrimaryButton,
  SecondaryButton,
  StatusChip,
  SearchField,
  SuccessButton,
  AppModal,
} from '../../components/ui';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { AppUser, ALL_USER_ROLES, UserRole, userRoleDisplayName } from '../../models/user';
import { getPermissionsForRole } from '../../permissions/permissionService';
import { permissionDisplayName } from '../../permissions/permission';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/user_management_screen.dart (verified against source on
 * 2026-06-22).
 *
 * Deviations from the Flutter source:
 * - Role "dropdowns" use chip selectors (house convention — no picker library).
 * - "Add User" calls the Phase 5 `createUser` Cloud Function directly instead of the Dart
 *   source's sign-out/re-authenticate workaround. This surfaces a real error until that
 *   callable deploys — correct expected behavior, not a port bug.
 *
 * UI/UX refresh (Operations Precision): the native stack header, emoji filter/checkbox/FAB/
 * action glyphs, role hex badges, and bespoke dialogs are replaced with the shared
 * AppHeader, SVG AppIcon/IconButton, SearchField, StatusChip, Card, AppModal, FormField,
 * and button primitives. Semantic tokens only.
 */
interface UserManagementProps {
  navigation: {
    goBack: () => void;
    navigate: (screen: string, params?: Record<string, unknown>) => void;
  };
}

export default function UserManagement({ navigation }: UserManagementProps) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const signOut = useAuthStore((s) => s.signOut);
  const users = useUserManagementStore((s) => s.users);
  const isLoading = useUserManagementStore((s) => s.isLoading);
  const subscribeForCompany = useUserManagementStore((s) => s.subscribeForCompany);
  const toggleUserStatus = useUserManagementStore((s) => s.toggleUserStatus);
  const updateUser = useUserManagementStore((s) => s.updateUser);
  const sendPasswordResetEmail = useUserManagementStore((s) => s.sendPasswordResetEmail);
  const createUser = useUserManagementStore((s) => s.createUser);

  const [searchQuery, setSearchQuery] = useState('');
  const [filterRole, setFilterRole] = useState<UserRole | null>(null);
  const [showInactive, setShowInactive] = useState(false);
  const [showFilterModal, setShowFilterModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState<AppUser | null>(null);
  const [editingUser, setEditingUser] = useState<AppUser | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);

  useEffect(() => {
    if (currentUser) {
      subscribeForCompany(currentUser.companyId, filterRole ? { role: filterRole } : undefined);
    }
  }, [currentUser, filterRole, subscribeForCompany]);

  const filteredUsers = useMemo(() => {
    const q = searchQuery.toLowerCase();
    const result = users.filter((user) => {
      if (!showInactive && !user.isActive) return false;
      if (q.length > 0) {
        return user.fullName.toLowerCase().includes(q) || user.email.toLowerCase().includes(q);
      }
      return true;
    });
    return [...result].sort((a, b) => a.fullName.localeCompare(b.fullName));
  }, [users, searchQuery, showInactive]);

  const handleToggleStatus = (user: AppUser) => {
    Alert.alert(`${user.isActive ? 'Deactivate' : 'Activate'} User`, `Are you sure you want to ${user.isActive ? 'deactivate' : 'activate'} ${user.fullName}?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Confirm',
        onPress: async () => {
          try {
            await toggleUserStatus(user.id, !user.isActive);
            setSelectedUser(null);
            Alert.alert('Success', `User ${user.isActive ? 'deactivated' : 'activated'} successfully`);
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  const handleResetPassword = (user: AppUser) => {
    Alert.alert('Reset Password', `Send a password reset email to ${user.email}?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Send',
        onPress: async () => {
          try {
            await sendPasswordResetEmail(user.email);
            setSelectedUser(null);
            Alert.alert('Success', `Password reset email sent to ${user.email}`);
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  const handleApproveDriver = (user: AppUser) => {
    if (!currentUser) return;
    Alert.alert('Approve Driver', `Are you sure you want to approve ${user.fullName} as a driver?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Approve',
        onPress: async () => {
          try {
            await updateUser({ ...user, approvalStatus: 'approved', approvedBy: currentUser.id, approvedAt: new Date() });
            setSelectedUser(null);
            Alert.alert('Success', `${user.fullName} has been approved as a driver`);
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        },
      },
    ]);
  };

  const handleSignOut = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  if (!currentUser) {
    return (
      <AdminShell
        activeNav="users"
        title="Users"
        onNavigate={(screen) => navigation.navigate(screen)}
        onLogout={handleSignOut}
      >
        <EmptyState icon="alert" title="No company selected" message="A company ID is required to manage users." />
      </AdminShell>
    );
  }

  return (
    <AdminShell
      activeNav="users"
      title="Users"
      userName={currentUser.fullName}
      onNavigate={(screen) => navigation.navigate(screen)}
      onLogout={handleSignOut}
    >
      <View style={styles.container}>
      <View style={styles.searchRow}>
        <SearchField
          accessibilityLabel="Search users"
          placeholder="Search by name or email"
          value={searchQuery}
          onChangeText={setSearchQuery}
          containerStyle={styles.searchField}
        />
        <IconButton icon="filter" accessibilityLabel="Filter users" onPress={() => setShowFilterModal(true)} />
      </View>

      {filterRole || showInactive ? (
        <View style={styles.activeFiltersRow}>
          {filterRole ? <RemovableChip label={userRoleDisplayName(filterRole)} onRemove={() => setFilterRole(null)} /> : null}
          {showInactive ? <RemovableChip label="Show inactive" onRemove={() => setShowInactive(false)} /> : null}
        </View>
      ) : null}

      {isLoading && users.length === 0 ? (
        <LoadingState title="Loading users" message="Retrieving user accounts." />
      ) : filteredUsers.length === 0 ? (
        <EmptyState icon="users" title="No users found" message="Adjust your search or filters, or add a new user." />
      ) : (
        <FlatList
          data={filteredUsers}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => <UserListTile user={item} onPress={() => setSelectedUser(item)} />}
        />
      )}

      <View style={styles.bottomBar}>
        <PrimaryButton label="Add user" icon="plus" onPress={() => setShowCreateModal(true)} />
      </View>

      <FilterModal
        visible={showFilterModal}
        filterRole={filterRole}
        showInactive={showInactive}
        onApply={(role, inactive) => {
          setFilterRole(role);
          setShowInactive(inactive);
          setShowFilterModal(false);
        }}
        onClose={() => setShowFilterModal(false)}
      />

      {selectedUser ? (
        <UserDetailsModal
          user={selectedUser}
          onClose={() => setSelectedUser(null)}
          onEdit={() => {
            setEditingUser(selectedUser);
            setSelectedUser(null);
          }}
          onToggleStatus={() => handleToggleStatus(selectedUser)}
          onResetPassword={() => handleResetPassword(selectedUser)}
          onApproveDriver={() => handleApproveDriver(selectedUser)}
        />
      ) : null}

      {editingUser ? (
        <EditUserModal
          user={editingUser}
          onClose={() => setEditingUser(null)}
          onSave={async (fullName, phone, role) => {
            try {
              await updateUser({ ...editingUser, fullName, phoneNumber: phone || undefined, role });
              setEditingUser(null);
              Alert.alert('Success', 'User updated successfully');
            } catch (e) {
              Alert.alert('Error', (e as Error).message);
            }
          }}
        />
      ) : null}

      <CreateUserModal
        visible={showCreateModal}
        companyId={currentUser.companyId}
        onClose={() => setShowCreateModal(false)}
        onCreate={async (params) => {
          try {
            await createUser(params);
            setShowCreateModal(false);
            Alert.alert('Success', 'User created successfully!');
          } catch (e) {
            Alert.alert('Error', (e as Error).message);
          }
        }}
      />
      </View>
    </AdminShell>
  );
}

function RemovableChip({ label, onRemove }: { label: string; onRemove: () => void }) {
  return (
    <View style={styles.removableChip}>
      <Text style={styles.removableChipText}>{label}</Text>
      <Pressable hitSlop={8} accessibilityRole="button" accessibilityLabel={`Remove ${label} filter`} onPress={onRemove}>
        <AppIcon name="close" size={14} color={colors.contentSecondary} />
      </Pressable>
    </View>
  );
}

function UserListTile({ user, onPress }: { user: AppUser; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`Open ${user.fullName}`} onPress={onPress}>
      <Card style={styles.userTile}>
        <View style={[styles.avatar, { backgroundColor: user.isActive ? colors.shell : colors.contentSecondary }]}>
          <Text style={styles.avatarText}>{user.fullName.charAt(0).toUpperCase() || '?'}</Text>
        </View>
        <View style={styles.userTileBody}>
          <Text style={[textStyles.bodyLarge, !user.isActive && styles.inactiveText]}>{user.fullName}</Text>
          <Text style={textStyles.bodySmall}>{user.email}</Text>
          <View style={styles.badgeRow}>
            <StatusChip label={userRoleDisplayName(user.role)} tone="info" />
            {!user.isActive ? <StatusChip label="Inactive" tone="neutral" /> : null}
            {user.role === 'driver' && user.approvalStatus !== 'approved' ? (
              <StatusChip label={user.approvalStatus ?? 'Pending'} tone="warning" />
            ) : null}
          </View>
        </View>
        <AppIcon name="chevronRight" size={20} color={colors.contentSecondary} />
      </Card>
    </Pressable>
  );
}

function FilterModal({
  visible,
  filterRole,
  showInactive,
  onApply,
  onClose,
}: {
  visible: boolean;
  filterRole: UserRole | null;
  showInactive: boolean;
  onApply: (role: UserRole | null, showInactive: boolean) => void;
  onClose: () => void;
}) {
  const [role, setRole] = useState(filterRole);
  const [inactive, setInactive] = useState(showInactive);

  useEffect(() => {
    setRole(filterRole);
    setInactive(showInactive);
  }, [filterRole, showInactive, visible]);

  return (
    <AppModal
      visible={visible}
      title="Filter users"
      onClose={onClose}
      footer={
        <View style={styles.modalActionsRow}>
          <SecondaryButton label="Cancel" style={styles.modalButton} onPress={onClose} />
          <PrimaryButton label="Apply" style={styles.modalButton} onPress={() => onApply(role, inactive)} />
        </View>
      }
    >
      <Text style={styles.fieldLabel}>Role</Text>
      <View style={styles.chipWrap}>
        <Chip label="All roles" selected={role == null} onPress={() => setRole(null)} />
        {ALL_USER_ROLES.map((r) => (
          <Chip key={r} label={userRoleDisplayName(r)} selected={role === r} onPress={() => setRole(r)} />
        ))}
      </View>

      <Pressable
        accessibilityRole="checkbox"
        accessibilityState={{ checked: inactive }}
        style={styles.checkboxRow}
        onPress={() => setInactive((prev) => !prev)}
      >
        <View style={[styles.checkbox, inactive && styles.checkboxChecked]}>
          {inactive ? <AppIcon name="check" size={14} color={colors.onPrimary} /> : null}
        </View>
        <Text style={textStyles.bodyMedium}>Show inactive users</Text>
      </Pressable>
    </AppModal>
  );
}

function UserDetailsModal({
  user,
  onClose,
  onEdit,
  onToggleStatus,
  onResetPassword,
  onApproveDriver,
}: {
  user: AppUser;
  onClose: () => void;
  onEdit: () => void;
  onToggleStatus: () => void;
  onResetPassword: () => void;
  onApproveDriver: () => void;
}) {
  const permissions = Array.from(getPermissionsForRole(user.role));

  return (
    <AppModal visible title="User details" onClose={onClose}>
      <ScrollView style={styles.detailsScroll}>
        <DetailRow label="Full name" value={user.fullName} />
        <DetailRow label="Email" value={user.email} />
        <DetailRow label="Phone" value={user.phoneNumber ?? 'Not provided'} />
        <DetailRow label="Role" value={userRoleDisplayName(user.role)} />
        <DetailRow label="Status" value={user.isActive ? 'Active' : 'Inactive'} />
        <DetailRow label="Company ID" value={user.companyId} />

        {user.role === 'driver' ? (
          <>
            <View style={styles.divider} />
            <Text style={textStyles.heading3}>Driver information</Text>
            <DetailRow label="License number" value={user.licenseNumber ?? 'Not provided'} />
            <DetailRow label="Vehicle info" value={user.vehicleInfo ?? 'Not provided'} />
            <DetailRow label="Approval status" value={user.approvalStatus ?? 'Pending'} />
          </>
        ) : null}

        <View style={styles.divider} />
        <Text style={textStyles.heading3}>Permissions</Text>
        <View style={styles.chipWrap}>
          {permissions.map((permission) => (
            <View key={permission} style={styles.permissionChip}>
              <Text style={styles.permissionChipText}>{permissionDisplayName(permission)}</Text>
            </View>
          ))}
        </View>

        <View style={styles.detailActions}>
          <PrimaryButton label="Edit user" icon="edit" onPress={onEdit} />
          <SecondaryButton
            label={user.isActive ? 'Deactivate user' : 'Activate user'}
            icon={user.isActive ? 'lock' : 'check'}
            onPress={onToggleStatus}
          />
          <SecondaryButton label="Reset password" icon="key" onPress={onResetPassword} />
          {user.role === 'driver' && user.approvalStatus !== 'approved' ? (
            <SuccessButton label="Approve driver" icon="check" onPress={onApproveDriver} />
          ) : null}
        </View>
      </ScrollView>
    </AppModal>
  );
}

function EditUserModal({ user, onClose, onSave }: { user: AppUser; onClose: () => void; onSave: (fullName: string, phone: string, role: UserRole) => void }) {
  const [fullName, setFullName] = useState(user.fullName);
  const [phone, setPhone] = useState(user.phoneNumber ?? '');
  const [role, setRole] = useState(user.role);

  return (
    <AppModal
      visible
      title="Edit user"
      onClose={onClose}
      footer={
        <View style={styles.modalActionsRow}>
          <SecondaryButton label="Cancel" style={styles.modalButton} onPress={onClose} />
          <PrimaryButton
            label="Update"
            style={styles.modalButton}
            onPress={() => {
              if (fullName.trim().length === 0) {
                Alert.alert('Missing Information', 'Please enter full name');
                return;
              }
              onSave(fullName.trim(), phone.trim(), role);
            }}
          />
        </View>
      }
    >
      <View style={styles.formFields}>
        <FormField label="Full name" value={fullName} onChangeText={setFullName} />
        <FormField label="Phone" value={phone} onChangeText={setPhone} keyboardType="phone-pad" />
        <View>
          <Text style={styles.fieldLabel}>Role</Text>
          <View style={styles.chipWrap}>
            {ALL_USER_ROLES.map((r) => (
              <Chip key={r} label={userRoleDisplayName(r)} selected={role === r} onPress={() => setRole(r)} />
            ))}
          </View>
        </View>
      </View>
    </AppModal>
  );
}

function CreateUserModal({
  visible,
  companyId,
  onClose,
  onCreate,
}: {
  visible: boolean;
  companyId: string;
  onClose: () => void;
  onCreate: (params: { email: string; password: string; fullName: string; companyId: string; role: UserRole; phoneNumber?: string }) => Promise<void>;
}) {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<UserRole>('driver');
  const [isCreating, setIsCreating] = useState(false);

  const reset = () => {
    setFullName('');
    setEmail('');
    setPhone('');
    setPassword('');
    setRole('driver');
  };

  const handleCreate = async () => {
    if (fullName.trim().length === 0) {
      Alert.alert('Missing Information', 'Please enter full name');
      return;
    }
    if (email.trim().length === 0 || !email.includes('@')) {
      Alert.alert('Missing Information', 'Please enter a valid email');
      return;
    }
    if (password.length < 6) {
      Alert.alert('Missing Information', 'Password must be at least 6 characters');
      return;
    }

    setIsCreating(true);
    try {
      await onCreate({ email: email.trim(), password, fullName: fullName.trim(), companyId, role, phoneNumber: phone.trim() || undefined });
      reset();
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <AppModal
      visible={visible}
      title="Create new user"
      onClose={onClose}
      footer={
        <View style={styles.modalActionsRow}>
          <SecondaryButton label="Cancel" style={styles.modalButton} disabled={isCreating} onPress={onClose} />
          <PrimaryButton label="Create" style={styles.modalButton} loading={isCreating} onPress={handleCreate} />
        </View>
      }
    >
      <ScrollView style={styles.detailsScroll}>
        <View style={styles.formFields}>
          <FormField label="Full name" value={fullName} onChangeText={setFullName} />
          <FormField label="Email" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" />
          <FormField label="Phone (optional)" value={phone} onChangeText={setPhone} keyboardType="phone-pad" />
          <FormField
            label="Initial password"
            helperText="User can change this after first login"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
          />
          <View>
            <Text style={styles.fieldLabel}>Role</Text>
            <View style={styles.chipWrap}>
              {ALL_USER_ROLES.map((r) => (
                <Chip key={r} label={userRoleDisplayName(r)} selected={role === r} onPress={() => setRole(r)} />
              ))}
            </View>
          </View>
        </View>
      </ScrollView>
    </AppModal>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={[textStyles.bodyMedium, styles.detailValue]}>{value}</Text>
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

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.canvas },
  searchRow: { flexDirection: 'row', gap: spacing.small, padding: spacing.medium, alignItems: 'center' },
  searchField: { flex: 1 },
  activeFiltersRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, paddingHorizontal: spacing.medium, marginBottom: spacing.small },
  removableChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small,
    backgroundColor: colors.surfaceMuted,
    borderRadius: radii.inputRadius,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: spacing.xs,
  },
  removableChipText: { ...textStyles.labelSmall, color: colors.contentPrimary },
  listContent: { padding: spacing.medium, paddingBottom: spacing.medium },
  userTile: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small + 4 },
  avatar: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', marginRight: spacing.medium },
  avatarText: { color: colors.onPrimary, fontWeight: '700', fontSize: 18 },
  userTileBody: { flex: 1 },
  inactiveText: { color: colors.contentSecondary },
  badgeRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.small, flexWrap: 'wrap' },
  bottomBar: { padding: spacing.medium, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border },
  fieldLabel: { ...textStyles.label, marginBottom: spacing.small, marginTop: spacing.small },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.inputRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
  chipSelected: { backgroundColor: colors.activeMuted, borderColor: colors.shell },
  chipText: { ...textStyles.bodySmall, color: colors.contentSecondary },
  chipTextSelected: { color: colors.shell, fontWeight: '600' },
  checkboxRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginTop: spacing.medium },
  checkbox: { width: 22, height: 22, borderRadius: 6, borderWidth: 2, borderColor: colors.border, alignItems: 'center', justifyContent: 'center' },
  checkboxChecked: { backgroundColor: colors.shell, borderColor: colors.shell },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium },
  modalButton: { flex: 1 },
  formFields: { gap: spacing.medium },
  detailsScroll: { maxHeight: 420 },
  divider: { height: 1, backgroundColor: colors.border, marginVertical: spacing.medium },
  detailRow: { flexDirection: 'row', marginBottom: spacing.small + 4 },
  detailLabel: { width: 120, ...textStyles.bodySmall, fontWeight: '600', color: colors.contentSecondary },
  detailValue: { flex: 1 },
  detailActions: { gap: spacing.small, marginTop: spacing.large },
  permissionChip: { backgroundColor: colors.surfaceMuted, borderRadius: radii.inputRadius, borderWidth: 1, borderColor: colors.border, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.xs },
  permissionChipText: { ...textStyles.bodySmall, color: colors.contentSecondary },
});
