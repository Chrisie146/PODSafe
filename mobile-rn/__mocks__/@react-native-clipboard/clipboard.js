// @react-native-clipboard/clipboard's native module doesn't exist under Jest's Node
// environment — mocked the same way as __mocks__/@react-native-firebase/*.js.
const Clipboard = {
  getString: jest.fn(() => Promise.resolve('')),
  setString: jest.fn(),
  hasString: jest.fn(() => Promise.resolve(false)),
};

module.exports = Clipboard;
module.exports.default = Clipboard;
