// expects route.params: { claimId: string }
import React, { useEffect, useState } from 'react';
import {
  Alert,
  Image,
  Linking,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import {
  AppHeader,
  AppIcon,
  AppIconName,
  AppModal,
  Card,
  DangerButton,
  EmptyState,
  FormField,
  IconButton,
  LoadingState,
  PrimaryButton,
  SecondaryButton,
  StatusChip,
  StatusChipTone,
  SuccessButton,
} from '../../components/ui';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { Claim, ClaimComment, ClaimStatus, claimStatusDisplayText, claimTypeDisplayText } from '../../models/claim';
import { colors, spacing, radii } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/claim_details_screen.dart
 * (`ClaimDetailsMobile`, verified against source on 2026-06-22) — admin claim review:
 * details, evidence (photos/signature), status history, comments, and the
 * approve/reject workflow.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the
 * >1000px desktop branch (`claim_details_desktop.dart`) lands in Phase 4.
 *
 * Deviations from the Flutter source:
 * - Takes only `claimId` via route params; prefers the live entry from
 *   `useClaimStore.allClaims` and falls back to a one-time `getClaimById` fetch.
 * - Added `updateClaimStatus()`/`updateClaim()` for the approve/reject + edit-amount paths.
 * - Bug fix: affected-items now read `description ?? productName` (the mobile Dart screen
 *   read a never-written `productName`, permanently showing "Unknown Product").
 * - No map library installed → GPS section shows coordinates + an "Open in Maps" link.
 * - `CachedNetworkImage` → RN `Image`; overflow placeholders stay honest "Coming Soon".
 * - Full-screen photo viewer is a paging ScrollView (swipe, no pinch-zoom).
 *
 * UI/UX refresh (Operations Precision): the custom navy header, emoji status banner,
 * emoji section/action/evidence/comment glyphs, and bespoke dialogs are replaced with the
 * shared AppHeader, SVG AppIcon/StatusChip, Card, AppModal, and button primitives.
 * Semantic tokens only.
 */
const TABS = ['Details', 'Evidence', 'History', 'Comments'] as const;
type TabName = (typeof TABS)[number];

interface ClaimDetailsProps {
  route: { params: { claimId: string } };
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void; goBack: () => void };
}

const ACTIONABLE_STATUSES: ClaimStatus[] = ['submitted', 'pendingReview', 'pendingApproval'];

const STATUS_BANNER: Record<string, { tone: StatusChipTone; icon: AppIconName; message: string }> = {
  submitted: { tone: 'info', icon: 'info', message: 'New claim awaiting review' },
  pendingReview: { tone: 'warning', icon: 'activity', message: 'Pending your review' },
  pendingApproval: { tone: 'warning', icon: 'activity', message: 'Pending approval' },
  approved: { tone: 'success', icon: 'check', message: 'Claim approved' },
  rejected: { tone: 'error', icon: 'close', message: 'Claim rejected' },
  resolved: { tone: 'success', icon: 'check', message: 'Claim resolved' },
};

const BANNER_PALETTE: Record<StatusChipTone, { bg: string; fg: string }> = {
  neutral: { bg: colors.surfaceMuted, fg: colors.contentSecondary },
  info: { bg: colors.activeMuted, fg: colors.shell },
  success: { bg: colors.verifiedMuted, fg: colors.shell },
  warning: { bg: colors.attentionMuted, fg: colors.contentPrimary },
  error: { bg: colors.criticalMuted, fg: colors.critical },
};

function affectedItemName(item: Record<string, unknown>): string {
  return (item.description as string) ?? (item.productName as string) ?? 'Unknown Product';
}

function capitalize(text: string): string {
  return text.length === 0 ? text : text.charAt(0).toUpperCase() + text.slice(1);
}

function openInMaps(latitude: number, longitude: number) {
  Linking.openURL(`https://www.google.com/maps?q=${latitude},${longitude}`).catch(() => {
    Alert.alert('Error', 'Could not open maps');
  });
}

export default function ClaimDetails({ route, navigation }: ClaimDetailsProps) {
  const { claimId } = route.params;
  const currentUser = useAuthStore((s) => s.currentUser);
  const allClaims = useClaimStore((s) => s.allClaims);
  const getClaimById = useClaimStore((s) => s.getClaimById);
  const updateClaim = useClaimStore((s) => s.updateClaim);
  const updateClaimStatus = useClaimStore((s) => s.updateClaimStatus);
  const addComment = useClaimStore((s) => s.addComment);

  const liveClaim = allClaims.find((c) => c.id === claimId) ?? null;
  const [fetchedClaim, setFetchedClaim] = useState<Claim | null>(null);
  const claim = liveClaim ?? fetchedClaim;

  const [activeTab, setActiveTab] = useState<TabName>('Details');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showActions, setShowActions] = useState(false);
  const [commentText, setCommentText] = useState('');

  const [showEditAmount, setShowEditAmount] = useState(false);
  const [amountText, setAmountText] = useState('');
  const [showApprove, setShowApprove] = useState(false);
  const [approveNotes, setApproveNotes] = useState('');
  const [showReject, setShowReject] = useState(false);
  const [rejectReason, setRejectReason] = useState('');

  const [photoViewerIndex, setPhotoViewerIndex] = useState<number | null>(null);
  const [showSignatureViewer, setShowSignatureViewer] = useState(false);
  const { width: screenWidth } = useWindowDimensions();

  useEffect(() => {
    if (!liveClaim) {
      getClaimById(claimId).then(setFetchedClaim);
    }
  }, [claimId, liveClaim, getClaimById]);

  const canTakeAction = claim ? ACTIONABLE_STATUSES.includes(claim.status) : false;

  const handleEditAmount = () => {
    if (!claim) return;
    setAmountText(claim.claimAmount?.toFixed(2) ?? '');
    setShowEditAmount(true);
  };

  const submitEditAmount = async () => {
    if (!claim) return;
    if (amountText.trim().length === 0) {
      Alert.alert('Notice', 'Please enter an amount');
      return;
    }
    const newAmount = parseFloat(amountText);
    if (Number.isNaN(newAmount)) return;

    setShowEditAmount(false);
    setIsSubmitting(true);
    try {
      const ok = await updateClaim({ ...claim, claimAmount: newAmount, updatedAt: new Date() });
      if (ok) {
        Alert.alert('Success', `Amount updated from R${claim.claimAmount?.toFixed(2) ?? '0.00'} to R${newAmount.toFixed(2)}`);
      } else {
        Alert.alert('Error', useClaimStore.getState().errorMessage ?? 'Failed to update amount');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  const submitApprove = async () => {
    if (!claim || !currentUser) return;
    setShowApprove(false);
    setIsSubmitting(true);
    try {
      const ok = await updateClaimStatus({
        claimId: claim.id,
        newStatus: 'approved',
        userId: currentUser.id,
        userName: currentUser.fullName,
        notes: approveNotes.trim().length > 0 ? approveNotes.trim() : undefined,
      });
      if (ok) {
        Alert.alert('Success', 'Claim approved successfully', [{ text: 'OK', onPress: () => navigation.goBack() }]);
      } else {
        Alert.alert('Error', useClaimStore.getState().errorMessage ?? 'Failed to approve claim');
      }
    } finally {
      setIsSubmitting(false);
      setApproveNotes('');
    }
  };

  const submitReject = async () => {
    if (!claim || !currentUser) return;
    if (rejectReason.trim().length === 0) {
      Alert.alert('Notice', 'Please provide a reason for rejection');
      return;
    }
    setShowReject(false);
    setIsSubmitting(true);
    try {
      const ok = await updateClaimStatus({
        claimId: claim.id,
        newStatus: 'rejected',
        userId: currentUser.id,
        userName: currentUser.fullName,
        notes: rejectReason.trim(),
      });
      if (ok) {
        Alert.alert('Claim rejected', '', [{ text: 'OK', onPress: () => navigation.goBack() }]);
      } else {
        Alert.alert('Error', useClaimStore.getState().errorMessage ?? 'Failed to reject claim');
      }
    } finally {
      setIsSubmitting(false);
      setRejectReason('');
    }
  };

  const submitComment = async () => {
    if (!claim || !currentUser) return;
    const text = commentText.trim();
    if (text.length === 0) return;

    const comment: ClaimComment = {
      id: Date.now().toString(),
      userId: currentUser.id,
      userName: currentUser.fullName,
      userRole: currentUser.role,
      comment: text,
      timestamp: new Date(),
      attachmentUrls: [],
      isInternal: true,
    };

    const ok = await addComment({ claimId: claim.id, comment });
    if (ok) {
      setCommentText('');
    } else {
      Alert.alert('Error', `Failed to add comment: ${useClaimStore.getState().errorMessage ?? ''}`);
    }
  };

  const handleDownloadAllEvidence = async () => {
    if (!claim) return;
    setShowActions(false);
    try {
      const urls = [...claim.photoUrls, ...(claim.customerSignatureUrl ? [claim.customerSignatureUrl] : []), ...(claim.driverSignatureUrl ? [claim.driverSignatureUrl] : [])];
      for (const url of urls) {
        await Linking.openURL(url);
      }
      Alert.alert('Success', `Downloaded ${urls.length} file(s)`);
    } catch (e) {
      Alert.alert('Error', `Error downloading files: ${(e as Error).message}`);
    }
  };

  const comingSoon = (label: string) => {
    setShowActions(false);
    Alert.alert(label, 'Coming Soon');
  };

  if (!claim) {
    return (
      <View style={styles.container}>
        <AppHeader title="Claim" onBack={navigation.goBack} />
        <LoadingState title="Loading claim" message="Retrieving claim details." />
      </View>
    );
  }

  const banner = STATUS_BANNER[claim.status] ?? { tone: 'neutral' as StatusChipTone, icon: 'info' as AppIconName, message: `Status: ${claimStatusDisplayText(claim.status)}` };
  const bannerPalette = BANNER_PALETTE[banner.tone];

  return (
    <View style={styles.container}>
      <AppHeader
        title={claim.id}
        onBack={navigation.goBack}
        right={<IconButton icon="more" accessibilityLabel="Claim actions" onPress={() => setShowActions(true)} />}
      />

      <View style={[styles.statusBanner, { backgroundColor: bannerPalette.bg }]}>
        <AppIcon name={banner.icon} size={20} color={bannerPalette.fg} />
        <Text style={[styles.statusBannerText, { color: bannerPalette.fg }]}>{banner.message}</Text>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabStrip} contentContainerStyle={styles.tabStripContent}>
        {TABS.map((tab) => (
          <Pressable
            key={tab}
            accessibilityRole="tab"
            accessibilityState={{ selected: activeTab === tab }}
            style={[styles.tabButton, activeTab === tab && styles.tabButtonActive]}
            onPress={() => setActiveTab(tab)}
          >
            <Text style={[styles.tabButtonText, activeTab === tab && styles.tabButtonTextActive]}>{tab}</Text>
          </Pressable>
        ))}
      </ScrollView>

      {activeTab === 'Comments' ? (
        <CommentsTab claim={claim} commentText={commentText} onChangeComment={setCommentText} onSend={submitComment} />
      ) : (
        <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
          {activeTab === 'Details' ? <DetailsTab claim={claim} onEditAmount={handleEditAmount} /> : null}
          {activeTab === 'Evidence' ? (
            <EvidenceTab claim={claim} onOpenPhoto={(i) => setPhotoViewerIndex(i)} onOpenSignature={() => setShowSignatureViewer(true)} />
          ) : null}
          {activeTab === 'History' ? <HistoryTab claim={claim} /> : null}
        </ScrollView>
      )}

      {canTakeAction && activeTab !== 'Comments' ? (
        <View style={styles.actionButtonsRow}>
          <DangerButton label="Reject" icon="close" style={styles.actionButton} disabled={isSubmitting} onPress={() => setShowReject(true)} />
          <SuccessButton label="Approve" icon="check" style={styles.actionButton} disabled={isSubmitting} onPress={() => setShowApprove(true)} />
        </View>
      ) : null}

      <Modal visible={showActions} transparent animationType="fade" onRequestClose={() => setShowActions(false)}>
        <Pressable style={styles.modalBackdrop} accessibilityRole="button" accessibilityLabel="Close actions" onPress={() => setShowActions(false)}>
          <View style={styles.actionSheet}>
            <ActionRow label="Assign to User" icon="user" onPress={() => comingSoon('Assign to User')} />
            <ActionRow label="Change Priority" icon="report" onPress={() => comingSoon('Change Priority')} />
            <ActionRow label="Export to PDF" icon="file" onPress={() => comingSoon('Export to PDF')} />
            <ActionRow label="Download All Evidence" icon="download" onPress={handleDownloadAllEvidence} />
            <ActionRow label="Close Claim" icon="lock" onPress={() => comingSoon('Close Claim')} />
          </View>
        </Pressable>
      </Modal>

      <AppModal
        visible={showEditAmount}
        title="Edit claim amount"
        onClose={() => setShowEditAmount(false)}
        footer={
          <View style={styles.modalButtonRow}>
            <SecondaryButton label="Cancel" style={styles.modalButton} onPress={() => setShowEditAmount(false)} />
            <PrimaryButton label="Update amount" style={styles.modalButton} onPress={submitEditAmount} />
          </View>
        }
      >
        <FormField
          label="New amount"
          helperText={`Current amount: R${claim.claimAmount?.toFixed(2) ?? '0.00'}`}
          placeholder="0.00"
          keyboardType="decimal-pad"
          value={amountText}
          onChangeText={setAmountText}
        />
      </AppModal>

      <AppModal
        visible={showApprove}
        title="Approve claim"
        onClose={() => setShowApprove(false)}
        footer={
          <View style={styles.modalButtonRow}>
            <SecondaryButton label="Cancel" style={styles.modalButton} onPress={() => setShowApprove(false)} />
            <SuccessButton label="Approve" style={styles.modalButton} onPress={submitApprove} />
          </View>
        }
      >
        <Text style={styles.modalHint}>Approve claim {claim.id}?</Text>
        <FormField
          label="Notes (optional)"
          placeholder="Add any notes or comments…"
          multiline
          inputStyle={styles.modalTextArea}
          value={approveNotes}
          onChangeText={setApproveNotes}
        />
      </AppModal>

      <AppModal
        visible={showReject}
        title="Reject claim"
        onClose={() => setShowReject(false)}
        footer={
          <View style={styles.modalButtonRow}>
            <SecondaryButton label="Cancel" style={styles.modalButton} onPress={() => setShowReject(false)} />
            <DangerButton label="Reject" style={styles.modalButton} onPress={submitReject} />
          </View>
        }
      >
        <Text style={styles.modalHint}>Reject claim {claim.id}?</Text>
        <FormField
          label="Reason"
          placeholder="Provide a reason for rejection…"
          multiline
          inputStyle={styles.modalTextArea}
          value={rejectReason}
          onChangeText={setRejectReason}
        />
      </AppModal>

      <Modal visible={photoViewerIndex != null} animationType="fade" onRequestClose={() => setPhotoViewerIndex(null)}>
        <View style={styles.photoViewerContainer}>
          <View style={styles.photoViewerHeader}>
            <Text style={styles.photoViewerTitle}>
              Photo {(photoViewerIndex ?? 0) + 1} of {claim.photoUrls.length}
            </Text>
            <IconButton icon="close" accessibilityLabel="Close photo viewer" color={colors.onPrimary} onPress={() => setPhotoViewerIndex(null)} />
          </View>
          <ScrollView
            horizontal
            pagingEnabled
            showsHorizontalScrollIndicator={false}
            contentOffset={{ x: (photoViewerIndex ?? 0) * screenWidth, y: 0 }}
            onMomentumScrollEnd={(e) => {
              const pageWidth = e.nativeEvent.layoutMeasurement.width;
              setPhotoViewerIndex(Math.round(e.nativeEvent.contentOffset.x / pageWidth));
            }}
          >
            {claim.photoUrls.map((url, i) => (
              <View key={i} style={[styles.photoViewerPage, { width: screenWidth }]}>
                <Image source={{ uri: url }} style={[styles.photoViewerImage, { width: screenWidth }]} resizeMode="contain" />
              </View>
            ))}
          </ScrollView>
        </View>
      </Modal>

      <AppModal visible={showSignatureViewer} title="Customer signature" onClose={() => setShowSignatureViewer(false)}>
        {claim.customerSignatureUrl ? <Image source={{ uri: claim.customerSignatureUrl }} style={styles.signatureViewerImage} resizeMode="contain" /> : null}
      </AppModal>
    </View>
  );
}

function DetailsTab({ claim, onEditAmount }: { claim: Claim; onEditAmount: () => void }) {
  return (
    <>
      <Section title="Claim information" icon="clipboard">
        <InfoRow label="Claim ID" value={claim.id} />
        <InfoRow label="Type" value={claimTypeDisplayText(claim.type)} />
        <InfoRow label="Status" value={claimStatusDisplayText(claim.status)} />
        <InfoRow label="Priority" value={capitalize(claim.priority)} />
        <InfoRow label="Filed" value={claim.createdAt.toLocaleString()} />
        {claim.claimAmount != null ? (
          <View style={styles.amountRow}>
            <Text style={styles.infoLabel}>Claimed amount:</Text>
            <Text style={styles.amountValue}>R{claim.claimAmount.toFixed(2)}</Text>
            <IconButton icon="edit" accessibilityLabel="Edit claim amount" onPress={onEditAmount} />
          </View>
        ) : null}
      </Section>

      <Section title="Customer & delivery" icon="user">
        <InfoRow label="Customer" value={claim.customerName} />
        {claim.customerAccountNumber ? <InfoRow label="Customer ID" value={claim.customerAccountNumber} /> : null}
        <InfoRow label="Driver" value={claim.driverName} />
        <InfoRow label="Delivery ID" value={claim.deliveryId} />
        {claim.invoiceNumber ? <InfoRow label="Invoice" value={claim.invoiceNumber} /> : null}
      </Section>

      <Section title="Description" icon="file">
        <Text style={styles.descriptionText}>{claim.description.length > 0 ? claim.description : 'No description provided'}</Text>
      </Section>

      {claim.affectedItems.length > 0 ? (
        <Section title={`Affected items (${claim.affectedItems.length})`} icon="package">
          {claim.affectedItems.map((item, i) => (
            <View key={i} style={styles.affectedItemCard}>
              <Text style={styles.affectedItemName}>{affectedItemName(item)}</Text>
              <Text style={styles.affectedItemQty}>Quantity: {String(item.quantity ?? 'N/A')}</Text>
            </View>
          ))}
        </Section>
      ) : null}

      {Object.keys(claim.gpsLocation).length > 0 ? (
        <Section title="Location" icon="location">
          <InfoRow label="Coordinates" value={`${claim.gpsLocation.latitude}, ${claim.gpsLocation.longitude}`} />
          <SecondaryButton
            label="Open in Maps"
            icon="map"
            style={styles.mapsLinkButton}
            onPress={() => openInMaps(Number(claim.gpsLocation.latitude), Number(claim.gpsLocation.longitude))}
          />
        </Section>
      ) : null}

      <Section title="Evidence quality" icon="shield">
        <View style={styles.evidenceScoreRow}>
          <View style={styles.evidenceScoreTrack}>
            <View
              style={[
                styles.evidenceScoreFill,
                {
                  width: `${(claim.evidenceQualityScore / 10) * 100}%`,
                  backgroundColor: claim.evidenceQualityScore >= 7 ? colors.verified : claim.evidenceQualityScore >= 5 ? colors.attention : colors.critical,
                },
              ]}
            />
          </View>
          <Text style={styles.evidenceScoreText}>{claim.evidenceQualityScore}/10</Text>
        </View>
      </Section>
    </>
  );
}

function EvidenceTab({
  claim,
  onOpenPhoto,
  onOpenSignature,
}: {
  claim: Claim;
  onOpenPhoto: (index: number) => void;
  onOpenSignature: () => void;
}) {
  const hasPhotos = claim.photoUrls.length > 0;
  const hasSignature = claim.customerSignatureUrl != null;

  if (!hasPhotos && !hasSignature) {
    return <EmptyState icon="image" title="No evidence attached" message="Photos and signatures captured for this claim will appear here." />;
  }

  return (
    <>
      {hasPhotos ? (
        <Section title={`Photos (${claim.photoUrls.length})`} icon="image">
          <View style={styles.photoGrid}>
            {claim.photoUrls.map((url, i) => (
              <Pressable key={i} accessibilityRole="button" accessibilityLabel={`Open photo ${i + 1}`} style={styles.photoGridItem} onPress={() => onOpenPhoto(i)}>
                <Image source={{ uri: url }} style={styles.photoGridImage} resizeMode="cover" />
              </Pressable>
            ))}
          </View>
        </Section>
      ) : null}

      {hasSignature ? (
        <Section title="Customer signature" icon="signature">
          <Pressable accessibilityRole="button" accessibilityLabel="View signature" style={styles.signaturePreviewBox} onPress={onOpenSignature}>
            <Image source={{ uri: claim.customerSignatureUrl! }} style={styles.signaturePreviewImage} resizeMode="contain" />
          </Pressable>
        </Section>
      ) : null}
    </>
  );
}

function HistoryTab({ claim }: { claim: Claim }) {
  if (claim.statusHistory.length === 0) {
    return <EmptyState icon="activity" title="No history yet" message="Status changes for this claim will be recorded here." />;
  }

  return (
    <>
      {claim.statusHistory.map((entry, index) => {
        const isLast = index === claim.statusHistory.length - 1;
        return (
          <View key={index} style={styles.historyRow}>
            <View style={styles.historyTimelineCol}>
              <View style={[styles.historyDot, isLast && styles.historyDotActive]} />
              {!isLast ? <View style={styles.historyLine} /> : null}
            </View>
            <View style={styles.historyTextBox}>
              <Text style={[styles.historyStatus, isLast && styles.historyStatusActive]}>{claimStatusDisplayText(entry.status)}</Text>
              <Text style={styles.historyMeta}>{entry.timestamp.toLocaleString()}</Text>
              <Text style={styles.historyMeta}>by {entry.userName}</Text>
              {entry.notes ? <Text style={styles.historyNotes}>{entry.notes}</Text> : null}
            </View>
          </View>
        );
      })}
    </>
  );
}

function CommentsTab({
  claim,
  commentText,
  onChangeComment,
  onSend,
}: {
  claim: Claim;
  commentText: string;
  onChangeComment: (text: string) => void;
  onSend: () => void;
}) {
  return (
    <View style={styles.commentsContainer}>
      {claim.comments.length === 0 ? (
        <EmptyState icon="message" title="No comments yet" message="Internal notes and comments on this claim will appear here." />
      ) : (
        <ScrollView style={styles.commentsList} contentContainerStyle={styles.commentsListContent}>
          {claim.comments.map((comment) => (
            <View key={comment.id} style={[styles.commentCard, comment.isInternal ? styles.commentCardInternal : styles.commentCardExternal]}>
              <View style={styles.commentHeaderRow}>
                <View style={[styles.commentAvatar, { backgroundColor: comment.isInternal ? colors.attention : colors.active }]}>
                  <Text style={styles.commentAvatarText}>{comment.userName.charAt(0).toUpperCase()}</Text>
                </View>
                <View style={styles.commentHeaderTextBox}>
                  <View style={styles.commentNameRow}>
                    <Text style={styles.commentName}>{comment.userName}</Text>
                    {comment.isInternal ? <StatusChip label="Internal" tone="warning" /> : null}
                  </View>
                  <Text style={styles.commentTimestamp}>{comment.timestamp.toLocaleString()}</Text>
                </View>
              </View>
              <Text style={styles.commentBody}>{comment.comment}</Text>
            </View>
          ))}
        </ScrollView>
      )}

      <View style={styles.commentInputRow}>
        <FormField
          label="Comment"
          containerStyle={styles.commentInput}
          placeholder="Add a comment…"
          multiline
          inputStyle={styles.commentInputText}
          value={commentText}
          onChangeText={onChangeComment}
        />
        <IconButton icon="arrowRight" accessibilityLabel="Send comment" color={colors.shell} onPress={onSend} />
      </View>
    </View>
  );
}

function Section({ title, icon, children }: { title: string; icon: AppIconName; children: React.ReactNode }) {
  return (
    <Card style={styles.section}>
      <View style={styles.sectionHeaderRow}>
        <AppIcon name={icon} size={18} color={colors.shell} />
        <Text style={styles.sectionTitle}>{title}</Text>
      </View>
      {children}
    </Card>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}:</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
  );
}

function ActionRow({ label, icon, onPress }: { label: string; icon: AppIconName; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} style={styles.actionRow} onPress={onPress}>
      <AppIcon name={icon} size={20} color={colors.contentSecondary} />
      <Text style={styles.actionRowLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.canvas },
  statusBanner: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  statusBannerText: { ...textStyles.label },
  tabStrip: { backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border, flexGrow: 0 },
  tabStripContent: { paddingHorizontal: spacing.medium, gap: spacing.small },
  tabButton: { paddingHorizontal: spacing.medium, paddingVertical: spacing.medium, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabButtonActive: { borderBottomColor: colors.shell },
  tabButtonText: { ...textStyles.label, color: colors.contentSecondary },
  tabButtonTextActive: { color: colors.shell },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge, gap: spacing.medium },
  section: { marginBottom: spacing.medium },
  sectionHeaderRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginBottom: spacing.small + 4 },
  sectionTitle: { ...textStyles.heading3, color: colors.shell },
  infoRow: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: spacing.small + 4 },
  infoLabel: { width: 120, ...textStyles.bodySmall, fontWeight: '600', color: colors.contentSecondary },
  infoValue: { flex: 1, ...textStyles.bodyMedium, color: colors.contentPrimary },
  amountRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small, marginBottom: spacing.small },
  amountValue: { ...textStyles.bodyLarge, fontWeight: '600', flex: 1 },
  descriptionText: { ...textStyles.bodyMedium, lineHeight: 21 },
  affectedItemCard: { backgroundColor: colors.surfaceMuted, borderRadius: radii.inputRadius, borderWidth: 1, borderColor: colors.border, padding: spacing.small + 4, marginBottom: spacing.small },
  affectedItemName: { ...textStyles.label },
  affectedItemQty: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: spacing.xs },
  mapsLinkButton: { alignSelf: 'flex-start', marginTop: spacing.small + 4 },
  evidenceScoreRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  evidenceScoreTrack: { flex: 1, height: 10, borderRadius: 5, backgroundColor: colors.surfaceMuted, overflow: 'hidden' },
  evidenceScoreFill: { height: 10, borderRadius: 5 },
  evidenceScoreText: { ...textStyles.label, fontWeight: '700' },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small + 4 },
  photoGridItem: { width: '47%', aspectRatio: 1, borderRadius: radii.inputRadius, overflow: 'hidden', backgroundColor: colors.surfaceMuted },
  photoGridImage: { width: '100%', height: '100%' },
  signaturePreviewBox: { height: 200, borderWidth: 1, borderColor: colors.border, borderRadius: radii.inputRadius, backgroundColor: colors.surface, overflow: 'hidden' },
  signaturePreviewImage: { width: '100%', height: '100%' },
  historyRow: { flexDirection: 'row', marginBottom: spacing.small },
  historyTimelineCol: { alignItems: 'center', width: 40 },
  historyDot: { width: 16, height: 16, borderRadius: 8, backgroundColor: colors.border },
  historyDotActive: { backgroundColor: colors.shell },
  historyLine: { width: 2, flex: 1, backgroundColor: colors.border, marginTop: 4 },
  historyTextBox: { flex: 1, paddingBottom: spacing.medium },
  historyStatus: { ...textStyles.label },
  historyStatusActive: { color: colors.shell, fontWeight: '700' },
  historyMeta: { ...textStyles.bodySmall, color: colors.contentSecondary, marginTop: 2 },
  historyNotes: { ...textStyles.bodySmall, color: colors.contentPrimary, backgroundColor: colors.surfaceMuted, borderRadius: radii.inputRadius, padding: spacing.small + 4, marginTop: spacing.small },
  commentsContainer: { flex: 1 },
  commentsList: { flex: 1 },
  commentsListContent: { padding: spacing.medium },
  commentCard: { borderRadius: radii.cardRadius, borderWidth: 1, padding: spacing.small + 4, marginBottom: spacing.medium },
  commentCardInternal: { backgroundColor: colors.attentionMuted, borderColor: colors.attention },
  commentCardExternal: { backgroundColor: colors.activeMuted, borderColor: colors.active },
  commentHeaderRow: { flexDirection: 'row', alignItems: 'center' },
  commentAvatar: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  commentAvatarText: { color: colors.onPrimary, fontWeight: '700' },
  commentHeaderTextBox: { flex: 1 },
  commentNameRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  commentName: { ...textStyles.label },
  commentTimestamp: { ...textStyles.bodySmall, color: colors.contentSecondary },
  commentBody: { ...textStyles.bodyMedium, marginTop: spacing.small },
  commentInputRow: { flexDirection: 'row', alignItems: 'flex-end', gap: spacing.small, padding: spacing.medium, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border },
  commentInput: { flex: 1 },
  commentInputText: { maxHeight: 100, minHeight: 48, textAlignVertical: 'top' },
  actionButtonsRow: { flexDirection: 'row', gap: spacing.medium, padding: spacing.medium, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border },
  actionButton: { flex: 1 },
  modalBackdrop: { flex: 1, backgroundColor: colors.scrim, justifyContent: 'flex-end' },
  actionSheet: { backgroundColor: colors.surface, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium, paddingVertical: spacing.medium },
  actionRowLabel: { ...textStyles.label },
  modalHint: { ...textStyles.bodyMedium, color: colors.contentSecondary, marginBottom: spacing.medium },
  modalTextArea: { minHeight: 80, textAlignVertical: 'top' },
  modalButtonRow: { flexDirection: 'row', gap: spacing.medium },
  modalButton: { flex: 1 },
  photoViewerContainer: { flex: 1, backgroundColor: '#000000' },
  photoViewerHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.medium, paddingVertical: spacing.small },
  photoViewerTitle: { color: colors.onPrimary, ...textStyles.label },
  photoViewerPage: { alignItems: 'center', justifyContent: 'center' },
  photoViewerImage: { height: '100%' },
  signatureViewerImage: { width: '100%', height: 250 },
});
