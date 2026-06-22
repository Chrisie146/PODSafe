// @react-native-ml-kit/text-recognition ships untranspiled ESM (.ts as `main`), which
// Jest can't parse, and its native module doesn't exist under Jest's Node environment
// anyway — mocked the same way as __mocks__/@react-native-firebase/*.js.
const TextRecognition = {
  recognize: jest.fn(() => Promise.resolve({ text: '', blocks: [] })),
};

module.exports = TextRecognition;
module.exports.default = TextRecognition;
module.exports.TextRecognitionScript = { LATIN: 'Latin', CHINESE: 'Chinese', DEVANAGARI: 'Devanagari', JAPANESE: 'Japanese', KOREAN: 'Korean' };
