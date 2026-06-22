/**
 * Ported from lib/models/chat_conversation_model.dart and
 * lib/models/chat_message_model.dart (verified against source on 2026-06-21).
 */

/** 'admin' or 'driver' — kept as a plain string union to match the loosely-typed Dart field. */
export type ChatParticipantRole = 'admin' | 'driver';

export interface ChatConversation {
  id: string;
  companyId: string;
  driverId: string;
  driverName: string;
  driverImageUrl?: string;
  /** Primary admin (conversation starter). */
  adminId: string;
  adminName: string;
  adminImageUrl?: string;
  /** All participants (driverId + admin(s)). */
  participantIds: string[];
  /** 'admin' or 'driver', parallel to participantIds. */
  participantRoles: string[];
  lastMessage: string;
  lastMessageAt: Date;
  /** Optional: linked delivery. */
  deliveryId?: string;
  /** Optional: linked claim. */
  claimId?: string;
  /** Optional: linked vehicle. */
  vehicleId?: string;
  isActive: boolean;
  isArchived: boolean;
  createdAt: Date;
  updatedAt: Date;
  /** {userId: isRead} */
  readStatus: Record<string, boolean>;
  /** {userId: count} */
  unreadCount: Record<string, number>;
}

export interface ChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  senderName: string;
  /** 'admin' or 'driver' */
  senderRole: string;
  senderImageUrl?: string;
  message: string;
  sentAt: Date;
  isRead: boolean;
  /** For image attachments. */
  imageUrl?: string;
  /** For file attachments. */
  attachmentUrl?: string;
  attachmentName?: string;
  /** 'image', 'file', etc. */
  attachmentType?: string;
  /** For message threads. */
  replyToMessageId?: string;
  editedAt?: Date;
  isEdited: boolean;
}
