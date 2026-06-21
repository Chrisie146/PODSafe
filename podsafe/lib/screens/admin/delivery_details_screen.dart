import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../models/delivery_model.dart';
import 'create_delivery_screen.dart';
import 'pod_details_screen.dart';

class DeliveryDetailsScreen extends StatefulWidget {
  final Delivery delivery;

  const DeliveryDetailsScreen({super.key, required this.delivery});

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  Map<String, dynamic>? _driverInfo;
  Map<String, dynamic>? _podData;
  bool _isLoadingDriver = true;
  bool _isLoadingPOD = true;

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
    _loadPODInfo();
  }

  Future<void> _loadDriverInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.delivery.driverId)
          .get();

      if (doc.exists) {
        setState(() {
          _driverInfo = doc.data();
          _isLoadingDriver = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver info: $e');
      setState(() => _isLoadingDriver = false);
    }
  }

  Future<void> _loadPODInfo() async {
    try {
      if (widget.delivery.podId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('pods')
            .doc(widget.delivery.podId)
            .get();

        if (doc.exists) {
          setState(() {
            _podData = doc.data();
            _isLoadingPOD = false;
          });
        }
      } else {
        setState(() => _isLoadingPOD = false);
      }
    } catch (e) {
      debugPrint('Error loading POD info: $e');
      setState(() => _isLoadingPOD = false);
    }
  }

  Future<void> _deleteDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery'),
        content: const Text(
          'Are you sure you want to delete this delivery? This action cannot be undone.',
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

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(widget.delivery.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery deleted successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting delivery: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateDeliveryScreen(
                    delivery: widget.delivery,
                  ),
                ),
              );
              if (result == true && mounted) {
                Navigator.pop(context, true); // Return to refresh list
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteDelivery,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.delivery.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _getStatusColor(widget.delivery.status),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(widget.delivery.status),
                      color: _getStatusColor(widget.delivery.status),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(widget.delivery.status),
                      style: TextStyle(
                        color: _getStatusColor(widget.delivery.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Customer Information
            _buildSectionTitle('Customer Information'),
            _buildInfoCard([
              _buildInfoRow('Name', widget.delivery.customerName),
              _buildInfoRow('Address', widget.delivery.customerAddress),
              if (widget.delivery.customerPhone != null)
                _buildInfoRow('Phone', widget.delivery.customerPhone!),
            ]),
            const SizedBox(height: 20),

            // Delivery Information
            _buildSectionTitle('Delivery Information'),
            _buildInfoCard([
              if (widget.delivery.orderNumber != null)
                _buildInfoRow('Order Number', widget.delivery.orderNumber!),
              _buildInfoRow('Invoice Number', widget.delivery.invoiceNumber),
              if (widget.delivery.vehicleUsed != null)
                _buildInfoRow('Vehicle Used', widget.delivery.vehicleUsed!),
              _buildInfoRow(
                'Scheduled Date',
                DateFormat('EEEE, MMMM d, y').format(widget.delivery.scheduledDate),
              ),
              _buildInfoRow(
                'Created',
                DateFormat('MMM d, y • h:mm a').format(widget.delivery.createdAt),
              ),
              if (widget.delivery.deliveredAt != null)
                _buildInfoRow(
                  'Delivered',
                  DateFormat('MMM d, y • h:mm a').format(widget.delivery.deliveredAt!),
                ),
            ]),
            const SizedBox(height: 20),

            // Third-Party Transport Section
            if (widget.delivery.isThirdPartyTransport) ...[
              _buildSectionTitle('Third-Party Transport'),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'External Transport Provider',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Provider', widget.delivery.thirdPartyProviderName ?? 'N/A'),
                      if (widget.delivery.thirdPartyDriverName != null)
                        _buildInfoRow('Driver', widget.delivery.thirdPartyDriverName!),
                      if (widget.delivery.thirdPartyDriverPhone != null)
                        _buildInfoRow('Phone', widget.delivery.thirdPartyDriverPhone!),
                      if (widget.delivery.thirdPartyVehicleInfo != null)
                        _buildInfoRow('Vehicle', widget.delivery.thirdPartyVehicleInfo!),
                      if (widget.delivery.uploadToken != null) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.link, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Upload Link',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: SelectableText(
                            'https://podsafe.app/upload/${widget.delivery.uploadToken}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Copy to clipboard
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Link copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy Link'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Share via WhatsApp
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('WhatsApp sharing coming soon'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share'),
                            ),
                          ],
                        ),
                      ],
                      if (widget.delivery.thirdPartyDocs != null && 
                          widget.delivery.thirdPartyDocs!.isNotEmpty) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Documents Uploaded (${widget.delivery.thirdPartyDocs!.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.delivery.thirdPartyDocs!.map((url) {
                            return InkWell(
                              onTap: () {
                                _showImageFullScreen(url, 'Third-Party Document');
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.broken_image, color: Colors.grey),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Driver Information (only show if NOT third-party)
            if (!widget.delivery.isThirdPartyTransport) ...[
              _buildSectionTitle('Driver Information'),
              _isLoadingDriver
                  ? const Center(child: CircularProgressIndicator())
                  : _buildInfoCard([
                      _buildInfoRow(
                        'Name',
                        _driverInfo?['displayName'] ?? 'Unknown Driver',
                      ),
                      if (_driverInfo?['email'] != null)
                        _buildInfoRow('Email', _driverInfo!['email']),
                      if (_driverInfo?['vehicleInfo'] != null)
                        _buildInfoRow(
                          'Vehicle Registration',
                          _driverInfo!['vehicleInfo'],
                        ),
                    ]),
              const SizedBox(height: 20),
            ],

            // Delivery Items
            _buildSectionTitle('Delivery Items (${widget.delivery.items.length})'),
            ...widget.delivery.items.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(item.description),
                  subtitle: item.unit != null ? Text('Unit: ${item.unit}') : null,
                ),
              );
            }),
            const SizedBox(height: 20),

            // Notes
            if (widget.delivery.notes != null) ...[
              _buildSectionTitle('Notes'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.delivery.notes!,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // POD Information
            if (widget.delivery.status == DeliveryStatus.delivered) ...[
              _buildSectionTitle('Proof of Delivery'),
              _isLoadingPOD
                  ? const Center(child: CircularProgressIndicator())
                  : _podData != null
                      ? Card(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PODDetailsScreen(
                                    podId: widget.delivery.podId!,
                                    podData: _podData!,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.receipt_long,
                                    color: AppTheme.successColor,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'POD Available',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Tap to view signature, photo, and GPS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey.shade400,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'No POD available for this delivery',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.heading3,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return AppTheme.warningColor;
      case DeliveryStatus.inTransit:
        return AppTheme.infoColor;
      case DeliveryStatus.delivered:
        return AppTheme.successColor;
      case DeliveryStatus.failed:
        return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Icons.schedule;
      case DeliveryStatus.inTransit:
        return Icons.local_shipping;
      case DeliveryStatus.delivered:
        return Icons.check_circle;
      case DeliveryStatus.failed:
        return Icons.error;
    }
  }

  String _getStatusText(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.inTransit:
        return 'In Transit';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.failed:
        return 'Failed';
    }
  }

  void _showImageFullScreen(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.grey[400], size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
