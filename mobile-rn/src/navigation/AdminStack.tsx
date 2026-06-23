import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import AbaserveImport from '../screens/admin/AbaserveImport';
import AdminDashboard from '../screens/admin/AdminDashboard';
import AdminSettings from '../screens/admin/AdminSettings';
import AnalyticsDashboard from '../screens/admin/AnalyticsDashboard';
import BcSettings from '../screens/admin/BcSettings';
import BulkItemCreation from '../screens/admin/BulkItemCreation';
import BulkUpload from '../screens/admin/BulkUpload';
import ClaimDetails from '../screens/admin/ClaimDetails';
import ClaimSettings from '../screens/admin/ClaimSettings';
import ClaimsDashboard from '../screens/admin/ClaimsDashboard';
import CreateDelivery from '../screens/admin/CreateDelivery';
import CreateDriver from '../screens/admin/CreateDriver';
import CustomerCreation from '../screens/admin/CustomerCreation';
import CustomerImport from '../screens/admin/CustomerImport';
import DataMigration from '../screens/admin/DataMigration';
import DeliveryDetails from '../screens/admin/DeliveryDetails';
import DeliveryManagement from '../screens/admin/DeliveryManagement';
import DriverDetails from '../screens/admin/DriverDetails';
import DriverManagement from '../screens/admin/DriverManagement';
import PodDetails from '../screens/admin/PodDetails';
import PodViewer from '../screens/admin/PodViewer';
import Reports from '../screens/admin/Reports';
import UploadEvidenceForm from '../screens/admin/UploadEvidenceForm';
import UserManagement from '../screens/admin/UserManagement';
import { colors, spacing } from '../theme/tokens';

export type AdminStackParamList = {
  AbaserveImport: undefined;
  AdminDashboard: undefined;
  AnalyticsDashboard: undefined;
  BcSettings: undefined;
  BulkItemCreation: undefined;
  ClaimDetails: { claimId: string };
  ClaimSettings: undefined;
  ClaimsDashboard: undefined;
  CustomerCreation: undefined;
  CustomerImport: undefined;
  DataMigration: undefined;
  DeliveryDetails: { deliveryId: string };
  DeliveryManagement: undefined;
  DriverDetails: { driverId: string };
  DriverManagement: undefined;
  PodViewer: undefined;
  Reports: undefined;
  UploadEvidence: undefined;
  UserManagement: undefined;
  AdminSettings: undefined;
  BulkUpload: undefined;
  CreateDelivery: { deliveryId?: string } | undefined;
  CreateDriver: { driverId?: string } | undefined;
  PodDetails: { deliveryId: string };
  VehicleManagement: undefined;
};

const Stack = createNativeStackNavigator<AdminStackParamList>();

function NotMigratedYet() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>This feature is still being migrated</Text>
      <Text style={styles.body}>It is not available in the React Native app yet. The existing Flutter app remains the working version for this feature.</Text>
    </View>
  );
}

export default function AdminStack() {
  return (
    <Stack.Navigator
      initialRouteName="AdminDashboard"
      screenOptions={{ headerTintColor: colors.white, headerStyle: { backgroundColor: colors.primary } }}
    >
      <Stack.Screen name="AdminDashboard" options={{ headerShown: false }}>
        {({ navigation }) => <AdminDashboard navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="AbaserveImport" component={AbaserveImport} options={{ title: 'Import from ABServe' }} />
      <Stack.Screen name="AnalyticsDashboard" component={AnalyticsDashboard} options={{ title: 'Analytics' }} />
      <Stack.Screen name="BcSettings" component={BcSettings} options={{ title: 'Business Central' }} />
      <Stack.Screen name="BulkItemCreation" component={BulkItemCreation} options={{ title: 'Bulk Item Creation' }} />
      <Stack.Screen name="ClaimDetails" component={ClaimDetails} options={{ title: 'Claim Details' }} />
      <Stack.Screen name="ClaimSettings" component={ClaimSettings} options={{ title: 'Claim Settings' }} />
      <Stack.Screen name="ClaimsDashboard" options={{ title: 'Claims' }}>
        {({ navigation }) => <ClaimsDashboard navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="CustomerCreation" component={CustomerCreation} options={{ title: 'Create Customer' }} />
      <Stack.Screen name="CustomerImport" component={CustomerImport} options={{ title: 'Import Customers' }} />
      <Stack.Screen name="DataMigration" component={DataMigration} options={{ title: 'Data Migration' }} />
      <Stack.Screen name="DeliveryDetails" component={DeliveryDetails} options={{ title: 'Delivery Details' }} />
      <Stack.Screen name="DeliveryManagement" options={{ title: 'Deliveries' }}>
        {({ navigation }) => <DeliveryManagement navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="DriverDetails" component={DriverDetails} options={{ title: 'Driver Details' }} />
      <Stack.Screen name="DriverManagement" options={{ title: 'Drivers' }}>
        {({ navigation }) => <DriverManagement navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="PodViewer" options={{ title: 'Proofs of Delivery' }}>
        {({ navigation }) => <PodViewer navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="Reports" component={Reports} options={{ title: 'Reports' }} />
      <Stack.Screen name="UploadEvidence" component={UploadEvidenceForm} options={{ title: 'Upload Evidence' }} />
      <Stack.Screen name="UserManagement" component={UserManagement} options={{ title: 'Users' }} />

      <Stack.Screen name="AdminSettings" options={{ title: 'Admin Settings' }}>
        {({ navigation }) => <AdminSettings navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="BulkUpload" component={BulkUpload} options={{ title: 'Bulk Upload' }} />
      <Stack.Screen name="CreateDelivery" options={{ title: 'Create Delivery' }}>
        {({ navigation, route }) => <CreateDelivery navigation={navigation} route={route} />}
      </Stack.Screen>
      <Stack.Screen name="CreateDriver" component={CreateDriver} options={{ title: 'Add Driver' }} />
      <Stack.Screen name="PodDetails" options={{ headerShown: false }}>
        {({ navigation, route }) => <PodDetails navigation={navigation} route={route} />}
      </Stack.Screen>
      <Stack.Screen name="VehicleManagement" component={NotMigratedYet} options={{ title: 'Vehicle Management' }} />
    </Stack.Navigator>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: spacing.large, backgroundColor: colors.background },
  title: { color: colors.textPrimary, fontSize: 20, fontWeight: '700', textAlign: 'center' },
  body: { color: colors.textSecondary, fontSize: 15, lineHeight: 22, marginTop: spacing.medium, textAlign: 'center' },
});
