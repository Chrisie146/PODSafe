import { TextStyle } from 'react-native';
import { colors } from './tokens';

/**
 * Ported 1:1 from lib/utils/theme.dart's AppTextStyles. Font family applied
 * separately via ThemeProvider once Poppins is linked (see Phase 1 native setup
 * checklist in the vault — "11 Environment and Native Setup").
 */
export const textStyles: Record<string, TextStyle> = {
  heading1: { fontSize: 32, fontWeight: 'bold', color: colors.textPrimary },
  heading2: { fontSize: 24, fontWeight: 'bold', color: colors.textPrimary },
  heading3: { fontSize: 20, fontWeight: '600', color: colors.textPrimary },
  bodyLarge: { fontSize: 16, fontWeight: 'normal', color: colors.textPrimary },
  bodyMedium: { fontSize: 14, fontWeight: 'normal', color: colors.textPrimary },
  bodySmall: { fontSize: 12, fontWeight: 'normal', color: colors.textSecondary },
  buttonText: { fontSize: 16, fontWeight: '600', color: colors.white },
  captionText: { fontSize: 12, fontWeight: 'normal', color: colors.textSecondary },
};
