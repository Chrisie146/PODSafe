import React, { useState } from 'react';
import { StyleProp, StyleSheet, TextInput, TextInputProps, View, ViewStyle } from 'react-native';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { AppIcon } from './AppIcon';

export interface SearchFieldProps extends Omit<TextInputProps, 'style'> {
  containerStyle?: StyleProp<ViewStyle>;
}

export function SearchField({ containerStyle, placeholder = 'Search', ...inputProps }: SearchFieldProps) {
  const [isFocused, setIsFocused] = useState(false);
  return (
    <View style={[styles.container, isFocused && styles.focused, containerStyle]}>
      <AppIcon name="search" size={20} color={colors.contentSecondary} />
      <TextInput
        {...inputProps}
        accessibilityLabel={inputProps.accessibilityLabel ?? placeholder}
        placeholder={placeholder}
        placeholderTextColor={colors.contentSecondary}
        style={styles.input}
        onBlur={(event) => {
          setIsFocused(false);
          inputProps.onBlur?.(event);
        }}
        onFocus={(event) => {
          setIsFocused(true);
          inputProps.onFocus?.(event);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.inputRadius,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.small,
    minHeight: 48,
    paddingHorizontal: spacing.medium,
  },
  focused: { borderColor: colors.focus, borderWidth: 2 },
  input: { ...textStyles.bodyLarge, flex: 1, minHeight: 46, paddingVertical: spacing.small },
});
