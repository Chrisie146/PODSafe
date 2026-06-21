/// Environment configuration for PODSafe
/// 
/// Controls which Firebase project and features are active based on build mode.
library;

enum Environment {
  development,
  production,
}

class EnvironmentConfig {
  // Change this to switch environments
  // DEV: For daily development work
  // PROD: For production releases only
  static const Environment current = Environment.development;
  
  // Environment checks
  static bool get isDevelopment => current == Environment.development;
  static bool get isProduction => current == Environment.production;
  
  // Logging configuration
  static bool get enableVerboseLogging => isDevelopment;
  static bool get enableDebugLogging => isDevelopment;
  
  // Feature flags
  static bool get enableDebugTools => isDevelopment;
  static bool get showEnvironmentBanner => true; // Always show for safety
  
  // Error reporting
  static bool get enableCrashlytics => isProduction;
  static bool get reportErrorsToFirebase => isProduction;
  static bool get enablePrintStatements => isDevelopment; // Control print statements
  
  // Analytics
  static bool get enableAnalytics => true; // Always on, but more detailed in prod
  static bool get collectDetailedAnalytics => isProduction;
  
  // Security
  static bool get enforceStrictSecurity => isProduction;
  
  // Display names
  static String get environmentName {
    switch (current) {
      case Environment.development:
        return 'DEVELOPMENT';
      case Environment.production:
        return 'PRODUCTION';
    }
  }
  
  // Firebase project IDs
  static String get firebaseProjectId {
    switch (current) {
      case Environment.development:
        return 'podsafe-92a3e';
      case Environment.production:
        return 'podsafe-production';
    }
  }
  
  // Public POD viewing base URL
  static String get publicPodBaseUrl {
    switch (current) {
      case Environment.development:
        // For development, use localhost with web port and hash routing
        return 'http://localhost:5000/#';
      case Environment.production:
        return 'https://podsafe.app';
    }
  }
}
