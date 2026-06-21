import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_category_model.dart';

/// Service for managing custom item categories
class ItemCategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get category collection reference for a company
  CollectionReference _getCategoryCollection(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('itemCategories');
  }

  /// Get all active categories for a company
  Future<List<ItemCategoryModel>> getCategories(String companyId) async {
    try {
      final snapshot = await _getCategoryCollection(companyId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      return snapshot.docs
          .map((doc) => ItemCategoryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  /// Get a single category by ID
  Future<ItemCategoryModel?> getCategory(
    String companyId,
    String categoryId,
  ) async {
    try {
      final doc =
          await _getCategoryCollection(companyId).doc(categoryId).get();
      if (!doc.exists) return null;
      return ItemCategoryModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to load category: $e');
    }
  }

  /// Create a new category
  Future<String> createCategory(
    String companyId,
    ItemCategoryModel category,
  ) async {
    try {
      // Check for duplicate name
      final existing = await _checkDuplicateName(companyId, category.name);
      if (existing != null) {
        throw Exception('A category with this name already exists: "${existing.name}"');
      }

      final docRef =
          await _getCategoryCollection(companyId).add(category.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  /// Update an existing category
  Future<void> updateCategory(
    String companyId,
    String categoryId,
    ItemCategoryModel category,
  ) async {
    try {
      // Check for duplicate name (excluding current category)
      final existing = await _checkDuplicateName(
        companyId,
        category.name,
        excludeId: categoryId,
      );
      if (existing != null) {
        throw Exception('A category with this name already exists: "${existing.name}"');
      }

      await _getCategoryCollection(companyId).doc(categoryId).update(category.toMap());
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  /// Delete a category (soft delete)
  Future<void> deleteCategory(
    String companyId,
    String categoryId,
  ) async {
    try {
      await _getCategoryCollection(companyId).doc(categoryId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  /// Check if a category with the same name already exists
  Future<ItemCategoryModel?> _checkDuplicateName(
    String companyId,
    String name, {
    String? excludeId,
  }) async {
    try {
      final snapshot = await _getCategoryCollection(companyId)
          .where('name', isEqualTo: name)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      if (excludeId != null && doc.id == excludeId) return null;

      return ItemCategoryModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Seed default categories for a new company
  Future<void> seedDefaultCategories(
    String companyId,
    String userId,
  ) async {
    try {
      // Check if categories already exist
      final existing = await getCategories(companyId);
      if (existing.isNotEmpty) return;

      // Create default categories
      final batch = _firestore.batch();
      final now = DateTime.now();

      for (final categoryData in ItemCategoryModel.defaultCategories) {
        final category = ItemCategoryModel(
          id: '', // Will be auto-generated
          companyId: companyId,
          name: categoryData['name'] as String,
          icon: categoryData['icon'] as String,
          sortOrder: categoryData['sortOrder'] as int,
          isActive: true,
          createdAt: now,
          createdBy: userId,
        );

        final docRef = _getCategoryCollection(companyId).doc();
        batch.set(docRef, category.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to seed default categories: $e');
    }
  }
}
