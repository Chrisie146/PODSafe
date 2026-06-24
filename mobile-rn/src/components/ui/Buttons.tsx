import React, { useState } from 'react';
import { ActivityIndicator, GestureResponderEvent, Pressable, StyleProp, StyleSheet, Text, TextStyle, ViewStyle } from 'react-native';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { AppIcon, AppIconName } from './AppIcon';

type ButtonVariant = 'primary' | 'secondary' | 'success' | 'danger';

export interface ButtonProps {
  label: string;
  onPress?: (event: GestureResponderEvent) => void;
  disabled?: boolean;
  loading?: boolean;
  icon?: AppIconName;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
  testID?: string;
}

function Button({
  label,
  onPress,
  disabled = false,
  loading = false,
  icon,
  accessibilityLabel,
  style,
  textStyle,
  testID,
  variant,
}: ButtonProps & { variant: ButtonVariant }) {
  const [isFocused, setIsFocused] = useState(false);
  const isDisabled = disabled || loading;
  const palette = variantStyles[variant];
  const variantColor = variantColors[variant];

  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityState={{ disabled: isDisabled, busy: loading }}
      disabled={isDisabled}
      onBlur={() => setIsFocused(false)}
      onFocus={() => setIsFocused(true)}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        palette.container,
        isFocused && styles.focused,
        pressed && !isDisabled && styles.pressed,
        isDisabled && styles.disabled,
        style,
      ]}
    >
      {loading ? <ActivityIndicator color={variantColor.indicator} size="small" /> : null}
      {!loading && icon ? <AppIcon name={icon} size={20} color={variantColor.icon} /> : null}
      <Text style={[styles.label, palette.label, isDisabled && styles.disabledLabel, textStyle]}>{label}</Text>
    </Pressable>
  );
}

export function PrimaryButton(props: ButtonProps) {
  return <Button {...props} variant="primary" />;
}

export function SecondaryButton(props: ButtonProps) {
  return <Button {...props} variant="secondary" />;
}

export function SuccessButton(props: ButtonProps) {
  return <Button {...props} variant="success" />;
}

export function DangerButton(props: ButtonProps) {
  return <Button {...props} variant="danger" />;
}

export interface IconButtonProps {
  icon: AppIconName;
  accessibilityLabel: string;
  onPress?: (event: GestureResponderEvent) => void;
  disabled?: boolean;
  color?: string;
  style?: StyleProp<ViewStyle>;
  testID?: string;
}

export function IconButton({ icon, accessibilityLabel, onPress, disabled = false, color = colors.contentPrimary, style, testID }: IconButtonProps) {
  const [isFocused, setIsFocused] = useState(false);

  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ disabled }}
      disabled={disabled}
      hitSlop={8}
      onBlur={() => setIsFocused(false)}
      onFocus={() => setIsFocused(true)}
      onPress={onPress}
      style={({ pressed }) => [
        styles.iconButton,
        isFocused && styles.focused,
        pressed && !disabled && styles.iconPressed,
        disabled && styles.disabled,
        style,
      ]}
    >
      <AppIcon name={icon} size={24} color={disabled ? colors.disabledContent : color} />
    </Pressable>
  );
}

const variantStyles = {
  primary: StyleSheet.create({
    container: { backgroundColor: colors.shell },
    label: { color: colors.onPrimary },
  }),
  secondary: StyleSheet.create({
    container: { backgroundColor: colors.surface, borderColor: colors.shell, borderWidth: 1 },
    label: { color: colors.shell },
  }),
  success: StyleSheet.create({
    container: { backgroundColor: colors.verified },
    label: { color: colors.shell },
  }),
  danger: StyleSheet.create({
    container: { backgroundColor: colors.critical },
    label: { color: colors.onPrimary },
  }),
} as const;

const variantColors: Record<ButtonVariant, { icon: string; indicator: string }> = {
  primary: { icon: colors.onPrimary, indicator: colors.onPrimary },
  secondary: { icon: colors.shell, indicator: colors.shell },
  success: { icon: colors.shell, indicator: colors.shell },
  danger: { icon: colors.onPrimary, indicator: colors.onPrimary },
};

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    borderRadius: radii.buttonRadius,
    flexDirection: 'row',
    gap: spacing.small,
    justifyContent: 'center',
    minHeight: 48,
    paddingHorizontal: spacing.medium,
  },
  label: { ...textStyles.buttonText, textAlign: 'center' },
  focused: { borderColor: colors.focus, borderWidth: 2 },
  pressed: { opacity: 0.84 },
  disabled: { backgroundColor: colors.disabled, borderColor: colors.disabled, opacity: 1 },
  disabledLabel: { color: colors.disabledContent },
  iconButton: {
    alignItems: 'center',
    borderRadius: radii.buttonRadius,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  iconPressed: { backgroundColor: colors.surfaceMuted },
});
