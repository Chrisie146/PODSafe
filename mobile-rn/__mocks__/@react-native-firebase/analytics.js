const mockAnalyticsModule = {
  setAnalyticsCollectionEnabled: jest.fn(() => Promise.resolve()),
  logEvent: jest.fn(() => Promise.resolve()),
};

const analyticsModule = jest.fn(() => mockAnalyticsModule);
module.exports = analyticsModule;
module.exports.default = analyticsModule;
