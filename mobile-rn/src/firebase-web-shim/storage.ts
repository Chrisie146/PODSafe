import {
  getStorage,
  ref as fbRef,
  uploadBytes,
  uploadString,
  getDownloadURL as fbGetDownloadURL,
  deleteObject,
  connectStorageEmulator,
  type FirebaseStorage,
  type StorageReference,
  type UploadMetadata,
} from 'firebase/storage';
import { getWebFirebaseApp } from '../config/firebase.web';
import { WebUnsupportedError } from './errors';

class StorageRef {
  constructor(readonly _ref: StorageReference) {}
  put(data: Blob | Uint8Array | ArrayBuffer, metadata?: UploadMetadata) {
    return uploadBytes(this._ref, data, metadata);
  }
  putString(data: string, format?: 'raw' | 'base64' | 'base64url' | 'data_url', metadata?: UploadMetadata) {
    return uploadString(this._ref, data, format, metadata);
  }
  getDownloadURL(): Promise<string> {
    return fbGetDownloadURL(this._ref);
  }
  delete(): Promise<void> {
    return deleteObject(this._ref);
  }
  putFile(_localPath: string): never {
    throw new WebUnsupportedError('storage().ref().putFile()');
  }
}

export interface StorageModule {
  ref(path: string): StorageRef;
  refFromURL(url: string): StorageRef;
  useEmulator(host: string, port: number): void;
}

function makeModule(instance: FirebaseStorage): StorageModule {
  return {
    ref: (path) => new StorageRef(fbRef(instance, path)),
    refFromURL: (url) => new StorageRef(fbRef(instance, url)),
    useEmulator: (host, port) => connectStorageEmulator(instance, host, port),
  };
}

export default function storage(): StorageModule {
  return makeModule(getStorage(getWebFirebaseApp()));
}

export namespace FirebaseStorageTypes {
  export type Module = StorageModule;
  export type Reference = StorageRef;
}
