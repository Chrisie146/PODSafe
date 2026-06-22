import { AppUser } from '../models/user';
import { hasAnyPermission, hasPermission, hasRole } from './permissionService';

/**
 * Typed replacement for permission_service.dart's stringly-typed canAccess(user, String feature).
 * The Flutter version takes a bare String with no compile-time safety — this Feature union
 * fixes that while preserving the exact same feature->permission mapping (verified against
 * lib/services/permission_service.dart on 2026-06-21).
 */
export type Feature =
  | 'user_management'
  | 'delivery_management'
  | 'pod_upload'
  | 'financial_reports'
  | 'analytics_dashboard'
  | 'claims_management'
  | 'customer_management'
  | 'driver_dashboard'
  | 'admin_dashboard';

export function canAccess(user: AppUser | null | undefined, feature: Feature): boolean {
  if (!user || !user.isActive) {
    return false;
  }

  switch (feature) {
    case 'user_management':
      return hasPermission(user, 'usersManage');
    case 'delivery_management':
      return hasAnyPermission(user, ['deliveriesManage', 'deliveriesView']);
    case 'pod_upload':
      return hasPermission(user, 'podsUpload');
    case 'financial_reports':
      return hasPermission(user, 'financeView');
    case 'analytics_dashboard':
      return hasPermission(user, 'analyticsView');
    case 'claims_management':
      return hasAnyPermission(user, ['claimsView', 'claimsApprove']);
    case 'customer_management':
      return hasAnyPermission(user, ['customersView', 'customersManage']);
    case 'driver_dashboard':
      return hasRole(user, 'driver') && user.approvalStatus === 'approved';
    case 'admin_dashboard':
      return hasRole(user, 'admin');
    default:
      return false;
  }
}
