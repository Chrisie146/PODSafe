import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { AppUser, UserRole } from './user';

const VALID_ROLES: UserRole[] = ['admin', 'manager', 'logistics', 'accountant', 'filing_clerk', 'driver'];

export function userFromFirestore(doc: FirebaseFirestoreTypes.DocumentSnapshot): AppUser {
  const data = doc.data() ?? {};
  const role = VALID_ROLES.includes(data.role) ? (data.role as UserRole) : 'driver';

  return {
    id: doc.id,
    email: data.email ?? '',
    fullName: data.fullName ?? data.displayName ?? '',
    role,
    companyId: data.companyId ?? '',
    phoneNumber: data.phoneNumber,
    profileImageUrl: data.profileImageUrl,
    isActive: data.isActive ?? true,
    createdAt: data.createdAt?.toDate?.() ?? new Date(),
    lastLoginAt: data.lastLoginAt?.toDate?.(),
    licenseNumber: data.licenseNumber,
    vehicleInfo: data.vehicleInfo,
    approvalStatus: data.approvalStatus,
    approvedBy: data.approvedBy,
    approvedAt: data.approvedAt?.toDate?.(),
  };
}

export function userToFirestore(user: AppUser): Record<string, unknown> {
  return {
    email: user.email,
    fullName: user.fullName,
    displayName: user.fullName, // kept for backward compatibility with the Flutter app's field
    role: user.role,
    companyId: user.companyId,
    phoneNumber: user.phoneNumber ?? null,
    profileImageUrl: user.profileImageUrl ?? null,
    isActive: user.isActive,
    createdAt: firestore.Timestamp.fromDate(user.createdAt),
    lastLoginAt: user.lastLoginAt ? firestore.Timestamp.fromDate(user.lastLoginAt) : null,
    ...(user.licenseNumber ? { licenseNumber: user.licenseNumber } : {}),
    ...(user.vehicleInfo ? { vehicleInfo: user.vehicleInfo } : {}),
    ...(user.approvalStatus ? { approvalStatus: user.approvalStatus } : {}),
    ...(user.approvedBy ? { approvedBy: user.approvedBy } : {}),
    ...(user.approvedAt ? { approvedAt: firestore.Timestamp.fromDate(user.approvedAt) } : {}),
  };
}
