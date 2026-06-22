// expects route.params: { claimId: string }
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Image, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useClaimStore } from '../../stores/useClaimStore';
import { ClaimStatus, claimTypeDisplayText } from '../../models/claim';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/driver/driver_claim_details_screen.dart (read-only claim view
 * for drivers).
 *
 * Deviations from the Flutter source:
 * - Takes only `claimId` via route params and loads through the store (matches the
 *   established pattern in DeliveryDetails.tsx), rather than receiving the full `Claim`
 *   object as a constructor arg.
 * - The full-screen photo viewer is a plain Modal + Image (no pinch-to-zoom library is
 *   installed — see Section 2 of the migration plan, which scopes cached-image handling
 *   to RN's built-in Image). InteractiveViewer's pinch-zoom is not reproduced.
 * - Status badge intentionally mirrors this screen's simpler 5-case Dart switch
 *   (pendingReview/approved/rejected/submitted/default), not MyClaims.tsx's richer
 *   per-status color map — the two Flutter screens use different badge richness and this
 *   keeps that same distinction.
 */

interface ClaimDetailsProps {
  route: { params: { claimId: string } };
}

function statusBadge(status: ClaimStatus): { color: string; label: string } {
  switch (status) {
    case 'pendingReview':
      return { color: colors.warning, label: 'Under Review' };
    case 'approved':
      return { color: colors.success, label: 'Approved' };
    case 'rejected':
      return { color: colors.error, label: 'Rejected' };
    case 'submitted':
      return { color: colors.info, label: 'Submitted' };
    default:
      return { color: colors.textSecondary, label: 'Unknown' };
  }
}

function formatDate(date: Date): string {
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

function formatDateTime(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${formatDate(date)} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export default function ClaimDetails({ route }: ClaimDetailsProps) {
  const { claimId } = route.params;
  const selectedClaim = useClaimStore((s) => s.selectedClaim);
  const getClaimById = useClaimStore((s) => s.getClaimById);
  const setSelectedClaim = useClaimStore((s) => s.setSelectedClaim);
  const errorMessage = useClaimStore((s) => s.errorMessage);

  const [isLoading, setIsLoading] = useState(true);
  const [viewerPhotoUrl, setViewerPhotoUrl] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    getClaimById(claimId).then((claim) => {
      if (isMounted) {
        setSelectedClaim(claim);
        setIsLoading(false);
      }
    });
    return () => {
      isMounted = false;
    };
  }, [claimId, getClaimById, setSelectedClaim]);

  const claim = selectedClaim?.id === claimId ? selectedClaim : null;

  if (isLoading && !claim) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  if (!claim) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>{errorMessage ?? 'Claim not found'}</Text>
      </View>
    );
  }

  const badge = statusBadge(claim.status);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.card}>
        <View style={styles.headerRow}>
          <View style={styles.headerText}>
            <Text style={[textStyles.heading3, styles.invoiceText]}>{claim.invoiceNumber ?? claim.id}</Text>
            <Text style={textStyles.bodyMedium}>{claimTypeDisplayText(claim.type)}</Text>
          </View>
          <View style={[styles.statusBadge, { backgroundColor: `${badge.color}1A`, borderColor: `${badge.color}4D` }]}>
            <Text style={[styles.statusBadgeText, { color: badge.color }]}>{badge.label}</Text>
          </View>
        </View>
        <Text style={[textStyles.bodyMedium, styles.description]}>{claim.description}</Text>
      </View>

      <View style={styles.card}>
        <Text style={textStyles.heading3}>Claim Details</Text>
        <View style={styles.divider} />
        <DetailRow label="Filed Date" value={formatDateTime(claim.createdAt)} />
        <DetailRow label="Delivery Date" value={formatDate(claim.deliveryDate)} />
        {claim.claimAmount != null ? <DetailRow label="Claim Amount" value={claim.claimAmount.toFixed(2)} /> : null}
        <DetailRow label="Customer" value={claim.customerName} />
        {claim.customerAccountNumber ? <DetailRow label="Account Number" value={claim.customerAccountNumber} /> : null}
      </View>

      {claim.photoUrls.length > 0 ? (
        <View style={styles.card}>
          <Text style={textStyles.heading3}>Photos</Text>
          <View style={styles.divider} />
          <View style={styles.photoGrid}>
            {claim.photoUrls.map((url, index) => (
              <Pressable key={`${url}-${index}`} style={styles.photoThumb} onPress={() => setViewerPhotoUrl(url)}>
                <Image source={{ uri: url }} style={styles.photoThumbImage} resizeMode="cover" />
              </Pressable>
            ))}
          </View>
        </View>
      ) : null}

      <View style={styles.card}>
        <Text style={textStyles.heading3}>Status History</Text>
        <View style={styles.divider} />
        <StatusItem label="Filed" date={claim.createdAt} />
        {claim.status === 'approved' ? (
          <StatusItem label="Approved" date={claim.updatedAt} />
        ) : claim.status === 'rejected' ? (
          <StatusItem label="Rejected" date={claim.updatedAt} />
        ) : claim.status === 'pendingReview' ? (
          <StatusItem label="Under Review" date={claim.updatedAt} />
        ) : null}
      </View>

      <Modal visible={viewerPhotoUrl !== null} transparent animationType="fade" onRequestClose={() => setViewerPhotoUrl(null)}>
        <View style={styles.viewerBackdrop}>
          {viewerPhotoUrl ? <Image source={{ uri: viewerPhotoUrl }} style={styles.viewerImage} resizeMode="contain" /> : null}
          <Pressable style={styles.viewerCloseButton} onPress={() => setViewerPhotoUrl(null)}>
            <Text style={styles.viewerCloseText}>✕</Text>
          </Pressable>
        </View>
      </Modal>
    </ScrollView>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={[textStyles.bodySmall, styles.detailLabel]}>{label}</Text>
      <Text style={[textStyles.bodyMedium, styles.detailValue]}>{value}</Text>
    </View>
  );
}

function StatusItem({ label, date }: { label: string; date: Date }) {
  return (
    <View style={styles.statusItemRow}>
      <View style={styles.statusItemDot} />
      <View style={styles.statusItemTextBox}>
        <Text style={textStyles.bodyMedium}>{label}</Text>
        <Text style={textStyles.bodySmall}>{formatDateTime(date)}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.medium },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
    ...shadows.card,
  },
  headerRow: { flexDirection: 'row', alignItems: 'flex-start' },
  headerText: { flex: 1 },
  invoiceText: { color: colors.primary },
  statusBadge: { borderRadius: 20, paddingHorizontal: spacing.small + 4, paddingVertical: 6, borderWidth: 1 },
  statusBadgeText: { fontSize: 12, fontWeight: '600' },
  description: { marginTop: spacing.medium, lineHeight: 22 },
  divider: { height: 1, backgroundColor: colors.divider, marginVertical: spacing.small + 4 },
  detailRow: { flexDirection: 'row', marginBottom: spacing.small + 4 },
  detailLabel: { width: 120, fontWeight: '600', color: colors.textSecondary },
  detailValue: { flex: 1 },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  photoThumb: { width: '48%', aspectRatio: 1, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.divider },
  photoThumbImage: { width: '100%', height: '100%' },
  statusItemRow: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: spacing.small + 4 },
  statusItemDot: { width: 12, height: 12, borderRadius: 6, backgroundColor: colors.success, marginRight: spacing.small + 4, marginTop: 4 },
  statusItemTextBox: { flex: 1 },
  viewerBackdrop: { flex: 1, backgroundColor: 'black', alignItems: 'center', justifyContent: 'center' },
  viewerImage: { width: '100%', height: '100%' },
  viewerCloseButton: { position: 'absolute', top: spacing.large, right: spacing.large, padding: spacing.small },
  viewerCloseText: { color: 'white', fontSize: 28 },
});
