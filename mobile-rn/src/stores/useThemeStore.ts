import { create } from 'zustand';
import firestore from '@react-native-firebase/firestore';

/**
 * Replaces lib/providers/theme_provider.dart's ThemeProvider (ChangeNotifier). See vault
 * "03 Inventory - Providers to Stores" for the mapping — that note still says "Not
 * started" for this one despite the Phase Checklist's "all 8 stores" claim; re-verified
 * against `src/stores/` directly (2026-06-23) and confirmed it genuinely didn't exist
 * yet. Layers dynamic per-company branding over the static theme/tokens.ts.
 *
 * Colors are kept as RN-friendly `#RRGGBB` hex strings rather than Dart's packed-int
 * `Color` objects, but persist to/from Firestore using the same `color.value.toString()`
 * (32-bit ARGB packed into a decimal string, full opacity assumed) format the Flutter
 * app still reads/writes, since both apps share this Firestore database during the
 * migration.
 */
interface ThemeState {
  primaryColor: string;
  accentColor: string;
  warningColor: string;
  successColor: string;
  appName: string;
  appLogoUrl?: string;
  isLoading: boolean;

  loadBrandingSettings: (companyId: string) => Promise<void>;
  setPrimaryColor: (color: string) => void;
  setAccentColor: (color: string) => void;
  setWarningColor: (color: string) => void;
  setSuccessColor: (color: string) => void;
  setAppName: (name: string) => void;
  setAppLogoUrl: (url: string | undefined) => void;
  saveBrandingSettings: (companyId: string, userId: string) => Promise<void>;
  reset: () => void;
}

const DEFAULTS = {
  primaryColor: '#1976D2',
  accentColor: '#2196F3',
  warningColor: '#FFA726',
  successColor: '#4CAF50',
  appName: 'PODSafe',
  appLogoUrl: undefined as string | undefined,
};

/** Mirrors Dart's `Color(int.parse(value))` on read: a 32-bit ARGB int as a decimal string. */
function argbStringToHex(value: unknown): string | undefined {
  const n = Number(value);
  if (!Number.isFinite(n)) return undefined;
  return `#${(n & 0xffffff).toString(16).padStart(6, '0').toUpperCase()}`;
}

/** Mirrors Dart's `color.value.toString()` on write. Assumes full opacity (alpha = FF). */
function hexToArgbString(hex: string): string {
  const rgb = hex.replace('#', '').padStart(6, '0');
  return String(parseInt(`FF${rgb}`, 16));
}

function brandingDocRef(companyId: string) {
  return firestore().collection('companies').doc(companyId).collection('settings').doc('branding');
}

export const useThemeStore = create<ThemeState>((set, get) => ({
  ...DEFAULTS,
  isLoading: false,

  loadBrandingSettings: async (companyId) => {
    set({ isLoading: true });
    try {
      const doc = await brandingDocRef(companyId).get();
      if (doc.exists()) {
        const data = doc.data() ?? {};
        set({
          appName: typeof data.appName === 'string' ? data.appName : DEFAULTS.appName,
          appLogoUrl: typeof data.appLogoUrl === 'string' ? data.appLogoUrl : undefined,
          primaryColor: argbStringToHex(data.primaryColor) ?? DEFAULTS.primaryColor,
          accentColor: argbStringToHex(data.accentColor) ?? DEFAULTS.accentColor,
          warningColor: argbStringToHex(data.warningColor) ?? DEFAULTS.warningColor,
          successColor: argbStringToHex(data.successColor) ?? DEFAULTS.successColor,
        });
      }
    } catch {
      // Mirrors Dart: keep current/default values on error.
    } finally {
      set({ isLoading: false });
    }
  },

  setPrimaryColor: (color) => set({ primaryColor: color }),
  setAccentColor: (color) => set({ accentColor: color }),
  setWarningColor: (color) => set({ warningColor: color }),
  setSuccessColor: (color) => set({ successColor: color }),
  setAppName: (name) => set({ appName: name }),
  setAppLogoUrl: (url) => set({ appLogoUrl: url }),

  saveBrandingSettings: async (companyId, userId) => {
    const state = get();
    await brandingDocRef(companyId).set({
      appName: state.appName,
      appLogoUrl: state.appLogoUrl ?? null,
      primaryColor: hexToArgbString(state.primaryColor),
      accentColor: hexToArgbString(state.accentColor),
      warningColor: hexToArgbString(state.warningColor),
      successColor: hexToArgbString(state.successColor),
      updatedAt: firestore.FieldValue.serverTimestamp(),
      updatedBy: userId,
    });
  },

  reset: () => set({ ...DEFAULTS, isLoading: false }),
}));
