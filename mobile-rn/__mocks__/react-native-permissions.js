// react-native-permissions' native module doesn't exist under Jest's Node environment —
// mocked the same way as __mocks__/@react-native-firebase/*.js.
const RESULTS = {
  UNAVAILABLE: 'unavailable',
  DENIED: 'denied',
  LIMITED: 'limited',
  GRANTED: 'granted',
  BLOCKED: 'blocked',
};

const PERMISSIONS = {
  IOS: { LOCATION_WHEN_IN_USE: 'ios.permission.LOCATION_WHEN_IN_USE' },
  ANDROID: { ACCESS_FINE_LOCATION: 'android.permission.ACCESS_FINE_LOCATION' },
};

module.exports = {
  RESULTS,
  PERMISSIONS,
  check: jest.fn(() => Promise.resolve(RESULTS.GRANTED)),
  request: jest.fn(() => Promise.resolve(RESULTS.GRANTED)),
};
