import { create } from 'zustand';
import { AppUser, UserRole } from '../models/user';
import { AuthRepository } from '../repositories/authRepository';

/**
 * Backs lib/screens/admin/user_management_screen.dart's admin-facing user CRUD (list,
 * edit, activate/deactivate, reset password, approve driver). Deliberately separate
 * from useAuthStore, which is about the *current signed-in session*, not the company's
 * user list — same separation the Dart app has (AuthProvider vs. this screen reading
 * straight from Firestore).
 */
const authRepository = new AuthRepository();

let usersUnsubscribe: (() => void) | null = null;

interface UserManagementState {
  users: AppUser[];
  selectedUser: AppUser | null;
  isLoading: boolean;
  errorMessage: string | null;

  subscribeForCompany: (companyId: string, filters?: { role?: UserRole }) => void;
  loadUserById: (userId: string) => Promise<void>;
  toggleUserStatus: (userId: string, isActive: boolean) => Promise<void>;
  updateUser: (user: AppUser) => Promise<void>;
  deleteUser: (userId: string) => Promise<void>;
  sendPasswordResetEmail: (email: string) => Promise<void>;
  createUser: (params: { email: string; password: string; fullName: string; companyId: string; role: UserRole; phoneNumber?: string }) => Promise<void>;
  clear: () => void;
}

export const useUserManagementStore = create<UserManagementState>((set) => ({
  users: [],
  selectedUser: null,
  isLoading: false,
  errorMessage: null,

  subscribeForCompany: (companyId, filters) => {
    set({ isLoading: true, errorMessage: null });
    usersUnsubscribe?.();
    usersUnsubscribe = authRepository.subscribeToUsersByCompany(
      companyId,
      (users) => set({ users, isLoading: false }),
      (error) => set({ errorMessage: error.message, isLoading: false }),
      filters,
    );
  },

  loadUserById: async (userId) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const user = await authRepository.getUserById(userId);
      set({ selectedUser: user, isLoading: false, errorMessage: user ? null : 'Driver not found' });
    } catch (e) {
      set({ errorMessage: (e as Error).message, isLoading: false });
    }
  },

  toggleUserStatus: (userId, isActive) => authRepository.toggleUserStatus(userId, isActive),

  updateUser: (user) => authRepository.updateUserProfile(user),

  deleteUser: (userId) => authRepository.deleteUser(userId),

  sendPasswordResetEmail: (email) => authRepository.sendPasswordResetEmail(email),

  createUser: (params) => authRepository.createUserViaCloudFunction(params),

  clear: () => {
    usersUnsubscribe?.();
    usersUnsubscribe = null;
    set({ users: [], selectedUser: null, isLoading: false, errorMessage: null });
  },
}));
