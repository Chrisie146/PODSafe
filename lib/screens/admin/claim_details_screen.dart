import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/claim_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/location_map_widget.dart';
import 'claim_details_desktop.dart';

/// Responsive admin screen for viewing and reviewing claim details
/// Automatically switches between mobile and desktop layouts based on screen width
class ClaimDetailsScreen extends StatelessWidget {
  final Claim claim;

  const ClaimDetailsScreen({
    super.key,
    required this.claim,
  });

  @override
  Widget build(BuildContext context) {
    // Use the provider's latest claim instance when available so UI updates
    final provider = Provider.of<ClaimProvider>(context);
    final latestClaim = provider.claims.firstWhere(
      (c) => c.id == claim.id,
      orElse: () => claim,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Switch to desktop layout for wide screens (> 1000px)
        if (constraints.maxWidth > 1000) {
          return ClaimDetailsDesktop(claim: latestClaim);
        }
        // Use mobile layout for narrow screens
        return ClaimDetailsMobile(claim: latestClaim);
      },
    );
  }
}

/// Mobile-optimized layout for claim details
class ClaimDetailsMobile extends StatefulWidget {
  final Claim claim;

  const ClaimDetailsMobile({
    super.key,
    required this.claim,
  });

  @override
  State<ClaimDetailsMobile> createState() => _ClaimDetailsMobileState();
}

class _ClaimDetailsMobileState extends State<ClaimDetailsMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _commentController = TextEditingController();
  final _resolutionNotesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _resolutionNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.claim.id),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'assign',
                child: Row(
                  children: [
                    Icon(Icons.person_add, size: 20),
                    SizedBox(width: 8),
                    Text('Assign to User'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'priority',
                child: Row(
                  children: [
                    Icon(Icons.flag, size: 20),
                    SizedBox(width: 8),
                    Text('Change Priority'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 20),
                    SizedBox(width: 8),
                    Text('Export to PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download_all',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Download All Evidence'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'close',
                child: Row(
                  children: [
                    Icon(Icons.close, size: 20),
                    SizedBox(width: 8),
                    Text('Close Claim'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Evidence'),
            Tab(text: 'History'),
            Tab(text: 'Comments'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Status Banner
          _buildStatusBanner(),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                _buildEvidenceTab(),
                _buildHistoryTab(),
                _buildCommentsTab(),
              ],
            ),
          ),

          // Action Buttons (only show if claim is actionable)
          if (_canTakeAction()) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final status = widget.claim.status;
    Color backgroundColor;
    Color textColor;
    String message;
    IconData icon;

    switch (status) {
      case ClaimStatus.submitted:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        message = 'New claim awaiting review';
        icon = Icons.new_releases;
        break;
      case ClaimStatus.pendingReview:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        message = 'Pending your review';
        icon = Icons.pending_actions;
        break;
      case ClaimStatus.pendingApproval:
        backgroundColor = Colors.amber[100]!;
        textColor = Colors.amber[900]!;
        message = 'Pending approval';
        icon = Icons.approval;
        break;
      case ClaimStatus.approved:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        message = 'Claim approved';
        icon = Icons.check_circle;
        break;
      case ClaimStatus.rejected:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        message = 'Claim rejected';
        icon = Icons.cancel;
        break;
      case ClaimStatus.resolved:
        backgroundColor = Colors.teal[100]!;
        textColor = Colors.teal[900]!;
        message = 'Claim resolved';
        icon = Icons.task_alt;
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        message = 'Status: ${status.name}';
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: textColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Claim Information
          _buildSection(
            title: 'Claim Information',
            icon: Icons.receipt_long,
            children: [
              _buildInfoRow('Claim ID', widget.claim.id),
              _buildInfoRow('Type', _getClaimTypeDisplay(widget.claim.type)),
              _buildInfoRow('Status', widget.claim.status.name),
              _buildInfoRow('Priority', widget.claim.priority.name),
              _buildInfoRow(
                'Filed',
                DateFormat('MMM d, yyyy h:mm a').format(widget.claim.createdAt),
              ),
              if (widget.claim.claimAmount != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: const Text(
                          'Claimed Amount:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'R${widget.claim.claimAmount!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _showEditAmountDialog,
                              child: Tooltip(
                                message: 'Edit amount',
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Customer & Delivery Information
          _buildSection(
            title: 'Customer & Delivery',
            icon: Icons.person,
            children: [
              _buildInfoRow('Customer', widget.claim.customerName),
              if (widget.claim.customerAccountNumber != null)
                _buildInfoRow('Customer ID', widget.claim.customerAccountNumber!),
              _buildInfoRow('Driver', widget.claim.driverName),
              _buildInfoRow('Delivery ID', widget.claim.deliveryId),
              if (widget.claim.invoiceNumber != null)
                _buildInfoRow('Invoice', widget.claim.invoiceNumber!),
            ],
          ),

          const SizedBox(height: 20),

          // Description
          _buildSection(
            title: 'Description',
            icon: Icons.description,
            children: [
              Text(
                widget.claim.description.isNotEmpty
                    ? widget.claim.description
                    : 'No description provided',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Affected Items
          if (widget.claim.affectedItems.isNotEmpty)
            _buildSection(
              title: 'Affected Items (${widget.claim.affectedItems.length})',
              icon: Icons.inventory_2,
              children: widget.claim.affectedItems.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['productName'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantity: ${item['quantity'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),

          // Location (if available)
          if (widget.claim.gpsLocation.isNotEmpty) ...[
            _buildSection(
              title: 'Location',
              icon: Icons.location_on,
              children: [
                _buildInfoRow(
                  'Coordinates',
                  '${widget.claim.gpsLocation['latitude']}, ${widget.claim.gpsLocation['longitude']}',
                ),
                const SizedBox(height: 12),
                LocationMapWidget(
                  latitude: _toDouble(widget.claim.gpsLocation['latitude']),
                  longitude: _toDouble(widget.claim.gpsLocation['longitude']),
                  accuracy: _toDouble(widget.claim.gpsLocation['accuracy']),
                  address: widget.claim.gpsLocation['address'] as String?,
                  height: 250,
                  showAccuracyCircle: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Evidence Quality Score
          // Evidence Quality Score
          _buildSection(
            title: 'Evidence Quality',
            icon: Icons.verified,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: widget.claim.evidenceQualityScore / 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.claim.evidenceQualityScore >= 7
                            ? Colors.green
                            : widget.claim.evidenceQualityScore >= 5
                                ? Colors.orange
                                : Colors.red,
                      ),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.claim.evidenceQualityScore}/10',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEvidenceTab() {
    final hasPhotos = widget.claim.photoUrls.isNotEmpty;
    final hasSignature = widget.claim.customerSignatureUrl != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photos
          if (hasPhotos) ...[
            _buildSection(
              title: 'Photos (${widget.claim.photoUrls.length})',
              icon: Icons.photo_library,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: widget.claim.photoUrls.length,
                  itemBuilder: (context, index) {
                    final photoUrl = widget.claim.photoUrls[index];
                    return GestureDetector(
                      onTap: () => _showPhotoViewer(context, index),
                      child: Hero(
                        tag: 'photo_$index',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Signature
          if (hasSignature) ...[
            _buildSection(
              title: 'Customer Signature',
              icon: Icons.draw,
              children: [
                GestureDetector(
                  onTap: () => _showSignatureViewer(context),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: widget.claim.customerSignatureUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // No Evidence Message
          if (!hasPhotos && !hasSignature)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No evidence attached',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
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

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.claim.statusHistory.length,
      itemBuilder: (context, index) {
        final historyItem = widget.claim.statusHistory[index];
        final isLast = index == widget.claim.statusHistory.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLast
                        ? AppTheme.primaryColor
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(historyItem.status),
                    color: isLast ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusDisplay(historyItem.status),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
                      color: isLast ? AppTheme.primaryColor : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy h:mm a').format(historyItem.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${historyItem.userName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (historyItem.notes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        historyItem.notes!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        // Comments List
        Expanded(
          child: widget.claim.comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No comments yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.claim.comments.length,
                  itemBuilder: (context, index) {
                    final comment = widget.claim.comments[index];
                    return _buildCommentCard(comment);
                  },
                ),
        ),

        // Add Comment Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addComment,
                icon: const Icon(Icons.send),
                color: AppTheme.primaryColor,
                tooltip: 'Send',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentCard(ClaimComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: comment.isInternal ? Colors.orange[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: comment.isInternal ? Colors.orange[200]! : Colors.blue[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    comment.isInternal ? Colors.orange : Colors.blue,
                child: Text(
                  comment.userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (comment.isInternal) ...[
                          const SizedBox(width: 8),
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
                              'INTERNAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      DateFormat('MMM d, yyyy h:mm a').format(comment.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.comment,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _showRejectDialog(),
              icon: const Icon(Icons.cancel),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _showApproveDialog(),
              icon: const Icon(Icons.check_circle),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  /// Convert any value to double, with validation and logging
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    
    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      debugPrint('⚠️ Could not convert $value (${value.runtimeType}) to double, using 0.0');
      return 0.0;
    } catch (e) {
      debugPrint('❌ Error converting $value to double: $e');
      return 0.0;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canTakeAction() {
    return widget.claim.status == ClaimStatus.submitted ||
        widget.claim.status == ClaimStatus.pendingReview ||
        widget.claim.status == ClaimStatus.pendingApproval;
  }

  Future<void> _showEditAmountDialog() async {
    final amountController = TextEditingController(
      text: widget.claim.claimAmount?.toStringAsFixed(2) ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Claim Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Amount: R${widget.claim.claimAmount?.toStringAsFixed(2) ?? "0.00"}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'New Amount',
                prefixText: 'R ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an amount'),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Update Amount'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newAmount = double.tryParse(amountController.text);
      if (newAmount != null) {
        await _updateClaimAmount(newAmount);
      }
      amountController.dispose();
    }
  }

  Future<void> _updateClaimAmount(double newAmount) async {
    try {
      setState(() => _isSubmitting = true);

      final claimProvider = context.read<ClaimProvider>();

      // Create updated claim with new amount
      final updatedClaim = widget.claim.copyWith(
        claimAmount: newAmount,
        updatedAt: DateTime.now(),
      );

      // Update via provider
      final success = await claimProvider.updateClaim(updatedClaim);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Amount updated from R${widget.claim.claimAmount?.toStringAsFixed(2)} to R${newAmount.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh the page by popping and re-opening
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(claimProvider.error ?? 'Failed to update amount'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'assign':
        _showAssignDialog();
        break;
      case 'priority':
        _showPriorityDialog();
        break;
      case 'export':
        _exportToPDF();
        break;
      case 'download_all':
        _downloadAllEvidence();
        break;
      case 'close':
        _closeClaim();
        break;
    }
  }

  Future<void> _showApproveDialog() async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve claim ${widget.claim.id}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                hintText: 'Add any notes or comments...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _approveClaim(notesController.text);
    }
  }

  Future<void> _showRejectDialog() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject claim ${widget.claim.id}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
                hintText: 'Provide a reason for rejection...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _rejectClaim(reasonController.text);
    }
  }

  Future<void> _approveClaim(String notes) async {
    setState(() => _isSubmitting = true);

    try {
      final claimProvider = context.read<ClaimProvider>();
      final authProvider = context.read<AuthProvider>();

      final success = await claimProvider.updateClaimStatus(
        claimId: widget.claim.id,
        newStatus: ClaimStatus.approved,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.fullName,
        notes: notes.isNotEmpty ? notes : null,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Claim approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(claimProvider.error ?? 'Failed to approve claim'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving claim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _rejectClaim(String reason) async {
    setState(() => _isSubmitting = true);

    try {
      final claimProvider = context.read<ClaimProvider>();
      final authProvider = context.read<AuthProvider>();

      final success = await claimProvider.updateClaimStatus(
        claimId: widget.claim.id,
        newStatus: ClaimStatus.rejected,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.fullName,
        notes: reason,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Claim rejected'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(claimProvider.error ?? 'Failed to reject claim'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting claim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final claimProvider = context.read<ClaimProvider>();
      final authProvider = context.read<AuthProvider>();
      
      final comment = ClaimComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.fullName,
        userRole: authProvider.currentUser!.role.toString(),
        comment: text,
        timestamp: DateTime.now(),
        isInternal: true,
      );
      
      final success = await claimProvider.addComment(
        claimId: widget.claim.id,
        comment: comment,
      );

      if (success) {
        _commentController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add comment: ${claimProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPhotoViewer(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photoUrls: widget.claim.photoUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showSignatureViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Customer Signature'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: CachedNetworkImage(
                imageUrl: widget.claim.customerSignatureUrl!,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assign to User - Coming Soon')),
    );
  }

  void _showPriorityDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change Priority - Coming Soon')),
    );
  }

  void _exportToPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export to PDF - Coming Soon')),
    );
  }

  void _closeClaim() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Close Claim - Coming Soon')),
    );
  }

  // Download all evidence (photos and signatures)
  Future<void> _downloadAllEvidence() async {
    try {
      int downloadCount = 0;
      
      // Download photos
      for (int i = 0; i < widget.claim.photoUrls.length; i++) {
        await _downloadFile(
          widget.claim.photoUrls[i],
          'claim_${widget.claim.id}_photo_${i + 1}.jpg',
        );
        downloadCount++;
      }
      
      // Download customer signature
      if (widget.claim.customerSignatureUrl != null) {
        await _downloadFile(
          widget.claim.customerSignatureUrl!,
          'claim_${widget.claim.id}_customer_signature.png',
        );
        downloadCount++;
      }
      
      // Download driver signature
      if (widget.claim.driverSignatureUrl != null) {
        await _downloadFile(
          widget.claim.driverSignatureUrl!,
          'claim_${widget.claim.id}_driver_signature.png',
        );
        downloadCount++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $downloadCount file(s)'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading files: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Download individual file
  Future<void> _downloadFile(String url, String filename) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  String _getClaimTypeDisplay(ClaimType type) {
    switch (type) {
      case ClaimType.damaged:
        return 'Damaged Goods';
      case ClaimType.shortage:
        return 'Short Delivered';
      case ClaimType.shortWeight:
        return 'Short Weight';
      case ClaimType.missing:
        return 'Missing Items';
      case ClaimType.wrongItems:
        return 'Wrong Items';
      case ClaimType.returns:
        return 'Returns';
      case ClaimType.priceError:
        return 'Price Error';
      case ClaimType.lateDelivery:
        return 'Late Delivery';
      case ClaimType.didNotDeliver:
        return 'Did Not Deliver';
      case ClaimType.qualityIssue:
        return 'Quality Issue';
      case ClaimType.temperatureIssue:
        return 'Temperature Issue';
      case ClaimType.packagingIssue:
        return 'Packaging Issue';
      case ClaimType.expiryIssue:
        return 'Expiry Issue';
      case ClaimType.serviceIssue:
        return 'Service Issue';
      case ClaimType.other:
        return 'Other';
    }
  }

  IconData _getStatusIcon(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
        return Icons.send;
      case ClaimStatus.pendingReview:
        return Icons.pending;
      case ClaimStatus.investigating:
        return Icons.search;
      case ClaimStatus.pendingApproval:
        return Icons.approval;
      case ClaimStatus.approved:
        return Icons.check_circle;
      case ClaimStatus.rejected:
        return Icons.cancel;
      case ClaimStatus.resolved:
        return Icons.task_alt;
      case ClaimStatus.closed:
        return Icons.lock;
      default:
        return Icons.circle;
    }
  }

  String _getStatusDisplay(ClaimStatus status) {
    return status.name
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Photo viewer screen with swipe navigation
class PhotoViewerScreen extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photoUrls,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photo ${_currentIndex + 1} of ${widget.photoUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Hero(
                tag: 'photo_$index',
                child: CachedNetworkImage(
                  imageUrl: widget.photoUrls[index],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

