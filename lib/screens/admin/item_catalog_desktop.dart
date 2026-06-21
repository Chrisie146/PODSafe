import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/catalog_item_model.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/manage_categories_dialog.dart';
import 'bulk_item_creation_screen.dart';

class ItemCatalogDesktop extends StatefulWidget {
  const ItemCatalogDesktop({super.key});

  @override
  State<ItemCatalogDesktop> createState() => _ItemCatalogDesktopState();
}

class _ItemCatalogDesktopState extends State<ItemCatalogDesktop> {
  final _searchController = TextEditingController();
  ItemCategory? _selectedCategory;
  SortOption _sortBy = SortOption.dateCreated; // Default to newest first
  bool _isLoading = true;

  // Desktop layout state
  bool _showFilters = true;
  bool _isMultiSelectMode = false;
  bool _showDetailPanel = false;
  Set<String> _selectedItemIds = {};

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCatalog();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+F - Focus search
      if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
        _focusNode.requestFocus();
        return KeyEventResult.handled;
      }
      // Ctrl+A - Select all
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        if (_isMultiSelectMode) {
          // Will select all visible items
          setState(() {});
          return KeyEventResult.handled;
        }
      }
      // Esc - Clear selection
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _selectedItemIds.clear();
          _isMultiSelectMode = false;
          _showDetailPanel = false;
        });
        return KeyEventResult.handled;
      }
      // F5 - Refresh
      else if (event.logicalKey == LogicalKeyboardKey.f5) {
        setState(() {}); // Triggers rebuild
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadCatalog() async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;

    if (companyId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final catalogProvider = context.read<CatalogProvider>();
      await catalogProvider.initialize(companyId);
      // Apply default sort (newest first)
      catalogProvider.sortItems(_sortBy);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading catalog: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleMultiSelect() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedItemIds.clear();
        _showDetailPanel = false;
      }
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _selectAllItems(List<CatalogItem> items) {
    setState(() {
      if (_selectedItemIds.length == items.length) {
        _selectedItemIds.clear();
      } else {
        _selectedItemIds = items.map((item) => item.id).toSet();
      }
    });
  }

  Future<void> _bulkDeleteItems() async {
    if (_selectedItemIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text(
          'Are you sure you want to delete ${_selectedItemIds.length} item(s)?\n\n'
          'This will remove them from the catalog, but won\'t affect existing deliveries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      final userId = authProvider.currentUser?.id;

      if (companyId == null || userId == null) return;

      final catalogProvider = context.read<CatalogProvider>();
      for (final itemId in _selectedItemIds) {
        await catalogProvider.deleteItem(companyId, itemId, userId);
      }

      setState(() {
        _selectedItemIds.clear();
        _isMultiSelectMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedItemIds.length} items deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting items: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _exportToCsv() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      if (companyId == null) throw Exception('No company ID');

      context.read<CatalogProvider>().loadCatalog(companyId).then((_) {
        final catalogProvider = context.read<CatalogProvider>();
        final items = catalogProvider.items;

        // Build CSV content
        final csvContent = StringBuffer();
        csvContent.writeln('Description,SKU,Category,Unit,Default Qty,Price,Usage Count,Created');

        for (final item in items) {
          csvContent.writeln(
            '${item.description},"${item.sku ?? ''}",${item.category.displayName},"${item.unit ?? ''}",'
            '${item.defaultQuantity ?? ''},${item.unitPrice ?? ''},${item.usageCount},'
            '${item.createdAt.toIso8601String()}'
          );
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('CSV ready: ${items.length} items'),
            backgroundColor: Colors.green,
          ),
        );
      });
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _selectItem(CatalogItem item) {
    setState(() {
      _selectedItem = item;
      _showDetailPanel = true;
    });
  }

  Future<void> _searchItems(String query) async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId;
    if (companyId != null) {
      await context.read<CatalogProvider>().search(companyId, query);
    }
  }

  void _filterByCategory(ItemCategory? category) {
    context.read<CatalogProvider>().filterByCategory(category);
    setState(() {
      _selectedCategory = category;
    });
  }

  CatalogItem? _selectedItem;

  void _sortItems(SortOption sortBy) {
    setState(() => _sortBy = sortBy);
    context.read<CatalogProvider>().sortItems(sortBy);
  }

  Future<void> _showAddItemDialog([CatalogItem? item]) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    final companyId = authProvider.currentUser?.companyId;

    if (userId == null || companyId == null) return;

    await showDialog(
      context: context,
      builder: (context) => _CatalogItemDialog(
        item: item,
        companyId: companyId,
        userId: userId,
      ),
    );
    
    // Refresh and clear filters to ensure new item is visible
    if (mounted) {
      // Clear local UI state (keep default sort)
      _searchController.clear();
      setState(() {
        _selectedCategory = null;
      });

      // Clear provider filters and reload
      final catalogProvider = context.read<CatalogProvider>();
      catalogProvider.clearFilters();
      await catalogProvider.loadCatalog(companyId);
      // Force sort by date created to show newest first
      catalogProvider.sortItems(SortOption.dateCreated);
    }
  }

  Future<void> _showEditItemDialog(CatalogItem item) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    final companyId = authProvider.currentUser?.companyId;

    if (userId == null || companyId == null) return;

    await showDialog(
      context: context,
      builder: (context) => _CatalogItemDialog(
        item: item,
        companyId: companyId,
        userId: userId,
      ),
    );
    
    // Refresh the catalog after dialog closes (keep existing filters for edits)
    if (mounted) {
      await context.read<CatalogProvider>().loadCatalog(companyId);
    }
  }

  Future<void> _showManageCategoriesDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const ManageCategoriesDialog(),
    );
    
    // Refresh the UI after dialog closes (in case categories were customized)
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteItem(CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to delete "${item.description}"?\n\n'
          'This will remove it from the catalog, but won\'t affect existing deliveries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      final userId = authProvider.currentUser?.id;

      if (companyId == null || userId == null) return;

      await context.read<CatalogProvider>().deleteItem(
            companyId,
            item.id,
            userId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Catalog Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Filter toggle
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
          ),
          // Multi-select toggle
          IconButton(
            icon: Icon(_isMultiSelectMode ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: _toggleMultiSelect,
            tooltip: _isMultiSelectMode ? 'Exit Multi-Select' : 'Enter Multi-Select',
          ),
          // Export button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCsv,
            tooltip: 'Export to CSV',
          ),
          // Add new item
          ElevatedButton.icon(
            onPressed: _showAddItemDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          // Bulk create items
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BulkItemCreationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.inventory_2),
            label: const Text('Bulk Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : KeyboardListener(
              focusNode: _focusNode,
              onKeyEvent: (KeyEvent event) => _handleKeyEvent(_focusNode, event),
              child: Consumer<CatalogProvider>(
                builder: (context, catalogProvider, _) {
                  return Row(
                    children: [
                      // Filter sidebar
                      if (_showFilters) _buildFilterSidebar(catalogProvider),

                      // Main content
                      Expanded(
                        child: Column(
                          children: [
                            // Statistics bar
                            _buildStatisticsBar(),

                            // Bulk actions bar (when in multi-select mode)
                            if (_isMultiSelectMode && _selectedItemIds.isNotEmpty)
                              _buildBulkActionsBar(),

                            // Items table area
                            Expanded(
                              child: Row(
                                children: [
                                  // Items table
                                  Expanded(
                                    child: catalogProvider.items.isEmpty
                                        ? _buildEmptyState()
                                        : _buildItemsTable(catalogProvider.items),
                                  ),
                                  // Detail panel
                                  if (_showDetailPanel && _selectedItem != null) ...[
                                    VerticalDivider(width: 1, color: Colors.grey[300]),
                                    _buildDetailPanel(),
                                  ],
                                ],
                              ),
                            ),

                            // Keyboard shortcuts bar
                            _buildKeyboardShortcutsBar(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildFilterSidebar(CatalogProvider catalogProvider) {
    return Container(
      width: 280,
      color: Colors.grey[50],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.filter_list, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                    _searchController.clear();
                  });
                  context.read<CatalogProvider>().clearFilters();
                },
                tooltip: 'Clear Filters',
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),

          // Search
          const Text(
            'Search Items',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by description or SKU...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _searchItems('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: _searchItems,
          ),
          const SizedBox(height: 24),

          // Category filter
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ItemCategory?>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...ItemCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Text(category.icon),
                      const SizedBox(width: 8),
                      Text(category.displayName),
                    ],
                  ),
                );
              }),
            ],
            onChanged: _filterByCategory,
          ),
          const SizedBox(height: 24),

          // Sort options
          const Text(
            'Sort By',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SortOption>(
            value: _sortBy,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: SortOption.values.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) _sortItems(value);
            },
          ),
          const SizedBox(height: 24),

          // Quick actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showManageCategoriesDialog,
            icon: const Icon(Icons.category, size: 18),
            label: const Text('Manage Categories'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBar() {
    return Consumer<CatalogProvider>(
      builder: (context, catalogProvider, child) {
        final items = catalogProvider.items;
        final totalItems = items.length;
        final activeItems = items.where((item) => item.isActive).length;
        final categories = items.map((item) => item.categoryId ?? item.category.name).toSet().length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              _buildStatCard(
                title: 'Total Items',
                value: totalItems.toString(),
                icon: Icons.inventory_2,
                color: Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                title: 'Active Items',
                value: activeItems.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                title: 'Categories',
                value: categories.toString(),
                icon: Icons.category,
                color: Colors.purple,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    if (!_isMultiSelectMode || _selectedItemIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedItemIds.length} item${_selectedItemIds.length == 1 ? '' : 's'} selected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showBulkDeleteDialog,
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showBulkCategoryDialog,
            icon: const Icon(Icons.category),
            label: const Text('Change Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardShortcutsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Keyboard Shortcuts:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          _buildShortcutChip('Ctrl+F', 'Search'),
          const SizedBox(width: 12),
          _buildShortcutChip('Ctrl+A', 'Select All'),
          const SizedBox(width: 12),
          _buildShortcutChip('Delete', 'Delete Selected'),
          const SizedBox(width: 12),
          _buildShortcutChip('Esc', 'Clear Selection'),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String shortcut, String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            shortcut,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            action,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (!_showDetailPanel || _selectedItemIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedItem = _selectedItemIds.length == 1
        ? _getItemById(_selectedItemIds.first)
        : null;

    if (selectedItem == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Item Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _showDetailPanel = false),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close panel',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item image placeholder
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Basic info
                  Text(
                    selectedItem.description,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SKU: ${selectedItem.sku ?? 'N/A'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // Pricing
                  _buildDetailSection(
                    title: 'Pricing',
                    children: [
                      _buildDetailRow('Unit Price', selectedItem.unitPrice != null ? '\$${selectedItem.unitPrice!.toStringAsFixed(2)}' : 'No price'),
                      _buildDetailRow('Default Quantity', selectedItem.defaultQuantity?.toString() ?? 'N/A'),
                      _buildDetailRow('Total Value', selectedItem.unitPrice != null && selectedItem.defaultQuantity != null
                          ? '\$${(selectedItem.unitPrice! * selectedItem.defaultQuantity!).toStringAsFixed(2)}'
                          : 'N/A'),
                    ],
                  ),

                  // Stock info
                  _buildDetailSection(
                    title: 'Stock Information',
                    children: [
                      _buildDetailRow('Default Quantity', selectedItem.defaultQuantity?.toString() ?? 'N/A'),
                      _buildDetailRow('Usage Count', selectedItem.usageCount.toString()),
                      _buildDetailRow('Status', selectedItem.isActive ? 'Active' : 'Inactive', valueColor: selectedItem.isActive ? Colors.green : Colors.grey),
                    ],
                  ),

                  // Category
                  _buildDetailSection(
                    title: 'Category',
                    children: [
                      _buildDetailRow('Category', selectedItem.category.displayName),
                    ],
                  ),

                  // Actions
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editItem(selectedItem),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Item'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _duplicateItem(selectedItem),
                          icon: const Icon(Icons.copy),
                          label: const Text('Duplicate'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteItem(selectedItem),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No catalog items yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first item to get started',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddItemDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add First Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<CatalogItem> items) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Default Qty', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Used', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.description,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.isPopular || item.isNew) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (item.isPopular)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'POPULAR',
                                    style: TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                ),
                              if (item.isNew) ...[
                                if (item.isPopular) const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      item.sku ?? '-',
                      style: TextStyle(
                        color: item.sku != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(Text(item.category.displayName)),
                  DataCell(Text(item.unit ?? '-')),
                  DataCell(Text(item.defaultQuantity?.toString() ?? '-')),
                  DataCell(Text(item.unitPrice != null ? item.formattedPrice : '-')),
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 16,
                          color: item.usageCount > 0 ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.usageCount}×',
                          style: TextStyle(
                            color: item.usageCount > 0 ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditItemDialog(item),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                          onPressed: () => _deleteItem(item),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }  void _clearSelection() {
    setState(() {
      _selectedItemIds.clear();
      _isMultiSelectMode = false;
    });
  }

  void _showBulkDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text('Are you sure you want to delete ${_selectedItemIds.length} item${_selectedItemIds.length == 1 ? '' : 's'}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performBulkDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkDelete() async {
    final itemCount = _selectedItemIds.length;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.currentUser?.companyId;
      final userId = authProvider.currentUser?.id;

      if (companyId == null || userId == null) return;

      final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);
      for (final itemId in _selectedItemIds) {
        await catalogProvider.deleteItem(companyId, itemId, userId);
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$itemCount item${itemCount == 1 ? '' : 's'} deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting items: $e')),
        );
      }
    }
  }

  void _showBulkCategoryDialog() {
    // For now, use enum categories. Could be extended to use custom categories later
    final categories = ItemCategory.values;

    showDialog(
      context: context,
      builder: (context) {
        ItemCategory? selectedCategory;
        return AlertDialog(
          title: const Text('Change Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a new category for the selected items:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<ItemCategory>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.displayName),
                  );
                }).toList(),
                onChanged: (value) => selectedCategory = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedCategory == null ? null : () async {
                Navigator.pop(context);
                await _performBulkCategoryChange(selectedCategory!);
              },
              child: const Text('Change Category'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performBulkCategoryChange(ItemCategory category) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null) return;

      final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);
      for (final itemId in _selectedItemIds) {
        final item = catalogProvider.getItemById(itemId);
        if (item != null) {
          final updatedItem = item.copyWith(category: category);
          await catalogProvider.updateItem(companyId, itemId, updatedItem);
        }
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating category: $e')),
        );
      }
    }
  }

  CatalogItem? _getItemById(String id) {
    final catalogProvider = Provider.of<CatalogProvider>(context, listen: false);
    return catalogProvider.getItemById(id);
  }

  void _editItem(CatalogItem item) {
    _showEditItemDialog(item);
  }

  void _duplicateItem(CatalogItem item) {
    final duplicatedItem = CatalogItem(
      id: '', // Will be set by Firestore
      companyId: item.companyId,
      description: '${item.description} (Copy)',
      sku: item.sku,
      unit: item.unit,
      defaultQuantity: item.defaultQuantity,
      unitPrice: item.unitPrice,
      category: item.category,
      categoryId: item.categoryId,
      isActive: item.isActive,
      usageCount: 0,
      createdAt: DateTime.now(),
      createdBy: item.createdBy, // Use current user
      updatedAt: DateTime.now(),
      updatedBy: item.updatedBy, // Use current user
    );
    _showAddItemDialog(duplicatedItem);
  }
}

// Dialog for adding/editing catalog items
class _CatalogItemDialog extends StatefulWidget {
  final CatalogItem? item;
  final String companyId;
  final String userId;

  const _CatalogItemDialog({
    this.item,
    required this.companyId,
    required this.userId,
  });

  @override
  State<_CatalogItemDialog> createState() => _CatalogItemDialogState();
}

class _CatalogItemDialogState extends State<_CatalogItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _skuController;
  late TextEditingController _unitController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late ItemCategory _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.item?.description ?? '');
    _skuController = TextEditingController(text: widget.item?.sku ?? '');
    _unitController = TextEditingController(text: widget.item?.unit ?? '');
    _quantityController = TextEditingController(
      text: widget.item?.defaultQuantity?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.item?.unitPrice?.toStringAsFixed(2) ?? '',
    );
    _selectedCategory = widget.item?.category ?? ItemCategory.general;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final catalogItem = CatalogItem(
        id: widget.item?.id ?? '',
        companyId: widget.companyId,
        description: _descriptionController.text.trim(),
        sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
        defaultQuantity: _quantityController.text.trim().isEmpty
            ? null
            : double.tryParse(_quantityController.text.trim()),
        unitPrice: _priceController.text.trim().isEmpty
            ? null
            : double.tryParse(_priceController.text.trim()),
        category: _selectedCategory,
        isActive: true,
        usageCount: widget.item?.usageCount ?? 0,
        lastUsed: widget.item?.lastUsed,
        createdAt: widget.item?.createdAt ?? now,
        createdBy: widget.item?.createdBy ?? widget.userId,
        updatedAt: now,
        updatedBy: widget.userId,
      );

      final catalogProvider = context.read<CatalogProvider>();

      if (widget.item == null) {
        await catalogProvider.addItem(widget.companyId, catalogItem);
      } else {
        await catalogProvider.updateItem(
          widget.companyId,
          widget.item!.id,
          catalogItem,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item == null ? 'Item added successfully' : 'Item updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Catalog Item' : 'Edit Catalog Item'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU / Part Number',
                    border: OutlineInputBorder(),
                    hintText: 'Optional',
                  ),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<ItemCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: ItemCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Text(category.icon),
                          const SizedBox(width: 8),
                          Text(category.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Default Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'e.g., boxes, pallets',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price (Optional)',
                    prefixText: 'R ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.item == null ? 'Add Item' : 'Save Changes'),
        ),
      ],
    );
  }
}
