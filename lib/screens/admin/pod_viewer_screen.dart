import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import 'pod_details_screen.dart';
import 'pod_viewer_desktop.dart';

class PODViewerScreen extends StatelessWidget {
  const PODViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: Width > 1000px (needs space for grid + sidebar/detail panel)
        // Mobile: Width <= 1000px
        if (constraints.maxWidth > 1000) {
          return const PODViewerDesktop();
        }
        return const PODViewerMobile();
      },
    );
  }
}

class PODViewerMobile extends StatefulWidget {
  const PODViewerMobile({super.key});

  @override
  State<PODViewerMobile> createState() => _PODViewerMobileState();
}

class _PODViewerMobileState extends State<PODViewerMobile> {
  String _selectedFilter = 'all';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Deliveries'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All PODs'),
              ),
              const PopupMenuItem(
                value: 'today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'week',
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: 'month',
                child: Text('This Month'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPODsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Refresh
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No PODs yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Proof of deliveries will appear here',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final pods = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: pods.length,
            itemBuilder: (context, index) {
              final podDoc = pods[index];
              final podData = podDoc.data() as Map<String, dynamic>;
              
              return _buildPODCard(podDoc.id, podData);
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getPODsStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyId = authProvider.companyId;

    debugPrint('🔍 [POD Viewer] Current user companyId: $companyId');

    if (companyId == null) {
      debugPrint('❌ [POD Viewer] ERROR: No company ID found!');
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('pods')
        .where('companyId', isEqualTo: companyId)
        .orderBy('timestamp', descending: true);

    // Apply date filters
    if (_selectedFilter != 'all') {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedFilter) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(2020); // Far past
      }

      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
      
      debugPrint('📅 [POD Viewer] Filtering by: $_selectedFilter (from $startDate)');
    }

    debugPrint('✅ [POD Viewer] Query created for companyId: $companyId');

    return query.snapshots();
  }

  Widget _buildPODCard(String podId, Map<String, dynamic> podData) {
    final deliveryId = podData['deliveryId'] as String?;
    final timestamp = podData['timestamp'] as Timestamp?;
    final hasSignature = podData['signatureUrl'] != null;
    final hasPhoto = podData['photoUrl'] != null;
    final hasStampPhoto = podData['stampPhotoUrl'] != null; // Customer stamp
    final hasLocation = podData['location'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PODDetailsScreen(
                podId: podId,
                podData: podData,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery #${deliveryId?.substring(0, 8) ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            DateFormat('MMM d, y • h:mm a').format(
                              timestamp.toDate(),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Additional details row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (podData['customerNumber'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer #',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              podData['customerNumber'].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (podData['receiverName'] != null && podData['receiverName'].toString().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receiver',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              podData['receiverName'].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (podData['invoiceNumber'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice #',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              podData['invoiceNumber'].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (podData['orderNumber'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              podData['orderNumber'].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildPODFeature(
                    icon: Icons.draw,
                    label: 'Signature',
                    hasFeature: hasSignature,
                  ),
                  _buildPODFeature(
                    icon: Icons.photo_camera,
                    label: 'Photo',
                    hasFeature: hasPhoto,
                  ),
                  if (hasStampPhoto)
                    _buildPODFeature(
                      icon: Icons.receipt_long,
                      label: 'Stamp',
                      hasFeature: hasStampPhoto,
                    ),
                  _buildPODFeature(
                    icon: Icons.location_on,
                    label: 'GPS',
                    hasFeature: hasLocation,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPODFeature({
    required IconData icon,
    required String label,
    required bool hasFeature,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: hasFeature ? AppTheme.successColor : AppTheme.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: hasFeature ? AppTheme.successColor : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
