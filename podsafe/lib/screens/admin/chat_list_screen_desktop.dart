import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_conversation_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/message_bubble.dart';
import 'chat_detail_screen_desktop.dart';

/// Desktop chat list screen for admin
class ChatListScreenDesktop extends StatefulWidget {
  const ChatListScreenDesktop({super.key});

  @override
  State<ChatListScreenDesktop> createState() => _ChatListScreenDesktopState();
}

class _ChatListScreenDesktopState extends State<ChatListScreenDesktop> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedConversationId;
  List<ChatConversation> _filteredConversations = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
    });
  }

  void _performSearch(String query, ChatProvider chatProvider) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      final results = await chatProvider.searchConversations(
        user.companyId,
        query,
      );
      setState(() {
        _filteredConversations = results;
      });
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
      appBar: AppBar(
        title: const Text('💬 Messages'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Start new conversation',
            child: IconButton(
              icon: const Icon(Icons.add_comment),
              onPressed: () => _showNewConversationDialog(context, user),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Chat list sidebar
          SizedBox(
            width: 350,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _performSearch(value, context.read<ChatProvider>()),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _isSearching = false);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                // Conversations list
                Expanded(
                  child: _isSearching
                      ? _buildSearchResults()
                      : _buildConversationsList(user.id, user.companyId),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            color: Colors.grey[300],
          ),
          // Chat detail view
          Expanded(
            flex: 2,
            child: _selectedConversationId != null
                ? ChatDetailScreenDesktop(
                    conversationId: _selectedConversationId!,
                    onClose: () {
                      setState(() => _selectedConversationId = null);
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Select a conversation to start messaging',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList(String userId, String companyId) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return StreamBuilder<List<ChatConversation>>(
          stream: chatProvider.loadConversationsStream(companyId, userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final conversations = snapshot.data ?? [];
            if (conversations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.inbox,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text('No conversations yet'),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final unreadCount = conv.unreadCount[userId] ?? 0;

                return ChatListItem(
                  conversationId: conv.id,
                  participantName: conv.driverName,
                  participantImageUrl: conv.driverImageUrl,
                  lastMessage: conv.lastMessage,
                  lastMessageTime: conv.lastMessageAt,
                  unreadCount: unreadCount,
                  isSelected: _selectedConversationId == conv.id,
                  onTap: () {
                    setState(() => _selectedConversationId = conv.id);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_filteredConversations.isEmpty) {
      return const Center(
        child: Text('No conversations found'),
      );
    }

    return ListView.builder(
      itemCount: _filteredConversations.length,
      itemBuilder: (context, index) {
        final conv = _filteredConversations[index];
        return ChatListItem(
          conversationId: conv.id,
          participantName: conv.driverName,
          participantImageUrl: conv.driverImageUrl,
          lastMessage: conv.lastMessage,
          lastMessageTime: conv.lastMessageAt,
          unreadCount: conv.unreadCount[context.read<AuthProvider>().currentUser?.id] ?? 0,
          isSelected: _selectedConversationId == conv.id,
          onTap: () {
            setState(() => _selectedConversationId = conv.id);
          },
        );
      },
    );
  }

  void _showNewConversationDialog(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (context) => _DriverSelectionDialog(user: user, onDriverSelected: (driverId, driverName, driverImageUrl) {
        setState(() => _selectedConversationId = null);
        _createConversation(context, user, driverId, driverName, driverImageUrl);
      }),
    );
  }

  Future<void> _createConversation(
    BuildContext context,
    dynamic user,
    String driverId,
    String driverName,
    String? driverImageUrl,
  ) async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final adminUser = authProvider.currentUser;

    try {
      final conversationId = await chatProvider.getOrCreateConversation(
        companyId: user.companyId,
        driverId: driverId,
        driverName: driverName,
        driverImageUrl: driverImageUrl,
        adminId: adminUser?.id ?? '',
        adminName: adminUser?.fullName ?? 'Admin',
        adminImageUrl: adminUser?.profileImageUrl,
      );

      if (mounted) {
        setState(() => _selectedConversationId = conversationId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation started!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _DriverSelectionDialog extends StatefulWidget {
  final dynamic user;
  final Function(String driverId, String driverName, String? driverImageUrl) onDriverSelected;

  const _DriverSelectionDialog({
    required this.user,
    required this.onDriverSelected,
  });

  @override
  State<_DriverSelectionDialog> createState() => _DriverSelectionDialogState();
}

class _DriverSelectionDialogState extends State<_DriverSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Select Driver',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search drivers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('companyId', isEqualTo: widget.user.companyId)
                    .where('role', isEqualTo: 'driver')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final drivers = snapshot.data?.docs ?? [];
                  
                  if (drivers.isEmpty) {
                    return const Center(
                      child: Text('No active drivers found'),
                    );
                  }

                  // Filter by search query
                  final filteredDrivers = drivers.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    return fullName.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();

                  if (filteredDrivers.isEmpty) {
                    return const Center(
                      child: Text('No drivers match your search'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDrivers.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDrivers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final driverId = doc.id;
                      final driverName = data['fullName'] ?? 'Unknown';
                      final driverEmail = data['email'] ?? '';
                      final driverImage = data['profileImageUrl'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: driverImage != null
                              ? NetworkImage(driverImage)
                              : null,
                          child: driverImage == null
                              ? Text(driverName[0].toUpperCase())
                              : null,
                        ),
                        title: Text(driverName),
                        subtitle: Text(driverEmail),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onDriverSelected(driverId, driverName, driverImage);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

