import { Platform, TextStyle } from 'react-native';
import { colors } from './tokens';

/**
 * Typography scale for the Operations Precision design system. Font assets are linked
 * into Android and iOS from assets/fonts via react-native.config.js.
 */
export const fontFamilies = {
  heading: Platform.select({ ios: 'Poppins-SemiBold', android: 'Poppins-SemiBold', web: 'Poppins, system-ui, sans-serif', default: 'Poppins-SemiBold' }),
  body: Platform.select({ ios: 'Inter-Regular', android: 'Inter-Regular', web: 'Inter, system-ui, sans-serif', default: 'Inter-Regular' }),
  bodyMedium: Platform.select({ ios: 'Inter-Medium', android: 'Inter-Medium', web: 'Inter, system-ui, sans-serif', default: 'Inter-Medium' }),
  bodySemiBold: Platform.select({ ios: 'Inter-SemiBold', android: 'Inter-SemiBold', web: 'Inter, system-ui, sans-serif', default: 'Inter-SemiBold' }),
} as const;

export const textStyles: Record<string, TextStyle> = {
  heading1: { fontFamily: fontFamilies.heading, fontSize: 32, lineHeight: 40, fontWeight: '600', color: colors.contentPrimary },
  heading2: { fontFamily: fontFamilies.heading, fontSize: 24, lineHeight: 32, fontWeight: '600', color: colors.contentPrimary },
  heading3: { fontFamily: fontFamilies.heading, fontSize: 18, lineHeight: 24, fontWeight: '600', color: colors.contentPrimary },
  bodyLarge: { fontFamily: fontFamilies.body, fontSize: 16, lineHeight: 24, fontWeight: '400', color: colors.contentPrimary },
  bodyMedium: { fontFamily: fontFamilies.body, fontSize: 14, lineHeight: 20, fontWeight: '400', color: colors.contentPrimary },
  bodySmall: { fontFamily: fontFamilies.body, fontSize: 12, lineHeight: 16, fontWeight: '400', color: colors.contentSecondary },
  label: { fontFamily: fontFamilies.bodyMedium, fontSize: 14, lineHeight: 20, fontWeight: '500', color: colors.contentPrimary },
  labelSmall: { fontFamily: fontFamilies.bodyMedium, fontSize: 12, lineHeight: 16, fontWeight: '500', color: colors.contentSecondary },
  buttonText: { fontFamily: fontFamilies.bodySemiBold, fontSize: 16, lineHeight: 20, fontWeight: '600', color: colors.onPrimary },
  captionText: { fontFamily: fontFamilies.body, fontSize: 12, lineHeight: 16, fontWeight: '400', color: colors.contentSecondary },
};
