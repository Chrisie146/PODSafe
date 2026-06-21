import 'package:cloud_firestore/cloud_firestore.dart';

/// Business Central Configuration Model
/// Stores connection details and authentication info for BC integration
class BCConfig {
  final String companyId; // PODSafe company ID
  final bool isEnabled;
  final String? tenantId; // Azure AD tenant ID
  final String? environment; // production or sandbox
  final String? bcCompanyId; // Business Central company ID
  final String? clientId; // Azure AD app client ID
  final String? bcApiUrl; // Business Central API base URL
  final DateTime? lastSyncedAt;
  final int syncIntervalMinutes;
  final bool autoCreateDeliveries;
  final bool autoAttachPODs;
  final String? lastSyncStatus; // success, failed, in-progress
  final String? lastSyncError;

  BCConfig({
    required this.companyId,
    this.isEnabled = false,
    this.tenantId,
    this.environment = 'production',
    this.bcCompanyId,
    this.clientId,
    this.bcApiUrl,
    this.lastSyncedAt,
    this.syncIntervalMinutes = 15,
    this.autoCreateDeliveries = false,
    this.autoAttachPODs = true,
    this.lastSyncStatus,
    this.lastSyncError,
  });

  /// Create from Firestore document
  factory BCConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('No data found in document');
    }

    return BCConfig(
      companyId: doc.id,
      isEnabled: data['isEnabled'] as bool? ?? false,
      tenantId: data['tenantId'] as String?,
      environment: data['environment'] as String? ?? 'production',
      bcCompanyId: data['bcCompanyId'] as String?,
      clientId: data['clientId'] as String?,
      bcApiUrl: data['bcApiUrl'] as String?,
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
      syncIntervalMinutes: data['syncIntervalMinutes'] as int? ?? 15,
      autoCreateDeliveries: data['autoCreateDeliveries'] as bool? ?? false,
      autoAttachPODs: data['autoAttachPODs'] as bool? ?? true,
      lastSyncStatus: data['lastSyncStatus'] as String?,
      lastSyncError: data['lastSyncError'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'isEnabled': isEnabled,
      'tenantId': tenantId,
      'environment': environment,
      'bcCompanyId': bcCompanyId,
      'clientId': clientId,
      'bcApiUrl': bcApiUrl,
      'lastSyncedAt': lastSyncedAt != null ? Timestamp.fromDate(lastSyncedAt!) : null,
      'syncIntervalMinutes': syncIntervalMinutes,
      'autoCreateDeliveries': autoCreateDeliveries,
      'autoAttachPODs': autoAttachPODs,
      'lastSyncStatus': lastSyncStatus,
      'lastSyncError': lastSyncError,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with updated fields
  BCConfig copyWith({
    String? companyId,
    bool? isEnabled,
    String? tenantId,
    String? environment,
    String? bcCompanyId,
    String? clientId,
    String? bcApiUrl,
    DateTime? lastSyncedAt,
    int? syncIntervalMinutes,
    bool? autoCreateDeliveries,
    bool? autoAttachPODs,
    String? lastSyncStatus,
    String? lastSyncError,
  }) {
    return BCConfig(
      companyId: companyId ?? this.companyId,
      isEnabled: isEnabled ?? this.isEnabled,
      tenantId: tenantId ?? this.tenantId,
      environment: environment ?? this.environment,
      bcCompanyId: bcCompanyId ?? this.bcCompanyId,
      clientId: clientId ?? this.clientId,
      bcApiUrl: bcApiUrl ?? this.bcApiUrl,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      autoCreateDeliveries: autoCreateDeliveries ?? this.autoCreateDeliveries,
      autoAttachPODs: autoAttachPODs ?? this.autoAttachPODs,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  /// Get full BC API endpoint URL
  String getApiEndpoint(String path) {
    if (bcApiUrl == null || bcApiUrl!.isEmpty) {
      throw Exception('BC API URL not configured');
    }
    final baseUrl = bcApiUrl!.endsWith('/') ? bcApiUrl! : '$bcApiUrl/';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl$cleanPath';
  }

  /// Check if configuration is complete and valid
  bool get isConfigured {
    return tenantId != null &&
        tenantId!.isNotEmpty &&
        bcCompanyId != null &&
        bcCompanyId!.isNotEmpty &&
        clientId != null &&
        clientId!.isNotEmpty &&
        bcApiUrl != null &&
        bcApiUrl!.isNotEmpty;
  }

  @override
  String toString() {
    return 'BCConfig(companyId: $companyId, isEnabled: $isEnabled, environment: $environment, isConfigured: $isConfigured)';
  }
}
