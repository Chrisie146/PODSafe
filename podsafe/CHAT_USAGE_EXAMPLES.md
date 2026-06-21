# 💬 Chat System - Usage Examples & Scenarios

## Real-World Use Cases

### Scenario 1: Driver Has a Delivery Issue

```dart
// Driver App - Delivery Details Screen
FloatingActionButton(
  onPressed: () async {
    final chatProvider = context.read<ChatProvider>();
    final driver = context.read<AuthProvider>().currentUser;
    
    // Get admin information (from delivery or company)
    final conversationId = await chatProvider.getOrCreateConversation(
      companyId: driver.companyId,
      driverId: driver.id,
      driverName: driver.fullName,
      driverImageUrl: driver.profileImageUrl,
      adminId: delivery.assignedAdminId, // Admin assigned to this delivery
      adminName: 'Admin Team',
      adminImageUrl: null,
      deliveryId: delivery.id, // Link conversation to delivery
    );
    
    // Navigate to chat
    Navigator.pushNamed(
      context,
      '/driver/chat',
      arguments: {'conversationId': conversationId},
    );
  },
  child: const Icon(Icons.message),
  tooltip: 'Ask admin for help',
)

// Driver sends message
await chatProvider.sendMessage(
  companyId: driver.companyId,
  conversationId: conversationId,
  senderId: driver.id,
  senderName: driver.fullName,
  senderRole: 'driver',
  message: 'Customer not home. What should I do?',
  senderImageUrl: driver.profileImageUrl,
);
```

---

### Scenario 2: Admin Reviews Delivery & Needs Info

```dart
// Admin Dashboard - Delivery Details
onDeliverySelected: (delivery) async {
  final chatProvider = context.read<ChatProvider>();
  final admin = context.read<AuthProvider>().currentUser;
  
  // Get driver information
  final driver = await driverService.getDriver(delivery.driverId);
  
  // Create conversation linked to delivery
  final conversationId = await chatProvider.getOrCreateConversation(
    companyId: admin.companyId,
    driverId: delivery.driverId,
    driverName: driver.fullName,
    driverImageUrl: driver.profileImageUrl,
    adminId: admin.id,
    adminName: admin.fullName,
    adminImageUrl: admin.profileImageUrl,
    deliveryId: delivery.id, // Link to delivery
  );
  
  // Navigate to chat
  Navigator.pushNamed(
    context,
    '/admin/chat',
    arguments: {'conversationId': conversationId},
  );
},

// Admin sends message with instructions
await chatProvider.sendMessage(
  companyId: admin.companyId,
  conversationId: conversationId,
  senderId: admin.id,
  senderName: admin.fullName,
  senderRole: 'admin',
  message: 'Customer will be home at 2 PM. Can you deliver then?',
  senderImageUrl: admin.profileImageUrl,
);
```

---

### Scenario 3: Claim Discussion Between Driver & Admin

```dart
// Admin Dashboard - Claims Section
onClaimCreated: (claim) async {
  final chatProvider = context.read<ChatProvider>();
  final admin = context.read<AuthProvider>().currentUser;
  
  // Get driver who filed claim
  final driver = await userService.getUser(claim.submittedBy);
  
  // Create conversation linked to claim
  final conversationId = await chatProvider.getOrCreateConversation(
    companyId: admin.companyId,
    driverId: driver.id,
    driverName: driver.fullName,
    driverImageUrl: driver.profileImageUrl,
    adminId: admin.id,
    adminName: admin.fullName,
    adminImageUrl: admin.profileImageUrl,
    claimId: claim.id, // Link to claim for tracking
  );
  
  // Show notification with chat button
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New Claim Filed'),
      content: Text('Claim from ${driver.fullName}'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(
              context,
              '/admin/chat',
              arguments: {'conversationId': conversationId},
            );
          },
          child: const Text('Chat with Driver'),
        ),
      ],
    ),
  );
},

// Conversation flow:
// Admin: "I see your claim for the damaged package"
// Driver: "Yes, the packaging was torn"
// Admin: "Let me get approval and I'll send you a replacement"
// Driver: "Thank you"
```

---

## Feature Examples

### Example 1: Searching for Conversations

```dart
// In ChatListScreenDesktop - search box
TextField(
  onChanged: (query) async {
    if (query.isEmpty) return;
    
    final results = await chatProvider.searchConversations(
      user.companyId,
      query,
    );
    
    setState(() => _filteredConversations = results);
  },
  decoration: InputDecoration(
    hintText: 'Search by driver name...',
    prefixIcon: const Icon(Icons.search),
  ),
)

// Results:
// - "John Smith" - Last message: "Can I deliver tomorrow?"
// - "John Driver" - Last message: "Package damaged in transit"
```

---

### Example 2: Getting Unread Message Count

```dart
// In Admin Dashboard - show notification badge
StreamBuilder<List<ChatConversation>>(
  stream: chatProvider.loadConversationsStream(
    user.companyId,
    user.id,
  ),
  builder: (context, snapshot) {
    final conversations = snapshot.data ?? [];
    int totalUnread = 0;
    
    for (var conv in conversations) {
      totalUnread += conv.unreadCount[user.id] ?? 0;
    }
    
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.mail),
          onPressed: () => Navigator.pushNamed(context, '/admin/chat'),
        ),
        if (totalUnread > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Badge(
              label: Text(totalUnread > 99 ? '99+' : totalUnread.toString()),
            ),
          ),
      ],
    );
  },
)
```

---

### Example 3: Messaging Flow

```dart
// Complete messaging conversation:

// 1. Admin initiates
Admin: "Hi John, how are the deliveries today?"
         → Message appears instantly

// 2. Driver responds
Driver: "Good morning! 3 deliveries completed, 2 pending"
         → Admin sees in real-time

// 3. Admin sends instructions
Admin: "Can you deliver Route B before noon?"
       → Marked as sent

// 4. Driver confirms
Driver: "Yes, I'll be at those addresses by 11:30 AM"
        → Admin sees immediately

// 5. Admin follows up
Admin: "Perfect! One customer might not be home, so call first"
       → Read status tracked

// 6. Admin edits previous message (if needed)
Admin: "Perfect! One customer might not be home, so call first. 
        His number is 555-1234"
       → Marked as (edited)

// 7. Driver acknowledges
Driver: "Got it! Will call before arriving"
        → Conversation remains for future reference
```

---

### Example 4: Handling Message Delivery Errors

```dart
// Error handling in UI
Future<void> _sendMessage() async {
  if (_messageController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot send empty message')),
    );
    return;
  }

  try {
    await chatProvider.sendMessage(
      // ... parameters
    );
    _messageController.clear();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
    // Message remains in input field for retry
  }
}
```

---

### Example 5: Archiving Old Conversations

```dart
// Archive conversation after resolution
Future<void> _archiveConversation(String conversationId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Archive Conversation?'),
      content: const Text(
        'This conversation will be archived. '
        'You can unarchive it later from settings.',
      ),
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
    await chatProvider.archiveConversation(
      user.companyId,
      conversationId,
    );
    
    // Conversation removed from list but kept in history
    setState(() => _selectedConversationId = null);
  }
}
```

---

### Example 6: Message Edit Flow

```dart
// User long-presses message
onLongPress: () {
  // Show popup menu with options
  showMenu(
    context: context,
    position: RelativeRect.fromRect(
      Offset.zero & size,
      Offset.zero & MediaQuery.of(context).size,
    ),
    items: [
      PopupMenuItem(
        child: const Text('Edit'),
        onTap: () => _startEditMode(),
      ),
      PopupMenuItem(
        child: const Text('Delete'),
        onTap: () => _deleteMessage(),
      ),
    ],
  );
},

// Edit mode:
// Original: "Can you deliver tomorrow?"
// Edited:   "Can you deliver tomorrow by 5 PM?"
//           (edited)
```

---

### Example 7: Conversation Info Panel

```dart
// Long-press conversation header → Show info
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Conversation Details'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Driver', conversation.driverName),
        _buildInfoRow('Admin', conversation.adminName),
        if (conversation.deliveryId != null)
          _buildInfoRow('Linked Delivery', conversation.deliveryId!),
        if (conversation.claimId != null)
          _buildInfoRow('Linked Claim', conversation.claimId!),
        _buildInfoRow('Started', conversation.createdAt.toString()),
        _buildInfoRow('Last Message', conversation.lastMessageAt.toString()),
        _buildInfoRow('Messages', '${messageCount}'),
      ],
    ),
  ),
)
```

---

## Integration Points

### From Delivery Details Screen
```dart
// Button to chat with driver about this delivery
FloatingActionButton(
  onPressed: () => _startChatForDelivery(delivery),
  child: const Icon(Icons.chat),
  tooltip: 'Chat with driver',
)
```

### From Claim Details Screen
```dart
// Button to discuss claim with submitter
FloatingActionButton(
  onPressed: () => _startChatForClaim(claim),
  child: const Icon(Icons.comment),
  tooltip: 'Discuss claim',
)
```

### From Driver Management Screen
```dart
// Quick action to message a driver
IconButton(
  icon: const Icon(Icons.message),
  onPressed: () => _createConversationWithDriver(driver),
  tooltip: 'Send message',
)
```

### From Vehicle Management Screen
```dart
// Contact driver about vehicle issue
IconButton(
  icon: const Icon(Icons.chat),
  onPressed: () => _contactDriverAboutVehicle(vehicle),
  tooltip: 'Chat about vehicle',
)
```

---

## Admin Dashboard Integration

### Add Chat Button to Quick Actions

```dart
// In admin_dashboard_desktop.dart - Quick Actions section

ElevatedButton.icon(
  onPressed: () => Navigator.pushNamed(context, '/admin/chat'),
  icon: const Icon(Icons.mail),
  label: const Text('Messages'),
),

// With unread badge
Stack(
  children: [
    ElevatedButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/admin/chat'),
      icon: const Icon(Icons.mail),
      label: const Text('Messages'),
    ),
    if (unreadCount > 0)
      Positioned(
        right: 8,
        top: 8,
        child: Badge(label: Text(unreadCount.toString())),
      ),
  ],
)
```

---

## Data Flow Diagram

```
User Action (e.g., "Send Message")
         ↓
UI Layer (ChatDetailScreenDesktop)
         ↓
Provider Layer (ChatProvider.sendMessage())
         ↓
Service Layer (ChatService.sendMessage())
         ↓
Firestore Database
         ↓
Stream Update
         ↓
All Participants Receive Update in Real-time
         ↓
UI Re-renders with New Message
```

---

## Performance Optimization Tips

### Tip 1: Lazy Load Messages
```dart
// Load messages in batches
final messages = await chatService.getMessages(
  companyId,
  conversationId,
  limit: 50,
  startAfter: lastDocument,
);
```

### Tip 2: Cache Avatars
```dart
// Use cached_network_image
CachedNetworkImage(
  imageUrl: user.profileImageUrl,
  placeholder: (context, url) => CircleAvatar(child: Text(user.fullName[0])),
)
```

### Tip 3: Debounce Search
```dart
// Don't search on every keystroke
_searchDebounce = Timer(const Duration(milliseconds: 500), () {
  _performSearch(query);
});
```

---

## Testing Example Scenarios

### Test 1: Complete Conversation Flow
1. Admin creates conversation with driver
2. Admin sends message
3. Driver receives message in real-time
4. Driver responds
5. Admin sees response
6. Admin edits message
7. Driver sees edited message
8. Admin deletes message
9. Driver sees deletion

### Test 2: Multi-Admin Scenario
1. Multiple admins with same company
2. Each can start conversation with driver
3. Conversations kept separate
4. No cross-conversation bleeding

### Test 3: Multi-Company Isolation
1. Company A admin cannot see Company B conversations
2. Company B driver cannot message Company A
3. Company IDs enforced on all operations

---

## Error Scenarios & Handling

### Scenario: Network Timeout
```
User sends message
→ Network fails
→ Message stays in input field
→ Show error: "Failed to send. Retry?"
→ User can retry
```

### Scenario: User Loses Permission
```
User has conversation open
→ Gets removed from company
→ Chat screen shows: "Access denied"
→ User redirected to login
```

### Scenario: Message Size Limit
```
User pastes large message (>5000 chars)
→ "Message too long (XXXX/5000)"
→ Submit button disabled
→ User must trim message
```

---

**These examples cover the most common use cases for your PODSafe chat system. Adapt as needed for your specific workflows!**
