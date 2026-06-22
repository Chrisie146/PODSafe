const mockFunctionsModule = {
  httpsCallable: jest.fn(() => jest.fn(() => Promise.resolve({ data: {} }))),
};

const functionsModule = jest.fn(() => mockFunctionsModule);
module.exports = functionsModule;
module.exports.default = functionsModule;
