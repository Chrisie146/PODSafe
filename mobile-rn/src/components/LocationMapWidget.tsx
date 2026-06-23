import React from 'react';
import { Linking, Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, spacing } from '../theme/tokens';

/**
 * Ported from lib/widgets/location_map_widget.dart (verified against source on
 * 2026-06-23) — same degraded-but-honest pattern already used by ClaimDetails.tsx's
 * GPS section and AnalyticsDashboard.tsx's location list: an info card with
 * coordinates/accuracy/address plus an "Open in Maps" deep link, instead of an
 * embedded interactive map. `react-native-maps` was installed for task #12
 * (live_tracking_screen) and is now available, but upgrading this widget to a real
 * embedded `MapView` is a separate, not-yet-decided follow-up — left as-is here.
 */
interface LocationMapWidgetProps {
  latitude: number;
  longitude: number;
  address?: string;
  accuracy?: number;
}

function openInMaps(latitude: number, longitude: number) {
  Linking.openURL(`https://www.google.com/maps?q=${latitude},${longitude}`).catch(() => {
    // best-effort; nothing sensible to do if the device has no maps handler
  });
}

export default function LocationMapWidget({ latitude, longitude, address, accuracy }: LocationMapWidgetProps) {
  const isValid = latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;

  if (!isValid) {
    return (
      <View style={styles.invalidCard}>
        <Text style={styles.invalidIcon}>⚠</Text>
        <Text style={styles.invalidText}>
          Invalid GPS coordinates:{'\n'}Lat: {latitude}, Lng: {longitude}
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.card}>
      <View style={styles.row}>
        <Text style={styles.pin}>📍</Text>
        <Text style={styles.coordinates}>
          {latitude.toFixed(6)}, {longitude.toFixed(6)}
        </Text>
      </View>
      {accuracy != null ? (
        <View style={styles.row}>
          <Text style={styles.metaIcon}>🎯</Text>
          <Text style={styles.meta}>Accuracy: {accuracy.toFixed(1)}m</Text>
        </View>
      ) : null}
      {address ? <Text style={styles.address}>{address}</Text> : null}
      <Pressable style={styles.mapsButton} onPress={() => openInMaps(latitude, longitude)}>
        <Text style={styles.mapsButtonText}>🗺 Open in Maps</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.card, borderRadius: radii.borderRadius, padding: spacing.medium },
  invalidCard: { backgroundColor: `${colors.error}14`, borderRadius: radii.borderRadius, padding: spacing.medium, alignItems: 'center' },
  invalidIcon: { fontSize: 32, color: colors.error },
  invalidText: { color: colors.error, textAlign: 'center', marginTop: spacing.small },
  row: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small },
  pin: { fontSize: 16, marginRight: spacing.small },
  coordinates: { fontSize: 13, fontWeight: '600', color: colors.textPrimary },
  metaIcon: { fontSize: 13, marginRight: spacing.small },
  meta: { fontSize: 12, color: colors.textSecondary },
  address: { fontSize: 12, color: colors.textSecondary, marginBottom: spacing.small },
  mapsButton: { alignSelf: 'flex-start', marginTop: spacing.small, backgroundColor: `${colors.primary}1A`, borderRadius: radii.borderRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  mapsButtonText: { color: colors.primary, fontWeight: '600' },
});
