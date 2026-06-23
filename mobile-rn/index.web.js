/**
 * @format
 * React Native Web entry point. Native uses index.js; this file is webpack-only.
 */

// MUST be first — polyfills crypto.getRandomValues before uuid is imported (parity with index.js).
import 'react-native-get-random-values';

import { AppRegistry } from 'react-native';
import './src/config/firebase.web';
import { configureFirebaseEmulators } from './src/config/firebaseEmulators';
import { name as appName } from './app.json';

configureFirebaseEmulators();
const App = require('./App').default;

AppRegistry.registerComponent(appName, () => App);
AppRegistry.runApplication(appName, {
  rootTag: document.getElementById('root'),
});
