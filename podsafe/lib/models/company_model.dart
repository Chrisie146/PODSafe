import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String id;
  final String name;
  final String address;
  final String email; // Changed from contactEmail for consistency
  final String phone; // Changed from phoneNumber? to required phone
  final String? registrationNumber; // Company registration/VAT number
  final String? logoUrl;
  final String plan; // 'free', 'basic', 'premium'
  final CompanySettings settings; // Changed to typed settings
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastBackupDate;

  Company({
    required this.id,
    required this.name,
    required this.address,
    required this.email,
    required this.phone,
    this.registrationNumber,
    this.logoUrl,
    this.plan = 'free',
    CompanySettings? settings,
    this.isActive = true,
    required this.createdAt,
    this.lastBackupDate,
  }) : settings = settings ?? CompanySettings();

  factory Company.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      email: data['email'] ?? data['contactEmail'] ?? '', // Support old field
      phone: data['phone'] ?? data['phoneNumber'] ?? '', // Support old field
      registrationNumber: data['registrationNumber'],
      logoUrl: data['logoUrl'],
      plan: data['plan'] ?? 'free',
      settings: CompanySettings.fromMap(data['settings'] ?? {}),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastBackupDate: (data['lastBackupDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'email': email,
      'phone': phone,
      'registrationNumber': registrationNumber,
      'logoUrl': logoUrl,
      'plan': plan,
      'settings': settings.toMap(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastBackupDate != null) 'lastBackupDate': Timestamp.fromDate(lastBackupDate!),
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? address,
    String? email,
    String? phone,
    String? registrationNumber,
    String? logoUrl,
    String? plan,
    CompanySettings? settings,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastBackupDate,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      logoUrl: logoUrl ?? this.logoUrl,
      plan: plan ?? this.plan,
      settings: settings ?? this.settings,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
    );
  }
}

class CompanySettings {
  final bool autoApproveDrivers;
  final bool requireDriverApproval;

  CompanySettings({
    this.autoApproveDrivers = false,
    this.requireDriverApproval = true,
  });

  factory CompanySettings.fromMap(Map<String, dynamic> map) {
    return CompanySettings(
      autoApproveDrivers: map['autoApproveDrivers'] ?? false,
      requireDriverApproval: map['requireDriverApproval'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoApproveDrivers': autoApproveDrivers,
      'requireDriverApproval': requireDriverApproval,
    };
  }

  CompanySettings copyWith({
    bool? autoApproveDrivers,
    bool? requireDriverApproval,
  }) {
    return CompanySettings(
      autoApproveDrivers: autoApproveDrivers ?? this.autoApproveDrivers,
      requireDriverApproval: requireDriverApproval ?? this.requireDriverApproval,
    );
  }
}