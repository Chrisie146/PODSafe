import { AppUser, UserRole } from '../models/user';
import { Permission, permissionDisplayName } from './permission';
import { ROLE_PERMISSIONS } from './rolePermissionMap';

/**
 * Centralized RBAC permission management. Ported 1:1 from
 * lib/services/permission_service.dart (verified directly against source on 2026-06-21).
 */

export function hasPermission(user: AppUser | null | undefined, permission: Permission): boolean {
  if (!user || !user.isActive) {
    return false;
  }

  // Special check for drivers: must be approved
  if (user.role === 'driver' && user.approvalStatus !== 'approved') {
    return false;
  }

  const permissions = ROLE_PERMISSIONS[user.role];
  if (!permissions) {
    return false;
  }

  return permissions.has(permission);
}

export function hasAnyPermission(user: AppUser | null | undefined, permissions: Permission[]): boolean {
  return permissions.some(p => hasPermission(user, p));
}

export function hasAllPermissions(user: AppUser | null | undefined, permissions: Permission[]): boolean {
  return permissions.every(p => hasPermission(user, p));
}

export function hasAnyRole(user: AppUser | null | undefined, roles: UserRole[]): boolean {
  if (!user || !user.isActive) {
    return false;
  }
  return roles.includes(user.role);
}

export function hasRole(user: AppUser | null | undefined, role: UserRole): boolean {
  if (!user || !user.isActive) {
    return false;
  }
  return user.role === role;
}

export function getPermissionsForRole(role: UserRole): Set<Permission> {
  return ROLE_PERMISSIONS[role] ?? new Set();
}

/** Multi-tenancy helper — every Firestore query must filter on companyId. */
export function getCompanyId(user: AppUser | null | undefined): string | undefined {
  return user?.companyId;
}

export function isActive(user: AppUser | null | undefined): boolean {
  return !!user && user.isActive;
}

export function isDriverApproved(user: AppUser | null | undefined): boolean {
  if (!user || user.role !== 'driver') {
    return false;
  }
  return user.approvalStatus === 'approved' && user.isActive;
}

export class PermissionError extends Error {}

export function requireAdmin(user: AppUser | null | undefined): void {
  if (!hasRole(user, 'admin')) {
    throw new PermissionError('Admin access required');
  }
}

export function requireAnyRole(user: AppUser | null | undefined, roles: UserRole[]): void {
  if (!hasAnyRole(user, roles)) {
    throw new PermissionError(`Insufficient permissions: Required roles: ${roles.join(', ')}`);
  }
}

export function requirePermission(user: AppUser | null | undefined, permission: Permission): void {
  if (!hasPermission(user, permission)) {
    throw new PermissionError(`Insufficient permissions: ${permissionDisplayName(permission)} required`);
  }
}
