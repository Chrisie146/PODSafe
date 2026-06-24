import React from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { IconButton } from './Buttons';

export interface AppModalProps {
  visible: boolean;
  title: string;
  children: React.ReactNode;
  onClose: () => void;
  dismissable?: boolean;
  footer?: React.ReactNode;
}

export function AppModal({ visible, title, children, onClose, dismissable = true, footer }: AppModalProps) {
  return (
    <Modal transparent animationType="fade" visible={visible} onRequestClose={onClose} statusBarTranslucent>
      <View style={styles.backdrop}>
        {dismissable ? <Pressable style={StyleSheet.absoluteFill} accessibilityRole="button" accessibilityLabel="Close dialog" onPress={onClose} /> : null}
        <View accessibilityViewIsModal style={styles.dialog}>
          <View style={styles.header}>
            <Text style={styles.title}>{title}</Text>
            {dismissable ? <IconButton icon="close" accessibilityLabel="Close dialog" onPress={onClose} /> : null}
          </View>
          <View style={styles.content}>{children}</View>
          {footer ? <View style={styles.footer}>{footer}</View> : null}
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { alignItems: 'center', backgroundColor: colors.scrim, flex: 1, justifyContent: 'center', padding: spacing.large },
  dialog: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.cardRadius,
    borderWidth: 1,
    maxWidth: 560,
    overflow: 'hidden',
    width: '100%',
    ...shadows.modal,
  },
  header: { alignItems: 'center', borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth, flexDirection: 'row', gap: spacing.small, minHeight: 64, paddingLeft: spacing.large, paddingRight: spacing.small },
  title: { ...textStyles.heading3, flex: 1 },
  content: { padding: spacing.large },
  footer: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, padding: spacing.medium },
});
