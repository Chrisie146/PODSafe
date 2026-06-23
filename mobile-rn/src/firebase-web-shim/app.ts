/**
 * Web shim for @react-native-firebase/app. Existing code imports { getApp } from it.
 * The firebase JS SDK app is initialized in src/config/firebase.web.ts.
 */
import { getApp } from 'firebase/app';

export { getApp };
export default { getApp };
