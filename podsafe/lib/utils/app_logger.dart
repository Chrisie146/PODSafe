import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Centralized logging utility for PODSafe
/// 
/// Usage:
/// ```dart
/// AppLogger.info('User logged in', data: {'userId': user.id});
/// AppLogger.error('Failed to save delivery', error: e, stackTrace: st);
/// AppLogger.debug('Processing claim', data: claim.toMap());
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    filter: _PODSafeLogFilter(),
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: _PODSafeLogOutput(),
  );

  /// Log verbose/trace messages (most detailed)
  static void verbose(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
    if (data != null) {
      _logger.t('Data: $data');
    }
  }

  /// Log debug messages (development only)
  static void debug(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    if (data != null) {
      _logger.d('Data: $data');
    }
  }

  /// Log informational messages
  static void info(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    if (data != null) {
      _logger.i('Data: $data');
    }
  }

  /// Log warning messages
  static void warning(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    if (data != null) {
      _logger.w('Data: $data');
    }
  }

  /// Log error messages
  static void error(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    if (data != null) {
      _logger.e('Data: $data');
    }
  }

  /// Log fatal/critical errors
  static void fatal(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    if (data != null) {
      _logger.f('Data: $data');
    }
  }

  // Convenience methods for common logging scenarios

  /// Log user authentication events
  static void auth(String event, {String? userId, Map<String, dynamic>? data}) {
    info('🔐 Auth: $event', data: {'userId': userId, ...?data});
  }

  /// Log delivery operations
  static void delivery(String operation, {String? deliveryId, Map<String, dynamic>? data}) {
    info('📦 Delivery: $operation', data: {'deliveryId': deliveryId, ...?data});
  }

  /// Log claim operations
  static void claim(String operation, {String? claimId, Map<String, dynamic>? data}) {
    info('📋 Claim: $operation', data: {'claimId': claimId, ...?data});
  }

  /// Log POD operations
  static void pod(String operation, {String? podId, Map<String, dynamic>? data}) {
    info('📄 POD: $operation', data: {'podId': podId, ...?data});
  }

  /// Log notification events
  static void notification(String event, {Map<String, dynamic>? data}) {
    info('🔔 Notification: $event', data: data);
  }

  /// Log API/network calls
  static void network(String endpoint, {String? method, int? statusCode, Map<String, dynamic>? data}) {
    info('🌐 Network: $method $endpoint', data: {'statusCode': statusCode, ...?data});
  }

  /// Log database operations
  static void database(String operation, {String? collection, Map<String, dynamic>? data}) {
    debug('💾 Database: $operation', data: {'collection': collection, ...?data});
  }

  /// Log performance metrics
  static void performance(String metric, {Duration? duration, Map<String, dynamic>? data}) {
    info('⚡ Performance: $metric', data: {'duration': duration?.inMilliseconds, ...?data});
  }
}

/// Custom log filter that respects environment settings
class _PODSafeLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In production, only log warnings and errors
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }

    // In debug mode, log everything except verbose (unless explicitly enabled)
    if (kDebugMode) {
      return event.level.index >= Level.debug.index;
    }

    // In profile mode, log info and above
    if (kProfileMode) {
      return event.level.index >= Level.info.index;
    }

    // Default: log everything
    return true;
  }
}

/// Custom log output that can be extended for remote logging
class _PODSafeLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // In debug mode, print to console
      if (kDebugMode) {
        // ignore: avoid_print
        print(line);
      }

      // TODO: In production, consider sending to remote logging service
      // if (kReleaseMode && event.level.index >= Level.error.index) {
      //   // Send to Crashlytics, Sentry, or custom logging service
      //   FirebaseCrashlytics.instance.log(line);
      // }
    }
  }
}

/// Specialized loggers for different modules

class AuthLogger {
  static void signIn(String email, {String? userId}) {
    AppLogger.auth('User signed in', userId: userId, data: {'email': email});
  }

  static void signOut(String userId) {
    AppLogger.auth('User signed out', userId: userId);
  }

  static void signUpAttempt(String email) {
    AppLogger.auth('Sign up attempt', data: {'email': email});
  }

  static void signUpSuccess(String userId, String email) {
    AppLogger.auth('Sign up successful', userId: userId, data: {'email': email});
  }

  static void signUpFailed(String email, dynamic error) {
    AppLogger.error('Sign up failed', error: error, data: {'email': email});
  }

  static void passwordResetRequested(String email) {
    AppLogger.auth('Password reset requested', data: {'email': email});
  }
}

class DeliveryLogger {
  static void created(String deliveryId, String customerName) {
    AppLogger.delivery('Delivery created', deliveryId: deliveryId, data: {'customerName': customerName});
  }

  static void statusChanged(String deliveryId, String fromStatus, String toStatus) {
    AppLogger.delivery(
      'Status changed',
      deliveryId: deliveryId,
      data: {'from': fromStatus, 'to': toStatus},
    );
  }

  static void assigned(String deliveryId, String driverId, String driverName) {
    AppLogger.delivery(
      'Assigned to driver',
      deliveryId: deliveryId,
      data: {'driverId': driverId, 'driverName': driverName},
    );
  }

  static void completed(String deliveryId, {String? podId}) {
    AppLogger.delivery('Delivery completed', deliveryId: deliveryId, data: {'podId': podId});
  }

  static void failed(String deliveryId, String reason) {
    AppLogger.warning('Delivery failed', data: {'deliveryId': deliveryId, 'reason': reason});
  }
}

class ClaimLogger {
  static void filed(String claimId, String type, String filingContext) {
    AppLogger.claim(
      'Claim filed',
      claimId: claimId,
      data: {'type': type, 'filingContext': filingContext},
    );
  }

  static void statusChanged(String claimId, String fromStatus, String toStatus) {
    AppLogger.claim(
      'Status changed',
      claimId: claimId,
      data: {'from': fromStatus, 'to': toStatus},
    );
  }

  static void approved(String claimId, String approvedBy) {
    AppLogger.claim('Claim approved', claimId: claimId, data: {'approvedBy': approvedBy});
  }

  static void rejected(String claimId, String rejectedBy, String reason) {
    AppLogger.claim(
      'Claim rejected',
      claimId: claimId,
      data: {'rejectedBy': rejectedBy, 'reason': reason},
    );
  }

  static void resolved(String claimId, String resolution) {
    AppLogger.claim('Claim resolved', claimId: claimId, data: {'resolution': resolution});
  }
}

class PODLogger {
  static void captured(String podId, String deliveryId) {
    AppLogger.pod('POD captured', podId: podId, data: {'deliveryId': deliveryId});
  }

  static void signatureAdded(String podId, String signatureType) {
    AppLogger.pod('Signature added', podId: podId, data: {'type': signatureType});
  }

  static void photoAdded(String podId, int photoCount) {
    AppLogger.pod('Photo added', podId: podId, data: {'totalPhotos': photoCount});
  }

  static void uploaded(String podId, String deliveryId) {
    AppLogger.pod('POD uploaded', podId: podId, data: {'deliveryId': deliveryId});
  }
}

class NotificationLogger {
  static void sent(String userId, String title, String type) {
    AppLogger.notification('Notification sent', data: {
      'userId': userId,
      'title': title,
      'type': type,
    });
  }

  static void received(String title, String type) {
    AppLogger.notification('Notification received', data: {
      'title': title,
      'type': type,
    });
  }

  static void tokenRefreshed(String userId) {
    AppLogger.notification('FCM token refreshed', data: {'userId': userId});
  }

  static void permissionGranted() {
    AppLogger.notification('Notification permission granted');
  }

  static void permissionDenied() {
    AppLogger.warning('Notification permission denied');
  }
}
