import React from 'react';
import { Alert, View } from 'react-native';
import { createNativeStackNavigator, NativeStackScreenProps } from '@react-navigation/native-stack';
import Dashboard from '../screens/driver/Dashboard';
import DeliveryList from '../screens/driver/DeliveryList';
import DeliveryDetails from '../screens/driver/DeliveryDetails';
import PodCapture from '../screens/driver/PodCapture';
import DocumentIntake from '../screens/driver/DocumentIntake';
import Chat from '../screens/driver/Chat';
import MyClaims from '../screens/driver/MyClaims';
import ClaimDetails from '../screens/driver/ClaimDetails';
import ReportIssue from '../screens/driver/ReportIssue';
import { IconButton } from '../components/ui/Buttons';
import { useAuthStore } from '../stores/useAuthStore';
import { colors } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

export type DriverStackParamList = {
  Dashboard: undefined;
  DeliveryList: undefined;
  DeliveryDetails: { deliveryId: string };
  PodCapture: { deliveryId: string };
  DocumentIntake: { deliveryId?: string } | undefined;
  Chat: undefined;
  MyClaims: undefined;
  ClaimDetails: { claimId: string };
  ReportIssue: { deliveryId: string; isAtDeliverySite: boolean };
};

const Stack = createNativeStackNavigator<DriverStackParamList>();

type DashboardScreenProps = NativeStackScreenProps<DriverStackParamList, 'Dashboard'>;

function DashboardHeaderActions({ navigation }: { navigation: DashboardScreenProps['navigation'] }) {
  const signOut = useAuthStore((s) => s.signOut);

  const handleLogout = () => {
    Alert.alert('Sign Out', 'Are you sure you want to sign out?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign Out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  return (
    <View style={styles.actions}>
      <IconButton icon="message" color={colors.onPrimary} accessibilityLabel="Chat with admin" onPress={() => navigation.navigate('Chat')} />
      <IconButton icon="clipboard" color={colors.onPrimary} accessibilityLabel="View my claims" onPress={() => navigation.navigate('MyClaims')} />
      <IconButton icon="logout" color={colors.onPrimary} accessibilityLabel="Sign out" onPress={handleLogout} />
    </View>
  );
}

function DashboardScreenWrapper({ navigation }: DashboardScreenProps) {
  React.useLayoutEffect(() => {
    navigation.setOptions({
      // eslint-disable-next-line react/no-unstable-nested-components -- required shape of React Navigation's headerRight option
      headerRight: () => <DashboardHeaderActions navigation={navigation} />,
    });
  }, [navigation]);

  return (
    <Dashboard
      onSelectDelivery={(delivery) => navigation.navigate('DeliveryDetails', { deliveryId: delivery.id })}
      onViewAllDeliveries={() => navigation.navigate('DeliveryList')}
    />
  );
}

export default function DriverStack() {
  return (
    <Stack.Navigator
      initialRouteName="Dashboard"
      screenOptions={{
        headerTintColor: colors.onPrimary,
        headerStyle: { backgroundColor: colors.shell },
        headerTitleStyle: { ...textStyles.label, color: colors.onPrimary },
      }}
    >
      <Stack.Screen name="Dashboard" component={DashboardScreenWrapper} options={{ title: 'PODSafe Driver' }} />

      <Stack.Screen name="DeliveryList" options={{ title: 'Deliveries' }}>
        {({ navigation }) => (
          <DeliveryList onSelectDelivery={(delivery) => navigation.navigate('DeliveryDetails', { deliveryId: delivery.id })} />
        )}
      </Stack.Screen>

      <Stack.Screen name="DeliveryDetails" component={DeliveryDetails} options={{ title: 'Delivery Details' }} />
      <Stack.Screen name="PodCapture" component={PodCapture} options={{ title: 'Capture POD' }} />
      <Stack.Screen name="DocumentIntake" component={DocumentIntake} options={{ title: 'Capture Invoice' }} />
      <Stack.Screen name="Chat" component={Chat} options={{ title: 'Chat with Admin' }} />
      <Stack.Screen name="MyClaims" component={MyClaims} options={{ title: 'My Claims' }} />
      <Stack.Screen name="ClaimDetails" component={ClaimDetails} options={{ title: 'Claim Details' }} />
      <Stack.Screen name="ReportIssue" component={ReportIssue} options={{ title: 'Report Issue' }} />
    </Stack.Navigator>
  );
}

const styles = {
  actions: { flexDirection: 'row' as const },
};
