class Constants {
  // App Configuration
  static const String appName = 'PODSafe';
  static const String appVersion = '1.0.0';
  static const String companyName = 'PODSafe Technologies';
  
  // API Configuration
  static const String baseUrl = 'https://api.podsafe.com';
  static const int requestTimeout = 30; // seconds
  
  // Storage Configuration
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxPdfSize = 10 * 1024 * 1024; // 10MB
  static const String imageQuality = 'medium'; // low, medium, high
  
  // Location Configuration
  static const double locationAccuracyThreshold = 10.0; // meters
  static const int locationTimeout = 15; // seconds
  static const double deliveryRadiusThreshold = 100.0; // meters
  
  // Sync Configuration
  static const int syncRetryAttempts = 3;
  static const int syncRetryDelay = 5; // seconds
  static const int maxOfflineRecords = 100;
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double cardElevation = 4.0;
  static const double borderRadius = 12.0;
  
  // Validation Rules
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  static const int maxCustomerNameLength = 100;
  static const int maxNotesLength = 500;
  
  // File Paths
  static const String signaturePath = 'signatures/';
  static const String photosPath = 'photos/';
  static const String pdfsPath = 'pdfs/';
  
  // Error Messages
  static const String networkError = 'Network connection error. Please try again.';
  static const String unknownError = 'An unexpected error occurred.';
  static const String validationError = 'Please check your input and try again.';
  static const String permissionError = 'Permission denied. Please check app settings.';
  
  // Success Messages
  static const String podSubmittedSuccess = 'POD submitted successfully!';
  static const String dataUploadedSuccess = 'Data uploaded successfully!';
  static const String syncCompletedSuccess = 'Sync completed successfully!';
  
  // POD Status Colors (hex values)
  static const String pendingColor = '#FFA726';
  static const String signedColor = '#4CAF50';
  static const String missingColor = '#E57373';
  static const String inTransitColor = '#42A5F5';
  
  // Delivery Status
  static const List<String> deliveryStatuses = [
    'pending',
    'inTransit', 
    'delivered',
    'failed'
  ];
  
  // POD Status
  static const List<String> podStatuses = [
    'pending',
    'signed',
    'missing'
  ];
  
  // User Roles
  static const List<String> userRoles = [
    'admin',
    'driver'
  ];
}

class RegexPatterns {
  static const String email = r'^[^@]+@[^@]+\.[^@]+';
  static const String phoneNumber = r'^\+?[\d\s\-\(\)]+$';
  static const String invoiceNumber = r'^[A-Z0-9\-_]+$';
  static const String postalCode = r'^[\d\w\s\-]{3,10}$';
}

class SharedPreferenceKeys {
  static const String isFirstLaunch = 'is_first_launch';
  static const String currentUserId = 'current_user_id';
  static const String lastSyncTime = 'last_sync_time';
  static const String offlineMode = 'offline_mode';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String biometricsEnabled = 'biometrics_enabled';
  static const String cacheVersion = 'cache_version';
  static const String appSettings = 'app_settings';
}