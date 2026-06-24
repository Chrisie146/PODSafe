import React from 'react';
import { Linking, StyleSheet, Text, View } from 'react-native';
import { AppIcon, Card, SecondaryButton } from './ui';
import { colors, spacing } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

interface LocationMapWidgetProps {
  latitude: number;
  longitude: number;
  address?: string;
  accuracy?: number;
}

function openInMaps(latitude: number, longitude: number) {
  Linking.openURL(
    `https://www.google.com/maps?q=${latitude},${longitude}`,
  ).catch(() => undefined);
}

/** A deliberate RNW-safe map fallback: coordinates, confidence, and a labelled maps action. */
export default function LocationMapWidget({
  latitude,
  longitude,
  address,
  accuracy,
}: LocationMapWidgetProps) {
  const isValid =
    latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;

  if (!isValid) {
    return (
      <Card style={styles.invalid}>
        <AppIcon name="alert" size={28} color={colors.critical} />
        <View style={styles.copy}>
          <Text style={textStyles.label}>Location unavailable</Text>
          <Text style={textStyles.bodySmall}>
            The captured coordinates are invalid.
          </Text>
        </View>
      </Card>
    );
  }

  return (
    <View style={styles.content}>
      <View style={styles.row}>
        <AppIcon name="location" size={18} color={colors.active} />
        <Text selectable style={textStyles.bodyMedium}>
          {latitude.toFixed(6)}, {longitude.toFixed(6)}
        </Text>
      </View>
      {accuracy != null ? (
        <View style={styles.row}>
          <AppIcon name="activity" size={18} color={colors.contentSecondary} />
          <Text style={textStyles.bodySmall}>
            Location accuracy: {accuracy.toFixed(1)} m
          </Text>
        </View>
      ) : null}
      {address ? <Text style={textStyles.bodySmall}>{address}</Text> : null}
      <SecondaryButton
        label="Open in Maps"
        icon="map"
        onPress={() => openInMaps(latitude, longitude)}
        style={styles.mapAction}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  content: { gap: spacing.small },
  row: { alignItems: 'center', flexDirection: 'row', gap: spacing.small },
  mapAction: { alignSelf: 'flex-start', marginTop: spacing.xs },
  invalid: {
    alignItems: 'center',
    backgroundColor: colors.criticalMuted,
    flexDirection: 'row',
    gap: spacing.small,
  },
  copy: { flex: 1, gap: spacing.xs },
});
