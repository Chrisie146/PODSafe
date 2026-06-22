import { create } from 'zustand';
import { AppUser } from '../models/user';
import { ChatConversation, ChatMessage } from '../models/chat';
import { ChatRepository } from '../repositories/chatRepository';

/**
 * Replaces lib/providers/chat_provider.dart's ChatProvider (ChangeNotifier).
 *
 * `startMonitoring` mirrors `startMonitoringForDriver(companyId, userId, userRole)`:
 * it is a no-op for non-drivers, subscribes to the driver's conversation list, takes the
 * first (drivers have exactly one conversation with admin), then subscribes to that
 * conversation's messages. Whenever the chat screen is not currently open and viewing
 * that exact conversation, incoming messages are pushed into `messages`/notification
 * state here so a global "new message" banner/badge can be driven from anywhere in the
 * app. When the chat screen IS open on that conversation, the screen's own subscription
 * (via `subscribeToMessages` called directly, or future hook) is the source of truth and
 * this path intentionally skips updating `messages` to avoid clobbering/flicker — same
 * tradeoff the Dart version makes.
 *
 * NOT wired into App.tsx here — per the task, another pass wires
 * `useAuthStore`'s `currentUser` to `useChatStore.startMonitoring`/`stopMonitoring`.
 */

const chatRepository = new ChatRepository();

interface ChatState {
  conversations: ChatConversation[];
  currentConversation: ChatConversation | null;
  messages: ChatMessage[];
  isLoading: boolean;
  errorMessage: string | null;
  unreadCount: number;

  // Notification state (driven by global monitoring).
  pendingNotificationMessage: ChatMessage | null;
  pendingNotificationConversation: ChatConversation | null;

  // Chat-screen-open tracking, used to suppress notifications while viewing the conversation.
  isChatScreenOpen: boolean;
  currentViewedConversationId: string | null;

  // Internal monitoring subscription handles (not part of the Dart provider's public surface,
  // kept here only so stopMonitoring can tear them down).
  _monitoringConversationsUnsubscribe: (() => void) | null;
  _monitoringMessagesUnsubscribe: (() => void) | null;

  /** Mirrors ChatProvider.initializeChat: loads the unread conversation count for a user. */
  initializeChat: (companyId: string, userId: string) => Promise<void>;

  /**
   * Mirrors ChatProvider.startMonitoringForDriver(companyId, userId, userRole).
   * No-op unless userRole === 'driver'. Call again to restart (replaces any existing
   * subscription, matching the Dart cancel-then-resubscribe behavior).
   */
  startMonitoring: (user: AppUser) => void;

  /** Mirrors ChatProvider.stopMonitoring. */
  stopMonitoring: () => void;

  /** Mirrors ChatProvider.loadConversationsStream + updateConversations, combined into one subscribe call. */
  subscribeToConversations: (companyId: string, userId: string) => () => void;

  /** Mirrors ChatProvider.setCurrentConversation: loads + marks read. */
  setCurrentConversation: (companyId: string, conversationId: string, userId: string) => Promise<void>;

  /** Mirrors ChatProvider.setChatScreenOpen. */
  setChatScreenOpen: (isOpen: boolean, conversationId?: string) => void;

  /** Mirrors ChatProvider.checkForNotification. */
  checkForNotification: (message: ChatMessage, conversation: ChatConversation, currentUserId: string) => void;

  /** Mirrors ChatProvider.clearPendingNotification. */
  clearPendingNotification: () => void;

  /** Mirrors ChatProvider.sendMessage. */
  sendMessage: (params: {
    companyId: string;
    conversationId: string;
    senderId: string;
    senderName: string;
    senderRole: string;
    message: string;
    senderImageUrl?: string;
    imageUrl?: string;
    attachmentUrl?: string;
    attachmentName?: string;
    attachmentType?: string;
  }) => Promise<void>;

  /** Mirrors ChatProvider.getOrCreateConversation. */
  getOrCreateConversation: (params: {
    companyId: string;
    driverId: string;
    driverName: string;
    driverImageUrl?: string;
    adminId: string;
    adminName: string;
    adminImageUrl?: string;
    deliveryId?: string;
    claimId?: string;
    vehicleId?: string;
  }) => Promise<string | null>;

  /** Mirrors ChatProvider.deleteMessage. */
  deleteMessage: (companyId: string, conversationId: string, messageId: string) => Promise<void>;

  /** Mirrors ChatProvider.editMessage. */
  editMessage: (companyId: string, conversationId: string, messageId: string, newMessage: string) => Promise<void>;

  /** Mirrors ChatProvider.archiveConversation. */
  archiveConversation: (companyId: string, conversationId: string) => Promise<void>;

  /** Mirrors ChatProvider.searchConversations. */
  searchConversations: (companyId: string, query: string) => Promise<ChatConversation[]>;

  /** Mirrors ChatProvider.clearState. */
  clearState: () => void;

  /** Mirrors ChatProvider.getUnreadCount(conversationId), keyed against the loaded conversations list. */
  getUnreadCountFor: (conversationId: string, userId: string) => number;

  /**
   * Internal helper used only by the `startMonitoring` subscription. Mirrors
   * ChatProvider.updateMessages — updates `messages` and raises a notification check
   * when a new message arrives. Not part of the Dart provider's intended public API
   * surface for screens; exposed on the store only because Zustand actions must live here.
   */
  updateMessagesFromMonitoring: (messages: ChatMessage[], currentUserId: string, conversation: ChatConversation) => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  conversations: [],
  currentConversation: null,
  messages: [],
  isLoading: false,
  errorMessage: null,
  unreadCount: 0,

  pendingNotificationMessage: null,
  pendingNotificationConversation: null,

  isChatScreenOpen: false,
  currentViewedConversationId: null,

  _monitoringConversationsUnsubscribe: null,
  _monitoringMessagesUnsubscribe: null,

  initializeChat: async (companyId, userId) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const unreadCount = await chatRepository.getUnreadConversationsCount(companyId, userId);
      set({ unreadCount, isLoading: false });
    } catch (e) {
      set({ errorMessage: `Failed to initialize chat: ${(e as Error).message}`, isLoading: false });
    }
  },

  startMonitoring: user => {
    if (user.role !== 'driver') return;

    // Cancel any existing subscriptions before starting new ones (matches Dart's cancel-then-resubscribe).
    get().stopMonitoring();

    const conversationsUnsubscribe = chatRepository.subscribeToConversationsForUser(
      user.companyId,
      user.id,
      conversations => {
        if (conversations.length === 0) return;
        const conversation = conversations[0];

        // Replace any previous message subscription (a new/changed first conversation).
        get()._monitoringMessagesUnsubscribe?.();

        const messagesUnsubscribe = chatRepository.subscribeToMessages(user.companyId, conversation.id, messages => {
          const { isChatScreenOpen, currentViewedConversationId } = get();
          // Only process if not on the chat screen, or viewing a different conversation —
          // matches the Dart provider's guard in startMonitoringForDriver.
          if (!isChatScreenOpen || currentViewedConversationId !== conversation.id) {
            get().updateMessagesFromMonitoring(messages, user.id, conversation);
          }
        });

        set({ _monitoringMessagesUnsubscribe: messagesUnsubscribe });
      },
    );

    set({ _monitoringConversationsUnsubscribe: conversationsUnsubscribe });
  },

  stopMonitoring: () => {
    get()._monitoringConversationsUnsubscribe?.();
    get()._monitoringMessagesUnsubscribe?.();
    set({ _monitoringConversationsUnsubscribe: null, _monitoringMessagesUnsubscribe: null });
  },

  subscribeToConversations: (companyId, userId) => {
    return chatRepository.subscribeToConversationsForUser(companyId, userId, conversations => {
      set({ conversations });
    });
  },

  setCurrentConversation: async (companyId, conversationId, userId) => {
    try {
      const currentConversation = await chatRepository.getConversation(companyId, conversationId);
      if (currentConversation) {
        await chatRepository.markConversationAsRead(companyId, conversationId, userId);
      }
      set({ currentConversation, errorMessage: null });
    } catch (e) {
      set({ errorMessage: `Failed to load conversation: ${(e as Error).message}` });
    }
  },

  setChatScreenOpen: (isOpen, conversationId) => {
    set({ isChatScreenOpen: isOpen, currentViewedConversationId: conversationId ?? null });
    if (isOpen) {
      get().clearPendingNotification();
    }
  },

  checkForNotification: (message, conversation, currentUserId) => {
    const { isChatScreenOpen, currentViewedConversationId } = get();

    // Don't notify if the chat screen is open and viewing this conversation.
    if (isChatScreenOpen && currentViewedConversationId === conversation.id) return;
    // Don't notify for messages sent by the current user.
    if (message.senderId === currentUserId) return;
    // Only notify drivers about admin messages (admins don't get notified of their own).
    if (message.senderRole !== 'admin') return;

    set({ pendingNotificationMessage: message, pendingNotificationConversation: conversation });
  },

  clearPendingNotification: () => {
    set({ pendingNotificationMessage: null, pendingNotificationConversation: null });
  },

  // Internal helper used only by the monitoring subscription, mirrors ChatProvider.updateMessages.
  updateMessagesFromMonitoring: (messages: ChatMessage[], currentUserId: string, conversation: ChatConversation) => {
    const previousCount = get().messages.length;
    set({ messages });

    if (messages.length > previousCount && messages.length > 0) {
      const latestMessage = messages[messages.length - 1];
      get().checkForNotification(latestMessage, conversation, currentUserId);
    }
  },

  sendMessage: async params => {
    set({ errorMessage: null });
    try {
      await chatRepository.sendMessage(params);
    } catch (e) {
      set({ errorMessage: `Failed to send message: ${(e as Error).message}` });
    }
  },

  getOrCreateConversation: async params => {
    set({ isLoading: true, errorMessage: null });
    try {
      const conversationId = await chatRepository.getOrCreateConversation(params);
      set({ isLoading: false });
      return conversationId;
    } catch (e) {
      set({ errorMessage: `Failed to create conversation: ${(e as Error).message}`, isLoading: false });
      return null;
    }
  },

  deleteMessage: async (companyId, conversationId, messageId) => {
    set({ errorMessage: null });
    try {
      await chatRepository.deleteMessage(companyId, conversationId, messageId);
    } catch (e) {
      set({ errorMessage: `Failed to delete message: ${(e as Error).message}` });
    }
  },

  editMessage: async (companyId, conversationId, messageId, newMessage) => {
    set({ errorMessage: null });
    try {
      await chatRepository.editMessage(companyId, conversationId, messageId, newMessage);
    } catch (e) {
      set({ errorMessage: `Failed to edit message: ${(e as Error).message}` });
    }
  },

  archiveConversation: async (companyId, conversationId) => {
    set({ errorMessage: null });
    try {
      await chatRepository.archiveConversation(companyId, conversationId);
      set(state => ({ conversations: state.conversations.filter(c => c.id !== conversationId) }));
    } catch (e) {
      set({ errorMessage: `Failed to archive conversation: ${(e as Error).message}` });
    }
  },

  searchConversations: async (companyId, query) => {
    set({ errorMessage: null });
    try {
      return await chatRepository.searchConversations(companyId, query);
    } catch (e) {
      set({ errorMessage: `Failed to search conversations: ${(e as Error).message}` });
      return [];
    }
  },

  clearState: () => {
    set({
      conversations: [],
      currentConversation: null,
      messages: [],
      isLoading: false,
      errorMessage: null,
    });
  },

  getUnreadCountFor: (conversationId, userId) => {
    const conversation = get().conversations.find(c => c.id === conversationId);
    return conversation ? conversation.unreadCount[userId] ?? 0 : 0;
  },
}));
