import React, { useState } from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { AppIcon, AppIconName, AppModal, IconButton, SearchField } from '../ui';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

type AdminNavKey =
  | 'dashboard'
  | 'deliveries'
  | 'proofs'
  | 'drivers'
  | 'users'
  | 'claims'
  | 'analytics'
  | 'reports'
  | 'settings';

interface AdminNavItem {
  key: AdminNavKey;
  label: string;
  icon: AppIconName;
  screen: string;
}

const NAVIGATION: AdminNavItem[] = [
  {
    key: 'dashboard',
    label: 'Dashboard',
    icon: 'home',
    screen: 'AdminDashboard',
  },
  {
    key: 'deliveries',
    label: 'Deliveries',
    icon: 'truck',
    screen: 'DeliveryManagement',
  },
  {
    key: 'proofs',
    label: 'Proofs of delivery',
    icon: 'signature',
    screen: 'PodViewer',
  },
  {
    key: 'drivers',
    label: 'Drivers',
    icon: 'users',
    screen: 'DriverManagement',
  },
  { key: 'users', label: 'Users', icon: 'user', screen: 'UserManagement' },
  { key: 'claims', label: 'Claims', icon: 'alert', screen: 'ClaimsDashboard' },
  {
    key: 'analytics',
    label: 'Analytics',
    icon: 'activity',
    screen: 'AnalyticsDashboard',
  },
  { key: 'reports', label: 'Reports', icon: 'chart', screen: 'Reports' },
  {
    key: 'settings',
    label: 'Settings',
    icon: 'settings',
    screen: 'AdminSettings',
  },
];

export interface AdminShellProps {
  children: React.ReactNode;
  title: string;
  activeNav: AdminNavKey;
  userName?: string;
  searchValue?: string;
  searchPlaceholder?: string;
  onNavigate: (screen: string) => void;
  onSearchChange?: (value: string) => void;
  onRefresh?: () => void;
  onLogout?: () => void;
}

/** Responsive administrative frame: 280px desktop shell and a safe mobile menu. */
export function AdminShell({
  children,
  title,
  activeNav,
  userName,
  searchValue,
  searchPlaceholder = 'Filter workspace',
  onNavigate,
  onSearchChange,
  onRefresh,
  onLogout,
}: AdminShellProps) {
  const { width } = useWindowDimensions();
  const [mobileNavVisible, setMobileNavVisible] = useState(false);
  const isDesktop = width >= 1200;

  const navigate = (item: AdminNavItem) => {
    setMobileNavVisible(false);
    onNavigate(item.screen);
  };

  const navigation = (
    <View
      style={isDesktop ? styles.desktopNavigation : styles.mobileNavigation}
    >
      {NAVIGATION.map(item => {
        const selected = item.key === activeNav;
        const navColor = selected
          ? colors.shell
          : isDesktop
          ? colors.onPrimary
          : colors.contentPrimary;
        return (
          <Pressable
            key={item.key}
            accessibilityRole="button"
            accessibilityLabel={item.label}
            accessibilityState={{ selected }}
            onPress={() => navigate(item)}
            style={({ pressed }) => [
              styles.navItem,
              selected && styles.navItemSelected,
              pressed && styles.navItemPressed,
            ]}
          >
            <AppIcon name={item.icon} size={20} color={navColor} />
            <Text
              style={[
                styles.navLabel,
                !isDesktop && styles.navLabelMobile,
                selected && styles.navLabelSelected,
              ]}
            >
              {item.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );

  return (
    <SafeAreaView
      edges={['top', 'left', 'right', 'bottom']}
      style={styles.safeArea}
    >
      <View style={styles.shell}>
        {isDesktop ? (
          <View style={styles.sidebar}>
            <View style={styles.brand}>
              <View style={styles.brandMark}>
                <AppIcon name="truck" size={24} color={colors.shell} />
              </View>
              <View>
                <Text style={styles.brandName}>PODSafe</Text>
                <Text style={styles.brandCaption}>OPERATIONS</Text>
              </View>
            </View>
            {navigation}
            <View style={styles.sidebarFooter}>
              <Text style={styles.sidebarFooterText}>
                {userName ?? 'Administrator'}
              </Text>
              <Text style={styles.sidebarFooterText}>Secure workspace</Text>
            </View>
          </View>
        ) : null}

        <View style={styles.main}>
          <View style={styles.utilityBar}>
            <View style={styles.utilityTitle}>
              {!isDesktop ? (
                <IconButton
                  icon="menu"
                  accessibilityLabel="Open admin navigation"
                  onPress={() => setMobileNavVisible(true)}
                />
              ) : null}
              <Text numberOfLines={1} style={textStyles.heading3}>
                {title}
              </Text>
            </View>
            <View style={styles.utilityActions}>
              {isDesktop && onSearchChange ? (
                <SearchField
                  value={searchValue}
                  onChangeText={onSearchChange}
                  placeholder={searchPlaceholder}
                  containerStyle={styles.search}
                />
              ) : null}
              {onRefresh ? (
                <IconButton
                  icon="activity"
                  accessibilityLabel="Refresh dashboard"
                  onPress={onRefresh}
                />
              ) : null}
              {onLogout ? (
                <IconButton
                  icon="logout"
                  accessibilityLabel="Sign out"
                  onPress={onLogout}
                />
              ) : null}
            </View>
          </View>
          <View style={styles.body}>{children}</View>
        </View>
      </View>

      <AppModal
        visible={mobileNavVisible}
        title="Admin navigation"
        onClose={() => setMobileNavVisible(false)}
      >
        {navigation}
      </AppModal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { backgroundColor: colors.canvas, flex: 1 },
  shell: { backgroundColor: colors.canvas, flex: 1, flexDirection: 'row' },
  sidebar: {
    backgroundColor: colors.shell,
    padding: spacing.medium,
    width: 280,
  },
  brand: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
    marginBottom: spacing.xxLarge,
    marginTop: spacing.small,
  },
  brandMark: {
    alignItems: 'center',
    backgroundColor: colors.verified,
    borderRadius: radii.inputRadius,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  brandName: { ...textStyles.heading3, color: colors.onPrimary },
  brandCaption: {
    ...textStyles.labelSmall,
    color: colors.onPrimary,
    letterSpacing: 1.2,
    opacity: 0.68,
  },
  desktopNavigation: { gap: spacing.xs },
  mobileNavigation: { gap: spacing.xs },
  navItem: {
    alignItems: 'center',
    borderRadius: radii.inputRadius,
    flexDirection: 'row',
    gap: spacing.small,
    minHeight: 48,
    paddingHorizontal: spacing.medium,
  },
  navItemSelected: { backgroundColor: colors.verified },
  navItemPressed: { opacity: 0.82 },
  navLabel: { ...textStyles.label, color: colors.onPrimary, flex: 1 },
  navLabelMobile: { color: colors.contentPrimary },
  navLabelSelected: { color: colors.shell },
  sidebarFooter: {
    borderTopColor: 'rgba(255,255,255,0.2)',
    borderTopWidth: StyleSheet.hairlineWidth,
    gap: spacing.xs,
    marginTop: 'auto',
    paddingTop: spacing.medium,
  },
  sidebarFooterText: {
    ...textStyles.bodySmall,
    color: colors.onPrimary,
    opacity: 0.72,
  },
  main: { flex: 1, minWidth: 0 },
  utilityBar: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.medium,
    justifyContent: 'space-between',
    minHeight: 72,
    paddingHorizontal: spacing.large,
  },
  utilityTitle: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    gap: spacing.small,
    minWidth: 0,
  },
  utilityActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  search: { width: 300 },
  body: { flex: 1, minWidth: 0 },
});
