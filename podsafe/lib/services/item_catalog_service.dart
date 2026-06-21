import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/catalog_item_model.dart';

/// Service for managing item catalog in Firestore
class ItemCatalogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get catalog collection reference for a company
  CollectionReference _getCatalogCollection(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('itemCatalog');
  }

  /// Get all active catalog items for a company
  Future<List<CatalogItem>> getCatalogItems(String companyId) async {
    try {
      final snapshot = await _getCatalogCollection(companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final items = snapshot.docs
          .map((doc) => CatalogItem.fromFirestore(doc))
          .toList();

      // Sort by usage count descending (most used first)
      items.sort((a, b) => b.usageCount.compareTo(a.usageCount));

      return items;
    } catch (e) {
      throw Exception('Failed to load catalog items: $e');
    }
  }

  /// Get catalog items by category
  Future<List<CatalogItem>> getCatalogItemsByCategory(
    String companyId,
    ItemCategory category,
  ) async {
    try {
      final snapshot = await _getCatalogCollection(companyId)
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category.name)
          .get();

      final items = snapshot.docs
          .map((doc) => CatalogItem.fromFirestore(doc))
          .toList();

      // Sort by usage count descending
      items.sort((a, b) => b.usageCount.compareTo(a.usageCount));

      return items;
    } catch (e) {
      throw Exception('Failed to load catalog items by category: $e');
    }
  }

  /// Get popular items (most used)
  Future<List<CatalogItem>> getPopularItems(
    String companyId, {
    int limit = 10,
  }) async {
    try {
      final snapshot = await _getCatalogCollection(companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final items = snapshot.docs
          .map((doc) => CatalogItem.fromFirestore(doc))
          .toList();

      // Sort by usage count descending and take limit
      items.sort((a, b) => b.usageCount.compareTo(a.usageCount));
      return items.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to load popular items: $e');
    }
  }

  /// Search catalog items by description
  Future<List<CatalogItem>> searchItems(
    String companyId,
    String query,
  ) async {
    try {
      // Get all active items first (Firestore doesn't support complex text search)
      final snapshot = await _getCatalogCollection(companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final allItems = snapshot.docs
          .map((doc) => CatalogItem.fromFirestore(doc))
          .toList();

      // Filter by query (case-insensitive partial match)
      final queryLower = query.toLowerCase();
      final filtered = allItems.where((item) {
        final descLower = item.description.toLowerCase();
        final unitLower = item.unit?.toLowerCase() ?? '';
        return descLower.contains(queryLower) || unitLower.contains(queryLower);
      }).toList();

      // Sort by relevance (exact match first, then by usage count)
      filtered.sort((a, b) {
        final aDesc = a.description.toLowerCase();
        final bDesc = b.description.toLowerCase();
        
        // Exact match gets highest priority
        if (aDesc == queryLower && bDesc != queryLower) return -1;
        if (bDesc == queryLower && aDesc != queryLower) return 1;
        
        // Starts with query gets second priority
        if (aDesc.startsWith(queryLower) && !bDesc.startsWith(queryLower)) {
          return -1;
        }
        if (bDesc.startsWith(queryLower) && !aDesc.startsWith(queryLower)) {
          return 1;
        }
        
        // Otherwise sort by usage count
        return b.usageCount.compareTo(a.usageCount);
      });

      return filtered;
    } catch (e) {
      throw Exception('Failed to search catalog items: $e');
    }
  }

  /// Get a single catalog item by ID
  Future<CatalogItem?> getCatalogItem(
    String companyId,
    String itemId,
  ) async {
    try {
      final doc = await _getCatalogCollection(companyId).doc(itemId).get();
      if (!doc.exists) return null;
      return CatalogItem.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to load catalog item: $e');
    }
  }

  /// Create a new catalog item
  Future<String> createCatalogItem(
    String companyId,
    CatalogItem item,
  ) async {
    try {
      // Check for duplicate description
      final existing = await _checkDuplicateDescription(
        companyId,
        item.description,
      );
      if (existing != null) {
        throw Exception(
          'An item with this description already exists: "${existing.description}"',
        );
      }

      final docRef = await _getCatalogCollection(companyId).add(item.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create catalog item: $e');
    }
  }

  /// Update an existing catalog item
  Future<void> updateCatalogItem(
    String companyId,
    String itemId,
    CatalogItem item,
  ) async {
    try {
      // Check for duplicate description (excluding current item)
      final existing = await _checkDuplicateDescription(
        companyId,
        item.description,
        excludeItemId: itemId,
      );
      if (existing != null) {
        throw Exception(
          'An item with this description already exists: "${existing.description}"',
        );
      }

      await _getCatalogCollection(companyId).doc(itemId).update(item.toMap());
    } catch (e) {
      throw Exception('Failed to update catalog item: $e');
    }
  }

  /// Delete a catalog item (soft delete by marking inactive)
  Future<void> deleteCatalogItem(
    String companyId,
    String itemId,
    String userId,
  ) async {
    try {
      await _getCatalogCollection(companyId).doc(itemId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
        'updatedBy': userId,
      });
    } catch (e) {
      throw Exception('Failed to delete catalog item: $e');
    }
  }

  /// Permanently delete a catalog item (use with caution)
  Future<void> permanentlyDeleteCatalogItem(
    String companyId,
    String itemId,
  ) async {
    try {
      await _getCatalogCollection(companyId).doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to permanently delete catalog item: $e');
    }
  }

  /// Increment usage count when item is used in a delivery
  Future<void> incrementUsageCount(
    String companyId,
    String itemId,
  ) async {
    try {
      await _getCatalogCollection(companyId).doc(itemId).update({
        'usageCount': FieldValue.increment(1),
        'lastUsed': Timestamp.now(),
      });
    } catch (e) {
      // Don't throw error here - usage tracking is not critical
      print('Warning: Failed to increment usage count: $e');
    }
  }

  /// Batch increment usage counts
  Future<void> batchIncrementUsageCount(
    String companyId,
    List<String> itemIds,
  ) async {
    try {
      final batch = _firestore.batch();
      final now = Timestamp.now();
      
      for (final itemId in itemIds) {
        final docRef = _getCatalogCollection(companyId).doc(itemId);
        batch.update(docRef, {
          'usageCount': FieldValue.increment(1),
          'lastUsed': now,
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Warning: Failed to batch increment usage count: $e');
    }
  }

  /// Check for duplicate description
  Future<CatalogItem?> _checkDuplicateDescription(
    String companyId,
    String description, {
    String? excludeItemId,
  }) async {
    try {
      final snapshot = await _getCatalogCollection(companyId)
          .where('description', isEqualTo: description)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final item = CatalogItem.fromFirestore(snapshot.docs.first);
      
      // If we're updating and found the same item, it's not a duplicate
      if (excludeItemId != null && item.id == excludeItemId) {
        return null;
      }

      return item;
    } catch (e) {
      return null;
    }
  }

  /// Get catalog statistics
  Future<Map<String, dynamic>> getCatalogStats(String companyId) async {
    try {
      final snapshot = await _getCatalogCollection(companyId).get();
      
      int totalItems = 0;
      int activeItems = 0;
      int totalUsage = 0;
      final categoryCounts = <ItemCategory, int>{};
      
      for (final doc in snapshot.docs) {
        final item = CatalogItem.fromFirestore(doc);
        totalItems++;
        
        if (item.isActive) {
          activeItems++;
          totalUsage += item.usageCount;
          
          final category = item.category;
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        }
      }
      
      return {
        'totalItems': totalItems,
        'activeItems': activeItems,
        'inactiveItems': totalItems - activeItems,
        'totalUsage': totalUsage,
        'averageUsage': activeItems > 0 ? totalUsage / activeItems : 0,
        'categoryCounts': categoryCounts.map((k, v) => MapEntry(k.name, v)),
      };
    } catch (e) {
      throw Exception('Failed to load catalog stats: $e');
    }
  }

  /// Stream catalog items (real-time updates)
  Stream<List<CatalogItem>> streamCatalogItems(String companyId) {
    return _getCatalogCollection(companyId)
        .where('isActive', isEqualTo: true)
        .orderBy('usageCount', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CatalogItem.fromFirestore(doc))
            .toList());
  }

  /// Bulk import catalog items from CSV data
  Future<Map<String, dynamic>> bulkImportItems(
    String companyId,
    String userId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      int successCount = 0;
      final errors = <String>[];

      for (var i = 0; i < items.length; i++) {
        try {
          final itemData = items[i];
          final description = itemData['description']?.toString().trim() ?? '';
          
          if (description.isEmpty) {
            errors.add('Row ${i + 1}: Description is required');
            continue;
          }

          final catalogItem = CatalogItem(
            id: '', // Will be generated
            companyId: companyId,
            description: description,
            unit: itemData['unit']?.toString().trim(),
            defaultQuantity: itemData['defaultQuantity'] != null
                ? double.tryParse(itemData['defaultQuantity'].toString())
                : null,
            unitPrice: itemData['unitPrice'] != null
                ? double.tryParse(itemData['unitPrice'].toString())
                : null,
            category: ItemCategory.fromString(itemData['category']),
            isActive: true,
            usageCount: 0,
            createdAt: now,
            createdBy: userId,
            updatedAt: now,
            updatedBy: userId,
          );

          final docRef = _getCatalogCollection(companyId).doc();
          batch.set(docRef, catalogItem.toMap());
          successCount++;
        } catch (e) {
          errors.add('Row ${i + 1}: $e');
        }
      }

      await batch.commit();

      return {
        'success': successCount,
        'errors': errors,
        'total': items.length,
      };
    } catch (e) {
      throw Exception('Failed to bulk import items: $e');
    }
  }
}
