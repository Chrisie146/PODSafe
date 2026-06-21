import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Get current app user data
  Stream<AppUser?> get currentAppUser {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) return null;
      
      try {
        // Add a small delay for web platform to allow auth token to propagate
        await Future.delayed(const Duration(milliseconds: 100));
        
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          return AppUser.fromFirestore(doc);
        } else {
          return null;
        }
      } catch (e) {
        // If permission denied, the rules might not have propagated yet
        return null;
      }
    });
  }
  
  // Sign in with email and password
  Future<AppUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // Check if user document exists
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .get();
        
        if (doc.exists) {
          // Update last login time
          await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
          
          return AppUser.fromFirestore(doc);
        } else {
          // Create a basic user document if it doesn't exist
          // This handles cases where Firebase Auth user exists but Firestore doc doesn't
          AppUser newUser = AppUser(
            id: result.user!.uid,
            email: email,
            fullName: result.user!.displayName ?? email.split('@')[0],
            role: UserRole.driver, // Default role
            companyId: 'default-company', // Needs to be set by admin
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );
          
          await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .set(newUser.toFirestore());
          
          return newUser;
        }
      }
      return null;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }
  
  // Create new user account
  Future<AppUser?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String companyId,
    required UserRole role,
    String? phoneNumber,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // Create user document in Firestore
        AppUser newUser = AppUser(
          id: result.user!.uid,
          email: email,
          fullName: fullName,
          role: role,
          companyId: companyId,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        
        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(newUser.toFirestore());
        
        return newUser;
      }
      return null;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out');
    }
  }
  
  // Reset password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }
  
  // Get user by ID
  Future<AppUser?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile(AppUser user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .update(user.toFirestore());
    } catch (e) {
      throw Exception('Failed to update profile');
    }
  }
  
  // Check if user is admin
  Future<bool> isAdmin() async {
    try {
      if (currentUser == null) return false;
      
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      if (doc.exists) {
        AppUser user = AppUser.fromFirestore(doc);
        return user.role == UserRole.admin;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // === ADMIN-ONLY USER MANAGEMENT METHODS ===
  
  /// Create user as admin without signing in
  /// Uses Firebase Admin SDK pattern (Cloud Function recommended for production)
  /// For now, uses client SDK with re-authentication workaround
  Future<void> createUserAsAdmin({
    required String email,
    required String password,
    required String fullName,
    required String companyId,
    required UserRole role,
    String? phoneNumber,
  }) async {
    User? currentUser = _auth.currentUser;
    
    try {
      // Store current user's info before creating new user
      if (currentUser == null) {
        throw Exception('Must be logged in as admin to create users');
      }
      
      // Create the new user (this will sign out the admin temporarily)
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        final newUserId = userCredential.user!.uid;
        
        // Create user document in Firestore
        AppUser newUser = AppUser(
          id: newUserId,
          email: email,
          fullName: fullName,
          role: role,
          companyId: companyId,
          phoneNumber: phoneNumber,
          isActive: true,
          createdAt: DateTime.now(),
          lastLoginAt: null,
        );
        
        // Save to Firestore BEFORE signing out the new user
        await _firestore
            .collection('users')
            .doc(newUserId)
            .set(newUser.toFirestore());
        
        // Sign out the newly created user
        await _auth.signOut();
        
        // NOTE: Admin needs to manually re-authenticate after this
        // The UI should handle re-login or we need to store credentials
        // For production, use Cloud Functions to avoid this issue
      }
    } catch (e) {
      // Try to restore admin session if possible
      
      throw _handleAuthError(e);
    }
  }
  
  /// Toggle user active status
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'isActive': isActive,
      });
    } catch (e) {
      throw Exception('Failed to update user status');
    }
  }
  
  /// Assign role to user
  Future<void> assignRole(String userId, UserRole role) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'role': role.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('Failed to assign role');
    }
  }
  
  /// Get all users in a company
  Future<List<AppUser>> getUsersByCompany(String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => AppUser.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  // === END ADMIN METHODS ===
  
  // Handle authentication errors
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Invalid password.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return 'An unexpected error occurred.';
  }
}