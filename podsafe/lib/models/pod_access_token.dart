import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../config/environment.dart';

/// Model for POD access tokens - allows secure public access to POD data
class PODAccessToken {
  final String deliveryId;
  final String token; // Secure random token
  final DateTime createdAt;
  final DateTime? expiresAt; // Optional expiration
  final bool isActive;
  final int accessCount; // Track how many times it's been accessed
  
  PODAccessToken({
    required this.deliveryId,
    required this.token,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.accessCount = 0,
  });
  
  /// Generate a secure token for a delivery
  static String generateToken(String deliveryId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    final input = '$deliveryId-$timestamp-$random';
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32); // 32 character token
  }
  
  /// Create a new token for a delivery
  factory PODAccessToken.create(String deliveryId, {int? expiryDays}) {
    final token = generateToken(deliveryId);
    final createdAt = DateTime.now();
    final expiresAt = expiryDays != null 
        ? createdAt.add(Duration(days: expiryDays))
        : null;
    
    return PODAccessToken(
      deliveryId: deliveryId,
      token: token,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isActive: true,
      accessCount: 0,
    );
  }
  
  /// Check if token is valid
  bool get isValid {
    if (!isActive) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
      return false;
    }
    return true;
  }
  
  /// Get public URL for this POD
  String getPublicUrl({String? baseUrl}) {
    final base = baseUrl ?? EnvironmentConfig.publicPodBaseUrl;
    return '$base/pod/$deliveryId?token=$token';
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'deliveryId': deliveryId,
      'token': token,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'accessCount': accessCount,
    };
  }
  
  /// Create from Firestore document
  factory PODAccessToken.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PODAccessToken(
      deliveryId: data['deliveryId'] ?? '',
      token: data['token'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null 
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      accessCount: data['accessCount'] ?? 0,
    );
  }
  
  /// Copy with updates
  PODAccessToken copyWith({
    String? deliveryId,
    String? token,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    int? accessCount,
  }) {
    return PODAccessToken(
      deliveryId: deliveryId ?? this.deliveryId,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      accessCount: accessCount ?? this.accessCount,
    );
  }
}
