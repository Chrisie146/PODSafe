export type UserRole =
  | 'admin'
  | 'manager'
  | 'logistics'
  | 'accountant'
  | 'filing_clerk'
  | 'driver';

export type ApprovalStatus = 'approved' | 'pending' | 'rejected';

export interface AppUser {
  id: string;
  email: string;
  fullName: string;
  role: UserRole;
  companyId: string;
  phoneNumber?: string;
  profileImageUrl?: string;
  isActive: boolean;
  createdAt: Date;
  lastLoginAt?: Date;
  licenseNumber?: string;
  vehicleInfo?: string;
  approvalStatus?: ApprovalStatus;
  approvedBy?: string;
  approvedAt?: Date;
}

/** Mirrors the `_getRoleDisplayName` helper duplicated across several admin screens (e.g. user_management_screen.dart). */
export function userRoleDisplayName(role: UserRole): string {
  switch (role) {
    case 'admin':
      return 'Administrator';
    case 'manager':
      return 'Manager';
    case 'logistics':
      return 'Logistics';
    case 'accountant':
      return 'Accountant';
    case 'filing_clerk':
      return 'Filing Clerk';
    case 'driver':
      return 'Driver';
  }
}

export const ALL_USER_ROLES: UserRole[] = ['admin', 'manager', 'logistics', 'accountant', 'filing_clerk', 'driver'];
