import React, { useState } from 'react';
import { StyleProp, StyleSheet, Text, TextInput, TextInputProps, TextStyle, View, ViewStyle } from 'react-native';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

export interface FormFieldProps extends TextInputProps {
  label: string;
  helperText?: string;
  error?: string;
  containerStyle?: StyleProp<ViewStyle>;
  inputStyle?: StyleProp<TextStyle>;
  rightAccessory?: React.ReactNode;
}

export function FormField({ label, helperText, error, containerStyle, inputStyle, rightAccessory, editable = true, ...inputProps }: FormFieldProps) {
  const [isFocused, setIsFocused] = useState(false);
  const message = error ?? helperText;

  return (
    <View style={[styles.container, containerStyle]}>
      <Text style={styles.label}>{label}</Text>
      <View style={[styles.inputWrap, isFocused && styles.focused, Boolean(error) && styles.errorBorder, !editable && styles.disabled]}>
        <TextInput
          {...inputProps}
          editable={editable}
          accessibilityLabel={inputProps.accessibilityLabel ?? label}
          placeholderTextColor={colors.contentSecondary}
          style={[styles.input, inputStyle]}
          onBlur={(event) => {
            setIsFocused(false);
            inputProps.onBlur?.(event);
          }}
          onFocus={(event) => {
            setIsFocused(true);
            inputProps.onFocus?.(event);
          }}
        />
        {rightAccessory}
      </View>
      {message ? <Text accessibilityLiveRegion="polite" style={[styles.message, error ? styles.errorMessage : undefined]}>{message}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: spacing.xs },
  label: textStyles.label,
  inputWrap: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.inputRadius,
    borderWidth: 1,
    flexDirection: 'row',
    minHeight: 48,
  },
  input: { ...textStyles.bodyLarge, flex: 1, minHeight: 48, paddingHorizontal: spacing.medium, paddingVertical: spacing.small },
  focused: { borderColor: colors.focus, borderWidth: 2 },
  errorBorder: { borderColor: colors.critical },
  disabled: { backgroundColor: colors.surfaceMuted },
  message: textStyles.bodySmall,
  errorMessage: { color: colors.critical },
});
