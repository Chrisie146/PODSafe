import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer type enumeration
enum CustomerType {
  business,
  residential,
}

/// Customer statistics
class CustomerStats {
  final int totalDeliveries;
  final DateTime? lastDelivery;
  final DateTime? firstDelivery;

  CustomerStats({
    this.totalDeliveries = 0,
    this.lastDelivery,
    this.firstDelivery,
  });

  factory CustomerStats.fromMap(Map<String, dynamic> map) {
    return CustomerStats(
      totalDeliveries: map['totalDeliveries'] ?? 0,
      lastDelivery: map['lastDelivery'] != null
          ? (map['lastDelivery'] as Timestamp).toDate()
          : null,
      firstDelivery: map['firstDelivery'] != null
          ? (map['firstDelivery'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalDeliveries': totalDeliveries,
      'lastDelivery': lastDelivery != null 
          ? Timestamp.fromDate(lastDelivery!) 
          : null,
      'firstDelivery': firstDelivery != null 
          ? Timestamp.fromDate(firstDelivery!) 
          : null,
    };
  }

  CustomerStats copyWith({
    int? totalDeliveries,
    DateTime? lastDelivery,
    DateTime? firstDelivery,
  }) {
    return CustomerStats(
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      lastDelivery: lastDelivery ?? this.lastDelivery,
      firstDelivery: firstDelivery ?? this.firstDelivery,
    );
  }
}

/// Customer model with simplified structure
/// Single address per customer, required customer number
class Customer {
  // === Identity (Required) ===
  final String id;                    // Firestore document ID
  final String companyId;             // Multi-tenant company ID
  final String customerNumber;        // BOX001, ACME999, etc. (Required, Unique per company)
  final String name;                  // Customer display name (Required)

  // === Address (Required - Single Address) ===
  final String address;               // Full delivery address (Required)

  // === Contact Information (Optional) ===
  final String? contactPerson;        // Main contact at customer
  final String? phone;                // Primary phone number
  final String? email;                // Email for notifications

  // === Delivery Preferences (Optional) ===
  final String? deliveryInstructions; // Special instructions, gate codes, etc.

  // === Business Details (Optional) ===
  final String? accountNumber;        // External accounting system ID
  final CustomerType customerType;    // Business or Residential

  // === Metadata ===
  final CustomerStats stats;          // Delivery statistics
  final bool isActive;                // Active or archived
  final bool isFavorite;              // Starred for quick access
  final List<String> tags;            // VIP, Weekly, Wholesale, etc.

  // === Timestamps ===
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.companyId,
    required this.customerNumber,
    required this.name,
    required this.address,
    this.contactPerson,
    this.phone,
    this.email,
    this.deliveryInstructions,
    this.accountNumber,
    this.customerType = CustomerType.business,
    CustomerStats? stats,
    this.isActive = true,
    this.isFavorite = false,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : stats = stats ?? CustomerStats(),
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create Customer from Firestore document
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Customer(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      customerNumber: data['customerNumber'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      contactPerson: data['contactPerson'],
      phone: data['phone'],
      email: data['email'],
      deliveryInstructions: data['deliveryInstructions'],
      accountNumber: data['accountNumber'],
      customerType: CustomerType.values.firstWhere(
        (e) => e.toString().split('.').last == data['customerType'],
        orElse: () => CustomerType.business,
      ),
      stats: data['stats'] != null 
          ? CustomerStats.fromMap(data['stats']) 
          : CustomerStats(),
      isActive: data['isActive'] ?? true,
      isFavorite: data['isFavorite'] ?? false,
      tags: data['tags'] != null 
          ? List<String>.from(data['tags']) 
          : [],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert Customer to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'customerNumber': customerNumber,
      'name': name,
      'address': address,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'deliveryInstructions': deliveryInstructions,
      'accountNumber': accountNumber,
      'customerType': customerType.toString().split('.').last,
      'stats': stats.toMap(),
      'isActive': isActive,
      'isFavorite': isFavorite,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  Customer copyWith({
    String? id,
    String? companyId,
    String? customerNumber,
    String? name,
    String? address,
    String? contactPerson,
    String? phone,
    String? email,
    String? deliveryInstructions,
    String? accountNumber,
    CustomerType? customerType,
    CustomerStats? stats,
    bool? isActive,
    bool? isFavorite,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      customerNumber: customerNumber ?? this.customerNumber,
      name: name ?? this.name,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      accountNumber: accountNumber ?? this.accountNumber,
      customerType: customerType ?? this.customerType,
      stats: stats ?? this.stats,
      isActive: isActive ?? this.isActive,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Display string for customer
  String get displayString => '$customerNumber - $name';

  /// Search string for filtering (lowercase)
  String get searchString => 
      '${customerNumber.toLowerCase()} ${name.toLowerCase()} ${contactPerson?.toLowerCase() ?? ''}';

  @override
  String toString() => displayString;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
