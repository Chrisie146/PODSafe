import React from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { AppIcon, AppIconName } from './AppIcon';
import { PrimaryButton } from './Buttons';

interface StateProps {
  title: string;
  message?: string;
  actionLabel?: string;
  onAction?: () => void;
  icon?: AppIconName;
}

export function LoadingState({ title = 'Loading', message = 'Please wait while we retrieve the latest information.' }: Pick<StateProps, 'title' | 'message'>) {
  return (
    <View accessibilityRole="progressbar" accessibilityLabel={title} style={styles.container}>
      <ActivityIndicator color={colors.active} size="large" />
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.message}>{message}</Text>
    </View>
  );
}

export function EmptyState({ title, message, actionLabel, onAction, icon = 'clipboard' }: StateProps) {
  return <StateContent title={title} message={message} actionLabel={actionLabel} onAction={onAction} icon={icon} />;
}

export function ErrorState({ title = 'Something went wrong', message = 'Try again. If the problem continues, contact your administrator.', actionLabel = 'Try again', onAction, icon = 'alert' }: Partial<StateProps>) {
  return <StateContent title={title} message={message} actionLabel={onAction ? actionLabel : undefined} onAction={onAction} icon={icon} isError />;
}

function StateContent({ title, message, actionLabel, onAction, icon, isError = false }: StateProps & { isError?: boolean }) {
  return (
    <View accessibilityLiveRegion="polite" style={styles.container}>
      <AppIcon name={icon ?? 'info'} size={32} color={isError ? colors.critical : colors.contentSecondary} />
      <Text style={styles.title}>{title}</Text>
      {message ? <Text style={styles.message}>{message}</Text> : null}
      {actionLabel && onAction ? <PrimaryButton label={actionLabel} onPress={onAction} style={styles.action} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', gap: spacing.small, justifyContent: 'center', minHeight: 200, padding: spacing.large },
  title: { ...textStyles.heading3, textAlign: 'center' },
  message: { ...textStyles.bodyMedium, color: colors.contentSecondary, maxWidth: 360, textAlign: 'center' },
  action: { alignSelf: 'stretch', marginTop: spacing.small, maxWidth: 320 },
});
