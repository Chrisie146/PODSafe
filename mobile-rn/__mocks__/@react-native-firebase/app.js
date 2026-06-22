// Jest manual mock — native Firebase modules can't run under Node/Jest at all
// (they bridge to real native SDKs), so every @react-native-firebase/* package is
// mocked here rather than transformed. See vault "11 Environment and Native Setup".
const app = {
  name: '[DEFAULT]',
};

module.exports = {
  getApp: jest.fn(() => app),
  default: jest.fn(() => app),
};
