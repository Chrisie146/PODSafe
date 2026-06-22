/**
 * Permission actions for RBAC system. Ported 1:1 from lib/models/permission.dart
 * (verified directly against source on 2026-06-21 — 24 values).
 */
export type Permission =
  // Delivery permissions
  | 'deliveriesView'
  | 'deliveriesManage'
  | 'deliveriesApprove'
  | 'deliveriesDelete'
  // POD (Proof of Delivery) permissions
  | 'podsView'
  | 'podsUpload'
  | 'podsApprove'
  | 'podsEdit'
  // Finance permissions
  | 'financeView'
  | 'financeExport'
  | 'financeEdit'
  // User management permissions (admin only)
  | 'usersView'
  | 'usersManage'
  | 'usersAssignRoles'
  // Claims permissions
  | 'claimsView'
  | 'claimsCreate'
  | 'claimsApprove'
  // Customer permissions
  | 'customersView'
  | 'customersManage'
  // Analytics permissions
  | 'analyticsView'
  | 'analyticsExport'
  // Reports permissions
  | 'reportsView'
  | 'reportsExport'
  // Driver-specific permissions
  | 'driverDeliveries'
  | 'driverPodCapture';

export const ALL_PERMISSIONS: Permission[] = [
  'deliveriesView',
  'deliveriesManage',
  'deliveriesApprove',
  'deliveriesDelete',
  'podsView',
  'podsUpload',
  'podsApprove',
  'podsEdit',
  'financeView',
  'financeExport',
  'financeEdit',
  'usersView',
  'usersManage',
  'usersAssignRoles',
  'claimsView',
  'claimsCreate',
  'claimsApprove',
  'customersView',
  'customersManage',
  'analyticsView',
  'analyticsExport',
  'reportsView',
  'reportsExport',
  'driverDeliveries',
  'driverPodCapture',
];

const DISPLAY_NAMES: Record<Permission, string> = {
  deliveriesView: 'View Deliveries',
  deliveriesManage: 'Manage Deliveries',
  deliveriesApprove: 'Approve Deliveries',
  deliveriesDelete: 'Delete Deliveries',
  podsView: 'View PODs',
  podsUpload: 'Upload PODs',
  podsApprove: 'Approve PODs',
  podsEdit: 'Edit PODs',
  financeView: 'View Finance',
  financeExport: 'Export Finance Data',
  financeEdit: 'Edit Finance',
  usersView: 'View Users',
  usersManage: 'Manage Users',
  usersAssignRoles: 'Assign Roles',
  claimsView: 'View Claims',
  claimsCreate: 'Create Claims',
  claimsApprove: 'Approve Claims',
  customersView: 'View Customers',
  customersManage: 'Manage Customers',
  analyticsView: 'View Analytics',
  analyticsExport: 'Export Analytics',
  reportsView: 'View Reports',
  reportsExport: 'Export Reports',
  driverDeliveries: 'Driver Deliveries',
  driverPodCapture: 'Capture POD',
};

const DESCRIPTIONS: Partial<Record<Permission, string>> = {
  deliveriesManage: 'Create, edit, and assign deliveries',
  deliveriesApprove: 'Approve delivery assignments and routes',
  podsUpload: 'Upload proof of delivery documents',
  podsApprove: 'Review and approve uploaded PODs',
  financeExport: 'Export financial reports and data',
  usersManage: 'Create, edit, and deactivate user accounts',
  usersAssignRoles: 'Assign and modify user roles',
};

export function permissionDisplayName(permission: Permission): string {
  return DISPLAY_NAMES[permission];
}

export function permissionDescription(permission: Permission): string {
  return DESCRIPTIONS[permission] ?? DISPLAY_NAMES[permission];
}
