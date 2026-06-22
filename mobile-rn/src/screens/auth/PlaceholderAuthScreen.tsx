import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { colors } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Shared shell for the auth screens not yet fully ported in Phase 1
 * (signup, company-registration, driver-registration, invite-registration,
 * pending-approval). Navigation routes already exist so the rest of the auth
 * flow can be wired against them; full forms land alongside the relevant
 * phase in the vault's "04 Inventory - Screens" checklist.
 */
export default function PlaceholderAuthScreen({ title }: { title: string }) {
  return (
    <View style={styles.container}>
      <Text style={textStyles.heading2}>{title}</Text>
      <Text style={[textStyles.bodyMedium, styles.note]}>Not yet ported — Phase 1 scaffold placeholder.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24, backgroundColor: colors.background },
  note: { marginTop: 8, color: colors.textSecondary },
});
