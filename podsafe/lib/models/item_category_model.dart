import 'package:cloud_firestore/cloud_firestore.dart';

/// Custom item category model
class ItemCategoryModel {
  final String id;
  final String companyId;
  final String name;
  final String icon; // Emoji or icon name
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  ItemCategoryModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.icon,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
  });

  /// Create from Firestore document
  factory ItemCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemCategoryModel(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      name: data['name'] ?? '',
      icon: data['icon'] ?? '📦',
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'icon': icon,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  /// Create a copy with modified fields
  ItemCategoryModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? icon,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return ItemCategoryModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Default categories to seed for new companies
  static List<Map<String, dynamic>> get defaultCategories => [
        {'name': 'General Items', 'icon': '📦', 'sortOrder': 1},
        {'name': 'Furniture', 'icon': '🪑', 'sortOrder': 2},
        {'name': 'Office Supplies', 'icon': '💼', 'sortOrder': 3},
        {'name': 'Electronics', 'icon': '🖥️', 'sortOrder': 4},
        {'name': 'Documents', 'icon': '📋', 'sortOrder': 5},
        {'name': 'Bulk Goods', 'icon': '🚚', 'sortOrder': 6},
        {'name': 'Equipment', 'icon': '⚙️', 'sortOrder': 7},
        {'name': 'Other', 'icon': '📦', 'sortOrder': 8},
      ];
}
