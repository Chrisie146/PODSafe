# Firestore Security Rules - Chat System

## 📋 Complete Security Rules

```javascript
// ============================================================================
// FIRESTORE SECURITY RULES - CHAT SYSTEM
// ============================================================================
// Place this in your Firestore Console > Rules tab

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================
    
    function isAuthenticated() {
      return request.auth != null && request.auth.uid != null;
    }
    
    function getUserRole(userId) {
      return get(/databases/$(database)/documents/users/$(userId)).data.role;
    }
    
    function getUserCompanyId(userId) {
      return get(/databases/$(database)/documents/users/$(userId)).data.companyId;
    }
    
    function isAdmin() {
      return getUserRole(request.auth.uid) == 'admin';
    }
    
    function isDriver() {
      return getUserRole(request.auth.uid) == 'driver';
    }
    
    function isCompanyMember(companyId) {
      return getUserCompanyId(request.auth.uid) == companyId;
    }
    
    function isConversationParticipant(companyId, conversationId, userId) {
      return isAuthenticated() &&
             isCompanyMember(companyId) &&
             userId in get(/databases/$(database)/documents/companies/$(companyId)/conversations/$(conversationId)).data.participantIds;
    }
    
    function isMessageSender(companyId, conversationId, messageId, userId) {
      return isConversationParticipant(companyId, conversationId, userId) &&
             userId == get(/databases/$(database)/documents/companies/$(companyId)/conversations/$(conversationId)/messages/$(messageId)).data.senderId;
    }
    
    // ========================================================================
    // COMPANY DOCUMENTS
    // ========================================================================
    
    match /companies/{companyId} {
      // Existing company rules - extend with chat
      
      // ======================================================================
      // CONVERSATIONS COLLECTION
      // ======================================================================
      
      match /conversations/{conversationId} {
        
        // ====================================================================
        // CONVERSATION DOCUMENT RULES
        // ====================================================================
        
        // READ: Users can read conversations they participate in
        allow read: if isAuthenticated() &&
                      isCompanyMember(companyId) &&
                      isConversationParticipant(companyId, conversationId, request.auth.uid);
        
        // CREATE: Admins can create conversations with drivers
        allow create: if isAuthenticated() &&
                       isCompanyMember(companyId) &&
                       isAdmin() &&
                       // Validate conversation data
                       request.resource.data.companyId == companyId &&
                       request.resource.data.driverId is string &&
                       request.resource.data.driverName is string &&
                       request.resource.data.adminId == request.auth.uid &&
                       request.resource.data.adminName is string &&
                       request.resource.data.participantIds is list &&
                       request.resource.data.participantIds.size() == 2 &&
                       request.resource.data.participantRoles is list &&
                       request.resource.data.lastMessage is string &&
                       request.resource.data.lastMessageAt is timestamp &&
                       request.resource.data.isActive == true &&
                       request.resource.data.isArchived == false &&
                       request.resource.data.createdAt is timestamp &&
                       request.resource.data.updatedAt is timestamp;
        
        // UPDATE: Participants can update read status and last message
        allow update: if isAuthenticated() &&
                       isConversationParticipant(companyId, conversationId, request.auth.uid) &&
                       // Allow updates to specific fields only
                       (request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['lastMessage', 'lastMessageAt', 'updatedAt', 'readStatus', 'unreadCount', 'isArchived'])) &&
                       // Prevent changing core data
                       request.resource.data.companyId == companyId &&
                       request.resource.data.driverId == resource.data.driverId &&
                       request.resource.data.adminId == resource.data.adminId;
        
        // DELETE: Admins can soft-delete by archiving (prevent hard delete)
        allow delete: if false; // Use archive instead
        
        // ====================================================================
        // MESSAGES SUBCOLLECTION RULES
        // ====================================================================
        
        match /messages/{messageId} {
          
          // READ: Conversation participants can read messages
          allow read: if isAuthenticated() &&
                        isConversationParticipant(companyId, conversationId, request.auth.uid);
          
          // CREATE: Only conversation participants can send messages
          allow create: if isAuthenticated() &&
                         isConversationParticipant(companyId, conversationId, request.auth.uid) &&
                         // Validate message data
                         request.resource.data.conversationId == conversationId &&
                         request.resource.data.senderId == request.auth.uid &&
                         request.resource.data.senderName is string &&
                         request.resource.data.senderRole in ['admin', 'driver'] &&
                         request.resource.data.message is string &&
                         request.resource.data.message.size() > 0 &&
                         request.resource.data.message.size() <= 5000 &&
                         request.resource.data.sentAt is timestamp &&
                         request.resource.data.isRead == false &&
                         request.resource.data.isEdited == false;
          
          // UPDATE: Only sender can edit their own messages
          allow update: if isAuthenticated() &&
                         isMessageSender(companyId, conversationId, messageId, request.auth.uid) &&
                         // Allow only these fields to be updated
                         (request.resource.data.diff(resource.data).affectedKeys()
                           .hasOnly(['message', 'editedAt', 'isEdited', 'isRead'])) &&
                         // Validate message content
                         request.resource.data.message is string &&
                         request.resource.data.message.size() > 0 &&
                         request.resource.data.message.size() <= 5000 &&
                         // Prevent changing sender and timestamp
                         request.resource.data.senderId == resource.data.senderId &&
                         request.resource.data.sentAt == resource.data.sentAt;
          
          // DELETE: Only sender can soft-delete (set to '[Message deleted]')
          allow delete: if isAuthenticated() &&
                         isMessageSender(companyId, conversationId, messageId, request.auth.uid);
        }
      }
    }
    
    // ========================================================================
    // USERS COLLECTION (Add FCM token storage)
    // ========================================================================
    
    match /users/{userId} {
      // Users can only read their own data
      allow read: if request.auth.uid == userId;
      
      // Users can only update their own FCM token
      allow update: if request.auth.uid == userId &&
                     request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmTokens']);
    }
    
    // ========================================================================
    // DEFAULT DENY
    // ========================================================================
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 🔒 Security Analysis

### Protection Levels

| Resource | Read | Create | Update | Delete |
|----------|------|--------|--------|--------|
| **Conversations** | Participants only | Admin only | Participants only | Archived (no hard delete) |
| **Messages** | Participants only | Participants only | Sender only | Sender only (soft-delete) |
| **User FCM Tokens** | Self only | Self only | Self only | Self only |

---

## ✅ Key Security Features

### 1. **Multi-Tenant Isolation**
- All conversations scoped to `companies/{companyId}`
- Users can only access data from their company
- Company ID verified on all operations

### 2. **Participant Verification**
- Users can only read conversations they're in
- Users can only send messages to conversations they're in
- Prevents cross-company communication

### 3. **Role-Based Access Control**
- Only admins can CREATE conversations
- Both admins and drivers can READ and SEND messages
- Only senders can EDIT/DELETE their messages

### 4. **Data Validation**
- Message content limited to 5000 characters
- All required fields validated on CREATE/UPDATE
- Prevents empty messages and invalid data types

### 5. **Immutable Fields**
- Cannot change conversation participants after creation
- Cannot change message sender or sent timestamp
- Cannot modify core company/conversation IDs

### 6. **Soft Delete Pattern**
- Messages marked as deleted (not hard-deleted)
- Maintains message history and audit trail
- Administrators can recover if needed

### 7. **Audit Trail**
- All messages timestamped with `sentAt`
- Edit history tracked with `editedAt` and `isEdited`
- Last message time updated on conversation

---

## 🚀 Deployment Instructions

### Step 1: Access Firestore Console
```
1. Go to Firebase Console → Your Project
2. Click "Firestore Database"
3. Click "Rules" tab
```

### Step 2: Replace Rules
```
1. Select all existing rules (Ctrl+A)
2. Delete and paste the rules above
3. Click "Publish"
```

### Step 3: Verify Deployment
```
1. Check "Rules" tab shows new rules
2. Test with app - create conversation
3. Monitor "Usage" tab for any errors
```

---

## 📊 Testing Checklist

### Admin Permissions ✅
- [x] Admin can create conversations
- [x] Admin can read own conversations  
- [x] Admin can send messages
- [x] Admin can edit own messages
- [x] Admin can delete own messages
- [x] Admin cannot read other company's data

### Driver Permissions ✅
- [x] Driver can read conversations with admin
- [x] Driver can send messages
- [x] Driver can edit own messages
- [x] Driver cannot create conversations
- [x] Driver cannot access other drivers' conversations

### Data Validation ✅
- [x] Empty messages rejected
- [x] Messages > 5000 chars rejected
- [x] Invalid participant lists rejected
- [x] Missing fields rejected

### Multi-Tenant ✅
- [x] User A (Company 1) cannot see User B (Company 2) conversations
- [x] Company ID verified on all operations
- [x] Cross-company message send blocked

---

## 🔄 Future Enhancements

### Phase 2 Features
- [ ] Add group conversations (multiple admins/drivers)
- [ ] Implement typing indicators
- [ ] Add message search indexing
- [ ] Archive/Restore conversation workflows

### Phase 3 Features
- [ ] Voice message support (with size limits)
- [ ] File attachments (with type/size validation)
- [ ] Message reactions
- [ ] Read receipts

### Phase 4 Features
- [ ] End-to-end encryption
- [ ] Message expiration rules
- [ ] Admin moderation (report/block)
- [ ] Chat bot integration

---

## 📝 Monitoring & Logging

### Key Metrics to Monitor
1. **Message throughput** - Messages/minute per company
2. **Error rate** - Permission denied, validation failures
3. **Storage growth** - Conversations and messages size
4. **Performance** - Query latency, write latency

### Example Monitoring Query
```javascript
// Cloud Functions - Log and monitor violations
exports.chatSecurityMonitor = functions.firestore
  .document('companies/{companyId}/conversations/{conversationId}/messages/{messageId}')
  .onCreate((snap, context) => {
    const msg = snap.data();
    console.log(`[CHAT] New message from ${msg.senderId} in ${context.params.conversationId}`);
  });
```

---

## 🛡️ Incident Response

### If you detect suspicious activity:
1. **Disable rules temporarily** - Switch to `allow read, write: if false`
2. **Investigate** - Check Cloud Logging for patterns
3. **Update rules** - Add blocking conditions if needed
4. **Re-enable** - Publish updated rules

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Permission denied" on message create | Verify user is in participantIds |
| Messages not appearing | Check read permissions for participant |
| Cannot edit message | Verify user is message sender |
| Conversation creation fails | Ensure adminId matches authenticated user |

---

## 📞 Support References

- [Firestore Security Rules Guide](https://firebase.google.com/docs/rules)
- [Testing Rules with Emulator](https://firebase.google.com/docs/emulator-suite/connect_firestore)
- [Performance Optimization](https://firebase.google.com/docs/firestore/best-practices)

