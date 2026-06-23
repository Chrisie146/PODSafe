import type { LinkingOptions } from '@react-navigation/native';
import type { RootStackParamList } from './RootNavigator';

/**
 * Single source of truth for public deep-link routing — /pod/:deliveryId?token=xxx
 * and /upload/:token. This collapses what the Flutter app did in TWO separate places
 * (lib/main.dart's onGenerateRoute AND splash_screen.dart's own Uri.base inspection)
 * into one config, resolved by React Navigation before any auth-gated screen mounts.
 * See plan Section 3, Phase 1.
 */
export const linking: LinkingOptions<RootStackParamList> = {
  prefixes: ['podsafe://', 'https://podsafe.app', 'http://localhost:5000'],
  config: {
    screens: {
      PublicPodView: {
        path: 'pod/:deliveryId',
        parse: {
          deliveryId: (id: string) => id,
        },
      },
      ExternalUpload: {
        path: 'upload/:token',
        parse: {
          token: (token: string) => token,
        },
      },
      // Auth/Home are intentionally absent from the link surface — they are resolved
      // by useAuthStore's currentUser state in RootNavigator, not a URL. Giving them
      // a path (even '') makes React Navigation's web linking throw "conflicting
      // screens with the same pattern", since both would resolve to ''.
    },
  },
};
