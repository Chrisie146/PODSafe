import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { colors } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import type { RootStackParamList } from '../../navigation/RootNavigator';

type Props = NativeStackScreenProps<RootStackParamList, 'PublicPodView'>;

/**
 * Ported from lib/screens/public/public_pod_view_screen.dart — token-gated, no login,
 * reached via /pod/:deliveryId?token=xxx. Full PODAccessToken validation + POD render
 * lands with the podRepository work in Phase 2; this is the Phase 1 routing target so
 * linking.ts has somewhere real to send the deep link.
 */
export default function PublicPodViewScreen({ route }: Props) {
  const { deliveryId, token } = route.params;
  return (
    <View style={styles.container}>
      <Text style={textStyles.heading2}>Proof of Delivery</Text>
      <Text style={[textStyles.bodyMedium, styles.note]}>Delivery: {deliveryId}</Text>
      <Text style={[textStyles.bodyMedium, styles.note]}>Token: {token}</Text>
      <Text style={[textStyles.bodySmall, styles.note]}>Not yet ported — Phase 2 will wire this to podRepository.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24, backgroundColor: colors.background },
  note: { marginTop: 8, color: colors.textSecondary, textAlign: 'center' },
});
