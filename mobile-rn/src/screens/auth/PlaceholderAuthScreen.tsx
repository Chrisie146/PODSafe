import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Screen, EmptyState, AppIconName } from '../../components/ui';
import { spacing } from '../../theme/tokens';

/**
 * Shared shell for the auth screens whose product flows are not yet ported
 * (signup, company-registration, driver-registration, invite-registration,
 * pending-approval). The routes already exist so the rest of the auth flow can be
 * wired against them; full forms land when each product flow is ready.
 *
 * UI/UX Refresh Phase 5: per the workflow guardrail we keep these as deliberate
 * placeholders, but give them a coherent design-system treatment (warm canvas +
 * branded empty state) instead of a raw "not yet ported" line.
 */
export default function PlaceholderAuthScreen({
  title,
  message = 'This flow is coming soon. For now, contact your administrator to get set up.',
  icon = 'info',
}: {
  title: string;
  message?: string;
  icon?: AppIconName;
}) {
  return (
    <Screen contentContainerStyle={styles.content}>
      <View style={styles.center}>
        <EmptyState title={title} message={message} icon={icon} />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', paddingHorizontal: spacing.medium },
});
