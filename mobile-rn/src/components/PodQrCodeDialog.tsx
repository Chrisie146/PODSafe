import React from 'react';
import { Alert, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import QRCode from 'react-native-qrcode-svg';
import { PodAccessToken, podTokenPublicUrl } from '../repositories/podTokenRepository';
import { colors, radii, spacing, shadows } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

/**
 * Ported from lib/widgets/pod_qr_code.dart's PODQRCodeDialog (verified against source on
 * 2026-06-22).
 *
 * Deviation: "Copy URL" and "Download" are kept as faithful no-ops, matching the Dart
 * source's *actual* current behavior exactly — its clipboard call is commented out
 * (so tapping does nothing today), and "Download" generates QR image bytes but never
 * persists or shares them, just shows a misleading "saved" toast regardless. Real
 * save/share wiring is in scope for Phase 6's cross-cutting download/export fixes, not
 * this pass — fixing it here would be inventing new behavior the source never had.
 */
interface PodQrCodeDialogProps {
  visible: boolean;
  token: PodAccessToken;
  baseUrl?: string;
  onClose: () => void;
}

export default function PodQrCodeDialog({ visible, token, baseUrl, onClose }: PodQrCodeDialogProps) {
  const url = podTokenPublicUrl(token, baseUrl);

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <View style={styles.card}>
          <View style={styles.headerRow}>
            <Text style={[textStyles.heading3, styles.headerTitle]}>📱 POD QR Code</Text>
            <Pressable onPress={onClose}>
              <Text style={styles.closeGlyph}>✕</Text>
            </Pressable>
          </View>

          <Text style={[textStyles.bodySmall, styles.subtitle]}>Scan this QR code to view the POD online</Text>

          <View style={styles.qrWrap}>
            <QRCode value={url} size={250} backgroundColor={colors.white} color={colors.textPrimary} ecl="M" />
          </View>

          <View style={styles.urlBox}>
            <Text style={styles.urlText} selectable>
              {url}
            </Text>
          </View>

          <View style={styles.actionsRow}>
            <Pressable style={styles.actionButton} onPress={() => {}}>
              <Text style={styles.actionText}>📋 Copy URL</Text>
            </Pressable>
            <Pressable
              style={[styles.actionButton, styles.actionButtonPrimary]}
              onPress={() => Alert.alert('QR code saved')}
            >
              <Text style={[styles.actionText, styles.actionTextPrimary]}>⬇ Download</Text>
            </Pressable>
          </View>

          <Text style={styles.expiryText}>
            Valid until: {token.expiresAt ? formatDate(token.expiresAt) : 'No expiry'}
          </Text>
        </View>
      </View>
    </Modal>
  );
}

function formatDate(date: Date): string {
  return `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.large,
    width: '100%',
    maxWidth: 400,
    ...shadows.card,
  },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  headerTitle: { color: colors.primary },
  closeGlyph: { fontSize: 20, color: colors.textSecondary, padding: spacing.small },
  subtitle: { textAlign: 'center', marginTop: spacing.medium },
  qrWrap: { alignItems: 'center', marginTop: spacing.large, padding: spacing.medium, backgroundColor: colors.white, borderRadius: radii.borderRadius },
  urlBox: { backgroundColor: colors.background, borderRadius: radii.borderRadius, padding: spacing.small + 4, marginTop: spacing.medium },
  urlText: { fontSize: 11, fontFamily: 'monospace', textAlign: 'center', color: colors.textPrimary },
  actionsRow: { flexDirection: 'row', justifyContent: 'space-evenly', marginTop: spacing.large, gap: spacing.small },
  actionButton: { paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius },
  actionButtonPrimary: { backgroundColor: colors.primary },
  actionText: { color: colors.primary, fontWeight: '600' },
  actionTextPrimary: { color: colors.white },
  expiryText: { marginTop: spacing.medium, fontSize: 12, color: colors.textSecondary, textAlign: 'center' },
});
