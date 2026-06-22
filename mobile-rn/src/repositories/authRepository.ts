import auth, { FirebaseAuthTypes } from '@react-native-firebase/auth';
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import functions, { FirebaseFunctionsTypes } from '@react-native-firebase/functions';
import { AppUser, ApprovalStatus, UserRole } from '../models/user';
import { userFromFirestore, userToFirestore } from '../models/user.converters';

/**
 * Ported from lib/services/auth_service.dart (verified against source on 2026-06-21),
 * following the constructor-injected repository pattern from pod_repository.dart rather
 * than the hardcoded-singleton pattern the rest of the Flutter services use.
 *
 * NOTE: Flutter's createUserAsAdmin() (admin creates a driver, temporarily signing
 * itself out as a client-SDK workaround, then prompting the admin for their own
 * password to re-authenticate — see user_management_screen.dart's _AdminPasswordDialog)
 * is NOT ported here. createUserViaCloudFunction() below calls the `createUser` Cloud
 * Function being added in Phase 5 instead (see vault "08 Backend Gap Fix Tracker") —
 * an Admin-SDK server-side create doesn't touch the calling admin's own session at all,
 * which is the entire reason that workaround existed in the first place.
 */
export class AuthRepository {
  constructor(
    private authInstance: FirebaseAuthTypes.Module = auth(),
    private firestoreInstance: FirebaseFirestoreTypes.Module = firestore(),
    private functionsInstance: FirebaseFunctionsTypes.Module = functions(),
  ) {}

  get currentUser(): FirebaseAuthTypes.User | null {
    return this.authInstance.currentUser;
  }

  onAuthStateChanged(callback: (user: FirebaseAuthTypes.User | null) => void): () => void {
    return this.authInstance.onAuthStateChanged(callback);
  }

  async fetchAppUser(uid: string): Promise<AppUser | null> {
    const doc = await this.firestoreInstance.collection('users').doc(uid).get();
    return doc.exists() ? userFromFirestore(doc) : null;
  }

  async signInWithEmailAndPassword(email: string, password: string): Promise<AppUser | null> {
    try {
      const result = await this.authInstance.signInWithEmailAndPassword(email, password);
      if (!result.user) {
        return null;
      }

      const userDocRef = this.firestoreInstance.collection('users').doc(result.user.uid);
      const doc = await userDocRef.get();

      if (doc.exists()) {
        await userDocRef.update({ lastLoginAt: firestore.FieldValue.serverTimestamp() });
        return userFromFirestore(doc);
      }

      // Handles the case where a Firebase Auth user exists but the Firestore doc doesn't.
      const newUser: AppUser = {
        id: result.user.uid,
        email,
        fullName: result.user.displayName ?? email.split('@')[0],
        role: 'driver',
        companyId: 'default-company', // needs to be set by admin
        isActive: true,
        createdAt: new Date(),
        lastLoginAt: new Date(),
      };
      await userDocRef.set(userToFirestore(newUser));
      return newUser;
    } catch (e) {
      throw new Error(handleAuthError(e));
    }
  }

  async createUserWithEmailAndPassword(params: {
    email: string;
    password: string;
    fullName: string;
    companyId: string;
    role: UserRole;
    phoneNumber?: string;
  }): Promise<AppUser | null> {
    try {
      const result = await this.authInstance.createUserWithEmailAndPassword(params.email, params.password);
      if (!result.user) {
        return null;
      }

      const newUser: AppUser = {
        id: result.user.uid,
        email: params.email,
        fullName: params.fullName,
        role: params.role,
        companyId: params.companyId,
        phoneNumber: params.phoneNumber,
        isActive: true,
        createdAt: new Date(),
        lastLoginAt: new Date(),
      };

      await this.firestoreInstance.collection('users').doc(result.user.uid).set(userToFirestore(newUser));
      return newUser;
    } catch (e) {
      throw new Error(handleAuthError(e));
    }
  }

  async signOut(): Promise<void> {
    await this.authInstance.signOut();
  }

  async sendPasswordResetEmail(email: string): Promise<void> {
    try {
      await this.authInstance.sendPasswordResetEmail(email);
    } catch (e) {
      throw new Error(handleAuthError(e));
    }
  }

  async getUserById(userId: string): Promise<AppUser | null> {
    const doc = await this.firestoreInstance.collection('users').doc(userId).get();
    return doc.exists() ? userFromFirestore(doc) : null;
  }

  async updateUserProfile(user: AppUser): Promise<void> {
    await this.firestoreInstance.collection('users').doc(user.id).update(userToFirestore(user));
  }

  async getUsersByCompany(companyId: string, filters?: { role?: UserRole; approvalStatus?: ApprovalStatus }): Promise<AppUser[]> {
    let query: FirebaseFirestoreTypes.Query = this.firestoreInstance.collection('users').where('companyId', '==', companyId);
    if (filters?.role) {
      query = query.where('role', '==', filters.role);
    }
    if (filters?.approvalStatus) {
      query = query.where('approvalStatus', '==', filters.approvalStatus);
    }
    const snapshot = await query.get();
    return snapshot.docs.map(userFromFirestore);
  }

  /** Mirrors AuthService.toggleUserStatus(): a targeted single-field update. */
  async toggleUserStatus(userId: string, isActive: boolean): Promise<void> {
    await this.firestoreInstance.collection('users').doc(userId).update({ isActive });
  }

  /** Mirrors driver_details_screen.dart's `_deleteDriver` Firestore delete. */
  async deleteUser(userId: string): Promise<void> {
    await this.firestoreInstance.collection('users').doc(userId).delete();
  }

  /**
   * Calls the Phase 5 `createUser` Cloud Function — see class-level note. Will throw
   * "not-found"/similar until that callable is deployed; this is the real intended
   * integration code, not a placeholder.
   */
  async createUserViaCloudFunction(params: {
    email: string;
    password: string;
    fullName: string;
    companyId: string;
    role: UserRole;
    phoneNumber?: string;
  }): Promise<void> {
    const callable = this.functionsInstance.httpsCallable('createUser');
    await callable(params);
  }

  /**
   * Mirrors user_management_screen.dart's `_buildUserQuery` StreamBuilder, extended for
   * driver_management_screen.dart's per-approval-status tabs (`approvalStatus` filter +
   * `orderByCreatedAtDesc`, both opt-in so UserManagement.tsx's existing unordered,
   * unfiltered-by-approval-status usage is unaffected). Returns an unsubscribe function.
   */
  subscribeToUsersByCompany(
    companyId: string,
    onChange: (users: AppUser[]) => void,
    onError?: (error: Error) => void,
    filters?: { role?: UserRole; approvalStatus?: ApprovalStatus; orderByCreatedAtDesc?: boolean },
  ): () => void {
    let query: FirebaseFirestoreTypes.Query = this.firestoreInstance.collection('users').where('companyId', '==', companyId);
    if (filters?.role) {
      query = query.where('role', '==', filters.role);
    }
    if (filters?.approvalStatus) {
      query = query.where('approvalStatus', '==', filters.approvalStatus);
    }
    if (filters?.orderByCreatedAtDesc) {
      query = query.orderBy('createdAt', 'desc');
    }

    return query.onSnapshot(
      (snapshot) => onChange(snapshot.docs.map(userFromFirestore)),
      (error) => onError?.(error as unknown as Error),
    );
  }
}

function handleAuthError(error: unknown): string {
  const code = (error as { code?: string })?.code;
  switch (code) {
    case 'auth/user-not-found':
      return 'No user found with this email address.';
    case 'auth/wrong-password':
      return 'Invalid password.';
    case 'auth/email-already-in-use':
      return 'An account already exists with this email.';
    case 'auth/weak-password':
      return 'Password is too weak.';
    case 'auth/invalid-email':
      return 'Please enter a valid email address.';
    case 'auth/user-disabled':
      return 'This account has been disabled.';
    case 'auth/too-many-requests':
      return 'Too many failed attempts. Please try again later.';
    default:
      return 'Authentication failed. Please try again.';
  }
}
