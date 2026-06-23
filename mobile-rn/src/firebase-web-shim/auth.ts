import {
  getAuth,
  onAuthStateChanged as fbOnAuthStateChanged,
  signInWithEmailAndPassword as fbSignIn,
  createUserWithEmailAndPassword as fbCreateUser,
  signOut as fbSignOut,
  sendPasswordResetEmail as fbSendReset,
  connectAuthEmulator,
  type Auth,
  type User as FbUser,
  type UserCredential,
} from 'firebase/auth';
import { getWebFirebaseApp } from '../config/firebase.web';

export interface AuthModule {
  readonly currentUser: FbUser | null;
  onAuthStateChanged(cb: (user: FbUser | null) => void): () => void;
  signInWithEmailAndPassword(email: string, password: string): Promise<UserCredential>;
  createUserWithEmailAndPassword(email: string, password: string): Promise<UserCredential>;
  signOut(): Promise<void>;
  sendPasswordResetEmail(email: string): Promise<void>;
  useEmulator(url: string): void;
}

function makeModule(instance: Auth): AuthModule {
  return {
    get currentUser() {
      return instance.currentUser;
    },
    onAuthStateChanged: (cb) => fbOnAuthStateChanged(instance, cb),
    signInWithEmailAndPassword: (email, password) => fbSignIn(instance, email, password),
    createUserWithEmailAndPassword: (email, password) => fbCreateUser(instance, email, password),
    signOut: () => fbSignOut(instance),
    sendPasswordResetEmail: (email) => fbSendReset(instance, email),
    useEmulator: (url) => connectAuthEmulator(instance, url),
  };
}

export default function auth(): AuthModule {
  return makeModule(getAuth(getWebFirebaseApp()));
}

// Type namespace parity with @react-native-firebase/auth.
export namespace FirebaseAuthTypes {
  export type User = FbUser;
  export type Module = AuthModule;
}
