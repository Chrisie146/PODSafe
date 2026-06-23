jest.mock('firebase/firestore', () => {
  // Fake modular doc ref returned inside snapshots. Deliberately has NO
  // .update/.set/.delete — mirrors the real firebase/firestore v9+
  // DocumentReference, which only exposes those as free functions, not
  // instance methods. This is what makes the pre-wrap behavior fail.
  const fakeModularRef = { __modularRef: true, id: 'd1' };
  return {
    getFirestore: jest.fn(() => ({ __db: true })),
    collection: jest.fn((...args) => ({ __coll: args })),
    doc: jest.fn((...args) => ({ __doc: args, id: 'd1' })),
    getDoc: jest.fn(async () => ({
      exists: () => true,
      id: 'd1',
      data: () => ({ a: 1 }),
      ref: fakeModularRef,
    })),
    getDocs: jest.fn(async () => {
      const docs = [
        {
          ref: fakeModularRef,
          exists: () => true,
          id: 'd1',
          data: () => ({}),
        },
      ];
      return {
        docs,
        size: 1,
        empty: false,
        forEach: (cb: (d: unknown) => void) => docs.forEach(cb),
      };
    }),
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
  };
});
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

describe('firestore shim snapshot.ref wrapping (instance methods on returned refs)', () => {
  // The real firebase/firestore v9+ DocumentReference has NO instance
  // .update()/.set()/.delete() — those are free functions. Consumers
  // (chatRepository.ts, deliveryRepository.ts, podTokenRepository.ts,
  // DataMigration.tsx) call `doc.ref.update(...)` and `batch.update(doc.ref, ...)`
  // on snapshot refs, so the shim must wrap snapshots so `.ref` is a shim
  // DocRef exposing those instance methods.

  it('doc().get() result .ref is a shim DocRef whose .update() reaches updateDoc with a defined arg', async () => {
    const snap = await firestore().doc('users/u1').get();
    expect(typeof (snap.ref as any).update).toBe('function');
    await (snap.ref as any).update({ a: 1 });
    expect(fs.updateDoc).toHaveBeenCalledWith(expect.objectContaining({ __modularRef: true }), { a: 1 });
  });

  it('doc().get() result still exposes .exists()/.data()/.id after wrapping', async () => {
    const snap = await firestore().doc('users/u1').get();
    expect(snap.exists()).toBe(true);
    expect(snap.data()).toEqual({ a: 1 });
    expect(snap.id).toBe('d1');
  });

  it('query.get() result docs[].ref is a shim DocRef whose .update() reaches updateDoc', async () => {
    const snap = await firestore().collection('users').where('isRead', '==', false).get();
    expect(snap.docs).toHaveLength(1);
    await (snap.docs[0].ref as any).update({ x: 1 });
    expect(fs.updateDoc).toHaveBeenCalledWith(expect.objectContaining({ __modularRef: true }), { x: 1 });
  });

  it('query.get() result docs[].ref works with batch.update (modular ref resolves via ._ref)', async () => {
    const batch = firestore().batch();
    const snap = await firestore().collection('tokens').where('isActive', '==', true).get();
    batch.update(snap.docs[0].ref as any, { isActive: false });
    expect((fs.writeBatch as jest.Mock).mock.results[0].value.update).toHaveBeenCalledWith(
      expect.objectContaining({ __modularRef: true }),
      { isActive: false },
    );
  });

  it('query.get() result preserves .size/.empty/.forEach after wrapping', async () => {
    const snap = await firestore().collection('users').get();
    expect(snap.size).toBe(1);
    expect(snap.empty).toBe(false);
    const seen: unknown[] = [];
    snap.forEach((d: any) => seen.push(d.id));
    expect(seen).toEqual(['d1']);
  });

  it('forEach callback receives wrapped docs whose .ref has .update()', async () => {
    const snap = await firestore().collection('tokens').where('isActive', '==', true).get();
    const refs: any[] = [];
    snap.forEach((d: any) => refs.push(d.ref));
    expect(typeof refs[0].update).toBe('function');
  });
});
