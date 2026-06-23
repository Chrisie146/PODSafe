jest.mock('firebase/firestore', () => ({
  getFirestore: jest.fn(() => ({ __db: true })),
  collection: jest.fn((...args) => ({ __coll: args })),
  doc: jest.fn((...args) => ({ __doc: args, id: 'd1' })),
  getDoc: jest.fn(async () => ({ exists: () => true, id: 'd1', data: () => ({ a: 1 }) })),
  getDocs: jest.fn(async () => ({ docs: [], size: 0, empty: true })),
  setDoc: jest.fn(async () => undefined),
  updateDoc: jest.fn(async () => undefined),
  addDoc: jest.fn(async () => ({ id: 'new1' })),
  deleteDoc: jest.fn(async () => undefined),
  onSnapshot: jest.fn(() => () => undefined),
  query: jest.fn((...args) => ({ __query: args })),
  where: jest.fn((...a) => ({ __where: a })),
  orderBy: jest.fn((...a) => ({ __orderBy: a })),
  limit: jest.fn((n) => ({ __limit: n })),
  startAfter: jest.fn((s) => ({ __startAfter: s })),
  writeBatch: jest.fn(() => ({ set: jest.fn(), update: jest.fn(), delete: jest.fn(), commit: jest.fn() })),
  runTransaction: jest.fn(),
  serverTimestamp: jest.fn(() => 'SERVER_TS'),
  increment: jest.fn((n) => ({ __inc: n })),
  arrayUnion: jest.fn((...v) => ({ __au: v })),
  arrayRemove: jest.fn((...v) => ({ __ar: v })),
  documentId: jest.fn(() => '__docId'),
  connectFirestoreEmulator: jest.fn(),
  Timestamp: { fromDate: jest.fn((d) => ({ d })), now: jest.fn(() => ({ now: true })) },
  GeoPoint: function GeoPoint() {},
}));
jest.mock('../../config/firebase.web', () => ({ getWebFirebaseApp: () => ({ __app: true }) }));

import * as fs from 'firebase/firestore';
import firestore from '../firestore';

describe('firestore shim refs', () => {
  it('collection().doc().get() delegates to getDoc with the modular doc ref', async () => {
    const snap = await firestore().collection('users').doc('u1').get();
    expect(fs.collection).toHaveBeenCalledWith(expect.objectContaining({ __db: true }), 'users');
    expect(fs.doc).toHaveBeenCalled();
    expect(snap.exists()).toBe(true);
    expect(snap.data()).toEqual({ a: 1 });
  });

  it('doc().set() forwards data and options to setDoc', async () => {
    await firestore().doc('users/u1').set({ name: 'x' }, { merge: true });
    expect(fs.setDoc).toHaveBeenCalledWith(expect.anything(), { name: 'x' }, { merge: true });
  });

  it('doc().update() forwards to updateDoc', async () => {
    await firestore().doc('users/u1').update({ name: 'y' });
    expect(fs.updateDoc).toHaveBeenCalledWith(expect.anything(), { name: 'y' });
  });

  it('doc().delete() forwards to deleteDoc', async () => {
    await firestore().doc('users/u1').delete();
    expect(fs.deleteDoc).toHaveBeenCalled();
  });

  it('collection().add() returns a wrapped DocRef with id', async () => {
    const ref = await firestore().collection('users').add({ name: 'z' });
    expect(ref.id).toBe('new1');
  });

  it('doc().onSnapshot returns an unsubscribe function', () => {
    const unsub = firestore().doc('users/u1').onSnapshot(() => undefined);
    expect(typeof unsub).toBe('function');
  });

  it('useEmulator connects the firestore emulator', () => {
    firestore().useEmulator('localhost', 8080);
    expect(fs.connectFirestoreEmulator).toHaveBeenCalledWith(
      expect.objectContaining({ __db: true }), 'localhost', 8080,
    );
  });
});
