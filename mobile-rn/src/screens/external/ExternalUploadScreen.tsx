import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { colors, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { Screen, Card, AppIcon } from '../../components/ui';
import type { RootStackParamList } from '../../navigation/RootNavigator';

type Props = NativeStackScreenProps<RootStackParamList, 'ExternalUpload'>;

/**
 * Ported from lib/screens/external/upload_screen.dart — token-gated, no login,
 * reached via /upload/:token (third-party transport provider document upload).
 * Full ExternalDeliveryToken validation + upload flow is a deferred product flow;
 * this remains a deliberate placeholder.
 *
 * UI/UX Refresh Phase 5: public/unauthenticated surfaces stay deliberately simple but
 * get a coherent brand treatment. The upload token is never echoed to the screen.
 */
export default function ExternalUploadScreen(_props: Props) {
  return (
    <Screen contentContainerStyle={styles.content}>
      <View style={styles.brand}>
        <View style={styles.logoBadge}>
          <AppIcon name="shield" size={22} color={colors.onPrimary} />
        </View>
        <Text style={[textStyles.label, styles.brandText]}>PODSafe</Text>
      </View>

      <Card padding="spacious" style={styles.card}>
        <View style={styles.iconWrap}>
          <AppIcon name="upload" size={28} color={colors.shell} />
        </View>
        <Text style={[textStyles.heading2, styles.title]}>Upload Documents</Text>
        <Text style={[textStyles.bodyMedium, styles.message]}>
          Secure document upload for this delivery is coming soon. You'll be able to attach
          delivery paperwork and proof here once the upload flow is available.
        </Text>
      </Card>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { flexGrow: 1, justifyContent: 'center', gap: spacing.large, maxWidth: 480, width: '100%', alignSelf: 'center' },
  brand: { alignItems: 'center', flexDirection: 'row', gap: spacing.small, justifyContent: 'center' },
  logoBadge: { alignItems: 'center', backgroundColor: colors.shell, borderRadius: 12, height: 36, justifyContent: 'center', width: 36 },
  brandText: { color: colors.shell, letterSpacing: 0.5 },
  card: { alignItems: 'center', gap: spacing.small },
  iconWrap: {
    alignItems: 'center',
    backgroundColor: colors.surfaceMuted,
    borderRadius: 16,
    height: 56,
    justifyContent: 'center',
    marginBottom: spacing.small,
    width: 56,
  },
  title: { textAlign: 'center' },
  message: { color: colors.contentSecondary, textAlign: 'center' },
});
