import React, { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { PodRepository } from '../../repositories/podRepository';
import { PodRecord } from '../../models/pod';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/pod_viewer_screen.dart
 * (`PODViewerMobile`, verified against source on 2026-06-22) — list of every proof of
 * delivery filed in the company, with an All/Today/This Week/This Month date filter.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the
 * >1000px desktop branch lands in Phase 4.
 *
 * Deviations from the Flutter source:
 * - Reads `customerNumber`/`orderNumber`/`stampPhotoUrl` from `pod.metadata` instead of
 *   top-level fields. Those were never part of the Dart `PODRecord` *class* either —
 *   `pod_capture_screen.dart` writes them as extra ad-hoc keys straight onto the raw
 *   Firestore map. The RN port's `usePodStore.submitPod()` (built in Phase 2) already
 *   chose to nest that same data inside the typed `metadata` field instead of
 *   replicating an untyped top-level sprawl — this screen reads it from there to match
 *   what the existing pipeline actually writes. `receiverName` does have a proper typed
 *   field (`signedBy`), used directly instead of reaching into `metadata` for it.
 * - Added `podRepository.subscribeToCompanyPods()` this pass (only `getPodById` existed
 *   before — no admin list view had been built yet).
 * - The filter `PopupMenuButton` becomes a header icon opening an action-sheet Modal
 *   (house convention, same pattern as DeliveryManagement.tsx's export menu).
 * - Tapping a card navigates to a `PodDetails` route that doesn't exist yet —
 *   pod_details_screen.dart needs FirebaseStorageImage/LocationMapWidget/
 *   PodImageDownloadService/PodPdfGeneratorService, none ported yet — same
 *   forward-reference pattern as other not-yet-built destinations this phase.
 */
type DateFilter = 'all' | 'today' | 'week' | 'month';

const FILTER_LABELS: Record<DateFilter, string> = {
  all: 'All PODs',
  today: 'Today',
  week: 'This Week',
  month: 'This Month',
};

interface PodViewerProps {
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void };
}

const podRepository = new PodRepository();

function filterSinceDate(filter: DateFilter): Date | undefined {
  const now = new Date();
  switch (filter) {
    case 'today':
      return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    case 'week':
      return new Date(now.getTime() - 7 * 86400000);
    case 'month':
      return new Date(now.getFullYear(), now.getMonth(), 1);
    case 'all':
      return undefined;
  }
}

export default function PodViewer({ navigation }: PodViewerProps) {
  const currentUser = useAuthStore((s) => s.currentUser);

  const [filter, setFilter] = useState<DateFilter>('all');
  const [showFilterMenu, setShowFilterMenu] = useState(false);
  const [pods, setPods] = useState<PodRecord[] | null>(null);
  const [hasError, setHasError] = useState(false);

  useEffect(() => {
    if (!currentUser) return;
    setPods(null);
    setHasError(false);

    const unsubscribe = podRepository.subscribeToCompanyPods(
      currentUser.companyId,
      setPods,
      () => setHasError(true),
      { since: filterSinceDate(filter) },
    );

    return unsubscribe;
  }, [currentUser, filter]);

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Text style={textStyles.heading2}>Proof of Deliveries</Text>
        <Pressable onPress={() => setShowFilterMenu(true)}>
          <Text style={styles.headerBarIcon}>▾ {FILTER_LABELS[filter]}</Text>
        </Pressable>
      </View>

      {hasError ? (
        <View style={styles.centered}>
          <Text style={styles.errorIcon}>⚠</Text>
          <Text style={styles.errorText}>Error loading PODs</Text>
        </View>
      ) : pods === null ? (
        <View style={styles.centered}>
          <ActivityIndicator color={colors.primary} />
        </View>
      ) : pods.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.emptyIcon}>🧾</Text>
          <Text style={styles.emptyText}>No PODs yet</Text>
          <Text style={styles.emptyHint}>Proof of deliveries will appear here</Text>
        </View>
      ) : (
        <FlatList
          data={pods}
          keyExtractor={(pod) => pod.id}
          contentContainerStyle={styles.listContent}
          renderItem={({ item }) => <PodCard pod={item} onPress={() => navigation.navigate('PodDetails', { deliveryId: item.deliveryId })} />}
        />
      )}

      <Modal visible={showFilterMenu} transparent animationType="fade" onRequestClose={() => setShowFilterMenu(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowFilterMenu(false)}>
          <View style={[styles.actionSheet, shadows.card]}>
            {(Object.keys(FILTER_LABELS) as DateFilter[]).map((key) => (
              <Pressable
                key={key}
                style={styles.actionRow}
                onPress={() => {
                  setFilter(key);
                  setShowFilterMenu(false);
                }}
              >
                <Text style={styles.actionRowGlyph}>{filter === key ? '◉' : '○'}</Text>
                <Text style={styles.actionRowLabel}>{FILTER_LABELS[key]}</Text>
              </Pressable>
            ))}
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

function PodCard({ pod, onPress }: { pod: PodRecord; onPress: () => void }) {
  const hasSignature = Boolean(pod.signatureUrl);
  const hasPhoto = Boolean(pod.photoUrl);
  const hasStampPhoto = Boolean(pod.metadata.stampPhotoUrl);
  const hasLocation = Boolean(pod.location);
  const customerNumber = pod.metadata.customerNumber as string | undefined;
  const orderNumber = pod.metadata.orderNumber as string | undefined;
  const invoiceNumber = pod.invoiceNumber;

  return (
    <Pressable style={[styles.card, shadows.card]} onPress={onPress}>
      <View style={styles.cardTopRow}>
        <View style={styles.cardIconBox}>
          <Text style={styles.cardIconText}>✓</Text>
        </View>
        <View style={styles.cardTextBox}>
          <Text style={styles.cardTitle}>Delivery #{pod.deliveryId.substring(0, 8)}</Text>
          <Text style={styles.cardSubtitle}>{pod.timestamp.toLocaleString(undefined, { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })}</Text>
        </View>
        <Text style={styles.cardChevron}>›</Text>
      </View>

      <View style={styles.tagRow}>
        {customerNumber ? <Tag label="Customer #" value={customerNumber} /> : null}
        {pod.signedBy ? <Tag label="Receiver" value={pod.signedBy} /> : null}
        {invoiceNumber ? <Tag label="Invoice #" value={invoiceNumber} /> : null}
        {orderNumber ? <Tag label="Order #" value={orderNumber} /> : null}
      </View>

      <View style={styles.divider} />

      <View style={styles.featuresRow}>
        <Feature icon="✎" label="Signature" active={hasSignature} />
        <Feature icon="📷" label="Photo" active={hasPhoto} />
        {hasStampPhoto ? <Feature icon="🧾" label="Stamp" active /> : null}
        <Feature icon="📍" label="GPS" active={hasLocation} />
      </View>
    </Pressable>
  );
}

function Tag({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.tag}>
      <Text style={styles.tagLabel}>{label}</Text>
      <Text style={styles.tagValue}>{value}</Text>
    </View>
  );
}

function Feature({ icon, label, active }: { icon: string; label: string; active: boolean }) {
  return (
    <View style={styles.feature}>
      <Text style={[styles.featureIcon, { color: active ? colors.success : colors.textSecondary }]}>{icon}</Text>
      <Text style={[styles.featureLabel, { color: active ? colors.success : colors.textSecondary }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.large, paddingVertical: spacing.medium },
  headerBarIcon: { color: colors.white, fontSize: 14, fontWeight: '600' },
  errorIcon: { fontSize: 48, color: colors.error },
  errorText: { color: colors.error, marginTop: spacing.small + 4 },
  emptyIcon: { fontSize: 56, opacity: 0.3 },
  emptyText: { fontSize: 17, fontWeight: '600', color: colors.textSecondary, marginTop: spacing.medium },
  emptyHint: { fontSize: 13, color: colors.textSecondary, marginTop: spacing.small },
  listContent: { padding: spacing.medium },
  card: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, marginBottom: spacing.medium },
  cardTopRow: { flexDirection: 'row', alignItems: 'center' },
  cardIconBox: { width: 44, height: 44, borderRadius: radii.borderRadius, backgroundColor: `${colors.success}1A`, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  cardIconText: { fontSize: 20, color: colors.success },
  cardTextBox: { flex: 1 },
  cardTitle: { fontSize: 16, fontWeight: '600' },
  cardSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  cardChevron: { fontSize: 20, color: colors.textSecondary },
  tagRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small, marginTop: spacing.medium },
  tag: { backgroundColor: colors.background, borderRadius: 4, paddingHorizontal: spacing.small + 4, paddingVertical: 4 },
  tagLabel: { fontSize: 10, color: colors.textSecondary, fontWeight: '500' },
  tagValue: { fontSize: 12, fontWeight: '600' },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.medium },
  featuresRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.large },
  feature: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  featureIcon: { fontSize: 14 },
  featureLabel: { fontSize: 12 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  actionSheet: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.medium, width: '100%', maxWidth: 320 },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowGlyph: { fontSize: 16, color: colors.primary, marginRight: spacing.medium },
  actionRowLabel: { fontSize: 15, fontWeight: '600' },
});
