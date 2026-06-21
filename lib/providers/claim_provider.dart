import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import '../models/claim_model.dart';
import '../models/company_claim_settings.dart';
import '../services/claim_service.dart';

/// Provider for managing claims state
class ClaimProvider with ChangeNotifier {
  final ClaimService _claimService = ClaimService();
  final Logger _logger = Logger();
  
  // Current company
  String? _companyId;
  
  // Company settings
  CompanyClaimSettings? _settings;
  
  // Claims cache
  List<Claim> _allClaims = [];
  List<Claim> _filteredClaims = [];
  
  // Stream caches - prevent creating multiple streams
  Stream<List<Claim>>? _pendingEvidenceStream;
  
  // Filters
  ClaimStatus? _statusFilter;
  ClaimType? _typeFilter;
  String? _driverIdFilter;
  String? _customerIdFilter;
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  String? _searchQuery;
  // Advanced filters
  String? _customerNumberFilter;
  String? _customerNameFilter;
  String? _invoiceNumberFilter;
  String? _orderNumberFilter;
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingSettings = false;
  String? _error;
  
  // Getters
  String? get companyId => _companyId;
  CompanyClaimSettings? get settings => _settings;
  List<Claim> get claims => _filteredClaims;
  List<Claim> get allClaims => _allClaims;
  bool get isLoading => _isLoading;
  bool get isLoadingSettings => _isLoadingSettings;
  String? get error => _error;
  
  ClaimStatus? get statusFilter => _statusFilter;
  ClaimType? get typeFilter => _typeFilter;
  String? get driverIdFilter => _driverIdFilter;
  String? get customerIdFilter => _customerIdFilter;
  DateTime? get startDateFilter => _startDateFilter;
  DateTime? get endDateFilter => _endDateFilter;
  String? get searchQuery => _searchQuery;
  String? get customerNumberFilter => _customerNumberFilter;
  String? get customerNameFilter => _customerNameFilter;
  String? get invoiceNumberFilter => _invoiceNumberFilter;
  String? get orderNumberFilter => _orderNumberFilter;
  
  /// Initialize provider with company
  Future<void> initialize(String companyId) async {
    // Clear stream cache if company changed
    if (_companyId != companyId) {
      _logger.i('[ClaimProvider] initialize: Company changed from $_companyId to $companyId, clearing stream cache');
      _pendingEvidenceStream = null;
    }
    
    _companyId = companyId;
    await loadSettings();
  }
  
  /// Load company claim settings
  Future<void> loadSettings() async {
    if (_companyId == null) return;
    
    _isLoadingSettings = true;
    _error = null;
    notifyListeners();
    
    try {
      // Load from Firestore (you'll need to add this method to ClaimService)
      // For now, using default settings
      _settings = CompanyClaimSettings(companyId: _companyId!);
      _error = null;
    } catch (e) {
      _error = 'Failed to load settings: $e';
      _logger.e(_error);
    } finally {
      _isLoadingSettings = false;
      notifyListeners();
    }
  }
  
  /// Load claims for a specific driver
  Future<void> loadClaimsForDriver(String driverId) async {
    if (_companyId == null) return;
    
    _isLoading = true;
    _error = null;
    _driverIdFilter = driverId;
    notifyListeners();
    
    try {
      // Subscribe to claims stream
      final stream = _claimService.getClaimsStream(
        _companyId!,
        driverId: driverId,
      );
      
      // Listen to first snapshot (initial load)
      final claims = await stream.first;
      _allClaims = claims;
      _applyFilters();
      _error = null;
      
      // Continue listening for updates
      stream.listen(
        (claims) {
          _allClaims = claims;
          _applyFilters();
        },
        onError: (error) {
          _error = 'Error loading claims: $error';
          _logger.e(_error);
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to load claims: $e';
      _logger.e(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load all claims for the company (admin view)
  Future<void> loadAllClaims() async {
    if (_companyId == null) return;
    
    _isLoading = true;
    _error = null;
    _driverIdFilter = null; // Clear driver filter for admin view
    notifyListeners();
    
    try {
      // Subscribe to all company claims stream (no driver filter)
      _logger.i('[ClaimProvider] loadAllClaims: Loading for companyId: $_companyId');
      final stream = _claimService.getClaimsStream(_companyId!);
      
      // Listen to first snapshot (initial load)
      final claims = await stream.first;
      _allClaims = claims;
      _applyFilters();
      _error = null;
      
      // Debug: Log loaded claims
      _logger.i('[ClaimProvider] Loaded ${claims.length} claims');
      if (claims.isNotEmpty) {
        _logger.i('[ClaimProvider] First claim: ${claims.first.id} - ${claims.first.title} (companyId: ${claims.first.companyId})');
      }
      
      // Continue listening for updates
      stream.listen(
        (claims) {
          _allClaims = claims;
          _applyFilters();
        },
        onError: (error) {
          _error = 'Error loading claims: $error';
          _logger.e(_error);
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to load claims: $e';
      _logger.e(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get claims stream (auto-updates)
  Stream<List<Claim>>? getClaimsStream() {
    if (_companyId == null) return null;
    
    return _claimService.getClaimsStream(
      _companyId!,
      status: _statusFilter,
      type: _typeFilter,
      driverId: _driverIdFilter,
      customerId: _customerIdFilter,
      startDate: _startDateFilter,
      endDate: _endDateFilter,
    );
  }
  
  /// Update claims from stream
  void updateClaims(List<Claim> claims) {
    _allClaims = claims;
    _applyFilters();
  }
  
  /// Set status filter
  void setStatusFilter(ClaimStatus? status) {
    _statusFilter = status;
    _applyFilters();
  }
  
  /// Set type filter
  void setTypeFilter(ClaimType? type) {
    _typeFilter = type;
    _applyFilters();
  }
  
  /// Set driver filter
  void setDriverFilter(String? driverId) {
    _driverIdFilter = driverId;
    _applyFilters();
  }
  
  /// Set customer filter
  void setCustomerFilter(String? customerId) {
    _customerIdFilter = customerId;
    _applyFilters();
  }
  
  /// Set date range filter
  void setDateRangeFilter(DateTime? start, DateTime? end) {
    _startDateFilter = start;
    _endDateFilter = end;
    _applyFilters();
  }
  
  /// Set search query
  void setSearchQuery(String? query) {
    _searchQuery = query;
    _applyFilters();
  }
  
  /// Set customer number filter
  void setCustomerNumberFilter(String? customerNumber) {
    _customerNumberFilter = customerNumber;
    _applyFilters();
  }
  
  /// Set customer name filter
  void setCustomerNameFilter(String? customerName) {
    _customerNameFilter = customerName;
    _applyFilters();
  }
  
  /// Set invoice number filter
  void setInvoiceNumberFilter(String? invoiceNumber) {
    _invoiceNumberFilter = invoiceNumber;
    _applyFilters();
  }
  
  /// Set order number filter
  void setOrderNumberFilter(String? orderNumber) {
    _orderNumberFilter = orderNumber;
    _applyFilters();
  }
  
  /// Clear all filters
  void clearFilters() {
    _statusFilter = null;
    _typeFilter = null;
    _driverIdFilter = null;
    _customerIdFilter = null;
    _startDateFilter = null;
    _endDateFilter = null;
    _searchQuery = null;
    _customerNumberFilter = null;
    _customerNameFilter = null;
    _invoiceNumberFilter = null;
    _orderNumberFilter = null;
    _applyFilters();
  }
  
  /// Apply filters to claims
  void _applyFilters() {
    _filteredClaims = _allClaims.where((claim) {
      // Status filter
      if (_statusFilter != null && claim.status != _statusFilter) {
        return false;
      }
      
      // Type filter
      if (_typeFilter != null && claim.type != _typeFilter) {
        return false;
      }
      
      // Driver filter
      if (_driverIdFilter != null && claim.driverId != _driverIdFilter) {
        return false;
      }
      
      // Customer filter
      if (_customerIdFilter != null && claim.customerId != _customerIdFilter) {
        return false;
      }
      
      // Date range filter
      if (_startDateFilter != null && claim.createdAt.isBefore(_startDateFilter!)) {
        return false;
      }
      if (_endDateFilter != null && claim.createdAt.isAfter(_endDateFilter!)) {
        return false;
      }
      
      // Customer number filter
      if (_customerNumberFilter != null && _customerNumberFilter!.isNotEmpty) {
        final query = _customerNumberFilter!.toLowerCase();
        final matches = (claim.customerNumber?.toLowerCase().contains(query) ?? false) ||
                        (claim.customerAccountNumber?.toLowerCase().contains(query) ?? false);
        if (!matches) {
          _logger.d('[DEBUG] Customer number filter REJECTED: customerNumber=${claim.customerNumber}, customerAccountNumber=${claim.customerAccountNumber}, query=$query');
          return false;
        }
      }
      
      // Customer name filter
      if (_customerNameFilter != null && _customerNameFilter!.isNotEmpty) {
        final query = _customerNameFilter!.toLowerCase();
        if (!claim.customerName.toLowerCase().contains(query)) {
          _logger.d('[DEBUG] Customer name filter REJECTED: customerName=${claim.customerName}, query=$query');
          return false;
        }
      }
      
      // Invoice number filter
      if (_invoiceNumberFilter != null && _invoiceNumberFilter!.isNotEmpty) {
        final query = _invoiceNumberFilter!.toLowerCase();
        if (!(claim.invoiceNumber?.toLowerCase().contains(query) ?? false)) {
          _logger.d('[DEBUG] Invoice number filter REJECTED: invoiceNumber=${claim.invoiceNumber}, query=$query');
          return false;
        }
      }
      
      // Order number filter (search in delivery ID and metadata)
      if (_orderNumberFilter != null && _orderNumberFilter!.isNotEmpty) {
        final query = _orderNumberFilter!.toLowerCase();
        final deliveryMatch = claim.deliveryId.toLowerCase().contains(query);
        // Check metadata for stored order number
        final metadataOrderNumber = claim.metadata['orderNumber'] as String?;
        final metadataMatch = metadataOrderNumber?.toLowerCase().contains(query) ?? false;
        
        _logger.d('[DEBUG] Order filter check: query=$query, deliveryId=${claim.deliveryId}, metadataOrderNumber=$metadataOrderNumber, deliveryMatch=$deliveryMatch, metadataMatch=$metadataMatch');
        
        if (!deliveryMatch && !metadataMatch) {
          _logger.d('[DEBUG] Order number filter REJECTED');
          return false;
        }
      }
      
      // Search query
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        return claim.id.toLowerCase().contains(query) ||
               claim.customerName.toLowerCase().contains(query) ||
               claim.driverName.toLowerCase().contains(query) ||
               claim.description.toLowerCase().contains(query) ||
               (claim.invoiceNumber?.toLowerCase().contains(query) ?? false);
      }
      
      return true;
    }).toList();
    
    _logger.d('[DEBUG] Filtered claims: ${_filteredClaims.length} out of ${_allClaims.length}');
    notifyListeners();
  }
  
  /// Get claims pending action for user
  Stream<List<Claim>>? getClaimsPendingAction(String userId, String userRole) {
    if (_companyId == null) return null;
    
    return _claimService.getClaimsPendingAction(_companyId!, userId, userRole);
  }
  
  /// Create new claim
  Future<String?> createClaim(Claim claim) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return null;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final claimId = await _claimService.createClaim(claim);
      _error = null;
      return claimId;
    } catch (e) {
      _error = 'Failed to create claim: $e';
      _logger.e(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Update claim
  Future<bool> updateClaim(Claim claim) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _claimService.updateClaim(_companyId!, claim);
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to update claim: $e';
      _logger.e(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Update claim status
  Future<bool> updateClaimStatus({
    required String claimId,
    required ClaimStatus newStatus,
    required String userId,
    required String userName,
    String? notes,
  }) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _claimService.updateClaimStatus(
        companyId: _companyId!,
        claimId: claimId,
        newStatus: newStatus,
        userId: userId,
        userName: userName,
        notes: notes,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to update status: $e';
      _logger.e(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Add comment to claim
  Future<bool> addComment({
    required String claimId,
    required ClaimComment comment,
  }) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return false;
    }
    
    try {
      await _claimService.addComment(
        companyId: _companyId!,
        claimId: claimId,
        comment: comment,
      );
      return true;
    } catch (e) {
      _error = 'Failed to add comment: $e';
      _logger.e(_error);
      return false;
    }
  }
  
  /// Approve claim level
  Future<bool> approveClaimLevel({
    required String claimId,
    required String userId,
    required String userName,
    required String userRole,
    String? notes,
    String? signatureUrl,
  }) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _claimService.approveClaimLevel(
        companyId: _companyId!,
        claimId: claimId,
        userId: userId,
        userName: userName,
        userRole: userRole,
        notes: notes,
        signatureUrl: signatureUrl,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to approve claim: $e';
      _logger.e(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Reject claim
  Future<bool> rejectClaim({
    required String claimId,
    required String userId,
    required String userName,
    required String reason,
  }) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _claimService.rejectClaim(
        companyId: _companyId!,
        claimId: claimId,
        userId: userId,
        userName: userName,
        reason: reason,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to reject claim: $e';
      _logger.e(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Resolve claim
  Future<bool> resolveClaim({
    required String claimId,
    required String userId,
    required String userName,
    required ClaimResolution resolution,
    String? resolutionNotes,
    String? creditNoteNumber,
    String? debitNoteNumber,
  }) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _claimService.resolveClaim(
        companyId: _companyId!,
        claimId: claimId,
        userId: userId,
        userName: userName,
        resolution: resolution,
        resolutionNotes: resolutionNotes,
        creditNoteNumber: creditNoteNumber,
        debitNoteNumber: debitNoteNumber,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to resolve claim: $e';
      _logger.e(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Close claim
  Future<bool> closeClaim({
    required String claimId,
    required String userId,
    required String userName,
    String? notes,
  }) async {
    if (_companyId == null) {
      _error = 'No company selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _claimService.closeClaim(
        companyId: _companyId!,
        claimId: claimId,
        userId: userId,
        userName: userName,
        notes: notes,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to close claim: $e';
      _logger.e(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get analytics
  Future<Map<String, dynamic>?> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_companyId == null) return null;
    
    try {
      return await _claimService.getClaimAnalytics(
        companyId: _companyId!,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = 'Failed to load analytics: $e';
      _logger.e(_error);
      return null;
    }
  }
  
  /// Get claim by ID
  Future<Claim?> getClaimById(String claimId) async {
    if (_companyId == null) return null;
    
    try {
      return await _claimService.getClaim(_companyId!, claimId);
    } catch (e) {
      _error = 'Failed to load claim: $e';
      _logger.e(_error);
      return null;
    }
  }
  
  /// Check if claim type is enabled
  bool isClaimTypeEnabled(ClaimType type) {
    return _settings?.isClaimTypeEnabled(type) ?? true;
  }
  
  /// Get enabled claim types
  List<ClaimType> getEnabledClaimTypes() {
    return _settings?.enabledClaimTypes ?? ClaimType.values;
  }
  
  /// Get workflow for claim type
  List<ApprovalRole> getWorkflowForType(ClaimType type) {
    return _settings?.getWorkflowForType(type) ?? [];
  }
  
  /// Get custom fields for claim type
  List<CustomFieldDefinition> getCustomFieldsForType(ClaimType type) {
    return _settings?.getCustomFieldsForType(type) ?? [];
  }
  
  // ===== Delayed Evidence Methods =====
  
  /// Create a claim without evidence requirement
  Future<String> createClaimWithoutEvidence(Claim claim) async {
    if (_companyId == null) {
      throw Exception('Company ID not set');
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final claimId = await _claimService.createClaimWithoutEvidence(
        _companyId!,
        claim,
      );
      
      // Refresh claims list
      await loadAllClaims();
      
      return claimId;
    } catch (e) {
      _error = 'Failed to create claim: $e';
      _logger.e(_error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Upload evidence to an existing claim
  Future<void> uploadEvidenceToClaim(
    String claimId,
    List<dynamic>? photos,
    dynamic signature,
    List<dynamic>? documents,
  ) async {
    if (_companyId == null) {
      throw Exception('Company ID not set');
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Normalize photos to {bytes, filename} maps for cross-platform uploads
      List<dynamic>? normalizedPhotos;
      if (photos != null && photos.isNotEmpty) {
        normalizedPhotos = [];
        for (int i = 0; i < photos.length; i++) {
          final p = photos[i];
          if (p == null) continue;

          try {
            // Accept pre-normalized maps (preferred for web compatibility)
            if (p is Map && p['bytes'] is Uint8List) {
              final fname = p['filename'] is String ? p['filename'] as String : 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
              normalizedPhotos.add({'bytes': p['bytes'] as Uint8List, 'filename': fname});
            } else if (p is Uint8List) {
              normalizedPhotos.add({
                'bytes': p,
                'filename': 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg'
              });
            } else if (p is XFile) {
              final bytes = await p.readAsBytes();
              normalizedPhotos.add({'bytes': bytes, 'filename': p.name});
            } else if (p is File) {
              if (kIsWeb) {
                throw Exception('On web, File objects are not supported. Use normalized maps with bytes.');
              } else {
                final bytes = await p.readAsBytes();
                final fileName = p.path.split(Platform.pathSeparator).last;
                normalizedPhotos.add({'bytes': bytes, 'filename': fileName});
              }
            } else {
              // Fallback: try dynamic read
              final dynamic dp = p;
              final bytes = await dp.readAsBytes();
              normalizedPhotos.add({'bytes': bytes, 'filename': 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg'});
            }
          } catch (e) {
            _error = 'Failed to prepare photo $i: $e';
            rethrow;
          }
        }
      }

      await _claimService.uploadEvidenceToClaim(
        _companyId!,
        claimId,
        normalizedPhotos,
        signature,
        documents,
      );
      
      // Refresh claims list
      await loadAllClaims();
      
    } catch (e) {
      _error = 'Failed to upload evidence: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get stream of claims pending evidence
  Stream<List<Claim>> getClaimsPendingEvidenceStream() {
    if (_companyId == null) {
      return Stream.value([]);
    }
    
    // Cache the stream so multiple calls don't create new subscriptions
    _pendingEvidenceStream ??= _claimService.getClaimsPendingEvidence(_companyId!);
    
    return _pendingEvidenceStream!;
  }
  
  /// Get count of claims pending evidence
  Future<int> getClaimsPendingEvidenceCount() async {
    if (_companyId == null) return 0;
    
    try {
      return await _claimService
          .getClaimsPendingEvidence(_companyId!)
          .first
          .then((claims) => claims.length);
    } catch (e) {
      _logger.e('Error getting pending evidence count: $e');
      return 0;
    }
  }
  
  /// Update evidence status for a claim
  Future<void> updateEvidenceStatus(
    String claimId,
    String status,
  ) async {
    if (_companyId == null) {
      throw Exception('Company ID not set');
    }
    
    try {
      await _claimService.updateEvidenceStatus(
        _companyId!,
        claimId,
        status,
      );
      
      // Refresh claims list
      await loadAllClaims();
      
    } catch (e) {
      _error = 'Failed to update evidence status: $e';
      _logger.e(_error);
      rethrow;
    }
  }
  
  /// Statistics helpers
  int get totalClaims => _filteredClaims.length;
  
  int get pendingClaims => _filteredClaims.where((c) => c.isPendingAction).length;
  
  int get overdueClaims => _filteredClaims.where((c) => c.isSlaBreached).length;
  
  double get totalClaimAmount => _filteredClaims.fold(
    0.0,
    (sum, claim) => sum + (claim.claimAmount ?? 0),
  );
  
  Map<ClaimType, int> get claimsByType {
    final map = <ClaimType, int>{};
    for (var claim in _filteredClaims) {
      map[claim.type] = (map[claim.type] ?? 0) + 1;
    }
    return map;
  }
  
  Map<ClaimStatus, int> get claimsByStatus {
    final map = <ClaimStatus, int>{};
    for (var claim in _filteredClaims) {
      map[claim.status] = (map[claim.status] ?? 0) + 1;
    }
    return map;
  }
}
