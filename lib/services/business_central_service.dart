import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/bc_config.dart';

/// Business Central API Service
/// Handles authentication, API calls, and data synchronization with Microsoft Dynamics 365 Business Central
/// 
/// Uses Firebase Cloud Functions to bypass CORS restrictions on all platforms.
/// This allows BC integration to work on web, desktop, and mobile consistently.
class BusinessCentralService {
  static const String _tokenStorageKey = 'bc_access_token';
  static const String _refreshTokenStorageKey = 'bc_refresh_token';
  static const String _tokenExpiryStorageKey = 'bc_token_expiry';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String? _cachedAccessToken;
  DateTime? _cachedTokenExpiry;

  // ===================== CONFIGURATION =====================

  /// Get BC configuration for a company
  Future<BCConfig?> getConfig(String companyId) async {
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('integrations')
          .doc('businessCentral')
          .get();

      if (!doc.exists) {
        return null;
      }

      return BCConfig.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting BC config: $e');
      return null;
    }
  }

  /// Save BC configuration
  Future<void> saveConfig(BCConfig config) async {
    try {
      await _firestore
          .collection('companies')
          .doc(config.companyId)
          .collection('integrations')
          .doc('businessCentral')
          .set(config.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving BC config: $e');
      rethrow;
    }
  }

  /// Update sync status
  Future<void> updateSyncStatus(
    String companyId,
    String status, {
    String? error,
  }) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('integrations')
          .doc('businessCentral')
          .update({
        'lastSyncStatus': status,
        'lastSyncError': error,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating sync status: $e');
    }
  }

  // ===================== AUTHENTICATION =====================

  /// Authenticate with Business Central using Cloud Function
  /// This works on all platforms (web, desktop, mobile) by using server-side OAuth
  Future<String?> authenticate(BCConfig config, String clientSecret) async {
    if (!config.isConfigured) {
      throw Exception('BC configuration is incomplete');
    }

    try {
      debugPrint('Authenticating with BC via Cloud Function...');
      
      // Call Cloud Function to handle OAuth (bypasses CORS)
      final callable = _functions.httpsCallable('bcAuthenticate');
      final result = await callable.call({
        'companyId': config.companyId,
        'clientSecret': clientSecret,
      });

      final data = result.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final expiresIn = data['expiresIn'] as int;

      // Cache token
      _cachedAccessToken = accessToken;
      _cachedTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // Store securely
      await _secureStorage.write(key: _tokenStorageKey, value: accessToken);
      await _secureStorage.write(
        key: _tokenExpiryStorageKey,
        value: _cachedTokenExpiry!.toIso8601String(),
      );

      debugPrint('BC authentication successful via Cloud Function');
      return accessToken;
    } catch (e) {
      debugPrint('Error authenticating with BC via Cloud Function: $e');
      rethrow;
    }
  }

  /// Get valid access token (from cache or request new one)
  Future<String?> getAccessToken(BCConfig config, String clientSecret) async {
    // Check if we have a cached token that's still valid
    if (_cachedAccessToken != null && _cachedTokenExpiry != null) {
      if (_cachedTokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        return _cachedAccessToken;
      }
    }

    // Try to load from secure storage
    final storedToken = await _secureStorage.read(key: _tokenStorageKey);
    final storedExpiry = await _secureStorage.read(key: _tokenExpiryStorageKey);

    if (storedToken != null && storedExpiry != null) {
      final expiry = DateTime.parse(storedExpiry);
      if (expiry.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        _cachedAccessToken = storedToken;
        _cachedTokenExpiry = expiry;
        return storedToken;
      }
    }

    // Token expired or not found, get a new one
    return await authenticate(config, clientSecret);
  }

  /// Clear stored authentication tokens
  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedTokenExpiry = null;
    await _secureStorage.delete(key: _tokenStorageKey);
    await _secureStorage.delete(key: _refreshTokenStorageKey);
    await _secureStorage.delete(key: _tokenExpiryStorageKey);
  }

  // ===================== API CALLS =====================

  /// Make authenticated GET request to Business Central API
  /// Make authenticated GET request to Business Central API via Cloud Function
  Future<Map<String, dynamic>> get(
    BCConfig config,
    String endpoint,
    String clientSecret,
  ) async {
    try {
      final callable = _functions.httpsCallable('bcApiCall');
      final result = await callable.call({
        'companyId': config.companyId,
        'clientSecret': clientSecret,
        'method': 'GET',
        'endpoint': endpoint,
      });

      final data = result.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('BC GET request failed: $e');
      rethrow;
    }
  }

  /// Make authenticated POST request to Business Central API via Cloud Function
  Future<Map<String, dynamic>> post(
    BCConfig config,
    String endpoint,
    String clientSecret,
    Map<String, dynamic> body,
  ) async {
    try {
      final callable = _functions.httpsCallable('bcApiCall');
      final result = await callable.call({
        'companyId': config.companyId,
        'clientSecret': clientSecret,
        'method': 'POST',
        'endpoint': endpoint,
        'body': body,
      });

      final data = result.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('BC POST request failed: $e');
      rethrow;
    }
  }

  /// Make authenticated PATCH request to Business Central API via Cloud Function
  Future<Map<String, dynamic>> patch(
    BCConfig config,
    String endpoint,
    String clientSecret,
    Map<String, dynamic> body,
  ) async {
    try {
      final callable = _functions.httpsCallable('bcApiCall');
      final result = await callable.call({
        'companyId': config.companyId,
        'clientSecret': clientSecret,
        'method': 'PATCH',
        'endpoint': endpoint,
        'body': body,
      });

      final data = result.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('BC PATCH request failed: $e');
      rethrow;
    }
  }

  // ===================== TEST CONNECTION =====================

  /// Test connection to Business Central
  Future<bool> testConnection(BCConfig config, String clientSecret) async {
    try {
      debugPrint('Testing BC connection via Cloud Function...');
      
      // Call Cloud Function to test connection
      final callable = _functions.httpsCallable('bcTestConnection');
      final result = await callable.call({
        'companyId': config.companyId,
        'clientSecret': clientSecret,
      });

      final data = result.data as Map<String, dynamic>;
      final success = data['success'] as bool;
      final message = data['message'] as String;
      final companiesCount = data['companiesCount'] as int;
      
      debugPrint('BC connection test result: $message ($companiesCount companies)');
      return success;
    } catch (e) {
      debugPrint('BC connection test failed: $e');
      return false;
    }
  }

  // ===================== CUSTOMER SYNC =====================

  /// Fetch customers from Business Central
  Future<List<Map<String, dynamic>>> getCustomers(
    BCConfig config,
    String clientSecret, {
    int? top,
    int? skip,
  }) async {
    try {
      String endpoint = 'companies(${config.bcCompanyId})/customers';
      
      // Add OData query parameters
      final params = <String>[];
      if (top != null) params.add('\$top=$top');
      if (skip != null) params.add('\$skip=$skip');
      
      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final result = await get(config, endpoint, clientSecret);
      final customers = result['value'] as List<dynamic>? ?? [];
      
      return customers.map((c) => c as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching customers from BC: $e');
      rethrow;
    }
  }

  /// Sync a single customer to Firestore
  Future<void> syncCustomerToFirestore(
    String companyId,
    Map<String, dynamic> bcCustomer,
  ) async {
    try {
      final customerData = {
        'companyId': companyId,
        'name': bcCustomer['displayName'] ?? bcCustomer['number'] ?? 'Unknown',
        'email': bcCustomer['email'] ?? '',
        'phone': bcCustomer['phoneNumber'] ?? '',
        'address': bcCustomer['address']?['street'] ?? '',
        'city': bcCustomer['address']?['city'] ?? '',
        'postalCode': bcCustomer['address']?['postalCode'] ?? '',
        'accountNumber': bcCustomer['number'] ?? '',
        'customerNumber': bcCustomer['number'] ?? '',
        'bcCustomerId': bcCustomer['id'],
        'bcSyncedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Use BC customer number as document ID to prevent duplicates
      final customerId = bcCustomer['number'] as String? ?? bcCustomer['id'] as String;
      
      await _firestore
          .collection('customers')
          .doc('bc_$customerId')
          .set(customerData, SetOptions(merge: true));
      
      debugPrint('Synced customer: ${customerData['name']}');
    } catch (e) {
      debugPrint('Error syncing customer to Firestore: $e');
      rethrow;
    }
  }

  // ===================== SALES ORDER SYNC =====================

  /// Fetch sales orders from Business Central
  Future<List<Map<String, dynamic>>> getSalesOrders(
    BCConfig config,
    String clientSecret, {
    String? filter,
    int? top,
  }) async {
    try {
      String endpoint = 'companies(${config.bcCompanyId})/salesOrders';
      
      final params = <String>[];
      if (filter != null) params.add('\$filter=$filter');
      if (top != null) params.add('\$top=$top');
      params.add('\$expand=salesOrderLines');
      
      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final result = await get(config, endpoint, clientSecret);
      final orders = result['value'] as List<dynamic>? ?? [];
      
      return orders.map((o) => o as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching sales orders from BC: $e');
      rethrow;
    }
  }

  /// Update sales order status in Business Central
  Future<void> updateSalesOrderStatus(
    BCConfig config,
    String clientSecret,
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final endpoint = 'companies(${config.bcCompanyId})/salesOrders($orderId)';
      await patch(config, endpoint, clientSecret, updates);
      debugPrint('Updated BC sales order: $orderId');
    } catch (e) {
      debugPrint('Error updating sales order in BC: $e');
      rethrow;
    }
  }

  // ===================== DELIVERY STATUS SYNC =====================

  /// Update delivery status in Business Central
  /// This would typically update custom fields on the sales order
  Future<void> syncDeliveryStatus(
    BCConfig config,
    String clientSecret,
    String orderNumber,
    String status,
    DateTime? deliveredAt,
    String? driverName,
  ) async {
    try {
      // Note: You'll need to create custom fields in BC to store these
      // This is a placeholder for future implementation
      debugPrint('Would sync delivery status for order: $orderNumber');
      debugPrint('  Status: $status');
      debugPrint('  Delivered At: $deliveredAt');
      debugPrint('  Driver: $driverName');
      
      // TODO: Implement actual BC update when custom fields are configured
      // final updates = {
      //   'PODSafe_Status': status,
      //   'PODSafe_Delivered_DateTime': deliveredAt?.toIso8601String(),
      //   'PODSafe_Driver_Name': driverName,
      // };
      // await updateSalesOrderStatus(config, clientSecret, orderId, updates);
    } catch (e) {
      debugPrint('Error syncing delivery status to BC: $e');
      rethrow;
    }
  }

  // ===================== ITEMS/PRODUCTS SYNC =====================

  /// Fetch items from Business Central
  Future<List<Map<String, dynamic>>> getItems(
    BCConfig config,
    String clientSecret, {
    int? top,
  }) async {
    try {
      String endpoint = 'companies(${config.bcCompanyId})/items';
      
      if (top != null) {
        endpoint += '?\$top=$top';
      }

      final result = await get(config, endpoint, clientSecret);
      final items = result['value'] as List<dynamic>? ?? [];
      
      return items.map((i) => i as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching items from BC: $e');
      rethrow;
    }
  }

  // ===================== SYNC LOGS =====================

  /// Log sync operation
  Future<void> logSync(
    String companyId,
    String syncType,
    String status,
    int recordsProcessed, {
    List<String>? errors,
    int? durationMs,
  }) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('syncLogs')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'syncType': syncType,
        'status': status,
        'recordsProcessed': recordsProcessed,
        'errors': errors ?? [],
        'duration': durationMs,
      });
    } catch (e) {
      debugPrint('Error logging sync: $e');
    }
  }
}
