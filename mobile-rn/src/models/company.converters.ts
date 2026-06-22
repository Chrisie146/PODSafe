import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { Company, CompanySettings, defaultCompanySettings } from './company';

/**
 * Ported from Company.fromFirestore/toFirestore + CompanySettings.fromMap/toMap in
 * lib/models/company_model.dart (verified against source on 2026-06-22).
 */
function companySettingsFromMap(map: Record<string, unknown>): CompanySettings {
  return {
    autoApproveDrivers: (map.autoApproveDrivers as boolean) ?? false,
    requireDriverApproval: (map.requireDriverApproval as boolean) ?? true,
  };
}

function companySettingsToMap(settings: CompanySettings): Record<string, unknown> {
  return {
    autoApproveDrivers: settings.autoApproveDrivers,
    requireDriverApproval: settings.requireDriverApproval,
  };
}

export function companyFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): Company {
  const data = doc.data() ?? {};

  return {
    id: doc.id,
    name: data.name ?? '',
    address: data.address ?? '',
    email: data.email ?? data.contactEmail ?? '',
    phone: data.phone ?? data.phoneNumber ?? '',
    registrationNumber: data.registrationNumber,
    logoUrl: data.logoUrl,
    plan: data.plan ?? 'free',
    settings: companySettingsFromMap(data.settings ?? {}),
    isActive: data.isActive ?? true,
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    lastBackupDate: data.lastBackupDate?.toDate?.(),
  };
}

export function companyToFirestore(company: Company): Record<string, unknown> {
  return {
    name: company.name,
    address: company.address,
    email: company.email,
    phone: company.phone,
    registrationNumber: company.registrationNumber ?? null,
    logoUrl: company.logoUrl ?? null,
    plan: company.plan,
    settings: companySettingsToMap(company.settings ?? defaultCompanySettings()),
    isActive: company.isActive,
    createdAt: firestore.Timestamp.fromDate(company.createdAt),
    ...(company.lastBackupDate ? { lastBackupDate: firestore.Timestamp.fromDate(company.lastBackupDate) } : {}),
  };
}
