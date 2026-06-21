import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../main.dart';

/// Global notification overlay for chat messages
class ChatNotificationOverlay extends StatefulWidget {
  const ChatNotificationOverlay({super.key});

  @override
  State<ChatNotificationOverlay> createState() => _ChatNotificationOverlayState();
}

class _ChatNotificationOverlayState extends State<ChatNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final hasNotification = chatProvider.hasPendingNotification;
        print('🔔 Overlay build: hasNotification = $hasNotification');
        
        // Animate in when notification appears
        if (hasNotification && !_isVisible) {
          print('🔔 Showing notification');
          _isVisible = true;
          _animationController.forward();
        } else if (!hasNotification && _isVisible) {
          print('🔔 Hiding notification');
          _isVisible = false;
          _animationController.reverse();
        }
        
        if (!hasNotification) {
          return const SizedBox.shrink();
        }

        final message = chatProvider.pendingNotificationMessage!;
        final conversation = chatProvider.pendingNotificationConversation!;
        print('🔔 Building notification for message: ${message.message}');

        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - _animation.value)),
                child: Opacity(
                  opacity: _animation.value,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A73E8),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.message,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'New Message from ${conversation.adminName}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Message content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.message,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTime(message.sentAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Actions
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      _animationController.reverse().then((_) {
                                        chatProvider.clearPendingNotification();
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Dismiss'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      print('🔔 View Message clicked');
                                      
                                      // Clear notification first
                                      chatProvider.clearPendingNotification();
                                      _animationController.reverse();
                                      
                                      // Navigate using global navigator key
                                      Future.delayed(const Duration(milliseconds: 150), () {
                                        if (navigatorKey.currentState?.mounted == true) {
                                          try {
                                            print('🔔 Attempting navigation with global key');
                                            navigatorKey.currentState!.pushNamed('/driver/chat');
                                            print('🔔 Navigation completed');
                                          } catch (e) {
                                            print('🔔 Navigation error: $e');
                                          }
                                        } else {
                                          print('🔔 Navigator state not available');
                                        }
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A73E8),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('View Message'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}