import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for handling Firebase and app errors with user-friendly messages
class ErrorHandler {
  
  /// Check if error is a permission denied error
  static bool isPermissionDenied(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    if (error is String) {
      return error.toLowerCase().contains('permission-denied') ||
             error.toLowerCase().contains('insufficient permissions');
    }
    return false;
  }
  
  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to access this data. Please contact your administrator if you believe this is an error.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please check your internet connection and try again.';
        case 'not-found':
          return 'The requested data was not found.';
        case 'already-exists':
          return 'This item already exists.';
        case 'resource-exhausted':
          return 'Too many requests. Please try again in a moment.';
        case 'unauthenticated':
          return 'Your session has expired. Please log in again.';
        case 'cancelled':
          return 'Operation was cancelled.';
        case 'deadline-exceeded':
          return 'Request took too long. Please try again.';
        default:
          return 'An error occurred: ${error.message ?? error.code}';
      }
    }
    
    if (error is String) {
      if (isPermissionDenied(error)) {
        return 'You don\'t have permission to access this data. Please contact your administrator.';
      }
      return error;
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
  
  /// Show error snackbar with appropriate styling
  static void showErrorSnackBar(BuildContext context, dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = getUserFriendlyMessage(error);
    final isPermissionError = isPermissionDenied(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isPermissionError ? Icons.lock : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isPermissionError ? Colors.orange.shade700 : Colors.red.shade700,
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Show error dialog with detailed information
  static void showErrorDialog(BuildContext context, dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) {
    final message = getUserFriendlyMessage(error);
    final isPermissionError = isPermissionDenied(error);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isPermissionError ? Icons.lock : Icons.error_outline,
          color: isPermissionError ? Colors.orange : Colors.red,
          size: 48,
        ),
        title: Text(title ?? (isPermissionError ? 'Access Denied' : 'Error')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (isPermissionError) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your role may not have the required permissions for this action.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Widget builder for permission denied state
  static Widget buildPermissionDeniedWidget({
    String? message,
    VoidCallback? onContactAdmin,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Colors.orange.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'You don\'t have permission to view this content.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Why am I seeing this?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your user role doesn\'t have the required permissions to access this data. Contact your administrator to request access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (onContactAdmin != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onContactAdmin,
                icon: const Icon(Icons.email),
                label: const Text('Contact Administrator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Widget builder for empty state (no data but has permission)
  static Widget buildEmptyStateWidget({
    required String title,
    required String message,
    IconData icon = Icons.inbox,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
