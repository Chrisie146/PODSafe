import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useAuthStore } from '../stores/useAuthStore';
import { colors } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

/**
 * Temporary post-login landing screen. Replaced by DriverStack (Phase 2) and
 * AdminStack/AdminWebRoutes (Phase 3/4) once those are built — this exists only
 * so RootNavigator has somewhere to send an authenticated user in Phase 1.
 */
export default function HomePlaceholderScreen() {
  const currentUser = useAuthStore(s => s.currentUser);
  const signOut = useAuthStore(s => s.signOut);

  return (
    <View style={styles.container}>
      <Text style={textStyles.heading2}>Signed in as {currentUser?.fullName ?? currentUser?.email}</Text>
      <Text style={[textStyles.bodyMedium, styles.role]}>Role: {currentUser?.role}</Text>
      <Pressable style={styles.button} onPress={() => signOut()}>
        <Text style={textStyles.buttonText}>Sign Out</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24, backgroundColor: colors.background },
  role: { marginTop: 8, marginBottom: 24, color: colors.textSecondary },
  button: { backgroundColor: colors.primary, borderRadius: 12, paddingVertical: 14, paddingHorizontal: 32 },
});
