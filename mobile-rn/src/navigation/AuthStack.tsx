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
        {() => (
          <PlaceholderAuthScreen
            title="Create an account"
            icon="user"
            message="Self-service signup is coming soon. For now, ask your administrator to invite you."
          />
        )}
      </Stack.Screen>
      <Stack.Screen name="CompanyRegistration" options={{ headerShown: true, title: 'Register Company' }}>
        {() => (
          <PlaceholderAuthScreen
            title="Register a company"
            icon="shield"
            message="Company onboarding is handled by the PODSafe team. Contact support to get your company set up."
          />
        )}
      </Stack.Screen>
      <Stack.Screen name="DriverRegistration" options={{ headerShown: true, title: 'Driver Registration' }}>
        {() => (
          <PlaceholderAuthScreen
            title="Driver registration"
            icon="truck"
            message="Drivers are added by an administrator. Ask yours to create your account or send an invite code."
          />
        )}
      </Stack.Screen>
      <Stack.Screen name="InviteRegistration" options={{ headerShown: true, title: 'Join with Invite Code' }}>
        {() => (
          <PlaceholderAuthScreen
            title="Join with an invite code"
            icon="key"
            message="Invite-code registration is coming soon. Use the code your administrator gave you once this flow is enabled."
          />
        )}
      </Stack.Screen>
      <Stack.Screen name="PendingApproval" options={{ headerShown: true, title: 'Pending Approval' }}>
        {() => (
          <PlaceholderAuthScreen
            title="Awaiting approval"
            icon="info"
            message="Your account is waiting for administrator approval. You'll get full access as soon as it's approved."
          />
        )}
      </Stack.Screen>
    </Stack.Navigator>
  );
}
