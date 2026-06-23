module.exports = {
  preset: '@react-native/jest-preset',
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-native-firebase|@react-native-async-storage|@react-navigation|react-native-.*|firebase|@firebase)/)',
  ],
};
