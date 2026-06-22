import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import LoginScreen from '../screens/auth/LoginScreen';
import PlaceholderAuthScreen from '../screens/auth/PlaceholderAuthScreen';

/**
 * Ported from lib/screens/auth/*.dart. Mirrors the Flutter app's auth flow screens:
 * login, signup, company-registration, driver-registration, invite-registration,
 * pending-approval. setup_wizard_screen.dart is routed separately post-login (see
 * RootNavigator), not part of this stack.
 */
export type AuthStackParamList = {
  Login: undefined;
  Signup: undefined;
  CompanyRegistration: undefined;
  DriverRegistration: undefined;
  InviteRegistration: { token?: string };
  PendingApproval: undefined;
};

const Stack = createNativeStackNavigator<AuthStackParamList>();

export default function AuthStack() {
  return (
    <Stack.Navigator initialRouteName="Login" screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Login" component={LoginScreen} />
      <Stack.Screen name="Signup" options={{ headerShown: true, title: 'Sign Up' }}>
        {() => <PlaceholderAuthScreen title="Sign Up" />}
      </Stack.Screen>
      <Stack.Screen name="CompanyRegistration" options={{ headerShown: true, title: 'Register Company' }}>
        {() => <PlaceholderAuthScreen title="Register Company" />}
      </Stack.Screen>
      <Stack.Screen name="DriverRegistration" options={{ headerShown: true, title: 'Driver Registration' }}>
        {() => <PlaceholderAuthScreen title="Driver Registration" />}
      </Stack.Screen>
      <Stack.Screen name="InviteRegistration" options={{ headerShown: true, title: 'Join with Invite Code' }}>
        {() => <PlaceholderAuthScreen title="Join with Invite Code" />}
      </Stack.Screen>
      <Stack.Screen name="PendingApproval" options={{ headerShown: true, title: 'Pending Approval' }}>
        {() => <PlaceholderAuthScreen title="Pending Approval" />}
      </Stack.Screen>
    </Stack.Navigator>
  );
}
