import { AppUser } from '../../models/user';
import { hasPermission, hasRole, isDriverApproved } from '../permissionService';
import { canAccess } from '../featureAccess';

function makeUser(overrides: Partial<AppUser> = {}): AppUser {
  return {
    id: 'u1',
    email: 'a@b.com',
    fullName: 'Test User',
    role: 'driver',
    companyId: 'company-1',
    isActive: true,
    createdAt: new Date(),
    ...overrides,
  };
}

describe('permissionService', () => {
  it('admin has every permission', () => {
    const admin = makeUser({ role: 'admin' });
    expect(hasPermission(admin, 'usersManage')).toBe(true);
    expect(hasPermission(admin, 'financeEdit')).toBe(true);
    expect(hasPermission(admin, 'driverPodCapture')).toBe(true);
  });

  it('inactive users have no permissions regardless of role', () => {
    const admin = makeUser({ role: 'admin', isActive: false });
    expect(hasPermission(admin, 'usersManage')).toBe(false);
  });

  it('drivers need approvalStatus === "approved" before any permission passes', () => {
    const pendingDriver = makeUser({ role: 'driver', approvalStatus: 'pending' });
    const approvedDriver = makeUser({ role: 'driver', approvalStatus: 'approved' });

    expect(hasPermission(pendingDriver, 'podsUpload')).toBe(false);
    expect(hasPermission(approvedDriver, 'podsUpload')).toBe(true);
  });

  it('manager has the documented subset, not full admin access', () => {
    const manager = makeUser({ role: 'manager', approvalStatus: undefined });
    expect(hasPermission(manager, 'deliveriesApprove')).toBe(true);
    expect(hasPermission(manager, 'usersManage')).toBe(false);
  });

  it('hasRole matches only the exact role', () => {
    const logistics = makeUser({ role: 'logistics' });
    expect(hasRole(logistics, 'logistics')).toBe(true);
    expect(hasRole(logistics, 'admin')).toBe(false);
  });

  it('isDriverApproved requires both the driver role and approved status', () => {
    expect(isDriverApproved(makeUser({ role: 'driver', approvalStatus: 'approved' }))).toBe(true);
    expect(isDriverApproved(makeUser({ role: 'driver', approvalStatus: 'pending' }))).toBe(false);
    expect(isDriverApproved(makeUser({ role: 'manager', approvalStatus: 'approved' }))).toBe(false);
  });

  it('canAccess admin_dashboard only for admins', () => {
    expect(canAccess(makeUser({ role: 'admin' }), 'admin_dashboard')).toBe(true);
    expect(canAccess(makeUser({ role: 'manager' }), 'admin_dashboard')).toBe(false);
  });
});
