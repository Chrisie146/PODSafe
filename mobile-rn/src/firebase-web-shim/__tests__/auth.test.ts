jest.mock('firebase/auth', () => ({
  getAuth: jest.fn(() => ({ __auth: true, currentUser: { uid: 'u1' } })),
  onAuthStateChanged: jest.fn(() => () => undefined),
  signInWithEmailAndPassword: jest.fn(async () => ({ user: { uid: 'u1' } })),
  createUserWithEmailAndPassword: jest.fn(async () => ({ user: { uid: 'u2' } })),
  signOut: jest.fn(async () => undefined),
  sendPasswordResetEmail: jest.fn(async () => undefined),
  connectAuthEmulator: jest.fn(),
}));
jest.mock('../../config/firebase.web', () => ({ getWebFirebaseApp: () => ({ __app: true }) }));

import * as fbAuth from 'firebase/auth';
import auth from '../auth';

describe('auth shim', () => {
  it('exposes currentUser from the modular auth instance', () => {
    expect(auth().currentUser).toEqual({ uid: 'u1' });
  });

  it('delegates signInWithEmailAndPassword to the modular fn with the auth instance', async () => {
    await auth().signInWithEmailAndPassword('a@b.com', 'pw');
    expect(fbAuth.signInWithEmailAndPassword).toHaveBeenCalledWith(
      expect.objectContaining({ __auth: true }), 'a@b.com', 'pw',
    );
  });

  it('returns an unsubscribe from onAuthStateChanged', () => {
    const unsub = auth().onAuthStateChanged(() => undefined);
    expect(typeof unsub).toBe('function');
  });

  it('connects the auth emulator via useEmulator', () => {
    auth().useEmulator('http://localhost:9099');
    expect(fbAuth.connectAuthEmulator).toHaveBeenCalledWith(
      expect.objectContaining({ __auth: true }), 'http://localhost:9099',
    );
  });
});
