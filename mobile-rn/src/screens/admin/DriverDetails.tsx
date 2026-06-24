import React, { useEffect, useMemo, useState } from 'react';
import { Alert, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  AppHeader,
  AppIcon,
  AppIconName,
  AppModal,
  Card,
  DangerButton,
  ErrorState,
  IconButton,
  LoadingState,
  Screen,
  SecondaryButton,
  StatusChip,
  SuccessButton,
} from '../../components/ui';
import { Delivery, DeliveryStatus } from '../../models/delivery';
import { AppUser, ApprovalStatus } from '../../models/user';
import { DeliveryRepository } from '../../repositories/deliveryRepository';
import { useUserManagementStore } from '../../stores/useUserManagementStore';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

interface DriverDetailsProps {
  route: { params: { driverId: string } };
  navigation: {
    navigate: (screen: string, params?: Record<string, unknown>) => void;
    goBack: () => void;
  };
}

const deliveryRepository = new DeliveryRepository();

function initials(name: string) {
  const parts = name.trim().split(' ').filter(Boolean);
  return parts.length < 2
    ? parts[0]?.[0]?.toUpperCase() ?? '?'
    : `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

function deliveryPresentation(status: DeliveryStatus): {
  label: string;
  tone: 'info' | 'success' | 'warning' | 'error';
  icon: AppIconName;
} {
  if (status === 'pending')
    return { label: 'Pending', tone: 'warning', icon: 'calendar' };
  if (status === 'inTransit')
    return { label: 'In transit', tone: 'info', icon: 'truck' };
  if (status === 'delivered')
    return { label: 'Delivered', tone: 'success', icon: 'check' };
  return { label: 'Failed', tone: 'error', icon: 'alert' };
}

function approvalPresentation(status?: ApprovalStatus): {
  label: string;
  tone: 'success' | 'warning' | 'error';
} {
  if (status === 'approved') return { label: 'Approved', tone: 'success' };
  if (status === 'pending')
    return { label: 'Pending approval', tone: 'warning' };
  return { label: 'Rejected', tone: 'error' };
}

function formatDate(date: Date) {
  return date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export default function DriverDetails({
  route,
  navigation,
}: DriverDetailsProps) {
  const { driverId } = route.params;
  const selectedUser = useUserManagementStore(state => state.selectedUser);
  const isLoading = useUserManagementStore(state => state.isLoading);
  const errorMessage = useUserManagementStore(state => state.errorMessage);
  const loadUserById = useUserManagementStore(state => state.loadUserById);
  const updateUser = useUserManagementStore(state => state.updateUser);
  const deleteUser = useUserManagementStore(state => state.deleteUser);
  const [deliveries, setDeliveries] = useState<Delivery[] | null>(null);
  const [actionsOpen, setActionsOpen] = useState(false);

  useEffect(() => {
    loadUserById(driverId);
  }, [driverId, loadUserById]);
  useEffect(
    () =>
      deliveryRepository.subscribeToDeliveriesForDriver(
        driverId,
        setDeliveries,
        () => setDeliveries([]),
      ),
    [driverId],
  );

  const driver = selectedUser?.id === driverId ? selectedUser : null;
  const stats = useMemo(
    () =>
      deliveries
        ? {
            total: deliveries.length,
            active: deliveries.filter(
              delivery => delivery.status === 'inTransit',
            ).length,
            completed: deliveries.filter(
              delivery => delivery.status === 'delivered',
            ).length,
          }
        : null,
    [deliveries],
  );

  const updateDriver = async (
    next: AppUser,
    successTitle: string,
    successMessage: string,
  ) => {
    try {
      await updateUser(next);
      Alert.alert(successTitle, successMessage);
      navigation.goBack();
    } catch (error) {
      Alert.alert('Unable to update driver', (error as Error).message);
    }
  };

  const confirm = (
    title: string,
    message: string,
    actionLabel: string,
    action: () => Promise<void>,
    destructive = false,
  ) => {
    setActionsOpen(false);
    Alert.alert(title, message, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: actionLabel,
        style: destructive ? 'destructive' : 'default',
        onPress: action,
      },
    ]);
  };

  if (isLoading)
    return (
      <Screen>
        <LoadingState
          title="Loading driver details"
          message="Retrieving the driver account."
        />
      </Screen>
    );
  if (!driver)
    return (
      <Screen>
        <AppHeader title="Driver details" onBack={navigation.goBack} />
        <ErrorState
          title="Driver unavailable"
          message={errorMessage ?? 'The requested driver could not be found.'}
          onAction={() => loadUserById(driverId)}
        />
      </Screen>
    );

  const approval = approvalPresentation(driver.approvalStatus);
  const recentDeliveries = deliveries?.slice(0, 5) ?? [];
  const activeLabel = driver.isActive ? 'Active' : 'Inactive';

  return (
    <Screen style={styles.screen} contentContainerStyle={styles.screenContent}>
      <AppHeader
        title="Driver details"
        subtitle={driver.email}
        onBack={navigation.goBack}
        right={
          <>
            <IconButton
              icon="edit"
              accessibilityLabel="Edit driver"
              onPress={() => navigation.navigate('CreateDriver', { driverId })}
            />
            <IconButton
              icon="more"
              accessibilityLabel="More driver actions"
              onPress={() => setActionsOpen(true)}
            />
          </>
        }
      />
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <Card style={styles.profileCard}>
          <View
            style={[
              styles.avatar,
              {
                backgroundColor: driver.isActive
                  ? colors.verifiedMuted
                  : colors.surfaceMuted,
              },
            ]}
          >
            <Text
              style={[
                textStyles.heading2,
                {
                  color: driver.isActive
                    ? colors.verified
                    : colors.contentSecondary,
                },
              ]}
            >
              {initials(driver.fullName)}
            </Text>
          </View>
          <Text style={textStyles.heading2}>{driver.fullName}</Text>
          <View style={styles.chips}>
            <StatusChip
              label={activeLabel}
              tone={driver.isActive ? 'success' : 'neutral'}
              icon={driver.isActive ? 'check' : 'alert'}
            />
            <StatusChip label={approval.label} tone={approval.tone} />
          </View>
        </Card>

        <Section title="Performance">
          <View style={styles.metrics}>
            {stats ? (
              <>
                <Metric
                  label="Deliveries"
                  value={stats.total}
                  icon="truck"
                  tone="info"
                />
                <Metric
                  label="In transit"
                  value={stats.active}
                  icon="activity"
                  tone="warning"
                />
                <Metric
                  label="Completed"
                  value={stats.completed}
                  icon="check"
                  tone="success"
                />
              </>
            ) : (
              <LoadingState
                title="Loading performance"
                message="Calculating current delivery activity."
              />
            )}
          </View>
        </Section>

        <Section title="Contact information">
          <InfoCard
            rows={[
              { label: 'Email', value: driver.email, icon: 'message' },
              ...(driver.phoneNumber
                ? [
                    {
                      label: 'Phone',
                      value: driver.phoneNumber,
                      icon: 'phone' as AppIconName,
                    },
                  ]
                : []),
            ]}
          />
        </Section>
        {driver.licenseNumber || driver.vehicleInfo ? (
          <Section title="Driver information">
            <InfoCard
              rows={[
                ...(driver.licenseNumber
                  ? [
                      {
                        label: 'License number',
                        value: driver.licenseNumber,
                        icon: 'shield' as AppIconName,
                      },
                    ]
                  : []),
                ...(driver.vehicleInfo
                  ? [
                      {
                        label: 'Vehicle',
                        value: driver.vehicleInfo,
                        icon: 'vehicle' as AppIconName,
                      },
                    ]
                  : []),
              ]}
            />
          </Section>
        ) : null}
        <Section title="Account information">
          <InfoCard
            rows={[
              {
                label: 'Driver ID',
                value: driver.id.substring(0, 12),
                icon: 'key',
              },
              {
                label: 'Joined',
                value: formatDate(driver.createdAt),
                icon: 'calendar',
              },
            ]}
          />
        </Section>
        <Section title="Recent deliveries">
          {deliveries === null ? (
            <LoadingState
              title="Loading deliveries"
              message="Retrieving this driver’s recent work."
            />
          ) : recentDeliveries.length === 0 ? (
            <Card>
              <View style={styles.noDelivery}>
                <AppIcon
                  name="truck"
                  size={30}
                  color={colors.contentSecondary}
                />
                <Text style={textStyles.bodyMedium}>
                  No deliveries assigned yet.
                </Text>
              </View>
            </Card>
          ) : (
            <View style={styles.deliveryList}>
              {recentDeliveries.map(delivery => (
                <DeliveryRow key={delivery.id} delivery={delivery} />
              ))}
            </View>
          )}
        </Section>
      </ScrollView>

      <AppModal
        visible={actionsOpen}
        title="Driver actions"
        onClose={() => setActionsOpen(false)}
      >
        <View style={styles.modalActions}>
          {driver.approvalStatus === 'pending' ? (
            <>
              <SuccessButton
                label="Approve driver"
                icon="check"
                onPress={() =>
                  confirm(
                    'Approve driver',
                    `${driver.fullName} will be able to receive deliveries.`,
                    'Approve',
                    () =>
                      updateDriver(
                        { ...driver, approvalStatus: 'approved' },
                        'Driver approved',
                        `${driver.fullName} can now receive deliveries.`,
                      ),
                  )
                }
              />
              <DangerButton
                label="Reject driver"
                icon="alert"
                onPress={() =>
                  confirm(
                    'Reject driver',
                    `${driver.fullName} will not be able to receive deliveries.`,
                    'Reject',
                    () =>
                      updateDriver(
                        { ...driver, approvalStatus: 'rejected' },
                        'Driver rejected',
                        `${driver.fullName} has been rejected.`,
                      ),
                    true,
                  )
                }
              />
            </>
          ) : null}
          <SecondaryButton
            label={driver.isActive ? 'Deactivate driver' : 'Activate driver'}
            icon={driver.isActive ? 'alert' : 'check'}
            onPress={() =>
              confirm(
                driver.isActive ? 'Deactivate driver' : 'Activate driver',
                driver.isActive
                  ? 'This driver will no longer receive new deliveries.'
                  : 'This driver will be able to receive new deliveries.',
                driver.isActive ? 'Deactivate' : 'Activate',
                () =>
                  updateDriver(
                    { ...driver, isActive: !driver.isActive },
                    driver.isActive ? 'Driver deactivated' : 'Driver activated',
                    `${driver.fullName}'s account has been updated.`,
                  ),
              )
            }
          />
          <DangerButton
            label="Delete driver"
            icon="trash"
            onPress={() =>
              confirm(
                'Delete driver',
                'This cannot be undone. Delivery history may be affected.',
                'Delete',
                async () => {
                  await deleteUser(driverId);
                  Alert.alert(
                    'Driver deleted',
                    `${driver.fullName} has been deleted.`,
                  );
                  navigation.goBack();
                },
                true,
              )
            }
          />
        </View>
      </AppModal>
    </Screen>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.section}>
      <Text style={textStyles.heading3}>{title}</Text>
      {children}
    </View>
  );
}
function Metric({
  label,
  value,
  icon,
  tone,
}: {
  label: string;
  value: number;
  icon: AppIconName;
  tone: 'info' | 'success' | 'warning';
}) {
  const color =
    tone === 'success'
      ? colors.verified
      : tone === 'warning'
      ? colors.attention
      : colors.active;
  return (
    <Card style={styles.metric}>
      <AppIcon name={icon} size={20} color={color} />
      <Text style={[textStyles.heading2, { color }]}>{value}</Text>
      <Text style={[textStyles.labelSmall, styles.metricLabel]}>{label}</Text>
    </Card>
  );
}
function InfoCard({
  rows,
}: {
  rows: Array<{ label: string; value: string; icon: AppIconName }>;
}) {
  return (
    <Card style={styles.infoCard}>
      {rows.map(row => (
        <View key={row.label} style={styles.infoRow}>
          <AppIcon name={row.icon} size={18} color={colors.contentSecondary} />
          <View style={styles.infoCopy}>
            <Text style={textStyles.labelSmall}>{row.label}</Text>
            <Text selectable style={textStyles.bodyMedium}>
              {row.value}
            </Text>
          </View>
        </View>
      ))}
    </Card>
  );
}
function DeliveryRow({ delivery }: { delivery: Delivery }) {
  const presentation = deliveryPresentation(delivery.status);
  return (
    <Card style={styles.deliveryRow}>
      <AppIcon
        name={presentation.icon}
        size={20}
        color={
          presentation.tone === 'success'
            ? colors.verified
            : presentation.tone === 'warning'
            ? colors.attention
            : presentation.tone === 'error'
            ? colors.critical
            : colors.active
        }
      />
      <View style={styles.infoCopy}>
        <Text numberOfLines={1} style={textStyles.label}>
          {delivery.orderNumber
            ? `${delivery.orderNumber} / ${delivery.customerName}`
            : delivery.customerName}
        </Text>
        <Text style={textStyles.bodySmall}>
          {formatDate(delivery.scheduledDate)}
        </Text>
      </View>
      <StatusChip
        label={presentation.label}
        tone={presentation.tone}
        icon={presentation.icon}
      />
    </Card>
  );
}

const styles = StyleSheet.create({
  screen: { backgroundColor: colors.canvas },
  screenContent: { flex: 1, paddingHorizontal: 0 },
  content: {
    gap: spacing.large,
    padding: spacing.medium,
    paddingBottom: spacing.xxLarge,
  },
  profileCard: {
    alignItems: 'center',
    gap: spacing.small,
    paddingVertical: spacing.large,
  },
  avatar: {
    alignItems: 'center',
    borderRadius: 40,
    height: 80,
    justifyContent: 'center',
    width: 80,
  },
  chips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.small,
    justifyContent: 'center',
  },
  section: { gap: spacing.small },
  metrics: { flexDirection: 'row', gap: spacing.small },
  metric: {
    alignItems: 'center',
    flex: 1,
    gap: spacing.xs,
    padding: spacing.small,
  },
  metricLabel: { textAlign: 'center' },
  infoCard: { gap: 0 },
  infoRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.small,
    paddingVertical: spacing.small,
  },
  infoCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  noDelivery: {
    alignItems: 'center',
    gap: spacing.small,
    padding: spacing.medium,
  },
  deliveryList: { gap: spacing.small },
  deliveryRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
  },
  modalActions: { gap: spacing.small },
});
