import 'package:cloud_firestore/cloud_firestore.dart';
import 'claim_model.dart';

/// Company-specific claim configuration
/// Allows each company to customize their claims process
class CompanyClaimSettings {
  final String companyId;
  
  // Enabled claim types
  final List<ClaimType> enabledClaimTypes;
  
  // Photo requirements
  final int minPhotosRequired;
  final int maxPhotosAllowed;
  final bool photosMandatory;
  final bool requirePhotoForImmediate;
  final bool requirePhotoForDelayed;
  
  // Signature requirements
  final bool requireCustomerSignature;
  final bool requireDriverSignature;
  
  // Time limits
  final int? claimFilingDeadlineDays; // How many days after delivery can claim be filed
  final int defaultSlaHours;          // Default SLA for approvals
  
  // Approval workflow presets
  final ClaimWorkflowPreset workflowPreset;
  final Map<ClaimType, List<ApprovalRole>> customWorkflows; // Custom workflows per claim type
  
  // Auto-approval rules
  final bool enableAutoApproval;
  final double? autoApproveUnderAmount;
  final List<ClaimType>? autoApproveTypes;
  
  // Custom fields per claim type
  final Map<ClaimType, List<CustomFieldDefinition>> customFieldsByType;
  
  // Notification settings
  final bool enablePushNotifications;
  final bool enableEmailNotifications;
  final bool enableSMSNotifications;
  
  // Integration settings
  final bool requiresERPSync;
  final String? erpSystem;
  final Map<String, dynamic>? erpConfig;
  
  // Fraud detection
  final bool enableFraudDetection;
  final double? fraudThresholdAmount;
  final int? fraudThresholdFrequency; // Claims per month
  
  // Pattern detection
  final bool enablePatternDetection;
  final int? recurringClaimThreshold; // Same issue X times = pattern
  
  // Features enabled
  final bool allowDriverFiling;
  final bool allowAdminFiling;
  final bool allowCustomerPortal;
  final bool enableComments;
  final bool enableInternalNotes;
  
  // Display settings
  final String claimIdPrefix; // e.g., "CLM", "CLAIM", "ISS"
  final int claimIdStartNumber;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyClaimSettings({
    required this.companyId,
    this.enabledClaimTypes = const [
      ClaimType.damaged,
      ClaimType.shortage,
      ClaimType.wrongItems,
      ClaimType.returns,
      ClaimType.other,
    ],
    this.minPhotosRequired = 1,
    this.maxPhotosAllowed = 10,
    this.photosMandatory = true,
    this.requirePhotoForImmediate = true,
    this.requirePhotoForDelayed = false,
    this.requireCustomerSignature = false,
    this.requireDriverSignature = false,
    this.claimFilingDeadlineDays,
    this.defaultSlaHours = 24,
    this.workflowPreset = ClaimWorkflowPreset.standard,
    this.customWorkflows = const {},
    this.enableAutoApproval = false,
    this.autoApproveUnderAmount,
    this.autoApproveTypes,
    this.customFieldsByType = const {},
    this.enablePushNotifications = true,
    this.enableEmailNotifications = false,
    this.enableSMSNotifications = false,
    this.requiresERPSync = false,
    this.erpSystem,
    this.erpConfig,
    this.enableFraudDetection = false,
    this.fraudThresholdAmount,
    this.fraudThresholdFrequency,
    this.enablePatternDetection = true,
    this.recurringClaimThreshold = 3,
    this.allowDriverFiling = true,
    this.allowAdminFiling = true,
    this.allowCustomerPortal = false,
    this.enableComments = true,
    this.enableInternalNotes = true,
    this.claimIdPrefix = 'CLM',
    this.claimIdStartNumber = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'enabledClaimTypes': enabledClaimTypes.map((e) => e.name).toList(),
      'minPhotosRequired': minPhotosRequired,
      'maxPhotosAllowed': maxPhotosAllowed,
      'photosMandatory': photosMandatory,
      'requirePhotoForImmediate': requirePhotoForImmediate,
      'requirePhotoForDelayed': requirePhotoForDelayed,
      'requireCustomerSignature': requireCustomerSignature,
      'requireDriverSignature': requireDriverSignature,
      'claimFilingDeadlineDays': claimFilingDeadlineDays,
      'defaultSlaHours': defaultSlaHours,
      'workflowPreset': workflowPreset.name,
      'customWorkflows': customWorkflows.map(
        (type, roles) => MapEntry(
          type.name,
          roles.map((r) => r.toMap()).toList(),
        ),
      ),
      'enableAutoApproval': enableAutoApproval,
      'autoApproveUnderAmount': autoApproveUnderAmount,
      'autoApproveTypes': autoApproveTypes?.map((e) => e.name).toList(),
      'customFieldsByType': customFieldsByType.map(
        (type, fields) => MapEntry(
          type.name,
          fields.map((f) => f.toMap()).toList(),
        ),
      ),
      'enablePushNotifications': enablePushNotifications,
      'enableEmailNotifications': enableEmailNotifications,
      'enableSMSNotifications': enableSMSNotifications,
      'requiresERPSync': requiresERPSync,
      'erpSystem': erpSystem,
      'erpConfig': erpConfig,
      'enableFraudDetection': enableFraudDetection,
      'fraudThresholdAmount': fraudThresholdAmount,
      'fraudThresholdFrequency': fraudThresholdFrequency,
      'enablePatternDetection': enablePatternDetection,
      'recurringClaimThreshold': recurringClaimThreshold,
      'allowDriverFiling': allowDriverFiling,
      'allowAdminFiling': allowAdminFiling,
      'allowCustomerPortal': allowCustomerPortal,
      'enableComments': enableComments,
      'enableInternalNotes': enableInternalNotes,
      'claimIdPrefix': claimIdPrefix,
      'claimIdStartNumber': claimIdStartNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CompanyClaimSettings.fromMap(Map<String, dynamic> map) {
    return CompanyClaimSettings(
      companyId: map['companyId'] ?? '',
      enabledClaimTypes: (map['enabledClaimTypes'] as List?)
              ?.map((e) => ClaimType.values.firstWhere(
                    (type) => type.name == e,
                    orElse: () => ClaimType.other,
                  ))
              .toList() ??
          [ClaimType.damaged, ClaimType.shortage, ClaimType.other],
      minPhotosRequired: map['minPhotosRequired'] ?? 1,
      maxPhotosAllowed: map['maxPhotosAllowed'] ?? 10,
      photosMandatory: map['photosMandatory'] ?? true,
      requirePhotoForImmediate: map['requirePhotoForImmediate'] ?? true,
      requirePhotoForDelayed: map['requirePhotoForDelayed'] ?? false,
      requireCustomerSignature: map['requireCustomerSignature'] ?? false,
      requireDriverSignature: map['requireDriverSignature'] ?? false,
      claimFilingDeadlineDays: map['claimFilingDeadlineDays'],
      defaultSlaHours: map['defaultSlaHours'] ?? 24,
      workflowPreset: ClaimWorkflowPreset.values.firstWhere(
        (e) => e.name == map['workflowPreset'],
        orElse: () => ClaimWorkflowPreset.standard,
      ),
      customWorkflows: (map['customWorkflows'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              ClaimType.values.firstWhere(
                (type) => type.name == key,
                orElse: () => ClaimType.other,
              ),
              (value as List).map((r) => ApprovalRole.fromMap(r)).toList(),
            ),
          ) ??
          {},
      enableAutoApproval: map['enableAutoApproval'] ?? false,
      autoApproveUnderAmount: map['autoApproveUnderAmount']?.toDouble(),
      autoApproveTypes: (map['autoApproveTypes'] as List?)
          ?.map((e) => ClaimType.values.firstWhere(
                (type) => type.name == e,
                orElse: () => ClaimType.other,
              ))
          .toList(),
      customFieldsByType: (map['customFieldsByType'] as Map<String, dynamic>?)
              ?.map(
            (key, value) => MapEntry(
              ClaimType.values.firstWhere(
                (type) => type.name == key,
                orElse: () => ClaimType.other,
              ),
              (value as List)
                  .map((f) => CustomFieldDefinition.fromMap(f))
                  .toList(),
            ),
          ) ??
          {},
      enablePushNotifications: map['enablePushNotifications'] ?? true,
      enableEmailNotifications: map['enableEmailNotifications'] ?? false,
      enableSMSNotifications: map['enableSMSNotifications'] ?? false,
      requiresERPSync: map['requiresERPSync'] ?? false,
      erpSystem: map['erpSystem'],
      erpConfig: map['erpConfig'],
      enableFraudDetection: map['enableFraudDetection'] ?? false,
      fraudThresholdAmount: map['fraudThresholdAmount']?.toDouble(),
      fraudThresholdFrequency: map['fraudThresholdFrequency'],
      enablePatternDetection: map['enablePatternDetection'] ?? true,
      recurringClaimThreshold: map['recurringClaimThreshold'] ?? 3,
      allowDriverFiling: map['allowDriverFiling'] ?? true,
      allowAdminFiling: map['allowAdminFiling'] ?? true,
      allowCustomerPortal: map['allowCustomerPortal'] ?? false,
      enableComments: map['enableComments'] ?? true,
      enableInternalNotes: map['enableInternalNotes'] ?? true,
      claimIdPrefix: map['claimIdPrefix'] ?? 'CLM',
      claimIdStartNumber: map['claimIdStartNumber'] ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  factory CompanyClaimSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyClaimSettings.fromMap(data);
  }

  /// Helper: Check if claim type is enabled
  bool isClaimTypeEnabled(ClaimType type) {
    return enabledClaimTypes.contains(type);
  }

  /// Helper: Get workflow for claim type
  List<ApprovalRole> getWorkflowForType(ClaimType type) {
    // Check custom workflow first
    if (customWorkflows.containsKey(type)) {
      return customWorkflows[type]!;
    }
    
    // Fall back to preset
    return workflowPreset.getDefaultWorkflow();
  }

  /// Helper: Get custom fields for claim type
  List<CustomFieldDefinition> getCustomFieldsForType(ClaimType type) {
    return customFieldsByType[type] ?? [];
  }

  /// Helper: Check if auto-approval applies
  bool shouldAutoApprove(ClaimType type, double? amount) {
    if (!enableAutoApproval) return false;
    
    // Check type
    if (autoApproveTypes != null && !autoApproveTypes!.contains(type)) {
      return false;
    }
    
    // Check amount
    if (autoApproveUnderAmount != null && amount != null) {
      return amount < autoApproveUnderAmount!;
    }
    
    return false;
  }

  CompanyClaimSettings copyWith({
    String? companyId,
    List<ClaimType>? enabledClaimTypes,
    int? minPhotosRequired,
    int? maxPhotosAllowed,
    bool? photosMandatory,
    bool? requirePhotoForImmediate,
    bool? requirePhotoForDelayed,
    bool? requireCustomerSignature,
    bool? requireDriverSignature,
    int? claimFilingDeadlineDays,
    int? defaultSlaHours,
    ClaimWorkflowPreset? workflowPreset,
    Map<ClaimType, List<ApprovalRole>>? customWorkflows,
    bool? enableAutoApproval,
    double? autoApproveUnderAmount,
    List<ClaimType>? autoApproveTypes,
    Map<ClaimType, List<CustomFieldDefinition>>? customFieldsByType,
    bool? enablePushNotifications,
    bool? enableEmailNotifications,
    bool? enableSMSNotifications,
    bool? requiresERPSync,
    String? erpSystem,
    Map<String, dynamic>? erpConfig,
    bool? enableFraudDetection,
    double? fraudThresholdAmount,
    int? fraudThresholdFrequency,
    bool? enablePatternDetection,
    int? recurringClaimThreshold,
    bool? allowDriverFiling,
    bool? allowAdminFiling,
    bool? allowCustomerPortal,
    bool? enableComments,
    bool? enableInternalNotes,
    String? claimIdPrefix,
    int? claimIdStartNumber,
    DateTime? updatedAt,
  }) {
    return CompanyClaimSettings(
      companyId: companyId ?? this.companyId,
      enabledClaimTypes: enabledClaimTypes ?? this.enabledClaimTypes,
      minPhotosRequired: minPhotosRequired ?? this.minPhotosRequired,
      maxPhotosAllowed: maxPhotosAllowed ?? this.maxPhotosAllowed,
      photosMandatory: photosMandatory ?? this.photosMandatory,
      requirePhotoForImmediate: requirePhotoForImmediate ?? this.requirePhotoForImmediate,
      requirePhotoForDelayed: requirePhotoForDelayed ?? this.requirePhotoForDelayed,
      requireCustomerSignature: requireCustomerSignature ?? this.requireCustomerSignature,
      requireDriverSignature: requireDriverSignature ?? this.requireDriverSignature,
      claimFilingDeadlineDays: claimFilingDeadlineDays ?? this.claimFilingDeadlineDays,
      defaultSlaHours: defaultSlaHours ?? this.defaultSlaHours,
      workflowPreset: workflowPreset ?? this.workflowPreset,
      customWorkflows: customWorkflows ?? this.customWorkflows,
      enableAutoApproval: enableAutoApproval ?? this.enableAutoApproval,
      autoApproveUnderAmount: autoApproveUnderAmount ?? this.autoApproveUnderAmount,
      autoApproveTypes: autoApproveTypes ?? this.autoApproveTypes,
      customFieldsByType: customFieldsByType ?? this.customFieldsByType,
      enablePushNotifications: enablePushNotifications ?? this.enablePushNotifications,
      enableEmailNotifications: enableEmailNotifications ?? this.enableEmailNotifications,
      enableSMSNotifications: enableSMSNotifications ?? this.enableSMSNotifications,
      requiresERPSync: requiresERPSync ?? this.requiresERPSync,
      erpSystem: erpSystem ?? this.erpSystem,
      erpConfig: erpConfig ?? this.erpConfig,
      enableFraudDetection: enableFraudDetection ?? this.enableFraudDetection,
      fraudThresholdAmount: fraudThresholdAmount ?? this.fraudThresholdAmount,
      fraudThresholdFrequency: fraudThresholdFrequency ?? this.fraudThresholdFrequency,
      enablePatternDetection: enablePatternDetection ?? this.enablePatternDetection,
      recurringClaimThreshold: recurringClaimThreshold ?? this.recurringClaimThreshold,
      allowDriverFiling: allowDriverFiling ?? this.allowDriverFiling,
      allowAdminFiling: allowAdminFiling ?? this.allowAdminFiling,
      allowCustomerPortal: allowCustomerPortal ?? this.allowCustomerPortal,
      enableComments: enableComments ?? this.enableComments,
      enableInternalNotes: enableInternalNotes ?? this.enableInternalNotes,
      claimIdPrefix: claimIdPrefix ?? this.claimIdPrefix,
      claimIdStartNumber: claimIdStartNumber ?? this.claimIdStartNumber,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Workflow presets
enum ClaimWorkflowPreset {
  simple,      // Driver → Admin → Done
  standard,    // Driver → Manager → Admin → Done
  enterprise,  // Driver → Manager → Approver → Processor → Reviewer → Done
  custom,      // Fully customized
}

extension ClaimWorkflowPresetExtension on ClaimWorkflowPreset {
  List<ApprovalRole> getDefaultWorkflow() {
    switch (this) {
      case ClaimWorkflowPreset.simple:
        return [
          ApprovalRole(role: 'admin', displayName: 'Admin', slaHours: 24),
        ];
      
      case ClaimWorkflowPreset.standard:
        return [
          ApprovalRole(role: 'manager', displayName: 'Manager', slaHours: 24),
          ApprovalRole(role: 'admin', displayName: 'Admin', slaHours: 24),
        ];
      
      case ClaimWorkflowPreset.enterprise:
        return [
          ApprovalRole(role: 'manager', displayName: 'Manager', slaHours: 24),
          ApprovalRole(role: 'approver', displayName: 'Approver', slaHours: 24),
          ApprovalRole(role: 'processor', displayName: 'Processor', slaHours: 24),
          ApprovalRole(role: 'reviewer', displayName: 'Reviewer', slaHours: 24),
        ];
      
      case ClaimWorkflowPreset.custom:
        return [];
    }
  }

  String get displayName {
    switch (this) {
      case ClaimWorkflowPreset.simple:
        return 'Simple (2 levels)';
      case ClaimWorkflowPreset.standard:
        return 'Standard (3 levels)';
      case ClaimWorkflowPreset.enterprise:
        return 'Enterprise (5 levels)';
      case ClaimWorkflowPreset.custom:
        return 'Custom Workflow';
    }
  }
}

/// Approval role definition
class ApprovalRole {
  final String role;
  final String displayName;
  final int slaHours;
  final bool canApprove;
  final bool canReject;
  final bool canRequestInfo;
  final bool requiresSignature;
  final List<String>? specificUserIds; // Optional: Limit to specific users

  ApprovalRole({
    required this.role,
    required this.displayName,
    this.slaHours = 24,
    this.canApprove = true,
    this.canReject = true,
    this.canRequestInfo = true,
    this.requiresSignature = false,
    this.specificUserIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'displayName': displayName,
      'slaHours': slaHours,
      'canApprove': canApprove,
      'canReject': canReject,
      'canRequestInfo': canRequestInfo,
      'requiresSignature': requiresSignature,
      'specificUserIds': specificUserIds,
    };
  }

  factory ApprovalRole.fromMap(Map<String, dynamic> map) {
    return ApprovalRole(
      role: map['role'] ?? '',
      displayName: map['displayName'] ?? '',
      slaHours: map['slaHours'] ?? 24,
      canApprove: map['canApprove'] ?? true,
      canReject: map['canReject'] ?? true,
      canRequestInfo: map['canRequestInfo'] ?? true,
      requiresSignature: map['requiresSignature'] ?? false,
      specificUserIds: map['specificUserIds'] != null
          ? List<String>.from(map['specificUserIds'])
          : null,
    );
  }
}

/// Custom field definition for company-specific data collection
class CustomFieldDefinition {
  final String id;
  final String label;
  final CustomFieldType type;
  final bool required;
  final List<String>? dropdownOptions;
  final String? placeholder;
  final String? helpText;
  final String? validationRegex;
  final String? errorMessage;
  final int? minValue;
  final int? maxValue;
  final int? maxLength;

  CustomFieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.dropdownOptions,
    this.placeholder,
    this.helpText,
    this.validationRegex,
    this.errorMessage,
    this.minValue,
    this.maxValue,
    this.maxLength,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'required': required,
      'dropdownOptions': dropdownOptions,
      'placeholder': placeholder,
      'helpText': helpText,
      'validationRegex': validationRegex,
      'errorMessage': errorMessage,
      'minValue': minValue,
      'maxValue': maxValue,
      'maxLength': maxLength,
    };
  }

  factory CustomFieldDefinition.fromMap(Map<String, dynamic> map) {
    return CustomFieldDefinition(
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
      helpText: map['helpText'],
      validationRegex: map['validationRegex'],
      errorMessage: map['errorMessage'],
      minValue: map['minValue'],
      maxValue: map['maxValue'],
      maxLength: map['maxLength'],
    );
  }
}
