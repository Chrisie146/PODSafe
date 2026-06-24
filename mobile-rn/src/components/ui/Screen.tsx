import React from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleProp, StyleSheet, View, ViewStyle } from 'react-native';
import { Edge, SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing } from '../../theme/tokens';

export interface ScreenProps {
  children: React.ReactNode;
  scroll?: boolean;
  keyboardAvoiding?: boolean;
  edges?: Edge[];
  style?: StyleProp<ViewStyle>;
  contentContainerStyle?: StyleProp<ViewStyle>;
  testID?: string;
}

/** A canvas-coloured, safe-area-aware screen foundation for new refresh work. */
export function Screen({
  children,
  scroll = false,
  keyboardAvoiding = false,
  edges = ['left', 'right', 'bottom'],
  style,
  contentContainerStyle,
  testID,
}: ScreenProps) {
  const content = scroll ? (
    <ScrollView
      contentContainerStyle={[styles.scrollContent, contentContainerStyle]}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  ) : (
    <View style={[styles.content, contentContainerStyle]}>{children}</View>
  );

  const body = keyboardAvoiding ? (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.select({ ios: 'padding', default: undefined })}>
      {content}
    </KeyboardAvoidingView>
  ) : content;

  return (
    <SafeAreaView testID={testID} edges={edges} style={[styles.safeArea, style]}>
      {body}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: colors.canvas },
  flex: { flex: 1 },
  content: { flex: 1, paddingHorizontal: spacing.medium },
  scrollContent: { flexGrow: 1, paddingHorizontal: spacing.medium, paddingVertical: spacing.medium },
});
