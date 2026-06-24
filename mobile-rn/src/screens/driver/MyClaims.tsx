import React, { useCallback, useEffect, useState } from 'react';
import { FlatList, Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';
import { AppIcon, Card, EmptyState, ErrorState, LoadingState, Screen, SearchField, StatusChip } from '../../components/ui';
import { Claim, ClaimStatus, claimStatusDisplayText, claimTypeDisplayText } from '../../models/claim';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { colors, radii, spacing } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const filters: Array<{ label: string; status: ClaimStatus | null }> = [
  { label: 'All', status: null }, { label: 'Submitted', status: 'submitted' }, { label: 'Under review', status: 'pendingReview' },
  { label: 'Approved', status: 'approved' }, { label: 'Rejected', status: 'rejected' }, { label: 'Resolved', status: 'resolved' },
];

function statusTone(status: ClaimStatus): 'neutral' | 'info' | 'success' | 'warning' | 'error' {
  if (['approved', 'resolved', 'closed'].includes(status)) return 'success';
  if (['rejected', 'cancelled', 'disputed'].includes(status)) return 'error';
  if (['submitted', 'pendingReview', 'investigating', 'pendingDriverResponse'].includes(status)) return 'warning';
  if (['driverResponded', 'pendingApproval', 'pendingSecondApproval', 'pendingProcessing', 'processing', 'pendingFinalReview'].includes(status)) return 'info';
  return 'neutral';
}

function formatRelativeDate(date: Date): string {
  const days = Math.floor((Date.now() - date.getTime()) / 86400000);
  if (days <= 0) return 'Today';
  if (days === 1) return 'Yesterday';
  if (days < 7) return `${days} days ago`;
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
    if (!companyId) await initialize(currentUser.companyId);
    await loadClaimsForDriver(currentUser.id);
  }, [companyId, currentUser, initialize, loadClaimsForDriver]);

  useEffect(() => { loadClaims(); }, [loadClaims]);
  const refresh = useCallback(async () => { setIsRefreshing(true); await loadClaims(); setIsRefreshing(false); }, [loadClaims]);
  const changeSearch = (value: string) => { setSearchText(value); setSearchQuery(value || null); };
  const sortedClaims = [...claims].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

  if (isLoading && claims.length === 0) return <Screen><LoadingState title="Loading claims" /></Screen>;
  if (errorMessage) return <Screen><ErrorState title="Claims could not be loaded" message={errorMessage} onAction={loadClaims} /></Screen>;

  return (
    <Screen contentContainerStyle={styles.screen}>
      <View style={styles.toolbar}>
        <Text style={textStyles.heading2}>My claims</Text>
        <SearchField value={searchText} onChangeText={changeSearch} placeholder="Search claim, customer, or description" />
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filters}>
          {filters.map((filter) => {
            const selected = statusFilter === filter.status;
            return <Pressable key={filter.label} accessibilityRole="button" accessibilityState={{ selected }} accessibilityLabel={`Filter claims by ${filter.label}`} onPress={() => setStatusFilter(filter.status)} style={({ pressed }) => [styles.filter, selected && styles.filterSelected, pressed && styles.filterPressed]}><Text style={[styles.filterText, selected && styles.filterTextSelected]}>{filter.label}</Text></Pressable>;
          })}
        </ScrollView>
      </View>
      <FlatList
        data={sortedClaims}
        keyExtractor={(claim) => claim.id}
        contentContainerStyle={styles.list}
        refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={refresh} colors={[colors.active]} />}
        ListHeaderComponent={<Text style={[textStyles.heading3, styles.count]}>{sortedClaims.length} claim{sortedClaims.length === 1 ? '' : 's'}</Text>}
        ListEmptyComponent={<EmptyState title={statusFilter || searchText ? 'No matching claims' : 'No claims filed'} message={statusFilter || searchText ? 'Adjust the search or status filter to see more results.' : 'You can report an issue from an assigned delivery.'} icon="report" />}
        renderItem={({ item }) => <ClaimCard claim={item} onPress={() => navigation.navigate('ClaimDetails', { claimId: item.id })} />}
      />
    </Screen>
  );
}

function ClaimCard({ claim, onPress }: { claim: Claim; onPress: () => void }) {
  return <Pressable accessibilityRole="button" accessibilityLabel={`View claim ${claim.invoiceNumber ?? claim.id}`} onPress={onPress} style={({ pressed }) => pressed && styles.pressed}><Card style={styles.card}><View style={styles.cardHeader}><View style={styles.cardCopy}><Text style={textStyles.heading3}>{claim.invoiceNumber ?? claim.id}</Text><Text style={textStyles.bodyMedium}>{claimTypeDisplayText(claim.type)}</Text></View><StatusChip label={claimStatusDisplayText(claim.status)} tone={statusTone(claim.status)} /></View><Info label="Customer" value={claim.customerName} /><Info label="Filed" value={formatRelativeDate(claim.createdAt)} />{claim.description ? <Info label="Description" value={claim.description} /> : null}<View style={styles.evidence}><AppIcon name="image" size={16} color={colors.contentSecondary} /><Text style={textStyles.bodySmall}>{claim.photoUrls.length} photo{claim.photoUrls.length === 1 ? '' : 's'}</Text>{claim.customerSignatureUrl ? <><AppIcon name="signature" size={16} color={colors.contentSecondary} /><Text style={textStyles.bodySmall}>Signature attached</Text></> : null}</View></Card></Pressable>;
}

function Info({ label, value }: { label: string; value: string }) { return <View style={styles.info}><Text style={textStyles.labelSmall}>{label}</Text><Text numberOfLines={2} style={textStyles.bodyMedium}>{value}</Text></View>; }

const styles = StyleSheet.create({
  screen: { paddingHorizontal: 0 }, toolbar: { gap: spacing.small, padding: spacing.medium }, filters: { gap: spacing.small, paddingRight: spacing.medium },
  filter: { alignItems: 'center', backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.inputRadius, borderWidth: 1, justifyContent: 'center', minHeight: 48, paddingHorizontal: spacing.medium }, filterSelected: { backgroundColor: colors.shell, borderColor: colors.shell }, filterPressed: { opacity: 0.84 }, filterText: textStyles.label, filterTextSelected: { color: colors.onPrimary },
  list: { flexGrow: 1, padding: spacing.medium }, count: { marginBottom: spacing.medium }, card: { gap: spacing.small, marginBottom: spacing.medium }, pressed: { opacity: 0.84 }, cardHeader: { alignItems: 'flex-start', flexDirection: 'row', gap: spacing.small, justifyContent: 'space-between' }, cardCopy: { flex: 1, gap: spacing.xs }, info: { gap: spacing.xs }, evidence: { alignItems: 'center', flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs, marginTop: spacing.xs },
});
