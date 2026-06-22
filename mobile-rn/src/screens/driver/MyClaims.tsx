// expects: no route params. Reads the signed-in driver from useAuthStore. Navigating to
// a claim's detail screen should pass { claimId: string } (see ClaimDetails.tsx).
import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, RefreshControl, StyleSheet, Text, TextInput, View } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { Claim, ClaimStatus, claimStatusDisplayText, claimTypeDisplayText } from '../../models/claim';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/driver/my_claims_screen.dart. Status filter chips + free-text
 * search are client-side over the driver's own claims, same as the Flutter screen.
 *
 * Deviation: the Flutter screen re-filters claimProvider.claims by driverId again in the
 * widget itself (belt-and-suspenders on top of the provider's own driverIdFilter); since
 * useClaimStore.loadClaimsForDriver already sets driverIdFilter and the subscription is
 * scoped server-side, that redundant client-side filter is not repeated here.
 */

const STATUS_CHIPS: Array<{ label: string; status: ClaimStatus | null }> = [
  { label: 'All', status: null },
  { label: 'Submitted', status: 'submitted' },
  { label: 'Under Review', status: 'pendingReview' },
  { label: 'Approved', status: 'approved' },
  { label: 'Rejected', status: 'rejected' },
  { label: 'Resolved', status: 'resolved' },
];

function statusBadgeColors(status: ClaimStatus): { background: string; text: string } {
  switch (status) {
    case 'draft':
      return { background: '#E0E0E0', text: '#424242' };
    case 'submitted':
      return { background: '#BBDEFB', text: '#0D47A1' };
    case 'pendingReview':
      return { background: '#FFE0B2', text: '#E65100' };
    case 'investigating':
      return { background: '#E1BEE7', text: '#4A148C' };
    case 'pendingDriverResponse':
      return { background: '#FFECB3', text: '#FF6F00' };
    case 'driverResponded':
      return { background: '#B2DFDB', text: '#004D40' };
    case 'pendingApproval':
    case 'pendingSecondApproval':
    case 'pendingProcessing':
    case 'processing':
    case 'pendingFinalReview':
      return { background: '#C5CAE9', text: '#1A237E' };
    case 'approved':
      return { background: '#C8E6C9', text: '#1B5E20' };
    case 'rejected':
      return { background: '#FFCDD2', text: '#B71C1C' };
    case 'resolved':
      return { background: '#B2DFDB', text: '#004D40' };
    case 'closed':
      return { background: '#BDBDBD', text: '#212121' };
    case 'cancelled':
      return { background: '#E0E0E0', text: '#616161' };
    case 'disputed':
      return { background: '#FFCCBC', text: '#BF360C' };
    default:
      return { background: colors.divider, text: colors.textSecondary };
  }
}

function formatRelativeDate(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMinutes = Math.floor(diffMs / (1000 * 60));
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    if (diffHours === 0) {
      return diffMinutes <= 0 ? 'Just now' : `${diffMinutes}m ago`;
    }
    return `${diffHours}h ago`;
  } else if (diffDays === 1) {
    return 'Yesterday';
  } else if (diffDays < 7) {
    return `${diffDays} days ago`;
  }
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

export default function MyClaims({ navigation }: { navigation: { navigate: (screen: string, params: { claimId: string }) => void } }) {
  const currentUser = useAuthStore((s) => s.currentUser);
  const claims = useClaimStore((s) => s.claims);
  const isLoading = useClaimStore((s) => s.isLoading);
  const errorMessage = useClaimStore((s) => s.errorMessage);
  const statusFilter = useClaimStore((s) => s.statusFilter);
  const setStatusFilter = useClaimStore((s) => s.setStatusFilter);
  const setSearchQuery = useClaimStore((s) => s.setSearchQuery);
  const initialize = useClaimStore((s) => s.initialize);
  const loadClaimsForDriver = useClaimStore((s) => s.loadClaimsForDriver);
  const companyId = useClaimStore((s) => s.companyId);

  const [searchText, setSearchText] = useState('');
  const [isRefreshing, setIsRefreshing] = useState(false);

  const loadClaims = useCallback(async () => {
    if (!currentUser) return;
    if (!companyId) {
      await initialize(currentUser.companyId);
    }
    loadClaimsForDriver(currentUser.id);
  }, [currentUser, companyId, initialize, loadClaimsForDriver]);

  useEffect(() => {
    loadClaims();
  }, [loadClaims]);

  const handleRefresh = useCallback(async () => {
    setIsRefreshing(true);
    await loadClaims();
    setIsRefreshing(false);
  }, [loadClaims]);

  const handleSearchChange = (text: string) => {
    setSearchText(text);
    setSearchQuery(text.length > 0 ? text : null);
  };

  const sortedClaims = [...claims].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

  return (
    <View style={styles.container}>
      <View style={styles.filterBar}>
        <Text style={[textStyles.bodySmall, styles.filterLabel]}>Filter by Status</Text>
        <FlatList
          horizontal
          showsHorizontalScrollIndicator={false}
          data={STATUS_CHIPS}
          keyExtractor={(item) => item.label}
          renderItem={({ item }) => (
            <StatusChip label={item.label} selected={statusFilter === item.status} onPress={() => setStatusFilter(item.status)} />
          )}
          contentContainerStyle={styles.chipRow}
        />
      </View>

      <View style={styles.searchBar}>
        <TextInput
          style={styles.searchInput}
          placeholder="Search by claim ID, customer, or description..."
          value={searchText}
          onChangeText={handleSearchChange}
        />
      </View>

      {isLoading && claims.length === 0 ? (
        <ActivityIndicator style={styles.loadingIndicator} color={colors.primary} />
      ) : errorMessage ? (
        <View style={styles.centered}>
          <Text style={styles.errorText}>{errorMessage}</Text>
          <Pressable style={styles.retryButton} onPress={loadClaims}>
            <Text style={textStyles.buttonText}>Retry</Text>
          </Pressable>
        </View>
      ) : sortedClaims.length === 0 ? (
        <View style={styles.centered}>
          <Text style={textStyles.bodyLarge}>{statusFilter || searchText ? 'No claims match your filters' : 'No claims filed yet'}</Text>
          <Text style={[textStyles.bodySmall, styles.emptySubtext]}>
            {statusFilter || searchText ? 'Try adjusting your filters' : 'File a claim from any delivery'}
          </Text>
        </View>
      ) : (
        <FlatList
          data={sortedClaims}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={handleRefresh} colors={[colors.primary]} />}
          renderItem={({ item }) => (
            <ClaimCard claim={item} onPress={() => navigation.navigate('ClaimDetails', { claimId: item.id })} />
          )}
        />
      )}
    </View>
  );
}

function StatusChip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function ClaimCard({ claim, onPress }: { claim: Claim; onPress: () => void }) {
  const badge = statusBadgeColors(claim.status);

  return (
    <Pressable style={styles.card} onPress={onPress}>
      <View style={styles.cardHeaderRow}>
        <View style={styles.cardHeaderText}>
          <Text style={[textStyles.heading3, styles.invoiceText]}>{claim.invoiceNumber ?? claim.id}</Text>
          <Text style={textStyles.bodyMedium}>{claimTypeDisplayText(claim.type)}</Text>
        </View>
        <View style={[styles.statusBadge, { backgroundColor: badge.background }]}>
          <Text style={[styles.statusBadgeText, { color: badge.text }]}>{claimStatusDisplayText(claim.status)}</Text>
        </View>
      </View>

      <InfoRow label="Customer" value={claim.customerName} />
      <InfoRow label="Filed" value={formatRelativeDate(claim.createdAt)} />
      {claim.description ? <InfoRow label="Description" value={claim.description} /> : null}

      <View style={styles.metaRow}>
        {claim.photoUrls.length > 0 ? (
          <Text style={styles.metaText}>
            {claim.photoUrls.length} photo{claim.photoUrls.length > 1 ? 's' : ''}
          </Text>
        ) : null}
        {claim.customerSignatureUrl ? <Text style={styles.metaText}>Signature</Text> : null}
        {claim.affectedItems.length > 0 ? (
          <Text style={styles.metaText}>
            {claim.affectedItems.length} item{claim.affectedItems.length > 1 ? 's' : ''}
          </Text>
        ) : null}
      </View>
    </Pressable>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <Text style={[textStyles.bodySmall, styles.infoRow]} numberOfLines={2}>
      <Text style={styles.infoLabel}>{label}: </Text>
      {value}
    </Text>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  filterBar: { backgroundColor: colors.card, padding: spacing.medium },
  filterLabel: { fontWeight: '600', marginBottom: spacing.small },
  chipRow: { gap: spacing.small },
  chip: {
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.small + 4,
    paddingVertical: 6,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.divider,
  },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  searchBar: { padding: spacing.medium, paddingTop: spacing.small },
  searchInput: {
    backgroundColor: colors.card,
    borderRadius: radii.borderRadius,
    borderWidth: 1,
    borderColor: colors.divider,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 2,
  },
  loadingIndicator: { marginTop: spacing.xLarge },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  errorText: { color: colors.error, textAlign: 'center', marginBottom: spacing.medium },
  retryButton: {
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.small + 4,
  },
  emptySubtext: { marginTop: spacing.small },
  listContent: { padding: spacing.medium },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
    marginBottom: spacing.medium,
    ...shadows.card,
  },
  cardHeaderRow: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: spacing.small + 4 },
  cardHeaderText: { flex: 1 },
  invoiceText: { color: colors.primary },
  statusBadge: { borderRadius: 16, paddingHorizontal: spacing.small + 4, paddingVertical: 6 },
  statusBadgeText: { fontSize: 12, fontWeight: '600' },
  infoRow: { marginBottom: spacing.small / 2 },
  infoLabel: { fontWeight: '600', color: colors.textSecondary },
  metaRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.small },
  metaText: { fontSize: 12, color: colors.textSecondary },
});
