import Config from 'react-native-config';

/**
 * Replaces lib/config/environment.dart's hardcoded Environment.current constant.
 * Driven by react-native-config (.env.development / .env.production, selected via
 * native build flavor/scheme — see vault note "11 Environment and Native Setup").
 *
 * Unlike the Flutter app today (which compiles BOTH dev and prod Firebase credentials
 * into every build regardless of environment), only the active environment's values
 * are present here, since the .env files are not bundled together.
 */
export type Environment = 'development' | 'production';

const environment = (Config.ENVIRONMENT as Environment) ?? 'development';

export const EnvironmentConfig = {
  current: environment,
  isDevelopment: environment === 'development',
  isProduction: environment === 'production',

  enableVerboseLogging: environment === 'development',
  enableDebugLogging: environment === 'development',
  enableDebugTools: environment === 'development',
  showEnvironmentBanner: Config.SHOW_ENVIRONMENT_BANNER === 'true',

  enableCrashlytics: Config.ENABLE_CRASHLYTICS === 'true',
  reportErrorsToFirebase: environment === 'production',
  enableAnalytics: true,
  collectDetailedAnalytics: environment === 'production',

  enforceStrictSecurity: environment === 'production',

  environmentName: environment === 'production' ? 'PRODUCTION' : 'DEVELOPMENT',
  firebaseProjectId: Config.FIREBASE_PROJECT_ID ?? 'podsafe-92a3e',
  publicPodBaseUrl: Config.PUBLIC_POD_BASE_URL ?? 'http://localhost:5000',
};
