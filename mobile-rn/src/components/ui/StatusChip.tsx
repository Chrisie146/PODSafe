import React from 'react';
import { StyleProp, StyleSheet, Text, View, ViewStyle } from 'react-native';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { AppIcon, AppIconName } from './AppIcon';

export type StatusChipTone = 'neutral' | 'info' | 'success' | 'warning' | 'error';

export interface StatusChipProps {
  label: string;
  tone?: StatusChipTone;
  icon?: AppIconName;
  style?: StyleProp<ViewStyle>;
}

export function StatusChip({ label, tone = 'neutral', icon, style }: StatusChipProps) {
  const palette = palettes[tone];
  return (
    <View accessible accessibilityLabel={`Status: ${label}`} style={[styles.chip, palette.container, style]}>
      {icon ? <AppIcon name={icon} size={16} color={palette.content} /> : null}
      <Text style={[styles.label, { color: palette.content }]}>{label}</Text>
    </View>
  );
}

const palettes = {
  neutral: { container: { backgroundColor: colors.surfaceMuted }, content: colors.contentSecondary },
  info: { container: { backgroundColor: colors.activeMuted }, content: colors.shell },
  success: { container: { backgroundColor: colors.verifiedMuted }, content: colors.shell },
  warning: { container: { backgroundColor: colors.attentionMuted }, content: colors.contentPrimary },
  error: { container: { backgroundColor: colors.criticalMuted }, content: colors.critical },
} as const;

const styles = StyleSheet.create({
  chip: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderRadius: radii.inputRadius,
    flexDirection: 'row',
    gap: spacing.xs,
    minHeight: 28,
    paddingHorizontal: spacing.small,
    paddingVertical: spacing.xs,
  },
  label: { ...textStyles.labelSmall },
});
