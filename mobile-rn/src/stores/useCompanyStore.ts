import { create } from 'zustand';
import { Company } from '../models/company';
import { CompanyRepository } from '../repositories/companyRepository';

/**
 * Replaces direct lib/services/company_service.dart usage (the Dart app calls
 * CompanyService directly from screens — there's no CompanyProvider). This store gives
 * the company domain the same Zustand-store treatment as every other domain, per the
 * migration plan's 1:1 store-per-domain rule.
 */
const companyRepository = new CompanyRepository();

let companyUnsubscribe: (() => void) | null = null;

interface CompanyState {
  company: Company | null;
  isLoading: boolean;
  errorMessage: string | null;

  registerCompany: (params: {
    companyName: string;
    companyEmail: string;
    companyPhone: string;
    companyAddress: string;
    adminName: string;
    adminEmail: string;
    adminPassword: string;
  }) => Promise<string>;
  subscribeToCompany: (companyId: string) => void;
  updateCompany: (companyId: string, data: Record<string, unknown>) => Promise<void>;
  verifyCompanyCode: (companyCode: string) => Promise<boolean>;
  getCompanyName: (companyCode: string) => Promise<string | null>;
  clear: () => void;
}

export const useCompanyStore = create<CompanyState>((set) => ({
  company: null,
  isLoading: false,
  errorMessage: null,

  registerCompany: (params) => companyRepository.registerCompany(params),

  subscribeToCompany: (companyId) => {
    set({ isLoading: true, errorMessage: null });
    companyUnsubscribe?.();
    companyUnsubscribe = companyRepository.subscribeToCompany(
      companyId,
      (company) => set({ company, isLoading: false }),
      (error) => set({ errorMessage: `Failed to load company: ${error.message}`, isLoading: false }),
    );
  },

  updateCompany: async (companyId, data) => {
    try {
      await companyRepository.updateCompany(companyId, data);
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      throw e;
    }
  },

  verifyCompanyCode: (companyCode) => companyRepository.verifyCompanyCode(companyCode),

  getCompanyName: (companyCode) => companyRepository.getCompanyName(companyCode),

  clear: () => {
    companyUnsubscribe?.();
    companyUnsubscribe = null;
    set({ company: null, isLoading: false, errorMessage: null });
  },
}));
