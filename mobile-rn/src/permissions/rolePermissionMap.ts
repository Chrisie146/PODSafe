import { ALL_PERMISSIONS, Permission } from './permission';
import { UserRole } from '../models/user';

/**
 * Role-to-Permission mapping, ported 1:1 from PermissionService._rolePermissions
 * in lib/services/permission_service.dart (verified directly against source on 2026-06-21).
 */
export const ROLE_PERMISSIONS: Record<UserRole, Set<Permission>> = {
  admin: new Set(ALL_PERMISSIONS),

  manager: new Set<Permission>([
    'deliveriesView',
    'deliveriesManage',
    'deliveriesApprove',
    'podsView',
    'podsApprove',
    'podsEdit',
    'financeView',
    'claimsView',
    'claimsApprove',
    'customersView',
    'analyticsView',
    'analyticsExport',
  ]),

  logistics: new Set<Permission>([
    'deliveriesView',
    'deliveriesManage',
    'deliveriesApprove',
    'podsView',
    'customersView',
    'customersManage',
    'claimsView',
  ]),

  accountant: new Set<Permission>([
    'deliveriesView',
    'podsView',
    'financeView',
    'financeExport',
    'financeEdit',
    'claimsView',
    'customersView',
    'analyticsView',
    'analyticsExport',
  ]),

  filing_clerk: new Set<Permission>([
    'deliveriesView',
    'podsView',
    'podsUpload',
    'podsEdit',
    'customersView',
  ]),

  driver: new Set<Permission>([
    'driverDeliveries',
    'driverPodCapture',
    'podsView',
    'podsUpload',
  ]),
};
