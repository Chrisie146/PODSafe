import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/vehicle_utils.dart';
import 'package:http/http.dart' as http;
// Conditional import: use dart:html on web, stub on other platforms
import '../../utils/web_utils_stub.dart'
    if (dart.library.html) 'dart:html' as html;
import '../../models/claim_model.dart';
import '../../providers/claim_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/location_map_widget.dart';

/// Desktop-optimized Claim Details screen with split-panel layout
/// Features: Keyboard shortcuts, resizable panels, floating toolbar, photo lightbox
class ClaimDetailsDesktop extends StatefulWidget {
  final Claim claim;

  const ClaimDetailsDesktop({super.key, required this.claim});

  @override
  State<ClaimDetailsDesktop> createState() => _ClaimDetailsDesktopState();
}

class _ClaimDetailsDesktopState extends State<ClaimDetailsDesktop> {
  int _selectedPhotoIndex = 0;
  bool _showPhotoLightbox = false;
  double _leftPanelWidth = 600;
  final double _minPanelWidth = 400;
  final double _maxPanelWidth = 800;
  bool _isFullScreen = false;
  String _activeSection = 'details'; // details, history, comments
  
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Esc - Close lightbox or go back
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_showPhotoLightbox) {
          setState(() => _showPhotoLightbox = false);
        } else {
          Navigator.pop(context);
        }
        return KeyEventResult.handled;
      }
      // Enter - Quick approve
      else if (event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        if (_canApprove()) {
          _showApproveDialog();
          return KeyEventResult.handled;
        }
      }
      // R - Quick reject
      else if (event.logicalKey == LogicalKeyboardKey.keyR &&
          HardwareKeyboard.instance.isControlPressed) {
        if (_canReject()) {
          _showRejectDialog();
          return KeyEventResult.handled;
        }
      }
      // Arrow Left - Previous photo
      else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_showPhotoLightbox && _selectedPhotoIndex > 0) {
          setState(() => _selectedPhotoIndex--);
          return KeyEventResult.handled;
        }
      }
      // Arrow Right - Next photo
      else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_showPhotoLightbox &&
            _selectedPhotoIndex < widget.claim.photoUrls.length - 1) {
          setState(() => _selectedPhotoIndex++);
          return KeyEventResult.handled;
        }
      }
      // F11 - Toggle full screen
      else if (event.logicalKey == LogicalKeyboardKey.f11) {
        setState(() => _isFullScreen = !_isFullScreen);
        return KeyEventResult.handled;
      }
      // Tab - Switch sections
      else if (event.logicalKey == LogicalKeyboardKey.tab &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _cycleSection();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _cycleSection() {
    setState(() {
      if (_activeSection == 'details') {
        _activeSection = 'history';
      } else if (_activeSection == 'history') {
        _activeSection = 'comments';
      } else {
        _activeSection = 'details';
      }
    });
  }

  bool _canApprove() {
    return widget.claim.status == ClaimStatus.pendingReview ||
        widget.claim.status == ClaimStatus.submitted;
  }

  bool _canReject() {
    return widget.claim.status == ClaimStatus.pendingReview ||
        widget.claim.status == ClaimStatus.submitted;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _isFullScreen ? null : _buildAppBar(),
        body: _buildBody(),
        floatingActionButton: _buildFloatingToolbar(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _getStatusColor(widget.claim.status),
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.claim.id,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            _getStatusDisplayName(widget.claim.status),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        // Breadcrumb hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Text(
                'Press Esc to go back • Enter to approve • Ctrl+R to reject',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
          tooltip: 'Full Screen (F11)',
          onPressed: () {
            setState(() => _isFullScreen = !_isFullScreen);
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            // Reload claim data
            context.read<ClaimProvider>().loadAllClaims();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'More options',
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
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
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Row(
          children: [
            // Left Panel - Information
            Container(
              width: _leftPanelWidth,
              color: Colors.white,
              child: _buildLeftPanel(),
            ),
            // Resizer
            _buildResizer(),
            // Right Panel - Evidence & Actions
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: _buildRightPanel(),
              ),
            ),
          ],
        ),
        // Photo Lightbox Overlay
        if (_showPhotoLightbox) _buildPhotoLightbox(),
      ],
    );
  }

  Widget _buildResizer() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _leftPanelWidth += details.delta.dx;
            _leftPanelWidth = _leftPanelWidth.clamp(_minPanelWidth, _maxPanelWidth);
          });
        },
        child: Container(
          width: 8,
          color: Colors.grey[300],
          child: Center(
            child: Container(
              width: 2,
              color: Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      children: [
        // Section Tabs
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              _buildSectionTab('Details', 'details', Icons.info_outline),
              _buildSectionTab('History', 'history', Icons.history),
              _buildSectionTab('Comments', 'comments', Icons.comment),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildLeftPanelContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTab(String label, String section, IconData icon) {
    final isActive = _activeSection == section;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _activeSection = section);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
            color: isActive ? AppTheme.primaryColor.withOpacity(0.05) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppTheme.primaryColor : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppTheme.primaryColor : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanelContent() {
    switch (_activeSection) {
      case 'details':
        return _buildDetailsSection();
      case 'history':
        return _buildHistorySection();
      case 'comments':
        return _buildCommentsSection();
      default:
        return _buildDetailsSection();
    }
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Claim Information
        _buildInfoCard(
          title: 'Claim Information',
          icon: Icons.assignment,
          children: [
            _buildInfoRow('Type', _getClaimTypeDisplayName(widget.claim.type)),
            _buildInfoRow('Priority', widget.claim.priority.name.toUpperCase()),
            _buildInfoRow('Status', _getStatusDisplayName(widget.claim.status)),
            // Amount with edit button
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: const Text(
                      'Amount:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'R${(widget.claim.claimAmount ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _showEditAmountDialog,
                            child: Tooltip(
                              message: 'Edit amount',
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildInfoRow('Filed At', widget.claim.filingContext.name.replaceAll('_', ' ').toUpperCase()),
            _buildInfoRow('Created', DateFormat('MMM d, yyyy h:mm a').format(widget.claim.createdAt)),
          ],
        ),
        const SizedBox(height: 24),
        // Customer & Delivery
        _buildInfoCard(
          title: 'Customer & Delivery',
          icon: Icons.local_shipping,
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
        const SizedBox(height: 24),
        // Description
        _buildInfoCard(
          title: 'Description',
          icon: Icons.description,
          children: [
            Text(
              widget.claim.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Affected Items
        if (widget.claim.affectedItems.isNotEmpty)
          _buildInfoCard(
            title: 'Affected Items (${widget.claim.affectedItems.length})',
            icon: Icons.inventory,
            children: widget.claim.affectedItems.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['description'] ?? item['productName'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${item['productSku'] ?? 'N/A'} • Qty: ${item['quantity'] ?? item['quantity'] ?? 0}${item['unit'] != null ? ' ${item['unit']}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (item['damageDescription'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        item['damageDescription'],
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 24),
        // GPS Location
        if (widget.claim.gpsLocation.isNotEmpty)
          _buildInfoCard(
            title: 'GPS Location',
            icon: Icons.location_on,
            children: [
              Text(
                'Lat: ${widget.claim.gpsLocation['latitude']}, '
                'Lng: ${widget.claim.gpsLocation['longitude']}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              LocationMapWidget(
                latitude: _toDouble(widget.claim.gpsLocation['latitude']),
                longitude: _toDouble(widget.claim.gpsLocation['longitude']),
                accuracy: _toDouble(widget.claim.gpsLocation['accuracy']),
                address: widget.claim.gpsLocation['address'] as String?,
                height: 200,
                showAccuracyCircle: true,
              ),
            ],
          ),
        const SizedBox(height: 24),
        // Evidence Quality
        _buildInfoCard(
          title: 'Evidence Quality Score',
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
                const SizedBox(width: 16),
                Text(
                  '${widget.claim.evidenceQualityScore}/10',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Header with milestone summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Claim Timeline',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.claim.statusHistory.length} status changes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Created ${_getRelativeTime(widget.claim.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...widget.claim.statusHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final historyItem = entry.value;
          final isLast = index == widget.claim.statusHistory.length - 1;
          final relativeTime = _getRelativeTime(historyItem.timestamp);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Timeline indicator with milestone marker
              Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getStatusColor(historyItem.status).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getStatusColor(historyItem.status),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(historyItem.status).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getStatusIcon(historyItem.status),
                      size: 24,
                      color: _getStatusColor(historyItem.status),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 3,
                      height: 80,
                      color: _getStatusColor(historyItem.status).withOpacity(0.3),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              // Enhanced Content Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(historyItem.status).withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStatusDisplayName(historyItem.status),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _getStatusColor(historyItem.status),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status changed to this stage',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
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
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  relativeTime,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  DateFormat('h:mm a').format(historyItem.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey[200]),
                      const SizedBox(height: 12),
                      // User Info with better styling
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Updated by',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    historyItem.userName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notes section with better styling
                      if (historyItem.notes != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border(
                              left: BorderSide(color: Colors.blue[400]!, width: 4),
                              top: BorderSide(color: Colors.blue[200]!, width: 1),
                              right: BorderSide(color: Colors.blue[200]!, width: 1),
                              bottom: BorderSide(color: Colors.blue[200]!, width: 1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                historyItem.notes!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments & Notes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 24),
        if (widget.claim.comments.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No comments yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ...widget.claim.comments.map((comment) {
            final isInternal = comment.isInternal;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isInternal ? Colors.orange[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInternal ? Colors.orange[200]! : Colors.blue[200]!,
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
                            isInternal ? Colors.orange[200] : Colors.blue[200],
                        child: Text(
                          comment.userName[0].toUpperCase(),
                          style: TextStyle(
                            color: isInternal ? Colors.orange[900] : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, h:mm a').format(comment.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isInternal ? Colors.orange[100] : Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isInternal ? 'INTERNAL' : 'EXTERNAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isInternal ? Colors.orange[900] : Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    comment.comment,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 24),
        // Add comment form (coming soon)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Comment functionality will be available in a future update',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        // Enhanced Evidence Header with stats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library,
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
                          'Evidence Gallery',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.claim.photoUrls.length} photo${widget.claim.photoUrls.length != 1 ? 's' : ''} • ${(widget.claim.photoUrls.length * 2.5).toStringAsFixed(1)}MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (widget.claim.photoUrls.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedPhotoIndex = 0;
                          _showPhotoLightbox = true;
                        });
                      },
                      icon: const Icon(Icons.fullscreen, size: 16),
                      label: const Text('Full Screen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                ],
              ),
              if (widget.claim.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Click any photo to view full screen • Use arrow keys to navigate',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Photo Grid
        Expanded(
          child: widget.claim.photoUrls.isEmpty
              ? _buildEmptyEvidence()
              : _buildPhotoGrid(),
        ),
        // Thumbnail Strip at Bottom
        if (widget.claim.photoUrls.isNotEmpty && widget.claim.photoUrls.length > 2)
          _buildThumbnailStrip(),
        // Signature Section
        if (widget.claim.customerSignatureUrl != null) _buildSignatureSection(),
      ],
    );
  }

  Widget _buildThumbnailStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Navigation',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.claim.photoUrls.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedPhotoIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedPhotoIndex = index);
                    },
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey[300]!,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.claim.photoUrls[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error_outline),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEvidence() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No photo evidence',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Photos will appear here when added',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: widget.claim.photoUrls.length,
      itemBuilder: (context, index) {
        return Hero(
          tag: 'photo_$index',
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedPhotoIndex = index;
                _showPhotoLightbox = true;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.claim.photoUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                    // Overlay with number
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    // Hover overlay
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPhotoIndex = index;
                              _showPhotoLightbox = true;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.draw, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Customer Signature',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.claim.customerSignatureUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoLightbox() {
    return Container(
      color: Colors.black87,
      child: Stack(
        children: [
          // Main photo
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'photo_$_selectedPhotoIndex',
                child: CachedNetworkImage(
                  imageUrl: widget.claim.photoUrls[_selectedPhotoIndex],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Photo ${_selectedPhotoIndex + 1} of ${widget.claim.photoUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() => _showPhotoLightbox = false);
                    },
                  ),
                ],
              ),
            ),
          ),
          // Navigation arrows
          if (_selectedPhotoIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 32),
                  onPressed: () {
                    setState(() => _selectedPhotoIndex--);
                  },
                ),
              ),
            ),
          if (_selectedPhotoIndex < widget.claim.photoUrls.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 32),
                  onPressed: () {
                    setState(() => _selectedPhotoIndex++);
                  },
                ),
              ),
            ),
          // Bottom hint
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Use arrow keys to navigate • Esc to close • Pinch to zoom',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    if (!_canApprove() && !_canReject()) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.claim.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Current Status: ${_getStatusDisplayName(widget.claim.status)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(widget.claim.status),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_canReject())
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showRejectDialog,
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              if (_canReject() && _canApprove()) const SizedBox(width: 12),
              if (_canApprove())
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showApproveDialog,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              if ((_canReject() || _canApprove()) &&
                  (widget.claim.status == ClaimStatus.pendingReview ||
                      widget.claim.status == ClaimStatus.submitted))
                const SizedBox(width: 12),
              if (widget.claim.status == ClaimStatus.pendingReview ||
                  widget.claim.status == ClaimStatus.submitted)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showRequestInfoDialog,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Request Info'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keyboard shortcuts: Enter to approve • Ctrl+R to reject • Esc to cancel',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRequestInfoDialog() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Additional Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim: ${widget.claim.id}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'What information do you need?',
                hintText: 'Enter details about the required information...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
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
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final message = controller.text.trim();
      if (message.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter what information you need'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Information request sent for claim ${widget.claim.id}',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
      controller.dispose();
    }
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating amount: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'download_all':
        _downloadAllEvidence();
        break;
      case 'export':
        _showExportDialog();
        break;
      case 'close':
        _showCloseDialog();
        break;
    }
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

  Future<void> _showExportDialog() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );

      // Generate PDF
      final pdf = await _generateClaimPDF();
      
      // Save PDF based on platform
      final bytes = await pdf.save();
      
      if (kIsWeb) {
        // Web platform - use dart:html for download
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'Claim_${widget.claim.id}_${DateTime.now().millisecondsSinceEpoch}.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Non-web platforms - show message (or implement native save)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF export not supported on this platform')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully!')),
      );
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  Future<pw.Document> _generateClaimPDF() async {
    final pdf = pw.Document();

    // Fetch delivery info if deliveryId exists
    Map<String, dynamic>? deliveryData;
    if (widget.claim.deliveryId.isNotEmpty) {
      try {
        final deliveryDoc = await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(widget.claim.deliveryId)
            .get();
        deliveryData = deliveryDoc.data();
      } catch (e) {
        debugPrint('⚠️ Error fetching delivery info: $e');
      }
    }

    // Fetch driver information
    Map<String, dynamic>? driverInfo;
    if (widget.claim.driverId.isNotEmpty) {
      try {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.claim.driverId)
            .get();
        driverInfo = driverDoc.data();
      } catch (e) {
        debugPrint('⚠️ Error fetching driver info: $e');
      }
    }

    // Fetch vehicle information
    Map<String, dynamic>? vehicleInfo;
    if (deliveryData?['vehicleUsed'] != null) {
      try {
        final vehicleUsed = deliveryData!['vehicleUsed'] as String;
        final companyId = deliveryData['companyId'] as String?;
        Map<String, dynamic>? vData;
        if (companyId != null && companyId.isNotEmpty) {
          final docSnap = await findVehicleDocForCompany(companyId, vehicleUsed);
          if (docSnap != null) vData = docSnap.data();
        } else {
          final docSnap = await FirebaseFirestore.instance.collection('vehicles').doc(vehicleUsed).get();
          if (docSnap.exists) vData = docSnap.data();
        }
        vehicleInfo = vData;
      } catch (e) {
        debugPrint('⚠️ Error fetching vehicle info: $e');
      }
    }

    // Download photos
    List<Uint8List?> photoBytes = [];
    for (final photoUrl in widget.claim.photoUrls) {
      if (photoUrl.isNotEmpty) {
        final bytes = await _downloadImageFromUrl(photoUrl);
        photoBytes.add(bytes);
      }
    }

    // Download scanned documents
    List<Uint8List?> documentBytes = [];
    List<Map<String, dynamic>> documentMetadata = [];
    for (int i = 0; i < widget.claim.documentUrls.length; i++) {
      final docUrl = widget.claim.documentUrls[i];
      if (docUrl.isNotEmpty) {
        final bytes = await _downloadImageFromUrl(docUrl);
        documentBytes.add(bytes);
        if (i < widget.claim.documentMetadata.length) {
          documentMetadata.add(widget.claim.documentMetadata[i]);
        }
      }
    }

    // Download signatures
    Uint8List? customerSignatureBytes;
    if (widget.claim.customerSignatureUrl != null && widget.claim.customerSignatureUrl!.isNotEmpty) {
      customerSignatureBytes = await _downloadImageFromUrl(widget.claim.customerSignatureUrl!);
    }

    Uint8List? driverSignatureBytes;
    if (widget.claim.driverSignatureUrl != null && widget.claim.driverSignatureUrl!.isNotEmpty) {
      driverSignatureBytes = await _downloadImageFromUrl(widget.claim.driverSignatureUrl!);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header
          pw.Text(
            'CLAIM REPORT',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Official Claim Documentation',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 10),

          // Claim ID and date
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Claim ID: ${widget.claim.id}'),
              pw.Text(
                'Generated: ${DateFormat('MMM dd, yyyy \'at\' h:mm a').format(DateTime.now())}',
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Claim Details
          _buildClaimPDFSection('Claim Information', [
            _buildClaimPDFInfoRow('Title', widget.claim.title),
            _buildClaimPDFInfoRow('Invoice Number', widget.claim.invoiceNumber ?? 'N/A'),
            _buildClaimPDFInfoRow('Claim Type', widget.claim.type.name),
            _buildClaimPDFInfoRow('Status', widget.claim.status.name),
            _buildClaimPDFInfoRow('Priority', widget.claim.priority.name),
            _buildClaimPDFInfoRow(
              'Claim Amount',
              'ZAR ${widget.claim.claimAmount?.toString() ?? '0.00'}',
            ),
          ]),
          pw.SizedBox(height: 15),

          // Customer Information
          _buildClaimPDFSection('Customer Information', [
            _buildClaimPDFInfoRow('Customer Name', widget.claim.customerName),
            _buildClaimPDFInfoRow('Customer Number', widget.claim.customerNumber ?? 'N/A'),
            _buildClaimPDFInfoRow('Account Number', widget.claim.customerAccountNumber ?? 'N/A'),
            _buildClaimPDFInfoRow('Customer Address', deliveryData?['customerAddress'] ?? 'N/A'),
            _buildClaimPDFInfoRow('Customer Phone', deliveryData?['customerPhone'] ?? 'N/A'),
          ]),
          pw.SizedBox(height: 15),

          // Driver Information
          _buildClaimPDFSection('Driver Information', [
            _buildClaimPDFInfoRow(
              'Driver Name',
              driverInfo?['displayName'] ?? driverInfo?['fullName'] ?? widget.claim.driverName,
            ),
            _buildClaimPDFInfoRow('Driver Phone', driverInfo?['phoneNumber'] ?? 'N/A'),
            _buildClaimPDFInfoRow('License Number', driverInfo?['licenseNumber'] ?? 'N/A'),
          ]),
          pw.SizedBox(height: 15),

          // Order Details
          _buildClaimPDFSection('Order Details', [
            _buildClaimPDFInfoRow('Order Number', deliveryData?['orderNumber'] ?? 'N/A'),
            _buildClaimPDFInfoRow(
              'Invoice Total',
              '${deliveryData?['currency'] ?? 'ZAR'} ${deliveryData?['invoiceTotal'] ?? 'N/A'}',
            ),
            _buildClaimPDFInfoRow(
              'Delivery Date',
              deliveryData?['scheduledDate'] != null
                  ? _formatPDFTimestamp(deliveryData!['scheduledDate'])
                  : 'N/A',
            ),
          ]),
          pw.SizedBox(height: 15),

          // Vehicle Information
          _buildClaimPDFSection('Vehicle Information', [
            _buildClaimPDFInfoRow('Vehicle Registration', deliveryData?['vehicleUsed'] ?? 'N/A'),
            _buildClaimPDFInfoRow('Make', vehicleInfo?['make'] ?? 'N/A'),
            _buildClaimPDFInfoRow('Model', vehicleInfo?['model'] ?? 'N/A'),
          ]),
          pw.SizedBox(height: 15),

          // GPS Location
          if (widget.claim.gpsLocation.isNotEmpty) ...[
            _buildClaimPDFSection('GPS Location', [
              _buildClaimPDFInfoRow('Latitude', widget.claim.gpsLocation['latitude']?.toString() ?? 'N/A'),
              _buildClaimPDFInfoRow('Longitude', widget.claim.gpsLocation['longitude']?.toString() ?? 'N/A'),
              _buildClaimPDFInfoRow(
                'Accuracy',
                '${(widget.claim.gpsLocation['accuracy'] as num?)?.toStringAsFixed(1) ?? 'N/A'} meters',
              ),
            ]),
            pw.SizedBox(height: 15),
          ],

          // Claim Description
          _buildClaimPDFSection('Claim Description', [
            pw.Text(
              widget.claim.description,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ]),
          pw.SizedBox(height: 15),

          // Timeline
          _buildClaimPDFSection('Timeline', [
            _buildClaimPDFInfoRow(
              'Created',
              DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(widget.claim.createdAt),
            ),
            _buildClaimPDFInfoRow(
              'Last Updated',
              DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(widget.claim.updatedAt),
            ),
            if (widget.claim.resolvedAt != null)
              _buildClaimPDFInfoRow(
                'Resolved',
                DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(widget.claim.resolvedAt!),
              ),
          ]),
          pw.SizedBox(height: 15),

          // Resolution Notes (if available)
          if (widget.claim.resolutionNotes != null && widget.claim.resolutionNotes!.isNotEmpty) ...[
            _buildClaimPDFSection('Resolution Notes', [
              pw.Text(
                widget.claim.resolutionNotes!,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ]),
            pw.SizedBox(height: 15),
          ],

          // Claim Photos
          if (photoBytes.isNotEmpty) ...[
            pw.Text(
              'Claim Photo${photoBytes.length > 1 ? 's' : ''}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            for (int i = 0; i < photoBytes.length; i++) ...[
              if (photoBytes[i] != null) ...[
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(photoBytes[i]!),
                    width: 400,
                    height: 300,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                if (photoBytes.length > 1 && i < photoBytes.length - 1)
                  pw.SizedBox(height: 10),
              ],
            ],
            pw.SizedBox(height: 15),
          ],

          // Scanned Documents
          if (documentBytes.isNotEmpty) ...[
            pw.Text(
              'Scanned Document${documentBytes.length > 1 ? 's' : ''}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            for (int i = 0; i < documentBytes.length; i++) ...[
              if (documentBytes[i] != null) ...[
                // Document type label
                if (i < documentMetadata.length)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      documentMetadata[i]['type'] ?? 'Document',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(documentBytes[i]!),
                    width: 400,
                    height: 300,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                if (documentBytes.length > 1 && i < documentBytes.length - 1)
                  pw.SizedBox(height: 10),
              ],
            ],
            pw.SizedBox(height: 15),
          ],

          // Customer Signature
          if (customerSignatureBytes != null) ...[
            pw.Text(
              'Customer Signature',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(customerSignatureBytes),
                width: 300,
                height: 150,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 15),
          ],

          // Driver Signature
          if (driverSignatureBytes != null) ...[
            pw.Text(
              'Driver Signature',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(driverSignatureBytes),
                width: 300,
                height: 150,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 15),
          ],

          // Footer
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'This is an official claim report generated by PodSafe',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Helper: Build section with title and rows
  pw.Widget _buildClaimPDFSection(String title, List<pw.Widget> content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...content,
      ],
    );
  }

  /// Helper: Build info row (key-value pair)
  pw.Widget _buildClaimPDFInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: Download image from URL
  Future<Uint8List?> _downloadImageFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 30),
          );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      debugPrint('⚠️ Failed to download image: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('⚠️ Error downloading image from $url: $e');
      return null;
    }
  }

  /// Helper: Format timestamp for PDF
  String _formatPDFTimestamp(dynamic timestamp) {
    try {
      DateTime dateTime;

      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }

      return DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(dateTime);
    } catch (e) {
      debugPrint('⚠️ Error formatting timestamp: $e');
      return 'N/A';
    }
  }


  void _showCloseDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Claim'),
        content: const Text('Are you sure you want to close this claim?'),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final authProvider = context.read<AuthProvider>();
        await context.read<ClaimProvider>().updateClaimStatus(
              claimId: widget.claim.id,
              newStatus: ClaimStatus.closed,
              userId: authProvider.currentUser!.id,
              userName: authProvider.currentUser!.fullName,
            );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showApproveDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Approve claim ${widget.claim.id}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                hintText: 'Add approval notes...',
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final provider = context.read<ClaimProvider>();
      final authProvider = context.read<AuthProvider>();

      final success = await provider.updateClaimStatus(
        claimId: widget.claim.id,
        newStatus: ClaimStatus.approved,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.fullName,
        notes: controller.text.trim().isEmpty ? null : controller.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Claim approved successfully' : 'Failed to approve claim'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          Navigator.pop(context);
        }
      }
    }
  }

  void _showRejectDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reject claim ${widget.claim.id}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (required)',
                border: OutlineInputBorder(),
                hintText: 'Explain why this claim is being rejected...',
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.cancel),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final provider = context.read<ClaimProvider>();
      final authProvider = context.read<AuthProvider>();

      final success = await provider.updateClaimStatus(
        claimId: widget.claim.id,
        newStatus: ClaimStatus.rejected,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.fullName,
        notes: controller.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Claim rejected successfully' : 'Failed to reject claim'),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
        if (success) {
          Navigator.pop(context);
        }
      }
    }
  }

  // Helper methods
  String _getClaimTypeDisplayName(ClaimType type) {
    switch (type) {
      case ClaimType.damaged:
        return 'Damaged Goods';
      case ClaimType.shortage:
        return 'Shortage';
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

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  String _getStatusDisplayName(ClaimStatus status) {
    return status.name.toUpperCase().replaceAll('_', ' ');
  }

  Color _getStatusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
      case ClaimStatus.pendingReview:
        return Colors.orange;
      case ClaimStatus.approved:
      case ClaimStatus.resolved:
        return Colors.green;
      case ClaimStatus.rejected:
      case ClaimStatus.cancelled:
        return Colors.red;
      case ClaimStatus.investigating:
        return Colors.purple;
      case ClaimStatus.processing:
        return Colors.blue;
      default:
        return Colors.grey;
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
      case ClaimStatus.approved:
        return Icons.check_circle;
      case ClaimStatus.rejected:
        return Icons.cancel;
      case ClaimStatus.resolved:
        return Icons.done_all;
      case ClaimStatus.processing:
        return Icons.hourglass_empty;
      default:
        return Icons.circle;
    }
  }
}
