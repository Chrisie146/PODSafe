jest.mock('firebase/functions', () => ({
  getFunctions: jest.fn(() => ({ __fns: true })),
  httpsCallable: jest.fn(() => async (data: unknown) => ({ data })),
  connectFunctionsEmulator: jest.fn(),
}));
jest.mock('firebase/storage', () => ({
  getStorage: jest.fn(() => ({ __storage: true })),
  ref: jest.fn((_s, p) => ({ __ref: p })),
  uploadBytes: jest.fn(async () => ({ ok: true })),
  uploadString: jest.fn(async () => ({ ok: true })),
  getDownloadURL: jest.fn(async () => 'https://dl/x'),
  deleteObject: jest.fn(async () => undefined),
  connectStorageEmulator: jest.fn(),
}));
jest.mock('../../config/firebase.web', () => ({ getWebFirebaseApp: () => ({ __app: true }) }));

import * as fbFns from 'firebase/functions';
import * as fbStorage from 'firebase/storage';
import functions from '../functions';
import storage from '../storage';
import { WebUnsupportedError } from '../errors';

describe('functions shim', () => {
  it('httpsCallable returns a callable that resolves { data }', async () => {
    const callable = functions().httpsCallable('reverseGeocode');
    const res = await callable({ lat: 1, lng: 2 });
    expect(res.data).toEqual({ lat: 1, lng: 2 });
    expect(fbFns.httpsCallable).toHaveBeenCalledWith(expect.objectContaining({ __fns: true }), 'reverseGeocode');
  });
  it('useEmulator connects functions emulator', () => {
    functions().useEmulator('localhost', 5001);
    expect(fbFns.connectFunctionsEmulator).toHaveBeenCalledWith(expect.anything(), 'localhost', 5001);
  });
});

describe('storage shim', () => {
  it('ref().getDownloadURL delegates', async () => {
    const url = await storage().ref('a/b.png').getDownloadURL();
    expect(url).toBe('https://dl/x');
  });
  it('ref().put delegates to uploadBytes', async () => {
    const blob = {} as Blob;
    await storage().ref('a/b.png').put(blob);
    expect(fbStorage.uploadBytes).toHaveBeenCalled();
  });
  it('ref().delete delegates to deleteObject', async () => {
    await storage().ref('a/b.png').delete();
    expect(fbStorage.deleteObject).toHaveBeenCalled();
  });
  it('putFile throws WebUnsupportedError', () => {
    expect(() => storage().ref('a/b.png').putFile('/local/path')).toThrow(WebUnsupportedError);
  });
});
