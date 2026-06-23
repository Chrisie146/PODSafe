import React, { useEffect, useMemo, useState } from 'react';
import { Alert, Image, Linking, Modal, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import { useAuthStore } from '../../stores/useAuthStore';
import { PodRepository } from '../../repositories/podRepository';
import { PodRecord } from '../../models/pod';
import { exportPODs } from '../../repositories/csvExportService';
import { bulkExportService } from '../../repositories/bulkExportService';
import FirebaseStorageImage from '../../components/FirebaseStorageImage';
import LocationMapWidget from '../../components/LocationMapWidget';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

const podRepository = new PodRepository();

type TimePeriod = 'all' | 'today' | 'week' | 'month' | 'custom';
type SortField = 'date' | 'delivery' | 'customer';
type ViewMode = 'grid' | 'list';

function periodSinceDate(period: TimePeriod): Date | undefined {
  const now = new Date();
  switch (period) {
    case 'today':
      return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    case 'week':
      return new Date(now.getTime() - 7 * 86400000);
    case 'month':
      return new Date(now.getFullYear(), now.getMonth(), 1);
    case 'all':
    case 'custom':
      return undefined;
  }
}

/**
 * Ported from lib/screens/admin/pod_viewer_desktop.dart (verified against source on
 * 2026-06-23). Same canonical `pods/{deliveryId}` data layer as the mobile variant
 * (PodViewer.tsx): `PodRepository.subscribeToCompanyPods()` + the typed `PodRecord`
 * model, reading `customerNumber`/`orderNumber`/`stampPhotoUrl`/`notes`/`receiverName`
 * from `pod.metadata` (same as mobile) rather than the Dart source's raw top-level
 * Firestore fields — those top-level fields are a legacy shape from before this
 * codebase's own bug fix (see deviation below on the migration tool).
 *
 * Real bug found and fixed: the "Has Signature"/"Has Photo"/"Has GPS" quick-filter chips
 * in the filter sidebar have `onTap: () { setState(() {}); }` — they trigger a rebuild
 * but never actually filter anything (confirmed by direct read: no `_hasSignatureFilter`-
 * style state exists anywhere in the class). Wired for real here.
 *
 * Deliberately NOT ported: `_runPODMigration()` / `migratePODData()` — a one-time legacy
 * data-repair script that backfills `customerName`/`invoiceNumber`/etc. as TOP-LEVEL
 * fields onto old `pods` documents that predate a Dart-side bug fix. Porting it would
 * write data in the wrong shape relative to this port's own `metadata`-nested convention
 * (already established in PodViewer.tsx), actively reintroducing the inconsistency this
 * migration was meant to clean up. If old PODs still need backfilling, that's a job for
 * the existing Flutter app (which still has the correct legacy-shape context), not this
 * port.
 *
 * Bulk download as PDF-reports-ZIP / images-ZIP (`BulkPODDownloadService`) was genuine
 * client-side Dart PDF+zip generation. Per this migration's settled decision (move heavy
 * PDF/image work server-side, same as the single-POD `generatePodPdf` callable), both are
 * now wired to the server-side `generateBulkPodZip` callable via
 * `bulkExportService.exportPodsAsZip(podIds, mode)` — `mode: 'pdf'` for the PDF-reports ZIP,
 * `mode: 'images'` for the raw photos/signature/stamp ZIP. Selected PODs are exported, or
 * all filtered PODs if none selected. The callable is built but not yet deployed (tracked
 * in the vault's Backend Gap Fix Tracker) — until deploy the call fails with a clear "may
 * not be deployed" message. CSV export (via the already-built `exportPODs()`) stays wired
 * for real.
 *
 * `_showFullPODDialog()` (an in-page modal largely duplicating PodDetails.tsx) becomes a
 * navigation to the already-ported `PodDetails` screen instead, avoiding a redundant
 * second detail UI — same simplification already applied consistently across other
 * Phase 4 desktop screens' detail panels.
 *
 * Dropped: keyboard shortcuts (Risk Register #14).
 */
export default function PodViewerDesktop({ navigation }: { navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void } }) {
  const currentUser = useAuthStore((s) => s.currentUser);

  const [allPods, setAllPods] = useState<PodRecord[] | null>(null);
  const [hasError, setHasError] = useState(false);

  const [showFilters, setShowFilters] = useState(true);
  const [viewMode, setViewMode] = useState<ViewMode>('grid');
  const [searchQuery, setSearchQuery] = useState('');
  const [timePeriod, setTimePeriod] = useState<TimePeriod>('all');
  const [customStart, setCustomStart] = useState<Date | null>(null);
  const [customEnd, setCustomEnd] = useState<Date | null>(null);
  const [showDateModal, setShowDateModal] = useState(false);
  const [dateStartText, setDateStartText] = useState('');
  const [dateEndText, setDateEndText] = useState('');
  const [sortBy, setSortBy] = useState<SortField>('date');
  const [sortAscending, setSortAscending] = useState(false);
  const [hasSignatureFilter, setHasSignatureFilter] = useState(false);
  const [hasPhotoFilter, setHasPhotoFilter] = useState(false);
  const [hasGpsFilter, setHasGpsFilter] = useState(false);

  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [selectedPod, setSelectedPod] = useState<PodRecord | null>(null);
  const [showExportSheet, setShowExportSheet] = useState(false);

  useEffect(() => {
    if (!currentUser) return;
    setAllPods(null);
    setHasError(false);
    const unsubscribe = podRepository.subscribeToCompanyPods(currentUser.companyId, setAllPods, () => setHasError(true), {
      since: timePeriod === 'custom' ? undefined : periodSinceDate(timePeriod),
    });
    return unsubscribe;
  }, [currentUser, timePeriod]);

  const filteredPods = useMemo(() => {
    if (!allPods) return null;
    let result = allPods;

    if (timePeriod === 'custom' && customStart && customEnd) {
      const endInclusive = new Date(customEnd.getFullYear(), customEnd.getMonth(), customEnd.getDate() + 1);
      result = result.filter((p) => p.timestamp >= customStart && p.timestamp < endInclusive);
    }

    const q = searchQuery.trim().toLowerCase();
    if (q.length > 0) {
      result = result.filter((p) => p.deliveryId.toLowerCase().includes(q) || p.customerName.toLowerCase().includes(q));
    }
    if (hasSignatureFilter) result = result.filter((p) => Boolean(p.signatureUrl));
    if (hasPhotoFilter) result = result.filter((p) => Boolean(p.photoUrl));
    if (hasGpsFilter) result = result.filter((p) => Boolean(p.location));

    result = [...result].sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case 'date':
          cmp = a.timestamp.getTime() - b.timestamp.getTime();
          break;
        case 'delivery':
          cmp = a.deliveryId.localeCompare(b.deliveryId);
          break;
        case 'customer':
          cmp = a.customerName.localeCompare(b.customerName);
          break;
      }
      return sortAscending ? cmp : -cmp;
    });
    return result;
  }, [allPods, timePeriod, customStart, customEnd, searchQuery, hasSignatureFilter, hasPhotoFilter, hasGpsFilter, sortBy, sortAscending]);

  const stats = useMemo(() => {
    const pods = allPods ?? [];
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    return {
      total: pods.length,
      today: pods.filter((p) => p.timestamp.getTime() >= startOfToday.getTime()).length,
      withSignature: pods.filter((p) => Boolean(p.signatureUrl)).length,
      withPhoto: pods.filter((p) => Boolean(p.photoUrl)).length,
    };
  }, [allPods]);

  if (!currentUser) {
    return (
      <View style={styles.centered}>
        <Text style={textStyles.bodyMedium}>Please log in</Text>
      </View>
    );
  }

  const toggleSelectOne = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const selectAllVisible = () => {
    if (!filteredPods) return;
    setSelectedIds(new Set(filteredPods.map((p) => p.id)));
  };

  const applyCustomDateRange = () => {
    const start = new Date(dateStartText);
    const end = new Date(dateEndText);
    if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime())) {
      setCustomStart(start);
      setCustomEnd(end);
      setTimePeriod('custom');
    }
    setShowDateModal(false);
  };

  const handleExportCsv = async () => {
    setShowExportSheet(false);
    const pods = isMultiSelectMode && selectedIds.size > 0 ? (filteredPods ?? []).filter((p) => selectedIds.has(p.id)) : filteredPods ?? [];
    try {
      await exportPODs(
        pods.map((p) => ({
          deliveryId: p.deliveryId,
          trackingNumber: p.invoiceNumber,
          customerName: p.customerName,
          deliveryAddress: p.metadata.customerAddress as string | undefined,
          timestamp: p.timestamp,
          status: p.status,
          signatureUrl: p.signatureUrl,
          photoUrl: p.photoUrl,
          photoUrls: p.photoUrls,
          recipientName: p.signedBy,
          notes: p.metadata.notes as string | undefined,
        })),
      );
      Alert.alert('Success', `Exported ${pods.length} POD(s) to CSV`);
    } catch (e) {
      Alert.alert('Error', `Error exporting PODs: ${(e as Error).message}`);
    }
  };

  const exportPodsZip = async (mode: 'pdf' | 'images') => {
    setShowExportSheet(false);
    const pods = isMultiSelectMode && selectedIds.size > 0 ? (filteredPods ?? []).filter((p) => selectedIds.has(p.id)) : filteredPods ?? [];
    if (pods.length === 0) {
      Alert.alert('No PODs', 'There are no PODs to export.');
      return;
    }
    const podIds = pods.map((p) => p.id);
    try {
      const result = await bulkExportService.exportPodsAsZip(podIds, mode);
      const skippedNote = result.skipped ? `\n${result.skipped} skipped (not found in your company).` : '';
      Alert.alert(
        'Export Ready',
        `${result.included} POD(s) packaged as a ZIP.${skippedNote}\n\nOpen the download link in your browser?`,
        [
          { text: 'Copy Link', onPress: () => Clipboard.setString(result.downloadUrl) },
          { text: 'Open', onPress: () => Linking.openURL(result.downloadUrl) },
          { text: 'Close', style: 'cancel' },
        ],
      );
    } catch (e) {
      const msg = (e as Error).message ?? 'Unknown error';
      Alert.alert(
        'Export Failed',
        msg.includes('not-found') || msg.includes('unauthenticated') || msg.includes('permission-denied')
          ? `${msg}\n\nThe bulk export function may not be deployed yet — tracked separately.`
          : `Error exporting PODs: ${msg}`,
      );
    }
  };

  const handleExportPdfZip = () => exportPodsZip('pdf');
  const handleExportImagesZip = () => exportPodsZip('images');

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <View style={styles.headerBarLeft}>
          <Text style={textStyles.heading3}>Proof of Deliveries</Text>
          <Text style={styles.desktopBadge}>Desktop</Text>
        </View>
        <View style={styles.headerBarRight}>
          <Pressable onPress={() => setViewMode((m) => (m === 'grid' ? 'list' : 'grid'))}>
            <Text style={styles.headerBarAction}>{viewMode === 'grid' ? '▦' : '☰'}</Text>
          </Pressable>
          <Pressable onPress={() => setIsMultiSelectMode((p) => !p)}>
            <Text style={styles.headerBarAction}>{isMultiSelectMode ? '☑' : '☐'}</Text>
          </Pressable>
          <Pressable onPress={() => setShowFilters((p) => !p)}>
            <Text style={styles.headerBarAction}>🔍</Text>
          </Pressable>
          <Pressable onPress={() => setShowExportSheet(true)}>
            <Text style={styles.headerBarAction}>⬇</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.body}>
        {showFilters ? (
          <View style={styles.sidebar}>
            <ScrollView contentContainerStyle={styles.sidebarContent}>
              <Text style={styles.sidebarTitle}>Filters</Text>
              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Search</Text>
              <TextInput style={styles.input} placeholder="Search deliveries..." value={searchQuery} onChangeText={setSearchQuery} />

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Time Period</Text>
              <FilterOption label="All Time" selected={timePeriod === 'all'} onPress={() => setTimePeriod('all')} />
              <FilterOption label="Today" selected={timePeriod === 'today'} onPress={() => setTimePeriod('today')} />
              <FilterOption label="This Week" selected={timePeriod === 'week'} onPress={() => setTimePeriod('week')} />
              <FilterOption label="This Month" selected={timePeriod === 'month'} onPress={() => setTimePeriod('month')} />
              <FilterOption
                label="Custom Range"
                selected={timePeriod === 'custom'}
                onPress={() => {
                  setDateStartText(customStart ? customStart.toISOString().slice(0, 10) : '');
                  setDateEndText(customEnd ? customEnd.toISOString().slice(0, 10) : '');
                  setShowDateModal(true);
                }}
              />
              {timePeriod === 'custom' && customStart && customEnd ? (
                <Text style={styles.customRangeText} numberOfLines={1}>
                  {customStart.toLocaleDateString()} - {customEnd.toLocaleDateString()}
                </Text>
              ) : null}

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Sort By</Text>
              <SortOption label="Date Submitted" selected={sortBy === 'date'} onPress={() => setSortBy('date')} />
              <SortOption label="Delivery ID" selected={sortBy === 'delivery'} onPress={() => setSortBy('delivery')} />
              <SortOption label="Customer Name" selected={sortBy === 'customer'} onPress={() => setSortBy('customer')} />
              <View style={styles.switchRow}>
                <Text style={styles.settingTitle}>Ascending</Text>
                <Switch value={sortAscending} onValueChange={setSortAscending} trackColor={{ true: colors.primary, false: colors.divider }} />
              </View>

              <Text style={[styles.sidebarLabel, styles.sidebarSectionSpacer]}>Quick Filters</Text>
              <View style={styles.chipWrap}>
                <Chip label="✎ Has Signature" selected={hasSignatureFilter} onPress={() => setHasSignatureFilter((p) => !p)} />
                <Chip label="📷 Has Photo" selected={hasPhotoFilter} onPress={() => setHasPhotoFilter((p) => !p)} />
                <Chip label="📍 Has GPS" selected={hasGpsFilter} onPress={() => setHasGpsFilter((p) => !p)} />
              </View>
            </ScrollView>
          </View>
        ) : null}

        <View style={styles.mainArea}>
          <View style={styles.statsBar}>
            <MiniStat label="Total PODs" value={stats.total} icon="🧾" color={colors.info} />
            <MiniStat label="Today" value={stats.today} icon="📅" color={colors.success} />
            <MiniStat label="With Signature" value={stats.withSignature} icon="✎" color="#9C27B0" />
            <MiniStat label="With Photo" value={stats.withPhoto} icon="📷" color={colors.warning} />
          </View>

          {isMultiSelectMode && selectedIds.size > 0 ? (
            <View style={styles.bulkBar}>
              <Text style={styles.bulkBarText}>{selectedIds.size} selected</Text>
              <Pressable onPress={selectAllVisible}>
                <Text style={styles.bulkBarAction}>Select All</Text>
              </Pressable>
              <Pressable onPress={() => setSelectedIds(new Set())}>
                <Text style={styles.bulkBarAction}>Deselect All</Text>
              </Pressable>
              <Pressable onPress={() => setShowExportSheet(true)}>
                <Text style={styles.bulkBarAction}>Export Selected</Text>
              </Pressable>
              <Pressable
                onPress={() => {
                  setSelectedIds(new Set());
                  setIsMultiSelectMode(false);
                }}
              >
                <Text style={styles.bulkBarAction}>Done</Text>
              </Pressable>
            </View>
          ) : null}

          <View style={styles.contentRow}>
            <View style={styles.contentSection}>
              {hasError ? (
                <View style={styles.centered}>
                  <Text style={styles.emptyIcon}>⚠</Text>
                  <Text style={textStyles.bodyMedium}>Error loading PODs</Text>
                </View>
              ) : filteredPods === null ? (
                <View style={styles.centered}>
                  <Text style={textStyles.bodyMedium}>Loading...</Text>
                </View>
              ) : filteredPods.length === 0 ? (
                <View style={styles.centered}>
                  <Text style={styles.emptyIcon}>🧾</Text>
                  <Text style={textStyles.heading3}>No PODs found</Text>
                </View>
              ) : viewMode === 'grid' ? (
                <ScrollView contentContainerStyle={styles.gridContent}>
                  {filteredPods.map((pod) => (
                    <PodGridCard
                      key={pod.id}
                      pod={pod}
                      isMultiSelectMode={isMultiSelectMode}
                      isSelected={selectedIds.has(pod.id)}
                      isActiveCard={selectedPod?.id === pod.id}
                      onToggleSelect={() => toggleSelectOne(pod.id)}
                      onPress={() => setSelectedPod(pod)}
                    />
                  ))}
                </ScrollView>
              ) : (
                <ScrollView>
                  {filteredPods.map((pod) => (
                    <PodListRow
                      key={pod.id}
                      pod={pod}
                      isMultiSelectMode={isMultiSelectMode}
                      isSelected={selectedIds.has(pod.id)}
                      isActiveRow={selectedPod?.id === pod.id}
                      onToggleSelect={() => toggleSelectOne(pod.id)}
                      onPress={() => setSelectedPod(pod)}
                    />
                  ))}
                </ScrollView>
              )}
            </View>

            {selectedPod && !isMultiSelectMode ? (
              <DetailPanel pod={selectedPod} onClose={() => setSelectedPod(null)} onViewFull={() => navigation.navigate('PodDetails', { deliveryId: selectedPod.deliveryId })} />
            ) : null}
          </View>
        </View>
      </View>

      <Modal visible={showDateModal} transparent animationType="fade" onRequestClose={() => setShowDateModal(false)}>
        <View style={styles.formModalBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Custom Date Range</Text>
            <Text style={styles.fieldLabel}>Start Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateStartText} onChangeText={setDateStartText} />
            <Text style={styles.fieldLabel}>End Date (YYYY-MM-DD)</Text>
            <TextInput style={styles.dateInput} value={dateEndText} onChangeText={setDateEndText} />
            <View style={styles.modalActionsRow}>
              <Pressable style={styles.modalSecondaryButton} onPress={() => setShowDateModal(false)}>
                <Text style={styles.modalSecondaryText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalPrimaryButton} onPress={applyCustomDateRange}>
                <Text style={textStyles.buttonText}>Apply</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={showExportSheet} transparent animationType="fade" onRequestClose={() => setShowExportSheet(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowExportSheet(false)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <Text style={styles.actionSheetTitle}>Export PODs</Text>
            <ActionRow icon="📊" label="Export as CSV" onPress={handleExportCsv} />
            <ActionRow icon="📄" label="Download as PDF Reports (ZIP)" onPress={handleExportPdfZip} />
            <ActionRow icon="🖼" label="Download Images (ZIP)" onPress={handleExportImagesZip} />
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

function MiniStat({ label, value, icon, color }: { label: string; value: number; icon: string; color: string }) {
  return (
    <View style={[styles.statCard, shadows.card]}>
      <View style={[styles.statIconBox, { backgroundColor: `${color}1A` }]}>
        <Text style={[styles.statIcon, { color }]}>{icon}</Text>
      </View>
      <View>
        <Text style={styles.statValue}>{value}</Text>
        <Text style={styles.statLabel}>{label}</Text>
      </View>
    </View>
  );
}

function FilterOption({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.filterOption, selected && styles.filterOptionSelected]} onPress={onPress}>
      <Text style={[styles.filterOptionGlyph, selected && styles.filterOptionGlyphSelected]}>{selected ? '●' : '○'}</Text>
      <Text style={[styles.filterOptionLabel, selected && styles.filterOptionLabelSelected]}>{label}</Text>
    </Pressable>
  );
}

function SortOption({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.sortOption, selected && styles.sortOptionSelected]} onPress={onPress}>
      <Text style={[styles.sortOptionLabel, selected && styles.sortOptionLabelSelected]}>{label}</Text>
    </Pressable>
  );
}

function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, selected && styles.chipSelected]} onPress={onPress}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

function ActionRow({ label, icon, onPress }: { label: string; icon: string; onPress: () => void }) {
  return (
    <Pressable style={styles.actionRow} onPress={onPress}>
      <Text style={styles.actionRowIcon}>{icon}</Text>
      <Text style={styles.actionRowLabel}>{label}</Text>
    </Pressable>
  );
}

function FeatureIcon({ icon, active }: { icon: string; active: boolean }) {
  return <Text style={[styles.featureIcon, { color: active ? colors.success : colors.divider }]}>{icon}</Text>;
}

function PodGridCard({
  pod,
  isMultiSelectMode,
  isSelected,
  isActiveCard,
  onToggleSelect,
  onPress,
}: {
  pod: PodRecord;
  isMultiSelectMode: boolean;
  isSelected: boolean;
  isActiveCard: boolean;
  onToggleSelect: () => void;
  onPress: () => void;
}) {
  const customerNumber = pod.metadata.customerNumber as string | undefined;
  const orderNumber = pod.metadata.orderNumber as string | undefined;

  return (
    <Pressable style={[styles.gridCard, shadows.card, isSelected && styles.gridCardSelected, isActiveCard && styles.gridCardActive]} onPress={isMultiSelectMode ? onToggleSelect : onPress}>
      <View style={styles.gridImageBox}>
        {pod.photoUrl ? (
          <FirebaseStorageImage imageUrl={pod.photoUrl} style={styles.gridImage} resizeMode="cover" />
        ) : (
          <View style={[styles.gridImage, styles.gridImageFallback]}>
            <Text style={styles.gridImageFallbackIcon}>🖼</Text>
          </View>
        )}
        <View style={styles.gridStatusBadge}>
          <Text style={styles.gridStatusBadgeText}>Delivered</Text>
        </View>
        {isMultiSelectMode ? (
          <View style={styles.gridCheckboxBox}>
            <Text>{isSelected ? '☑' : '☐'}</Text>
          </View>
        ) : null}
      </View>
      <View style={styles.gridCardBody}>
        <Text style={styles.gridCardTitle} numberOfLines={1}>
          Delivery #{pod.deliveryId.substring(0, 8)}
        </Text>
        <Text style={styles.gridCardSubtitle} numberOfLines={1}>
          {pod.customerName}
        </Text>
        <View style={styles.gridChipRow}>
          {customerNumber ? <MiniTag label="Cust" value={customerNumber} color="#1976D2" /> : null}
          {pod.invoiceNumber ? <MiniTag label="Inv" value={pod.invoiceNumber} color={colors.success} /> : null}
          {orderNumber ? <MiniTag label="Order" value={orderNumber} color={colors.warning} /> : null}
        </View>
        <Text style={styles.gridTimestamp}>🕐 {pod.timestamp.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}</Text>
        <View style={styles.gridFeatureRow}>
          <FeatureIcon icon="✎" active={Boolean(pod.signatureUrl)} />
          <FeatureIcon icon="📷" active={Boolean(pod.photoUrl)} />
          {pod.metadata.stampPhotoUrl ? <FeatureIcon icon="🧾" active /> : null}
          <FeatureIcon icon="📍" active={Boolean(pod.location)} />
        </View>
      </View>
    </Pressable>
  );
}

function MiniTag({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <View style={[styles.miniTag, { backgroundColor: `${color}1A` }]}>
      <Text style={[styles.miniTagLabel, { color }]}>{label}</Text>
      <Text style={styles.miniTagValue}>{value}</Text>
    </View>
  );
}

function PodListRow({
  pod,
  isMultiSelectMode,
  isSelected,
  isActiveRow,
  onToggleSelect,
  onPress,
}: {
  pod: PodRecord;
  isMultiSelectMode: boolean;
  isSelected: boolean;
  isActiveRow: boolean;
  onToggleSelect: () => void;
  onPress: () => void;
}) {
  const customerNumber = pod.metadata.customerNumber as string | undefined;
  return (
    <Pressable style={[styles.listRow, isActiveRow && styles.listRowActive]} onPress={isMultiSelectMode ? onToggleSelect : onPress}>
      {isMultiSelectMode ? <Text style={styles.listCheckbox}>{isSelected ? '☑' : '☐'}</Text> : null}
      <View style={styles.listThumbBox}>
        {pod.photoUrl ? <FirebaseStorageImage imageUrl={pod.photoUrl} style={styles.listThumb} resizeMode="cover" /> : <View style={[styles.listThumb, styles.gridImageFallback]} />}
      </View>
      <View style={styles.listTextBox}>
        <Text style={styles.gridCardTitle} numberOfLines={1}>
          Delivery #{pod.deliveryId.substring(0, 8)} — {pod.customerName}
        </Text>
        <Text style={styles.gridCardSubtitle} numberOfLines={1}>
          {customerNumber ? `Cust ${customerNumber} • ` : ''}
          {pod.timestamp.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}
        </Text>
      </View>
      <View style={styles.listFeatureRow}>
        <FeatureIcon icon="✎" active={Boolean(pod.signatureUrl)} />
        <FeatureIcon icon="📷" active={Boolean(pod.photoUrl)} />
        <FeatureIcon icon="📍" active={Boolean(pod.location)} />
      </View>
    </Pressable>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue} numberOfLines={2}>
        {value}
      </Text>
    </View>
  );
}

function DetailPanel({ pod, onClose, onViewFull }: { pod: PodRecord; onClose: () => void; onViewFull: () => void }) {
  const customerNumber = pod.metadata.customerNumber as string | undefined;
  const orderNumber = pod.metadata.orderNumber as string | undefined;
  const stampPhotoUrl = pod.metadata.stampPhotoUrl as string | undefined;
  const notes = pod.metadata.notes as string | undefined;

  return (
    <View style={styles.detailPanel}>
      <View style={styles.detailPanelHeader}>
        <Text style={styles.detailPanelTitle}>POD Details</Text>
        <Pressable onPress={onClose}>
          <Text style={styles.closeGlyph}>✕</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.detailPanelContent}>
        {pod.photoUrl ? (
          <>
            <Text style={styles.detailSectionTitle}>Delivery Photo</Text>
            <FirebaseStorageImage imageUrl={pod.photoUrl} style={styles.detailImage} resizeMode="cover" />
            <View style={styles.sectionSpacer} />
          </>
        ) : null}

        {stampPhotoUrl ? (
          <>
            <Text style={styles.detailSectionTitle}>🧾 Customer Stamp</Text>
            <Text style={styles.detailHint}>Corporate Store Receipt</Text>
            <FirebaseStorageImage imageUrl={stampPhotoUrl} style={styles.detailImage} resizeMode="cover" />
            <View style={styles.sectionSpacer} />
          </>
        ) : null}

        {pod.documentUrls && pod.documentUrls.length > 0 ? (
          <>
            <Text style={styles.detailSectionTitle}>📄 Scanned Documents</Text>
            {pod.documentUrls.map((url, index) => (
              <View key={url} style={styles.documentBlock}>
                <View style={styles.documentTypeBadge}>
                  <Text style={styles.documentTypeBadgeText}>{pod.documentMetadata?.[index]?.type ?? 'Document'}</Text>
                </View>
                <FirebaseStorageImage imageUrl={url} style={styles.documentImage} resizeMode="contain" />
              </View>
            ))}
            <View style={styles.sectionSpacer} />
          </>
        ) : null}

        {pod.signatureUrl ? (
          <>
            <Text style={styles.detailSectionTitle}>Customer Signature</Text>
            <View style={styles.signatureBox}>
              <Image source={{ uri: pod.signatureUrl }} style={styles.signatureImage} resizeMode="contain" />
            </View>
            <View style={styles.sectionSpacer} />
          </>
        ) : null}

        <DetailRow label="Delivery ID" value={pod.deliveryId} />
        <DetailRow label="Customer" value={pod.customerName} />
        <DetailRow label="Receiver" value={pod.signedBy ?? 'Not specified'} />
        <DetailRow label="Customer #" value={customerNumber ?? 'N/A'} />
        <DetailRow label="Order #" value={orderNumber ?? 'N/A'} />
        <DetailRow label="Invoice #" value={pod.invoiceNumber ?? 'N/A'} />
        <DetailRow label="Completed" value={pod.timestamp.toLocaleString()} />

        {pod.location ? (
          <>
            <View style={styles.sectionSpacer} />
            <Text style={styles.detailSectionTitle}>GPS Location</Text>
            <View style={styles.gpsBox}>
              <Text style={styles.gpsText}>Lat: {pod.location.latitude.toFixed(6)}</Text>
              <Text style={styles.gpsText}>Lng: {pod.location.longitude.toFixed(6)}</Text>
              {pod.location.accuracy != null ? <Text style={styles.gpsHint}>Accuracy: {pod.location.accuracy}m</Text> : null}
            </View>
            <View style={styles.sectionSpacerSmall} />
            <LocationMapWidget latitude={pod.location.latitude} longitude={pod.location.longitude} accuracy={pod.location.accuracy} address={pod.location.address} />
          </>
        ) : null}

        {notes ? (
          <>
            <View style={styles.sectionSpacer} />
            <Text style={styles.detailSectionTitle}>Notes</Text>
            <View style={styles.notesBox}>
              <Text style={styles.notesText}>{notes}</Text>
            </View>
          </>
        ) : null}

        <View style={styles.sectionSpacer} />
        <Pressable style={styles.modalPrimaryButton} onPress={onViewFull}>
          <Text style={textStyles.buttonText}>↗ View Full Details</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  emptyIcon: { fontSize: 56, opacity: 0.3, marginBottom: spacing.medium },
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.primary, paddingHorizontal: spacing.medium, paddingVertical: spacing.medium },
  headerBarLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.small + 4 },
  desktopBadge: { color: colors.white, fontSize: 11, fontWeight: '700', opacity: 0.8, borderWidth: 1, borderColor: colors.white, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 },
  headerBarRight: { flexDirection: 'row', gap: spacing.medium },
  headerBarAction: { color: colors.white, fontSize: 18 },
  body: { flex: 1, flexDirection: 'row' },
  sidebar: { width: 280, borderRightWidth: 1, borderRightColor: colors.divider, backgroundColor: colors.card },
  sidebarContent: { padding: spacing.medium },
  sidebarTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary },
  sidebarLabel: { fontWeight: '600', color: colors.textSecondary, marginBottom: spacing.small, fontSize: 12 },
  sidebarSectionSpacer: { marginTop: spacing.large },
  input: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, padding: spacing.small + 4, backgroundColor: colors.background },
  filterOption: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small + 4, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, marginBottom: spacing.small },
  filterOptionSelected: { backgroundColor: colors.primary, borderColor: colors.primary },
  filterOptionGlyph: { fontSize: 16, marginRight: spacing.small, color: colors.textSecondary, width: 18 },
  filterOptionGlyphSelected: { color: colors.white },
  filterOptionLabel: { fontSize: 14, color: colors.textPrimary },
  filterOptionLabelSelected: { color: colors.white, fontWeight: '600' },
  customRangeText: { fontSize: 12, color: colors.textSecondary, marginTop: -spacing.small, marginBottom: spacing.small },
  sortOption: { paddingVertical: spacing.small + 4, paddingHorizontal: spacing.small + 4, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, marginBottom: spacing.small },
  sortOptionSelected: { backgroundColor: `${colors.primary}1A`, borderColor: colors.primary },
  sortOptionLabel: { fontSize: 13, color: colors.textPrimary },
  sortOptionLabelSelected: { color: colors.primary, fontWeight: '600' },
  switchRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: spacing.small },
  settingTitle: { fontSize: 13, color: colors.textPrimary },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small },
  chip: { borderRadius: 20, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.divider },
  chipSelected: { backgroundColor: `${colors.primary}33`, borderColor: colors.primary },
  chipText: { fontSize: 12, color: colors.textSecondary },
  chipTextSelected: { color: colors.primary, fontWeight: '600' },
  mainArea: { flex: 1 },
  statsBar: { flexDirection: 'row', gap: spacing.small + 4, padding: spacing.medium },
  statCard: { flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.small + 4 },
  statIconBox: { width: 36, height: 36, borderRadius: radii.borderRadius, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small },
  statIcon: { fontSize: 16 },
  statValue: { fontSize: 18, fontWeight: 'bold', color: colors.textPrimary },
  statLabel: { fontSize: 11, color: colors.textSecondary },
  bulkBar: { flexDirection: 'row', alignItems: 'center', gap: spacing.large, backgroundColor: `${colors.primary}14`, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, marginHorizontal: spacing.medium, borderRadius: radii.borderRadius },
  bulkBarText: { flex: 1, fontWeight: '700', color: colors.textPrimary },
  bulkBarAction: { fontWeight: '600', color: colors.primary },
  contentRow: { flex: 1, flexDirection: 'row' },
  contentSection: { flex: 1 },
  gridContent: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.medium, padding: spacing.medium },
  gridCard: { width: 240, borderRadius: radii.cardRadius, backgroundColor: colors.card, overflow: 'hidden' },
  gridCardSelected: { borderWidth: 2, borderColor: colors.primary },
  gridCardActive: { borderWidth: 2, borderColor: colors.info },
  gridImageBox: { height: 150, backgroundColor: colors.divider },
  gridImage: { width: '100%', height: '100%' },
  gridImageFallback: { alignItems: 'center', justifyContent: 'center' },
  gridImageFallbackIcon: { fontSize: 32, opacity: 0.4 },
  gridStatusBadge: { position: 'absolute', top: 8, left: 8, backgroundColor: colors.success, borderRadius: 4, paddingHorizontal: spacing.small, paddingVertical: 2 },
  gridStatusBadgeText: { color: colors.white, fontSize: 10, fontWeight: 'bold' },
  gridCheckboxBox: { position: 'absolute', top: 8, right: 8, backgroundColor: colors.white, borderRadius: 12, width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
  gridCardBody: { padding: spacing.small + 4 },
  gridCardTitle: { fontWeight: '700', fontSize: 14, color: colors.textPrimary },
  gridCardSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  gridChipRow: { flexDirection: 'row', gap: 4, marginTop: spacing.small },
  gridTimestamp: { fontSize: 11, color: colors.textSecondary, marginTop: spacing.small },
  gridFeatureRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.small, justifyContent: 'space-evenly' },
  featureIcon: { fontSize: 14 },
  miniTag: { borderRadius: 3, paddingHorizontal: 6, paddingVertical: 2 },
  miniTagLabel: { fontSize: 8, fontWeight: '600' },
  miniTagValue: { fontSize: 9, fontWeight: 'bold', color: colors.textPrimary },
  listRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  listRowActive: { backgroundColor: `${colors.primary}0F` },
  listCheckbox: { marginRight: spacing.small + 4 },
  listThumbBox: { width: 56, height: 56, borderRadius: radii.borderRadius, overflow: 'hidden', marginRight: spacing.small + 4 },
  listThumb: { width: '100%', height: '100%' },
  listTextBox: { flex: 1 },
  listFeatureRow: { flexDirection: 'row', gap: spacing.small },
  detailPanel: { width: 400, borderLeftWidth: 1, borderLeftColor: colors.divider, backgroundColor: colors.card },
  detailPanelHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: spacing.medium, borderBottomWidth: 1, borderBottomColor: colors.divider },
  detailPanelTitle: { fontWeight: '700', fontSize: 15, color: colors.textPrimary },
  closeGlyph: { fontSize: 20, color: colors.textSecondary },
  detailPanelContent: { padding: spacing.large },
  detailSectionTitle: { fontWeight: '600', fontSize: 14, color: colors.textPrimary, marginBottom: spacing.small },
  detailHint: { fontSize: 11, color: colors.textSecondary, fontStyle: 'italic', marginBottom: spacing.small },
  detailImage: { height: 200, width: '100%', borderRadius: radii.borderRadius },
  documentBlock: { marginBottom: spacing.medium },
  documentTypeBadge: { alignSelf: 'flex-start', backgroundColor: `${colors.primary}1A`, borderRadius: 4, paddingHorizontal: spacing.small, paddingVertical: 4, marginBottom: spacing.small },
  documentTypeBadgeText: { color: colors.primary, fontWeight: '600', fontSize: 11 },
  documentImage: { height: 250, width: '100%', borderRadius: radii.borderRadius, borderWidth: 2, borderColor: colors.primary },
  signatureBox: { height: 120, backgroundColor: colors.white, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider },
  signatureImage: { width: '100%', height: '100%' },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4, gap: spacing.medium },
  detailLabel: { color: colors.textSecondary },
  detailValue: { fontWeight: '600', color: colors.textPrimary, flex: 1, textAlign: 'right' },
  gpsBox: { backgroundColor: colors.white, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, padding: spacing.small + 4 },
  gpsText: { fontSize: 12, fontFamily: 'monospace' },
  gpsHint: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  notesBox: { backgroundColor: colors.white, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, padding: spacing.small + 4 },
  notesText: { fontSize: 13, color: colors.textPrimary },
  sectionSpacer: { height: spacing.medium },
  sectionSpacerSmall: { height: spacing.small },
  modalPrimaryButton: { alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  formModalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionSheetTitle: { fontWeight: '700', fontSize: 16, color: colors.textPrimary, marginBottom: spacing.small },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600', color: colors.textPrimary },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 360 },
  fieldLabel: { fontWeight: '600', fontSize: 13, marginTop: spacing.medium, marginBottom: spacing.small },
  dateInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  modalActionsRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalSecondaryButton: { flex: 1, alignItems: 'center', paddingVertical: spacing.small + 4, borderRadius: radii.buttonRadius, borderWidth: 1, borderColor: colors.divider },
  modalSecondaryText: { color: colors.textSecondary, fontWeight: '600' },
});
