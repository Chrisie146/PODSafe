import { createNavigationContainerRef } from '@react-navigation/native';

/**
 * Equivalent of Flutter's global `navigatorKey` in lib/main.dart — lets services
 * (e.g. notificationRepository.ts in Phase 6) navigate without a component's
 * BuildContext/navigation prop, for FCM tap-routing.
 */
export const navigationRef = createNavigationContainerRef();

export function navigate(name: string, params?: object) {
  if (navigationRef.isReady()) {
    // @ts-expect-error - generic navigate, route names are validated at each call site
    navigationRef.navigate(name, params);
  }
}
