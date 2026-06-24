// Ported from lib/screens/driver/driver_chat_screen.dart. Expects no navigation params
// (mirrors the Dart screen, which is parameterless) — it derives the company/user from
// useAuthStore and looks up the driver's single conversation with admin. If/when this is
// added to a DriverStack, register it as a route with `undefined` params.
import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  FlatList,
  Image,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import firestore from '@react-native-firebase/firestore';
import { useAuthStore } from '../../stores/useAuthStore';
import { useChatStore } from '../../stores/useChatStore';
import { ChatRepository } from '../../repositories/chatRepository';
import { userFromFirestore } from '../../models/user.converters';
import { ChatMessage } from '../../models/chat';
import MessageBubble from '../../components/MessageBubble';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';
import { IconButton, LoadingState, PrimaryButton, Screen } from '../../components/ui';

const chatRepository = new ChatRepository();

export default function Chat() {
  const currentUser = useAuthStore(s => s.currentUser);

  const conversations = useChatStore(s => s.conversations);
  const subscribeToConversations = useChatStore(s => s.subscribeToConversations);
  const sendMessage = useChatStore(s => s.sendMessage);
  const editMessage = useChatStore(s => s.editMessage);
  const deleteMessage = useChatStore(s => s.deleteMessage);
  const setChatScreenOpen = useChatStore(s => s.setChatScreenOpen);
  const getOrCreateConversation = useChatStore(s => s.getOrCreateConversation);
  const isLoading = useChatStore(s => s.isLoading);

  const [messageText, setMessageText] = useState('');
  const [conversationMessages, setConversationMessages] = useState<ChatMessage[]>([]);
  const [isStartingConversation, setIsStartingConversation] = useState(false);
  const [startError, setStartError] = useState<string | null>(null);
  const listRef = useRef<FlatList<ChatMessage>>(null);

  const conversation = conversations.length > 0 ? conversations[0] : null;

  // Subscribe to the driver's conversation list (mirrors StreamBuilder over loadConversationsStream).
  useEffect(() => {
    if (!currentUser) return;
    const unsubscribe = subscribeToConversations(currentUser.companyId, currentUser.id);
    return unsubscribe;
  }, [currentUser, subscribeToConversations]);

  // Mark the chat screen as open/viewing this conversation while mounted, matching
  // ChatProvider.setChatScreenOpen — suppresses the global monitor's notification path
  // (useChatStore.startMonitoring, wired up elsewhere) while this screen is on-screen.
  useEffect(() => {
    if (!conversation) return;
    setChatScreenOpen(true, conversation.id);
    return () => setChatScreenOpen(false);
  }, [conversation, setChatScreenOpen]);

  // The screen owns its own messages subscription (separate from the global monitor's
  // `messages` state in useChatStore, which is reserved for cross-screen notifications)
  // — mirrors the Dart screen's own StreamBuilder over chatProvider.getMessagesStream.
  useEffect(() => {
    if (!currentUser || !conversation) {
      setConversationMessages([]);
      return;
    }

    let isMounted = true;
    const unsubscribe = chatRepository.subscribeToMessages(currentUser.companyId, conversation.id, msgs => {
      if (isMounted) setConversationMessages(msgs);
    });

    return () => {
      isMounted = false;
      unsubscribe();
    };
  }, [currentUser, conversation]);

  useEffect(() => {
    if (conversationMessages.length > 0) {
      requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
    }
  }, [conversationMessages.length]);

  const handleSend = async () => {
    const trimmed = messageText.trim();
    if (!trimmed || !conversation || !currentUser) return;

    await sendMessage({
      companyId: currentUser.companyId,
      conversationId: conversation.id,
      senderId: currentUser.id,
      senderName: currentUser.fullName,
      senderRole: currentUser.role,
      message: trimmed,
    });

    setMessageText('');
  };

  const handleStartConversation = async () => {
    if (!currentUser) return;
    setIsStartingConversation(true);
    setStartError(null);
    try {
      const adminSnapshot = await firestore()
        .collection('users')
        .where('companyId', '==', currentUser.companyId)
        .where('role', '==', 'admin')
        .where('isActive', '==', true)
        .limit(1)
        .get();

      if (adminSnapshot.empty) {
        setStartError('No admin found for your company');
        return;
      }

      const adminUser = userFromFirestore(adminSnapshot.docs[0]);

      await getOrCreateConversation({
        companyId: currentUser.companyId,
        driverId: currentUser.id,
        driverName: currentUser.fullName,
        driverImageUrl: currentUser.profileImageUrl,
        adminId: adminUser.id,
        adminName: adminUser.fullName,
        adminImageUrl: adminUser.profileImageUrl,
      });
    } catch (e) {
      setStartError(`Failed to start conversation: ${(e as Error).message}`);
    } finally {
      setIsStartingConversation(false);
    }
  };

  const renderItem = useCallback(
    ({ item }: { item: ChatMessage }) => {
      const isMe = item.senderId === currentUser?.id;
      return (
        <MessageBubble
          message={item}
          isCurrentUser={isMe}
          onEdit={isMe ? newText => editMessage(currentUser!.companyId, conversation!.id, item.id, newText) : undefined}
          onDelete={isMe ? () => deleteMessage(currentUser!.companyId, conversation!.id, item.id) : undefined}
        />
      );
    },
    [currentUser, conversation, editMessage, deleteMessage],
  );

  if (!currentUser) {
    return <Screen><Text style={textStyles.bodyMedium}>Please log in</Text></Screen>;
  }

  if (!conversation) {
    return (
      <View style={styles.centered}>
        <Text style={[textStyles.heading3, styles.emptyTitle]}>No conversation yet</Text>
        <Text style={[textStyles.bodyMedium, styles.emptySubtitle]}>Start a conversation with your admin</Text>
        {startError ? <Text style={styles.errorText}>{startError}</Text> : null}
        <PrimaryButton label="Start conversation" loading={isStartingConversation} onPress={handleStartConversation} />
      </View>
    );
  }

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={styles.header}>
        {conversation.adminImageUrl ? (
          <Image source={{ uri: conversation.adminImageUrl }} style={styles.avatar} />
        ) : (
          <View style={[styles.avatar, styles.avatarFallback]}>
            <Text style={styles.avatarInitial}>{conversation.adminName.charAt(0).toUpperCase()}</Text>
          </View>
        )}
        <View style={styles.headerText}>
          <Text style={textStyles.bodyLarge}>{conversation.adminName}</Text>
          <Text style={[textStyles.bodySmall]}>Admin</Text>
        </View>
      </View>

      {isLoading && conversationMessages.length === 0 ? (
        <LoadingState title="Loading conversation" />
      ) : conversationMessages.length === 0 ? (
        <View style={styles.centered}>
          <Text style={textStyles.bodyMedium}>No messages yet. Start the conversation!</Text>
        </View>
      ) : (
        <FlatList
          ref={listRef}
          data={conversationMessages}
          keyExtractor={item => item.id}
          renderItem={renderItem}
          contentContainerStyle={styles.messagesList}
        />
      )}

      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          placeholder="Type a message..."
          accessibilityLabel="Message to admin"
          value={messageText}
          onChangeText={setMessageText}
          onSubmitEditing={handleSend}
          multiline
        />
        <IconButton icon="arrowRight" color={colors.onPrimary} accessibilityLabel="Send message" onPress={handleSend} style={styles.sendButton} />
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyTitle: { marginBottom: spacing.small },
  emptySubtitle: { color: colors.textSecondary, textAlign: 'center', marginBottom: spacing.large },
  errorText: { color: colors.error, marginBottom: spacing.small, textAlign: 'center' },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.small + 4,
    backgroundColor: colors.card,
    borderBottomWidth: 1,
    borderBottomColor: colors.divider,
  },
  avatar: { width: 40, height: 40, borderRadius: 20, marginRight: spacing.small },
  avatarFallback: { backgroundColor: colors.divider, alignItems: 'center', justifyContent: 'center' },
  avatarInitial: { color: colors.textPrimary, fontWeight: '600' },
  headerText: { flex: 1 },
  messagesList: { padding: spacing.medium },
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
    backgroundColor: colors.shell,
    borderRadius: radii.buttonRadius,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: spacing.small,
  },
});
