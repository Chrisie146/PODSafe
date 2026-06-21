import 'package:flutter/material.dart';
import 'dart:async';
import '../models/catalog_item_model.dart';
import '../utils/theme.dart';

/// Autocomplete widget for selecting catalog items
class ItemAutocomplete extends StatefulWidget {
  final List<CatalogItem> items;
  final Function(CatalogItem) onItemSelected;
  final String? initialValue;
  final TextEditingController? controller;
  final bool enabled;
  final InputDecoration? decoration;

  const ItemAutocomplete({
    super.key,
    required this.items,
    required this.onItemSelected,
    this.initialValue,
    this.controller,
    this.enabled = true,
    this.decoration,
  });

  @override
  State<ItemAutocomplete> createState() => _ItemAutocompleteState();
}

class _ItemAutocompleteState extends State<ItemAutocomplete> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<CatalogItem> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _updateSuggestions();
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateSuggestions();
    } else {
      // Delay to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _updateSuggestions() {
    final query = _controller.text.toLowerCase().trim();

    if (query.isEmpty) {
      // Show popular items when field is empty
      setState(() {
        _suggestions = widget.items.take(5).toList();
        _showSuggestions = true;
      });
    } else {
      // Filter and sort items based on query
      final filtered = widget.items.where((item) {
        final descLower = item.description.toLowerCase();
        final unitLower = item.unit?.toLowerCase() ?? '';
        return descLower.contains(query) || unitLower.contains(query);
      }).toList();

      // Sort by relevance
      filtered.sort((a, b) {
        final aDesc = a.description.toLowerCase();
        final bDesc = b.description.toLowerCase();

        // Exact match first
        if (aDesc == query && bDesc != query) return -1;
        if (bDesc == query && aDesc != query) return 1;

        // Starts with query
        if (aDesc.startsWith(query) && !bDesc.startsWith(query)) return -1;
        if (bDesc.startsWith(query) && !aDesc.startsWith(query)) return 1;

        // Otherwise by usage count
        return b.usageCount.compareTo(a.usageCount);
      });

      setState(() {
        _suggestions = filtered.take(10).toList();
        _showSuggestions = filtered.isNotEmpty;
      });
    }

    if (_showSuggestions && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _suggestions.isEmpty
                  ? _buildNoResultsWidget()
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        return _buildSuggestionItem(_suggestions[index]);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'No matching items found',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a custom item',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(CatalogItem item) {
    return InkWell(
      onTap: () {
        _controller.text = item.description;
        widget.onItemSelected(item);
        _removeOverlay();
        _focusNode.unfocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Text(
              item.category.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isPopular) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ],
                      if (item.isNew) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.sku != null) ...[
                        Text(
                          'SKU: ${item.sku}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (item.defaultQuantity != null) ...[
                        Text(
                          '${item.defaultQuantity} ${item.unit ?? ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (item.unitPrice != null) ...[
                          Text(
                            ' • ',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                      if (item.unitPrice != null)
                        Text(
                          item.formattedPrice,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const Spacer(),
                      if (item.usageCount > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item.usageCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: widget.decoration ??
            InputDecoration(
              labelText: 'Description *',
              hintText: 'Start typing or select from catalog...',
              prefixIcon: const Icon(Icons.inventory_2),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _controller.clear();
                        _updateSuggestions();
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
        onChanged: (value) {
          // Handled by listener
        },
      ),
    );
  }
}

/// Simple autocomplete for unit field
class UnitAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> commonUnits = const [
    'boxes',
    'pallets',
    'cases',
    'units',
    'pieces',
    'crates',
    'cartons',
    'bags',
    'rolls',
    'sheets',
  ];

  const UnitAutocomplete({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return commonUnits;
        }
        return commonUnits.where((String option) {
          return option
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Sync with provided controller
        if (controller.text.isNotEmpty && fieldController.text.isEmpty) {
          fieldController.text = controller.text;
        }
        
        fieldController.addListener(() {
          if (controller.text != fieldController.text) {
            controller.text = fieldController.text;
          }
        });

        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Unit (Optional)',
            hintText: 'e.g., boxes, pallets, cases',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (String value) {
            onFieldSubmitted();
          },
        );
      },
    );
  }
}
