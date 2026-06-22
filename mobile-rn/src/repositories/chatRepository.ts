import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { ChatConversation, ChatMessage } from '../models/chat';
import {
  chatConversationFromFirestore,
  chatConversationToFirestore,
  chatMessageFromFirestore,
  chatMessageToFirestore,
} from '../models/chat.converters';

/**
 * Ported from lib/services/chat_service.dart (verified against source on 2026-06-21),
 * following the constructor-injected repository pattern from authRepository.ts.
 *
 * Driver<->admin 1:1 chat: get-or-create conversation, send/list messages,
 * read/unread tracking, archive, search.
 */
export class ChatRepository {
  constructor(private firestoreInstance: FirebaseFirestoreTypes.Module = firestore()) {}

  private conversationsRef(companyId: string) {
    return this.firestoreInstance.collection('companies').doc(companyId).collection('conversations');
  }

  private messagesRef(companyId: string, conversationId: string) {
    return this.conversationsRef(companyId).doc(conversationId).collection('messages');
  }

  // ==========================================================================
  // CONVERSATION METHODS
  // ==========================================================================

  /** Subscribe to all (non-archived) conversations for a user. Returns an unsubscribe function. */
  subscribeToConversationsForUser(
    companyId: string,
    userId: string,
    onChange: (conversations: ChatConversation[]) => void,
    onError?: (error: Error) => void,
  ): () => void {
    return this.conversationsRef(companyId)
      .where('participantIds', 'array-contains', userId)
      .where('isArchived', '==', false)
      .orderBy('lastMessageAt', 'desc')
      .onSnapshot(
        (snapshot: FirebaseFirestoreTypes.QuerySnapshot) => {
          onChange(snapshot.docs.map(chatConversationFromFirestore));
        },
        (error: Error) => onError?.(error),
      );
  }

  /** Get a single conversation. Returns null if not found or on error (matches Dart's swallow-and-return-null). */
  async getConversation(companyId: string, conversationId: string): Promise<ChatConversation | null> {
    try {
      const doc = await this.conversationsRef(companyId).doc(conversationId).get();
      if (!doc.exists()) return null;
      return chatConversationFromFirestore(doc);
    } catch {
      return null;
    }
  }

  /** Get or create a conversation between driver and admin. Returns the conversation id. */
  async getOrCreateConversation(params: {
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
  }): Promise<string> {
    const { companyId, driverId, driverName, driverImageUrl, adminId, adminName, adminImageUrl, deliveryId, claimId, vehicleId } =
      params;

    const existing = await this.conversationsRef(companyId)
      .where('driverId', '==', driverId)
      .where('adminId', '==', adminId)
      .where('isArchived', '==', false)
      .limit(1)
      .get();

    if (!existing.empty) {
      return existing.docs[0].id;
    }

    const now = new Date();
    const newConversation: ChatConversation = {
      id: '', // set by Firestore
      companyId,
      driverId,
      driverName,
      driverImageUrl,
      adminId,
      adminName,
      adminImageUrl,
      participantIds: [driverId, adminId],
      participantRoles: ['driver', 'admin'],
      lastMessage: 'Conversation started',
      lastMessageAt: now,
      deliveryId,
      claimId,
      vehicleId,
      isActive: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      readStatus: {},
      unreadCount: {},
    };

    const docRef = await this.conversationsRef(companyId).add(chatConversationToFirestore(newConversation));
    return docRef.id;
  }

  /** Update last message in conversation. Swallows errors (matches Dart). */
  async updateLastMessage(companyId: string, conversationId: string, lastMessage: string): Promise<void> {
    try {
      await this.conversationsRef(companyId).doc(conversationId).update({
        lastMessage,
        lastMessageAt: firestore.Timestamp.now(),
        updatedAt: firestore.Timestamp.now(),
      });
    } catch {
      // matches Dart's silent catch
    }
  }

  /** Mark conversation as read for user (sets readStatus[userId]=true and unreadCount[userId]=0). */
  async markConversationAsRead(companyId: string, conversationId: string, userId: string): Promise<void> {
    try {
      const docRef = this.conversationsRef(companyId).doc(conversationId);
      const doc = await docRef.get();
      if (!doc.exists()) return;

      const data = doc.data() ?? {};
      const readStatus: Record<string, boolean> = { ...(data.readStatus ?? {}) };
      readStatus[userId] = true;

      const unreadCount: Record<string, number> = { ...(data.unreadCount ?? {}) };
      unreadCount[userId] = 0;

      await docRef.update({ readStatus, unreadCount });
    } catch {
      // matches Dart's catch-and-log
    }
  }

  /** Get unread conversations count for user. */
  async getUnreadConversationsCount(companyId: string, userId: string): Promise<number> {
    try {
      const snapshot = await this.conversationsRef(companyId)
        .where('participantIds', 'array-contains', userId)
        .where('isArchived', '==', false)
        .get();

      let unreadCount = 0;
      for (const doc of snapshot.docs) {
        const readStatus = doc.data()?.readStatus ?? {};
        if (readStatus[userId] !== true) {
          unreadCount++;
        }
      }
      return unreadCount;
    } catch {
      return 0;
    }
  }

  /** Archive a conversation. Swallows errors (matches Dart). */
  async archiveConversation(companyId: string, conversationId: string): Promise<void> {
    try {
      await this.conversationsRef(companyId).doc(conversationId).update({ isArchived: true });
    } catch {
      // matches Dart's catch-and-log
    }
  }

  // ==========================================================================
  // MESSAGE METHODS
  // ==========================================================================

  /** Send a message, update the conversation's last message, and bump unread counts for other participants. */
  async sendMessage(params: {
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
  }): Promise<string> {
    const {
      companyId,
      conversationId,
      senderId,
      senderName,
      senderRole,
      message,
      senderImageUrl,
      imageUrl,
      attachmentUrl,
      attachmentName,
      attachmentType,
    } = params;

    const messageRef = this.messagesRef(companyId, conversationId).doc();

    const chatMessage: ChatMessage = {
      id: messageRef.id,
      conversationId,
      senderId,
      senderName,
      senderRole,
      senderImageUrl,
      message,
      sentAt: new Date(),
      isRead: false,
      imageUrl,
      attachmentUrl,
      attachmentName,
      attachmentType,
      isEdited: false,
    };

    await messageRef.set(chatMessageToFirestore(chatMessage));

    await this.updateLastMessage(companyId, conversationId, message);

    // Reset unread count for sender, bump for every other participant.
    const conversation = await this.getConversation(companyId, conversationId);
    if (conversation) {
      const unreadCount: Record<string, number> = { ...conversation.unreadCount };
      for (const participantId of conversation.participantIds) {
        if (participantId !== senderId) {
          unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
        }
      }
      await this.conversationsRef(companyId).doc(conversationId).update({ unreadCount });
    }

    return messageRef.id;
  }

  /** Subscribe to messages for a conversation, oldest first. Returns an unsubscribe function. */
  subscribeToMessages(
    companyId: string,
    conversationId: string,
    onChange: (messages: ChatMessage[]) => void,
    onError?: (error: Error) => void,
  ): () => void {
    return this.messagesRef(companyId, conversationId)
      .orderBy('sentAt', 'asc')
      .onSnapshot(
        (snapshot: FirebaseFirestoreTypes.QuerySnapshot) => {
          onChange(snapshot.docs.map(chatMessageFromFirestore));
        },
        (error: Error) => onError?.(error),
      );
  }

  /** Get messages for a conversation (paginated, newest first under the hood, returned oldest-first). */
  async getMessages(
    companyId: string,
    conversationId: string,
    options?: { limit?: number; startAfter?: FirebaseFirestoreTypes.DocumentSnapshot },
  ): Promise<ChatMessage[]> {
    try {
      const limitCount = options?.limit ?? 50;
      let query = this.messagesRef(companyId, conversationId).orderBy('sentAt', 'desc').limit(limitCount);

      if (options?.startAfter) {
        query = query.startAfter(options.startAfter);
      }

      const snapshot = await query.get();
      return snapshot.docs.map(chatMessageFromFirestore).reverse();
    } catch {
      return [];
    }
  }

  /** Soft-delete a message. Swallows errors (matches Dart). */
  async deleteMessage(companyId: string, conversationId: string, messageId: string): Promise<void> {
    try {
      await this.messagesRef(companyId, conversationId).doc(messageId).update({
        message: '[Message deleted]',
        imageUrl: null,
        attachmentUrl: null,
        editedAt: firestore.Timestamp.now(),
        isEdited: true,
      });
    } catch {
      // matches Dart's catch-and-log
    }
  }

  /** Edit a message. Swallows errors (matches Dart). */
  async editMessage(companyId: string, conversationId: string, messageId: string, newMessage: string): Promise<void> {
    try {
      await this.messagesRef(companyId, conversationId).doc(messageId).update({
        message: newMessage,
        editedAt: firestore.Timestamp.now(),
        isEdited: true,
      });
    } catch {
      // matches Dart's catch-and-log
    }
  }

  /** Mark a single message as read. Swallows errors (matches Dart). */
  async markMessageAsRead(companyId: string, conversationId: string, messageId: string): Promise<void> {
    try {
      await this.messagesRef(companyId, conversationId).doc(messageId).update({ isRead: true });
    } catch {
      // matches Dart's catch-and-log
    }
  }

  /** Mark all unread messages in a conversation as read. Swallows errors (matches Dart). */
  async markAllMessagesAsRead(companyId: string, conversationId: string): Promise<void> {
    try {
      const snapshot = await this.messagesRef(companyId, conversationId).where('isRead', '==', false).get();
      await Promise.all(snapshot.docs.map(doc => doc.ref.update({ isRead: true })));
    } catch {
      // matches Dart's catch-and-log
    }
  }

  // ==========================================================================
  // SEARCH & FILTER
  // ==========================================================================

  /** Search non-archived conversations by driver name (client-side, case-insensitive substring match). */
  async searchConversations(companyId: string, searchQuery: string): Promise<ChatConversation[]> {
    try {
      const snapshot = await this.conversationsRef(companyId).where('isArchived', '==', false).get();
      const query = searchQuery.toLowerCase();
      return snapshot.docs.map(chatConversationFromFirestore).filter(conv => conv.driverName.toLowerCase().includes(query));
    } catch {
      return [];
    }
  }

  /** Subscribe to conversations linked to a specific delivery. Returns an unsubscribe function. */
  subscribeToConversationsByDelivery(
    companyId: string,
    deliveryId: string,
    onChange: (conversations: ChatConversation[]) => void,
    onError?: (error: Error) => void,
  ): () => void {
    return this.conversationsRef(companyId)
      .where('deliveryId', '==', deliveryId)
      .onSnapshot(
        (snapshot: FirebaseFirestoreTypes.QuerySnapshot) => onChange(snapshot.docs.map(chatConversationFromFirestore)),
        (error: Error) => onError?.(error),
      );
  }

  /** Subscribe to conversations linked to a specific claim. Returns an unsubscribe function. */
  subscribeToConversationsByClaim(
    companyId: string,
    claimId: string,
    onChange: (conversations: ChatConversation[]) => void,
    onError?: (error: Error) => void,
  ): () => void {
    return this.conversationsRef(companyId)
      .where('claimId', '==', claimId)
      .onSnapshot(
        (snapshot: FirebaseFirestoreTypes.QuerySnapshot) => onChange(snapshot.docs.map(chatConversationFromFirestore)),
        (error: Error) => onError?.(error),
      );
  }
}
