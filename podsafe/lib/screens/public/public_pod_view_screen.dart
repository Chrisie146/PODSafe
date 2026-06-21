import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../services/pod_token_service.dart';
import '../../utils/app_logger.dart';

/// Public POD viewing screen - accessible via QR code
/// URL format: /pod/<deliveryId>?token=<secureToken>
class PublicPODViewScreen extends StatefulWidget {
  final String deliveryId;
  final String token;
  
  const PublicPODViewScreen({
    super.key,
    required this.deliveryId,
    required this.token,
  });
  
  @override
  State<PublicPODViewScreen> createState() => _PublicPODViewScreenState();
}

class _PublicPODViewScreenState extends State<PublicPODViewScreen> {
  final PODTokenService _tokenService = PODTokenService();
  bool _isLoading = true;
  bool _isAuthorized = false;
  Map<String, dynamic>? _podData;
  Map<String, dynamic>? _deliveryData;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadPODData();
  }
  
  Future<void> _loadPODData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Validate token
      final deliveryId = await _tokenService.validateToken(widget.token);
      
      if (deliveryId == null || deliveryId != widget.deliveryId) {
        setState(() {
          _isLoading = false;
          _isAuthorized = false;
          _errorMessage = 'Invalid or expired access token';
        });
        return;
      }
      
      // Token is valid, fetch POD data
      final podDoc = await FirebaseFirestore.instance
          .collection('pods')
          .doc(widget.deliveryId)
          .get();
      
      if (!podDoc.exists) {
        setState(() {
          _isLoading = false;
          _isAuthorized = false;
          _errorMessage = 'POD not found';
        });
        return;
      }
      
      // Fetch delivery data for additional context
      final deliveryDoc = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .get();
      
      setState(() {
        _isLoading = false;
        _isAuthorized = true;
        _podData = podDoc.data();
        _deliveryData = deliveryDoc.exists ? deliveryDoc.data() : null;
      });
      
      AppLogger.info('Public POD viewed', data: {
        'deliveryId': widget.deliveryId,
        'token': widget.token,
      });
      
    } catch (e) {
      AppLogger.error('Failed to load public POD', error: e);
      setState(() {
        _isLoading = false;
        _isAuthorized = false;
        _errorMessage = 'Failed to load POD data';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('Proof of Delivery'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (!_isAuthorized || _errorMessage != null) {
      return _buildErrorView();
    }
    
    return _buildPODView();
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 26),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Access Denied',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This POD is not available or the access link has expired.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPODView() {
    if (_podData == null) return const SizedBox();
    
    final timestamp = (_podData!['timestamp'] as Timestamp?)?.toDate();
    final photoUrl = _podData!['photoUrl'] as String?;
    final List<String> photoUrls = (_podData!['photoUrls'] != null && _podData!['photoUrls'] is List)
        ? List<String>.from(_podData!['photoUrls'] as List)
        : (photoUrl != null ? [photoUrl] : []);
    final stampPhotoUrl = _podData!['stampPhotoUrl'] as String?; // Customer stamp photo
    final signatureUrl = _podData!['signatureUrl'] as String?;
    final customerName = _podData!['customerName'] as String? ?? 
                        _deliveryData?['customerName'] as String? ?? 
                        'Unknown';
    final invoiceNumber = _podData!['invoiceNumber'] as String? ?? 
                         _deliveryData?['invoiceNumber'] as String? ?? 
                         'N/A';
    final orderNumber = _podData!['orderNumber'] as String? ?? 
                       _deliveryData?['orderNumber'] as String?;
    final notes = _podData!['notes'] as String?;
    final location = _podData!['location'] as Map<String, dynamic>?;
    
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          margin: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.successColor, Color(0xFF27AE60)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successColor.withValues(alpha: 77),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'DELIVERED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(timestamp),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(timestamp),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 230),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Delivery details card
              _buildInfoCard(
                title: 'Delivery Information',
                icon: Icons.local_shipping,
                children: [
                  _buildDetailRow('Delivery ID', widget.deliveryId.substring(0, 12)),
                  _buildDetailRow('Customer', customerName),
                  if (orderNumber != null)
                    _buildDetailRow('Order #', orderNumber),
                  _buildDetailRow('Invoice #', invoiceNumber),
                ],
              ),
              const SizedBox(height: 24),
              
              // Photo(s)
              if (photoUrls.isNotEmpty) ...[
                _buildInfoCard(
                  title: 'Delivery Photo${photoUrls.length > 1 ? 's' : ''}',
                  icon: Icons.photo_camera,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: photoUrls.length == 1
                          ? FirebaseStorageImage(
                              imageUrl: photoUrls.first,
                              fit: BoxFit.cover,
                              height: 300,
                              width: double.infinity,
                            )
                          : SizedBox(
                              height: 300,
                              child: PageView.builder(
                                itemCount: photoUrls.length,
                                itemBuilder: (context, index) {
                                  final url = photoUrls[index];
                                  return FirebaseStorageImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                    ),
                    if (photoUrls.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Swipe to view all ${photoUrls.length} photos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              // Customer Stamp Photo (optional - for corporate customers)
              if (stampPhotoUrl != null) ...[
                _buildInfoCard(
                  title: 'Customer Stamp (Corporate Store Receipt)',
                  icon: Icons.receipt_long,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FirebaseStorageImage(
                        imageUrl: stampPhotoUrl,
                        fit: BoxFit.cover,
                        height: 300,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              // Signature
              if (signatureUrl != null) ...[
                _buildInfoCard(
                  title: 'Signature',
                  icon: Icons.draw,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: FirebaseStorageImage(
                        imageUrl: signatureUrl,
                        fit: BoxFit.contain,
                        height: 150,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              // Notes
              if (notes != null && notes.isNotEmpty) ...[
                _buildInfoCard(
                  title: 'Delivery Notes',
                  icon: Icons.note,
                  children: [
                    Text(
                      notes,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              // Location
              if (location != null) ...[
                _buildInfoCard(
                  title: 'GPS Location',
                  icon: Icons.location_on,
                  children: [
                    Text(
                      'Latitude: ${location['latitude']?.toStringAsFixed(6)}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Longitude: ${location['longitude']?.toStringAsFixed(6)}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    if (location['accuracy'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Accuracy: ±${location['accuracy']}m',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              // Download button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _downloadPOD,
                  icon: const Icon(Icons.download),
                  label: const Text('Download POD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Footer
              Center(
                child: Text(
                  'Powered by PODSafe',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
  
  Widget _buildDetailRow(String label, String value) {
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
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _downloadPOD() {
    // TODO: Implement PDF download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
