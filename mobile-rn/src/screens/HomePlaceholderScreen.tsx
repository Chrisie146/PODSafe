import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useAuthStore } from '../stores/useAuthStore';
import { colors, spacing } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';
import { Screen, Card, PrimaryButton, AppIcon } from '../components/ui';

/**
 * Temporary post-login landing screen. Replaced by DriverStack and
 * AdminStack/AdminWebRoutes once those are built — this exists only so RootNavigator
 * has somewhere to send an authenticated user when no role stack resolves.
 *
 * UI/UX Refresh Phase 5: rebuilt on the shared primitives so even the fallback
 * landing reads as the Operations Precision system.
 */
export default function HomePlaceholderScreen() {
  const currentUser = useAuthStore(s => s.currentUser);
  const signOut = useAuthStore(s => s.signOut);

  return (
    <Screen contentContainerStyle={styles.content}>
      <Card padding="spacious" style={styles.card}>
        <View style={styles.avatar}>
          <AppIcon name="user" size={28} color={colors.onPrimary} />
        </View>
        <Text style={[textStyles.heading2, styles.name]}>{currentUser?.fullName ?? currentUser?.email}</Text>
        <Text style={[textStyles.bodyMedium, styles.role]}>Role: {currentUser?.role}</Text>
        <PrimaryButton label="Sign out" icon="logout" onPress={() => signOut()} style={styles.button} />
      </Card>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1, justifyContent: 'center', maxWidth: 440, width: '100%', alignSelf: 'center' },
  card: { alignItems: 'center', gap: spacing.small },
  avatar: {
    alignItems: 'center',
    backgroundColor: colors.shell,
    borderRadius: 28,
    height: 56,
    justifyContent: 'center',
    marginBottom: spacing.small,
    width: 56,
  },
  name: { textAlign: 'center' },
  role: { color: colors.contentSecondary, marginBottom: spacing.medium, textAlign: 'center' },
  button: { alignSelf: 'stretch' },
});
