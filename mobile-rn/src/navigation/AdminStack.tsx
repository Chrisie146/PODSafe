import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import AbaserveImport from '../screens/admin/AbaserveImport';
import AdminDashboard from '../screens/admin/AdminDashboard';
import AdminDashboardDesktop from '../screens/admin/AdminDashboardDesktop';
import AdminSettings from '../screens/admin/AdminSettings';
import AnalyticsDashboard from '../screens/admin/AnalyticsDashboard';
import AnalyticsDashboardDesktop from '../screens/admin/AnalyticsDashboardDesktop';
import BcSettings from '../screens/admin/BcSettings';
import BulkItemCreation from '../screens/admin/BulkItemCreation';
import BulkUpload from '../screens/admin/BulkUpload';
import ChatListDesktop from '../screens/admin/ChatListDesktop';
import ClaimDetails from '../screens/admin/ClaimDetails';
import ClaimDetailsDesktop from '../screens/admin/ClaimDetailsDesktop';
import ClaimSettings from '../screens/admin/ClaimSettings';
import ClaimSettingsDesktop from '../screens/admin/ClaimSettingsDesktop';
import ClaimsDashboard from '../screens/admin/ClaimsDashboard';
import ClaimsDashboardDesktop from '../screens/admin/ClaimsDashboardDesktop';
import CreateDelivery from '../screens/admin/CreateDelivery';
import CreateDriver from '../screens/admin/CreateDriver';
import CustomerCreation from '../screens/admin/CustomerCreation';
import CustomerImport from '../screens/admin/CustomerImport';
import DataMigration from '../screens/admin/DataMigration';
import DeliveryDetails from '../screens/admin/DeliveryDetails';
import DeliveryManagement from '../screens/admin/DeliveryManagement';
import DeliveryManagementDesktop from '../screens/admin/DeliveryManagementDesktop';
import DriverDetails from '../screens/admin/DriverDetails';
import DriverManagement from '../screens/admin/DriverManagement';
import DriverManagementDesktop from '../screens/admin/DriverManagementDesktop';
import ItemCatalogDesktop from '../screens/admin/ItemCatalogDesktop';
import LiveTracking from '../screens/admin/LiveTracking';
import PodDetails from '../screens/admin/PodDetails';
import PodViewer from '../screens/admin/PodViewer';
import PodViewerDesktop from '../screens/admin/PodViewerDesktop';
import Reports from '../screens/admin/Reports';
import ReportsDesktop from '../screens/admin/ReportsDesktop';
import UploadEvidenceForm from '../screens/admin/UploadEvidenceForm';
import UserManagement from '../screens/admin/UserManagement';
import VehicleManagement from '../screens/admin/VehicleManagement';
import VehicleManagementDesktop from '../screens/admin/VehicleManagementDesktop';
import { colors } from '../theme/tokens';

export type AdminStackParamList = {
  AbaserveImport: undefined;
  AdminDashboard: undefined;
  AdminDashboardDesktop: undefined;
  AnalyticsDashboard: undefined;
  AnalyticsDashboardDesktop: undefined;
  BcSettings: undefined;
  BulkItemCreation: undefined;
  ChatListDesktop: undefined;
  ClaimDetails: { claimId: string };
  ClaimDetailsDesktop: { claimId: string };
  ClaimSettings: undefined;
  ClaimSettingsDesktop: undefined;
  ClaimsDashboard: undefined;
  ClaimsDashboardDesktop: undefined;
  CustomerCreation: undefined;
  CustomerImport: undefined;
  DataMigration: undefined;
  DeliveryDetails: { deliveryId: string };
  DeliveryManagement: undefined;
  DeliveryManagementDesktop: undefined;
  DriverDetails: { driverId: string };
  DriverManagement: undefined;
  DriverManagementDesktop: undefined;
  ItemCatalogDesktop: undefined;
  LiveTracking: undefined;
  PodViewer: undefined;
  PodViewerDesktop: undefined;
  Reports: undefined;
  ReportsDesktop: undefined;
  UploadEvidence: undefined;
  UserManagement: undefined;
  AdminSettings: undefined;
  BulkUpload: undefined;
  CreateDelivery: { deliveryId?: string } | undefined;
  CreateDriver: { driverId?: string } | undefined;
  PodDetails: { deliveryId: string };
  VehicleManagement: undefined;
  VehicleManagementDesktop: undefined;
};

const Stack = createNativeStackNavigator<AdminStackParamList>();

export default function AdminStack() {
  return (
    <Stack.Navigator
      initialRouteName="AdminDashboard"
      screenOptions={{ headerTintColor: colors.white, headerStyle: { backgroundColor: colors.primary } }}
    >
      <Stack.Screen name="AdminDashboard" options={{ headerShown: false }}>
        {({ navigation }) => <AdminDashboard navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="AdminDashboardDesktop" options={{ headerShown: false }}>
        {({ navigation }) => <AdminDashboardDesktop navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="AbaserveImport" component={AbaserveImport} options={{ title: 'Import from ABServe' }} />
      <Stack.Screen name="AnalyticsDashboard" component={AnalyticsDashboard} options={{ title: 'Analytics' }} />
      <Stack.Screen name="AnalyticsDashboardDesktop" options={{ headerShown: false }}>
        {({ navigation }) => <AnalyticsDashboardDesktop navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="BcSettings" component={BcSettings} options={{ title: 'Business Central' }} />
      <Stack.Screen name="BulkItemCreation" component={BulkItemCreation} options={{ title: 'Bulk Item Creation' }} />
      <Stack.Screen name="ChatListDesktop" component={ChatListDesktop} options={{ headerShown: false }} />
      <Stack.Screen name="ClaimDetails" component={ClaimDetails} options={{ title: 'Claim Details' }} />
      <Stack.Screen name="ClaimDetailsDesktop" options={{ headerShown: false }}>
        {({ navigation, route }) => <ClaimDetailsDesktop navigation={navigation} route={route} />}
      </Stack.Screen>
      <Stack.Screen name="ClaimSettings" component={ClaimSettings} options={{ title: 'Claim Settings' }} />
      <Stack.Screen name="ClaimSettingsDesktop" component={ClaimSettingsDesktop} options={{ headerShown: false }} />
      <Stack.Screen name="ClaimsDashboard" options={{ title: 'Claims' }}>
        {({ navigation }) => <ClaimsDashboard navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="ClaimsDashboardDesktop" options={{ headerShown: false }}>
        {({ navigation }) => <ClaimsDashboardDesktop navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="CustomerCreation" component={CustomerCreation} options={{ title: 'Create Customer' }} />
      <Stack.Screen name="CustomerImport" component={CustomerImport} options={{ title: 'Import Customers' }} />
      <Stack.Screen name="DataMigration" component={DataMigration} options={{ title: 'Data Migration' }} />
      <Stack.Screen name="DeliveryDetails" component={DeliveryDetails} options={{ title: 'Delivery Details' }} />
      <Stack.Screen name="DeliveryManagement" options={{ title: 'Deliveries' }}>
        {({ navigation }) => <DeliveryManagement navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="DeliveryManagementDesktop" options={{ headerShown: false }}>
        {({ navigation }) => <DeliveryManagementDesktop navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="DriverDetails" component={DriverDetails} options={{ title: 'Driver Details' }} />
      <Stack.Screen name="DriverManagement" options={{ title: 'Drivers' }}>
        {({ navigation }) => <DriverManagement navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="DriverManagementDesktop" options={{ headerShown: false }}>
        {({ navigation }) => <DriverManagementDesktop navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="ItemCatalogDesktop" component={ItemCatalogDesktop} options={{ headerShown: false }} />
      <Stack.Screen name="LiveTracking" component={LiveTracking} options={{ title: 'Live Tracking' }} />
      <Stack.Screen name="PodViewer" options={{ title: 'Proofs of Delivery' }}>
        {({ navigation }) => <PodViewer navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="PodViewerDesktop" options={{ headerShown: false }}>
        {({ navigation }) => <PodViewerDesktop navigation={navigation} />}
      </Stack.Screen>
      <Stack.Screen name="Reports" component={Reports} options={{ title: 'Reports' }} />
      <Stack.Screen name="ReportsDesktop" component={ReportsDesktop} options={{ headerShown: false }} />
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
      <Stack.Screen name="VehicleManagement" component={VehicleManagement} options={{ title: 'Vehicle Management' }} />
      <Stack.Screen name="VehicleManagementDesktop" component={VehicleManagementDesktop} options={{ title: 'Vehicle Management' }} />
    </Stack.Navigator>
  );
}
