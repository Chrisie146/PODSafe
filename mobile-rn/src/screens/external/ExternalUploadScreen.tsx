import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { colors } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import type { RootStackParamList } from '../../navigation/RootNavigator';

type Props = NativeStackScreenProps<RootStackParamList, 'ExternalUpload'>;

/**
 * Ported from lib/screens/external/upload_screen.dart — token-gated, no login,
 * reached via /upload/:token (third-party transport provider document upload).
 * Phase 1 routing target only; full ExternalDeliveryToken validation + upload flow
 * lands in Phase 3 alongside deliveryRepository.
 */
export default function ExternalUploadScreen({ route }: Props) {
  const { token } = route.params;
  return (
    <View style={styles.container}>
      <Text style={textStyles.heading2}>Upload Documents</Text>
      <Text style={[textStyles.bodyMedium, styles.note]}>Token: {token}</Text>
      <Text style={[textStyles.bodySmall, styles.note]}>Not yet ported — Phase 3 will wire this to deliveryRepository.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24, backgroundColor: colors.background },
  note: { marginTop: 8, color: colors.textSecondary, textAlign: 'center' },
});
