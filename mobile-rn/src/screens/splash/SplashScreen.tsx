import React from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { AppIcon } from '../../components/ui';

/**
 * Ported from lib/screens/splash_screen.dart, minus its dual public-link-detection
 * responsibility — that's now handled once in navigation/linking.ts, not duplicated here.
 * This screen only renders while RootNavigator waits on useAuthStore's isInitializing flag.
 *
 * UI/UX Refresh Phase 5: branded on the Operations Precision palette (navy badge on the
 * warm canvas) to match the Login entry surface.
 */
export default function SplashScreen() {
  return (
    <View style={styles.container}>
      <View style={styles.logoBadge}>
        <AppIcon name="shield" size={36} color={colors.onPrimary} />
      </View>
      <Text style={[textStyles.heading1, styles.title]}>PODSafe</Text>
      <ActivityIndicator color={colors.active} style={styles.spinner} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: colors.canvas },
  logoBadge: {
    alignItems: 'center',
    backgroundColor: colors.shell,
    borderRadius: 22,
    height: 72,
    justifyContent: 'center',
    marginBottom: spacing.medium,
    width: 72,
  },
  title: { color: colors.shell, marginBottom: spacing.large },
  spinner: {},
});
