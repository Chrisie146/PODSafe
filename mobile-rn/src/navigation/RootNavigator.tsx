import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useAuthStore } from '../stores/useAuthStore';
import AuthStack from './AuthStack';
import AdminStack from './AdminStack';
import DriverStack from './DriverStack';
import SplashScreen from '../screens/splash/SplashScreen';
import PublicPodViewScreen from '../screens/public/PublicPodViewScreen';
import ExternalUploadScreen from '../screens/external/ExternalUploadScreen';
import { navigationRef } from './navigationRef';
import { linking } from './linking';

/**
 * Auth-state-driven root switch — replaces lib/main.dart's SplashScreen ->
 * role-based-redirect logic. Public deep links (PublicPodView/ExternalUpload) are
 * reachable regardless of auth state, matching the Flutter app's "skip auth bootstrap
 * for public links" behavior, but via linking.ts instead of a duplicated check.
 *
 * Driver and admin role stacks own their authenticated flows. Public links remain
 * reachable regardless of authentication state.
 */
export type RootStackParamList = {
  Auth: undefined;
  Home: undefined;
  PublicPodView: { deliveryId: string; token?: string };
  ExternalUpload: { token: string };
};

declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  const isInitializing = useAuthStore(s => s.isInitializing);
  const currentUser = useAuthStore(s => s.currentUser);
  const initialize = useAuthStore(s => s.initialize);

  useEffect(() => {
    const unsubscribe = initialize();
    return unsubscribe;
  }, [initialize]);

  if (isInitializing) {
    return <SplashScreen />;
  }

  return (
    <NavigationContainer ref={navigationRef} linking={linking}>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {currentUser ? (
          <Stack.Screen name="Home" component={currentUser.role === 'driver' ? DriverStack : AdminStack} />
        ) : (
          <Stack.Screen name="Auth" component={AuthStack} />
        )}
        <Stack.Screen
          name="PublicPodView"
          component={PublicPodViewScreen}
          options={{ headerShown: true, title: 'Proof of Delivery' }}
        />
        <Stack.Screen
          name="ExternalUpload"
          component={ExternalUploadScreen}
          options={{ headerShown: true, title: 'Upload Documents' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
