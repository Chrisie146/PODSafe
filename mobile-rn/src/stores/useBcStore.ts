import { create } from 'zustand';
import { BcConfig, defaultBcConfig } from '../models/bcConfig';
import { BcRepository } from '../repositories/bcRepository';

/**
 * Replaces direct lib/services/business_central_service.dart usage (bc_settings_screen.dart
 * instantiates `BusinessCentralService()` directly, no provider). Gives the BC domain
 * the same store treatment as the rest of the app. See bcRepository.ts's class-level
 * comment re: the 3 Cloud Functions this depends on not existing yet (Phase 5).
 */
const bcRepository = new BcRepository();

interface BcState {
  config: BcConfig | null;
  isLoading: boolean;
  isTesting: boolean;
  errorMessage: string | null;

  loadConfig: (companyId: string) => Promise<void>;
  saveConfig: (config: BcConfig) => Promise<void>;
  testConnection: (clientSecret: string) => Promise<boolean>;
  authenticate: (clientSecret: string) => Promise<string | null>;
  clearError: () => void;
}

export const useBcStore = create<BcState>((set, get) => ({
  config: null,
  isLoading: false,
  isTesting: false,
  errorMessage: null,

  loadConfig: async (companyId) => {
    set({ isLoading: true, errorMessage: null });
    const config = await bcRepository.getConfig(companyId);
    set({ config: config ?? defaultBcConfig(companyId), isLoading: false });
  },

  saveConfig: async (config) => {
    try {
      await bcRepository.saveConfig(config);
      set({ config });
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      throw e;
    }
  },

  testConnection: async (clientSecret) => {
    const { config } = get();
    if (!config) return false;

    set({ isTesting: true, errorMessage: null });
    try {
      const success = await bcRepository.testConnection(config, clientSecret);
      set({ isTesting: false });
      return success;
    } catch (e) {
      set({ isTesting: false, errorMessage: (e as Error).message });
      return false;
    }
  },

  authenticate: async (clientSecret) => {
    const { config } = get();
    if (!config) return null;

    try {
      return await bcRepository.authenticate(config, clientSecret);
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      return null;
    }
  },

  clearError: () => set({ errorMessage: null }),
}));
