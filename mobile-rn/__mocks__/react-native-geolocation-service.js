// react-native-geolocation-service's native module backs onto a NativeEventEmitter
// that doesn't exist under Jest's Node environment — mocked the same way as
// __mocks__/@react-native-firebase/*.js.
const Geolocation = {
  requestAuthorization: jest.fn(() => Promise.resolve('granted')),
  getCurrentPosition: jest.fn((success) =>
    success({ coords: { latitude: 0, longitude: 0, accuracy: 0, altitude: null, heading: null, speed: null }, timestamp: 0 }),
  ),
  watchPosition: jest.fn(() => 0),
  clearWatch: jest.fn(),
  stopObserving: jest.fn(),
};

module.exports = Geolocation;
module.exports.default = Geolocation;
