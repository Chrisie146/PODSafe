import 'package:flutter/foundation.dart';
import '../models/catalog_item_model.dart';
import '../services/item_catalog_service.dart';

/// Provider for managing catalog items state
class CatalogProvider extends ChangeNotifier {
  final ItemCatalogService _catalogService = ItemCatalogService();

  List<CatalogItem> _items = [];
  List<CatalogItem> _filteredItems = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  ItemCategory? _selectedCategory;
  String? _currentCompanyId;

  // Getters
  List<CatalogItem> get items => _filteredItems;
  List<CatalogItem> get allItems => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  ItemCategory? get selectedCategory => _selectedCategory;
  bool get hasItems => _items.isNotEmpty;

  /// Get popular items (most used)
  List<CatalogItem> get popularItems {
    final sorted = List<CatalogItem>.from(_items);
    sorted.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.take(10).toList();
  }

  /// Get trending items (recently used)
  List<CatalogItem> get trendingItems {
    return _items.where((item) => item.isTrending).toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
  }

  /// Get new items (created within 7 days)
  List<CatalogItem> get newItems {
    return _items.where((item) => item.isNew).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get items by category
  List<CatalogItem> getItemsByCategory(ItemCategory category) {
    return _items.where((item) => item.category == category).toList();
  }

  /// Initialize provider with company ID
  Future<void> initialize(String companyId) async {
    if (_currentCompanyId == companyId && _items.isNotEmpty) {
      // Already loaded for this company
      return;
    }

    _currentCompanyId = companyId;
    await loadCatalog(companyId);
  }

  /// Load all catalog items for a company
  Future<void> loadCatalog(String companyId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _items = await _catalogService.getCatalogItems(companyId);
      _applyFilters();

      // Apply default sort (newest first) if no specific sort is set
      if (_filteredItems.isNotEmpty) {
        _filteredItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search catalog items
  Future<void> search(String companyId, String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      _filteredItems = _filterByCategory(_items);
      notifyListeners();
      return;
    }

    try {
      final results = await _catalogService.searchItems(companyId, query);
      _filteredItems = _filterByCategory(results);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Filter by category
  void filterByCategory(ItemCategory? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Clear filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _applyFilters();
    notifyListeners();
  }

  /// Apply current filters
  void _applyFilters() {
    List<CatalogItem> filtered = _items;

    // Apply category filter
    if (_selectedCategory != null) {
      filtered = filtered
          .where((item) => item.category == _selectedCategory)
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final queryLower = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        final descLower = item.description.toLowerCase();
        final unitLower = item.unit?.toLowerCase() ?? '';
        return descLower.contains(queryLower) || unitLower.contains(queryLower);
      }).toList();
    }

    _filteredItems = filtered;
  }

  /// Helper to filter list by category
  List<CatalogItem> _filterByCategory(List<CatalogItem> items) {
    if (_selectedCategory == null) return items;
    return items.where((item) => item.category == _selectedCategory).toList();
  }

  /// Add new catalog item
  Future<String> addItem(String companyId, CatalogItem item) async {
    try {
      final itemId = await _catalogService.createCatalogItem(companyId, item);
      await loadCatalog(companyId); // Reload to get updated list
      return itemId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update existing catalog item
  Future<void> updateItem(
    String companyId,
    String itemId,
    CatalogItem item,
  ) async {
    try {
      await _catalogService.updateCatalogItem(companyId, itemId, item);
      await loadCatalog(companyId); // Reload to get updated list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete catalog item (soft delete)
  Future<void> deleteItem(
    String companyId,
    String itemId,
    String userId,
  ) async {
    try {
      await _catalogService.deleteCatalogItem(companyId, itemId, userId);
      _items.removeWhere((item) => item.id == itemId);
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Increment usage count (call when item is used in delivery)
  Future<void> incrementUsage(String companyId, String itemId) async {
    try {
      await _catalogService.incrementUsageCount(companyId, itemId);
      
      // Update local cache
      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          usageCount: _items[index].usageCount + 1,
          lastUsed: DateTime.now(),
        );
        _applyFilters();
        notifyListeners();
      }
    } catch (e) {
      // Don't throw - usage tracking is not critical
      debugPrint('Warning: Failed to increment usage: $e');
    }
  }

  /// Batch increment usage counts for multiple items
  Future<void> batchIncrementUsage(
    String companyId,
    List<String> itemIds,
  ) async {
    try {
      await _catalogService.batchIncrementUsageCount(companyId, itemIds);
      
      // Update local cache
      final now = DateTime.now();
      for (final itemId in itemIds) {
        final index = _items.indexWhere((item) => item.id == itemId);
        if (index != -1) {
          _items[index] = _items[index].copyWith(
            usageCount: _items[index].usageCount + 1,
            lastUsed: now,
          );
        }
      }
      _applyFilters();
      notifyListeners();
    } catch (e) {
      debugPrint('Warning: Failed to batch increment usage: $e');
    }
  }

  /// Get catalog statistics
  Future<Map<String, dynamic>> getStats(String companyId) async {
    try {
      return await _catalogService.getCatalogStats(companyId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Bulk import items from CSV data
  Future<Map<String, dynamic>> bulkImport(
    String companyId,
    String userId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final result = await _catalogService.bulkImportItems(
        companyId,
        userId,
        items,
      );
      await loadCatalog(companyId); // Reload to show new items
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Sort items
  void sortItems(SortOption sortBy) {
    switch (sortBy) {
      case SortOption.usageCount:
        _filteredItems.sort((a, b) => b.usageCount.compareTo(a.usageCount));
        break;
      case SortOption.description:
        _filteredItems.sort((a, b) => a.description.compareTo(b.description));
        break;
      case SortOption.dateCreated:
        _filteredItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.category:
        _filteredItems.sort((a, b) =>
            a.category.displayName.compareTo(b.category.displayName));
        break;
    }
    notifyListeners();
  }

  /// Get item by ID from local cache
  CatalogItem? getItemById(String itemId) {
    try {
      return _items.firstWhere((item) => item.id == itemId);
    } catch (_) {
      return null;
    }
  }

  /// Check if description already exists
  bool descriptionExists(String description, {String? excludeItemId}) {
    return _items.any((item) =>
        item.description.toLowerCase() == description.toLowerCase() &&
        item.id != excludeItemId);
  }
}

/// Sort options for catalog items
enum SortOption {
  usageCount,
  description,
  dateCreated,
  category,
}

extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.usageCount:
        return 'Most Used';
      case SortOption.description:
        return 'Description (A-Z)';
      case SortOption.dateCreated:
        return 'Recently Added';
      case SortOption.category:
        return 'Category';
    }
  }
}
