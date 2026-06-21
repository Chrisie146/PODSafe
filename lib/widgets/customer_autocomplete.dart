import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../utils/theme.dart';

class CustomerAutocomplete extends StatefulWidget {
  final Customer? initialCustomer;
  final Function(Customer?) onCustomerSelected;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final String? Function(String?)? validator;

  const CustomerAutocomplete({
    super.key,
    this.initialCustomer,
    required this.onCustomerSelected,
    this.labelText = 'Customer',
    this.hintText = 'Search by customer number or name...',
    this.enabled = true,
    this.validator,
  });

  @override
  State<CustomerAutocomplete> createState() => _CustomerAutocompleteState();
}

class _CustomerAutocompleteState extends State<CustomerAutocomplete> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  List<Customer> _searchResults = [];
  bool _showDropdown = false;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
    _controller = TextEditingController(
      text: widget.initialCustomer?.displayString ?? '',
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showDropdown = true);
        if (_controller.text.isEmpty) {
          _loadFavoritesAndRecent();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadFavoritesAndRecent() async {
    final provider = context.read<CustomerProvider>();
    setState(() {
      _searchResults = [
        ...provider.favoriteCustomers,
        ...provider.customers.take(10),
      ];
      _showDropdown = true;
    });
  }

  void _search(String query) async {
    if (query.isEmpty) {
      _loadFavoritesAndRecent();
      return;
    }

    try {
      final provider = context.read<CustomerProvider>();
      final results = await provider.searchCustomers(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _showDropdown = true;
        });
      }
    } catch (e) {
      // Search failed, keep existing results
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _controller.text = customer.displayString;
      _showDropdown = false;
    });
    widget.onCustomerSelected(customer);
    _focusNode.unfocus();
  }

  void _clearSelection() {
    setState(() {
      _selectedCustomer = null;
      _controller.clear();
      _searchResults = [];
      _showDropdown = false;
    });
    widget.onCustomerSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.person),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCustomer != null && _selectedCustomer!.isFavorite)
                  const Icon(Icons.star, color: AppTheme.warningColor, size: 20),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: widget.enabled ? _clearSelection : null,
                  ),
              ],
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            // Clear selection if user types manually
            if (_selectedCustomer != null &&
                value != _selectedCustomer!.displayString) {
              setState(() => _selectedCustomer = null);
              widget.onCustomerSelected(null);
            }
            _search(value);
          },
          validator: widget.validator,
        ),
        if (_showDropdown && _searchResults.isNotEmpty)
          _buildDropdown(),
      ],
    );
  }

  Widget _buildDropdown() {
    return Card(
      margin: const EdgeInsets.only(top: 4),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            if (_controller.text.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Text(
                      'Favorites & Recent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Results
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final customer = _searchResults[index];
                  return _buildCustomerTile(customer);
                },
              ),
            ),

            // Close button
            Divider(height: 1, color: Colors.grey[300]),
            InkWell(
              onTap: () => setState(() => _showDropdown = false),
              child: Container(
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTile(Customer customer) {
    return InkWell(
      onTap: () => _selectCustomer(customer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            // Customer icon with type indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: customer.customerType == CustomerType.business
                    ? AppTheme.primaryColor.withValues(alpha: 26)
                    : Colors.green.withValues(alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                customer.customerType == CustomerType.business
                    ? Icons.business
                    : Icons.home,
                size: 20,
                color: customer.customerType == CustomerType.business
                    ? AppTheme.primaryColor
                    : Colors.green,
              ),
            ),
            const SizedBox(width: 12),

            // Customer details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        customer.displayString,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (customer.isFavorite) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.phone!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Stats
            if (customer.stats.totalDeliveries > 0) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${customer.stats.totalDeliveries} deliveries',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                  if (customer.stats.lastDelivery != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatLastDelivery(customer.stats.lastDelivery!),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatLastDelivery(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }
}
