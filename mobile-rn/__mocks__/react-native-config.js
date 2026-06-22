// react-native-config's values are populated natively at build time from .env files;
// under Jest there's no native binary, so the real module's getConfig() throws on a
// null native module. Mocked the same way as __mocks__/@react-native-firebase/*.js —
// environment.ts's own `??`/`===` fallbacks handle every key being absent here.
module.exports = {};
