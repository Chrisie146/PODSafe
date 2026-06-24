/**
 * PODSafe — React Native rewrite entry point.
 * @format
 */

import React, { useEffect } from 'react';
import { Platform, StatusBar, useColorScheme } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import RootNavigator from './src/navigation/RootNavigator';

interface WebStyleElement {
  id: string;
  textContent: string;
  remove: () => void;
}

interface WebDocument {
  getElementById: (id: string) => unknown;
  createElement: (tagName: 'style') => WebStyleElement;
  head: { appendChild: (node: WebStyleElement) => unknown };
}

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  useEffect(() => {
    const webDocument = (globalThis as typeof globalThis & { document?: WebDocument }).document;
    if (Platform.OS !== 'web' || !webDocument) {
      return undefined;
    }

    const styleId = 'podsafe-font-faces';
    if (webDocument.getElementById(styleId)) {
      return undefined;
    }

    const assetUrl = (asset: unknown) => typeof asset === 'string' ? asset : (asset as { default?: string }).default ?? '';
    const style = webDocument.createElement('style');
    style.id = styleId;
    style.textContent = `
      @font-face { font-family: 'Poppins'; src: url('${assetUrl(require('./assets/fonts/Poppins-Regular.ttf'))}') format('truetype'); font-weight: 400; font-style: normal; font-display: swap; }
      @font-face { font-family: 'Poppins'; src: url('${assetUrl(require('./assets/fonts/Poppins-SemiBold.ttf'))}') format('truetype'); font-weight: 600; font-style: normal; font-display: swap; }
      @font-face { font-family: 'Inter'; src: url('${assetUrl(require('./assets/fonts/Inter-Regular.ttf'))}') format('truetype'); font-weight: 400; font-style: normal; font-display: swap; }
      @font-face { font-family: 'Inter'; src: url('${assetUrl(require('./assets/fonts/Inter-Medium.ttf'))}') format('truetype'); font-weight: 500; font-style: normal; font-display: swap; }
      @font-face { font-family: 'Inter'; src: url('${assetUrl(require('./assets/fonts/Inter-SemiBold.ttf'))}') format('truetype'); font-weight: 600; font-style: normal; font-display: swap; }
    `;
    webDocument.head.appendChild(style);
    return () => style.remove();
  }, []);

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <RootNavigator />
    </SafeAreaProvider>
  );
}

export default App;
