import 'package:cloud_firestore/cloud_firestore.dart';

/// Extracted OCR fields from a scanned document
class OcrFields {
  final String? supplier;           // e.g., "Meat Traders (Queenstown) (Pty) Ltd"
  final String? customer;           // e.g., "Boxer Superstores (Pty) Ltd"
  final String? invoiceNo;          // e.g., "INV400098"
  final DateTime? documentDate;     // Parsed date from document
  final String? branch;             // e.g., "X319" or "1250"
  final String? site;               // e.g., "Cleary Park"
  final String? vatNo;              // Numeric string
  final double? totalExcl;          // Total excluding VAT
  final double? totalVat;           // VAT amount
  final double? totalIncl;          // Total including VAT
  final double? totalMassKg;        // Total mass in kg
  final int? totalQty;              // Total quantity
  final String? truckReg;           // Vehicle registration
  final String? driverName;         // Driver name
  final String? receivedBy;         // Person who received the delivery
  final String? ocrRawText;         // Full OCR text for reference

  OcrFields({
    this.supplier,
    this.customer,
    this.invoiceNo,
    this.documentDate,
    this.branch,
    this.site,
    this.vatNo,
    this.totalExcl,
    this.totalVat,
    this.totalIncl,
    this.totalMassKg,
    this.totalQty,
    this.truckReg,
    this.driverName,
    this.receivedBy,
    this.ocrRawText,
  });

  /// Create from JSON
  factory OcrFields.fromJson(Map<String, dynamic> json) {
    return OcrFields(
      supplier: json['supplier'] as String?,
      customer: json['customer'] as String?,
      invoiceNo: json['invoiceNo'] as String?,
      documentDate: json['documentDate'] != null
          ? DateTime.parse(json['documentDate'] as String)
          : null,
      branch: json['branch'] as String?,
      site: json['site'] as String?,
      vatNo: json['vatNo'] as String?,
      totalExcl: (json['totalExcl'] as num?)?.toDouble(),
      totalVat: (json['totalVat'] as num?)?.toDouble(),
      totalIncl: (json['totalIncl'] as num?)?.toDouble(),
      totalMassKg: (json['totalMassKg'] as num?)?.toDouble(),
      totalQty: json['totalQty'] as int?,
      truckReg: json['truckReg'] as String?,
      driverName: json['driverName'] as String?,
      receivedBy: json['receivedBy'] as String?,
      ocrRawText: json['ocrRawText'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'supplier': supplier,
        'customer': customer,
        'invoiceNo': invoiceNo,
        'documentDate': documentDate?.toIso8601String(),
        'branch': branch,
        'site': site,
        'vatNo': vatNo,
        'totalExcl': totalExcl,
        'totalVat': totalVat,
        'totalIncl': totalIncl,
        'totalMassKg': totalMassKg,
        'totalQty': totalQty,
        'truckReg': truckReg,
        'driverName': driverName,
        'receivedBy': receivedBy,
        'ocrRawText': ocrRawText,
      };

  @override
  String toString() => 'OcrFields(invoiceNo: $invoiceNo, customer: $customer, '
      'totalIncl: $totalIncl, truckReg: $truckReg)';
}

/// Detection flags for document quality and features
class DetectionFlags {
  final bool hasSignature;          // Signature detected
  final bool hasStamp;              // Stamp/marking detected
  final bool ocrConfident;          // OCR confidence >= threshold
  final List<String> warnings;      // Validation warnings
  final double ocrConfidenceScore;  // 0.0 to 1.0

  DetectionFlags({
    this.hasSignature = false,
    this.hasStamp = false,
    this.ocrConfident = false,
    this.warnings = const [],
    this.ocrConfidenceScore = 0.5,
  });

  /// Create from JSON
  factory DetectionFlags.fromJson(Map<String, dynamic> json) {
    return DetectionFlags(
      hasSignature: json['hasSignature'] as bool? ?? false,
      hasStamp: json['hasStamp'] as bool? ?? false,
      ocrConfident: json['ocrConfident'] as bool? ?? false,
      warnings: List<String>.from(json['warnings'] as List? ?? []),
      ocrConfidenceScore: (json['ocrConfidenceScore'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'hasSignature': hasSignature,
        'hasStamp': hasStamp,
        'ocrConfident': ocrConfident,
        'warnings': warnings,
        'ocrConfidenceScore': ocrConfidenceScore,
      };

  @override
  String toString() => 'DetectionFlags(signature: $hasSignature, stamp: $hasStamp, '
      'confident: $ocrConfident, warnings: ${warnings.length})';
}

/// POD Document - represents a scanned invoice or delivery note
class PodDocument {
  final String id;                  // Firestore doc ID
  final String companyId;           // Company that owns this document
  final String type;                // 'invoice', 'delivery_note', 'unknown'
  final String storagePath;         // gs://bucket/path/to/image
  final DateTime capturedAt;        // When the photo was taken
  final String capturedByUid;       // User who captured it (driver UID)
  final OcrFields fields;           // Extracted fields
  final DetectionFlags flags;       // Quality and feature detection
  final String? matchedDeliveryId;  // Linked delivery ID if auto-matched
  final String status;              // 'Pending', 'Needs Review', 'Verified', 'Rejected'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;              // Admin notes

  PodDocument({
    required this.id,
    required this.companyId,
    required this.type,
    required this.storagePath,
    required this.capturedAt,
    required this.capturedByUid,
    required this.fields,
    required this.flags,
    this.matchedDeliveryId,
    this.status = 'Pending',
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  /// Create from Firestore document
  factory PodDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PodDocument(
      id: doc.id,
      companyId: data['companyId'] as String? ?? '',
      type: data['type'] as String? ?? 'unknown',
      storagePath: data['storagePath'] as String? ?? '',
      capturedAt: (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      capturedByUid: data['capturedByUid'] as String? ?? '',
      fields: OcrFields.fromJson(data['fields'] as Map<String, dynamic>? ?? {}),
      flags:
          DetectionFlags.fromJson(data['flags'] as Map<String, dynamic>? ?? {}),
      matchedDeliveryId: data['matchedDeliveryId'] as String?,
      status: data['status'] as String? ?? 'Pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() => {
        'companyId': companyId,
        'type': type,
        'storagePath': storagePath,
        'capturedAt': Timestamp.fromDate(capturedAt),
        'capturedByUid': capturedByUid,
        'fields': fields.toJson(),
        'flags': flags.toJson(),
        'matchedDeliveryId': matchedDeliveryId,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'notes': notes,
      };

  /// Copy with modifications
  PodDocument copyWith({
    String? id,
    String? companyId,
    String? type,
    String? storagePath,
    DateTime? capturedAt,
    String? capturedByUid,
    OcrFields? fields,
    DetectionFlags? flags,
    String? matchedDeliveryId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) {
    return PodDocument(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      type: type ?? this.type,
      storagePath: storagePath ?? this.storagePath,
      capturedAt: capturedAt ?? this.capturedAt,
      capturedByUid: capturedByUid ?? this.capturedByUid,
      fields: fields ?? this.fields,
      flags: flags ?? this.flags,
      matchedDeliveryId: matchedDeliveryId ?? this.matchedDeliveryId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() =>
      'PodDocument(id: $id, type: $type, invoiceNo: ${fields.invoiceNo}, '
      'status: $status, matched: ${matchedDeliveryId != null})';
}
