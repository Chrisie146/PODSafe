const mockCrashlyticsModule = {
  setCrashlyticsCollectionEnabled: jest.fn(() => Promise.resolve()),
  recordError: jest.fn(),
  log: jest.fn(),
};

const crashlytics = jest.fn(() => mockCrashlyticsModule);
module.exports = crashlytics;
module.exports.default = crashlytics;
