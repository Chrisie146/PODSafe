import React, { ReactNode } from 'react';
import Svg, { Circle, Line, Path, Polyline, Rect } from 'react-native-svg';

/**
 * PODSafe's single SVG icon entry point. Keep new icons in this 24×24, 2px
 * rounded-stroke style; never substitute emoji, Unicode glyphs, or icon fonts.
 */
export type AppIconName =
  | 'activity'
  | 'alert'
  | 'arrowDown'
  | 'arrowLeft'
  | 'arrowRight'
  | 'calendar'
  | 'camera'
  | 'chart'
  | 'check'
  | 'chevronDown'
  | 'chevronRight'
  | 'clipboard'
  | 'close'
  | 'copy'
  | 'download'
  | 'edit'
  | 'eye'
  | 'file'
  | 'filter'
  | 'home'
  | 'image'
  | 'info'
  | 'key'
  | 'link'
  | 'location'
  | 'lock'
  | 'logout'
  | 'map'
  | 'menu'
  | 'message'
  | 'minus'
  | 'more'
  | 'package'
  | 'phone'
  | 'plus'
  | 'qrCode'
  | 'report'
  | 'search'
  | 'settings'
  | 'shield'
  | 'signature'
  | 'truck'
  | 'trash'
  | 'upload'
  | 'user'
  | 'users'
  | 'vehicle'
  | 'wifiOff';

export interface AppIconProps {
  name: AppIconName;
  size?: number;
  color?: string;
  strokeWidth?: number;
  accessibilityLabel?: string;
}

function glyph(name: AppIconName): ReactNode {
  switch (name) {
    case 'activity':
      return (
        <>
          <Path d="M3 12h3l2-7 4 14 2-7h7" />
        </>
      );
    case 'alert':
      return (
        <>
          <Path d="M12 3 2.7 19.1a1.4 1.4 0 0 0 1.2 2.1h16.2a1.4 1.4 0 0 0 1.2-2.1L12 3Z" />
          <Line x1="12" y1="9" x2="12" y2="13" />
          <Circle cx="12" cy="17" r=".75" fill="currentColor" stroke="none" />
        </>
      );
    case 'arrowDown':
      return (
        <>
          <Line x1="12" y1="4" x2="12" y2="20" />
          <Polyline points="6 14 12 20 18 14" />
        </>
      );
    case 'arrowLeft':
      return (
        <>
          <Line x1="20" y1="12" x2="4" y2="12" />
          <Polyline points="10 6 4 12 10 18" />
        </>
      );
    case 'arrowRight':
      return (
        <>
          <Line x1="4" y1="12" x2="20" y2="12" />
          <Polyline points="14 6 20 12 14 18" />
        </>
      );
    case 'calendar':
      return (
        <>
          <Rect x="3" y="5" width="18" height="16" rx="2" />
          <Line x1="3" y1="10" x2="21" y2="10" />
          <Line x1="8" y1="3" x2="8" y2="7" />
          <Line x1="16" y1="3" x2="16" y2="7" />
        </>
      );
    case 'camera':
      return (
        <>
          <Path d="M4 7h3l1.5-2h7L17 7h3a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2Z" />
          <Circle cx="12" cy="13" r="3.5" />
        </>
      );
    case 'chart':
      return (
        <>
          <Line x1="4" y1="20" x2="4" y2="4" />
          <Line x1="4" y1="20" x2="21" y2="20" />
          <Polyline points="7 16 11 11 14 14 20 7" />
        </>
      );
    case 'check':
      return <Polyline points="5 12 10 17 20 7" />;
    case 'chevronDown':
      return <Polyline points="6 9 12 15 18 9" />;
    case 'chevronRight':
      return <Polyline points="9 6 15 12 9 18" />;
    case 'clipboard':
      return (
        <>
          <Rect x="5" y="4" width="14" height="17" rx="2" />
          <Path d="M9 4.5V3.8A1.8 1.8 0 0 1 10.8 2h2.4A1.8 1.8 0 0 1 15 3.8v.7" />
          <Rect x="8" y="3" width="8" height="4" rx="1" />
        </>
      );
    case 'close':
      return (
        <>
          <Line x1="6" y1="6" x2="18" y2="18" />
          <Line x1="18" y1="6" x2="6" y2="18" />
        </>
      );
    case 'copy':
      return (
        <>
          <Rect x="8" y="8" width="12" height="12" rx="2" />
          <Path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" />
        </>
      );
    case 'download':
      return (
        <>
          <Path d="M12 3v12" />
          <Polyline points="7 11 12 16 17 11" />
          <Path d="M5 20h14" />
        </>
      );
    case 'edit':
      return (
        <>
          <Path d="m4 16.5-.8 4.3 4.3-.8L19 8.5 15.5 5 4 16.5Z" />
          <Line x1="13.8" y1="6.7" x2="17.3" y2="10.2" />
        </>
      );
    case 'eye':
      return (
        <>
          <Path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z" />
          <Circle cx="12" cy="12" r="2.5" />
        </>
      );
    case 'file':
      return (
        <>
          <Path d="M6 3h8l4 4v14H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
          <Polyline points="14 3 14 7 18 7" />
          <Line x1="8" y1="12" x2="16" y2="12" />
          <Line x1="8" y1="16" x2="14" y2="16" />
        </>
      );
    case 'filter':
      return (
        <>
          <Path d="M4 5h16l-6 7v5l-4 2v-7L4 5Z" />
        </>
      );
    case 'home':
      return (
        <>
          <Path d="m3 11 9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-9Z" />
        </>
      );
    case 'image':
      return (
        <>
          <Rect x="3" y="4" width="18" height="16" rx="2" />
          <Circle cx="8" cy="9" r="1.5" />
          <Path d="m4 18 5-5 3 3 2-2 6 4" />
        </>
      );
    case 'info':
      return (
        <>
          <Circle cx="12" cy="12" r="9" />
          <Line x1="12" y1="11" x2="12" y2="16" />
          <Circle cx="12" cy="8" r=".8" fill="currentColor" stroke="none" />
        </>
      );
    case 'key':
      return (
        <>
          <Circle cx="8" cy="15" r="4" />
          <Path d="m11 12 8-8 2 2-2 2 2 2-3 3-2-2-2 2" />
        </>
      );
    case 'link':
      return (
        <>
          <Path d="M10 13.5a4 4 0 0 0 5.7.1l2-2a4 4 0 0 0-5.7-5.7l-1.1 1.1" />
          <Path d="M14 10.5a4 4 0 0 0-5.7-.1l-2 2A4 4 0 0 0 12 18.1l1.1-1.1" />
        </>
      );
    case 'location':
      return (
        <>
          <Path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z" />
          <Circle cx="12" cy="10" r="2.5" />
        </>
      );
    case 'lock':
      return (
        <>
          <Rect x="5" y="10" width="14" height="11" rx="2" />
          <Path d="M8 10V7a4 4 0 0 1 8 0v3" />
        </>
      );
    case 'logout':
      return (
        <>
          <Path d="M10 5H5a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h5" />
          <Line x1="12" y1="12" x2="21" y2="12" />
          <Polyline points="17 8 21 12 17 16" />
        </>
      );
    case 'map':
      return (
        <>
          <Path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3V6Z" />
          <Line x1="9" y1="3" x2="9" y2="18" />
          <Line x1="15" y1="6" x2="15" y2="21" />
        </>
      );
    case 'menu':
      return (
        <>
          <Line x1="4" y1="6" x2="20" y2="6" />
          <Line x1="4" y1="12" x2="20" y2="12" />
          <Line x1="4" y1="18" x2="20" y2="18" />
        </>
      );
    case 'message':
      return (
        <>
          <Path d="M20 15a3 3 0 0 1-3 3H9l-5 3v-3a3 3 0 0 1-2-3V7a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v8Z" />
          <Line x1="7" y1="10" x2="17" y2="10" />
          <Line x1="7" y1="14" x2="13" y2="14" />
        </>
      );
    case 'minus':
      return <Line x1="5" y1="12" x2="19" y2="12" />;
    case 'more':
      return (
        <>
          <Circle cx="5" cy="12" r="1" fill="currentColor" stroke="none" />
          <Circle cx="12" cy="12" r="1" fill="currentColor" stroke="none" />
          <Circle cx="19" cy="12" r="1" fill="currentColor" stroke="none" />
        </>
      );
    case 'package':
      return (
        <>
          <Path d="m3 7 9-4 9 4-9 4-9-4Z" />
          <Path d="M3 7v10l9 4 9-4V7" />
          <Line x1="12" y1="11" x2="12" y2="21" />
        </>
      );
    case 'phone':
      return (
        <>
          <Path d="M7 3h3l1 5-2 1.5a14 14 0 0 0 5.5 5.5L16 13l5 1v3c0 1.1-.9 2-2 2C10.2 19 5 13.8 5 5a2 2 0 0 1 2-2Z" />
        </>
      );
    case 'plus':
      return (
        <>
          <Line x1="12" y1="5" x2="12" y2="19" />
          <Line x1="5" y1="12" x2="19" y2="12" />
        </>
      );
    case 'qrCode':
      return (
        <>
          <Rect x="3" y="3" width="7" height="7" />
          <Rect x="14" y="3" width="7" height="7" />
          <Rect x="3" y="14" width="7" height="7" />
          <Path d="M14 14h3v3h-3zM18 18h3v3h-3zM14 20h2" />
        </>
      );
    case 'report':
      return (
        <>
          <Path d="M5 3h12l2 3-2 3H5v12H3V3h2Z" />
        </>
      );
    case 'search':
      return (
        <>
          <Circle cx="10.5" cy="10.5" r="6.5" />
          <Line x1="15" y1="15" x2="21" y2="21" />
        </>
      );
    case 'settings':
      return (
        <>
          <Circle cx="12" cy="12" r="3" />
          <Path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.1 2.1-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5v.2h-3v-.2a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1L6.6 17l.1-.1A1.7 1.7 0 0 0 7 15a1.7 1.7 0 0 0-1.5-1H5.3v-3h.2A1.7 1.7 0 0 0 7 10a1.7 1.7 0 0 0-.3-1.9l-.1-.1 2.1-2.1.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.5v-.2h3v.2a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 8l-.1.1A1.7 1.7 0 0 0 19.4 10a1.7 1.7 0 0 0 1.5 1h.2v3h-.2a1.7 1.7 0 0 0-1.5 1Z" />
        </>
      );
    case 'shield':
      return (
        <>
          <Path d="M12 3 20 6v5c0 5-3.4 8.2-8 10-4.6-1.8-8-5-8-10V6l8-3Z" />
          <Polyline points="8.5 12 11 14.5 15.5 9.5" />
        </>
      );
    case 'signature':
      return (
        <>
          <Path d="M3 17c2.5 0 3-7 5-7 1.5 0-.5 6 1.5 6 2.5 0 2.5-8 4.5-8 1.5 0-1 8 1 8 1.5 0 2-2 3-3" />
          <Line x1="3" y1="21" x2="21" y2="21" />
        </>
      );
    case 'truck':
      return (
        <>
          <Path d="M3 5h11v11H3zM14 9h4l3 3v4h-7V9Z" />
          <Circle cx="7" cy="18" r="2" />
          <Circle cx="18" cy="18" r="2" />
        </>
      );
    case 'trash':
      return (
        <>
          <Path d="M4 7h16" />
          <Path d="M9 7V4h6v3" />
          <Path d="m6 7 1 14h10l1-14" />
          <Line x1="10" y1="11" x2="10" y2="17" />
          <Line x1="14" y1="11" x2="14" y2="17" />
        </>
      );
    case 'upload':
      return (
        <>
          <Path d="M12 21V9" />
          <Polyline points="7 14 12 9 17 14" />
          <Path d="M5 20h14" />
        </>
      );
    case 'user':
      return (
        <>
          <Circle cx="12" cy="8" r="4" />
          <Path d="M4 21a8 8 0 0 1 16 0" />
        </>
      );
    case 'users':
      return (
        <>
          <Circle cx="9" cy="8" r="3" />
          <Path d="M3 20a6 6 0 0 1 12 0" />
          <Path d="M15 5a3 3 0 0 1 0 6" />
          <Path d="M17 14a5 5 0 0 1 4 5" />
        </>
      );
    case 'vehicle':
      return (
        <>
          <Path d="m5 11 2-5h10l2 5" />
          <Rect x="3" y="11" width="18" height="7" rx="2" />
          <Circle cx="7" cy="18" r="1.5" />
          <Circle cx="17" cy="18" r="1.5" />
        </>
      );
    case 'wifiOff':
      return (
        <>
          <Path d="M4 8a12 12 0 0 1 15.5-.5" />
          <Path d="M7 12a8 8 0 0 1 8.5-.3" />
          <Path d="M10 16a4 4 0 0 1 2.5-.1" />
          <Line x1="3" y1="3" x2="21" y2="21" />
        </>
      );
  }
}

export function AppIcon({
  name,
  size = 24,
  color = '#1B1C1A',
  strokeWidth = 2,
  accessibilityLabel,
}: AppIconProps) {
  return (
    <Svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke={color}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      accessible={accessibilityLabel ? true : undefined}
      accessibilityLabel={accessibilityLabel}
    >
      {glyph(name)}
    </Svg>
  );
}
