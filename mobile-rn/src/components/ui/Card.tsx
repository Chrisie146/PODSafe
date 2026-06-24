import React from 'react';
import { StyleProp, StyleSheet, View, ViewProps, ViewStyle } from 'react-native';
import { colors, radii, spacing } from '../../theme/tokens';

export interface CardProps extends ViewProps {
  children: React.ReactNode;
  padding?: 'none' | 'compact' | 'regular' | 'spacious';
  style?: StyleProp<ViewStyle>;
}

export function Card({ children, padding = 'regular', style, ...props }: CardProps) {
  return <View {...props} style={[styles.card, paddingStyles[padding], style]}>{children}</View>;
}

const paddingStyles = StyleSheet.create({
  none: { padding: 0 },
  compact: { padding: spacing.small },
  regular: { padding: spacing.medium },
  spacious: { padding: spacing.large },
});

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.cardRadius,
    borderWidth: StyleSheet.hairlineWidth,
  },
});
