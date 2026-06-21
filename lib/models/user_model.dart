import 'package:cloud_firestore/cloud_firestore.dart';

/// User roles for RBAC system
/// - admin: Full access, can manage users and roles
/// - manager: Can view and approve PODs, view reports
/// - logistics: Can create deliveries and assign drivers
/// - accountant: Can view financials and export reports
/// - filing_clerk: Can upload and tag scanned PODs
/// - driver: Can scan/upload PODs, mark deliveries complete
enum UserRole { 
  admin, 
  manager, 
  logistics, 
  accountant, 
  filing_clerk, 
  driver 
}

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String companyId;
  final String? phoneNumber;
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  
  // Driver-specific fields
  final String? licenseNumber;
  final String? vehicleInfo;
  final String? approvalStatus; // 'pending', 'approved', 'rejected'
  final String? approvedBy; // admin UID who approved
  final DateTime? approvedAt;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.companyId,
    this.phoneNumber,
    this.profileImageUrl,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.licenseNumber,
    this.vehicleInfo,
    this.approvalStatus,
    this.approvedBy,
    this.approvedAt,
  });

  // Convert from Firestore Document
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? data['displayName'] ?? '', // Support old field
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == data['role'],
        orElse: () => UserRole.driver,
      ),
      companyId: data['companyId'] ?? '',
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null 
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] != null 
        ? (data['lastLoginAt'] as Timestamp).toDate() 
        : null,
      licenseNumber: data['licenseNumber'],
      vehicleInfo: data['vehicleInfo'],
      approvalStatus: data['approvalStatus'],
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null
        ? (data['approvedAt'] as Timestamp).toDate()
        : null,
    );
  }

  // Convert to Firestore Document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'displayName': fullName, // Keep for backward compatibility
      'role': role.toString().split('.').last,
      'companyId': companyId,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null 
        ? Timestamp.fromDate(lastLoginAt!) 
        : null,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (vehicleInfo != null) 'vehicleInfo': vehicleInfo,
      if (approvalStatus != null) 'approvalStatus': approvalStatus,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? companyId,
    String? phoneNumber,
    String? profileImageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? licenseNumber,
    String? vehicleInfo,
    String? approvalStatus,
    String? approvedBy,
    DateTime? approvedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}