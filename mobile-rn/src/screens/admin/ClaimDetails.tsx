// expects route.params: { claimId: string }
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Image, Linking, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View, useWindowDimensions } from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useClaimStore } from '../../stores/useClaimStore';
import { Claim, ClaimComment, ClaimStatus, claimStatusDisplayText, claimTypeDisplayText } from '../../models/claim';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from the MOBILE layout of lib/screens/admin/claim_details_screen.dart
 * (`ClaimDetailsMobile`, verified against source on 2026-06-22) — admin claim review:
 * details, evidence (photos/signature), status history, comments, and the
 * approve/reject workflow.
 *
 * Group A responsive-split screen — only the mobile path is ported this pass; the
 * >1000px desktop branch (`claim_details_desktop.dart`) lands in Phase 4. Note that file
 * already has the affected-items field-name fix below — see that bullet.
 *
 * Deviations from the Flutter source:
 * - Takes only `claimId` via route params. Prefers the live entry from
 *   `useClaimStore.allClaims` (kept fresh by ClaimsDashboard's subscription) and falls
 *   back to a one-time `getClaimById` fetch if not found there (e.g. a direct deep link
 *   with no dashboard subscription active) — same intent as the Dart source's
 *   `provider.claims.firstWhere(..., orElse: () => claim)`, just without requiring the
 *   caller to pass the (possibly stale) full Claim object.
 * - Added `claimRepository.updateClaimStatus()` / `useClaimStore.updateClaimStatus()` +
 *   `updateClaim()` this pass — the approve/reject workflow and the edit-amount path
 *   didn't have a write method yet (only driver-facing `createClaim` existed).
 * - Bug fix: the Dart MOBILE screen's affected-items list reads `item['productName']`,
 *   a field nothing ever writes (every claim-filing path writes `description`) — every
 *   affected item here permanently shows "Unknown Product" in production. The DESKTOP
 *   variant (`claim_details_desktop.dart`) already has the fix (`description ?? productName`);
 *   this port uses that same corrected lookup.
 * - No map library is installed yet (`react-native-maps` is deferred to whenever
 *   live_tracking_screen is tackled), so the GPS location section shows coordinates as
 *   text plus an "Open in Maps" link (`Linking.openURL` to a Google Maps query) instead
 *   of the Dart source's embedded `LocationMapWidget`.
 * - `CachedNetworkImage` becomes RN's built-in `Image` (per the package mapping
 *   decisions — no image-cache library needed for this app's usage).
 * - The overflow menu's "Assign to User"/"Change Priority"/"Export to PDF"/"Close Claim"
 *   stay honest "Coming Soon" placeholders, same as the Dart source (these show a plain
 *   snackbar, not a false success message, so they're not in the same category as the
 *   Copy-Link/Share-via-WhatsApp dead stubs fixed earlier in DeliveryDetails.tsx).
 *   "Download All Evidence" is wired for real via `Linking.openURL`, matching the Dart
 *   source's `url_launcher` calls.
 * - The full-screen photo viewer uses a horizontally paging ScrollView
 *   (`pagingEnabled`) instead of Dart's `PageView` + `InteractiveViewer` — swipeable, but
 *   no pinch-zoom (no gesture/zoom library installed; same degraded-but-honest tradeoff
 *   as DeliveryDetails.tsx's image viewer).
 */
const TABS = ['Details', 'Evidence', 'History', 'Comments'] as const;
type TabName = (typeof TABS)[number];

interface ClaimDetailsProps {
  route: { params: { claimId: string } };
  navigation: { navigate: (screen: string, params?: Record<string, unknown>) => void; goBack: () => void };
}

const ACTIONABLE_STATUSES: ClaimStatus[] = ['submitted', 'pendingReview', 'pendingApproval'];

const STATUS_BANNER: Record<string, { bg: string; text: string; message: string; icon: string }> = {
  submitted: { bg: '#BBDEFB', text: '#0D47A1', message: 'New claim awaiting review', icon: '🆕' },
  pendingReview: { bg: '#FFE0B2', text: '#E65100', message: 'Pending your review', icon: '⏳' },
  pendingApproval: { bg: '#FFECB3', text: '#FF6F00', message: 'Pending approval', icon: '✔' },
  approved: { bg: '#C8E6C9', text: '#1B5E20', message: 'Claim approved', icon: '✓' },
  rejected: { bg: '#FFCDD2', text: '#B71C1C', message: 'Claim rejected', icon: '✕' },
  resolved: { bg: '#B2DFDB', text: '#004D40', message: 'Claim resolved', icon: '☑' },
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
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  const banner = STATUS_BANNER[claim.status] ?? { bg: '#EEEEEE', text: '#424242', message: `Status: ${claim.status}`, icon: 'ℹ' };

  return (
    <View style={styles.container}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => navigation.goBack()}>
          <Text style={styles.headerBarAction}>‹ Back</Text>
        </Pressable>
        <Text style={textStyles.heading3}>{claim.id}</Text>
        <Pressable onPress={() => setShowActions(true)}>
          <Text style={styles.headerBarAction}>⋮</Text>
        </Pressable>
      </View>

      <View style={[styles.statusBanner, { backgroundColor: banner.bg }]}>
        <Text style={[styles.statusBannerIcon, { color: banner.text }]}>{banner.icon}</Text>
        <Text style={[styles.statusBannerText, { color: banner.text }]}>{banner.message}</Text>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabStrip} contentContainerStyle={styles.tabStripContent}>
        {TABS.map((tab) => (
          <Pressable key={tab} style={[styles.tabButton, activeTab === tab && styles.tabButtonActive]} onPress={() => setActiveTab(tab)}>
            <Text style={[styles.tabButtonText, activeTab === tab && styles.tabButtonTextActive]}>{tab}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        {activeTab === 'Details' ? <DetailsTab claim={claim} onEditAmount={handleEditAmount} /> : null}
        {activeTab === 'Evidence' ? (
          <EvidenceTab claim={claim} onOpenPhoto={(i) => setPhotoViewerIndex(i)} onOpenSignature={() => setShowSignatureViewer(true)} />
        ) : null}
        {activeTab === 'History' ? <HistoryTab claim={claim} /> : null}
        {activeTab === 'Comments' ? null : null}
      </ScrollView>

      {activeTab === 'Comments' ? (
        <CommentsTab claim={claim} commentText={commentText} onChangeComment={setCommentText} onSend={submitComment} />
      ) : null}

      {canTakeAction && activeTab !== 'Comments' ? (
        <View style={styles.actionButtonsRow}>
          <Pressable style={[styles.actionButton, styles.rejectButton]} disabled={isSubmitting} onPress={() => setShowReject(true)}>
            <Text style={styles.actionButtonText}>✕ Reject</Text>
          </Pressable>
          <Pressable style={[styles.actionButton, styles.approveButton]} disabled={isSubmitting} onPress={() => setShowApprove(true)}>
            <Text style={styles.actionButtonText}>✓ Approve</Text>
          </Pressable>
        </View>
      ) : null}

      <Modal visible={showActions} transparent animationType="fade" onRequestClose={() => setShowActions(false)}>
        <Pressable style={styles.modalBackdrop} onPress={() => setShowActions(false)}>
          <View style={[styles.actionSheet, shadows.card]}>
            <ActionRow label="Assign to User" icon="👤" onPress={() => comingSoon('Assign to User')} />
            <ActionRow label="Change Priority" icon="🚩" onPress={() => comingSoon('Change Priority')} />
            <ActionRow label="Export to PDF" icon="📄" onPress={() => comingSoon('Export to PDF')} />
            <ActionRow label="Download All Evidence" icon="⬇" onPress={handleDownloadAllEvidence} />
            <ActionRow label="Close Claim" icon="🔒" onPress={() => comingSoon('Close Claim')} />
          </View>
        </Pressable>
      </Modal>

      <Modal visible={showEditAmount} transparent animationType="fade" onRequestClose={() => setShowEditAmount(false)}>
        <View style={styles.modalCenterBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Edit Claim Amount</Text>
            <Text style={styles.modalHint}>Current Amount: R{claim.claimAmount?.toFixed(2) ?? '0.00'}</Text>
            <TextInput style={styles.modalInput} placeholder="0.00" keyboardType="decimal-pad" value={amountText} onChangeText={setAmountText} />
            <View style={styles.modalButtonRow}>
              <Pressable style={styles.modalSecondaryButton} onPress={() => setShowEditAmount(false)}>
                <Text style={styles.modalSecondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={styles.modalPrimaryButton} onPress={submitEditAmount}>
                <Text style={textStyles.buttonText}>Update Amount</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={showApprove} transparent animationType="fade" onRequestClose={() => setShowApprove(false)}>
        <View style={styles.modalCenterBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Approve Claim</Text>
            <Text style={styles.modalHint}>Approve claim {claim.id}?</Text>
            <TextInput style={[styles.modalInput, styles.modalTextArea]} placeholder="Add any notes or comments..." multiline value={approveNotes} onChangeText={setApproveNotes} />
            <View style={styles.modalButtonRow}>
              <Pressable style={styles.modalSecondaryButton} onPress={() => setShowApprove(false)}>
                <Text style={styles.modalSecondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={[styles.modalPrimaryButton, styles.approveButton]} onPress={submitApprove}>
                <Text style={textStyles.buttonText}>Approve</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={showReject} transparent animationType="fade" onRequestClose={() => setShowReject(false)}>
        <View style={styles.modalCenterBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={textStyles.heading3}>Reject Claim</Text>
            <Text style={styles.modalHint}>Reject claim {claim.id}?</Text>
            <TextInput style={[styles.modalInput, styles.modalTextArea]} placeholder="Provide a reason for rejection..." multiline value={rejectReason} onChangeText={setRejectReason} />
            <View style={styles.modalButtonRow}>
              <Pressable style={styles.modalSecondaryButton} onPress={() => setShowReject(false)}>
                <Text style={styles.modalSecondaryButtonText}>Cancel</Text>
              </Pressable>
              <Pressable style={[styles.modalPrimaryButton, styles.rejectButton]} onPress={submitReject}>
                <Text style={textStyles.buttonText}>Reject</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={photoViewerIndex != null} animationType="fade" onRequestClose={() => setPhotoViewerIndex(null)}>
        <View style={styles.photoViewerContainer}>
          <View style={styles.photoViewerHeader}>
            <Text style={styles.photoViewerTitle}>
              Photo {(photoViewerIndex ?? 0) + 1} of {claim.photoUrls.length}
            </Text>
            <Pressable onPress={() => setPhotoViewerIndex(null)}>
              <Text style={styles.photoViewerClose}>✕</Text>
            </Pressable>
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

      <Modal visible={showSignatureViewer} transparent animationType="fade" onRequestClose={() => setShowSignatureViewer(false)}>
        <View style={styles.modalCenterBackdrop}>
          <View style={[styles.modalCard, shadows.card]}>
            <View style={styles.signatureViewerHeaderRow}>
              <Text style={textStyles.heading3}>Customer Signature</Text>
              <Pressable onPress={() => setShowSignatureViewer(false)}>
                <Text style={styles.photoViewerClose}>✕</Text>
              </Pressable>
            </View>
            {claim.customerSignatureUrl ? <Image source={{ uri: claim.customerSignatureUrl }} style={styles.signatureViewerImage} resizeMode="contain" /> : null}
          </View>
        </View>
      </Modal>
    </View>
  );
}

function DetailsTab({ claim, onEditAmount }: { claim: Claim; onEditAmount: () => void }) {
    return (
      <>
        <Section title="Claim Information" icon="🧾">
          <InfoRow label="Claim ID" value={claim.id} />
          <InfoRow label="Type" value={claimTypeDisplayText(claim.type)} />
          <InfoRow label="Status" value={claimStatusDisplayText(claim.status)} />
          <InfoRow label="Priority" value={capitalize(claim.priority)} />
          <InfoRow label="Filed" value={claim.createdAt.toLocaleString()} />
          {claim.claimAmount != null ? (
            <View style={styles.amountRow}>
              <Text style={styles.infoLabel}>Claimed Amount:</Text>
              <Text style={styles.amountValue}>R{claim.claimAmount.toFixed(2)}</Text>
              <Pressable style={styles.editAmountButton} onPress={onEditAmount}>
                <Text style={styles.editAmountButtonText}>✎</Text>
              </Pressable>
            </View>
          ) : null}
        </Section>

        <Section title="Customer & Delivery" icon="👤">
          <InfoRow label="Customer" value={claim.customerName} />
          {claim.customerAccountNumber ? <InfoRow label="Customer ID" value={claim.customerAccountNumber} /> : null}
          <InfoRow label="Driver" value={claim.driverName} />
          <InfoRow label="Delivery ID" value={claim.deliveryId} />
          {claim.invoiceNumber ? <InfoRow label="Invoice" value={claim.invoiceNumber} /> : null}
        </Section>

        <Section title="Description" icon="📝">
          <Text style={styles.descriptionText}>{claim.description.length > 0 ? claim.description : 'No description provided'}</Text>
        </Section>

        {claim.affectedItems.length > 0 ? (
          <Section title={`Affected Items (${claim.affectedItems.length})`} icon="📦">
            {claim.affectedItems.map((item, i) => (
              <View key={i} style={styles.affectedItemCard}>
                <Text style={styles.affectedItemName}>{affectedItemName(item)}</Text>
                <Text style={styles.affectedItemQty}>Quantity: {String(item.quantity ?? 'N/A')}</Text>
              </View>
            ))}
          </Section>
        ) : null}

        {Object.keys(claim.gpsLocation).length > 0 ? (
          <Section title="Location" icon="📍">
            <InfoRow label="Coordinates" value={`${claim.gpsLocation.latitude}, ${claim.gpsLocation.longitude}`} />
            <Pressable
              style={styles.mapsLinkButton}
              onPress={() => openInMaps(Number(claim.gpsLocation.latitude), Number(claim.gpsLocation.longitude))}
            >
              <Text style={styles.mapsLinkButtonText}>🗺 Open in Maps</Text>
            </Pressable>
          </Section>
        ) : null}

        <Section title="Evidence Quality" icon="✅">
          <View style={styles.evidenceScoreRow}>
            <View style={styles.evidenceScoreTrack}>
              <View
                style={[
                  styles.evidenceScoreFill,
                  {
                    width: `${(claim.evidenceQualityScore / 10) * 100}%`,
                    backgroundColor: claim.evidenceQualityScore >= 7 ? colors.success : claim.evidenceQualityScore >= 5 ? colors.warning : colors.error,
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
      return (
        <View style={styles.emptyState}>
          <Text style={styles.emptyStateIcon}>🖼</Text>
          <Text style={styles.emptyStateText}>No evidence attached</Text>
        </View>
      );
    }

    return (
      <>
        {hasPhotos ? (
          <Section title={`Photos (${claim.photoUrls.length})`} icon="🖼">
            <View style={styles.photoGrid}>
              {claim.photoUrls.map((url, i) => (
                <Pressable key={i} style={styles.photoGridItem} onPress={() => onOpenPhoto(i)}>
                  <Image source={{ uri: url }} style={styles.photoGridImage} resizeMode="cover" />
                </Pressable>
              ))}
            </View>
          </Section>
        ) : null}

        {hasSignature ? (
          <Section title="Customer Signature" icon="✎">
            <Pressable style={styles.signaturePreviewBox} onPress={onOpenSignature}>
              <Image source={{ uri: claim.customerSignatureUrl! }} style={styles.signaturePreviewImage} resizeMode="contain" />
            </Pressable>
          </Section>
        ) : null}
      </>
    );
  }

function HistoryTab({ claim }: { claim: Claim }) {
    if (claim.statusHistory.length === 0) {
      return (
        <View style={styles.emptyState}>
          <Text style={styles.emptyStateIcon}>🕓</Text>
          <Text style={styles.emptyStateText}>No history yet</Text>
        </View>
      );
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
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateIcon}>💬</Text>
            <Text style={styles.emptyStateText}>No comments yet</Text>
          </View>
        ) : (
          <ScrollView style={styles.commentsList} contentContainerStyle={styles.commentsListContent}>
            {claim.comments.map((comment) => (
              <View key={comment.id} style={[styles.commentCard, comment.isInternal ? styles.commentCardInternal : styles.commentCardExternal]}>
                <View style={styles.commentHeaderRow}>
                  <View style={[styles.commentAvatar, { backgroundColor: comment.isInternal ? colors.warning : colors.info }]}>
                    <Text style={styles.commentAvatarText}>{comment.userName.charAt(0).toUpperCase()}</Text>
                  </View>
                  <View style={styles.commentHeaderTextBox}>
                    <View style={styles.commentNameRow}>
                      <Text style={styles.commentName}>{comment.userName}</Text>
                      {comment.isInternal ? (
                        <View style={styles.internalPill}>
                          <Text style={styles.internalPillText}>INTERNAL</Text>
                        </View>
                      ) : null}
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
          <TextInput style={styles.commentInput} placeholder="Add a comment..." multiline value={commentText} onChangeText={onChangeComment} />
          <Pressable style={styles.commentSendButton} onPress={onSend}>
            <Text style={styles.commentSendButtonText}>➤</Text>
          </Pressable>
        </View>
      </View>
    );
  }

function Section({ title, icon, children }: { title: string; icon: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeaderRow}>
        <Text style={styles.sectionIcon}>{icon}</Text>
        <Text style={styles.sectionTitle}>{title}</Text>
      </View>
      {children}
    </View>
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

function ActionRow({ label, icon, onPress }: { label: string; icon: string; onPress: () => void }) {
  return (
    <Pressable style={styles.actionRow} onPress={onPress}>
      <Text style={styles.actionRowIcon}>{icon}</Text>
      <Text style={styles.actionRowLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background },
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.medium,
  },
  headerBarAction: { color: colors.white, fontSize: 16, fontWeight: '600' },
  statusBanner: { flexDirection: 'row', alignItems: 'center', padding: spacing.medium },
  statusBannerIcon: { fontSize: 18, marginRight: spacing.small + 4 },
  statusBannerText: { fontSize: 15, fontWeight: '600' },
  tabStrip: { backgroundColor: colors.card, borderBottomWidth: 1, borderBottomColor: colors.divider },
  tabStripContent: { paddingHorizontal: spacing.medium, gap: spacing.small },
  tabButton: { paddingHorizontal: spacing.medium, paddingVertical: spacing.medium, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabButtonActive: { borderBottomColor: colors.primary },
  tabButtonText: { color: colors.textSecondary, fontWeight: '600' },
  tabButtonTextActive: { color: colors.primary },
  content: { flex: 1 },
  contentInner: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  section: { marginBottom: spacing.large },
  sectionHeaderRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small + 4 },
  sectionIcon: { fontSize: 18, marginRight: spacing.small, color: colors.primary },
  sectionTitle: { fontSize: 17, fontWeight: 'bold', color: colors.primary },
  infoRow: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: spacing.small + 4 },
  infoLabel: { width: 120, fontWeight: '600', color: colors.textSecondary },
  infoValue: { flex: 1, color: colors.textPrimary },
  amountRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.small + 4 },
  amountValue: { fontSize: 16, fontWeight: '500', marginRight: spacing.medium },
  editAmountButton: { backgroundColor: `${colors.primary}1A`, borderRadius: 4, padding: spacing.small - 2 },
  editAmountButtonText: { color: colors.primary, fontSize: 14 },
  descriptionText: { fontSize: 14, lineHeight: 21 },
  affectedItemCard: { backgroundColor: colors.card, borderRadius: radii.borderRadius, borderWidth: 1, borderColor: colors.divider, padding: spacing.small + 4, marginBottom: spacing.small },
  affectedItemName: { fontWeight: '600', fontSize: 14 },
  affectedItemQty: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },
  mapsLinkButton: { alignSelf: 'flex-start', marginTop: spacing.small + 4, backgroundColor: `${colors.primary}1A`, borderRadius: radii.borderRadius, paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4 },
  mapsLinkButtonText: { color: colors.primary, fontWeight: '600' },
  evidenceScoreRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.medium },
  evidenceScoreTrack: { flex: 1, height: 10, borderRadius: 5, backgroundColor: colors.divider, overflow: 'hidden' },
  evidenceScoreFill: { height: 10, borderRadius: 5 },
  evidenceScoreText: { fontWeight: 'bold', fontSize: 16 },
  emptyState: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.xLarge },
  emptyStateIcon: { fontSize: 56, opacity: 0.3 },
  emptyStateText: { fontSize: 16, color: colors.textSecondary, marginTop: spacing.medium },
  photoGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.small + 4 },
  photoGridItem: { width: '47%', aspectRatio: 1, borderRadius: radii.borderRadius, overflow: 'hidden', backgroundColor: colors.divider },
  photoGridImage: { width: '100%', height: '100%' },
  signaturePreviewBox: { height: 200, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, backgroundColor: colors.white, overflow: 'hidden' },
  signaturePreviewImage: { width: '100%', height: '100%' },
  historyRow: { flexDirection: 'row', marginBottom: spacing.small },
  historyTimelineCol: { alignItems: 'center', width: 40 },
  historyDot: { width: 16, height: 16, borderRadius: 8, backgroundColor: colors.divider },
  historyDotActive: { backgroundColor: colors.primary },
  historyLine: { width: 2, flex: 1, backgroundColor: colors.divider, marginTop: 4 },
  historyTextBox: { flex: 1, paddingBottom: spacing.medium },
  historyStatus: { fontSize: 15, fontWeight: '600' },
  historyStatusActive: { color: colors.primary, fontWeight: 'bold' },
  historyMeta: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  historyNotes: { fontSize: 13, backgroundColor: colors.card, borderRadius: radii.borderRadius, padding: spacing.small + 4, marginTop: spacing.small },
  commentsContainer: { flex: 1 },
  commentsList: { flex: 1 },
  commentsListContent: { padding: spacing.medium },
  commentCard: { borderRadius: radii.borderRadius, borderWidth: 1, padding: spacing.small + 4, marginBottom: spacing.medium },
  commentCardInternal: { backgroundColor: `${colors.warning}14`, borderColor: `${colors.warning}66` },
  commentCardExternal: { backgroundColor: `${colors.info}14`, borderColor: `${colors.info}66` },
  commentHeaderRow: { flexDirection: 'row', alignItems: 'center' },
  commentAvatar: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  commentAvatarText: { color: colors.white, fontWeight: 'bold' },
  commentHeaderTextBox: { flex: 1 },
  commentNameRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.small },
  commentName: { fontWeight: '600', fontSize: 14 },
  internalPill: { backgroundColor: colors.warning, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 1 },
  internalPillText: { fontSize: 10, fontWeight: 'bold', color: colors.white },
  commentTimestamp: { fontSize: 11, color: colors.textSecondary },
  commentBody: { fontSize: 14, marginTop: spacing.small },
  commentInputRow: { flexDirection: 'row', alignItems: 'flex-end', padding: spacing.medium, backgroundColor: colors.card, borderTopWidth: 1, borderTopColor: colors.divider, gap: spacing.small },
  commentInput: { flex: 1, borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, maxHeight: 100, backgroundColor: colors.background },
  commentSendButton: { backgroundColor: colors.primary, borderRadius: 20, width: 40, height: 40, alignItems: 'center', justifyContent: 'center' },
  commentSendButtonText: { color: colors.white, fontSize: 16 },
  actionButtonsRow: { flexDirection: 'row', gap: spacing.medium, padding: spacing.medium, backgroundColor: colors.card, borderTopWidth: 1, borderTopColor: colors.divider },
  actionButton: { flex: 1, alignItems: 'center', borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  approveButton: { backgroundColor: colors.success },
  rejectButton: { backgroundColor: colors.error },
  actionButtonText: { color: colors.white, fontWeight: 'bold' },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  modalCenterBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', alignItems: 'center', justifyContent: 'center', padding: spacing.large },
  actionSheet: { backgroundColor: colors.card, borderTopLeftRadius: radii.cardRadius, borderTopRightRadius: radii.cardRadius, padding: spacing.medium },
  actionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.medium },
  actionRowIcon: { fontSize: 18, marginRight: spacing.medium, width: 24, textAlign: 'center' },
  actionRowLabel: { fontSize: 15, fontWeight: '600' },
  modalCard: { backgroundColor: colors.card, borderRadius: radii.cardRadius, padding: spacing.large, width: '100%', maxWidth: 420, maxHeight: '80%' },
  modalHint: { color: colors.textSecondary, marginTop: spacing.small, marginBottom: spacing.medium },
  modalInput: { borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.small + 4, paddingVertical: spacing.small + 4, backgroundColor: colors.background },
  modalTextArea: { minHeight: 80, textAlignVertical: 'top' },
  modalButtonRow: { flexDirection: 'row', gap: spacing.medium, marginTop: spacing.large },
  modalSecondaryButton: { flex: 1, alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  modalSecondaryButtonText: { color: colors.textSecondary, fontWeight: '600' },
  modalPrimaryButton: { flex: 1, alignItems: 'center', backgroundColor: colors.primary, borderRadius: radii.buttonRadius, paddingVertical: spacing.small + 4 },
  photoViewerContainer: { flex: 1, backgroundColor: 'black' },
  photoViewerHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: spacing.medium },
  photoViewerTitle: { color: colors.white, fontSize: 15, fontWeight: '600' },
  photoViewerClose: { color: colors.white, fontSize: 22 },
  photoViewerPage: { alignItems: 'center', justifyContent: 'center' },
  photoViewerImage: { height: '100%' },
  signatureViewerHeaderRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.medium },
  signatureViewerImage: { width: '100%', height: 250 },
});
