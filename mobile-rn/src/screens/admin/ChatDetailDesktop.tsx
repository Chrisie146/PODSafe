import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Modal, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useChatStore } from '../../stores/useChatStore';
import { ChatRepository } from '../../repositories/chatRepository';
import { ChatConversation, ChatMessage } from '../../models/chat';
import MessageBubble from '../../components/MessageBubble';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const chatRepository = new ChatRepository();

/**
 * Ported from lib/screens/admin/chat_detail_screen_desktop.dart (verified against source on
 * 2026-06-23). Not a route — embedded directly inside ChatListDesktop.tsx's detail pane,
 * same as the Dart source embeds ChatDetailScreenDesktop as a plain widget, not a pushed route.
 *
 * Deviation/fix: the Dart source's header (`conv?.driverName ?? 'Loading...'`) and the
 * "Conversation Info" dialog both read `ChatProvider.currentConversation`, but this screen
 * never calls `setCurrentConversation()` anywhere — confirmed by direct read, no initState,
 * no other call site sets it for this conversation id. In production the header would show
 * "Loading..." forever unless some unrelated prior screen happened to leave a matching
 * conversation cached. Fixed for real here: the conversation object is passed down directly
 * from the already-subscribed list in ChatListDesktop (no second fetch needed), and mounting
 * this pane also calls `useChatStore.setCurrentConversation()` for its real side effect —
 * marking the conversation read for the admin, which the Dart source also never triggers.
 */
export default function ChatDetailDesktop({ conversation, onClose }: { conversation: ChatConversation; onClose: () => void }) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const sendMessage = useChatStore((s) => s.sendMessage);
  const deleteMessage = useChatStore((s) => s.deleteMessage);
  const editMessage = useChatStore((s) => s.editMessage);
  const archiveConversation = useChatStore((s) => s.archiveConversation);
  const setCurrentConversation = useChatStore((s) => s.setCurrentConversation);

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [messageText, setMessageText] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [showInfo, setShowInfo] = useState(false);
  const listRef = useRef<FlatList<ChatMessage>>(null);

  useEffect(() => {
    if (!currentUser) return;
    setCurrentConversation(currentUser.companyId, conversation.id, currentUser.id);
  }, [currentUser, conversation.id, setCurrentConversation]);

  useEffect(() => {
    if (!currentUser) return;
    const unsubscribe = chatRepository.subscribeToMessages(currentUser.companyId, conversation.id, setMessages);
    return unsubscribe;
  }, [currentUser, conversation.id]);

  useEffect(() => {
    if (messages.length > 0) {
      requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
    }
  }, [messages.length]);

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Please log in</Text>
      </View>
    );
  }

  const handleSend = async () => {
    const trimmed = messageText.trim();
    if (!trimmed) return;
    setIsSending(true);
    try {
      await sendMessage({
        companyId: currentUser.companyId,
        conversationId: conversation.id,
        senderId: currentUser.id,
        senderName: currentUser.fullName,
        senderRole: currentUser.role,
        message: trimmed,
      });
      setMessageText('');
    } finally {
      setIsSending(false);
    }
  };

  const handleArchive = () => {
    Alert.alert('Archive Conversation', 'Archive this conversation? You can unarchive it later.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Archive',
        onPress: async () => {
          await archiveConversation(currentUser.companyId, conversation.id);
          onClose();
        },
      },
    ]);
  };

  const handleDeleteMessage = (messageId: string) => {
    Alert.alert('Delete Message', 'Are you sure you want to delete this message?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteMessage(currentUser.companyId, conversation.id, messageId) },
    ]);
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={styles.headerText}>
          <Text style={[textStyles.bodyLarge, styles.headerName]}>{conversation.driverName}</Text>
          <Text style={styles.headerSubtitle}>{conversation.participantIds.length} participants</Text>
        </View>
        <View style={styles.headerActions}>
          <Pressable style={styles.headerActionButton} onPress={() => setShowInfo(true)}>
            <Text style={styles.headerActionIcon}>ℹ️</Text>
          </Pressable>
          <Pressable style={styles.headerActionButton} onPress={handleArchive}>
            <Text style={styles.headerActionIcon}>🗄️</Text>
          </Pressable>
        </View>
      </View>

      {messages.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.emptyIcon}>💬</Text>
          <Text style={textStyles.bodyMedium}>No messages yet. Start the conversation!</Text>
        </View>
      ) : (
        <FlatList
          ref={listRef}
          style={styles.messagesList}
          contentContainerStyle={styles.messagesListContent}
          data={messages}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => {
            const isMe = item.senderId === currentUser.id;
            return (
              <MessageBubble
                message={item}
                isCurrentUser={isMe}
                onDelete={isMe ? () => handleDeleteMessage(item.id) : undefined}
                onEdit={isMe ? (newText) => editMessage(currentUser.companyId, conversation.id, item.id, newText) : undefined}
              />
            );
          }}
        />
      )}

      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          placeholder="Type a message..."
          value={messageText}
          onChangeText={setMessageText}
          onSubmitEditing={handleSend}
          editable={!isSending}
          multiline
        />
        <Pressable style={styles.sendButton} onPress={handleSend} disabled={isSending}>
          {isSending ? <ActivityIndicator color={colors.white} size="small" /> : <Text style={styles.sendIcon}>➤</Text>}
        </Pressable>
      </View>

      <Modal visible={showInfo} transparent animationType="fade" onRequestClose={() => setShowInfo(false)}>
        <View style={styles.infoBackdrop}>
          <View style={[styles.infoCard, shadows.card]}>
            <Text style={textStyles.heading3}>Conversation Info</Text>
            <InfoRow label="Driver" value={conversation.driverName} />
            {conversation.deliveryId ? <InfoRow label="Delivery ID" value={conversation.deliveryId} /> : null}
            {conversation.claimId ? <InfoRow label="Claim ID" value={conversation.claimId} /> : null}
            {conversation.vehicleId ? <InfoRow label="Vehicle ID" value={conversation.vehicleId} /> : null}
            <InfoRow label="Created" value={conversation.createdAt.toLocaleString()} />
            <InfoRow label="Last Message" value={conversation.lastMessageAt.toLocaleString()} />
            <Pressable style={styles.infoCloseButton} onPress={() => setShowInfo(false)}>
              <Text style={textStyles.buttonText}>Close</Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </View>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue} numberOfLines={2}>
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyIcon: { fontSize: 40, opacity: 0.4, marginBottom: spacing.small },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.medium,
  },
  headerText: { flex: 1 },
  headerName: { color: colors.white },
  headerSubtitle: { color: 'rgba(255,255,255,0.8)', fontSize: 12 },
  headerActions: { flexDirection: 'row', gap: spacing.small },
  headerActionButton: { padding: spacing.small },
  headerActionIcon: { fontSize: 18 },
  messagesList: { flex: 1 },
  messagesListContent: { padding: spacing.medium },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.small + 4,
    backgroundColor: colors.card,
    borderTopWidth: 1,
    borderTopColor: colors.divider,
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: 24,
    paddingHorizontal: spacing.medium,
    paddingVertical: 10,
    backgroundColor: colors.background,
    maxHeight: 120,
  },
  sendButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: spacing.small,
  },
  sendIcon: { color: colors.white, fontSize: 18 },
  infoBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  infoCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420 },
  infoRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: spacing.medium },
  infoLabel: { fontWeight: '600', color: colors.textSecondary },
  infoValue: { flex: 1, textAlign: 'right', marginLeft: spacing.medium },
  infoCloseButton: {
    marginTop: spacing.large,
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingVertical: spacing.small + 4,
  },
});
