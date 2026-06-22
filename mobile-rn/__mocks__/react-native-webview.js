const React = require('react');

// react-native-webview's native module (RNCWebViewModule) doesn't exist under Jest's
// Node environment. Mocked the same way as __mocks__/@react-native-firebase/*.js —
// auto-discovered by Jest, no jest.mock() calls needed. Only react-native-signature-canvas
// pulls this in transitively today; no test currently exercises WebView behavior directly.
function WebView(props) {
  return React.createElement('WebView', props, props.children);
}

module.exports = { WebView, default: WebView };
