import { create } from 'zustand';
import { Claim, ClaimComment, ClaimStatus, ClaimType } from '../models/claim';
import { CompanyClaimSettings } from '../models/companyClaimSettings';
import { getWorkflowForType as settingsGetWorkflowForType, getCustomFieldsForType as settingsGetCustomFieldsForType, isClaimTypeEnabled as settingsIsClaimTypeEnabled } from '../models/companyClaimSettings';
import { ApprovalRole, CustomFieldDefinition } from '../models/companyClaimSettings';
import { ClaimRepository } from '../repositories/claimRepository';
import { ALL_CLAIM_TYPES } from '../models/claim';

/**
 * Replaces lib/providers/claim_provider.dart's ClaimProvider (ChangeNotifier),
 * scoped to the driver-facing surface (see claimRepository.ts's class-level comment for
 * the full list of admin-only methods intentionally not wired up here).
 *
 * Deviations from the Flutter source:
 * - Only the filter fields actually used by driver screens are kept (statusFilter,
 *   driverIdFilter, searchQuery). The Flutter provider's customerNumberFilter /
 *   customerNameFilter / invoiceNumberFilter / orderNumberFilter / typeFilter /
 *   customerIdFilter / date-range filters are admin-only triage filters (used by the
 *   admin claims list, not my_claims_screen.dart, which only filters by status + free-text
 *   search client-side) and are left out; they can be added back when the admin claims
 *   list is ported in Phase 3.
 * - getClaimsPendingAction, approval/resolution/close mutations, and analytics are not
 *   exposed here — see claimRepository.ts's skip list.
 * - Firestore listeners are unsubscribed automatically when a new subscription replaces
 *   them, via an internally retained unsubscribe handle (the Flutter provider leaked its
 *   stream subscriptions, same issue noted in useDeliveryStore.ts).
 */

const claimRepository = new ClaimRepository();

interface ClaimState {
  companyId: string | null;
  settings: CompanyClaimSettings | null;
  allClaims: Claim[];
  claims: Claim[]; // filtered view, mirrors ClaimProvider.claims
  selectedClaim: Claim | null;
  pendingEvidenceClaims: Claim[];

  isLoading: boolean;
  isLoadingSettings: boolean;
  errorMessage: string | null;

  statusFilter: ClaimStatus | null;
  driverIdFilter: string | null;
  searchQuery: string | null;

  /** Mirrors ClaimProvider.initialize: sets companyId and loads settings. */
  initialize: (companyId: string) => Promise<void>;

  /** Mirrors ClaimProvider.loadSettings. */
  loadSettings: () => Promise<void>;

  /** Mirrors ClaimService.updateCompanySettings (admin settings editor). */
  updateSettings: (settings: CompanyClaimSettings) => Promise<boolean>;

  /** Mirrors ClaimProvider.loadClaimsForDriver: subscribes to this driver's claims. */
  loadClaimsForDriver: (driverId: string) => void;

  /** Mirrors ClaimProvider.loadAllClaims: subscribes to every claim in the company (admin dashboard). */
  loadAllClaims: () => void;

  /** Mirrors ClaimProvider.setStatusFilter. */
  setStatusFilter: (status: ClaimStatus | null) => void;

  /** Mirrors ClaimProvider.setSearchQuery. */
  setSearchQuery: (query: string | null) => void;

  /** Mirrors ClaimProvider.clearFilters (driver-relevant subset). */
  clearFilters: () => void;

  /** Mirrors ClaimProvider.createClaim. */
  createClaim: (claim: Claim) => Promise<string | null>;

  /** Mirrors ClaimProvider.updateClaim (e.g. editing the claimed amount). */
  updateClaim: (claim: Claim) => Promise<boolean>;

  /** Mirrors ClaimProvider.createClaimWithoutEvidence. */
  createClaimWithoutEvidence: (claim: Claim) => Promise<string | null>;

  /** Mirrors ClaimProvider.uploadEvidenceToClaim. */
  uploadEvidenceToClaim: (params: { claimId: string; photoUris?: string[]; signatureDataUrl?: string; documentUris?: string[] }) => Promise<boolean>;

  /** Mirrors ClaimProvider.getClaimsPendingEvidenceStream. */
  subscribeToPendingEvidence: (companyId: string) => void;

  /** Mirrors ClaimProvider.addComment. */
  addComment: (params: { claimId: string; comment: ClaimComment }) => Promise<boolean>;

  /** Mirrors ClaimProvider.updateClaimStatus (approval workflow — approve/reject/etc.). */
  updateClaimStatus: (params: { claimId: string; newStatus: ClaimStatus; userId: string; userName: string; notes?: string }) => Promise<boolean>;

  /** Mirrors ClaimProvider.getClaimById. */
  getClaimById: (claimId: string) => Promise<Claim | null>;

  /** Sets the currently viewed claim (used by ClaimDetails screen navigation). */
  setSelectedClaim: (claim: Claim | null) => void;

  /** Mirrors ClaimProvider.isClaimTypeEnabled. */
  isClaimTypeEnabled: (type: ClaimType) => boolean;

  /** Mirrors ClaimProvider.getEnabledClaimTypes. */
  getEnabledClaimTypes: () => ClaimType[];

  /** Mirrors ClaimProvider.getWorkflowForType. */
  getWorkflowForType: (type: ClaimType) => ApprovalRole[];

  /** Mirrors ClaimProvider.getCustomFieldsForType. */
  getCustomFieldsForType: (type: ClaimType) => CustomFieldDefinition[];

  /** Generates the next human-readable claim ID for the current company. */
  generateClaimId: () => Promise<string>;

  /** Uploads a photo for a claim being filed and returns its download URL. */
  uploadPhoto: (params: { claimId: string; fileUri: string; fileName: string }) => Promise<string>;

  /** Uploads a signature for a claim being filed and returns its download URL. */
  uploadSignature: (params: { claimId: string; signatureDataUrl: string; signatureType: 'customer' | 'driver' }) => Promise<string>;

  /** Pure scoring helper, delegated to the repository. */
  calculateEvidenceQualityScore: (claim: Claim) => number;

  /** Best-effort GPS read for evidence capture, delegated to the repository. */
  getCurrentLocation: () => Promise<Record<string, unknown>>;

  /** Mirrors ClaimProvider's dispose/clear-on-logout behavior. */
  clearData: () => void;
}

let claimsUnsubscribe: (() => void) | null = null;
let pendingEvidenceUnsubscribe: (() => void) | null = null;

function applyFilters(
  allClaims: Claim[],
  filters: { statusFilter: ClaimStatus | null; driverIdFilter: string | null; searchQuery: string | null },
): Claim[] {
  return allClaims.filter((claim) => {
    if (filters.statusFilter && claim.status !== filters.statusFilter) {
      return false;
    }
    if (filters.driverIdFilter && claim.driverId !== filters.driverIdFilter) {
      return false;
    }
    if (filters.searchQuery && filters.searchQuery.trim().length > 0) {
      const query = filters.searchQuery.toLowerCase();
      return (
        claim.id.toLowerCase().includes(query) ||
        claim.customerName.toLowerCase().includes(query) ||
        claim.driverName.toLowerCase().includes(query) ||
        claim.description.toLowerCase().includes(query) ||
        (claim.invoiceNumber?.toLowerCase().includes(query) ?? false)
      );
    }
    return true;
  });
}

export const useClaimStore = create<ClaimState>((set, get) => ({
  companyId: null,
  settings: null,
  allClaims: [],
  claims: [],
  selectedClaim: null,
  pendingEvidenceClaims: [],

  isLoading: false,
  isLoadingSettings: false,
  errorMessage: null,

  statusFilter: null,
  driverIdFilter: null,
  searchQuery: null,

  initialize: async (companyId) => {
    set({ companyId });
    await get().loadSettings();
  },

  loadSettings: async () => {
    const { companyId } = get();
    if (!companyId) return;

    set({ isLoadingSettings: true, errorMessage: null });
    try {
      const settings = await claimRepository.getCompanySettings(companyId);
      set({ settings, isLoadingSettings: false });
    } catch (e) {
      set({ errorMessage: `Failed to load settings: ${(e as Error).message}`, isLoadingSettings: false });
    }
  },

  updateSettings: async (settings) => {
    set({ isLoadingSettings: true, errorMessage: null });
    try {
      await claimRepository.updateCompanySettings(settings);
      set({ settings, isLoadingSettings: false });
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to save settings: ${(e as Error).message}`, isLoadingSettings: false });
      return false;
    }
  },

  loadClaimsForDriver: (driverId) => {
    const { companyId } = get();
    if (!companyId) return;

    set({ isLoading: true, errorMessage: null, driverIdFilter: driverId });
    claimsUnsubscribe?.();
    claimsUnsubscribe = claimRepository.subscribeToClaims(
      companyId,
      (allClaims) => {
        const { statusFilter, driverIdFilter, searchQuery } = get();
        set({
          allClaims,
          claims: applyFilters(allClaims, { statusFilter, driverIdFilter, searchQuery }),
          isLoading: false,
        });
      },
      (error) => set({ errorMessage: `Failed to load claims: ${error.message}`, isLoading: false }),
      { driverId },
    );
  },

  loadAllClaims: () => {
    const { companyId } = get();
    if (!companyId) return;

    set({ isLoading: true, errorMessage: null, driverIdFilter: null });
    claimsUnsubscribe?.();
    claimsUnsubscribe = claimRepository.subscribeToClaims(
      companyId,
      (allClaims) => {
        const { statusFilter, searchQuery } = get();
        set({
          allClaims,
          claims: applyFilters(allClaims, { statusFilter, driverIdFilter: null, searchQuery }),
          isLoading: false,
        });
      },
      (error) => set({ errorMessage: `Failed to load claims: ${error.message}`, isLoading: false }),
    );
  },

  setStatusFilter: (status) => {
    set((state) => ({
      statusFilter: status,
      claims: applyFilters(state.allClaims, { statusFilter: status, driverIdFilter: state.driverIdFilter, searchQuery: state.searchQuery }),
    }));
  },

  setSearchQuery: (query) => {
    set((state) => ({
      searchQuery: query,
      claims: applyFilters(state.allClaims, { statusFilter: state.statusFilter, driverIdFilter: state.driverIdFilter, searchQuery: query }),
    }));
  },

  clearFilters: () => {
    set((state) => ({
      statusFilter: null,
      searchQuery: null,
      claims: applyFilters(state.allClaims, { statusFilter: null, driverIdFilter: state.driverIdFilter, searchQuery: null }),
    }));
  },

  createClaim: async (claim) => {
    const { companyId } = get();
    if (!companyId) {
      set({ errorMessage: 'No company selected' });
      return null;
    }

    set({ isLoading: true, errorMessage: null });
    try {
      const claimId = await claimRepository.createClaim(claim);
      set({ isLoading: false });
      return claimId;
    } catch (e) {
      set({ errorMessage: `Failed to create claim: ${(e as Error).message}`, isLoading: false });
      return null;
    }
  },

  createClaimWithoutEvidence: async (claim) => {
    const { companyId } = get();
    if (!companyId) {
      set({ errorMessage: 'No company selected' });
      return null;
    }

    set({ isLoading: true, errorMessage: null });
    try {
      const claimId = await claimRepository.createClaimWithoutEvidence(companyId, claim);
      set({ isLoading: false });
      return claimId;
    } catch (e) {
      set({ errorMessage: `Failed to create claim: ${(e as Error).message}`, isLoading: false });
      return null;
    }
  },

  uploadEvidenceToClaim: async ({ claimId, photoUris, signatureDataUrl, documentUris }) => {
    const { companyId } = get();
    if (!companyId) {
      set({ errorMessage: 'No company selected' });
      return false;
    }

    try {
      await claimRepository.uploadEvidenceToClaim({ companyId, claimId, photoUris, signatureDataUrl, documentUris });
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to upload evidence: ${(e as Error).message}` });
      return false;
    }
  },

  subscribeToPendingEvidence: (companyId) => {
    pendingEvidenceUnsubscribe?.();
    pendingEvidenceUnsubscribe = claimRepository.subscribeToClaimsPendingEvidence(
      companyId,
      (pendingEvidenceClaims) => set({ pendingEvidenceClaims }),
      (error) => set({ errorMessage: `Failed to load claims pending evidence: ${error.message}` }),
    );
  },

  addComment: async ({ claimId, comment }) => {
    const { companyId } = get();
    if (!companyId) {
      set({ errorMessage: 'No company selected' });
      return false;
    }

    try {
      await claimRepository.addComment({ companyId, claimId, comment });
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to add comment: ${(e as Error).message}` });
      return false;
    }
  },

  updateClaim: async (claim) => {
    const { companyId } = get();
    if (!companyId) {
      set({ errorMessage: 'No company selected' });
      return false;
    }

    try {
      await claimRepository.updateClaim(companyId, claim);
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to update claim: ${(e as Error).message}` });
      return false;
    }
  },

  updateClaimStatus: async ({ claimId, newStatus, userId, userName, notes }) => {
    const { companyId } = get();
    if (!companyId) {
      set({ errorMessage: 'No company selected' });
      return false;
    }

    set({ isLoading: true, errorMessage: null });
    try {
      await claimRepository.updateClaimStatus({ companyId, claimId, newStatus, userId, userName, notes });
      set({ isLoading: false });
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to update status: ${(e as Error).message}`, isLoading: false });
      return false;
    }
  },

  getClaimById: async (claimId) => {
    const { companyId } = get();
    if (!companyId) return null;

    try {
      return await claimRepository.getClaim(companyId, claimId);
    } catch (e) {
      set({ errorMessage: `Failed to load claim: ${(e as Error).message}` });
      return null;
    }
  },

  setSelectedClaim: (claim) => set({ selectedClaim: claim }),

  isClaimTypeEnabled: (type) => {
    const { settings } = get();
    return settings ? settingsIsClaimTypeEnabled(settings, type) : true;
  },

  getEnabledClaimTypes: () => {
    const { settings } = get();
    return settings ? settings.enabledClaimTypes : ALL_CLAIM_TYPES;
  },

  getWorkflowForType: (type) => {
    const { settings } = get();
    return settings ? settingsGetWorkflowForType(settings, type) : [];
  },

  getCustomFieldsForType: (type) => {
    const { settings } = get();
    return settings ? settingsGetCustomFieldsForType(settings, type) : [];
  },

  generateClaimId: async () => {
    const { companyId } = get();
    if (!companyId) {
      throw new Error('Company ID not set');
    }
    return claimRepository.generateClaimId(companyId);
  },

  uploadPhoto: async ({ claimId, fileUri, fileName }) => {
    const { companyId } = get();
    if (!companyId) {
      throw new Error('Company ID not set');
    }
    return claimRepository.uploadPhoto({ companyId, claimId, fileUri, fileName });
  },

  uploadSignature: async ({ claimId, signatureDataUrl, signatureType }) => {
    const { companyId } = get();
    if (!companyId) {
      throw new Error('Company ID not set');
    }
    return claimRepository.uploadSignature({ companyId, claimId, signatureDataUrl, signatureType });
  },

  calculateEvidenceQualityScore: (claim) => claimRepository.calculateEvidenceQualityScore(claim),

  getCurrentLocation: () => claimRepository.getCurrentLocation(),

  clearData: () => {
    claimsUnsubscribe?.();
    claimsUnsubscribe = null;
    pendingEvidenceUnsubscribe?.();
    pendingEvidenceUnsubscribe = null;
    set({
      companyId: null,
      settings: null,
      allClaims: [],
      claims: [],
      selectedClaim: null,
      pendingEvidenceClaims: [],
      isLoading: false,
      isLoadingSettings: false,
      errorMessage: null,
      statusFilter: null,
      driverIdFilter: null,
      searchQuery: null,
    });
  },
}));
