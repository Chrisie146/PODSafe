import 'package:cloud_firestore/cloud_firestore.dart';
import 'delivery_model.dart';

/// Categories for organizing catalog items
enum ItemCategory {
  general,
  furniture,
  officeSupplies,
  electronics,
  documents,
  bulkGoods,
  equipment,
  other;

  String get displayName {
    switch (this) {
      case ItemCategory.general:
        return 'General Items';
      case ItemCategory.furniture:
        return 'Furniture';
      case ItemCategory.officeSupplies:
        return 'Office Supplies';
      case ItemCategory.electronics:
        return 'Electronics';
      case ItemCategory.documents:
        return 'Documents';
      case ItemCategory.bulkGoods:
        return 'Bulk Goods';
      case ItemCategory.equipment:
        return 'Equipment';
      case ItemCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ItemCategory.general:
        return '📦';
      case ItemCategory.furniture:
        return '🪑';
      case ItemCategory.officeSupplies:
        return '💼';
      case ItemCategory.electronics:
        return '🖥️';
      case ItemCategory.documents:
        return '📋';
      case ItemCategory.bulkGoods:
        return '🚚';
      case ItemCategory.equipment:
        return '⚙️';
      case ItemCategory.other:
        return '📦';
    }
  }

  static ItemCategory fromString(String? value) {
    if (value == null) return ItemCategory.general;
    try {
      return ItemCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ItemCategory.general,
      );
    } catch (_) {
      return ItemCategory.general;
    }
  }
}

/// Catalog item model for reusable delivery items
class CatalogItem {
  final String id;
  final String companyId;
  final String description;
  final String? sku; // SKU/Part Number
  final String? unit;
  final double? defaultQuantity;
  final double? unitPrice; // Optional pricing
  final ItemCategory category; // Deprecated: Use categoryId instead
  final String? categoryId; // Custom category ID from itemCategories collection
  final bool isActive;
  final int usageCount;
  final DateTime? lastUsed;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;

  CatalogItem({
    required this.id,
    required this.companyId,
    required this.description,
    this.sku,
    this.unit,
    this.defaultQuantity,
    this.unitPrice,
    this.category = ItemCategory.general,
    this.categoryId, // Optional: if null, uses category enum
    this.isActive = true,
    this.usageCount = 0,
    this.lastUsed,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  /// Create from Firestore document
  factory CatalogItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CatalogItem.fromMap(data, doc.id);
  }

  /// Create from map
  factory CatalogItem.fromMap(Map<String, dynamic> map, String id) {
    return CatalogItem(
      id: id,
      companyId: map['companyId'] ?? '',
      description: map['description'] ?? '',
      sku: map['sku'],
      unit: map['unit'],
      defaultQuantity: map['defaultQuantity']?.toDouble(),
      unitPrice: map['unitPrice']?.toDouble(),
      category: ItemCategory.fromString(map['category']),
      categoryId: map['categoryId'],
      isActive: map['isActive'] ?? true,
      usageCount: map['usageCount'] ?? 0,
      lastUsed: map['lastUsed'] != null
          ? (map['lastUsed'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      updatedBy: map['updatedBy'] ?? '',
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'description': description,
      'sku': sku,
      'unit': unit,
      'defaultQuantity': defaultQuantity,
      'unitPrice': unitPrice,
      'category': category.name,
      'categoryId': categoryId,
      'isActive': isActive,
      'usageCount': usageCount,
      'lastUsed': lastUsed != null ? Timestamp.fromDate(lastUsed!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  /// Convert to DeliveryItem with optional quantity override
  DeliveryItem toDeliveryItem({double? quantity, double? totalPrice}) {
    final qty = quantity ?? defaultQuantity ?? 1.0;
    return DeliveryItem(
      description: description,
      quantity: qty,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice ?? (unitPrice != null ? unitPrice! * qty : null),
    );
  }

  /// Copy with updated fields
  CatalogItem copyWith({
    String? id,
    String? companyId,
    String? description,
    String? unit,
    double? defaultQuantity,
    double? unitPrice,
    ItemCategory? category,
    bool? isActive,
    int? usageCount,
    DateTime? lastUsed,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
    bool clearUnit = false,
    bool clearDefaultQuantity = false,
    bool clearUnitPrice = false,
    bool clearLastUsed = false,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      description: description ?? this.description,
      unit: clearUnit ? null : (unit ?? this.unit),
      defaultQuantity: clearDefaultQuantity
          ? null
          : (defaultQuantity ?? this.defaultQuantity),
      unitPrice: clearUnitPrice ? null : (unitPrice ?? this.unitPrice),
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      usageCount: usageCount ?? this.usageCount,
      lastUsed: clearLastUsed ? null : (lastUsed ?? this.lastUsed),
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Check if item is popular (used 50+ times)
  bool get isPopular => usageCount >= 50;

  /// Check if item is trending (used 10+ times in last 30 days)
  bool get isTrending {
    if (lastUsed == null) return false;
    final daysSinceLastUse = DateTime.now().difference(lastUsed!).inDays;
    return usageCount >= 10 && daysSinceLastUse <= 30;
  }

  /// Check if item is new (created within 7 days)
  bool get isNew {
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
    return daysSinceCreation <= 7;
  }

  /// Get display text for search/autocomplete
  String get displayText => '$description${unit != null ? " ($unit)" : ""}';

  /// Get formatted price
  String get formattedPrice {
    if (unitPrice == null) return 'No price';
    return 'R ${unitPrice!.toStringAsFixed(2)}';
  }

  @override
  String toString() => 'CatalogItem(id: $id, description: $description)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatalogItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
