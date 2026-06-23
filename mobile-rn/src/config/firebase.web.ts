import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';

/**
 * Web-only Firebase initialization using the plain JS SDK. The firebase-web-shim
 * modules (aliased over @react-native-firebase/*) call getApp() to reach this instance.
 * Config comes from process.env, injected by webpack DefinePlugin.
 */
const webFirebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN,
  projectId: process.env.FIREBASE_PROJECT_ID,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.FIREBASE_APP_ID,
};

export function getWebFirebaseApp(): FirebaseApp {
  return getApps().length ? getApp() : initializeApp(webFirebaseConfig);
}

// Initialize eagerly on import so the shim modules can synchronously getApp().
getWebFirebaseApp();
