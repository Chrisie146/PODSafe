import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExternalDeliveryToken {
  final String id;
  final String deliveryId;
  final String companyId;
  final String providerName;
  final String? providerContact;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isUsed;
  final List<String> uploadedFiles;
  final DateTime? uploadedAt;
  final String? uploadNotes;

  ExternalDeliveryToken({
    required this.id,
    required this.deliveryId,
    required this.companyId,
    required this.providerName,
    this.providerContact,
    required this.createdAt,
    this.expiresAt,
    this.isUsed = false,
    this.uploadedFiles = const [],
    this.uploadedAt,
    this.uploadNotes,
  });

  /// Generates a secure random token
  static String generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (i) => random.nextInt(256));
    return base64Url
        .encode(bytes)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .substring(0, 32);
  }

  /// Checks if token is valid for use
  bool isValid() {
    if (isUsed) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
      return false;
    }
    return true;
  }

  factory ExternalDeliveryToken.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ExternalDeliveryToken(
      id: doc.id,
      deliveryId: data['deliveryId'] ?? '',
      companyId: data['companyId'] ?? '',
      providerName: data['providerName'] ?? '',
      providerContact: data['providerContact'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isUsed: data['isUsed'] ?? false,
      uploadedFiles:
          (data['uploadedFiles'] as List<dynamic>?)?.cast<String>() ?? [],
      uploadedAt: data['uploadedAt'] != null
          ? (data['uploadedAt'] as Timestamp).toDate()
          : null,
      uploadNotes: data['uploadNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deliveryId': deliveryId,
      'companyId': companyId,
      'providerName': providerName,
      'providerContact': providerContact,
      'createdAt': Timestamp.fromDate(createdAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'isUsed': isUsed,
      'uploadedFiles': uploadedFiles,
      if (uploadedAt != null) 'uploadedAt': Timestamp.fromDate(uploadedAt!),
      'uploadNotes': uploadNotes,
    };
  }

  ExternalDeliveryToken copyWith({
    String? id,
    String? deliveryId,
    String? companyId,
    String? providerName,
    String? providerContact,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
    List<String>? uploadedFiles,
    DateTime? uploadedAt,
    String? uploadNotes,
  }) {
    return ExternalDeliveryToken(
      id: id ?? this.id,
      deliveryId: deliveryId ?? this.deliveryId,
      companyId: companyId ?? this.companyId,
      providerName: providerName ?? this.providerName,
      providerContact: providerContact ?? this.providerContact,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
      uploadedFiles: uploadedFiles ?? this.uploadedFiles,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadNotes: uploadNotes ?? this.uploadNotes,
    );
  }
}
