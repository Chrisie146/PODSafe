import {
  getFirestore,
  collection as fbCollection,
  doc as fbDoc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  addDoc,
  deleteDoc,
  onSnapshot as fbOnSnapshot,
  query as fbQuery,
  where as fbWhere,
  orderBy as fbOrderBy,
  limit as fbLimit,
  startAfter as fbStartAfter,
  writeBatch,
  runTransaction as fbRunTransaction,
  connectFirestoreEmulator,
  serverTimestamp as fbServerTimestamp,
  increment as fbIncrement,
  arrayUnion as fbArrayUnion,
  arrayRemove as fbArrayRemove,
  documentId as fbDocumentId,
  Timestamp as FbTimestamp,
  GeoPoint as FbGeoPoint,
  type Firestore,
  type DocumentReference as FbDocRef,
  type CollectionReference as FbCollRef,
  type Query as FbQuery,
  type QueryConstraint,
  type DocumentSnapshot,
  type QuerySnapshot,
  type WhereFilterOp,
  type OrderByDirection,
} from 'firebase/firestore';
import { getWebFirebaseApp } from '../config/firebase.web';

type DocCb = (snap: DocumentSnapshot) => void;
type QueryCb = (snap: QuerySnapshot) => void;
type ErrCb = (err: Error) => void;

class DocRef {
  constructor(readonly _ref: FbDocRef) {}
  get id(): string {
    return this._ref.id;
  }
  get(): Promise<DocumentSnapshot> {
    return getDoc(this._ref);
  }
  set(data: Record<string, unknown>, options?: { merge?: boolean }): Promise<void> {
    return options ? setDoc(this._ref, data, options) : setDoc(this._ref, data);
  }
  update(data: Record<string, unknown>): Promise<void> {
    return updateDoc(this._ref, data);
  }
  delete(): Promise<void> {
    return deleteDoc(this._ref);
  }
  collection(path: string): CollectionRef {
    return new CollectionRef(fbCollection(this._ref, path));
  }
  onSnapshot(onNext: DocCb, onError?: ErrCb): () => void {
    return fbOnSnapshot(this._ref, onNext, onError);
  }
}

class Query {
  constructor(readonly _ref: FbCollRef | FbQuery, readonly _constraints: QueryConstraint[] = []) {}
  protected _add(c: QueryConstraint): Query {
    return new Query(this._ref, [...this._constraints, c]);
  }
  where(field: string | object, op: WhereFilterOp, value: unknown): Query {
    return this._add(fbWhere(field as string, op, value));
  }
  orderBy(field: string | object, direction?: OrderByDirection): Query {
    return this._add(fbOrderBy(field as string, direction));
  }
  limit(n: number): Query {
    return this._add(fbLimit(n));
  }
  startAfter(snap: DocumentSnapshot): Query {
    return this._add(fbStartAfter(snap));
  }
  protected _compiled(): FbQuery {
    return this._constraints.length ? fbQuery(this._ref, ...this._constraints) : (this._ref as FbQuery);
  }
  get(): Promise<QuerySnapshot> {
    return getDocs(this._compiled());
  }
  onSnapshot(onNext: QueryCb, onError?: ErrCb): () => void {
    return fbOnSnapshot(this._compiled(), onNext, onError);
  }
}

class CollectionRef extends Query {
  constructor(readonly _coll: FbCollRef) {
    super(_coll);
  }
  doc(path?: string): DocRef {
    return new DocRef(path ? fbDoc(this._coll, path) : fbDoc(this._coll));
  }
  async add(data: Record<string, unknown>): Promise<DocRef> {
    const ref = await addDoc(this._coll, data);
    return new DocRef(ref);
  }
}

export interface FirestoreModule {
  collection(path: string): CollectionRef;
  doc(path: string): DocRef;
  batch(): WriteBatchShim;
  runTransaction<T>(fn: (tx: TransactionShim) => Promise<T>): Promise<T>;
  useEmulator(host: string, port: number): void;
}

export interface WriteBatchShim {
  set(ref: DocRef, data: Record<string, unknown>, options?: { merge?: boolean }): WriteBatchShim;
  update(ref: DocRef, data: Record<string, unknown>): WriteBatchShim;
  delete(ref: DocRef): WriteBatchShim;
  commit(): Promise<void>;
}
export interface TransactionShim {
  get(ref: DocRef): Promise<DocumentSnapshot>;
  set(ref: DocRef, data: Record<string, unknown>, options?: { merge?: boolean }): TransactionShim;
  update(ref: DocRef, data: Record<string, unknown>): TransactionShim;
  delete(ref: DocRef): TransactionShim;
}

function makeModule(db: Firestore): FirestoreModule {
  return {
    collection: (path) => new CollectionRef(fbCollection(db, path)),
    doc: (path) => new DocRef(fbDoc(db, path)),
    batch: () => makeBatch(db),
    runTransaction: (fn) => runTransactionShim(db, fn),
    useEmulator: (host, port) => connectFirestoreEmulator(db, host, port),
  };
}

function makeBatch(db: Firestore): WriteBatchShim {
  const b = writeBatch(db);
  const shim: WriteBatchShim = {
    set: (ref, data, options) => {
      options ? b.set(ref._ref, data, options) : b.set(ref._ref, data);
      return shim;
    },
    update: (ref, data) => {
      b.update(ref._ref, data);
      return shim;
    },
    delete: (ref) => {
      b.delete(ref._ref);
      return shim;
    },
    commit: () => b.commit(),
  };
  return shim;
}

function runTransactionShim<T>(db: Firestore, fn: (tx: TransactionShim) => Promise<T>): Promise<T> {
  return fbRunTransaction(db, (tx) => {
    const shim: TransactionShim = {
      get: (ref) => tx.get(ref._ref),
      set: (ref, data, options) => {
        options ? tx.set(ref._ref, data, options) : tx.set(ref._ref, data);
        return shim;
      },
      update: (ref, data) => {
        tx.update(ref._ref, data);
        return shim;
      },
      delete: (ref) => {
        tx.delete(ref._ref);
        return shim;
      },
    };
    return fn(shim);
  });
}

export default function firestore(): FirestoreModule {
  return makeModule(getFirestore(getWebFirebaseApp()));
}

// Statics attached to the default export, mirroring @react-native-firebase/firestore.
const FieldValue = {
  serverTimestamp: () => fbServerTimestamp(),
  increment: (n: number) => fbIncrement(n),
  arrayUnion: (...values: unknown[]) => fbArrayUnion(...values),
  arrayRemove: (...values: unknown[]) => fbArrayRemove(...values),
};
const FieldPath = {
  documentId: () => fbDocumentId(),
};

(firestore as unknown as Record<string, unknown>).Timestamp = FbTimestamp;
(firestore as unknown as Record<string, unknown>).GeoPoint = FbGeoPoint;
(firestore as unknown as Record<string, unknown>).FieldValue = FieldValue;
(firestore as unknown as Record<string, unknown>).FieldPath = FieldPath;

// Module-level alias to the Query class instance type, so the namespace member
// `Query` below can reference it without shadowing itself.
type QueryInstance = Query;

export namespace FirebaseFirestoreTypes {
  export type Module = FirestoreModule;
  export type DocumentSnapshot = import('firebase/firestore').DocumentSnapshot;
  export type QueryDocumentSnapshot = import('firebase/firestore').QueryDocumentSnapshot;
  export type QuerySnapshot = import('firebase/firestore').QuerySnapshot;
  export type Query = QueryInstance;
  export type Timestamp = FbTimestamp;
  export type GeoPoint = FbGeoPoint;
}

export { DocRef, CollectionRef, Query };
