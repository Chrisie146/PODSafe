import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/delivery_model.dart';
import '../../providers/delivery_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/pod_qr_code.dart';
import '../../services/pod_token_service.dart';
import 'pod_capture_screen.dart';
import 'report_issue_screen.dart';

class DeliveryDetailsScreen extends StatelessWidget {
  final Delivery delivery;

  const DeliveryDetailsScreen({
    super.key,
    required this.delivery,
  });

  @override
  Widget build(BuildContext context) {
    // Get safe area insets for proper spacing
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppTheme.paddingMedium,
            right: AppTheme.paddingMedium,
            top: AppTheme.paddingMedium,
            // Add bottom padding that accounts for navigation bar + extra space
            bottom: bottomPadding > 0 ? bottomPadding + 16 : 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildCustomerInfoCard(),
              const SizedBox(height: 16),
              _buildDeliveryInfoCard(),
              const SizedBox(height: 16),
              _buildItemsCard(),
              const SizedBox(height: 24),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _getStatusText(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    delivery.invoiceNumber,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Information',
              style: AppTextStyles.heading3,
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.person, 'Name', delivery.customerName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Phone', delivery.customerPhone ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Information',
              style: AppTextStyles.heading3,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.location_on_outlined,
              'Delivery Address',
              delivery.customerAddress,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.access_time,
              'Scheduled Time',
              _formatDateTime(delivery.scheduledDate),
            ),
            if (delivery.notes != null && delivery.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.info_outline,
                'Notes',
                delivery.notes!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Items',
              style: AppTextStyles.heading3,
            ),
            const Divider(height: 24),
            ...delivery.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Qty: ${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    // Allow POD capture for pending, inTransit deliveries (not delivered or failed)
    final canCapturePOD = delivery.status == DeliveryStatus.pending || 
                          delivery.status == DeliveryStatus.inTransit;
    
    // Can report issues for any delivery (during or after)
    final canReportIssue = true; // Always available

    return Column(
      children: [
        if (delivery.status == DeliveryStatus.pending)
          CustomButton(
            text: 'Start Delivery',
            onPressed: () => _updateStatus(context, DeliveryStatus.inTransit),
            icon: Icons.local_shipping,
          ),
        if (canCapturePOD) ...[
          const SizedBox(height: 12),
          CustomButton(
            text: 'Capture Proof of Delivery',
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PODCaptureScreen(delivery: delivery),
                ),
              );
              // If POD was successfully captured, go back to previous screen (dashboard)
              if (result == true && context.mounted) {
                Navigator.of(context).pop(); // Close delivery details screen
              }
            },
            icon: Icons.camera_alt,
            backgroundColor: AppTheme.successColor,
          ),
        ],
        if (delivery.status == DeliveryStatus.delivered) ...[
          const SizedBox(height: 12),
          CustomButton(
            text: 'View QR Code',
            onPressed: () async {
              try {
                final token = await PODTokenService().getTokenByDeliveryId(delivery.id);
                if (token != null && context.mounted) {
                  await PODQRCodeDialog.show(context, token: token);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('QR code not available yet. Please try again in a moment.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to load QR code: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            icon: Icons.qr_code_2,
            backgroundColor: AppTheme.primaryColor,
          ),
        ],
        if (canReportIssue) ...[
          const SizedBox(height: 12),
          CustomButton(
            text: 'Report Issue',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ReportIssueScreen(
                    delivery: delivery,
                    pod: null, // TODO: Get POD if exists
                    isAtDeliverySite: delivery.status == DeliveryStatus.inTransit,
                  ),
                ),
              );
            },
            icon: Icons.report_problem,
            backgroundColor: Colors.orange,
          ),
        ],
      ],
    );
  }

  void _updateStatus(BuildContext context, DeliveryStatus newStatus) async {
    final deliveryProvider = context.read<DeliveryProvider>();
    
    try {
      final updatedDelivery = Delivery(
        id: delivery.id,
        companyId: delivery.companyId,
        driverId: delivery.driverId,
        customerName: delivery.customerName,
        customerPhone: delivery.customerPhone,
        customerAddress: delivery.customerAddress,
        customerId: delivery.customerId,
        customerNumber: delivery.customerNumber,
        orderNumber: delivery.orderNumber,
        status: newStatus,
        scheduledDate: delivery.scheduledDate,
        items: delivery.items,
        invoiceNumber: delivery.invoiceNumber,
        createdAt: delivery.createdAt,
        deliveredAt: newStatus == DeliveryStatus.delivered ? DateTime.now() : delivery.deliveredAt,
        notes: delivery.notes,
        podId: delivery.podId,
      );

      await deliveryProvider.updateDelivery(updatedDelivery);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${_getStatusText()}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  IconData _getStatusIcon() {
    switch (delivery.status) {
      case DeliveryStatus.pending:
        return Icons.pending;
      case DeliveryStatus.inTransit:
        return Icons.local_shipping;
      case DeliveryStatus.delivered:
        return Icons.check_circle;
      case DeliveryStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusColor() {
    switch (delivery.status) {
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

  String _getStatusText() {
    switch (delivery.status) {
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
