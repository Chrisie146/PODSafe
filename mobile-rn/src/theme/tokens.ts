/**
 * Design tokens — "Operations Precision" design system.
 * Source of truth: vault note "12 Design & Style System".
 *
 * Legacy key names (primary/secondary/accent/background/card/divider/pod*) are retained
 * for backward compatibility with the ~63 files that already import them, but their VALUES
 * now map to the approved semantic palette (navy shell, warm canvas, bordered white
 * surfaces, semantic blue/green/amber/coral, tonal depth instead of pervasive shadow).
 * New code should prefer the semantic aliases (shell/canvas/surface/border/focus/...).
 */
export const colors = {
  // --- Semantic palette (preferred for new code) ---
  shell: '#0B1F3A', // app shell / primary action — sidebar, principal buttons, strong headings
  canvas: '#FAF9F5', // working canvas — main app background
  surface: '#FFFFFF', // elevated surface — cards, forms, tables, panels
  surfaceMuted: '#F2F1EB', // subtle tonal layer on the canvas
  active: '#3D9BFF', // active / informational — current route, active tabs
  verified: '#36C68A', // verified / completed — successful POD evidence
  attention: '#F5B942', // warning / attention — due-soon, non-critical exceptions
  critical: '#BA1A1A', // error / critical — failed or critical states
  contentPrimary: '#1B1C1A', // main text
  contentSecondary: '#44474D', // metadata and supporting copy
  border: '#C4C6CE', // dividers / outlines — inputs, card borders, table separators
  focus: '#3D9BFF', // focus ring / active input
  disabled: '#C4C6CE', // disabled control
  onPrimary: '#FFFFFF', // text/icon on shell/primary fills
  scrim: 'rgba(11, 31, 58, 0.5)', // modal/overlay scrim (navy)

  // --- Legacy keys (same names as before; remapped to the new palette) ---
  primary: '#0B1F3A', // was teal #2E7D8C → navy shell / primary action
  secondary: '#36C68A', // was #4CAF50 → verified/completed green
  accent: '#3D9BFF', // was cyan #00BCD4 → active/informational blue

  success: '#36C68A',
  error: '#BA1A1A',
  warning: '#F5B942',
  info: '#3D9BFF',

  background: '#FAF9F5',
  card: '#FFFFFF',
  textPrimary: '#1B1C1A',
  textSecondary: '#44474D',
  divider: '#C4C6CE',

  // POD status colors
  podPending: '#F5B942',
  podSigned: '#36C68A',
  podMissing: '#BA1A1A',
  podInTransit: '#3D9BFF',

  white: '#FFFFFF',
} as const;

export const radii = {
  borderRadius: 12,
  cardRadius: 16,
  buttonRadius: 12,
  inputRadius: 8,
};

// 4px baseline grid.
export const spacing = {
  xs: 4,
  small: 8,
  medium: 16,
  large: 24,
  xLarge: 32,
  xxLarge: 48,
};

/**
 * Depth: the design system prefers a 1px border + tonal layering over shadows. Only
 * modals/popovers carry a quiet ambient shadow. `card`/`button` are kept (47 files spread
 * them) but reduced to near-flat so surfaces lean on `colors.border` instead.
 */
export const shadows = {
  card: {
    shadowColor: '#0B1F3A',
    shadowOpacity: 0.04,
    shadowRadius: 2,
    shadowOffset: { width: 0, height: 1 },
    elevation: 1,
  },
  button: {
    shadowColor: '#000000',
    shadowOpacity: 0,
    shadowRadius: 0,
    shadowOffset: { width: 0, height: 0 },
    elevation: 0,
  },
  modal: {
    shadowColor: '#0B1F3A',
    shadowOpacity: 0.12,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 4 },
    elevation: 8,
  },
} as const;
