import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { AppUser, ALL_USER_ROLES, UserRole, userRoleDisplayName } from '../../models/user';
import { getPermissionsForRole } from '../../permissions/permissionService';
import { permissionDisplayName } from '../../permissions/permission';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/user_management_screen.dart (verified against source on
 * 2026-06-22).
 *
 * Deviations from the Flutter source:
 * - Role "dropdowns" use chip selectors (house convention — no picker library, see
 *   MyClaims.tsx's STATUS_CHIPS).
 * - "Add User" calls the Phase 5 `createUser` Cloud Function directly instead of
 *   replicating the Dart source's sign-out/re-authenticate-with-own-password workaround
 *   (`_AdminPasswordDialog` + `createUserAsAdmin`) — see authRepository.ts's class-level
 *   comment. This will surface a real error until Phase 5 deploys that callable, which is
 *   the correct and expected behavior right now, not a bug in this port.
 */
const ROLE_BADGE_COLORS: Record<UserRole, string> = {
  admin: '#E53935',
  manager: '#1E88E5',
  logistics: '#43A047',
  accountant: '#8E24AA',
  filing_clerk: colors.warning,
  driver: '#00897B',
};

export default function UserManagement() {
  const currentUser = useAuthStore((s) => s.currentUser);
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

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Error: No company ID</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.searchRow}>
        <TextInput style={styles.searchInput} placeholder="Search users..." value={searchQuery} onChangeText={setSearchQuery} />
        <Pressable style={styles.filterButton} onPress={() => setShowFilterModal(true)}>
          <Text>🔽</Text>
        </Pressable>
      </View>

      {filterRole || showInactive ? (
        <View style={styles.activeFiltersRow}>
          {filterRole ? (
            <FilterChip label={userRoleDisplayName(filterRole)} onRemove={() => setFilterRole(null)} />
          ) : null}
          {showInactive ? <FilterChip label="Show Inactive" onRemove={() => setShowInactive(false)} /> : null}
        </View>
      ) : null}

      {isLoading && users.length === 0 ? (
        <ActivityIndicator style={styles.loadingIndicator} color={colors.primary} />
      ) : filteredUsers.length === 0 ? (
        <View style={styles.centered}>
          <Text style={textStyles.bodyMedium}>No users found</Text>
        </View>
      ) : (
        <FlatList
          data={filteredUsers}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => <UserListTile user={item} onPress={() => setSelectedUser(item)} />}
        />
      )}

      <Pressable style={styles.fab} onPress={() => setShowCreateModal(true)}>
        <Text style={styles.fabIcon}>👤+</Text>
        <Text style={styles.fabLabel}>Add User</Text>
      </Pressable>

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
  );
}

function FilterChip({ label, onRemove }: { label: string; onRemove: () => void }) {
  return (
    <View style={styles.filterChip}>
      <Text style={styles.filterChipText}>{label}</Text>
      <Pressable onPress={onRemove}>
        <Text style={styles.filterChipRemove}>✕</Text>
      </Pressable>
    </View>
  );
}

function RoleBadge({ role }: { role: UserRole }) {
  const color = ROLE_BADGE_COLORS[role];
  return (
    <View style={[styles.roleBadge, { backgroundColor: color }]}>
      <Text style={styles.roleBadgeText}>{userRoleDisplayName(role).toUpperCase()}</Text>
    </View>
  );
}

function UserListTile({ user, onPress }: { user: AppUser; onPress: () => void }) {
  return (
    <Pressable style={styles.userTile} onPress={onPress}>
      <View style={[styles.avatar, { backgroundColor: user.isActive ? colors.primary : colors.textSecondary }]}>
        <Text style={styles.avatarText}>{user.fullName.charAt(0).toUpperCase() || '?'}</Text>
      </View>
      <View style={styles.userTileBody}>
        <Text style={[textStyles.bodyLarge, !user.isActive && styles.inactiveText]}>{user.fullName}</Text>
        <Text style={textStyles.bodySmall}>{user.email}</Text>
        <View style={styles.badgeRow}>
          <RoleBadge role={user.role} />
          {!user.isActive ? (
            <View style={styles.inactiveBadge}>
              <Text style={styles.inactiveBadgeText}>Inactive</Text>
            </View>
          ) : null}
          {user.role === 'driver' && user.approvalStatus !== 'approved' ? (
            <View style={styles.pendingBadge}>
              <Text style={styles.pendingBadgeText}>{user.approvalStatus ?? 'Pending'}</Text>
            </View>
          ) : null}
        </View>
      </View>
      <Text style={styles.chevron}>›</Text>
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
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Filter Users</Text>

          <Text style={styles.fieldLabel}>Role</Text>
          <View style={styles.chipWrap}>
            <Chip label="All Roles" selected={role == null} onPress={() => setRole(null)} />
            {ALL_USER_ROLES.map((r) => (
              <Chip key={r} label={userRoleDisplayName(r)} selected={role === r} onPress={() => setRole(r)} />
            ))}
          </View>

          <Pressable style={styles.checkboxRow} onPress={() => setInactive((prev) => !prev)}>
            <Text style={styles.checkboxGlyph}>{inactive ? '☑' : '☐'}</Text>
            <Text style={textStyles.bodyMedium}>Show Inactive Users</Text>
          </Pressable>

          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} onPress={onClose}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.modalPrimaryButton} onPress={() => onApply(role, inactive)}>
              <Text style={textStyles.buttonText}>Apply</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
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
    <Modal visible transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.sheetBackdrop}>
        <View style={[styles.sheetCard, shadows.card]}>
          <ScrollView>
            <View style={styles.sheetHeaderRow}>
              <Text style={textStyles.heading2}>User Details</Text>
              <Pressable onPress={onClose}>
                <Text style={styles.closeGlyph}>✕</Text>
              </Pressable>
            </View>
            <View style={styles.divider} />

            <DetailRow label="Full Name" value={user.fullName} />
            <DetailRow label="Email" value={user.email} />
            <DetailRow label="Phone" value={user.phoneNumber ?? 'Not provided'} />
            <DetailRow label="Role" value={userRoleDisplayName(user.role)} />
            <DetailRow label="Status" value={user.isActive ? 'Active' : 'Inactive'} />
            <DetailRow label="Company ID" value={user.companyId} />

            {user.role === 'driver' ? (
              <>
                <View style={styles.divider} />
                <Text style={textStyles.heading3}>Driver Information</Text>
                <DetailRow label="License Number" value={user.licenseNumber ?? 'Not provided'} />
                <DetailRow label="Vehicle Info" value={user.vehicleInfo ?? 'Not provided'} />
                <DetailRow label="Approval Status" value={user.approvalStatus ?? 'Pending'} />
              </>
            ) : null}

            <View style={styles.sectionSpacer} />
            <Text style={textStyles.heading3}>Permissions</Text>
            <View style={styles.chipWrap}>
              {permissions.map((permission) => (
                <View key={permission} style={styles.permissionChip}>
                  <Text style={styles.permissionChipText}>{permissionDisplayName(permission)}</Text>
                </View>
              ))}
            </View>

            <View style={styles.sectionSpacer} />
            <Pressable style={styles.modalPrimaryButton} onPress={onEdit}>
              <Text style={textStyles.buttonText}>✎ Edit User</Text>
            </Pressable>
            <Pressable style={styles.modalOutlinedButton} onPress={onToggleStatus}>
              <Text style={styles.modalOutlinedText}>{user.isActive ? '🚫 Deactivate User' : '✓ Activate User'}</Text>
            </Pressable>
            <Pressable style={styles.modalOutlinedButton} onPress={onResetPassword}>
              <Text style={styles.modalOutlinedText}>🔑 Reset Password</Text>
            </Pressable>
            {user.role === 'driver' && user.approvalStatus !== 'approved' ? (
              <Pressable style={[styles.modalPrimaryButton, styles.approveButton]} onPress={onApproveDriver}>
                <Text style={textStyles.buttonText}>✓ Approve Driver</Text>
              </Pressable>
            ) : null}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

function EditUserModal({ user, onClose, onSave }: { user: AppUser; onClose: () => void; onSave: (fullName: string, phone: string, role: UserRole) => void }) {
  const [fullName, setFullName] = useState(user.fullName);
  const [phone, setPhone] = useState(user.phoneNumber ?? '');
  const [role, setRole] = useState(user.role);

  return (
    <Modal visible transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Edit User</Text>

          <Text style={styles.fieldLabel}>Full Name</Text>
          <TextInput style={styles.input} value={fullName} onChangeText={setFullName} />

          <Text style={styles.fieldLabel}>Phone</Text>
          <TextInput style={styles.input} value={phone} onChangeText={setPhone} keyboardType="phone-pad" />

          <Text style={styles.fieldLabel}>Role</Text>
          <View style={styles.chipWrap}>
            {ALL_USER_ROLES.map((r) => (
              <Chip key={r} label={userRoleDisplayName(r)} selected={role === r} onPress={() => setRole(r)} />
            ))}
          </View>

          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} onPress={onClose}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable
              style={styles.modalPrimaryButton}
              onPress={() => {
                if (fullName.trim().length === 0) {
                  Alert.alert('Missing Information', 'Please enter full name');
                  return;
                }
                onSave(fullName.trim(), phone.trim(), role);
              }}
            >
              <Text style={textStyles.buttonText}>Update</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
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
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <ScrollView style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>Create New User</Text>

          <Text style={styles.fieldLabel}>Full Name</Text>
          <TextInput style={styles.input} value={fullName} onChangeText={setFullName} />

          <Text style={styles.fieldLabel}>Email</Text>
          <TextInput style={styles.input} value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" />

          <Text style={styles.fieldLabel}>Phone (Optional)</Text>
          <TextInput style={styles.input} value={phone} onChangeText={setPhone} keyboardType="phone-pad" />

          <Text style={styles.fieldLabel}>Initial Password</Text>
          <TextInput style={styles.input} value={password} onChangeText={setPassword} secureTextEntry />
          <Text style={styles.helperText}>User can change this after first login</Text>

          <Text style={styles.fieldLabel}>Role</Text>
          <View style={styles.chipWrap}>
            {ALL_USER_ROLES.map((r) => (
              <Chip key={r} label={userRoleDisplayName(r)} selected={role === r} onPress={() => setRole(r)} />
            ))}
          </View>

          <View style={styles.modalActionsRow}>
            <Pressable style={styles.modalSecondaryButton} disabled={isCreating} onPress={onClose}>
              <Text style={styles.modalSecondaryText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.modalPrimaryButton} disabled={isCreating} onPress={handleCreate}>
              {isCreating ? <ActivityIndicator color={colors.white} size="small" /> : <Text style={textStyles.buttonText}>Create</Text>}
            </Pressable>
          </View>
        </ScrollView>
      </View>
    </Modal>
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
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  searchRow: { flexDirection: 'row', gap: spacing.small, padding: spacing.medium, alignItems: 'center' },
  searchInput: { flex: 1, backgroundColor: colors.card, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, padding: spacing.small + 4 },
  filterButton: { padding: spacing.small + 4 },
  activeFiltersRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, paddingHorizontal: spacing.medium, marginBottom: spacing.small },
  filterChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small,
    backgroundColor: colors.divider,
    borderRadius: 16,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: 4,
  },
  filterChipText: { fontSize: 12 },
  filterChipRemove: { fontSize: 12, color: colors.textSecondary },
  loadingIndicator: { marginTop: spacing.xLarge },
  listContent: { padding: spacing.medium, paddingBottom: spacing.xLarge * 2 },
  userTile: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.small + 4 },
  avatar: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', marginRight: spacing.medium },
  avatarText: { color: colors.white, fontWeight: 'bold', fontSize: 18 },
  userTileBody: { flex: 1 },
  inactiveText: { color: colors.textSecondary },
  badgeRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.small, flexWrap: 'wrap' },
  roleBadge: { borderRadius: 10, paddingHorizontal: spacing.small, paddingVertical: 2 },
  roleBadgeText: { color: colors.white, fontSize: 10, fontWeight: 'bold' },
  inactiveBadge: { backgroundColor: colors.textSecondary, borderRadius: 10, paddingHorizontal: spacing.small, paddingVertical: 2 },
  inactiveBadgeText: { color: colors.white, fontSize: 10 },
  pendingBadge: { backgroundColor: colors.warning, borderRadius: 10, paddingHorizontal: spacing.small, paddingVertical: 2 },
  pendingBadgeText: { color: colors.white, fontSize: 10 },
  chevron: { fontSize: 20, color: colors.textSecondary },
  fab: {
    position: 'absolute',
    right: spacing.large,
    bottom: spacing.large,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.small,
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 4,
    ...shadows.button,
  },
  fabIcon: { color: colors.white, fontSize: 16 },
  fabLabel: { color: colors.white, fontWeight: '600' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '85%' },
  fieldLabel: { fontWeight: '600', marginTop: spacing.medium, marginBottom: spacing.small },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  helperText: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: 6, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  checkboxRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginTop: spacing.medium },
  checkboxGlyph: { fontSize: 20, color: colors.primary },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalSecondaryButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius, borderWidth: 1, borderColor: colors.divider },
  modalSecondaryText: { color: colors.textSecondary, fontWeight: '600' },
  modalPrimaryButton: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedButton: { alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4, marginTop: spacing.small },
  modalOutlinedText: { color: colors.textPrimary, fontWeight: '600' },
  approveButton: { backgroundColor: colors.success },
  sheetBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  sheetCard: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.large, maxHeight: '90%' },
  sheetHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  detailRow: { flexDirection: 'row', marginBottom: spacing.small + 4 },
  detailLabel: { width: 120, fontWeight: '600', color: colors.textSecondary },
  detailValue: { flex: 1 },
  sectionSpacer: { height: spacing.medium },
  permissionChip: { backgroundColor: colors.background, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, paddingHorizontal: spacing.small + 4, paddingVertical: 4 },
  permissionChipText: { fontSize: 11, color: colors.textSecondary },
});
