// react-native-share's native module doesn't exist under Jest's Node environment —
// mocked the same way as __mocks__/@react-native-firebase/*.js.
const Social = { Whatsapp: 'whatsapp', Email: 'email', Sms: 'sms' };

const Share = {
  open: jest.fn(() => Promise.resolve({ success: true })),
  shareSingle: jest.fn(() => Promise.resolve({ success: true })),
  Social,
};

module.exports = Share;
module.exports.default = Share;
module.exports.Social = Social;
