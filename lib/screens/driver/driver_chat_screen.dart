import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/chat_message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/message_bubble.dart';
import '../../models/user_model.dart';

/// Driver chat screen - shows conversation with admin
class DriverChatScreen extends StatefulWidget {
  const DriverChatScreen({super.key});

  @override
  State<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<DriverChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  ChatProvider? _chatProvider;
  bool _hasSetChatScreenOpen = false;

  @override
  void initState() {
    super.initState();
    // Mark chat screen as open (will be updated when conversation loads)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider = context.read<ChatProvider>();
    });
  }

  @override
  void dispose() {
    // Don't call setChatScreenOpen during dispose as it causes issues
    // The notification system handles its own state
    
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(ChatProvider chatProvider) async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _conversationId == null) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    await chatProvider.sendMessage(
      companyId: user.companyId,
      conversationId: _conversationId!,
      senderId: user.id,
      senderName: user.fullName,
      senderRole: user.role.toString().split('.').last,
      message: message,
    );

    _messageController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Chat with Admin'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          return StreamBuilder<List<ChatConversation>>(
            stream: chatProvider.loadConversationsStream(user.companyId, user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final conversations = snapshot.data ?? [];
              
              // Driver should have only one conversation with admin
              if (conversations.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.message_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No conversation yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start a conversation with your admin',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _startConversationWithAdmin(context, chatProvider, user),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Start Conversation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final conversation = conversations.first;
              
              // Only update chat screen open state once when conversation ID is first set
              if (_conversationId != conversation.id) {
                _conversationId = conversation.id;
                _hasSetChatScreenOpen = false;
              }
              
              if (!_hasSetChatScreenOpen && _conversationId != null && mounted) {
                _hasSetChatScreenOpen = true;
                // Don't call setChatScreenOpen here as it's not needed and causes issues
                // The notification system will check _isChatScreenOpen separately
              }

              return Column(
                children: [
                  // Admin info header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: conversation.adminImageUrl != null
                              ? NetworkImage(conversation.adminImageUrl!)
                              : null,
                          child: conversation.adminImageUrl == null
                              ? Text(conversation.adminName[0].toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conversation.adminName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Messages list
                  Expanded(
                    child: StreamBuilder<List<ChatMessage>>(
                      stream: chatProvider.getMessagesStream(
                        user.companyId,
                        conversation.id,
                      ),
                      builder: (context, messageSnapshot) {
                        if (messageSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (messageSnapshot.hasError) {
                          return Center(child: Text('Error: ${messageSnapshot.error}'));
                        }

                        final messages = messageSnapshot.data ?? [];
                        
                        // Don't call updateMessages here - it causes flickering
                        // The global monitoring handles notifications separately
                        
                        if (messages.isEmpty) {
                          return const Center(
                            child: Text('No messages yet. Start the conversation!'),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.senderId == user.id;

                            return MessageBubble(
                              message: message,
                              isCurrentUser: isMe,
                              onEdit: isMe
                                  ? (newText) async {
                                      await chatProvider.editMessage(
                                        user.companyId,
                                        conversation.id,
                                        message.id,
                                        newText,
                                      );
                                    }
                                  : null,
                              onDelete: isMe
                                  ? () async {
                                      await chatProvider.deleteMessage(
                                        user.companyId,
                                        conversation.id,
                                        message.id,
                                      );
                                    }
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Message input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(chatProvider),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: AppTheme.primaryColor,
                          onPressed: () => _sendMessage(chatProvider),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Start conversation with admin
  Future<void> _startConversationWithAdmin(
    BuildContext context,
    ChatProvider chatProvider,
    dynamic user,
  ) async {
    // Get ScaffoldMessenger before async gap
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      // Show loading
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Finding admin...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get first admin from company
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('companyId', isEqualTo: user.companyId)
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No admin found for your company'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final adminDoc = adminSnapshot.docs.first;
      final adminUser = AppUser.fromFirestore(adminDoc);

      // Create conversation
      final conversationId = await chatProvider.getOrCreateConversation(
        companyId: user.companyId,
        driverId: user.id,
        driverName: user.fullName,
        driverImageUrl: user.profileImageUrl,
        adminId: adminUser.id,
        adminName: adminUser.fullName,
        adminImageUrl: adminUser.profileImageUrl,
      );

      if (conversationId != null && mounted) {
        setState(() {
          _conversationId = conversationId;
        });
        
        // Update chat provider with current conversation
        chatProvider.setChatScreenOpen(true, conversationId: conversationId);

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Conversation started! You can now send messages.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
