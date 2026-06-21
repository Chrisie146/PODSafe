import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a chat conversation between a driver and admin(s)
class ChatConversation {
  final String id;
  final String companyId;
  final String driverId;
  final String driverName;
  final String? driverImageUrl;
  final String adminId; // Primary admin (conversation starter)
  final String adminName;
  final String? adminImageUrl;
  final List<String> participantIds; // All participants (driverId + admin(s))
  final List<String> participantRoles; // 'admin' or 'driver'
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? deliveryId; // Optional: linked delivery
  final String? claimId; // Optional: linked claim
  final String? vehicleId; // Optional: linked vehicle
  final bool isActive;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, bool> readStatus; // {userId: isRead}
  final Map<String, int> unreadCount; // {userId: count}

  ChatConversation({
    required this.id,
    required this.companyId,
    required this.driverId,
    required this.driverName,
    this.driverImageUrl,
    required this.adminId,
    required this.adminName,
    this.adminImageUrl,
    required this.participantIds,
    required this.participantRoles,
    required this.lastMessage,
    required this.lastMessageAt,
    this.deliveryId,
    this.claimId,
    this.vehicleId,
    this.isActive = true,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    Map<String, bool>? readStatus,
    Map<String, int>? unreadCount,
  })  : readStatus = readStatus ?? {},
        unreadCount = unreadCount ?? {};

  /// Convert ChatConversation to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'driverId': driverId,
      'driverName': driverName,
      'driverImageUrl': driverImageUrl,
      'adminId': adminId,
      'adminName': adminName,
      'adminImageUrl': adminImageUrl,
      'participantIds': participantIds,
      'participantRoles': participantRoles,
      'lastMessage': lastMessage,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'deliveryId': deliveryId,
      'claimId': claimId,
      'vehicleId': vehicleId,
      'isActive': isActive,
      'isArchived': isArchived,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'readStatus': readStatus,
      'unreadCount': unreadCount,
    };
  }

  /// Create ChatConversation from Firestore document
  factory ChatConversation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ChatConversation(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? 'Unknown Driver',
      driverImageUrl: data['driverImageUrl'],
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? 'Unknown Admin',
      adminImageUrl: data['adminImageUrl'],
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantRoles: List<String>.from(data['participantRoles'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : DateTime.now(),
      deliveryId: data['deliveryId'],
      claimId: data['claimId'],
      vehicleId: data['vehicleId'],
      isActive: data['isActive'] ?? true,
      isArchived: data['isArchived'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      readStatus: Map<String, bool>.from(data['readStatus'] ?? {}),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)) ?? {}
      ),
    );
  }

  /// Copy with modifications
  ChatConversation copyWith({
    String? id,
    String? companyId,
    String? driverId,
    String? driverName,
    String? driverImageUrl,
    String? adminId,
    String? adminName,
    String? adminImageUrl,
    List<String>? participantIds,
    List<String>? participantRoles,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? deliveryId,
    String? claimId,
    String? vehicleId,
    bool? isActive,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, bool>? readStatus,
    Map<String, int>? unreadCount,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverImageUrl: driverImageUrl ?? this.driverImageUrl,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      adminImageUrl: adminImageUrl ?? this.adminImageUrl,
      participantIds: participantIds ?? this.participantIds,
      participantRoles: participantRoles ?? this.participantRoles,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      deliveryId: deliveryId ?? this.deliveryId,
      claimId: claimId ?? this.claimId,
      vehicleId: vehicleId ?? this.vehicleId,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readStatus: readStatus ?? this.readStatus,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  String toString() => 'ChatConversation($id, driver: $driverName, lastMessage: $lastMessageAt)';
}
