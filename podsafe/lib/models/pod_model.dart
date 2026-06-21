import 'package:cloud_firestore/cloud_firestore.dart';

enum PODStatus { pending, signed, missing }

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final double? accuracy;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.accuracy,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      accuracy: map['accuracy']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'accuracy': accuracy,
    };
  }
}

class PODRecord {
  final String id;
  final String companyId;
  final String driverId;
  final String deliveryId;
  final String customerName;
  final String invoiceNumber;
  final PODStatus status;
  final DateTime timestamp;
  final LocationData? location;
  final String? signedBy;
  final String? signatureUrl; // Firebase Storage URL
  final String? photoUrl; // Firebase Storage URL
  final List<String>? photoUrls; // Firebase Storage URLs (multiple photos)
  final List<String>? documentUrls; // Scanned document URLs (separate from photos)
  final List<Map<String, String>>? documentMetadata; // Document types (Invoice, Delivery Note, etc.)
  final String? pdfUrl; // Generated PDF URL
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // 🆕 NEW: OCR extracted fields
  final String? ocrRawText;          // Full OCR text
  final Map<String, dynamic>? ocrFields;  // Parsed fields (invoiceNo, supplier, etc.)
  final double? ocrConfidence;       // Confidence score (0.0 - 1.0)

  PODRecord({
    required this.id,
    required this.companyId,
    required this.driverId,
    required this.deliveryId,
    required this.customerName,
    required this.invoiceNumber,
    this.status = PODStatus.pending,
    required this.timestamp,
    this.location,
    this.signedBy,
    this.signatureUrl,
    this.photoUrl,
    this.photoUrls,
    this.documentUrls,
    this.documentMetadata,
    this.pdfUrl,
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    
    // 🆕 NEW: OCR parameters
    this.ocrRawText,
    this.ocrFields,
    this.ocrConfidence,
  });

  factory PODRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return PODRecord(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      driverId: data['driverId'] ?? '',
      deliveryId: data['deliveryId'] ?? '',
      customerName: data['customerName'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      status: PODStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => PODStatus.pending,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      location: data['location'] != null 
        ? LocationData.fromMap(data['location']) 
        : null,
      signedBy: data['signedBy'],
      signatureUrl: data['signatureUrl'],
      photoUrl: data['photoUrl'],
      photoUrls: data['photoUrls'] != null ? List<String>.from(data['photoUrls']) : null,
      documentUrls: data['documentUrls'] != null ? List<String>.from(data['documentUrls']) : null,
      documentMetadata: data['documentMetadata'] != null 
        ? (data['documentMetadata'] as List).map((e) => Map<String, String>.from(e)).toList()
        : null,
      pdfUrl: data['pdfUrl'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
        ? (data['updatedAt'] as Timestamp).toDate() 
        : null,
      
      // 🆕 NEW: Add OCR fields
      ocrRawText: data['ocrRawText'],
      ocrFields: data['ocrFields'] != null
        ? Map<String, dynamic>.from(data['ocrFields'])
        : null,
      ocrConfidence: (data['ocrConfidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'driverId': driverId,
      'deliveryId': deliveryId,
      'customerName': customerName,
      'invoiceNumber': invoiceNumber,
      'status': status.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location?.toMap(),
      'signedBy': signedBy,
      'signatureUrl': signatureUrl,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'documentUrls': documentUrls,
      'documentMetadata': documentMetadata,
      'pdfUrl': pdfUrl,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null 
        ? Timestamp.fromDate(updatedAt!) 
        : null,
      
      // 🆕 NEW: Add OCR fields
      'ocrRawText': ocrRawText,
      'ocrFields': ocrFields,
      'ocrConfidence': ocrConfidence,
    };
  }

  PODRecord copyWith({
    String? id,
    String? companyId,
    String? driverId,
    String? deliveryId,
    String? customerName,
    String? invoiceNumber,
    PODStatus? status,
    DateTime? timestamp,
    LocationData? location,
    String? signedBy,
    String? signatureUrl,
    String? photoUrl,
    List<String>? photoUrls,
    String? pdfUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ocrRawText,           // 🆕 NEW
    Map<String, dynamic>? ocrFields,  // 🆕 NEW
    double? ocrConfidence,        // 🆕 NEW
  }) {
    return PODRecord(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      driverId: driverId ?? this.driverId,
      deliveryId: deliveryId ?? this.deliveryId,
      customerName: customerName ?? this.customerName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      signedBy: signedBy ?? this.signedBy,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      
      // 🆕 NEW: Copy OCR fields
      ocrRawText: ocrRawText ?? this.ocrRawText,
      ocrFields: ocrFields ?? this.ocrFields,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
    );
  }
}