/**
 * Web counterpart of environment.ts. react-native-config does not work under
 * react-native-web, so values are read from process.env, injected at build time by
 * webpack DefinePlugin (see webpack.config.js). Resolution order in webpack prefers
 * this .web.ts over environment.ts for the web target only; Metro never resolves it.
 */
export type Environment = 'development' | 'production';

const env = (process.env.ENVIRONMENT as Environment) ?? 'development';

export const EnvironmentConfig = {
  current: env,
  isDevelopment: env === 'development',
  isProduction: env === 'production',

  enableVerboseLogging: env === 'development',
  enableDebugLogging: env === 'development',
  enableDebugTools: env === 'development',
  showEnvironmentBanner: process.env.SHOW_ENVIRONMENT_BANNER === 'true',

  enableCrashlytics: false,
  reportErrorsToFirebase: env === 'production',
  enableAnalytics: false,
  collectDetailedAnalytics: env === 'production',

  enforceStrictSecurity: env === 'production',

  environmentName: env === 'production' ? 'PRODUCTION' : 'DEVELOPMENT',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID ?? 'podsafe-f4a47',
  publicPodBaseUrl: process.env.PUBLIC_POD_BASE_URL ?? 'http://localhost:5000',
  useFirebaseEmulators: process.env.USE_FIREBASE_EMULATORS === 'true',
  firebaseEmulatorHost: process.env.FIREBASE_EMULATOR_HOST || 'localhost',
  firebaseAuthEmulatorPort: Number(process.env.FIREBASE_AUTH_EMULATOR_PORT) || 9099,
};
