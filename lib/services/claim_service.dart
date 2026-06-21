import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/claim_model.dart';
import '../models/company_claim_settings.dart';

/// Service for managing claims in Firestore
class ClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get claims for a company
  Stream<List<Claim>> getClaimsStream(String companyId, {
    ClaimStatus? status,
    ClaimType? type,
    String? driverId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('claims')
        .orderBy('createdAt', descending: true);

    // Apply filters
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    if (driverId != null) {
      query = query.where('driverId', isEqualTo: driverId);
    }
    if (customerId != null) {
      query = query.where('customerId', isEqualTo: customerId);
    }
    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Claim.fromFirestore(doc)).toList();
    });
  }

  /// Get single claim
  Future<Claim?> getClaim(String companyId, String claimId) async {
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .doc(claimId)
          .get();

      if (!doc.exists) return null;
      return Claim.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Get claims pending action for current user
  Stream<List<Claim>> getClaimsPendingAction(
    String companyId,
    String userId,
    String userRole,
  ) {
    // Find claims where current approval level matches user's role
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('claims')
        .where('status', whereIn: [
          ClaimStatus.pendingReview.name,
          ClaimStatus.pendingApproval.name,
          ClaimStatus.pendingSecondApproval.name,
          ClaimStatus.pendingProcessing.name,
          ClaimStatus.pendingFinalReview.name,
        ])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Claim.fromFirestore(doc))
              .where((claim) {
                // Check if current approval level matches user's role
                if (claim.currentApprovalLevel < claim.approvalChain.length) {
                  final currentLevel = claim.approvalChain[claim.currentApprovalLevel];
                  return currentLevel.role == userRole && !currentLevel.approved;
                }
                return false;
              })
              .toList();
        });
  }

  /// Create a new claim
  Future<String> createClaim(Claim claim) async {
    try {
      final claimRef = _firestore
          .collection('companies')
          .doc(claim.companyId)
          .collection('claims')
          .doc();

      final claimWithId = claim.copyWith(
        id: claimRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await claimRef.set(claimWithId.toMap());
      return claimRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update claim
  Future<void> updateClaim(String companyId, Claim claim) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .doc(claim.id)
          .update(claim.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Update claim status with history tracking
  Future<void> updateClaimStatus({
    required String companyId,
    required String claimId,
    required ClaimStatus newStatus,
    required String userId,
    required String userName,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final claim = await getClaim(companyId, claimId);
      if (claim == null) throw Exception('Claim not found');

      final historyEntry = StatusHistoryEntry(
        status: newStatus,
        timestamp: DateTime.now(),
        userId: userId,
        userName: userName,
        notes: notes,
        metadata: metadata,
      );

      final updatedClaim = claim.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        statusHistory: [...claim.statusHistory, historyEntry],
      );

      await updateClaim(companyId, updatedClaim);
    } catch (e) {
      rethrow;
    }
  }

  /// Add comment to claim
  Future<void> addComment({
    required String companyId,
    required String claimId,
    required ClaimComment comment,
  }) async {
    try {
      final claim = await getClaim(companyId, claimId);
      if (claim == null) throw Exception('Claim not found');

      final updatedClaim = claim.copyWith(
        comments: [...claim.comments, comment],
        updatedAt: DateTime.now(),
      );

      await updateClaim(companyId, updatedClaim);
    } catch (e) {
      rethrow;
    }
  }

  /// Upload photo evidence
  Future<String> uploadPhoto({
    required String companyId,
    required String claimId,
    required File photoFile,
    required String fileName,
  }) async {
    try {
      final path = 'companies/$companyId/claims/$claimId/photos/$fileName';
      final ref = _storage.ref().child(path);
      await ref.putFile(photoFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading photo: $e');
      rethrow;
    }
  }

  /// Upload signature
  Future<String> uploadSignature({
    required String companyId,
    required String claimId,
    required File signatureFile,
    required String signatureType, // 'customer' or 'driver'
  }) async {
    try {
      final path = 'companies/$companyId/claims/$claimId/signatures/${signatureType}_signature.png';
      final ref = _storage.ref().child(path);
      await ref.putFile(signatureFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading signature: $e');
      rethrow;
    }
  }

  /// Get current GPS location
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting location: $e');
      return {};
    }
  }

  /// Approve current level in approval chain
  Future<void> approveClaimLevel({
    required String companyId,
    required String claimId,
    required String userId,
    required String userName,
    required String userRole,
    String? notes,
    String? signatureUrl,
  }) async {
    try {
      final claim = await getClaim(companyId, claimId);
      if (claim == null) throw Exception('Claim not found');

      if (claim.currentApprovalLevel >= claim.approvalChain.length) {
        throw Exception('No pending approvals');
      }

      // Update current approval level
      final updatedApprovalChain = List<ApprovalLevel>.from(claim.approvalChain);
      updatedApprovalChain[claim.currentApprovalLevel] = updatedApprovalChain[claim.currentApprovalLevel].copyWith(
        userId: userId,
        userName: userName,
        actionDate: DateTime.now(),
        notes: notes,
        approved: true,
        signatureUrl: signatureUrl,
      );

      // Move to next level or mark as approved
      final newLevel = claim.currentApprovalLevel + 1;
      final newStatus = newLevel >= claim.approvalChain.length
          ? ClaimStatus.approved
          : _getStatusForApprovalLevel(newLevel);

      final updatedClaim = claim.copyWith(
        approvalChain: updatedApprovalChain,
        currentApprovalLevel: newLevel,
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      await updateClaim(companyId, updatedClaim);

      // Add to history
      await updateClaimStatus(
        companyId: companyId,
        claimId: claimId,
        newStatus: newStatus,
        userId: userId,
        userName: userName,
        notes: notes ?? 'Approved at ${updatedApprovalChain[claim.currentApprovalLevel].role} level',
      );
    } catch (e) {
      print('Error approving claim: $e');
      rethrow;
    }
  }

  /// Reject claim
  Future<void> rejectClaim({
    required String companyId,
    required String claimId,
    required String userId,
    required String userName,
    required String reason,
  }) async {
    try {
      await updateClaimStatus(
        companyId: companyId,
        claimId: claimId,
        newStatus: ClaimStatus.rejected,
        userId: userId,
        userName: userName,
        notes: reason,
      );
    } catch (e) {
      print('Error rejecting claim: $e');
      rethrow;
    }
  }

  /// Resolve claim
  Future<void> resolveClaim({
    required String companyId,
    required String claimId,
    required String userId,
    required String userName,
    required ClaimResolution resolution,
    String? resolutionNotes,
    String? creditNoteNumber,
    String? debitNoteNumber,
  }) async {
    try {
      final claim = await getClaim(companyId, claimId);
      if (claim == null) throw Exception('Claim not found');

      final updatedClaim = claim.copyWith(
        status: ClaimStatus.resolved,
        resolution: resolution,
        resolutionNotes: resolutionNotes,
        resolvedBy: userId,
        resolvedByName: userName,
        resolvedAt: DateTime.now(),
        creditNoteNumber: creditNoteNumber,
        debitNoteNumber: debitNoteNumber,
        updatedAt: DateTime.now(),
      );

      await updateClaim(companyId, updatedClaim);

      await updateClaimStatus(
        companyId: companyId,
        claimId: claimId,
        newStatus: ClaimStatus.resolved,
        userId: userId,
        userName: userName,
        notes: resolutionNotes ?? 'Claim resolved: ${resolution.name}',
      );
    } catch (e) {
      print('Error resolving claim: $e');
      rethrow;
    }
  }

  /// Close claim
  Future<void> closeClaim({
    required String companyId,
    required String claimId,
    required String userId,
    required String userName,
    String? notes,
  }) async {
    try {
      await updateClaimStatus(
        companyId: companyId,
        claimId: claimId,
        newStatus: ClaimStatus.closed,
        userId: userId,
        userName: userName,
        notes: notes ?? 'Claim closed',
      );
    } catch (e) {
      print('Error closing claim: $e');
      rethrow;
    }
  }

  /// Generate next claim ID
  Future<String> generateClaimId(String companyId) async {
    try {
      // Get company settings for prefix
      final settingsDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('claims')
          .get();

      final settings = settingsDoc.exists
          ? CompanyClaimSettings.fromMap(settingsDoc.data()!)
          : CompanyClaimSettings(companyId: companyId);

      final prefix = settings.claimIdPrefix;
      final year = DateTime.now().year;

      // Get counter for this year
      final counterRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claimCounters')
          .doc(year.toString());

      final result = await _firestore.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        int nextNumber;
        if (!counterDoc.exists) {
          nextNumber = settings.claimIdStartNumber;
          transaction.set(counterRef, {'count': nextNumber});
        } else {
          nextNumber = (counterDoc.data()?['count'] ?? 0) + 1;
          transaction.update(counterRef, {'count': nextNumber});
        }

        return nextNumber;
      });

      // Format: CLM-2025-0001
      return '$prefix-$year-${result.toString().padLeft(4, '0')}';
    } catch (e) {
      print('Error generating claim ID: $e');
      // Fallback to timestamp-based ID
      return 'CLM-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Check if auto-approval applies
  Future<bool> shouldAutoApprove(
    CompanyClaimSettings settings,
    ClaimType type,
    double? amount,
  ) async {
    return settings.shouldAutoApprove(type, amount);
  }

  /// Calculate evidence quality score (1-10)
  int calculateEvidenceQualityScore(Claim claim) {
    int score = 0;

    // Photos (max 4 points)
    if (claim.photoUrls.length >= 3) {
      score += 4;
    } else if (claim.photoUrls.length >= 2) {
      score += 3;
    } else if (claim.photoUrls.isNotEmpty) {
      score += 2;
    }

    // GPS location (2 points)
    if (claim.gpsLocation.isNotEmpty) {
      score += 2;
    }

    // Customer signature (2 points)
    if (claim.customerSignatureUrl != null) {
      score += 2;
    }

    // Filed at delivery (immediate - 1 point)
    if (claim.filingContext == ClaimFilingContext.atDeliverySite) {
      score += 1;
    }

    // Fresh filing (within 24 hours - 1 point)
    final hoursSinceFiled = DateTime.now().difference(claim.createdAt).inHours;
    if (hoursSinceFiled <= 24) {
      score += 1;
    }

    return score.clamp(0, 10);
  }

  /// Detect fraud patterns
  Future<bool> detectFraudPattern({
    required String companyId,
    required String? driverId,
    required String? customerId,
    required double? claimAmount,
  }) async {
    try {
      final settingsDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('claims')
          .get();

      if (!settingsDoc.exists) return false;

      final settings = CompanyClaimSettings.fromMap(settingsDoc.data()!);
      if (!settings.enableFraudDetection) return false;

      // Check amount threshold
      if (settings.fraudThresholdAmount != null && 
          claimAmount != null && 
          claimAmount > settings.fraudThresholdAmount!) {
        return true;
      }

      // Check frequency threshold (claims per month)
      if (settings.fraudThresholdFrequency != null) {
        final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
        
        Query query = _firestore
            .collection('companies')
            .doc(companyId)
            .collection('claims')
            .where('createdAt', isGreaterThan: oneMonthAgo.toIso8601String());

        if (driverId != null) {
          query = query.where('driverId', isEqualTo: driverId);
        }
        if (customerId != null) {
          query = query.where('customerId', isEqualTo: customerId);
        }

        final snapshot = await query.get();
        if (snapshot.docs.length >= settings.fraudThresholdFrequency!) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error detecting fraud: $e');
      return false;
    }
  }

  /// Detect recurring claim patterns
  Future<String?> detectRecurringPattern({
    required String companyId,
    required String customerId,
    required ClaimType type,
  }) async {
    try {
      final settingsDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('claims')
          .get();

      if (!settingsDoc.exists) return null;

      final settings = CompanyClaimSettings.fromMap(settingsDoc.data()!);
      if (!settings.enablePatternDetection) return null;

      // Get recent claims of same type from same customer
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final snapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .where('customerId', isEqualTo: customerId)
          .where('type', isEqualTo: type.name)
          .where('createdAt', isGreaterThan: threeMonthsAgo.toIso8601String())
          .get();

      if (snapshot.docs.length >= (settings.recurringClaimThreshold ?? 3)) {
        // Create pattern group ID
        return 'PATTERN-${customerId.substring(0, 8)}-${type.name}';
      }

      return null;
    } catch (e) {
      print('Error detecting pattern: $e');
      return null;
    }
  }

  /// Get status for approval level
  ClaimStatus _getStatusForApprovalLevel(int level) {
    // Map approval level to appropriate status
    if (level == 0) return ClaimStatus.pendingReview;
    if (level == 1) return ClaimStatus.pendingApproval;
    if (level == 2) return ClaimStatus.pendingSecondApproval;
    if (level == 3) return ClaimStatus.pendingProcessing;
    if (level >= 4) return ClaimStatus.pendingFinalReview;
    return ClaimStatus.pendingReview;
  }

  /// Get analytics data
  Future<Map<String, dynamic>> getClaimAnalytics({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims');

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final snapshot = await query.get();
      final claims = snapshot.docs.map((doc) => Claim.fromFirestore(doc)).toList();

      // Calculate analytics
      final totalClaims = claims.length;
      final totalAmount = claims.fold<double>(0, (sum, claim) => sum + (claim.claimAmount ?? 0));
      
      final claimsByType = <ClaimType, int>{};
      final claimsByStatus = <ClaimStatus, int>{};
      final claimsByDriver = <String, int>{};
      final claimsByCustomer = <String, int>{};
      
      for (var claim in claims) {
        claimsByType[claim.type] = (claimsByType[claim.type] ?? 0) + 1;
        claimsByStatus[claim.status] = (claimsByStatus[claim.status] ?? 0) + 1;
        claimsByDriver[claim.driverName] = (claimsByDriver[claim.driverName] ?? 0) + 1;
        claimsByCustomer[claim.customerName] = (claimsByCustomer[claim.customerName] ?? 0) + 1;
      }

      final resolvedClaims = claims.where((c) => c.status == ClaimStatus.resolved || c.status == ClaimStatus.closed).toList();
      final avgResolutionTime = resolvedClaims.isEmpty
          ? 0
          : resolvedClaims.fold<int>(0, (sum, claim) {
              if (claim.resolvedAt != null) {
                return sum + claim.resolvedAt!.difference(claim.createdAt).inHours;
              }
              return sum;
            }) / resolvedClaims.length;

      return {
        'totalClaims': totalClaims,
        'totalAmount': totalAmount,
        'claimsByType': claimsByType.map((k, v) => MapEntry(k.name, v)),
        'claimsByStatus': claimsByStatus.map((k, v) => MapEntry(k.name, v)),
        'claimsByDriver': claimsByDriver,
        'claimsByCustomer': claimsByCustomer,
        'avgResolutionTimeHours': avgResolutionTime,
        'avgClaimAmount': totalClaims > 0 ? totalAmount / totalClaims : 0,
      };
    } catch (e) {
      print('Error getting analytics: $e');
      return {};
    }
  }

  /// Get company claim settings
  Future<CompanyClaimSettings> getCompanySettings(String companyId) async {
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('claims')
          .get();

      if (doc.exists) {
        return CompanyClaimSettings.fromFirestore(doc);
      } else {
        // Return default settings if none exist
        final defaultSettings = CompanyClaimSettings(companyId: companyId);
        // Save default settings
        await updateCompanySettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      print('Error getting company settings: $e');
      // Return default settings on error
      return CompanyClaimSettings(companyId: companyId);
    }
  }

  /// Update company claim settings
  Future<void> updateCompanySettings(CompanyClaimSettings settings) async {
    try {
      await _firestore
          .collection('companies')
          .doc(settings.companyId)
          .collection('settings')
          .doc('claims')
          .set(settings.toMap());
    } catch (e) {
      print('Error updating company settings: $e');
      rethrow;
    }
  }

  // ===== Delayed Evidence Submission Methods =====

  /// Create a claim without requiring evidence upfront
  /// This allows creating claims and uploading evidence later
  Future<String> createClaimWithoutEvidence(
    String companyId,
    Claim claim,
  ) async {
    try {
      final claimRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .doc();

      final claimData = claim.copyWith(
        id: claimRef.id,
        evidenceStatus: 'pending', // Set to pending for evidence
      ).toMap();

      await claimRef.set(claimData);
      print('Claim created without evidence: ${claimRef.id}');
      return claimRef.id;
    } catch (e) {
      print('Error creating claim without evidence: $e');
      rethrow;
    }
  }

  /// Upload evidence (photos, signatures, documents) to an existing claim
  Future<void> uploadEvidenceToClaim(
    String companyId,
    String claimId,
    List<dynamic>? photos,
    dynamic signature,
    List<dynamic>? documents,
  ) async {
    try {
      final claimRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .doc(claimId);

      // Get current claim
      final doc = await claimRef.get();
      if (!doc.exists) {
        throw Exception('Claim not found');
      }

      final claim = Claim.fromFirestore(doc);
      final photoUrls = List<String>.from(claim.photoUrls);
      bool hasSignature = claim.hasSignature;
      bool hasDocuments = claim.hasDocuments;
      int photoCount = claim.photoCount;

      // Upload photos - accepts normalized maps {bytes, filename} or XFile/File
      if (photos != null && photos.isNotEmpty) {
        for (int i = 0; i < photos.length; i++) {
          try {
            // Extract bytes and filename from normalized map (preferred) or read from XFile/File
            Uint8List? bytes;
            String fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

            if (photos[i] is Map && photos[i]['bytes'] != null) {
              final map = photos[i] as Map;
              bytes = map['bytes'] as Uint8List;
              if (map['filename'] != null) fileName = map['filename'] as String;
            }

            final storageRef = _storage.ref().child(
              'companies/$companyId/claims/$claimId/photos/$fileName',
            );

            if (kIsWeb) {
              // Web: use putData with bytes (required for web compatibility)
              if (bytes == null) {
                if (photos[i] is XFile) {
                  bytes = await (photos[i] as XFile).readAsBytes();
                } else {
                  bytes = await (photos[i] as dynamic).readAsBytes() as Uint8List;
                }
              }
              await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
            } else {
              // Mobile/Desktop: prefer putData if bytes provided, else putFile
              if (bytes != null) {
                await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
              } else if (photos[i] is File) {
                await storageRef.putFile(photos[i] as File);
              } else if (photos[i] is XFile) {
                await storageRef.putFile(File((photos[i] as XFile).path));
              } else {
                final dynamic p = photos[i];
                if (p.path != null) {
                  await storageRef.putFile(File(p.path));
                } else {
                  throw Exception('Unsupported photo type: ${p.runtimeType}');
                }
              }
            }

            final url = await storageRef.getDownloadURL();
            photoUrls.add(url);
            photoCount++;
          } catch (e) {
            print('[ClaimService] Error uploading photo $i: $e');
          }
        }
      }

      // Upload signature - accepts normalized map {bytes, filename} or XFile/File
      if (signature != null) {
        try {
          Uint8List? bytes;
          if (signature is Map && signature['bytes'] != null) {
            bytes = signature['bytes'] as Uint8List;
          }

          final storageRef = _storage.ref().child(
            'companies/$companyId/claims/$claimId/signature_${DateTime.now().millisecondsSinceEpoch}.png',
          );

          if (kIsWeb) {
            if (bytes == null) {
              if (signature is XFile) {
                bytes = await signature.readAsBytes();
              } else {
                bytes = await (signature as dynamic).readAsBytes() as Uint8List;
              }
            }
            await storageRef.putData(bytes, SettableMetadata(contentType: 'image/png'));
          } else {
            if (bytes != null) {
              await storageRef.putData(bytes, SettableMetadata(contentType: 'image/png'));
            } else if (signature is File) {
              await storageRef.putFile(signature);
            } else if (signature is XFile) {
              await storageRef.putFile(File(signature.path));
            } else {
              final dynamic s = signature;
              if (s.path != null) {
                await storageRef.putFile(File(s.path));
              } else {
                throw Exception('Unsupported signature type: ${s.runtimeType}');
              }
            }
          }

          final url = await storageRef.getDownloadURL();
          await claimRef.update({'customerSignatureUrl': url});
          hasSignature = true;
        } catch (e) {
          print('Error uploading signature: $e');
        }
      }

      // Upload documents
      if (documents != null && documents.isNotEmpty) {
        for (int i = 0; i < documents.length; i++) {
          try {
            // Get filename safely for both web and mobile
            String fileName = 'document_$i';
            if (documents[i] is XFile) {
              final xfile = documents[i] as XFile;
              fileName = xfile.name;
            } else if (documents[i] is File && !kIsWeb) {
              final file = documents[i] as File;
              fileName = file.path.split('/').last;
            }
            
            final storageRef = _storage.ref().child(
              'companies/$companyId/claims/$claimId/documents/${DateTime.now().millisecondsSinceEpoch}_$fileName',
            );
            
            if (kIsWeb) {
              Uint8List bytes;
              if (documents[i] is XFile) {
                bytes = await (documents[i] as XFile).readAsBytes();
              } else if (documents[i] is File) {
                bytes = await (documents[i] as File).readAsBytes();
              } else {
                final dynamic d = documents[i];
                bytes = await d.readAsBytes();
              }
              await storageRef.putData(bytes);
            } else {
              if (documents[i] is File) {
                await storageRef.putFile(documents[i] as File);
              } else if (documents[i] is XFile) {
                await storageRef.putFile(File((documents[i] as XFile).path));
              } else {
                final dynamic d = documents[i];
                if (d.path != null) {
                  await storageRef.putFile(File(d.path));
                } else {
                  throw Exception('Unsupported document type: ${d.runtimeType}');
                }
              }
            }
            
            // We could track document URLs if needed
          } catch (e) {
            print('Error uploading document $i: $e');
          }
        }
        hasDocuments = true;
      }

      // Update claim with evidence info
      await claimRef.update({
        'photoUrls': photoUrls,
        'photoCount': photoCount,
        'hasSignature': hasSignature,
        'hasDocuments': hasDocuments,
        'evidenceStatus': 'received',
        'evidenceReceivedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error uploading evidence: $e');
      rethrow;
    }
  }

  /// Get all claims pending evidence for a company
  Stream<List<Claim>> getClaimsPendingEvidence(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('claims')
        .where('evidenceStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            final claims = snapshot.docs
                .map((doc) {
                  return Claim.fromFirestore(doc);
                })
                .toList();
            return claims;
          } catch (e) {
            print('[ClaimService] ERROR mapping claims: $e');
            return [];
          }
        });
  }

  /// Update evidence status for a claim
  /// Status values: pending, received, complete
  Future<void> updateEvidenceStatus(
    String companyId,
    String claimId,
    String status,
  ) async {
    try {
      final validStatuses = ['pending', 'received', 'complete'];
      if (!validStatuses.contains(status)) {
        throw Exception('Invalid evidence status: $status');
      }

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .doc(claimId)
          .update({
            'evidenceStatus': status,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      print('Evidence status updated to $status for claim $claimId');
    } catch (e) {
      print('Error updating evidence status: $e');
      rethrow;
    }
  }
}

