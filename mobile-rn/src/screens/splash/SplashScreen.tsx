import React from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { colors } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/splash_screen.dart, minus its dual public-link-detection
 * responsibility — that's now handled once in navigation/linking.ts (Phase 1 work item
 * still pending; see vault "00 Overview" Phase 1 description), not duplicated here.
 * This screen now only renders while RootNavigator waits on useAuthStore's
 * isInitializing flag.
 */
export default function SplashScreen() {
  return (
    <View style={styles.container}>
      <Text style={[textStyles.heading1, styles.title]}>PODSafe</Text>
      <ActivityIndicator color={colors.primary} style={styles.spinner} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: colors.background },
  title: { color: colors.primary, marginBottom: 24 },
  spinner: {},
});
