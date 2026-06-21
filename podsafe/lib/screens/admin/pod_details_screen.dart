import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../models/delivery_model.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/location_map_widget.dart';
import '../../services/pod_image_download_service.dart';
import '../../utils/vehicle_utils.dart';
import '../../services/pod_pdf_generator_service.dart';
import '../../providers/auth_provider.dart';

class PODDetailsScreen extends StatefulWidget {
  final String podId;
  final Map<String, dynamic> podData;

  const PODDetailsScreen({
    super.key,
    required this.podId,
    required this.podData,
  });

  @override
  State<PODDetailsScreen> createState() => _PODDetailsScreenState();
}

class _PODDetailsScreenState extends State<PODDetailsScreen> {
  Delivery? _delivery;
  bool _isLoadingDelivery = true;
  String? _companyName;
  String? _companyLogoUrl;
  Map<String, dynamic>? _driverInfo;
  Map<String, dynamic>? _vehicleInfo;

  @override
  void initState() {
    super.initState();
    _loadDeliveryDetails();
    _loadCompanyInfo();
  }

  Future<void> _loadDeliveryDetails() async {
    try {
      final deliveryId = widget.podData['deliveryId'] as String?;
      if (deliveryId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(deliveryId)
            .get();
        
        if (doc.exists) {
          final delivery = Delivery.fromFirestore(doc);
          setState(() {
            _delivery = delivery;
            _isLoadingDelivery = false;
          });
          
          // Load driver info after delivery is loaded
          if (delivery.driverId.isNotEmpty) {
            await _loadDriverInfo(delivery.driverId);
          }
          
          // Load vehicle info if vehicle is assigned
          if (delivery.vehicleUsed != null && delivery.vehicleUsed!.isNotEmpty) {
            await _loadVehicleInfo(delivery.vehicleUsed!);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading delivery: $e');
      setState(() => _isLoadingDelivery = false);
    }
  }

  Future<void> _loadDriverInfo(String driverId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();
      
      if (doc.exists) {
        setState(() {
          _driverInfo = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error loading driver info: $e');
    }
  }

  Future<void> _loadVehicleInfo(String vehicleRegistration) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId != null) {
        // Query vehicles by registration to get Make and Model
        final snapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('vehicles')
            .where('registration', isEqualTo: normalizeRegistration(vehicleRegistration))
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          setState(() {
            _vehicleInfo = snapshot.docs.first.data();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading vehicle info: $e');
    }
  }

  Future<void> _loadCompanyInfo() async {
    try {
      // Get the current user's company ID from auth provider
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;
      
      if (companyId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        
        if (doc.exists) {
          setState(() {
            _companyName = doc.data()?['name'] as String?;
            _companyLogoUrl = doc.data()?['logoUrl'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading company info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final signatureUrl = widget.podData['signatureUrl'] as String?;
  final photoUrl = widget.podData['photoUrl'] as String?;
  final List<String> photoUrls = (widget.podData['photoUrls'] != null && widget.podData['photoUrls'] is List)
    ? List<String>.from(widget.podData['photoUrls'] as List)
    : (photoUrl != null ? [photoUrl] : []);
  
  // 📄 NEW: Extract scanned documents
  final List<String> documentUrls = (widget.podData['documentUrls'] != null && widget.podData['documentUrls'] is List)
    ? List<String>.from(widget.podData['documentUrls'] as List)
    : [];
  final List<Map<String, String>> documentMetadata = (widget.podData['documentMetadata'] != null && widget.podData['documentMetadata'] is List)
    ? (widget.podData['documentMetadata'] as List).map((e) => Map<String, String>.from(e)).toList()
    : [];
  
  final stampPhotoUrl = widget.podData['stampPhotoUrl'] as String?; // New stamp photo
    final notes = widget.podData['notes'] as String?;
    final timestamp = widget.podData['timestamp'] as Timestamp?;
    final location = widget.podData['location'] as Map<String, dynamic>?;
    
    print('📄 POD Details Screen');
    print('📄 POD ID: ${widget.podId}');
    print('📄 Photo URL: $photoUrl');
    print('📄 Photo URLs: $photoUrls');
    print('📄 Photo URLs length: ${photoUrls.length}');
    print('📄 Document URLs: $documentUrls');
    print('📄 Document URLs length: ${documentUrls.length}');
    print('📄 Stamp Photo URL: $stampPhotoUrl');

    return Scaffold(
      appBar: AppBar(
        title: const Text('POD Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share feature coming soon!'),
                  backgroundColor: AppTheme.infoColor,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showDownloadOptions,
            tooltip: 'Download POD Images',
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
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.successColor,
                    width: 2,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delivered Successfully',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Information
            if (_delivery != null) ...[
              _buildSectionTitle('Delivery Information'),
              _buildInfoCard([
                _buildInfoRow('Customer', _delivery!.customerName),
                _buildInfoRow('Address', _delivery!.customerAddress),
                _buildInfoRow('Phone', _delivery!.customerPhone ?? 'N/A'),
                _buildInfoRow('Receiver', widget.podData['receiverName'] ?? 'Not specified'),
              ]),
              const SizedBox(height: 20),
            ] else if (_isLoadingDelivery) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
            ],

            // Timestamp
            if (timestamp != null) ...[
              _buildSectionTitle('Delivery Time'),
              _buildInfoCard([
                _buildInfoRow(
                  'Completed At',
                  DateFormat('EEEE, MMMM d, y • h:mm a').format(
                    timestamp.toDate(),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ],

            // Location
            if (location != null) ...[
              _buildSectionTitle('GPS Location'),
              _buildInfoCard([
                _buildInfoRow(
                  'Latitude',
                  location['latitude']?.toString() ?? 'N/A',
                ),
                _buildInfoRow(
                  'Longitude',
                  location['longitude']?.toString() ?? 'N/A',
                ),
                _buildInfoRow(
                  'Accuracy',
                  '${location['accuracy']?.toStringAsFixed(1) ?? 'N/A'} meters',
                ),
              ]),
              const SizedBox(height: 12),
              LocationMapWidget(
                latitude: location['latitude'] ?? 0.0,
                longitude: location['longitude'] ?? 0.0,
                accuracy: location['accuracy'] as double?,
                address: location['address'] as String?,
                height: 250,
                showAccuracyCircle: true,
              ),
              const SizedBox(height: 20),
            ],

            // Signature
            if (signatureUrl != null) ...[
              _buildSectionTitle('Customer Signature'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FirebaseStorageImage(
                            imageUrl: signatureUrl,
                            fit: BoxFit.contain,
                            showErrorDetails: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _showImageFullScreen(signatureUrl, 'Signature'),
                        icon: const Icon(Icons.fullscreen),
                        label: const Text('View Full Size'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Photo(s)
            if (photoUrls.isNotEmpty) ...[
              _buildSectionTitle('Delivery Photo${photoUrls.length > 1 ? 's' : ''}'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: photoUrls.length == 1
                              ? FirebaseStorageImage(
                                  imageUrl: photoUrls.first,
                                  fit: BoxFit.cover,
                                  showErrorDetails: true,
                                )
                              : SizedBox(
                                  height: 250,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: photoUrls.length,
                                    itemBuilder: (context, index) {
                                      final url = photoUrls[index];
                                      return Container(
                                        width: 250,
                                        margin: EdgeInsets.only(right: index < photoUrls.length - 1 ? 8 : 0),
                                        child: FirebaseStorageImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          showErrorDetails: true,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _showImageFullScreen(photoUrls.first, 'Photo'),
                            icon: const Icon(Icons.fullscreen),
                            label: const Text('View First Photo Full Size'),
                          ),
                          const SizedBox(width: 12),
                          if (photoUrls.length > 1)
                            Text('Scroll horizontally to view all ${photoUrls.length} photos', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 📄 NEW: Scanned Documents Section
            if (documentUrls.isNotEmpty) ...[
              _buildSectionTitle('Scanned Documents (${documentUrls.length})'),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.document_scanner,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'High-quality scanned documents',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Display documents in a grid
                      ...List.generate(documentUrls.length, (index) {
                        final url = documentUrls[index];
                        final docType = index < documentMetadata.length 
                            ? documentMetadata[index]['type'] ?? 'Document'
                            : 'Document';
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0) const SizedBox(height: 16),
                            // Document type label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.label, size: 16, color: AppTheme.primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    docType,
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Document image
                            Container(
                              width: double.infinity,
                              height: 300,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primaryColor, width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: FirebaseStorageImage(
                                  imageUrl: url,
                                  fit: BoxFit.contain,
                                  showErrorDetails: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _showImageFullScreen(url, docType),
                              icon: const Icon(Icons.fullscreen),
                              label: Text('View $docType Full Size'),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Stamp Photo (Optional - for corporate customers)
            if (stampPhotoUrl != null) ...[
              _buildSectionTitle('Customer Stamp'),
              Card(
                color: AppTheme.infoColor.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: AppTheme.infoColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Corporate Store Receipt Stamp',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FirebaseStorageImage(
                            imageUrl: stampPhotoUrl,
                            fit: BoxFit.cover,
                            showErrorDetails: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _showImageFullScreen(stampPhotoUrl, 'Stamp Photo'),
                        icon: const Icon(Icons.fullscreen),
                        label: const Text('View Full Size'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 🆕 OCR Extracted Data (if available) - HIDDEN FOR FUTURE USE
            // if (widget.podData['ocrFields'] != null && 
            //     (widget.podData['ocrFields'] as Map).isNotEmpty) ...[
            //   _buildSectionTitle('📊 OCR Extracted Data'),
            //   _buildOcrDataSection(
            //     ocrFields: widget.podData['ocrFields'] as Map<String, dynamic>,
            //     confidence: widget.podData['ocrConfidence'] as double? ?? 0.0,
            //   ),
            //   const SizedBox(height: 20),
            // ],

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              _buildSectionTitle('Delivery Notes'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    notes,
                    style: const TextStyle(fontSize: 15),
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

  // 🆕 NEW: Build OCR Data Section with extracted fields and confidence badge
  // ignore: unused_element
  Widget _buildOcrDataSection({
    required Map<String, dynamic> ocrFields,
    required double confidence,
  }) {
    // Extract key fields - convert to string safely
    final invoiceNo = _safeToString(ocrFields['invoiceNo']) ?? 'Not extracted';
    final supplier = _safeToString(ocrFields['supplier']) ?? 'Not extracted';
    final customer = _safeToString(ocrFields['customer']) ?? 'Not extracted';
    final totalIncl = _safeToString(ocrFields['totalIncl']) ?? 'Not extracted';
    final driverName = _safeToString(ocrFields['driverName']) ?? 'Not extracted';
    
    // Determine confidence color based on score
    Color confidenceColor;
    IconData confidenceIcon;
    if (confidence >= 0.80) {
      confidenceColor = Colors.green;
      confidenceIcon = Icons.check_circle;
    } else if (confidence >= 0.65) {
      confidenceColor = Colors.orange;
      confidenceIcon = Icons.info;
    } else {
      confidenceColor = Colors.red;
      confidenceIcon = Icons.warning;
    }
    
    return Card(
      color: confidenceColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confidence Badge
            Row(
              children: [
                Icon(
                  confidenceIcon,
                  color: confidenceColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extraction Confidence',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: confidence,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  confidenceColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: confidenceColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Extracted Fields Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildOcrField(
                  label: 'Invoice',
                  value: invoiceNo,
                  icon: Icons.receipt,
                ),
                _buildOcrField(
                  label: 'Supplier',
                  value: supplier,
                  icon: Icons.business,
                ),
                _buildOcrField(
                  label: 'Customer',
                  value: customer,
                  icon: Icons.person,
                ),
                _buildOcrField(
                  label: 'Total (Incl)',
                  value: totalIncl,
                  icon: Icons.payments,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Driver Name (full width)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Driver Name',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          driverName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Admin Action Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Review & Edit Extracted Data'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit functionality coming soon!'),
                      backgroundColor: AppTheme.infoColor,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 NEW: Build individual OCR field tile
  Widget _buildOcrField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

  void _showImageFullScreen(String imageUrl, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title),
          ),
          body: Center(
            child: InteractiveViewer(
              child: FirebaseStorageImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                showErrorDetails: true,
                placeholder: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDownloadOptions() {
    final signatureUrl = widget.podData['signatureUrl'] as String?;
    final photoUrl = widget.podData['photoUrl'] as String?;
    final List<String> photoUrls = (widget.podData['photoUrls'] != null && widget.podData['photoUrls'] is List)
        ? List<String>.from(widget.podData['photoUrls'] as List)
        : (photoUrl != null ? [photoUrl] : []);
    final stampPhotoUrl = widget.podData['stampPhotoUrl'] as String?;
    
    // 📄 NEW: Extract scanned documents
    final List<String> documentUrls = (widget.podData['documentUrls'] != null && widget.podData['documentUrls'] is List)
        ? List<String>.from(widget.podData['documentUrls'] as List)
        : [];
    final List<Map<String, String>> documentMetadata = (widget.podData['documentMetadata'] != null && widget.podData['documentMetadata'] is List)
        ? (widget.podData['documentMetadata'] as List).map((e) => Map<String, String>.from(e)).toList()
        : [];
    
    final options = <String, String>{};
    if (signatureUrl != null) options['Signature'] = signatureUrl;
    if (stampPhotoUrl != null) options['Stamp Photo'] = stampPhotoUrl;
    // Add all delivery photos (support multiple)
    for (var i = 0; i < photoUrls.length; i++) {
      final key = photoUrls.length == 1 ? 'Delivery Photo' : 'Delivery Photo ${i + 1}';
      options[key] = photoUrls[i];
    }
    // 📄 NEW: Add all scanned documents
    for (var i = 0; i < documentUrls.length; i++) {
      final docType = i < documentMetadata.length 
          ? documentMetadata[i]['type'] ?? 'Document'
          : 'Document';
      final key = documentUrls.length == 1 ? docType : '$docType ${i + 1}';
      options[key] = documentUrls[i];
    }
    
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No images available to download'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Options'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PDF Download Option (At the top)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.infoColor, width: 2),
                ),
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: AppTheme.infoColor),
                  title: const Text(
                    'Download as PDF Report',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('All details, images & signature in one file'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadPODReport();
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Or Download Individual Items',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              
              // Download All Images
              ListTile(
                leading: Icon(Icons.download),
                title: const Text('Download All Images'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAllImages(options);
                },
              ),
              
              // Individual Images
              ...options.entries.map((entry) {
                return ListTile(
                  leading: const Icon(Icons.image),
                  title: Text('Download ${entry.key}'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadSingleImage(entry.value, entry.key);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSingleImage(String imageUrl, String imageName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $imageName...'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      final filename = PODImageDownloadService.generateFilename(
        imageName.toLowerCase(),
        widget.podId,
        _delivery?.customerName,
      );
      
      await PODImageDownloadService.downloadImage(imageUrl, filename);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $imageName downloaded successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading image: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _downloadAllImages(Map<String, String> images) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting download of all images...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      await PODImageDownloadService.downloadMultipleImages(
        images,
        widget.podId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ All ${images.length} images downloaded successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading images: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _downloadPODReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF report...'),
          duration: Duration(seconds: 2),
        ),
      );

      final signatureUrl = widget.podData['signatureUrl'] as String?;
      final photoUrl = widget.podData['photoUrl'] as String?;
      final List<String> photoUrls = (widget.podData['photoUrls'] != null && widget.podData['photoUrls'] is List)
          ? List<String>.from(widget.podData['photoUrls'] as List)
          : (photoUrl != null ? [photoUrl] : []);
      final stampPhotoUrl = widget.podData['stampPhotoUrl'] as String?;
      final notes = widget.podData['notes'] as String?;
      final timestamp = widget.podData['timestamp'] as Timestamp?;
      final location = widget.podData['location'] as Map<String, dynamic>?;

      // Build comprehensive delivery data map
      final deliveryData = {
        // Customer Information
        'customerName': _delivery?.customerName ?? 'N/A',
        'customerAddress': _delivery?.customerAddress ?? 'N/A',
        'customerPhone': _delivery?.customerPhone ?? 'N/A',
        'customerNumber': _delivery?.customerNumber ?? 'N/A',
        
        // Order & Invoice Information
        'orderNumber': _delivery?.orderNumber ?? 'N/A',
        'invoiceNumber': _delivery?.invoiceNumber ?? 'N/A',
        'invoiceTotal': _delivery?.invoiceTotal?.toStringAsFixed(2) ?? 'N/A',
        'currency': _delivery?.currency ?? 'ZAR',
        
        // Driver Information
        'driverName': _driverInfo?['fullName'] ?? _driverInfo?['displayName'] ?? 'N/A',
        'driverPhone': _driverInfo?['phoneNumber'] ?? 'N/A',
        'licenseNumber': _driverInfo?['licenseNumber'] ?? 'N/A',
        
        // Vehicle Information
        'vehicleUsed': _delivery?.vehicleUsed ?? 'N/A',
        'vehicleMake': _vehicleInfo?['make'] ?? 'N/A',
        'vehicleModel': _vehicleInfo?['model'] ?? 'N/A',
      };

      // 📄 Extract document URLs for PDF
      final List<String> documentUrls = (widget.podData['documentUrls'] != null && widget.podData['documentUrls'] is List)
          ? List<String>.from(widget.podData['documentUrls'] as List)
          : [];
      final List<Map<String, String>> documentMetadata = (widget.podData['documentMetadata'] != null && widget.podData['documentMetadata'] is List)
          ? (widget.podData['documentMetadata'] as List).map((e) => Map<String, String>.from(e)).toList()
          : [];
      
      await PODPdfGeneratorService.downloadPODReportPDF(
        podId: widget.podId,
        deliveryData: deliveryData,
        podData: widget.podData,
        photoUrl: photoUrl,
        photoUrls: photoUrls,
        documentUrls: documentUrls,  // 📄 NEW: Pass scanned documents
        documentMetadata: documentMetadata,  // 📄 NEW: Pass document types
        signatureUrl: signatureUrl,
        stampPhotoUrl: stampPhotoUrl,
        timestamp: timestamp,
        location: location,
        notes: notes,
        companyName: _companyName,
        companyLogoUrl: _companyLogoUrl,
        receiverName: widget.podData['receiverName'],  // 🆕 NEW: Pass receiver name
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ PDF report downloaded successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper method to safely convert any value to string
  // ignore: unused_element
  String? _safeToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is double) return value.toString();
    if (value is bool) return value.toString();
    return value.toString(); // fallback
  }
}
