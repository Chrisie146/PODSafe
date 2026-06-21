import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'firebase_options_prod.dart' as prod_config;
import 'config/environment.dart';
import 'providers/auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/pod_provider.dart';
import 'providers/claim_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/pod_viewer_screen.dart';
import 'screens/admin/delivery_management_screen.dart';
import 'screens/admin/create_delivery_screen.dart';
import 'screens/admin/driver_management_screen.dart';
import 'screens/admin/analytics_dashboard_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/bc_settings_screen.dart';
import 'screens/admin/delivery_details_screen.dart';
import 'screens/admin/customer_import_screen.dart';
import 'models/delivery_model.dart';
import 'models/user_model.dart';
import 'screens/admin/live_tracking_screen.dart';
import 'screens/admin/item_catalog_desktop.dart';
import 'screens/public/public_pod_view_screen.dart';
import 'screens/external/upload_screen.dart';
import 'screens/driver/document_intake_screen.dart';
import 'screens/driver/driver_chat_screen.dart';
import 'screens/admin/chat_list_screen_desktop.dart';
import 'screens/setup/setup_wizard_screen.dart';
import 'services/notification_service.dart';
import 'services/ocr_parser.dart';
import 'services/pod_repository.dart';
import 'services/pod_controller.dart';
import 'widgets/chat_notification_overlay.dart';
import 'utils/theme.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Route handler for delivery details that fetches the delivery data
class DeliveryDetailsRoute extends StatefulWidget {
  final String deliveryId;

  const DeliveryDetailsRoute({super.key, required this.deliveryId});

  @override
  State<DeliveryDetailsRoute> createState() => _DeliveryDetailsRouteState();
}

class _DeliveryDetailsRouteState extends State<DeliveryDetailsRoute> {
  Delivery? _delivery;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDelivery();
  }

  Future<void> _loadDelivery() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .get();

      if (doc.exists) {
        _delivery = Delivery.fromFirestore(doc);
      } else {
        _error = 'Delivery not found';
      }
    } catch (e) {
      _error = 'Error loading delivery: $e';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _delivery == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Delivery Not Found'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? 'Delivery not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return DeliveryDetailsScreen(delivery: _delivery!);
  }
}

void main() async {
  // Run app in a protected zone to catch all errors
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Use path-based URLs instead of hash-based (#) for web
    if (kIsWeb) {
      usePathUrlStrategy();
    }
    
    // Initialize Firebase with environment-specific options
    try {
      final firebaseOptions = EnvironmentConfig.isProduction
          ? prod_config.DefaultFirebaseOptions.currentPlatform
          : DefaultFirebaseOptions.currentPlatform;
      
      await Firebase.initializeApp(
        options: firebaseOptions,
      );
      
      // Log which environment we're using
      if (kDebugMode) {
        print('🚀 PODSafe started in ${EnvironmentConfig.environmentName} mode');
        print('📱 Firebase Project: ${EnvironmentConfig.firebaseProjectId}');
      }
    } catch (e) {
      // Firebase already initialized (e.g., on Android with google-services.json)
      if (e.toString().contains('duplicate-app')) {
        debugPrint('Firebase already initialized');
      } else {
        rethrow;
      }
    }

    // Initialize Crashlytics (only for mobile platforms, not desktop)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
                    defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        // Pass all uncaught errors from the framework to Crashlytics
        FlutterError.onError = (errorDetails) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        };
        
        // Pass all uncaught asynchronous errors to Crashlytics
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };

        // Enable Crashlytics collection
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      } catch (e) {
        debugPrint('Crashlytics initialization failed: $e');
      }
    }
    
    // Initialize Analytics (web and mobile only)
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || 
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        FirebaseAnalytics analytics = FirebaseAnalytics.instance;
        await analytics.setAnalyticsCollectionEnabled(true);
      } catch (e) {
        debugPrint('Analytics initialization failed: $e');
      }
    }
    
    // Setup background message handler (mobile only)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
                    defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('Firebase Messaging initialization failed: $e');
      }
    }
    
    runApp(const PODSafeApp());
  }, (error, stack) {
    // Catch errors not handled by Flutter framework
    // Only use Crashlytics on mobile platforms
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
                    defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (e) {
        debugPrint('Failed to record error to Crashlytics: $e');
      }
    }
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

class PODSafeApp extends StatelessWidget {
  const PODSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        ChangeNotifierProvider(create: (_) => PODProvider()),
        ChangeNotifierProvider(create: (_) => ClaimProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider(), lazy: false),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Phase 2 OCR Document Intake Providers
        Provider(create: (_) => OcrParser()),
        Provider(create: (_) => PodRepository()),
        ChangeNotifierProvider(
          create: (context) => PodController(
            repository: context.read<PodRepository>(),
            ocrParser: context.read<OcrParser>(),
          ),
        ),
      ],
      child: _AppWithNotificationOverlay(),
    );
  }
}

/// Widget that wraps the MaterialApp with a global notification overlay
class _AppWithNotificationOverlay extends StatefulWidget {
  const _AppWithNotificationOverlay();

  @override
  State<_AppWithNotificationOverlay> createState() => _AppWithNotificationOverlayState();
}

class _AppWithNotificationOverlayState extends State<_AppWithNotificationOverlay> {
  @override
  void initState() {
    super.initState();
    // Start chat monitoring when user signs in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      
      // Check if user is already logged in
      final currentUser = authProvider.currentUser;
      if (currentUser != null && currentUser.role == UserRole.driver) {
        print('💬 Starting global chat monitoring for already logged in driver: ${currentUser.id}');
        chatProvider.startMonitoringForDriver(
          currentUser.companyId,
          currentUser.id,
          currentUser.role.toString().split('.').last,
        );
      }
      
      // Listen to auth changes and start monitoring for drivers
      authProvider.addListener(() {
        final user = authProvider.currentUser;
        if (user != null && user.role == UserRole.driver) {
          print('💬 Starting global chat monitoring for driver: ${user.id}');
          chatProvider.startMonitoringForDriver(
            user.companyId,
            user.id,
            user.role.toString().split('.').last,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PODSafe',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Wrap the entire app with the notification overlay
        return Stack(
          children: [
            if (child != null) child,
            const ChatNotificationOverlay(),
          ],
        );
      },
      theme: ThemeData(
        colorScheme: AppTheme.colorScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData().textTheme,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryColor,
        ),
      ),
      home: EnvironmentConfig.showEnvironmentBanner
          ? _EnvironmentBanner(child: const SplashScreen())
          : const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/setup': (context) => const SetupWizardScreen(),
        '/driver/document-intake': (context) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          return DocumentIntakeScreen(
            companyId: authProvider.companyId ?? '',
            driverId: authProvider.currentUser?.id ?? '',
          );
        },
        '/driver/chat': (context) => const DriverChatScreen(),
        '/admin/pods': (context) => const PODViewerScreen(),
        '/admin/deliveries': (context) => const DeliveryManagementScreen(),
        '/admin/deliveries/create': (context) => const CreateDeliveryScreen(),
        '/admin/drivers': (context) => const DriverManagementScreen(),
        '/admin/analytics': (context) => const AnalyticsDashboardScreen(),
        '/admin/reports': (context) => const ReportsScreen(),
        '/admin/bc-settings': (context) => const BCSettingsScreen(),
        '/admin/customers/import': (context) => const CustomerImportScreen(),
        '/admin/chat': (context) => const ChatListScreenDesktop(),
        '/admin/live-tracking': (context) => const LiveTrackingScreen(),
        '/admin/catalog': (context) => const ItemCatalogDesktop(),
        '/admin/delivery-details': (context) {
          final deliveryId = ModalRoute.of(context)?.settings.arguments as String?;
          if (deliveryId != null) {
            return DeliveryDetailsRoute(deliveryId: deliveryId);
          }
          return const DeliveryManagementScreen();
        },
      },
      onGenerateRoute: (settings) {
        debugPrint('🔍 Navigating to: ${settings.name}');
        
        // Handle public upload route: /upload/:token
        if (settings.name != null && settings.name!.contains('/upload/')) {
          try {
            // Split and clean the path
            final pathSegments = settings.name!.split('/').where((s) => s.isNotEmpty).toList();
            debugPrint('📍 Path segments: $pathSegments');
            
            if (pathSegments.length >= 2 && pathSegments[0] == 'upload') {
              final token = pathSegments[1].split('?').first; // Remove query params if any
              debugPrint('🎫 Token extracted: $token');
              
              if (token.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (context) => ExternalUploadScreen(token: token),
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing upload route: $e');
          }
        }
        
        // Handle public POD view route: /pod/:deliveryId?token=xxx
        if (settings.name != null && settings.name!.startsWith('/pod/')) {
          try {
            final uri = Uri.parse(settings.name!);
            final pathSegments = uri.pathSegments;
            
            if (pathSegments.length >= 2 && pathSegments[0] == 'pod') {
              final deliveryId = pathSegments[1];
              final token = uri.queryParameters['token'];
              
              if (deliveryId.isNotEmpty && token != null && token.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (context) => PublicPODViewScreen(
                    deliveryId: deliveryId,
                    token: token,
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing POD view route: $e');
          }
        }
        
        // Handle other dynamic routes here as needed
        
        return null; // Let onUnknownRoute handle it
      },
      onUnknownRoute: (settings) {
        // Fallback for unknown routes
        debugPrint('⚠️ Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        );
      },
    );
  }
}

/// Environment banner widget to show which environment is active
/// Only shown in development mode
class _EnvironmentBanner extends StatelessWidget {
  final Widget child;

  const _EnvironmentBanner({required this.child});

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: EnvironmentConfig.environmentName,
      location: BannerLocation.topEnd,
      color: EnvironmentConfig.isProduction ? Colors.green : Colors.red,
      child: child,
    );
  }
}

