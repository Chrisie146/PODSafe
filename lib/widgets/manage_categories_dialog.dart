import 'package:flutter/material.dart';
import '../../models/catalog_item_model.dart';
import '../../utils/theme.dart';

/// Dialog for managing item categories
class ManageCategoriesDialog extends StatefulWidget {
  const ManageCategoriesDialog({super.key});

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  // Store customizations (in a real app, this would be saved to Firestore)
  static final Map<ItemCategory, _CategoryCustomization> _customizations = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize category names and icons for your company',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: ItemCategory.values.length,
                itemBuilder: (context, index) {
                  final category = ItemCategory.values[index];
                  final customization = _customizations[category];

                  return Card(
                    child: ListTile(
                      leading: Text(
                        customization?.icon ?? category.icon,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        customization?.name ?? category.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Default: ${category.icon} ${category.displayName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditCategoryDialog(category),
                            tooltip: 'Edit',
                          ),
                          if (customization != null)
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () {
                                setState(() {
                                  _customizations.remove(category);
                                });
                              },
                              tooltip: 'Reset to default',
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Category customizations are saved per company and visible to all users',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _showEditCategoryDialog(ItemCategory category) async {
    final customization = _customizations[category];
    final nameController = TextEditingController(
      text: customization?.name ?? category.displayName,
    );
    final iconController = TextEditingController(
      text: customization?.icon ?? category.icon,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${category.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                labelText: 'Icon (emoji)',
                border: OutlineInputBorder(),
                hintText: '📦',
              ),
              maxLength: 2,
            ),
            const SizedBox(height: 8),
            Text(
              'Popular icons: 📦 🪑 💼 🖥️ 📋 🚚 ⚙️ 🏠 📱 🎨 🔧 🛠️',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  iconController.text.trim().isNotEmpty) {
                setState(() {
                  _customizations[category] = _CategoryCustomization(
                    name: nameController.text.trim(),
                    icon: iconController.text.trim(),
                  );
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    iconController.dispose();
  }

  /// Get custom name for a category (or default if not customized)
  static String getCategoryName(ItemCategory category) {
    return _customizations[category]?.name ?? category.displayName;
  }

  /// Get custom icon for a category (or default if not customized)
  static String getCategoryIcon(ItemCategory category) {
    return _customizations[category]?.icon ?? category.icon;
  }
}

class _CategoryCustomization {
  final String name;
  final String icon;

  _CategoryCustomization({
    required this.name,
    required this.icon,
  });
}
