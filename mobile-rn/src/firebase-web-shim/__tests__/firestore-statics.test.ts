jest.mock('firebase/firestore', () => ({
  getFirestore: jest.fn(() => ({ __db: true })),
  collection: jest.fn(), doc: jest.fn(), getDoc: jest.fn(), getDocs: jest.fn(),
  setDoc: jest.fn(), updateDoc: jest.fn(), addDoc: jest.fn(), deleteDoc: jest.fn(),
  onSnapshot: jest.fn(), query: jest.fn(), where: jest.fn(), orderBy: jest.fn(),
  limit: jest.fn(), startAfter: jest.fn(), writeBatch: jest.fn(), runTransaction: jest.fn(),
  connectFirestoreEmulator: jest.fn(),
  serverTimestamp: jest.fn(() => 'SERVER_TS'),
  increment: jest.fn((n) => ({ __inc: n })),
  arrayUnion: jest.fn((...v) => ({ __au: v })),
  arrayRemove: jest.fn((...v) => ({ __ar: v })),
  documentId: jest.fn(() => '__docId'),
  Timestamp: { fromDate: jest.fn((d) => ({ d })), now: jest.fn(() => ({ now: true })) },
  GeoPoint: function GeoPoint(this: { lat: number; lng: number }, lat: number, lng: number) {
    this.lat = lat;
    this.lng = lng;
  },
}));
jest.mock('../../config/firebase.web', () => ({ getWebFirebaseApp: () => ({ __app: true }) }));

import * as fs from 'firebase/firestore';
import firestore from '../firestore';

describe('firestore shim statics', () => {
  it('FieldValue.serverTimestamp delegates', () => {
    expect((firestore as any).FieldValue.serverTimestamp()).toBe('SERVER_TS');
  });
  it('FieldValue.increment delegates', () => {
    (firestore as any).FieldValue.increment(3);
    expect(fs.increment).toHaveBeenCalledWith(3);
  });
  it('FieldValue.arrayUnion / arrayRemove delegate', () => {
    (firestore as any).FieldValue.arrayUnion('a', 'b');
    expect(fs.arrayUnion).toHaveBeenCalledWith('a', 'b');
    (firestore as any).FieldValue.arrayRemove('c');
    expect(fs.arrayRemove).toHaveBeenCalledWith('c');
  });
  it('Timestamp.fromDate delegates to the SDK Timestamp', () => {
    const d = new Date('2026-06-23T00:00:00Z');
    expect((firestore as any).Timestamp.fromDate(d)).toEqual({ d });
  });
  it('FieldPath.documentId delegates', () => {
    (firestore as any).FieldPath.documentId();
    expect(fs.documentId).toHaveBeenCalled();
  });
  it('GeoPoint is the SDK GeoPoint', () => {
    const gp = new (firestore as any).GeoPoint(1, 2);
    expect(gp.lat).toBe(1);
    expect(gp.lng).toBe(2);
  });
});
