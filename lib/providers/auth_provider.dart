import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final Logger _logger = Logger();
  
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isDriver => _currentUser?.role == UserRole.driver;
  bool get isManager => _currentUser?.role == UserRole.manager;
  bool get isLogistics => _currentUser?.role == UserRole.logistics;
  bool get isAccountant => _currentUser?.role == UserRole.accountant;
  bool get isFilingClerk => _currentUser?.role == UserRole.filing_clerk;
  String? get companyId => _currentUser?.companyId;
  
  // Initialize auth state
  void initialize() {
    _authService.currentAppUser.listen((AppUser? user) {
      _currentUser = user;
      notifyListeners();
    });
  }
  
  // Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      AppUser? user = await _authService.signInWithEmailAndPassword(email, password);
      if (user != null) {
        _currentUser = user;
        
        // Initialize notifications for logged in user
        await _notificationService.initialize(user.id);
        
        // Subscribe to role-based topics
        if (user.role == UserRole.driver) {
          await _notificationService.subscribeToTopic('drivers');
          await _notificationService.subscribeToTopic('driver_${user.id}');
        } else if (user.role == UserRole.admin) {
          await _notificationService.subscribeToTopic('admins');
          await _notificationService.subscribeToTopic('company_${user.companyId}');
        }
        
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to sign in. Please check your credentials.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Create new user account
  Future<bool> createAccount({
    required String email,
    required String password,
    required String fullName,
    required String companyId,
    required UserRole role,
    String? phoneNumber,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      AppUser? user = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        companyId: companyId,
        role: role,
        phoneNumber: phoneNumber,
      );
      
      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Failed to create account.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    
    try {
      // Delete notification token before signing out
      if (_currentUser != null) {
        await _notificationService.deleteToken(_currentUser!.id);
      }
      
      await _authService.signOut();
      _currentUser = null;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
  
  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Update user profile
  Future<bool> updateProfile(AppUser updatedUser) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.updateUserProfile(updatedUser);
      _currentUser = updatedUser;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // Check if user is admin
  Future<bool> checkAdminStatus() async {
    try {
      return await _authService.isAdmin();
    } catch (e) {
      return false;
    }
  }
  
  // Refresh current user data
  Future<void> refreshUser() async {
    if (_currentUser != null) {
      try {
        AppUser? user = await _authService.getUserById(_currentUser!.id);
        if (user != null) {
          _currentUser = user;
          notifyListeners();
        }
      } catch (e) {
        _logger.e('Error refreshing user: $e');
      }
    }
  }
  
  // === ADMIN-ONLY USER MANAGEMENT METHODS ===
  
  /// Create user as admin (doesn't sign in the new user)
  /// Admin can create users with any role and set initial password
  /// NOTE: This will temporarily sign out the admin - they must re-login
  Future<bool> createUserAsAdmin({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
    String? adminEmail,
    String? adminPassword,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Ensure current user is admin
      if (_currentUser == null || _currentUser!.role != UserRole.admin) {
        throw Exception('Only administrators can create users');
      }
      
      final companyId = _currentUser!.companyId;
      
      await _authService.createUserAsAdmin(
        email: email,
        password: password,
        fullName: fullName,
        companyId: companyId,
        role: role,
        phoneNumber: phoneNumber,
      );
      
      // After creating user, admin is signed out
      // Re-authenticate the admin if credentials provided
      if (adminEmail != null && adminPassword != null) {
        await signIn(adminEmail, adminPassword);
      } else {
        // Clear current user since we're signed out
        _currentUser = null;
        notifyListeners();
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Update user details as admin
  /// Can change role, personal info, etc.
  Future<bool> updateUserAsAdmin(AppUser updatedUser) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Ensure current user is admin
      if (_currentUser == null || _currentUser!.role != UserRole.admin) {
        throw Exception('Only administrators can update users');
      }
      
      // Ensure user is in same company
      if (updatedUser.companyId != _currentUser!.companyId) {
        throw Exception('Cannot update users from other companies');
      }
      
      await _authService.updateUserProfile(updatedUser);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Toggle user active status (activate/deactivate)
  /// Does not delete user, just marks as inactive
  Future<bool> toggleUserStatus(String userId, bool isActive) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Ensure current user is admin
      if (_currentUser == null || _currentUser!.role != UserRole.admin) {
        throw Exception('Only administrators can change user status');
      }
      
      await _authService.toggleUserStatus(userId, isActive);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  /// Assign role to user (admin only)
  Future<bool> assignRole(String userId, UserRole role) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Ensure current user is admin
      if (_currentUser == null || _currentUser!.role != UserRole.admin) {
        throw Exception('Only administrators can assign roles');
      }
      
      await _authService.assignRole(userId, role);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
  
  // === END ADMIN METHODS ===
  
  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // Clear all data (used when signing out)
  void clearData() {
    _currentUser = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}