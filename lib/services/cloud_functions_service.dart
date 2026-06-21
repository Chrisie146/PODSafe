import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service for calling Firebase Cloud Functions
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Create a new user via Cloud Function (Admin SDK)
  /// 
  /// This allows admins to create users without signing out.
  /// The Cloud Function uses Firebase Admin SDK which doesn't affect
  /// the current authentication session.
  /// 
  /// Parameters:
  /// - email: User's email address
  /// - password: User's password (min 6 characters)
  /// - name: User's full name
  /// - role: User role (admin, manager, driver)
  /// - isActive: Whether user is active (defaults to true)
  /// 
  /// Returns:
  /// - Map with 'uid' and 'email' of created user
  /// 
  /// Throws:
  /// - FirebaseFunctionsException on error
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    bool isActive = true,
  }) async {
    try {
      debugPrint('🔧 [Cloud Functions] Calling createUser function...');
      debugPrint('   Email: $email');
      debugPrint('   Name: $name');
      debugPrint('   Role: $role');

      final HttpsCallable callable = _functions.httpsCallable('createUser');
      
      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'isActive': isActive,
      });

      debugPrint('✅ [Cloud Functions] User created successfully');
      debugPrint('   UID: ${result.data['uid']}');

      return {
        'uid': result.data['uid'],
        'email': result.data['email'],
        'message': result.data['message'],
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [Cloud Functions] Error creating user: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');
      
      // Re-throw with user-friendly message
      throw _handleFunctionsError(e);
    } catch (e) {
      debugPrint('❌ [Cloud Functions] Unexpected error: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  /// Convert FirebaseFunctionsException to user-friendly error message
  Exception _handleFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return Exception('You must be logged in to create users');
      case 'permission-denied':
        return Exception('Only admins can create users');
      case 'invalid-argument':
        return Exception(e.message ?? 'Invalid input data');
      case 'already-exists':
        return Exception('A user with this email already exists');
      case 'not-found':
        return Exception('User account not found');
      default:
        return Exception(e.message ?? 'Failed to create user');
    }
  }
}
