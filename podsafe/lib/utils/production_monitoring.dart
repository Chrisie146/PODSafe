/// Production Monitoring Utility
/// 
/// Handles all monitoring and logging for production environment:
/// - Firebase Crashlytics error reporting
/// - Firebase Analytics event tracking
/// - Custom error logging
/// - Performance monitoring
/// 
/// Usage:
/// ```dart
/// // Log an error
/// await ProductionMonitoring.logError('Failed to upload photo', stackTrace);
/// 
/// // Track feature usage
/// await ProductionMonitoring.trackFeature('pod_capture');
/// 
/// // Log custom event
/// await ProductionMonitoring.logEvent('delivery_completed', {
///   'deliveryId': '123',
///   'duration': '45 minutes',
/// });
/// ```
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class ProductionMonitoring {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Initialize production monitoring
  /// Call this once in main() after Firebase initialization
  static Future<void> initialize() async {
    if (kDebugMode) {
      // In debug mode, print to console instead of sending to Crashlytics
      await _crashlytics.setCrashlyticsCollectionEnabled(false);
    } else {
      // In production, enable Crashlytics
      await _crashlytics.setCrashlyticsCollectionEnabled(true);
      await _analytics.setAnalyticsCollectionEnabled(true);
    }
    
    debugPrint('📊 Production monitoring initialized');
  }

  /// Log a non-fatal error
  /// These appear in Crashlytics but don't crash the app
  static Future<void> logError(
    String message, [
    StackTrace? stackTrace,
    Map<String, String>? context,
  ]) async {
    try {
      if (kDebugMode) {
        debugPrint('❌ ERROR: $message');
        if (stackTrace != null) {
          debugPrint('Stack trace: $stackTrace');
        }
      } else {
        await _crashlytics.recordError(
          Exception(message),
          stackTrace,
          fatal: false,
        );
      }
    } catch (e) {
      // Fail silently so logging errors don't crash the app
      debugPrint('Failed to log error: $e');
    }
  }

  /// Log a fatal error (app will likely crash)
  static Future<void> logFatalError(
    String message,
    StackTrace stackTrace, [
    Map<String, String>? context,
  ]) async {
    try {
      if (kDebugMode) {
        debugPrint('💀 FATAL: $message');
        debugPrint('Stack trace: $stackTrace');
      } else {
        await _crashlytics.recordError(
          Exception(message),
          stackTrace,
          fatal: true,
        );
      }
    } catch (e) {
      debugPrint('Failed to log fatal error: $e');
    }
  }

  /// Log a custom analytics event
  static Future<void> logEvent(
    String name,
    Map<String, dynamic> parameters,
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('📊 Event: $name');
        debugPrint('   Parameters: $parameters');
      } else {
        // Convert parameters to String values (Firebase requirement)
        final stringParams = parameters.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        
        await _analytics.logEvent(
          name: name,
          parameters: stringParams,
        );
      }
    } catch (e) {
      debugPrint('Failed to log event: $e');
    }
  }

  /// Track a feature being used
  static Future<void> trackFeature(String featureName) async {
    await logEvent('feature_used', {
      'feature': featureName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track user action
  static Future<void> trackAction(String action, Map<String, dynamic> details) async {
    await logEvent('user_action', {
      'action': action,
      ...details,
    });
  }

  /// Track workflow completion
  static Future<void> trackWorkflow(
    String workflowName,
    String status, // 'completed', 'failed', 'abandoned'
    int durationSeconds,
  ) async {
    await logEvent('workflow_$status', {
      'workflow': workflowName,
      'duration_seconds': durationSeconds,
    });
  }

  /// Track performance metric
  static Future<void> trackPerformance(
    String operation,
    int durationMilliseconds,
  ) async {
    if (durationMilliseconds > 1000) {
      // Slow operation - log as warning
      await logEvent('slow_operation', {
        'operation': operation,
        'duration_ms': durationMilliseconds,
      });
    } else {
      // Normal operation
      await logEvent('operation_completed', {
        'operation': operation,
        'duration_ms': durationMilliseconds,
      });
    }
  }

  /// Set user identifier for error tracking
  /// Call this after user logs in
  static Future<void> setUserId(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Failed to set user ID: $e');
    }
  }

  /// Clear user identifier
  /// Call this on logout
  static Future<void> clearUserId() async {
    try {
      await _crashlytics.setUserIdentifier('');
      // Analytics doesn't have clearUserId, so we just don't call setUserId again
    } catch (e) {
      debugPrint('Failed to clear user ID: $e');
    }
  }

  /// Add custom key-value data to crash reports
  static Future<void> setCustomKey(String key, String value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
    } catch (e) {
      debugPrint('Failed to set custom key: $e');
    }
  }

  /// Measure operation performance
  static Future<T> measurePerformance<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      await trackPerformance(operationName, stopwatch.elapsedMilliseconds);
    }
  }
}

/// Extension on exceptions for easy logging
extension ExceptionLogging on Exception {
  Future<void> logToProduction([StackTrace? stackTrace]) async {
    await ProductionMonitoring.logError(
      toString(),
      stackTrace,
    );
  }
}

/// Mixin for widgets that need error tracking
mixin MonitoredStatefulWidget {
  @protected
  Future<void> onErrorInWidget(String message, StackTrace stackTrace) async {
    await ProductionMonitoring.logError(message, stackTrace);
  }

  @protected
  Future<void> trackFeatureUsage(String featureName) async {
    await ProductionMonitoring.trackFeature(featureName);
  }
}
