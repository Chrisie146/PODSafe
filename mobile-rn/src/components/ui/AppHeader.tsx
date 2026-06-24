import React from 'react';
import { StyleProp, StyleSheet, Text, View, ViewStyle } from 'react-native';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { IconButton } from './Buttons';

export interface AppHeaderProps {
  title: string;
  subtitle?: string;
  onBack?: () => void;
  right?: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}

/** A contextual, accessible header for screen-owned navigation. */
export function AppHeader({ title, subtitle, onBack, right, style }: AppHeaderProps) {
  return (
    <View style={[styles.header, style]} accessibilityRole="header">
      {onBack ? <IconButton icon="arrowLeft" accessibilityLabel="Go back" onPress={onBack} /> : null}
      <View style={styles.titleGroup}>
        <Text numberOfLines={1} style={styles.title}>{title}</Text>
        {subtitle ? <Text numberOfLines={1} style={styles.subtitle}>{subtitle}</Text> : null}
      </View>
      {right ? <View style={styles.actions}>{right}</View> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    alignItems: 'center',
    backgroundColor: colors.canvas,
    flexDirection: 'row',
    gap: spacing.small,
    minHeight: 64,
    paddingHorizontal: spacing.medium,
  },
  titleGroup: { flex: 1, minWidth: 0 },
  title: textStyles.heading3,
  subtitle: textStyles.bodySmall,
  actions: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
});
