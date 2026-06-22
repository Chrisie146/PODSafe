import React, { useState } from 'react';
import { Image, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { ChatMessage } from '../models/chat';
import { colors, radii, spacing } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

interface MessageBubbleProps {
  message: ChatMessage;
  isCurrentUser: boolean;
  onDelete?: () => void;
  onEdit?: (newText: string) => void;
  replyToMessage?: ChatMessage;
}

function formatTime(date: Date): string {
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  return `${hours}:${minutes}`;
}

/**
 * Ported from lib/widgets/message_bubble.dart's MessageBubble (verified against source
 * on 2026-06-21). The Flutter version's long-press PopupMenuButton (Edit/Delete) is
 * replaced with an inline action row shown below the bubble on long-press, since RN has
 * no direct popup-menu primitive in this project — behavior (edit-in-place, delete) is
 * preserved. ChatListItem and TypingIndicator from the same Dart file are NOT ported:
 * they're not used by driver_chat_screen.dart (only MessageBubble is imported there).
 */
export default function MessageBubble({ message, isCurrentUser, onDelete, onEdit, replyToMessage }: MessageBubbleProps) {
  const [showOptions, setShowOptions] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editText, setEditText] = useState(message.message);

  const handleLongPress = () => {
    if (isCurrentUser) {
      setShowOptions(prev => !prev);
    }
  };

  const handleConfirmEdit = () => {
    onEdit?.(editText);
    setIsEditing(false);
    setShowOptions(false);
  };

  const bubbleTextColor = isCurrentUser ? colors.white : colors.textPrimary;

  return (
    <View style={[styles.container, isCurrentUser ? styles.containerSent : styles.containerReceived]}>
      {replyToMessage ? (
        <View style={[styles.replyPreview, isCurrentUser ? styles.replyPreviewSent : styles.replyPreviewReceived]}>
          <Text style={styles.replyAuthor}>Replying to {replyToMessage.senderName}</Text>
          <Text style={styles.replyText} numberOfLines={2}>
            {replyToMessage.message}
          </Text>
        </View>
      ) : null}

      <View style={[styles.row, isCurrentUser ? styles.rowSent : styles.rowReceived]}>
        <Pressable onLongPress={handleLongPress} style={styles.bubbleWrapper}>
          <View style={[styles.bubble, isCurrentUser ? styles.bubbleSent : styles.bubbleReceived]}>
            {isEditing ? (
              <View style={styles.editRow}>
                <TextInput
                  style={[styles.editInput, { color: bubbleTextColor }]}
                  value={editText}
                  onChangeText={setEditText}
                  autoFocus
                  onSubmitEditing={handleConfirmEdit}
                />
                <Pressable onPress={handleConfirmEdit} style={styles.editConfirm}>
                  <Text style={{ color: bubbleTextColor }}>{'✓'}</Text>
                </Pressable>
              </View>
            ) : (
              <>
                {message.imageUrl ? (
                  <Image source={{ uri: message.imageUrl }} style={styles.image} />
                ) : null}
                <Text style={[textStyles.bodyMedium, { color: bubbleTextColor }]}>{message.message}</Text>
                {message.attachmentUrl ? (
                  <View style={[styles.attachment, isCurrentUser ? styles.attachmentSent : styles.attachmentReceived]}>
                    <Text style={[styles.attachmentText, { color: bubbleTextColor }]}>
                      {message.attachmentName ?? 'Attachment'}
                    </Text>
                  </View>
                ) : null}
                {message.isEdited ? (
                  <Text style={[styles.editedLabel, isCurrentUser ? styles.editedLabelSent : styles.editedLabelReceived]}>
                    (edited)
                  </Text>
                ) : null}
              </>
            )}
          </View>
        </Pressable>
      </View>

      {showOptions && isCurrentUser && !isEditing ? (
        <View style={styles.actionsRow}>
          <Pressable onPress={() => setIsEditing(true)} style={styles.actionButton}>
            <Text style={styles.actionText}>Edit</Text>
          </Pressable>
          <Pressable
            onPress={() => {
              onDelete?.();
              setShowOptions(false);
            }}
            style={styles.actionButton}
          >
            <Text style={[styles.actionText, { color: colors.error }]}>Delete</Text>
          </Pressable>
        </View>
      ) : null}

      <Text style={styles.timestamp}>{formatTime(message.sentAt)}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: spacing.small / 2,
  },
  containerSent: {
    alignItems: 'flex-end',
  },
  containerReceived: {
    alignItems: 'flex-start',
  },
  replyPreview: {
    backgroundColor: colors.divider,
    borderLeftWidth: 3,
    borderLeftColor: colors.primary,
    borderRadius: radii.borderRadius / 1.5,
    padding: spacing.small,
    marginBottom: 4,
  },
  replyPreviewSent: {
    marginRight: spacing.small,
  },
  replyPreviewReceived: {
    marginLeft: spacing.small,
  },
  replyAuthor: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.primary,
  },
  replyText: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 4,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'flex-end',
  },
  rowSent: {
    justifyContent: 'flex-end',
  },
  rowReceived: {
    justifyContent: 'flex-start',
  },
  bubbleWrapper: {
    maxWidth: '80%',
  },
  bubble: {
    marginHorizontal: spacing.small,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: radii.borderRadius,
  },
  bubbleSent: {
    backgroundColor: colors.primary,
  },
  bubbleReceived: {
    backgroundColor: colors.divider,
  },
  editRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  editInput: {
    flex: 1,
    fontSize: 14,
    padding: 0,
  },
  editConfirm: {
    marginLeft: spacing.small,
  },
  image: {
    width: 150,
    height: 150,
    borderRadius: 8,
    marginBottom: spacing.small,
  },
  attachment: {
    marginTop: spacing.small,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    alignSelf: 'flex-start',
  },
  attachmentSent: {
    backgroundColor: 'rgba(255,255,255,0.24)',
  },
  attachmentReceived: {
    backgroundColor: colors.divider,
  },
  attachmentText: {
    fontSize: 12,
  },
  editedLabel: {
    fontSize: 11,
    fontStyle: 'italic',
    marginTop: 4,
  },
  editedLabelSent: {
    color: 'rgba(255,255,255,0.7)',
  },
  editedLabelReceived: {
    color: colors.textSecondary,
  },
  actionsRow: {
    flexDirection: 'row',
    marginHorizontal: spacing.small,
    marginTop: 4,
  },
  actionButton: {
    paddingHorizontal: spacing.small,
    paddingVertical: 4,
  },
  actionText: {
    fontSize: 13,
    color: colors.primary,
    fontWeight: '600',
  },
  timestamp: {
    fontSize: 12,
    color: colors.textSecondary,
    marginHorizontal: spacing.small + 4,
    marginTop: 2,
  },
});
