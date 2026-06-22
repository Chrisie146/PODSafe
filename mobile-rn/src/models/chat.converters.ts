import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { ChatConversation, ChatMessage } from './chat';

/**
 * Ported from ChatConversation.fromFirestore/toMap and ChatMessage.fromFirestore/toMap
 * in lib/models/chat_conversation_model.dart and lib/models/chat_message_model.dart
 * (verified against source on 2026-06-21).
 */

export function chatConversationFromFirestore(
  doc: FirebaseFirestoreTypes.DocumentSnapshot | FirebaseFirestoreTypes.QueryDocumentSnapshot,
): ChatConversation {
  const data = doc.data() ?? {};

  return {
    id: doc.id,
    companyId: data.companyId ?? '',
    driverId: data.driverId ?? '',
    driverName: data.driverName ?? 'Unknown Driver',
    driverImageUrl: data.driverImageUrl,
    adminId: data.adminId ?? '',
    adminName: data.adminName ?? 'Unknown Admin',
    adminImageUrl: data.adminImageUrl,
    participantIds: Array.isArray(data.participantIds) ? data.participantIds : [],
    participantRoles: Array.isArray(data.participantRoles) ? data.participantRoles : [],
    lastMessage: data.lastMessage ?? '',
    lastMessageAt: data.lastMessageAt?.toDate?.() ?? new Date(),
    deliveryId: data.deliveryId,
    claimId: data.claimId,
    vehicleId: data.vehicleId,
    isActive: data.isActive ?? true,
    isArchived: data.isArchived ?? false,
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    updatedAt: data.updatedAt?.toDate?.() ?? new Date(),
    readStatus: data.readStatus ?? {},
    unreadCount: data.unreadCount ?? {},
  };
}

export function chatConversationToFirestore(conversation: ChatConversation): Record<string, unknown> {
  return {
    companyId: conversation.companyId,
    driverId: conversation.driverId,
    driverName: conversation.driverName,
    driverImageUrl: conversation.driverImageUrl ?? null,
    adminId: conversation.adminId,
    adminName: conversation.adminName,
    adminImageUrl: conversation.adminImageUrl ?? null,
    participantIds: conversation.participantIds,
    participantRoles: conversation.participantRoles,
    lastMessage: conversation.lastMessage,
    lastMessageAt: firestore.Timestamp.fromDate(conversation.lastMessageAt),
    deliveryId: conversation.deliveryId ?? null,
    claimId: conversation.claimId ?? null,
    vehicleId: conversation.vehicleId ?? null,
    isActive: conversation.isActive,
    isArchived: conversation.isArchived,
    createdAt: firestore.Timestamp.fromDate(conversation.createdAt),
    updatedAt: firestore.Timestamp.fromDate(conversation.updatedAt),
    readStatus: conversation.readStatus,
    unreadCount: conversation.unreadCount,
  };
}

export function chatMessageFromFirestore(
  doc: FirebaseFirestoreTypes.DocumentSnapshot | FirebaseFirestoreTypes.QueryDocumentSnapshot,
): ChatMessage {
  const data = doc.data() ?? {};

  return {
    id: doc.id,
    conversationId: data.conversationId ?? '',
    senderId: data.senderId ?? '',
    senderName: data.senderName ?? 'Unknown',
    senderRole: data.senderRole ?? 'driver',
    senderImageUrl: data.senderImageUrl,
    message: data.message ?? '',
    sentAt: data.sentAt?.toDate?.() ?? new Date(),
    isRead: data.isRead ?? false,
    imageUrl: data.imageUrl,
    attachmentUrl: data.attachmentUrl,
    attachmentName: data.attachmentName,
    attachmentType: data.attachmentType,
    replyToMessageId: data.replyToMessageId,
    editedAt: data.editedAt?.toDate?.(),
    isEdited: data.isEdited ?? false,
  };
}

export function chatMessageToFirestore(message: ChatMessage): Record<string, unknown> {
  return {
    conversationId: message.conversationId,
    senderId: message.senderId,
    senderName: message.senderName,
    senderRole: message.senderRole,
    senderImageUrl: message.senderImageUrl ?? null,
    message: message.message,
    sentAt: firestore.Timestamp.fromDate(message.sentAt),
    isRead: message.isRead,
    imageUrl: message.imageUrl ?? null,
    attachmentUrl: message.attachmentUrl ?? null,
    attachmentName: message.attachmentName ?? null,
    attachmentType: message.attachmentType ?? null,
    replyToMessageId: message.replyToMessageId ?? null,
    editedAt: message.editedAt ? firestore.Timestamp.fromDate(message.editedAt) : null,
    isEdited: message.isEdited,
  };
}
