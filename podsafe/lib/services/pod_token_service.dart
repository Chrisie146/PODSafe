import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pod_access_token.dart';
import '../utils/app_logger.dart';

/// Service for managing POD access tokens
class PODTokenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Create or get existing token for a delivery
  Future<PODAccessToken> createToken(
    String deliveryId, {
    int expiryDays = 90, // Default 90 days expiry
  }) async {
    try {
      // Check if token already exists
      final existingTokens = await _firestore
          .collection('pod_tokens')
          .where('deliveryId', isEqualTo: deliveryId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      if (existingTokens.docs.isNotEmpty) {
        final existingToken = PODAccessToken.fromFirestore(existingTokens.docs.first);
        if (existingToken.isValid) {
          AppLogger.info('Using existing valid token for delivery $deliveryId');
          return existingToken;
        }
      }
      
      // Create new token
      final token = PODAccessToken.create(deliveryId, expiryDays: expiryDays);
      
      // Save to Firestore
      await _firestore
          .collection('pod_tokens')
          .doc(token.token)
          .set(token.toFirestore());
      
      AppLogger.info('Created new token for delivery $deliveryId');
      return token;
      
    } catch (e) {
      AppLogger.error('Failed to create token for delivery $deliveryId', error: e);
      rethrow;
    }
  }
  
  /// Validate a token and return delivery ID if valid
  Future<String?> validateToken(String token) async {
    try {
      final doc = await _firestore
          .collection('pod_tokens')
          .doc(token)
          .get();
      
      if (!doc.exists) {
        AppLogger.warning('Token not found: $token');
        return null;
      }
      
      final tokenData = PODAccessToken.fromFirestore(doc);
      
      if (!tokenData.isValid) {
        AppLogger.warning('Token is invalid or expired: $token');
        return null;
      }
      
      // Increment access count
      await _incrementAccessCount(token);
      
      return tokenData.deliveryId;
      
    } catch (e) {
      AppLogger.error('Failed to validate token: $token', error: e);
      return null;
    }
  }
  
  /// Get token by delivery ID
  Future<PODAccessToken?> getTokenByDeliveryId(String deliveryId) async {
    try {
      final tokens = await _firestore
          .collection('pod_tokens')
          .where('deliveryId', isEqualTo: deliveryId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      if (tokens.docs.isEmpty) return null;
      
      return PODAccessToken.fromFirestore(tokens.docs.first);
      
    } catch (e) {
      AppLogger.error('Failed to get token for delivery $deliveryId', error: e);
      return null;
    }
  }
  
  /// Increment access count
  Future<void> _incrementAccessCount(String token) async {
    try {
      await _firestore
          .collection('pod_tokens')
          .doc(token)
          .update({
        'accessCount': FieldValue.increment(1),
        'lastAccessedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical error, just log it
      AppLogger.warning('Failed to increment access count for token: $token', error: e);
    }
  }
  
  /// Deactivate a token
  Future<void> deactivateToken(String token) async {
    try {
      await _firestore
          .collection('pod_tokens')
          .doc(token)
          .update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.info('Deactivated token: $token');
      
    } catch (e) {
      AppLogger.error('Failed to deactivate token: $token', error: e);
      rethrow;
    }
  }
  
  /// Deactivate all tokens for a delivery
  Future<void> deactivateAllTokensForDelivery(String deliveryId) async {
    try {
      final tokens = await _firestore
          .collection('pod_tokens')
          .where('deliveryId', isEqualTo: deliveryId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final batch = _firestore.batch();
      
      for (var doc in tokens.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      AppLogger.info('Deactivated ${tokens.docs.length} tokens for delivery $deliveryId');
      
    } catch (e) {
      AppLogger.error('Failed to deactivate tokens for delivery $deliveryId', error: e);
      rethrow;
    }
  }
  
  /// Clean up expired tokens (admin function)
  Future<int> cleanupExpiredTokens() async {
    try {
      final now = DateTime.now();
      final tokens = await _firestore
          .collection('pod_tokens')
          .where('isActive', isEqualTo: true)
          .get();
      
      int deactivated = 0;
      final batch = _firestore.batch();
      
      for (var doc in tokens.docs) {
        final token = PODAccessToken.fromFirestore(doc);
        if (!token.isValid) {
          batch.update(doc.reference, {
            'isActive': false,
            'deactivatedAt': Timestamp.fromDate(now),
          });
          deactivated++;
        }
      }
      
      await batch.commit();
      
      AppLogger.info('Cleaned up $deactivated expired tokens');
      return deactivated;
      
    } catch (e) {
      AppLogger.error('Failed to cleanup expired tokens', error: e);
      return 0;
    }
  }
}
