import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/message_bubble.dart';

/// Desktop chat detail screen for viewing and sending messages
class ChatDetailScreenDesktop extends StatefulWidget {
  final String conversationId;
  final VoidCallback? onClose;

  const ChatDetailScreenDesktop({
    super.key,
    required this.conversationId,
    this.onClose,
  });

  @override
  State<ChatDetailScreenDesktop> createState() =>
      _ChatDetailScreenDesktopState();
}

class _ChatDetailScreenDesktopState extends State<ChatDetailScreenDesktop> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await context.read<ChatProvider>().sendMessage(
        companyId: user.companyId,
        conversationId: widget.conversationId,
        senderId: user.id,
        senderName: user.fullName,
        senderRole: user.role.toString().split('.').last,
        message: _messageController.text,
        senderImageUrl: user.profileImageUrl,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
      appBar: _buildAppBar(user.companyId),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _buildMessagesList(user),
          ),
          // Divider
          Container(
            height: 1,
            color: Colors.grey[300],
          ),
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String companyId) {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final conv = chatProvider.currentConversation;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conv?.driverName ?? 'Loading...'),
              if (conv != null)
                Text(
                  '${conv.participantIds.length} participants',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showConversationInfo(companyId),
        ),
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => _archiveConversation(companyId),
        ),
      ],
    );
  }

  Widget _buildMessagesList(var user) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return StreamBuilder<List<ChatMessage>>(
          stream: chatProvider.loadMessagesStream(
            user.companyId,
            widget.conversationId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final messages = snapshot.data ?? [];
            if (messages.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text('No messages yet. Start the conversation!'),
                  ],
                ),
              );
            }

            // Don't call updateMessages here as it causes setState during build
            // The messages are already available from the stream
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isCurrentUser = message.senderId == user.id;

                return MessageBubble(
                  message: message,
                  isCurrentUser: isCurrentUser,
                  onDelete: isCurrentUser
                      ? () => _deleteMessage(
                          user.companyId, message.id)
                      : null,
                  onEdit: isCurrentUser
                      ? (newMessage) =>
                          _editMessage(user.companyId, message.id, newMessage)
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              enabled: !_isLoading,
              maxLines: null,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _isLoading ? null : _sendMessage,
            backgroundColor: AppTheme.primaryColor,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String companyId, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<ChatProvider>().deleteMessage(
        companyId,
        widget.conversationId,
        messageId,
      );
    }
  }

  Future<void> _editMessage(
    String companyId,
    String messageId,
    String newMessage,
  ) async {
    await context.read<ChatProvider>().editMessage(
      companyId,
      widget.conversationId,
      messageId,
      newMessage,
    );
  }

  Future<void> _archiveConversation(String companyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Conversation'),
        content: const Text('Archive this conversation? You can unarchive it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<ChatProvider>().archiveConversation(
        companyId,
        widget.conversationId,
      );
      widget.onClose?.call();
    }
  }

  void _showConversationInfo(String companyId) {
    final conv = context.read<ChatProvider>().currentConversation;
    if (conv == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conversation Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Driver', conv.driverName),
            if (conv.deliveryId != null) _buildInfoRow('Delivery ID', conv.deliveryId!),
            if (conv.claimId != null) _buildInfoRow('Claim ID', conv.claimId!),
            if (conv.vehicleId != null) _buildInfoRow('Vehicle ID', conv.vehicleId!),
            _buildInfoRow('Created', conv.createdAt.toString()),
            _buildInfoRow('Last Message', conv.lastMessageAt.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
