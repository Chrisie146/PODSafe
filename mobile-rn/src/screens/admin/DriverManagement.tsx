import React, { useEffect, useState } from 'react';
import {
  Alert,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { AdminShell } from '../../components/admin/AdminShell';
import {
  AppIcon,
  AppIconName,
  Card,
  EmptyState,
  LoadingState,
  PrimaryButton,
  SearchField,
  SecondaryButton,
  StatusChip,
  SuccessButton,
} from '../../components/ui';
import { AppUser, ApprovalStatus } from '../../models/user';
import { AuthRepository } from '../../repositories/authRepository';
import { useAuthStore } from '../../stores/useAuthStore';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const TABS: Array<{ key: ApprovalStatus; label: string; icon: AppIconName }> = [
  { key: 'approved', label: 'Approved', icon: 'check' },
  { key: 'pending', label: 'Pending', icon: 'activity' },
  { key: 'rejected', label: 'Rejected', icon: 'alert' },
];

const authRepository = new AuthRepository();

interface DriverManagementProps {
  navigation: {
    navigate: (screen: string, params?: Record<string, unknown>) => void;
    goBack: () => void;
  };
}

function initials(name: string): string {
  const parts = name.trim().split(' ').filter(Boolean);
  return parts.length < 2
    ? parts[0]?.[0]?.toUpperCase() ?? '?'
    : `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

function tone(status: ApprovalStatus): 'success' | 'warning' | 'error' {
  return status === 'approved'
    ? 'success'
    : status === 'pending'
    ? 'warning'
    : 'error';
}

function relativeDate(date: Date): string {
  const days = Math.floor((Date.now() - date.getTime()) / 86400000);
  if (days === 0) return 'Registered today';
  if (days === 1) return 'Registered yesterday';
  if (days < 7) return `Registered ${days} days ago`;
  return `Registered ${date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })}`;
}

export default function DriverManagement({
  navigation,
}: DriverManagementProps) {
  const currentUser = useAuthStore(state => state.currentUser);
  const signOut = useAuthStore(state => state.signOut);
  const updateUser = useUserManagementStore(state => state.updateUser);

  const handleSignOut = () => {
    Alert.alert('Sign out', 'Sign out of this administration workspace?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };
  const [activeTab, setActiveTab] = useState<ApprovalStatus>('approved');
  const [searchQuery, setSearchQuery] = useState('');
  const [driversByStatus, setDriversByStatus] = useState<
    Record<ApprovalStatus, AppUser[] | null>
  >({ approved: null, pending: null, rejected: null });

  useEffect(() => {
    if (!currentUser) return;
    const unsubscribes = TABS.map(({ key }) =>
      authRepository.subscribeToUsersByCompany(
        currentUser.companyId,
        users =>
          setDriversByStatus(previous => ({ ...previous, [key]: users })),
        () => setDriversByStatus(previous => ({ ...previous, [key]: [] })),
        { role: 'driver', approvalStatus: key, orderByCreatedAtDesc: true },
      ),
    );
    return () => unsubscribes.forEach(unsubscribe => unsubscribe());
  }, [currentUser]);

  const approve = async (driver: AppUser) => {
    if (!currentUser) return;
    try {
      await updateUser({
        ...driver,
        approvalStatus: 'approved',
        isActive: true,
        approvedBy: currentUser.id,
        approvedAt: new Date(),
      });
      Alert.alert(
        'Driver approved',
        `${driver.fullName} can now access delivery work.`,
      );
    } catch (error) {
      Alert.alert('Unable to approve driver', (error as Error).message);
    }
  };

  const reject = (driver: AppUser) =>
    Alert.alert(
      'Reject driver',
      `Reject ${driver.fullName}'s driver approval?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Reject',
          style: 'destructive',
          onPress: async () => {
            if (!currentUser) return;
            try {
              await updateUser({
                ...driver,
                approvalStatus: 'rejected',
                isActive: false,
                approvedBy: currentUser.id,
                approvedAt: new Date(),
              });
              Alert.alert(
                'Driver rejected',
                `${driver.fullName} has been notified.`,
              );
            } catch (error) {
              Alert.alert('Unable to reject driver', (error as Error).message);
            }
          },
        },
      ],
    );

  const drivers = driversByStatus[activeTab];
  const query = searchQuery.trim().toLowerCase();
  const filteredDrivers =
    drivers?.filter(
      driver =>
        !query ||
        `${driver.fullName} ${driver.email} ${driver.phoneNumber ?? ''}`
          .toLowerCase()
          .includes(query),
    ) ?? null;
  const emptyTitle = query
    ? 'No matching drivers'
    : activeTab === 'approved'
    ? 'No approved drivers'
    : activeTab === 'pending'
    ? 'No pending approvals'
    : 'No rejected drivers';

  return (
    <AdminShell
      activeNav="drivers"
      title="Drivers"
      userName={currentUser?.fullName}
      onNavigate={screen => navigation.navigate(screen)}
      onLogout={handleSignOut}
    >
      <View style={styles.body}>
        <View style={styles.intro}>
          <View>
            <Text style={textStyles.heading2}>Driver management</Text>
            <Text style={textStyles.bodySmall}>
              Review driver accounts and approve delivery access.
            </Text>
          </View>
          <StatusChip
            label={`${drivers?.length ?? 0} ${activeTab}`}
            tone={tone(activeTab)}
            icon={TABS.find(tab => tab.key === activeTab)?.icon}
          />
        </View>
        <View accessibilityRole="tablist" style={styles.tabs}>
          {TABS.map(tab => (
            <Pressable
              key={tab.key}
              accessibilityRole="tab"
              accessibilityLabel={`${tab.label} drivers`}
              accessibilityState={{ selected: activeTab === tab.key }}
              onPress={() => setActiveTab(tab.key)}
              style={[styles.tab, activeTab === tab.key && styles.tabActive]}
            >
              <AppIcon
                name={tab.icon}
                size={18}
                color={
                  activeTab === tab.key
                    ? colors.onPrimary
                    : colors.contentSecondary
                }
              />
              <Text
                style={[
                  textStyles.labelSmall,
                  activeTab === tab.key && styles.tabActiveText,
                ]}
              >
                {tab.label}
              </Text>
            </Pressable>
          ))}
        </View>
        <SearchField
          accessibilityLabel="Search drivers"
          placeholder="Search by name or email"
          value={searchQuery}
          onChangeText={setSearchQuery}
          containerStyle={styles.search}
        />
        <View style={styles.listArea}>
          {filteredDrivers === null ? (
            <LoadingState
              title="Loading drivers"
              message="Retrieving driver accounts."
            />
          ) : filteredDrivers.length === 0 ? (
            <EmptyState
              title={emptyTitle}
              message={
                query
                  ? 'Try a different name or email address.'
                  : activeTab === 'approved'
                  ? 'Approve a pending driver or add a new driver to begin.'
                  : 'Driver accounts matching this status will appear here.'
              }
              icon="users"
            />
          ) : (
            <FlatList
              data={filteredDrivers}
              keyExtractor={driver => driver.id}
              contentContainerStyle={styles.list}
              renderItem={({ item }) => (
                <DriverCard
                  driver={item}
                  onPress={() =>
                    navigation.navigate('DriverDetails', { driverId: item.id })
                  }
                  onApprove={() => approve(item)}
                  onReject={() => reject(item)}
                />
              )}
            />
          )}
        </View>
        <PrimaryButton
          label="Add driver"
          icon="plus"
          style={styles.addDriver}
          onPress={() => navigation.navigate('CreateDriver')}
        />
      </View>
    </AdminShell>
  );
}

function DriverCard({
  driver,
  onPress,
  onApprove,
  onReject,
}: {
  driver: AppUser;
  onPress: () => void;
  onApprove: () => void;
  onReject: () => void;
}) {
  const status = driver.approvalStatus ?? 'approved';
  const statusTone = tone(status);
  const avatarColor =
    statusTone === 'success'
      ? colors.verified
      : statusTone === 'warning'
      ? colors.attention
      : colors.critical;
  return (
    <Card padding="none" style={styles.driverCard}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Open ${driver.fullName}`}
        onPress={onPress}
        style={styles.driverMain}
      >
        <View style={[styles.avatar, { backgroundColor: `${avatarColor}22` }]}>
          <Text style={[textStyles.label, { color: avatarColor }]}>
            {initials(driver.fullName)}
          </Text>
        </View>
        <View style={styles.driverCopy}>
          <View style={styles.driverTitle}>
            <Text numberOfLines={1} style={textStyles.label}>
              {driver.fullName}
            </Text>
            <StatusChip label={status} tone={statusTone} />
          </View>
          <Detail icon="message" value={driver.email} />
          <Detail icon="phone" value={driver.phoneNumber} />
          <Detail icon="vehicle" value={driver.vehicleInfo} />
          <Text style={textStyles.bodySmall}>
            {relativeDate(driver.createdAt)}
          </Text>
        </View>
        <AppIcon
          name="chevronRight"
          size={20}
          color={colors.contentSecondary}
        />
      </Pressable>
      {status === 'pending' ? (
        <View style={styles.driverActions}>
          <SecondaryButton
            label="Reject"
            icon="alert"
            style={styles.actionButton}
            onPress={onReject}
          />
          <SuccessButton
            label="Approve"
            icon="check"
            style={styles.actionButton}
            onPress={onApprove}
          />
        </View>
      ) : null}
    </Card>
  );
}

function Detail({
  icon,
  value,
}: {
  icon: 'message' | 'phone' | 'vehicle';
  value?: string;
}) {
  return value ? (
    <View style={styles.detail}>
      <AppIcon name={icon} size={15} color={colors.contentSecondary} />
      <Text numberOfLines={1} style={textStyles.bodySmall}>
        {value}
      </Text>
    </View>
  ) : null;
}

const styles = StyleSheet.create({
  body: { flex: 1, padding: spacing.medium },
  intro: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.small,
    justifyContent: 'space-between',
    marginBottom: spacing.large,
  },
  tabs: { flexDirection: 'row', gap: spacing.xs, marginBottom: spacing.medium },
  tab: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    flex: 1,
    flexDirection: 'row',
    gap: spacing.xs,
    justifyContent: 'center',
    minHeight: 48,
    paddingHorizontal: spacing.xs,
  },
  tabActive: { backgroundColor: colors.shell, borderColor: colors.shell },
  tabActiveText: { color: colors.onPrimary },
  search: { marginBottom: spacing.medium },
  listArea: { flex: 1 },
  list: { gap: spacing.small, paddingBottom: 76 },
  driverCard: { overflow: 'hidden' },
  driverMain: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
    padding: spacing.medium,
  },
  avatar: {
    alignItems: 'center',
    borderRadius: 24,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  driverCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  driverTitle: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
    justifyContent: 'space-between',
  },
  detail: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  driverActions: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.small,
    padding: spacing.small,
  },
  actionButton: { flex: 1 },
  addDriver: {
    bottom: spacing.medium,
    position: 'absolute',
    right: spacing.medium,
  },
});
