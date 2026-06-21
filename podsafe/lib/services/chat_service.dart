import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import '../models/chat_conversation_model.dart';

/// Service for managing chat conversations and messages
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // CONVERSATION METHODS
  // ============================================================================

  /// Get all conversations for a user
  Stream<List<ChatConversation>> getConversationsForUser(
    String companyId,
    String userId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .where('isArchived', isEqualTo: false)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatConversation.fromFirestore(doc))
            .toList());
  }

  /// Get a single conversation
  Future<ChatConversation?> getConversation(
    String companyId,
    String conversationId,
  ) async {
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!doc.exists) return null;
      return ChatConversation.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Get or create a conversation between driver and admin
  Future<String> getOrCreateConversation({
    required String companyId,
    required String driverId,
    required String driverName,
    required String? driverImageUrl,
    required String adminId,
    required String adminName,
    required String? adminImageUrl,
    String? deliveryId,
    String? claimId,
    String? vehicleId,
  }) async {
    try {
      // Check if conversation already exists
      final existingConv = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .where('driverId', isEqualTo: driverId)
          .where('adminId', isEqualTo: adminId)
          .where('isArchived', isEqualTo: false)
          .limit(1)
          .get();

      if (existingConv.docs.isNotEmpty) {
        return existingConv.docs.first.id;
      }

      // Create new conversation
      final newConv = ChatConversation(
        id: '', // Will be set by Firestore
        companyId: companyId,
        driverId: driverId,
        driverName: driverName,
        driverImageUrl: driverImageUrl,
        adminId: adminId,
        adminName: adminName,
        adminImageUrl: adminImageUrl,
        participantIds: [driverId, adminId],
        participantRoles: ['driver', 'admin'],
        lastMessage: 'Conversation started',
        lastMessageAt: DateTime.now(),
        deliveryId: deliveryId,
        claimId: claimId,
        vehicleId: vehicleId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .add(newConv.toMap());

      print('✅ Created new conversation: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update last message in conversation
  Future<void> updateLastMessage(
    String companyId,
    String conversationId,
    String lastMessage,
  ) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .update({
            'lastMessage': lastMessage,
            'lastMessageAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
    }
  }

  /// Mark conversation as read for user
  Future<void> markConversationAsRead(
    String companyId,
    String conversationId,
    String userId,
  ) async {
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (doc.exists) {
        final readStatus =
            Map<String, bool>.from(doc.get('readStatus') ?? {});
        readStatus[userId] = true;

        final unreadCount =
            Map<String, int>.from((doc.get('unreadCount') ?? {})
                as Map<dynamic, dynamic>);
        unreadCount[userId] = 0;

        await doc.reference.update({
          'readStatus': readStatus,
          'unreadCount': unreadCount,
        });
      }
    } catch (e) {
      print('❌ Error marking conversation as read: $e');
    }
  }

  /// Get unread conversations count for user
  Future<int> getUnreadConversationsCount(
    String companyId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .where('isArchived', isEqualTo: false)
          .get();

      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final readStatus = Map<String, bool>.from(doc.get('readStatus') ?? {});
        if (readStatus[userId] != true) {
          unreadCount++;
        }
      }
      return unreadCount;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Archive a conversation
  Future<void> archiveConversation(
    String companyId,
    String conversationId,
  ) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .update({'isArchived': true});
      print('✅ Archived conversation: $conversationId');
    } catch (e) {
      print('❌ Error archiving conversation: $e');
    }
  }

  // ============================================================================
  // MESSAGE METHODS
  // ============================================================================

  /// Send a message
  Future<String> sendMessage({
    required String companyId,
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
    String? senderImageUrl,
    String? imageUrl,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    try {
      final messageRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      final chatMessage = ChatMessage(
        id: messageRef.id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        senderImageUrl: senderImageUrl,
        message: message,
        sentAt: DateTime.now(),
        imageUrl: imageUrl,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentType: attachmentType,
      );

      await messageRef.set(chatMessage.toMap());

      // Update conversation's last message
      await updateLastMessage(companyId, conversationId, message);

      // Reset unread count for sender
      final conv = await getConversation(companyId, conversationId);
      if (conv != null) {
        final unreadCount =
            Map<String, int>.from((conv.unreadCount));
        for (var participantId in conv.participantIds) {
          if (participantId != senderId) {
            unreadCount[participantId] =
                (unreadCount[participantId] ?? 0) + 1;
          }
        }

        await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('conversations')
            .doc(conversationId)
            .update({'unreadCount': unreadCount});
      }

      print('✅ Message sent: ${messageRef.id}');
      return messageRef.id;
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages stream for a conversation
  Stream<List<ChatMessage>> getMessagesStream(
    String companyId,
    String conversationId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  /// Get messages for a conversation (paginated)
  Future<List<ChatMessage>> getMessages(
    String companyId,
    String conversationId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }

  /// Delete a message (soft delete)
  Future<void> deleteMessage(
    String companyId,
    String conversationId,
    String messageId,
  ) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
            'message': '[Message deleted]',
            'imageUrl': null,
            'attachmentUrl': null,
            'editedAt': Timestamp.now(),
            'isEdited': true,
          });
      print('✅ Message deleted: $messageId');
    } catch (e) {
      print('❌ Error deleting message: $e');
    }
  }

  /// Edit a message
  Future<void> editMessage(
    String companyId,
    String conversationId,
    String messageId,
    String newMessage,
  ) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
            'message': newMessage,
            'editedAt': Timestamp.now(),
            'isEdited': true,
          });
      print('✅ Message edited: $messageId');
    } catch (e) {
      print('❌ Error editing message: $e');
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(
    String companyId,
    String conversationId,
    String messageId,
  ) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      print('❌ Error marking message as read: $e');
    }
  }

  /// Mark all messages in conversation as read
  Future<void> markAllMessagesAsRead(
    String companyId,
    String conversationId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({'isRead': true});
      }
      print('✅ All messages marked as read');
    } catch (e) {
      print('❌ Error marking all messages as read: $e');
    }
  }

  // ============================================================================
  // SEARCH & FILTER
  // ============================================================================

  /// Search conversations by driver name
  Future<List<ChatConversation>> searchConversations(
    String companyId,
    String searchQuery,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('conversations')
          .where('isArchived', isEqualTo: false)
          .get();

      return snapshot.docs
          .map((doc) => ChatConversation.fromFirestore(doc))
          .where((conv) =>
              conv.driverName.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    } catch (e) {
      print('❌ Error searching conversations: $e');
      return [];
    }
  }

  /// Get conversations for a specific delivery
  Stream<List<ChatConversation>> getConversationsByDelivery(
    String companyId,
    String deliveryId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('conversations')
        .where('deliveryId', isEqualTo: deliveryId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatConversation.fromFirestore(doc))
            .toList());
  }

  /// Get conversations for a specific claim
  Stream<List<ChatConversation>> getConversationsByClaim(
    String companyId,
    String claimId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('conversations')
        .where('claimId', isEqualTo: claimId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatConversation.fromFirestore(doc))
            .toList());
  }
}
