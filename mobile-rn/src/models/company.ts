/**
 * Ported from lib/models/company_model.dart (verified against source on 2026-06-22).
 */
export interface CompanySettings {
  autoApproveDrivers: boolean;
  requireDriverApproval: boolean;
}

export function defaultCompanySettings(): CompanySettings {
  return { autoApproveDrivers: false, requireDriverApproval: true };
}

export interface Company {
  id: string;
  name: string;
  address: string;
  email: string;
  phone: string;
  registrationNumber?: string;
  logoUrl?: string;
  /** 'free' | 'basic' | 'premium' */
  plan: string;
  settings: CompanySettings;
  isActive: boolean;
  createdAt: Date;
  lastBackupDate?: Date;
}
