const React = require('react');
const { View } = require('react-native');

module.exports = {
  LineChart: (props) => React.createElement(View, { ...props, testID: 'line-chart' }),
};
