/**
 * Static design tokens, ported 1:1 from lib/utils/theme.dart's AppTheme
 * (verified directly against source on 2026-06-21).
 */
export const colors = {
  // Primary Colors - Business Professional Blue & Green
  primary: '#2E7D8C',
  secondary: '#4CAF50',
  accent: '#00BCD4',

  // Status Colors
  success: '#4CAF50',
  error: '#E57373',
  warning: '#FFA726',
  info: '#42A5F5',

  // Neutral Colors
  background: '#F8F9FA',
  card: '#FFFFFF',
  textPrimary: '#212529',
  textSecondary: '#6C757D',
  divider: '#E9ECEF',

  // POD status colors
  podPending: '#FFA726',
  podSigned: '#4CAF50',
  podMissing: '#E57373',
  podInTransit: '#42A5F5',

  white: '#FFFFFF',
} as const;

export const gradients = {
  primary: { colors: [colors.primary, colors.accent] as const, start: { x: 0, y: 0 }, end: { x: 1, y: 1 } },
  success: { colors: [colors.success, '#66BB6A'] as const, start: { x: 0, y: 0 }, end: { x: 1, y: 1 } },
};

export const radii = {
  borderRadius: 12,
  cardRadius: 16,
  buttonRadius: 12,
};

export const spacing = {
  small: 8,
  medium: 16,
  large: 24,
  xLarge: 32,
};

export const shadows = {
  card: {
    shadowColor: '#000000',
    shadowOpacity: 0.1,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 4,
  },
  button: {
    shadowColor: '#000000',
    shadowOpacity: 0.15,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
    elevation: 2,
  },
} as const;
