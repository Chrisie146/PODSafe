import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message_model.dart';
import '../utils/theme.dart';

/// Widget to display a single message bubble
class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final VoidCallback? onDelete;
  final Function(String)? onEdit;
  final ChatMessage? replyToMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onDelete,
    this.onEdit,
    this.replyToMessage,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showOptions = false;
  TextEditingController? _editController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.message);
  }

  @override
  void dispose() {
    _editController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: widget.isCurrentUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Reply preview if exists
        if (widget.replyToMessage != null)
          Padding(
            padding: EdgeInsets.only(
              left: widget.isCurrentUser ? 0 : 12,
              right: widget.isCurrentUser ? 12 : 0,
              bottom: 4,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to ${widget.replyToMessage!.senderName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.replyToMessage!.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        // Main message bubble
        GestureDetector(
          onLongPress: () {
            if (widget.isCurrentUser) {
              setState(() => _showOptions = !_showOptions);
            }
          },
          child: Row(
            mainAxisAlignment: widget.isCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_showOptions && widget.isCurrentUser)
                PopupMenuButton(
                  position: PopupMenuPosition.under,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                      onTap: () {
                        setState(() => _isEditing = true);
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      onTap: () => widget.onDelete?.call(),
                    ),
                  ],
                ),
              Flexible(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isCurrentUser
                        ? AppTheme.primaryColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isEditing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _editController,
                                decoration: const InputDecoration.collapsed(
                                  hintText: '',
                                ),
                                style: TextStyle(
                                  color: widget.isCurrentUser
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () {
                                widget.onEdit?.call(_editController!.text);
                                setState(() => _isEditing = false);
                              },
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: widget.isCurrentUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Image attachment
                            if (widget.message.imageUrl != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image:
                                        NetworkImage(widget.message.imageUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            // Message text
                            Text(
                              widget.message.message,
                              style: TextStyle(
                                color: widget.isCurrentUser
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                            // File attachment info
                            if (widget.message.attachmentUrl != null)
                              SizedBox(height: 8),
                            if (widget.message.attachmentUrl != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.isCurrentUser
                                      ? Colors.white24
                                      : Colors.grey[400],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.attachment,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.message.attachmentName ??
                                          'Attachment',
                                      style: TextStyle(
                                        color: widget.isCurrentUser
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Edited indicator
                            if (widget.message.isEdited)
                              SizedBox(height: 4),
                            if (widget.message.isEdited)
                              Text(
                                '(edited)',
                                style: TextStyle(
                                  color: widget.isCurrentUser
                                      ? Colors.white70
                                      : Colors.grey,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        // Timestamp
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          child: Text(
            DateFormat('HH:mm').format(widget.message.sentAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}

/// Chat list item widget
class ChatListItem extends StatelessWidget {
  final String conversationId;
  final String participantName;
  final String? participantImageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isSelected;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.conversationId,
    required this.participantName,
    this.participantImageUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().difference(lastMessageTime).inDays == 0;
    final timeString = isToday
        ? DateFormat('HH:mm').format(lastMessageTime)
        : DateFormat('MMM dd').format(lastMessageTime);

    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: Colors.grey[100],
      leading: CircleAvatar(
        backgroundImage: participantImageUrl != null
            ? NetworkImage(participantImageUrl!)
            : null,
        child: participantImageUrl == null
            ? Text(participantName[0].toUpperCase())
            : null,
      ),
      title: Text(
        participantName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            timeString,
            style: const TextStyle(fontSize: 12),
          ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
/// Typing indicator widget
class TypingIndicator extends StatefulWidget {
  final String userName;

  const TypingIndicator({
    super.key,
    required this.userName,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      3,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      )..repeat(
          min: 0,
          max: 1,
          period: const Duration(milliseconds: 1200),
          reverse: true,
        ),
    );

    for (var i = 0; i < _animationControllers.length; i++) {
      _animationControllers[i].forward(from: (i * 0.1));
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${widget.userName} is typing',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 4),
        Row(
          children: List.generate(
            3,
            (i) => ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.2)
                  .animate(_animationControllers[i]),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
