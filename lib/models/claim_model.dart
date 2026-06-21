import 'package:cloud_firestore/cloud_firestore.dart';

/// Configurable claim types - companies can enable/disable as needed
enum ClaimType {
  damaged,          // Damaged goods
  shortage,         // Short delivered (quantity)
  shortWeight,      // Short weight (weight discrepancy)
  missing,          // Missing items
  wrongItems,       // Wrong products delivered
  returns,          // Customer returns stock
  priceError,       // Pricing discrepancies
  lateDelivery,     // Delivery was late
  didNotDeliver,    // Driver couldn't complete delivery
  qualityIssue,     // Product quality problem
  temperatureIssue, // Cold chain breach
  packagingIssue,   // Packaging damaged/incorrect
  expiryIssue,      // Expiry date problem
  serviceIssue,     // Service quality issue
  other,            // Custom/other
}

/// Claim status through its lifecycle
enum ClaimStatus {
  draft,                    // Being created, not submitted
  submitted,                // Filed, awaiting assignment
  pendingReview,            // Assigned, awaiting initial review
  investigating,            // Under investigation
  pendingDriverResponse,    // Waiting for driver to respond
  driverResponded,          // Driver has responded
  pendingApproval,          // Awaiting manager/approver decision
  pendingSecondApproval,    // Multiple approval levels
  pendingProcessing,        // Approved, awaiting processing (credit note, etc.)
  processing,               // Being processed
  pendingFinalReview,       // Final review before closure
  approved,                 // Claim approved
  rejected,                 // Claim rejected
  resolved,                 // Resolved/completed
  closed,                   // Closed and archived
  cancelled,                // Cancelled by submitter
  disputed,                 // Customer/driver disputes decision
}

/// Priority levels
enum ClaimPriority {
  low,
  medium,
  high,
  urgent,
}

/// How the claim was filed
enum ClaimFilingContext {
  atDeliverySite,    // Filed by driver at customer location (immediate)
  afterDelivery,     // Filed later (delayed - admin or driver)
  systemGenerated,   // Auto-created by system
  customerPortal,    // Filed by customer through portal
}

/// Resolution type
enum ClaimResolution {
  creditIssued,      // Credit note issued to customer
  debitDriver,       // Driver charged/invoiced
  refund,            // Refund issued
  replacement,       // Replacement delivery scheduled
  adjustment,        // Price adjustment
  noAction,          // No action taken
  other,             // Custom resolution
}

/// Custom field types for flexible data collection
enum CustomFieldType {
  text,
  number,
  date,
  dropdown,
  checkbox,
  photo,
  signature,
  file,
}

/// Custom field definition
class CustomField {
  final String id;
  final String label;
  final CustomFieldType type;
  final bool required;
  final List<String>? dropdownOptions;
  final String? placeholder;
  final String? validationRegex;
  final dynamic value;

  CustomField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.dropdownOptions,
    this.placeholder,
    this.validationRegex,
    this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'required': required,
      'dropdownOptions': dropdownOptions,
      'placeholder': placeholder,
      'validationRegex': validationRegex,
      'value': value,
    };
  }

  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      type: CustomFieldType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CustomFieldType.text,
      ),
      required: map['required'] ?? false,
      dropdownOptions: map['dropdownOptions'] != null 
          ? List<String>.from(map['dropdownOptions']) 
          : null,
      placeholder: map['placeholder'],
      validationRegex: map['validationRegex'],
      value: map['value'],
    );
  }
}

/// Approval level in workflow
class ApprovalLevel {
  final String role;           // 'manager', 'approver', 'processor', etc.
  final String? userId;        // Specific user if assigned
  final String? userName;
  final DateTime? actionDate;
  final String? notes;
  final bool approved;
  final String? signatureUrl;
  final int slaHours;          // SLA for this level

  ApprovalLevel({
    required this.role,
    this.userId,
    this.userName,
    this.actionDate,
    this.notes,
    this.approved = false,
    this.signatureUrl,
    this.slaHours = 24,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'userId': userId,
      'userName': userName,
      'actionDate': actionDate?.toIso8601String(),
      'notes': notes,
      'approved': approved,
      'signatureUrl': signatureUrl,
      'slaHours': slaHours,
    };
  }

  factory ApprovalLevel.fromMap(Map<String, dynamic> map) {
    return ApprovalLevel(
      role: map['role'] ?? '',
      userId: map['userId'],
      userName: map['userName'],
      actionDate: map['actionDate'] != null 
          ? (map['actionDate'] is Timestamp 
              ? (map['actionDate'] as Timestamp).toDate()
              : DateTime.parse(map['actionDate'])) 
          : null,
      notes: map['notes'],
      approved: map['approved'] ?? false,
      signatureUrl: map['signatureUrl'],
      slaHours: map['slaHours'] ?? 24,
    );
  }

  ApprovalLevel copyWith({
    String? role,
    String? userId,
    String? userName,
    DateTime? actionDate,
    String? notes,
    bool? approved,
    String? signatureUrl,
    int? slaHours,
  }) {
    return ApprovalLevel(
      role: role ?? this.role,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      actionDate: actionDate ?? this.actionDate,
      notes: notes ?? this.notes,
      approved: approved ?? this.approved,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      slaHours: slaHours ?? this.slaHours,
    );
  }
}

/// Status history entry for audit trail
class StatusHistoryEntry {
  final ClaimStatus status;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String? notes;
  final Map<String, dynamic>? metadata;

  StatusHistoryEntry({
    required this.status,
    required this.timestamp,
    required this.userId,
    required this.userName,
    this.notes,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'notes': notes,
      'metadata': metadata,
    };
  }

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      status: ClaimStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ClaimStatus.submitted,
      ),
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.parse(map['timestamp']),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      notes: map['notes'],
      metadata: map['metadata'],
    );
  }
}

/// Comment on a claim
class ClaimComment {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String comment;
  final DateTime timestamp;
  final List<String> attachmentUrls;
  final bool isInternal; // Internal notes vs customer-visible

  ClaimComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.comment,
    required this.timestamp,
    this.attachmentUrls = const [],
    this.isInternal = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
      'attachmentUrls': attachmentUrls,
      'isInternal': isInternal,
    };
  }

  factory ClaimComment.fromMap(Map<String, dynamic> map) {
    return ClaimComment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userRole: map['userRole'] ?? '',
      comment: map['comment'] ?? '',
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.parse(map['timestamp']),
      attachmentUrls: List<String>.from(map['attachmentUrls'] ?? []),
      isInternal: map['isInternal'] ?? false,
    );
  }
}

/// Main Claim model - flexible and configurable
class Claim {
  final String id;
  final String companyId;
  
  // Basic claim info
  final ClaimType type;
  final ClaimStatus status;
  final ClaimPriority priority;
  final ClaimFilingContext filingContext;
  final String title;
  final String description;
  
  // Related entities
  final String deliveryId;
  final String? podId;
  final String customerId;
  final String customerName;
  final String? customerNumber;        // Customer number (e.g., BOX001, ACME999)
  final String? customerAccountNumber;
  final String driverId;
  final String driverName;
  
  // Financial
  final String? invoiceNumber;
  final double? claimAmount;
  final String? creditNoteNumber;
  final String? debitNoteNumber;
  
  // Dates
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? dueDate;
  final DateTime deliveryDate;
  
  // Filed by
  final String filedBy;
  final String filedByName;
  final String filedByRole;
  
  // Evidence (flexible for different claim types)
  final List<String> photoUrls;
  final String? customerSignatureUrl;
  final String? driverSignatureUrl;
  final Map<String, dynamic> gpsLocation;
  final Map<String, dynamic> metadata; // Flexible key-value storage
  
  // Scanned documents (NEW: Phase 1 enhancement)
  final List<String> documentUrls;
  final List<Map<String, dynamic>> documentMetadata; // Metadata like type, uploadedBy, uploadedAt
  
  // Approval workflow
  final List<ApprovalLevel> approvalChain;
  final int currentApprovalLevel;
  
  // For immediate claims (at delivery site)
  final bool? customerAcknowledged;
  final DateTime? filedAtDelivery;
  
  // For delayed claims (after delivery)
  final bool? driverNotified;
  final bool? driverResponded;
  final String? driverResponse;
  final List<String> driverEvidenceUrls;
  final int? daysAfterDelivery;
  
  // Items affected
  final List<Map<String, dynamic>> affectedItems;
  
  // Investigation
  final String? investigatedBy;
  final String? investigatorName;
  final String? investigationNotes;
  final DateTime? investigationDate;
  
  // Resolution
  final ClaimResolution? resolution;
  final String? resolutionNotes;
  final String? resolvedBy;
  final String? resolvedByName;
  
  // Quality metrics
  final int evidenceQualityScore; // 1-10
  final bool hasAllRequiredEvidence;
  
  // Comments and history
  final List<ClaimComment> comments;
  final List<StatusHistoryEntry> statusHistory;
  
  // Custom fields (company-specific)
  final List<CustomField> customFields;
  
  // Integration
  final String? externalSystemId; // For ERP integration
  final Map<String, dynamic>? externalSystemData;
  
  // Flags
  final bool isFraudulent;
  final bool isEscalated;
  final bool isRecurring; // Pattern detection
  final String? recurringClaimGroupId;
  
  // Evidence tracking (for delayed evidence submission)
  final String evidenceStatus; // pending, received, complete
  final DateTime? evidenceReceivedAt;
  final int photoCount; // Number of photos attached
  final bool hasSignature; // Has signature?
  final bool hasDocuments; // Has documents?

  Claim({
    required this.id,
    required this.companyId,
    required this.type,
    required this.status,
    required this.priority,
    required this.filingContext,
    required this.title,
    required this.description,
    required this.deliveryId,
    this.podId,
    required this.customerId,
    required this.customerName,
    this.customerNumber,
    this.customerAccountNumber,
    required this.driverId,
    required this.driverName,
    this.invoiceNumber,
    this.claimAmount,
    this.creditNoteNumber,
    this.debitNoteNumber,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.dueDate,
    required this.deliveryDate,
    required this.filedBy,
    required this.filedByName,
    required this.filedByRole,
    this.photoUrls = const [],
    this.customerSignatureUrl,
    this.driverSignatureUrl,
    this.gpsLocation = const {},
    this.metadata = const {},
    this.documentUrls = const [],
    this.documentMetadata = const [],
    this.approvalChain = const [],
    this.currentApprovalLevel = 0,
    this.customerAcknowledged,
    this.filedAtDelivery,
    this.driverNotified,
    this.driverResponded,
    this.driverResponse,
    this.driverEvidenceUrls = const [],
    this.daysAfterDelivery,
    this.affectedItems = const [],
    this.investigatedBy,
    this.investigatorName,
    this.investigationNotes,
    this.investigationDate,
    this.resolution,
    this.resolutionNotes,
    this.resolvedBy,
    this.resolvedByName,
    this.evidenceQualityScore = 5,
    this.hasAllRequiredEvidence = false,
    this.comments = const [],
    this.statusHistory = const [],
    this.customFields = const [],
    this.externalSystemId,
    this.externalSystemData,
    this.isFraudulent = false,
    this.isEscalated = false,
    this.isRecurring = false,
    this.recurringClaimGroupId,
    this.evidenceStatus = 'pending',
    this.evidenceReceivedAt,
    this.photoCount = 0,
    this.hasSignature = false,
    this.hasDocuments = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'type': type.name,
      'status': status.name,
      'priority': priority.name,
      'filingContext': filingContext.name,
      'title': title,
      'description': description,
      'deliveryId': deliveryId,
      'podId': podId,
      'customerId': customerId,
      'customerName': customerName,
      'customerNumber': customerNumber,
      'customerAccountNumber': customerAccountNumber,
      'driverId': driverId,
      'driverName': driverName,
      'invoiceNumber': invoiceNumber,
      'claimAmount': claimAmount,
      'creditNoteNumber': creditNoteNumber,
      'debitNoteNumber': debitNoteNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'deliveryDate': deliveryDate.toIso8601String(),
      'filedBy': filedBy,
      'filedByName': filedByName,
      'filedByRole': filedByRole,
      'photoUrls': photoUrls,
      'customerSignatureUrl': customerSignatureUrl,
      'driverSignatureUrl': driverSignatureUrl,
      'gpsLocation': gpsLocation,
      'metadata': metadata,
      'documentUrls': documentUrls,
      'documentMetadata': documentMetadata,
      'approvalChain': approvalChain.map((a) => a.toMap()).toList(),
      'currentApprovalLevel': currentApprovalLevel,
      'customerAcknowledged': customerAcknowledged,
      'filedAtDelivery': filedAtDelivery?.toIso8601String(),
      'driverNotified': driverNotified,
      'driverResponded': driverResponded,
      'driverResponse': driverResponse,
      'driverEvidenceUrls': driverEvidenceUrls,
      'daysAfterDelivery': daysAfterDelivery,
      'affectedItems': affectedItems,
      'investigatedBy': investigatedBy,
      'investigatorName': investigatorName,
      'investigationNotes': investigationNotes,
      'investigationDate': investigationDate?.toIso8601String(),
      'resolution': resolution?.name,
      'resolutionNotes': resolutionNotes,
      'resolvedBy': resolvedBy,
      'resolvedByName': resolvedByName,
      'evidenceQualityScore': evidenceQualityScore,
      'hasAllRequiredEvidence': hasAllRequiredEvidence,
      'comments': comments.map((c) => c.toMap()).toList(),
      'statusHistory': statusHistory.map((h) => h.toMap()).toList(),
      'customFields': customFields.map((f) => f.toMap()).toList(),
      'externalSystemId': externalSystemId,
      'externalSystemData': externalSystemData,
      'isFraudulent': isFraudulent,
      'isEscalated': isEscalated,
      'isRecurring': isRecurring,
      'recurringClaimGroupId': recurringClaimGroupId,
      'evidenceStatus': evidenceStatus,
      'evidenceReceivedAt': evidenceReceivedAt?.toIso8601String(),
      'photoCount': photoCount,
      'hasSignature': hasSignature,
      'hasDocuments': hasDocuments,
    };
  }

  factory Claim.fromMap(Map<String, dynamic> map) {
    return Claim(
      id: map['id'] ?? '',
      companyId: map['companyId'] ?? '',
      type: ClaimType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ClaimType.other,
      ),
      status: ClaimStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ClaimStatus.submitted,
      ),
      priority: ClaimPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => ClaimPriority.medium,
      ),
      filingContext: ClaimFilingContext.values.firstWhere(
        (e) => e.name == map['filingContext'],
        orElse: () => ClaimFilingContext.afterDelivery,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      deliveryId: map['deliveryId'] ?? '',
      podId: map['podId'],
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerNumber: map['customerNumber'],
      customerAccountNumber: map['customerAccountNumber'],
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      invoiceNumber: map['invoiceNumber'],
      claimAmount: map['claimAmount']?.toDouble(),
      creditNoteNumber: map['creditNoteNumber'],
      debitNoteNumber: map['debitNoteNumber'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt']))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp 
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt']))
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null 
          ? (map['resolvedAt'] is Timestamp 
              ? (map['resolvedAt'] as Timestamp).toDate()
              : DateTime.parse(map['resolvedAt'])) 
          : null,
      dueDate: map['dueDate'] != null 
          ? (map['dueDate'] is Timestamp 
              ? (map['dueDate'] as Timestamp).toDate()
              : DateTime.parse(map['dueDate'])) 
          : null,
      deliveryDate: map['deliveryDate'] != null
          ? (map['deliveryDate'] is Timestamp 
              ? (map['deliveryDate'] as Timestamp).toDate()
              : DateTime.parse(map['deliveryDate']))
          : DateTime.now(),
      filedBy: map['filedBy'] ?? '',
      filedByName: map['filedByName'] ?? '',
      filedByRole: map['filedByRole'] ?? '',
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      customerSignatureUrl: map['customerSignatureUrl'],
      driverSignatureUrl: map['driverSignatureUrl'],
      gpsLocation: Map<String, dynamic>.from(map['gpsLocation'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      documentUrls: List<String>.from(map['documentUrls'] ?? []),
      documentMetadata: (map['documentMetadata'] != null 
          ? (map['documentMetadata'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : []),
      approvalChain: (map['approvalChain'] != null
          ? (map['approvalChain'] as List)
              .map((a) => ApprovalLevel.fromMap(a))
              .toList()
          : []),
      currentApprovalLevel: map['currentApprovalLevel'] ?? 0,
      customerAcknowledged: map['customerAcknowledged'],
      filedAtDelivery: map['filedAtDelivery'] != null 
          ? (map['filedAtDelivery'] is Timestamp 
              ? (map['filedAtDelivery'] as Timestamp).toDate()
              : DateTime.parse(map['filedAtDelivery'])) 
          : null,
      driverNotified: map['driverNotified'],
      driverResponded: map['driverResponded'],
      driverResponse: map['driverResponse'],
      driverEvidenceUrls: List<String>.from(map['driverEvidenceUrls'] ?? []),
      daysAfterDelivery: map['daysAfterDelivery'],
      affectedItems: List<Map<String, dynamic>>.from(map['affectedItems'] ?? []),
      investigatedBy: map['investigatedBy'],
      investigatorName: map['investigatorName'],
      investigationNotes: map['investigationNotes'],
      investigationDate: map['investigationDate'] != null 
          ? (map['investigationDate'] is Timestamp 
              ? (map['investigationDate'] as Timestamp).toDate()
              : DateTime.parse(map['investigationDate'])) 
          : null,
      resolution: map['resolution'] != null
          ? ClaimResolution.values.firstWhere(
              (e) => e.name == map['resolution'],
              orElse: () => ClaimResolution.other,
            )
          : null,
      resolutionNotes: map['resolutionNotes'],
      resolvedBy: map['resolvedBy'],
      resolvedByName: map['resolvedByName'],
      evidenceQualityScore: map['evidenceQualityScore'] ?? 5,
      hasAllRequiredEvidence: map['hasAllRequiredEvidence'] ?? false,
      comments: (map['comments'] as List?)
          ?.map((c) => ClaimComment.fromMap(c))
          .toList() ?? [],
      statusHistory: (map['statusHistory'] as List?)
          ?.map((h) => StatusHistoryEntry.fromMap(h))
          .toList() ?? [],
      customFields: (map['customFields'] as List?)
          ?.map((f) => CustomField.fromMap(f))
          .toList() ?? [],
      externalSystemId: map['externalSystemId'],
      externalSystemData: map['externalSystemData'],
      isFraudulent: map['isFraudulent'] ?? false,
      isEscalated: map['isEscalated'] ?? false,
      isRecurring: map['isRecurring'] ?? false,
      recurringClaimGroupId: map['recurringClaimGroupId'],
      evidenceStatus: map['evidenceStatus'] ?? 'pending',
      evidenceReceivedAt: map['evidenceReceivedAt'] != null 
          ? (map['evidenceReceivedAt'] is Timestamp 
              ? (map['evidenceReceivedAt'] as Timestamp).toDate()
              : DateTime.parse(map['evidenceReceivedAt'])) 
          : null,
      photoCount: map['photoCount'] ?? 0,
      hasSignature: map['hasSignature'] ?? false,
      hasDocuments: map['hasDocuments'] ?? false,
    );
  }

  factory Claim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Claim.fromMap({...data, 'id': doc.id});
  }

  Claim copyWith({
    String? id,
    String? companyId,
    ClaimType? type,
    ClaimStatus? status,
    ClaimPriority? priority,
    ClaimFilingContext? filingContext,
    String? title,
    String? description,
    String? deliveryId,
    String? podId,
    String? customerId,
    String? customerName,
    String? customerNumber,
    String? customerAccountNumber,
    String? driverId,
    String? driverName,
    String? invoiceNumber,
    double? claimAmount,
    String? creditNoteNumber,
    String? debitNoteNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? dueDate,
    DateTime? deliveryDate,
    String? filedBy,
    String? filedByName,
    String? filedByRole,
    List<String>? photoUrls,
    String? customerSignatureUrl,
    String? driverSignatureUrl,
    Map<String, dynamic>? gpsLocation,
    Map<String, dynamic>? metadata,
    List<String>? documentUrls,
    List<Map<String, dynamic>>? documentMetadata,
    List<ApprovalLevel>? approvalChain,
    int? currentApprovalLevel,
    bool? customerAcknowledged,
    DateTime? filedAtDelivery,
    bool? driverNotified,
    bool? driverResponded,
    String? driverResponse,
    List<String>? driverEvidenceUrls,
    int? daysAfterDelivery,
    List<Map<String, dynamic>>? affectedItems,
    String? investigatedBy,
    String? investigatorName,
    String? investigationNotes,
    DateTime? investigationDate,
    ClaimResolution? resolution,
    String? resolutionNotes,
    String? resolvedBy,
    String? resolvedByName,
    int? evidenceQualityScore,
    bool? hasAllRequiredEvidence,
    List<ClaimComment>? comments,
    List<StatusHistoryEntry>? statusHistory,
    List<CustomField>? customFields,
    String? externalSystemId,
    Map<String, dynamic>? externalSystemData,
    bool? isFraudulent,
    bool? isEscalated,
    bool? isRecurring,
    String? recurringClaimGroupId,
    String? evidenceStatus,
    DateTime? evidenceReceivedAt,
    int? photoCount,
    bool? hasSignature,
    bool? hasDocuments,
  }) {
    return Claim(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      filingContext: filingContext ?? this.filingContext,
      title: title ?? this.title,
      description: description ?? this.description,
      deliveryId: deliveryId ?? this.deliveryId,
      podId: podId ?? this.podId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerNumber: customerNumber ?? this.customerNumber,
      customerAccountNumber: customerAccountNumber ?? this.customerAccountNumber,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      claimAmount: claimAmount ?? this.claimAmount,
      creditNoteNumber: creditNoteNumber ?? this.creditNoteNumber,
      debitNoteNumber: debitNoteNumber ?? this.debitNoteNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      dueDate: dueDate ?? this.dueDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      filedBy: filedBy ?? this.filedBy,
      filedByName: filedByName ?? this.filedByName,
      filedByRole: filedByRole ?? this.filedByRole,
      photoUrls: photoUrls ?? this.photoUrls,
      customerSignatureUrl: customerSignatureUrl ?? this.customerSignatureUrl,
      driverSignatureUrl: driverSignatureUrl ?? this.driverSignatureUrl,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      metadata: metadata ?? this.metadata,
      documentUrls: documentUrls ?? this.documentUrls,
      documentMetadata: documentMetadata ?? this.documentMetadata,
      approvalChain: approvalChain ?? this.approvalChain,
      currentApprovalLevel: currentApprovalLevel ?? this.currentApprovalLevel,
      customerAcknowledged: customerAcknowledged ?? this.customerAcknowledged,
      filedAtDelivery: filedAtDelivery ?? this.filedAtDelivery,
      driverNotified: driverNotified ?? this.driverNotified,
      driverResponded: driverResponded ?? this.driverResponded,
      driverResponse: driverResponse ?? this.driverResponse,
      driverEvidenceUrls: driverEvidenceUrls ?? this.driverEvidenceUrls,
      daysAfterDelivery: daysAfterDelivery ?? this.daysAfterDelivery,
      affectedItems: affectedItems ?? this.affectedItems,
      investigatedBy: investigatedBy ?? this.investigatedBy,
      investigatorName: investigatorName ?? this.investigatorName,
      investigationNotes: investigationNotes ?? this.investigationNotes,
      investigationDate: investigationDate ?? this.investigationDate,
      resolution: resolution ?? this.resolution,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedByName: resolvedByName ?? this.resolvedByName,
      evidenceQualityScore: evidenceQualityScore ?? this.evidenceQualityScore,
      hasAllRequiredEvidence: hasAllRequiredEvidence ?? this.hasAllRequiredEvidence,
      comments: comments ?? this.comments,
      statusHistory: statusHistory ?? this.statusHistory,
      customFields: customFields ?? this.customFields,
      externalSystemId: externalSystemId ?? this.externalSystemId,
      externalSystemData: externalSystemData ?? this.externalSystemData,
      isFraudulent: isFraudulent ?? this.isFraudulent,
      isEscalated: isEscalated ?? this.isEscalated,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringClaimGroupId: recurringClaimGroupId ?? this.recurringClaimGroupId,
      evidenceStatus: evidenceStatus ?? this.evidenceStatus,
      evidenceReceivedAt: evidenceReceivedAt ?? this.evidenceReceivedAt,
      photoCount: photoCount ?? this.photoCount,
      hasSignature: hasSignature ?? this.hasSignature,
      hasDocuments: hasDocuments ?? this.hasDocuments,
    );
  }

  /// Helper: Get status display text
  String get statusDisplayText {
    switch (status) {
      case ClaimStatus.draft:
        return 'Draft';
      case ClaimStatus.submitted:
        return 'Submitted';
      case ClaimStatus.pendingReview:
        return 'Pending Review';
      case ClaimStatus.investigating:
        return 'Investigating';
      case ClaimStatus.pendingDriverResponse:
        return 'Awaiting Driver Response';
      case ClaimStatus.driverResponded:
        return 'Driver Responded';
      case ClaimStatus.pendingApproval:
        return 'Pending Approval';
      case ClaimStatus.pendingSecondApproval:
        return 'Pending Final Approval';
      case ClaimStatus.pendingProcessing:
        return 'Pending Processing';
      case ClaimStatus.processing:
        return 'Processing';
      case ClaimStatus.pendingFinalReview:
        return 'Pending Final Review';
      case ClaimStatus.approved:
        return 'Approved';
      case ClaimStatus.rejected:
        return 'Rejected';
      case ClaimStatus.resolved:
        return 'Resolved';
      case ClaimStatus.closed:
        return 'Closed';
      case ClaimStatus.cancelled:
        return 'Cancelled';
      case ClaimStatus.disputed:
        return 'Disputed';
    }
  }

  /// Helper: Get type display text
  String get typeDisplayText {
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

  /// Helper: Is SLA breached?
  bool get isSlaBreached {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Helper: Days since filed
  int get daysSinceFiled {
    return DateTime.now().difference(createdAt).inDays;
  }

  /// Helper: Is pending action?
  bool get isPendingAction {
    return status == ClaimStatus.pendingReview ||
           status == ClaimStatus.pendingDriverResponse ||
           status == ClaimStatus.pendingApproval ||
           status == ClaimStatus.pendingSecondApproval ||
           status == ClaimStatus.pendingProcessing ||
           status == ClaimStatus.pendingFinalReview;
  }
}
