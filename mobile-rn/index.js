/**
 * @format
 */

// MUST be the first import — react-native-get-random-values polyfills crypto.getRandomValues
// before uuid is ever imported. If this ordering breaks, uuid v4 generation silently produces
// weak randomness under Hermes. See vault note "10 Risk Register", item 6.
import 'react-native-get-random-values';

import { AppRegistry } from 'react-native';
import { configureFirebaseEmulators } from './src/config/firebaseEmulators';
import { name as appName } from './app.json';

// configureFirebaseEmulators() must run before anything touches the native Auth
// module, so App is required (not statically imported) after the emulator call —
// static imports are hoisted above this file's own top-level statements.
configureFirebaseEmulators();
const App = require('./App').default;
AppRegistry.registerComponent(appName, () => App);
