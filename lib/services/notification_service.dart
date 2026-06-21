import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey;
import '../screens/admin/claim_details_screen.dart';
import '../screens/driver/delivery_details_screen.dart';
import '../models/delivery_model.dart';
import '../models/claim_model.dart';

/// Notification Service for handling FCM push notifications
/// Manages device tokens, sends notifications, and handles incoming messages
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize Firebase Messaging
  Future<void> initialize(String userId) async {
    try {
      debugPrint('🔔 Initializing NotificationService for user: $userId');

      // Request permission (iOS/Android) - may hang on web, so wrap in try-catch
      debugPrint('📋 Requesting notification permission...');
      NotificationSettings? settings;
      try {
        settings = await _requestPermission().timeout(
          const Duration(seconds: 5),
        );
        debugPrint('✅ Permission status: ${settings.authorizationStatus}');
        
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('⚠️ Notification permission denied');
          return;
        }
      } catch (e) {
        debugPrint('⏱️ Permission request timeout or error: $e');
        debugPrint('ℹ️ Continuing without explicit permission (web platform)');
        // Continue anyway - web platform may not need explicit permission request
      }

      // Get FCM token with timeout
      debugPrint('🔑 Getting FCM token...');
      try {
        _fcmToken = await _messaging.getToken().timeout(
          const Duration(seconds: 10),
        );
        debugPrint('📱 FCM Token: $_fcmToken');

        if (_fcmToken != null) {
          await _saveTokenToFirestore(userId, _fcmToken!);
        }
      } catch (e) {
        debugPrint('⏱️ FCM token request timeout or error: $e');
        if (kIsWeb) {
          debugPrint('ℹ️ Web platform: Token retrieval failed. Service worker may not be registered.');
          debugPrint('ℹ️ Notifications will not work on this platform until service worker is fixed.');
        }
        // Continue without token - app will still work, just no notifications
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _saveTokenToFirestore(userId, newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle initial message if app was opened from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('✅ NotificationService initialized (token: ${_fcmToken != null ? "available" : "not available"})');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing NotificationService: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't throw - allow app to continue even if notifications fail
    }
  }

  /// Request notification permissions
  Future<NotificationSettings> _requestPermission() async {
    return await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      // Diagnostic: log current auth state and ensure user doc exists
      final authUser = FirebaseAuth.instance.currentUser;
      debugPrint('💡 _saveTokenToFirestore: targetUserId=$userId authUid=${authUser?.uid}');

      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        debugPrint('💡 userDoc.exists=${userDoc.exists} userDoc.data=${userDoc.data()}');
      } catch (readErr) {
        debugPrint('⚠️ Could not read users/$userId before write: $readErr');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(token)
          .set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'lastActive': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('💾 FCM token saved to Firestore (users/$userId/devices/$token)');
    } catch (e) {
      debugPrint('❌ Error saving token to Firestore: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Show in-app notification when app is in foreground
    if (navigatorKey.currentContext != null) {
      final context = navigatorKey.currentContext!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.notification?.title ?? 'Notification',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (message.notification?.body != null)
                Text(message.notification!.body!),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _handleNotificationTap(message),
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.blue.shade700,
        ),
      );
    }
  }

  /// Handle notification tap (when user taps on notification)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped');
    debugPrint('Data: ${message.data}');

    final type = message.data['type'];
    final deliveryId = message.data['deliveryId'];
    
    debugPrint('Notification type: $type');
    debugPrint('Delivery ID: $deliveryId');

    // Navigate based on notification type
    if (navigatorKey.currentContext != null) {
      switch (type) {
        case 'delivery_assigned':
          // Navigate driver to delivery details
          debugPrint('📍 Navigating to driver delivery details: $deliveryId');
          _navigateToDriverDeliveryDetails(deliveryId);
          break;
          
        case 'delivery_status_change':
          // Navigate admin to delivery management
          debugPrint('📍 Navigating to admin delivery details: $deliveryId');
          _navigateToAdminDeliveryManagement();
          break;
          
        case 'pod_completed':
          // Navigate to POD viewer
          debugPrint('📍 Navigating to POD viewer');
          navigatorKey.currentState?.pushNamed('/admin/pods');
          break;
          
        case 'claim_filed':
        case 'claim_updated':
        case 'claim_status_changed':
          // Navigate to claim details
          final claimId = message.data['claimId'];
          final companyId = message.data['companyId'];
          debugPrint('📍 Navigating to claim details: $claimId');
          _navigateToClaimDetails(claimId, companyId);
          break;
          
        default:
          debugPrint('⚠️ Unknown notification type: $type');
      }
    } else {
      debugPrint('⚠️ Navigator context not available');
    }
  }
  
  /// Navigate to driver delivery details
  Future<void> _navigateToDriverDeliveryDetails(String? deliveryId) async {
    if (deliveryId == null || navigatorKey.currentContext == null) return;
    
    try {
      // Fetch delivery document
      final deliveryDoc = await _firestore
          .collection('deliveries')
          .doc(deliveryId)
          .get();
      
      if (!deliveryDoc.exists || navigatorKey.currentContext == null) return;
      
      // Import Delivery model to convert document
      final delivery = Delivery.fromFirestore(deliveryDoc);
      
      final context = navigatorKey.currentContext!;
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryDetailsScreen(delivery: delivery),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to delivery details: $e');
    }
  }
  
  /// Navigate to claim details
  Future<void> _navigateToClaimDetails(String? claimId, String? companyId) async {
    if (claimId == null || companyId == null || navigatorKey.currentContext == null) return;
    
    try {
      // Fetch claim document
      final claimDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .doc(claimId)
          .get();
      
      if (!claimDoc.exists || navigatorKey.currentContext == null) return;
      
      // Convert document to Claim model
      final claim = Claim.fromFirestore(claimDoc);
      
      final context = navigatorKey.currentContext!;
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClaimDetailsScreen(claim: claim),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to claim details: $e');
    }
  }
  
  /// Navigate to admin delivery management
  void _navigateToAdminDeliveryManagement() {
    navigatorKey.currentState?.pushNamed('/admin/deliveries');
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      // Topic subscriptions are not supported on web
      // Web clients should use token-based targeting instead
      if (kIsWeb) {
        debugPrint('ℹ️ Topic subscriptions not supported on web - using token-based targeting');
        return;
      }
      
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      // Topic subscriptions are not supported on web
      if (kIsWeb) {
        debugPrint('ℹ️ Topic subscriptions not supported on web');
        return;
      }
      
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken(String userId) async {
    try {
      if (_fcmToken != null) {
        // Remove token from Firestore
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .doc(_fcmToken)
            .delete();

        // Delete FCM token
        await _messaging.deleteToken();
        _fcmToken = null;

        debugPrint('🗑️ FCM token deleted');
      }
    } catch (e) {
      debugPrint('❌ Error deleting token: $e');
    }
  }

  /// Send notification to user (to be called from Cloud Functions)
  /// This is a placeholder - actual sending will be done server-side
  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // This would typically be done via Cloud Functions
    // For now, we'll create a notification document that triggers Cloud Function
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      debugPrint('📤 Notification queued for user: $userId');
    } catch (e) {
      debugPrint('❌ Error queuing notification: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}
