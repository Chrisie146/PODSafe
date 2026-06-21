import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single message in a chat conversation
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'admin' or 'driver'
  final String? senderImageUrl;
  final String message;
  final DateTime sentAt;
  final bool isRead;
  final String? imageUrl; // For image attachments
  final String? attachmentUrl; // For file attachments
  final String? attachmentName;
  final String? attachmentType; // 'image', 'file', etc.
  final String? replyToMessageId; // For message threads
  final DateTime? editedAt;
  final bool isEdited;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderImageUrl,
    required this.message,
    required this.sentAt,
    this.isRead = false,
    this.imageUrl,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.replyToMessageId,
    this.editedAt,
    this.isEdited = false,
  });

  /// Convert ChatMessage to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'senderImageUrl': senderImageUrl,
      'message': message,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'replyToMessageId': replyToMessageId,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'isEdited': isEdited,
    };
  }

  /// Create ChatMessage from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ChatMessage(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderRole: data['senderRole'] ?? 'driver',
      senderImageUrl: data['senderImageUrl'],
      message: data['message'] ?? '',
      sentAt: data['sentAt'] != null
          ? (data['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      attachmentUrl: data['attachmentUrl'],
      attachmentName: data['attachmentName'],
      attachmentType: data['attachmentType'],
      replyToMessageId: data['replyToMessageId'],
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      isEdited: data['isEdited'] ?? false,
    );
  }

  /// Copy with modifications
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderImageUrl,
    String? message,
    DateTime? sentAt,
    bool? isRead,
    String? imageUrl,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    String? replyToMessageId,
    DateTime? editedAt,
    bool? isEdited,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderImageUrl: senderImageUrl ?? this.senderImageUrl,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentType: attachmentType ?? this.attachmentType,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      editedAt: editedAt ?? this.editedAt,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  @override
  String toString() => 'ChatMessage($id, from: $senderName, sentAt: $sentAt)';
}
