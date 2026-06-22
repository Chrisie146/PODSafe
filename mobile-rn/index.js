/**
 * @format
 */

// MUST be the first import — react-native-get-random-values polyfills crypto.getRandomValues
// before uuid is ever imported. If this ordering breaks, uuid v4 generation silently produces
// weak randomness under Hermes. See vault note "10 Risk Register", item 6.
import 'react-native-get-random-values';

import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
