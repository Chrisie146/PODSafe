import { create } from 'zustand';
import { AppUser, UserRole } from '../models/user';
import { AuthRepository } from '../repositories/authRepository';

/**
 * Replaces lib/providers/auth_provider.dart's AuthProvider (ChangeNotifier).
 * See vault "03 Inventory - Providers to Stores" for the full mapping table.
 */

const authRepository = new AuthRepository();

interface AuthState {
  currentUser: AppUser | null;
  isLoading: boolean;
  isInitializing: boolean;
  errorMessage: string | null;

  isAdmin: boolean;
  isDriver: boolean;
  isManager: boolean;
  companyId: string | null;

  initialize: () => () => void;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (params: { email: string; password: string; fullName: string; companyId: string; role: UserRole; phoneNumber?: string }) => Promise<void>;
  signOut: () => Promise<void>;
  sendPasswordResetEmail: (email: string) => Promise<void>;
  clearError: () => void;
}

function deriveRoleFlags(user: AppUser | null) {
  return {
    isAdmin: user?.role === 'admin',
    isDriver: user?.role === 'driver',
    isManager: user?.role === 'manager',
    companyId: user?.companyId ?? null,
  };
}

export const useAuthStore = create<AuthState>((set) => ({
  currentUser: null,
  isLoading: false,
  isInitializing: true,
  errorMessage: null,
  ...deriveRoleFlags(null),

  initialize: () => {
    return authRepository.onAuthStateChanged(async (firebaseUser) => {
      if (!firebaseUser) {
        set({ currentUser: null, isInitializing: false, ...deriveRoleFlags(null) });
        return;
      }

      try {
        const appUser = await authRepository.fetchAppUser(firebaseUser.uid);
        set({ currentUser: appUser, isInitializing: false, ...deriveRoleFlags(appUser) });
      } catch {
        set({ currentUser: null, isInitializing: false, ...deriveRoleFlags(null) });
      }
    });
  },

  signIn: async (email, password) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const user = await authRepository.signInWithEmailAndPassword(email, password);
      set({ currentUser: user, isLoading: false, ...deriveRoleFlags(user) });
    } catch (e) {
      set({ isLoading: false, errorMessage: (e as Error).message });
      throw e;
    }
  },

  signUp: async (params) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const user = await authRepository.createUserWithEmailAndPassword(params);
      set({ currentUser: user, isLoading: false, ...deriveRoleFlags(user) });
    } catch (e) {
      set({ isLoading: false, errorMessage: (e as Error).message });
      throw e;
    }
  },

  signOut: async () => {
    await authRepository.signOut();
    set({ currentUser: null, ...deriveRoleFlags(null) });
  },

  sendPasswordResetEmail: async (email) => {
    await authRepository.sendPasswordResetEmail(email);
  },

  clearError: () => set({ errorMessage: null }),
}));
