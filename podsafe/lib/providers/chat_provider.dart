import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/chat_message_model.dart';
import '../models/chat_conversation_model.dart';
import '../services/chat_service.dart';

/// State provider for chat functionality
class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final Logger _logger = Logger();

  // State
  List<ChatConversation> _conversations = [];
  ChatConversation? _currentConversation;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadCount = 0;
  
  // Notification state
  ChatMessage? _pendingNotificationMessage;
  ChatConversation? _pendingNotificationConversation;
  bool _isChatScreenOpen = false;
  String? _currentViewedConversationId;
  
  // Global message monitoring for drivers
  String? _monitoringCompanyId;
  String? _monitoringUserId;
  String? _monitoringConversationId;
  StreamSubscription<List<ChatMessage>>? _messageSubscription;

  // Getters
  List<ChatConversation> get conversations => _conversations;
  ChatConversation? get currentConversation => _currentConversation;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;
  
  // Notification getters
  ChatMessage? get pendingNotificationMessage => _pendingNotificationMessage;
  ChatConversation? get pendingNotificationConversation => _pendingNotificationConversation;
  bool get hasPendingNotification => _pendingNotificationMessage != null && _pendingNotificationConversation != null;

  /// Initialize chat provider - load conversations for user
  Future<void> initializeChat(String companyId, String userId) async {
    _setLoading(true);
    try {
      _unreadCount = await _chatService.getUnreadConversationsCount(
        companyId,
        userId,
      );
      _clearError();
    } catch (e) {
      _setError('Failed to initialize chat: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Start monitoring messages for driver (for notifications)
  void startMonitoringForDriver(String companyId, String userId, String userRole) {
    // Only monitor for drivers
    if (userRole != 'driver') return;
    
    // Cancel existing subscription if any
    _messageSubscription?.cancel();
    
    _monitoringCompanyId = companyId;
    _monitoringUserId = userId;
    
    // Get the driver's conversation and start monitoring
    loadConversationsStream(companyId, userId).listen((conversations) {
      if (conversations.isNotEmpty) {
        final conversation = conversations.first;
        _monitoringConversationId = conversation.id;
        
        // Monitor messages in this conversation
        _messageSubscription = getMessagesStream(companyId, conversation.id).listen((messages) {
          // Only process if not on chat screen or viewing different conversation
          if (!_isChatScreenOpen || _currentViewedConversationId != conversation.id) {
            // Defer the update to avoid calling during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              updateMessages(messages, currentUserId: userId, conversation: conversation);
            });
          }
        });
      }
    });
  }
  
  /// Stop monitoring messages
  void stopMonitoring() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _monitoringCompanyId = null;
    _monitoringUserId = null;
    _monitoringConversationId = null;
  }

  /// Load conversations stream for user
  Stream<List<ChatConversation>> loadConversationsStream(
    String companyId,
    String userId,
  ) {
    return _chatService.getConversationsForUser(companyId, userId);
  }

  /// Update conversations list (from stream)
  void updateConversations(List<ChatConversation> conversations) {
    _conversations = conversations;
    notifyListeners();
  }

  /// Load messages for a conversation
  Stream<List<ChatMessage>> loadMessagesStream(
    String companyId,
    String conversationId,
  ) {
    return _chatService.getMessagesStream(companyId, conversationId);
  }

  /// Update messages list (from stream)
  void updateMessages(List<ChatMessage> messages, {String? currentUserId, ChatConversation? conversation}) {
    final previousMessageCount = _messages.length;
    _messages = messages;
    
    // Check if we have a new message that should trigger a notification
    // Defer the notification check to after the current build phase
    if (messages.length > previousMessageCount && messages.isNotEmpty && currentUserId != null && conversation != null) {
      final latestMessage = messages.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkForNotification(latestMessage, conversation, currentUserId);
      });
    }
    
    // Defer notifyListeners to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Get messages stream for a conversation
  Stream<List<ChatMessage>> getMessagesStream(
    String companyId,
    String conversationId,
  ) {
    return _chatService.getMessagesStream(companyId, conversationId);
  }

  /// Set current conversation
  Future<void> setCurrentConversation(
    String companyId,
    String conversationId,
    String userId,
  ) async {
    try {
      _currentConversation =
          await _chatService.getConversation(companyId, conversationId);
      
      if (_currentConversation != null) {
        // Mark conversation as read
        await _chatService.markConversationAsRead(
          companyId,
          conversationId,
          userId,
        );
      }
      
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load conversation: $e');
    }
  }

  /// Set chat screen open state
  void setChatScreenOpen(bool isOpen, {String? conversationId}) {
    _isChatScreenOpen = isOpen;
    _currentViewedConversationId = conversationId;
    
    // Clear any pending notifications if chat screen is opened
    if (isOpen) {
      clearPendingNotification();
    }
    
    // Stop monitoring when chat screen is open to avoid conflicts
    if (isOpen) {
      _messageSubscription?.pause();
    } else {
      _messageSubscription?.resume();
    }
    
    // Don't call notifyListeners here to avoid setState during build
  }

  /// Check if a new message should trigger a notification
  void checkForNotification(ChatMessage message, ChatConversation conversation, String currentUserId) {
    print('🔔 Checking for notification: message from ${message.senderId}, current user $currentUserId, sender role ${message.senderRole}');
    print('🔔 Chat screen open: $_isChatScreenOpen, current conversation: $_currentViewedConversationId');
    
    // Don't show notification if chat screen is open and viewing this conversation
    if (_isChatScreenOpen && _currentViewedConversationId == conversation.id) {
      print('🔔 Skipping notification: chat screen open for this conversation');
      return;
    }
    
    // Don't show notification for messages sent by current user
    if (message.senderId == currentUserId) {
      print('🔔 Skipping notification: message from current user');
      return;
    }
    
    // Only show notifications for driver role (admins don't need notifications for their own messages)
    if (message.senderRole != 'admin') {
      print('🔔 Skipping notification: sender is not admin');
      return;
    }
    
    print('🔔 Setting pending notification');
    // Set pending notification
    _pendingNotificationMessage = message;
    _pendingNotificationConversation = conversation;
    notifyListeners();
  }

  /// Clear pending notification
  void clearPendingNotification() {
    _pendingNotificationMessage = null;
    _pendingNotificationConversation = null;
    notifyListeners();
  }

  /// Send a message
  Future<void> sendMessage({
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
      _clearError();
      
      await _chatService.sendMessage(
        companyId: companyId,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        message: message,
        senderImageUrl: senderImageUrl,
        imageUrl: imageUrl,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentType: attachmentType,
      );
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to send message: $e');
    }
  }

  /// Create or get a conversation
  Future<String?> getOrCreateConversation({
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
      _setLoading(true);
      _clearError();
      
      final conversationId = await _chatService.getOrCreateConversation(
        companyId: companyId,
        driverId: driverId,
        driverName: driverName,
        driverImageUrl: driverImageUrl,
        adminId: adminId,
        adminName: adminName,
        adminImageUrl: adminImageUrl,
        deliveryId: deliveryId,
        claimId: claimId,
        vehicleId: vehicleId,
      );
      
      return conversationId;
    } catch (e) {
      _setError('Failed to create conversation: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a message
  Future<void> deleteMessage(
    String companyId,
    String conversationId,
    String messageId,
  ) async {
    try {
      _clearError();
      await _chatService.deleteMessage(
        companyId,
        conversationId,
        messageId,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete message: $e');
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
      _clearError();
      await _chatService.editMessage(
        companyId,
        conversationId,
        messageId,
        newMessage,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to edit message: $e');
    }
  }

  /// Archive a conversation
  Future<void> archiveConversation(
    String companyId,
    String conversationId,
  ) async {
    try {
      _clearError();
      await _chatService.archiveConversation(companyId, conversationId);
      _conversations
          .removeWhere((conv) => conv.id == conversationId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to archive conversation: $e');
    }
  }

  /// Search conversations
  Future<List<ChatConversation>> searchConversations(
    String companyId,
    String query,
  ) async {
    try {
      _clearError();
      return await _chatService.searchConversations(companyId, query);
    } catch (e) {
      _setError('Failed to search conversations: $e');
      return [];
    }
  }

  /// Get conversations for a delivery
  Stream<List<ChatConversation>> getConversationsByDelivery(
    String companyId,
    String deliveryId,
  ) {
    return _chatService.getConversationsByDelivery(companyId, deliveryId);
  }

  /// Get conversations for a claim
  Stream<List<ChatConversation>> getConversationsByClaim(
    String companyId,
    String claimId,
  ) {
    return _chatService.getConversationsByClaim(companyId, claimId);
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _logger.e('❌ ChatProvider Error: $message');
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Clear chat state
  void clearState() {
    _conversations = [];
    _currentConversation = null;
    _messages = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Get unread count for a conversation
  int getUnreadCount(String conversationId) {
    final conv = _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => ChatConversation(
        id: '',
        companyId: '',
        driverId: '',
        driverName: '',
        adminId: '',
        adminName: '',
        participantIds: [],
        participantRoles: [],
        lastMessage: '',
        lastMessageAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return conv.id.isNotEmpty ? conv.unreadCount[''] ?? 0 : 0;
  }
}
