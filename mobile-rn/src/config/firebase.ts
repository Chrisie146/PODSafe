import { getApp } from '@react-native-firebase/app';

/**
 * @react-native-firebase native modules auto-initialize from the native config files
 * (google-services.json / GoogleService-Info.plist) per environment/build-flavor —
 * see vault "11 Environment and Native Setup". This module exists as a single place
 * to reach the initialized app instance once those native files are in place; nothing
 * to configure on the JS side for native builds.
 *
 * The RNW (web) build target cannot use these native modules at all and needs its own
 * firebase.web.ts using the plain Firebase JS SDK — tracked for Phase 4 (web admin
 * screens) since Phase 1/2 only target native (Android — no Xcode/iOS available in
 * this dev environment, see session note).
 */
export function getFirebaseApp() {
  return getApp();
}
