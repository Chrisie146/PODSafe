import React from 'react';
import {
  Pressable,
  StyleProp,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import { AppIcon, AppIconName, Card, EmptyState } from '../ui';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

export interface AdminMetricCardProps {
  title: string;
  value: number | string;
  description: string;
  icon: AppIconName;
  tone?: 'info' | 'warning' | 'success' | 'error';
  style?: StyleProp<ViewStyle>;
  onPress?: () => void;
}

const metricPalette = {
  info: { color: colors.active, background: colors.activeMuted },
  warning: { color: colors.attention, background: colors.attentionMuted },
  success: { color: colors.verified, background: colors.verifiedMuted },
  error: { color: colors.critical, background: colors.criticalMuted },
} as const;

export function AdminMetricCard({
  title,
  value,
  description,
  icon,
  tone = 'info',
  style,
  onPress,
}: AdminMetricCardProps) {
  const palette = metricPalette[tone];
  const content = (
    <>
      <View style={styles.metricTop}>
        <View
          style={[styles.metricIcon, { backgroundColor: palette.background }]}
        >
          <AppIcon name={icon} size={22} color={palette.color} />
        </View>
        <Text style={styles.metricValue}>{value}</Text>
      </View>
      <Text style={styles.metricTitle}>{title}</Text>
      <Text style={textStyles.bodySmall}>{description}</Text>
    </>
  );
  if (!onPress)
    return <Card style={[styles.metricCard, style]}>{content}</Card>;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${title}: ${value}`}
      onPress={onPress}
      style={({ pressed }) => [
        styles.metricPressable,
        pressed && styles.pressed,
        style,
      ]}
    >
      <Card style={styles.metricCard}>{content}</Card>
    </Pressable>
  );
}

export function AdminSectionHeader({
  title,
  actionLabel,
  onAction,
}: {
  title: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <View style={styles.sectionHeader}>
      <Text style={textStyles.heading3}>{title}</Text>
      {actionLabel && onAction ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={actionLabel}
          onPress={onAction}
          style={({ pressed }) => pressed && styles.pressed}
        >
          <Text style={styles.sectionAction}>{actionLabel}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function AdminDataPanel({
  title,
  message,
  icon = 'clipboard',
  actionLabel,
  onAction,
}: {
  title: string;
  message: string;
  icon?: AppIconName;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <EmptyState
      title={title}
      message={message}
      icon={icon}
      actionLabel={actionLabel}
      onAction={onAction}
    />
  );
}

export function AdminToolbar({
  children,
  style,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return <View style={[styles.toolbar, style]}>{children}</View>;
}

const styles = StyleSheet.create({
  metricPressable: { flexGrow: 1, minWidth: 170 },
  metricCard: { flexGrow: 1, gap: spacing.small, minWidth: 170 },
  metricTop: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  metricIcon: {
    alignItems: 'center',
    borderRadius: radii.cardRadius,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  metricValue: textStyles.heading1,
  metricTitle: textStyles.label,
  sectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionAction: { ...textStyles.label, color: colors.active },
  toolbar: {
    alignItems: 'center',
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.small,
    justifyContent: 'space-between',
  },
  pressed: { opacity: 0.78 },
});
