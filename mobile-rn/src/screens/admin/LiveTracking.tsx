import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, Modal, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import MapView, { Callout, Marker, Polyline } from 'react-native-maps';
import { useAuthStore } from '../../stores/useAuthStore';
import { Delivery } from '../../models/delivery';
import { deliveryFromFirestore } from '../../models/delivery.converters';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/live_tracking_screen.dart (verified against source on
 * 2026-06-23) — a sidebar of active deliveries next to a live map of delivery/driver
 * markers, with routes drawn between a driver and their assigned delivery.
 *
 * Bug fixes vs. the Dart source (stored delivery status is camelCase, e.g. 'inTransit' —
 * confirmed via delivery.converters.ts's VALID_STATUSES — but the Dart source compares
 * against snake_case 'in_transit' in three separate places, so real in-transit
 * deliveries were never matched in production):
 * - The Firestore `status in [...]` query now uses 'inTransit' — the Dart query never
 *   actually returned in-transit deliveries.
 * - statusColor()/statusText() (used by both map pins and the sidebar list) now switch
 *   on 'inTransit'.
 * - handleSelectDelivery zooms the map to the tapped delivery's OWN resolved location.
 *   The Dart `_zoomToDelivery(deliveryId)` ignored its parameter entirely (a stale TODO)
 *   and always zoomed to an arbitrary first driver instead.
 * - The deliveries/drivers listeners live in one effect keyed on
 *   [companyId, startDate, endDate, refreshKey] with a cleanup that unsubscribes the
 *   previous listeners. The Dart source re-subscribes on every date-range change and
 *   Refresh tap without ever cancelling the previous subscription, leaking listeners.
 *
 * Driver markers (green) read users/{uid}'s raw currentLocation GeoPoint +
 * locationUpdatedAt directly (no AppUser field exists for this). Nothing in this
 * codebase currently writes those fields in production, so driver markers are ported
 * faithfully but won't show real drivers until a future location-reporting feature
 * exists.
 */

type LatLngLiteral = { latitude: number; longitude: number };

interface DriverLocation {
  id: string;
  fullName: string;
  location: LatLngLiteral;
}

const INITIAL_REGION = {
  latitude: -26.2041,
  longitude: 28.0473,
  latitudeDelta: 0.5,
  longitudeDelta: 0.5,
};

// City-center approximation for pending/in-transit deliveries with no POD location yet,
// ported verbatim from the Dart source's _geocodeAddress (no real geocoding API call).
const CITY_COORDINATES: Record<string, LatLngLiteral> = {
  johannesburg: { latitude: -26.2041, longitude: 28.0473 },
  joburg: { latitude: -26.2041, longitude: 28.0473 },
  sandton: { latitude: -26.1076, longitude: 28.0567 },
  pretoria: { latitude: -25.7479, longitude: 28.2293 },
  'cape town': { latitude: -33.9249, longitude: 18.4241 },
  durban: { latitude: -29.8587, longitude: 31.0218 },
  'port elizabeth': { latitude: -33.9608, longitude: 25.6022 },
  bloemfontein: { latitude: -29.0852, longitude: 26.1596 },
  'east london': { latitude: -33.0153, longitude: 27.9116 },
  pietermaritzburg: { latitude: -29.6011, longitude: 30.3794 },
  nelspruit: { latitude: -25.4748, longitude: 30.9699 },
  kimberley: { latitude: -28.7282, longitude: 24.7499 },
  polokwane: { latitude: -23.9045, longitude: 29.4689 },
};

function geocodeAddress(address: string): LatLngLiteral {
  const lower = address.toLowerCase();
  for (const [city, coords] of Object.entries(CITY_COORDINATES)) {
    if (lower.includes(city)) return coords;
  }
  return CITY_COORDINATES.johannesburg;
}

function statusColor(status: string): string {
  switch (status) {
    case 'pending':
      return colors.warning;
    case 'inTransit':
      return colors.info;
    case 'delivered':
      return colors.success;
    case 'failed':
      return colors.error;
    default:
      return colors.textSecondary;
  }
}

function statusText(status: string): string {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'inTransit':
      return 'In Transit';
    case 'delivered':
      return 'Delivered';
    case 'failed':
      return 'Failed';
    default:
      return status;
  }
}

function formatDateShort(date: Date): string {
  return `${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getDate()).padStart(2, '0')}`;
}

function dateOnlyMillis(date: Date): number {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

export default function LiveTracking() {
  const companyId = useAuthStore((s) => s.companyId);
  const mapRef = useRef<MapView>(null);
  const geocodeCacheRef = useRef<Record<string, LatLngLiteral>>({});

  const [startDate, setStartDate] = useState(() => new Date(Date.now() - 7 * 86400000));
  const [endDate, setEndDate] = useState(() => new Date());
  const [dateModalVisible, setDateModalVisible] = useState(false);
  const [startDateText, setStartDateText] = useState('');
  const [endDateText, setEndDateText] = useState('');

  const [refreshKey, setRefreshKey] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [deliveries, setDeliveries] = useState<Record<string, Delivery>>({});
  const [drivers, setDrivers] = useState<Record<string, DriverLocation>>({});
  const [podLocations, setPodLocations] = useState<Record<string, LatLngLiteral>>({});
  const [selectedDeliveryId, setSelectedDeliveryId] = useState<string | null>(null);

  const resolveDeliveryLocation = useCallback(async (delivery: Delivery) => {
    if (delivery.podId) {
      try {
        const podDoc = await firestore().collection('pods').doc(delivery.podId).get();
        const location = podDoc.data()?.location as { latitude?: number; longitude?: number } | undefined;
        if (location?.latitude != null && location?.longitude != null) {
          setPodLocations((prev) => ({ ...prev, [delivery.id]: { latitude: location.latitude!, longitude: location.longitude! } }));
          return;
        }
      } catch {
        // best-effort, matches the Dart source's silent catch-and-skip
      }
    }
    if (delivery.customerAddress) {
      const cached = geocodeCacheRef.current[delivery.customerAddress];
      const coords = cached ?? geocodeAddress(delivery.customerAddress);
      geocodeCacheRef.current[delivery.customerAddress] = coords;
      setPodLocations((prev) => ({ ...prev, [delivery.id]: coords }));
    }
  }, []);

  useEffect(() => {
    if (!companyId) return;
    setIsLoading(true);

    const startOnly = dateOnlyMillis(startDate);
    const endOnly = dateOnlyMillis(endDate);

    const unsubscribeDeliveries = firestore()
      .collection('deliveries')
      .where('companyId', '==', companyId)
      .where('status', 'in', ['pending', 'inTransit', 'delivered'])
      .onSnapshot((snapshot) => {
        const next: Record<string, Delivery> = {};
        snapshot.docs.forEach((doc) => {
          const delivery = deliveryFromFirestore(doc);
          const createdOnly = dateOnlyMillis(delivery.createdAt);
          if (createdOnly < startOnly || createdOnly > endOnly) return;
          next[delivery.id] = delivery;
          resolveDeliveryLocation(delivery);
        });
        setDeliveries(next);
        setIsLoading(false);
      });

    const unsubscribeDrivers = firestore()
      .collection('users')
      .where('companyId', '==', companyId)
      .where('role', '==', 'driver')
      .where('isActive', '==', true)
      .onSnapshot((snapshot) => {
        const next: Record<string, DriverLocation> = {};
        snapshot.docs.forEach((doc) => {
          const data = doc.data();
          const location = data.currentLocation as FirebaseFirestoreTypes.GeoPoint | undefined;
          if (location) {
            next[doc.id] = {
              id: doc.id,
              fullName: (data.fullName as string) ?? 'Unknown Driver',
              location: { latitude: location.latitude, longitude: location.longitude },
            };
          }
        });
        setDrivers(next);
      });

    return () => {
      unsubscribeDeliveries();
      unsubscribeDrivers();
    };
  }, [companyId, startDate, endDate, refreshKey, resolveDeliveryLocation]);

  const deliveryList = useMemo(() => Object.values(deliveries), [deliveries]);
  const driverList = useMemo(() => Object.values(drivers), [drivers]);

  const fitAllMarkers = useCallback(() => {
    const coords: LatLngLiteral[] = [
      ...deliveryList.map((d) => podLocations[d.id]).filter((c): c is LatLngLiteral => !!c),
      ...driverList.map((d) => d.location),
    ];
    if (coords.length === 0) return;
    mapRef.current?.fitToCoordinates(coords, { edgePadding: { top: 50, right: 50, bottom: 50, left: 50 }, animated: true });
  }, [deliveryList, driverList, podLocations]);

  const handleSelectDelivery = useCallback(
    (deliveryId: string) => {
      setSelectedDeliveryId(deliveryId);
      const target = podLocations[deliveryId];
      if (target) {
        mapRef.current?.animateToRegion({ ...target, latitudeDelta: 0.05, longitudeDelta: 0.05 }, 500);
      }
    },
    [podLocations],
  );

  const openDateModal = () => {
    setStartDateText(startDate.toISOString().slice(0, 10));
    setEndDateText(endDate.toISOString().slice(0, 10));
    setDateModalVisible(true);
  };

  const applyDateRange = () => {
    const parsedStart = new Date(startDateText);
    const parsedEnd = new Date(endDateText);
    if (!Number.isNaN(parsedStart.getTime())) setStartDate(parsedStart);
    if (!Number.isNaN(parsedEnd.getTime())) setEndDate(parsedEnd);
    setDateModalVisible(false);
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>📍 Live Tracking</Text>
        <View style={styles.headerActions}>
          <Pressable style={styles.dateChip} onPress={openDateModal}>
            <Text style={styles.dateChipText}>
              {formatDateShort(startDate)} - {formatDateShort(endDate)}
            </Text>
          </Pressable>
          <Pressable onPress={fitAllMarkers}>
            <Text style={styles.headerBarIcon}>⌖</Text>
          </Pressable>
          <Pressable onPress={() => setRefreshKey((k) => k + 1)}>
            <Text style={styles.headerBarIcon}>↻</Text>
          </Pressable>
        </View>
      </View>

      {isLoading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : (
        <View style={styles.body}>
          <View style={styles.sidebar}>
            <View style={styles.statsHeader}>
              <Text style={textStyles.heading3}>All Deliveries</Text>
              <View style={styles.statsRow}>
                <StatChip value={String(deliveryList.length)} label="Total" color={colors.info} icon="📦" />
                <StatChip value={String(driverList.length)} label="Drivers" color={colors.success} icon="🚚" />
              </View>
            </View>
            {deliveryList.length === 0 ? (
              <View style={styles.centered}>
                <Text style={styles.emptyText}>No deliveries</Text>
              </View>
            ) : (
              <FlatList
                data={deliveryList}
                keyExtractor={(item) => item.id}
                renderItem={({ item }) => {
                  const isSelected = selectedDeliveryId === item.id;
                  const color = statusColor(item.status);
                  return (
                    <Pressable style={[styles.deliveryCard, isSelected && styles.deliveryCardSelected]} onPress={() => handleSelectDelivery(item.id)}>
                      <Text style={styles.deliveryIcon}>🚚</Text>
                      <View style={styles.deliveryTextBox}>
                        <Text style={styles.deliveryName}>{item.customerName}</Text>
                        <Text style={styles.deliveryAddress} numberOfLines={1}>
                          {item.customerAddress}
                        </Text>
                        <View style={styles.deliveryStatusRow}>
                          <Text style={[styles.deliveryStatusText, { color }]}>{statusText(item.status)}</Text>
                          {!podLocations[item.id] ? <ActivityIndicator size="small" color={color} style={styles.deliveryStatusSpinner} /> : null}
                        </View>
                      </View>
                      <Text style={styles.deliveryChevron}>›</Text>
                    </Pressable>
                  );
                }}
              />
            )}
          </View>

          <MapView ref={mapRef} style={styles.map} initialRegion={INITIAL_REGION} onMapReady={() => setTimeout(fitAllMarkers, 500)}>
            {deliveryList.map((delivery) => {
              const location = podLocations[delivery.id];
              if (!location) return null;
              const isSelected = selectedDeliveryId === delivery.id;
              const color = statusColor(delivery.status);
              const driver = delivery.driverId ? drivers[delivery.driverId] : undefined;

              return (
                <React.Fragment key={delivery.id}>
                  <Marker coordinate={location} pinColor={color} opacity={isSelected ? 1 : 0.7} onPress={() => handleSelectDelivery(delivery.id)}>
                    <Callout onPress={() => handleSelectDelivery(delivery.id)}>
                      <View style={styles.callout}>
                        <Text style={styles.calloutTitle}>📦 {delivery.customerName}</Text>
                        <Text style={styles.calloutSubtitle}>
                          {statusText(delivery.status)} - {delivery.customerAddress}
                        </Text>
                      </View>
                    </Callout>
                  </Marker>
                  {driver ? (
                    <Polyline
                      coordinates={[driver.location, location]}
                      strokeColor={isSelected ? colors.primary : `${colors.primary}80`}
                      strokeWidth={isSelected ? 4 : 2}
                      lineDashPattern={[20, 10]}
                    />
                  ) : null}
                </React.Fragment>
              );
            })}

            {driverList.map((driver) => (
              <Marker key={driver.id} coordinate={driver.location} pinColor={colors.success}>
                <Callout>
                  <View style={styles.callout}>
                    <Text style={styles.calloutTitle}>🚗 {driver.fullName}</Text>
                    <Text style={styles.calloutSubtitle}>Active driver</Text>
                  </View>
                </Callout>
              </Marker>
            ))}
          </MapView>
        </View>
      )}

      <Modal visible={dateModalVisible} transparent animationType="fade" onRequestClose={() => setDateModalVisible(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Date Range</Text>
            <View style={styles.gap} />
            <Text style={styles.inputLabel}>Start Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.input} value={startDateText} onChangeText={setStartDateText} placeholder="YYYY-MM-DD" />
            <View style={styles.gap} />
            <Text style={styles.inputLabel}>End Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.input} value={endDateText} onChangeText={setEndDateText} placeholder="YYYY-MM-DD" />
            <View style={styles.modalActionsRow}>
              <Pressable style={styles.secondaryButton} onPress={() => setDateModalVisible(false)}>
                <Text style={styles.secondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalCloseButton} onPress={applyDateRange}>
                <Text style={textStyles.buttonText}>Apply</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

function StatChip({ value, label, color, icon }: { value: string; label: string; color: string; icon: string }) {
  return (
    <View style={[styles.statChip, { backgroundColor: color }]}>
      <Text style={styles.statChipIcon}>{icon}</Text>
      <Text style={styles.statChipValue}>{value}</Text>
      <Text style={styles.statChipLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  headerActions: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  headerBarIcon: { fontSize: 20, color: colors.white },
  dateChip: { backgroundColor: 'rgba(255,255,255,0.2)', borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small },
  dateChipText: { color: colors.white, fontSize: 12, fontWeight: '600' },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 350, backgroundColor: colors.card, borderRightWidth: 1, borderRightColor: colors.divider },
  statsHeader: { padding: spacing.medium, backgroundColor: colors.background },
  statsRow: { flexDirection: 'row', gap: spacing.small, marginTop: spacing.small },
  statChip: { flexDirection: 'row', alignItems: 'center', borderRadius: 16, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small },
  statChipIcon: { fontSize: 14, marginRight: 4 },
  statChipValue: { color: colors.white, fontWeight: 'bold', fontSize: 13, marginRight: 4 },
  statChipLabel: { color: colors.white, fontSize: 11 },
  emptyText: { color: colors.textSecondary },
  deliveryCard: { flexDirection: 'row', alignItems: 'center', padding: spacing.medium, borderBottomWidth: 1, borderBottomColor: colors.divider },
  deliveryCardSelected: { backgroundColor: `${colors.primary}1A` },
  deliveryIcon: { fontSize: 20, marginRight: spacing.small + 4 },
  deliveryTextBox: { flex: 1, marginRight: spacing.small },
  deliveryName: { fontWeight: 'bold' },
  deliveryAddress: { color: colors.textSecondary, fontSize: 13, marginTop: 2 },
  deliveryStatusRow: { flexDirection: 'row', alignItems: 'center', marginTop: 4 },
  deliveryStatusText: { fontWeight: '500', fontSize: 12 },
  deliveryStatusSpinner: { marginLeft: 6 },
  deliveryChevron: { fontSize: 20, color: colors.textSecondary },
  map: { flex: 1 },
  callout: { minWidth: 160, maxWidth: 240 },
  calloutTitle: { fontWeight: 'bold' },
  calloutSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 440 },
  gap: { height: spacing.medium },
  inputLabel: { fontSize: 13, fontWeight: '600', color: colors.textSecondary, marginBottom: spacing.small },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, fontSize: 15, color: colors.textPrimary },
  modalActionsRow: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.medium, marginTop: spacing.large },
  secondaryButton: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4 },
  secondaryButtonText: { color: colors.textSecondary, fontWeight: '600' },
  modalCloseButton: { backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingHorizontal: spacing.large, paddingVertical: spacing.small + 4, alignItems: 'center', minWidth: 80 },
});
