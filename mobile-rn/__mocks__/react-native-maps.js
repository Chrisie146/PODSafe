const React = require('react');
const { View } = require('react-native');

function MapView(props, ref) {
  React.useImperativeHandle(ref, () => ({
    animateCamera: () => {},
    animateToRegion: () => {},
    fitToCoordinates: () => {},
  }));
  return React.createElement(View, { ...props, testID: 'map-view' }, props.children);
}

module.exports = {
  __esModule: true,
  default: React.forwardRef(MapView),
  Marker: (props) => React.createElement(View, { ...props, testID: 'map-marker' }),
  Polyline: (props) => React.createElement(View, { ...props, testID: 'map-polyline' }),
  Callout: (props) => React.createElement(View, { ...props, testID: 'map-callout' }, props.children),
  PROVIDER_GOOGLE: 'google',
  PROVIDER_DEFAULT: 'default',
};
