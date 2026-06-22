import auth from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import functions from '@react-native-firebase/functions';
import storage from '@react-native-firebase/storage';
import { EnvironmentConfig } from './environment';

let configured = false;

/**
 * Routes development builds to local Firebase emulators when explicitly enabled.
 * This must execute before repositories start their Auth/Firestore subscriptions.
 */
export function configureFirebaseEmulators(): void {
  if (configured || !EnvironmentConfig.useFirebaseEmulators) return;

  const host = EnvironmentConfig.firebaseEmulatorHost;
  auth().useEmulator(`http://${host}:${EnvironmentConfig.firebaseAuthEmulatorPort}`);
  firestore().useEmulator(host, 8080);
  functions().useEmulator(host, 5001);
  storage().useEmulator(host, 9199);
  configured = true;
}
