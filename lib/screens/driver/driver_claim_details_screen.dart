import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/claim_model.dart';
import '../../utils/theme.dart';

/// Screen for drivers to view their claim details (read-only)
class DriverClaimDetailsScreen extends StatefulWidget {
  final Claim claim;

  const DriverClaimDetailsScreen({
    super.key,
    required this.claim,
  });

  @override
  State<DriverClaimDetailsScreen> createState() => _DriverClaimDetailsScreenState();
}

class _DriverClaimDetailsScreenState extends State<DriverClaimDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Claim Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim header
            _buildClaimHeader(claim),

            const SizedBox(height: 24),

            // Claim details
            _buildClaimDetails(claim),

            const SizedBox(height: 24),

            // Photos section
            if (claim.photoUrls.isNotEmpty) ...[
              _buildPhotosSection(claim),
              const SizedBox(height: 24),
            ],

            // Status timeline
            _buildStatusTimeline(claim),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimHeader(Claim claim) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.invoiceNumber ?? claim.id,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getClaimTypeDisplay(claim.type),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(claim.status),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              claim.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimDetails(Claim claim) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Claim Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Filed Date', DateFormat('MMM d, y HH:mm').format(claim.createdAt)),
            _buildDetailRow('Delivery Date', DateFormat('MMM d, y').format(claim.deliveryDate)),
            if (claim.claimAmount != null)
              _buildDetailRow('Claim Amount', '\$${claim.claimAmount!.toStringAsFixed(2)}'),
            _buildDetailRow('Customer', claim.customerName),
            if (claim.customerAccountNumber != null)
              _buildDetailRow('Account Number', claim.customerAccountNumber!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(Claim claim) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: claim.photoUrls.length,
              itemBuilder: (context, index) {
                final photoUrl = claim.photoUrls[index];
                return GestureDetector(
                  onTap: () => _showPhotoDialog(context, photoUrl, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(Claim claim) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            // Current status
            _buildStatusItem(
              'Filed',
              claim.createdAt,
              isCompleted: true,
            ),
            // Add more status items based on claim history
            if (claim.status == ClaimStatus.approved)
              _buildStatusItem(
                'Approved',
                claim.updatedAt,
                isCompleted: true,
              )
            else if (claim.status == ClaimStatus.rejected)
              _buildStatusItem(
                'Rejected',
                claim.updatedAt,
                isCompleted: true,
              )
            else if (claim.status == ClaimStatus.pendingReview)
              _buildStatusItem(
                'Under Review',
                claim.updatedAt,
                isCompleted: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String status, DateTime date, {bool isCompleted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? AppTheme.successColor : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('MMM d, y HH:mm').format(date),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ClaimStatus status) {
    Color color;
    String text;

    switch (status) {
      case ClaimStatus.pendingReview:
        color = Colors.orange;
        text = 'Under Review';
        break;
      case ClaimStatus.approved:
        color = AppTheme.successColor;
        text = 'Approved';
        break;
      case ClaimStatus.rejected:
        color = AppTheme.errorColor;
        text = 'Rejected';
        break;
      case ClaimStatus.submitted:
        color = Colors.blue;
        text = 'Submitted';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getClaimTypeDisplay(ClaimType type) {
    switch (type) {
      case ClaimType.damaged:
        return 'Damaged Goods Claim';
      case ClaimType.shortage:
        return 'Short Delivery Claim';
      case ClaimType.shortWeight:
        return 'Short Weight Claim';
      case ClaimType.missing:
        return 'Missing Items Claim';
      case ClaimType.wrongItems:
        return 'Wrong Items Claim';
      case ClaimType.returns:
        return 'Returns Claim';
      case ClaimType.priceError:
        return 'Price Error Claim';
      case ClaimType.lateDelivery:
        return 'Late Delivery Claim';
      case ClaimType.didNotDeliver:
        return 'Did Not Deliver Claim';
      case ClaimType.qualityIssue:
        return 'Quality Issue Claim';
      case ClaimType.temperatureIssue:
        return 'Temperature Issue Claim';
      case ClaimType.packagingIssue:
        return 'Packaging Issue Claim';
      case ClaimType.expiryIssue:
        return 'Expiry Issue Claim';
      case ClaimType.serviceIssue:
        return 'Service Issue Claim';
      case ClaimType.other:
        return 'Other Claim';
    }
  }

  void _showPhotoDialog(BuildContext context, String photoUrl, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}