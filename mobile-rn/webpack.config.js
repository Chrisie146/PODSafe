const path = require('path');
const webpack = require('webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const Dotenv = require('dotenv');

// Load .env.web (local, gitignored) if present; fall back to process env.
const fileEnv = Dotenv.config({ path: path.resolve(__dirname, '.env.web') }).parsed || {};
const ENV_KEYS = [
  'ENVIRONMENT', 'SHOW_ENVIRONMENT_BANNER',
  'FIREBASE_API_KEY', 'FIREBASE_AUTH_DOMAIN', 'FIREBASE_PROJECT_ID',
  'FIREBASE_STORAGE_BUCKET', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_APP_ID',
  'PUBLIC_POD_BASE_URL', 'USE_FIREBASE_EMULATORS',
  'FIREBASE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_PORT',
];
const defineEnv = ENV_KEYS.reduce((acc, k) => {
  acc[`process.env.${k}`] = JSON.stringify(fileEnv[k] ?? process.env[k] ?? '');
  return acc;
}, {});

// React Native and many RN-ecosystem packages ship untranspiled Flow/JSX and must
// pass through babel-loader (node_modules is otherwise excluded).
const compileNodeModules = [
  'react-native',
  'react-native-web',
  'react-native-safe-area-context',
  'react-native-svg',
  'react-native-get-random-values',
  '@react-navigation',
].map((m) => path.resolve(__dirname, 'node_modules', m));

// Native-only RN libraries that have no web build — aliased to a noop stub so the
// web bundle resolves. Real per-screen web fallbacks are M3 work.
const NATIVE_ONLY_STUBS = [
  '@react-native-ml-kit/text-recognition',
  '@react-native-documents/picker',
  'react-native-linear-gradient',
  'expo-linear-gradient',
  'react-native-maps',
  'react-native-geolocation-service',
  'react-native-permissions',
  'react-native-image-picker',
  'react-native-signature-canvas',
  'react-native-share',
  '@react-native-clipboard/clipboard',
];
const noopStub = path.resolve(__dirname, 'src/web-stubs/native-noop.js');
const nativeOnlyStubAliases = NATIVE_ONLY_STUBS.reduce((acc, name) => {
  acc[`${name}$`] = noopStub;
  return acc;
}, {});

module.exports = {
  entry: path.resolve(__dirname, 'index.web.js'),
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'bundle.[contenthash].js',
    publicPath: '/',
    clean: true,
  },
  resolve: {
    alias: {
      'react-native$': 'react-native-web',
      // Native-only libraries with no web implementation → noop stub (M1/M2
      // placeholder; real web fallbacks are M3). See src/web-stubs/native-noop.js.
      ...nativeOnlyStubAliases,
      // Firebase shim aliases are added in Task 7.
    },
    extensions: ['.web.tsx', '.web.ts', '.web.js', '.tsx', '.ts', '.js'],
  },
  module: {
    rules: [
      {
        // Many ESM packages (firebase, RN-ecosystem) use extensionless relative
        // imports; webpack 5 otherwise rejects them as not "fully specified".
        test: /\.m?js$/,
        resolve: { fullySpecified: false },
      },
      {
        test: /\.(js|jsx|ts|tsx)$/,
        include: [path.resolve(__dirname, 'index.web.js'), path.resolve(__dirname, 'App.tsx'), path.resolve(__dirname, 'src'), ...compileNodeModules],
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['module:@react-native/babel-preset'],
            plugins: ['react-native-web'],
          },
        },
      },
      {
        test: /\.(png|jpe?g|gif|svg|ttf|woff2?)$/,
        type: 'asset/resource',
      },
    ],
  },
  plugins: [
    new HtmlWebpackPlugin({ template: path.resolve(__dirname, 'public/index.html') }),
    new webpack.DefinePlugin({ ...defineEnv, __DEV__: JSON.stringify(true) }),
  ],
  devServer: {
    static: { directory: path.resolve(__dirname, 'public') },
    historyApiFallback: true,
    port: 8082,
  },
};
