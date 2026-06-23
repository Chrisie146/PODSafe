# RNW Web Parity — M1 (Toolchain) + M2 (Firebase Shim) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mobile-rn` build and run as a React Native Web target that logs in and renders a real-data admin screen, by adding the web toolchain (M1) and a webpack-aliased `@react-native-firebase/*` shim over the `firebase` JS SDK (M2).

**Architecture:** A web-only `index.web.js` boots the app into a DOM root. `webpack.config.js` aliases `react-native` → `react-native-web` and each `@react-native-firebase/*` module → a local shim in `src/firebase-web-shim/`. The shim re-implements the *namespaced* RNFirebase API (`auth()`, `firestore().collection().doc().get()`, statics, etc.) on top of the modular `firebase` JS SDK, so the existing ~47 native-Firebase files compile and run unchanged on web. Native (Metro) never resolves `.web.*` files or the webpack aliases, so the Android build is untouched.

**Tech Stack:** React 19.2.3, React Native 0.86, `react-native-web` 0.21, `firebase` JS SDK (modular, v11), webpack 5, babel-loader, jest.

## Global Constraints

- **Never touch the native build path.** No edits to `index.js`, `babel.config.js`, `metro.config.js`, or any `@react-native-firebase` import in existing source. Web behaviour is added exclusively via new `.web.*` files and `webpack.config.js`.
- **Never touch `lib/`, `podsafe/`, `ios/`, `android/`** or any `.dart`/`.swift`/`.kt`/`.java` file.
- **Branch:** `beta_v1.0`.
- **App name:** `PodSafeRN` (from `app.json`) — `index.web.js` must register/run this exact name.
- **Firebase project:** `podsafe-f4a47`.
- **Shim covers only the audited API surface** in `docs/superpowers/specs/2026-06-23-rnw-web-parity-design.md` — no speculative methods (YAGNI). A called-but-unimplemented method must throw a clear named error, never fail silently.
- **TDD:** shim translation logic is unit-tested by mocking the modular `firebase/*` functions and asserting delegation. Toolchain tasks are gated on build/run command output.
- **Refinement vs spec:** modular `firebase/firestore` already exposes `DocumentSnapshot.exists()` as a method and `.data()/.id/.metadata`, so query/doc **snapshots are returned unwrapped**. Only `CollectionReference`, `DocumentReference`, `Query`, `WriteBatch`, and `Transaction` are wrapped (chaining API divergence).

---

## File Structure

**M1 (create):**
- `mobile-rn/public/index.html` — DOM root host.
- `mobile-rn/index.web.js` — web entry: polyfill → firebase init → run app.
- `mobile-rn/src/config/environment.web.ts` — env from `process.env` (replaces `react-native-config`).
- `mobile-rn/src/config/firebase.web.ts` — `initializeApp` with web config.
- `mobile-rn/webpack.config.js` — aliases, loaders, plugins.
- `mobile-rn/.env.web.example` — documented web config keys.
- `mobile-rn/package.json` — add `firebase` dep + `web`/`build:web` scripts (modify).

**M2 (create):**
- `mobile-rn/src/firebase-web-shim/errors.ts` — `WebUnsupportedError`, `NotImplementedError`.
- `mobile-rn/src/firebase-web-shim/app.ts` — `getApp()`.
- `mobile-rn/src/firebase-web-shim/auth.ts` — `auth()` + `FirebaseAuthTypes`.
- `mobile-rn/src/firebase-web-shim/firestore.ts` — `firestore()` + refs/query/batch/transaction + statics + `FirebaseFirestoreTypes`.
- `mobile-rn/src/firebase-web-shim/functions.ts` — `functions()` + `FirebaseFunctionsTypes`.
- `mobile-rn/src/firebase-web-shim/storage.ts` — `storage()` + `FirebaseStorageTypes`.
- `mobile-rn/src/firebase-web-shim/__tests__/*.test.ts` — translation unit tests.

---

## M1 — Toolchain

### Task 1: Add `firebase` dependency and web scripts

**Files:**
- Modify: `mobile-rn/package.json`

**Interfaces:**
- Produces: `firebase` JS SDK available to import; npm scripts `web` (dev server) and `build:web` (bundle).

- [ ] **Step 1: Install the firebase JS SDK**

Run (from `mobile-rn/`):
```bash
npm install firebase@^11
```
Expected: `firebase` appears under `dependencies` in `package.json`, install completes with no peer-dependency errors that block (React 19 is supported by firebase 11).

- [ ] **Step 2: Add web scripts**

In `mobile-rn/package.json`, add to the `"scripts"` object (keep existing entries):
```json
    "web": "webpack serve --mode development --config webpack.config.js",
    "build:web": "webpack --mode production --config webpack.config.js"
```

- [ ] **Step 3: Verify**

Run:
```bash
node -e "console.log(require('firebase/package.json').version)"
```
Expected: prints an `11.x` version string.

- [ ] **Step 4: Commit**

```bash
git add mobile-rn/package.json mobile-rn/package-lock.json
git commit -m "build(mobile-rn): add firebase JS SDK + web npm scripts"
```

---

### Task 2: Web entry, env, firebase init, HTML host, webpack config

This task is the M1 toolchain as one deliverable: the web build boots `App` to the Login screen. (No unit test — gated on `npm run build:web` succeeding and a manual `npm run web` render. The `@react-native-firebase/*` aliases are added but point to shims that arrive in M2; to boot to Login *without* invoking Firebase, the firebase aliases are added in Task 7. In this task only the `react-native` → `react-native-web` alias and toolchain exist, and the build is verified by compiling a Firebase-free entry.)

**Files:**
- Create: `mobile-rn/public/index.html`
- Create: `mobile-rn/src/config/environment.web.ts`
- Create: `mobile-rn/src/config/firebase.web.ts`
- Create: `mobile-rn/index.web.js`
- Create: `mobile-rn/webpack.config.js`
- Create: `mobile-rn/.env.web.example`

**Interfaces:**
- Consumes: nothing from earlier tasks except the installed `firebase` dep.
- Produces:
  - `environment.web.ts` exporting `EnvironmentConfig` with the same shape as `src/config/environment.ts`.
  - `firebase.web.ts` exporting `getWebFirebaseApp(): FirebaseApp` and side-effect `initializeApp` on import.
  - `webpack.config.js` exporting a config whose `resolve.alias` maps `react-native` → `react-native-web` and (added in Task 7) the five `@react-native-firebase/*` modules → `src/firebase-web-shim/*`, with `resolve.extensions` preferring `.web.tsx`/`.web.ts`.

- [ ] **Step 1: Create the HTML host**

`mobile-rn/public/index.html`:
```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />
    <title>PODSafe</title>
    <style>
      html, body, #root { height: 100%; margin: 0; }
      #root { display: flex; }
    </style>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
```

- [ ] **Step 2: Create the web environment config**

`react-native-config` is native-only; on web the values come from `process.env` injected by webpack's `DefinePlugin` (Step 6). Keep the exact same export shape as `src/config/environment.ts` so importers are unaffected.

`mobile-rn/src/config/environment.web.ts`:
```ts
/**
 * Web counterpart of environment.ts. react-native-config does not work under
 * react-native-web, so values are read from process.env, injected at build time by
 * webpack DefinePlugin (see webpack.config.js). Resolution order in webpack prefers
 * this .web.ts over environment.ts for the web target only; Metro never resolves it.
 */
export type Environment = 'development' | 'production';

const env = (process.env.ENVIRONMENT as Environment) ?? 'development';

export const EnvironmentConfig = {
  current: env,
  isDevelopment: env === 'development',
  isProduction: env === 'production',

  enableVerboseLogging: env === 'development',
  enableDebugLogging: env === 'development',
  enableDebugTools: env === 'development',
  showEnvironmentBanner: process.env.SHOW_ENVIRONMENT_BANNER === 'true',

  enableCrashlytics: false,
  reportErrorsToFirebase: env === 'production',
  enableAnalytics: false,
  collectDetailedAnalytics: env === 'production',

  enforceStrictSecurity: env === 'production',

  environmentName: env === 'production' ? 'PRODUCTION' : 'DEVELOPMENT',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID ?? 'podsafe-f4a47',
  publicPodBaseUrl: process.env.PUBLIC_POD_BASE_URL ?? 'http://localhost:5000',
  useFirebaseEmulators: process.env.USE_FIREBASE_EMULATORS === 'true',
  firebaseEmulatorHost: process.env.FIREBASE_EMULATOR_HOST || 'localhost',
  firebaseAuthEmulatorPort: Number(process.env.FIREBASE_AUTH_EMULATOR_PORT) || 9099,
};
```

- [ ] **Step 3: Create the web Firebase init**

`mobile-rn/src/config/firebase.web.ts`:
```ts
import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';

/**
 * Web-only Firebase initialization using the plain JS SDK. The firebase-web-shim
 * modules (aliased over @react-native-firebase/*) call getApp() to reach this instance.
 * Config comes from process.env, injected by webpack DefinePlugin.
 */
const webFirebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN,
  projectId: process.env.FIREBASE_PROJECT_ID,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.FIREBASE_APP_ID,
};

export function getWebFirebaseApp(): FirebaseApp {
  return getApps().length ? getApp() : initializeApp(webFirebaseConfig);
}

// Initialize eagerly on import so the shim modules can synchronously getApp().
getWebFirebaseApp();
```

- [ ] **Step 4: Create the web entry**

`mobile-rn/index.web.js`:
```js
/**
 * @format
 * React Native Web entry point. Native uses index.js; this file is webpack-only.
 */

// MUST be first — polyfills crypto.getRandomValues before uuid is imported (parity with index.js).
import 'react-native-get-random-values';

import { AppRegistry } from 'react-native';
import './src/config/firebase.web';
import { configureFirebaseEmulators } from './src/config/firebaseEmulators';
import { name as appName } from './app.json';

configureFirebaseEmulators();
const App = require('./App').default;

AppRegistry.registerComponent(appName, () => App);
AppRegistry.runApplication(appName, {
  rootTag: document.getElementById('root'),
});
```

- [ ] **Step 5: Create the env example**

`mobile-rn/.env.web.example`:
```
ENVIRONMENT=development
FIREBASE_API_KEY=
FIREBASE_AUTH_DOMAIN=podsafe-f4a47.firebaseapp.com
FIREBASE_PROJECT_ID=podsafe-f4a47
FIREBASE_STORAGE_BUCKET=podsafe-f4a47.appspot.com
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_APP_ID=
PUBLIC_POD_BASE_URL=http://localhost:5000
USE_FIREBASE_EMULATORS=false
FIREBASE_EMULATOR_HOST=localhost
FIREBASE_AUTH_EMULATOR_PORT=9099
```

> **Outward action (do not skip):** the real values for `FIREBASE_API_KEY`, `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_APP_ID` come from a **Firebase Web App** registered in the `podsafe-f4a47` console. Ask the user to register one (or authorize doing so) and place real values in a local `.env.web` (gitignored). The build compiles without them but auth/firestore calls fail at runtime until they are set.

- [ ] **Step 6: Create the webpack config**

`mobile-rn/webpack.config.js`:
```js
const path = require('path');
const webpack = require('webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const Dotenv = require('dotenv');

// Load .env.web (local, gitignored) if present; fall back to process env.
const fileEnv = Dotenv.config({ path: path.resolve(__dirname, '.env.web') }).parsed || {};
const ENV_KEYS = [
  'ENVIRONMENT', 'SHOW_ENVIRONMENT_BANNER',
  'FIREBASE_API_KEY', 'FIREBASE_AUTH_DOMAIN', 'FIREBASE_PROJECT_ID',
  'FIREBASE_STORAGE_BUCKET', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_APP_ID',
  'PUBLIC_POD_BASE_URL', 'USE_FIREBASE_EMULATORS',
  'FIREBASE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_PORT',
];
const defineEnv = ENV_KEYS.reduce((acc, k) => {
  acc[`process.env.${k}`] = JSON.stringify(fileEnv[k] ?? process.env[k] ?? '');
  return acc;
}, {});

// React Native and many RN-ecosystem packages ship untranspiled Flow/JSX and must
// pass through babel-loader (node_modules is otherwise excluded).
const compileNodeModules = [
  'react-native',
  'react-native-web',
  'react-native-safe-area-context',
  'react-native-svg',
  'react-native-get-random-values',
  '@react-navigation',
].map((m) => path.resolve(__dirname, 'node_modules', m));

module.exports = {
  entry: path.resolve(__dirname, 'index.web.js'),
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'bundle.[contenthash].js',
    publicPath: '/',
    clean: true,
  },
  resolve: {
    alias: {
      'react-native$': 'react-native-web',
      // Firebase shim aliases are added in Task 7.
    },
    extensions: ['.web.tsx', '.web.ts', '.web.js', '.tsx', '.ts', '.js'],
  },
  module: {
    rules: [
      {
        test: /\.(js|jsx|ts|tsx)$/,
        include: [path.resolve(__dirname, 'index.web.js'), path.resolve(__dirname, 'App.tsx'), path.resolve(__dirname, 'src'), ...compileNodeModules],
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['module:@react-native/babel-preset'],
            plugins: ['react-native-web'],
          },
        },
      },
      {
        test: /\.(png|jpe?g|gif|svg|ttf|woff2?)$/,
        type: 'asset/resource',
      },
    ],
  },
  plugins: [
    new HtmlWebpackPlugin({ template: path.resolve(__dirname, 'public/index.html') }),
    new webpack.DefinePlugin({ ...defineEnv, __DEV__: JSON.stringify(true) }),
  ],
  devServer: {
    static: { directory: path.resolve(__dirname, 'public') },
    historyApiFallback: true,
    port: 8082,
  },
};
```

> Note: `babel-plugin-react-native-web` and `dotenv` are transitive/utility deps. If `npm run build:web` reports either as missing, install with `npm install -D babel-plugin-react-native-web dotenv` and re-run.

- [ ] **Step 7: Gitignore the local web env**

Append to `mobile-rn/.gitignore` (create the line if absent):
```
.env.web
dist/
```

- [ ] **Step 8: Verify the build compiles**

Run (from `mobile-rn/`):
```bash
npm run build:web
```
Expected: webpack completes and writes `dist/bundle.<hash>.js` and `dist/index.html`. It is acceptable for the bundle to reference `@react-native-firebase/*` (still resolving to the real native packages at this point) — they are pure JS modules that compile; they only *fail at runtime* on web, which Task 7 fixes via aliasing. If the build errors on a missing babel plugin or loader, install it (Step 6 note) and re-run until green.

- [ ] **Step 9: Commit**

```bash
git add mobile-rn/public/index.html mobile-rn/index.web.js mobile-rn/webpack.config.js \
  mobile-rn/src/config/environment.web.ts mobile-rn/src/config/firebase.web.ts \
  mobile-rn/.env.web.example mobile-rn/.gitignore
git commit -m "feat(mobile-rn): add RNW web toolchain (webpack, web entry, web env + firebase init)"
```

---

## M2 — Firebase Web Shim

All shim modules live in `mobile-rn/src/firebase-web-shim/`. Tests mock the modular
`firebase/*` functions and assert the shim delegates with unwrapped arguments and
returns the wrapped result. No network or emulator is used in unit tests.

### Task 3: Shim errors, app, and auth

**Files:**
- Create: `mobile-rn/src/firebase-web-shim/errors.ts`
- Create: `mobile-rn/src/firebase-web-shim/app.ts`
- Create: `mobile-rn/src/firebase-web-shim/auth.ts`
- Test: `mobile-rn/src/firebase-web-shim/__tests__/auth.test.ts`

**Interfaces:**
- Consumes: `getWebFirebaseApp()` from `src/config/firebase.web.ts`.
- Produces:
  - `errors.ts`: `class WebUnsupportedError extends Error`, `class NotImplementedError extends Error`.
  - `app.ts`: default export — re-exports `getApp` from `firebase/app` (so `@react-native-firebase/app`'s `getApp` import resolves).
  - `auth.ts`: default export `auth(): AuthModule` where `AuthModule` has `currentUser` getter, `onAuthStateChanged(cb): () => void`, `signInWithEmailAndPassword(email, password)`, `createUserWithEmailAndPassword(email, password)`, `signOut()`, `sendPasswordResetEmail(email)`, `useEmulator(url)`. Also `export namespace FirebaseAuthTypes { type User = FbUser; type Module = AuthModule; }`.

- [ ] **Step 1: Write the failing auth test**

`mobile-rn/src/firebase-web-shim/__tests__/auth.test.ts`:
```ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/auth.test.ts
```
Expected: FAIL — `Cannot find module '../auth'` (and `../errors`, `../app` not yet created).

- [ ] **Step 3: Implement errors.ts**

`mobile-rn/src/firebase-web-shim/errors.ts`:
```ts
export class WebUnsupportedError extends Error {
  constructor(method: string) {
    super(`${method} is not supported on the web (react-native-web) target.`);
    this.name = 'WebUnsupportedError';
  }
}

export class NotImplementedError extends Error {
  constructor(method: string) {
    super(`${method} is not implemented in the firebase-web-shim. Add it to the shim if a web screen needs it.`);
    this.name = 'NotImplementedError';
  }
}
```

- [ ] **Step 4: Implement app.ts**

`mobile-rn/src/firebase-web-shim/app.ts`:
```ts
/**
 * Web shim for @react-native-firebase/app. Existing code imports { getApp } from it.
 * The firebase JS SDK app is initialized in src/config/firebase.web.ts.
 */
import { getApp } from 'firebase/app';

export { getApp };
export default { getApp };
```

- [ ] **Step 5: Implement auth.ts**

`mobile-rn/src/firebase-web-shim/auth.ts`:
```ts
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
```

- [ ] **Step 6: Run test to verify it passes**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/auth.test.ts
```
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add mobile-rn/src/firebase-web-shim/errors.ts mobile-rn/src/firebase-web-shim/app.ts \
  mobile-rn/src/firebase-web-shim/auth.ts mobile-rn/src/firebase-web-shim/__tests__/auth.test.ts
git commit -m "feat(mobile-rn): firebase-web-shim app + auth modules"
```

---

### Task 4: Shim firestore — references, get/set/update/delete, onSnapshot

**Files:**
- Create: `mobile-rn/src/firebase-web-shim/firestore.ts`
- Test: `mobile-rn/src/firebase-web-shim/__tests__/firestore-refs.test.ts`

**Interfaces:**
- Consumes: `getWebFirebaseApp()`.
- Produces: default export `firestore(): FirestoreModule`. `FirestoreModule` has `collection(path): CollectionRef`, `doc(path): DocRef`, `batch(): WriteBatchShim`, `runTransaction(fn): Promise<T>`, `useEmulator(host, port): void`.
  - `DocRef`: `{ readonly id: string; readonly _ref: FbDocRef; get(); set(data, options?); update(data); delete(); collection(path): CollectionRef; onSnapshot(onNext, onError?): () => void; }`
  - `CollectionRef`: `{ readonly _ref: FbCollRef; doc(path?): DocRef; add(data): Promise<DocRef>; where(...); orderBy(...); limit(n); startAfter(snap); get(); onSnapshot(...); }` (query methods provided in Task 5).
  - Snapshots from `get()`/`onSnapshot()` are the **unwrapped** modular `DocumentSnapshot`/`QuerySnapshot` (already expose `.exists()`, `.data()`, `.id`, `.docs`, `.size`, `.empty`, `.forEach`, `.metadata`).

> Task 4 implements `firestore.ts` with refs + doc operations and a placeholder `Query`. Task 5 fills in the query constraint chain, statics, batch, and transaction in the **same file**. Both tasks edit `firestore.ts`; Task 4 commits a compiling subset, Task 5 completes it.

- [ ] **Step 1: Write the failing refs test**

`mobile-rn/src/firebase-web-shim/__tests__/firestore-refs.test.ts`:
```ts
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
  Timestamp: class { static fromDate(d: Date) { return { d }; } static now() { return { now: true }; } },
  GeoPoint: class { constructor(public lat: number, public lng: number) {} },
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/firestore-refs.test.ts
```
Expected: FAIL — `Cannot find module '../firestore'`.

- [ ] **Step 3: Implement firestore.ts (refs + doc ops + lazy Query skeleton)**

`mobile-rn/src/firebase-web-shim/firestore.ts`:
```ts
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

// Batch + transaction implemented in Task 5; declared here for the interface.
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

// --- batch + transaction (completed in Task 5) ---
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

export { DocRef, CollectionRef, Query };
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/firestore-refs.test.ts
```
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile-rn/src/firebase-web-shim/firestore.ts \
  mobile-rn/src/firebase-web-shim/__tests__/firestore-refs.test.ts
git commit -m "feat(mobile-rn): firebase-web-shim firestore refs, doc ops, batch, transaction"
```

---

### Task 5: Shim firestore — statics (Timestamp/FieldValue/FieldPath/GeoPoint), query chain, type namespace

**Files:**
- Modify: `mobile-rn/src/firebase-web-shim/firestore.ts` (add statics + `FirebaseFirestoreTypes`)
- Test: `mobile-rn/src/firebase-web-shim/__tests__/firestore-statics.test.ts`

**Interfaces:**
- Consumes: the `firestore()` default export and classes from Task 4.
- Produces: the default-exported `firestore` function object also carries statics: `firestore.Timestamp`, `firestore.FieldValue` (`serverTimestamp()`, `increment(n)`, `arrayUnion(...v)`, `arrayRemove(...v)`), `firestore.FieldPath` (`documentId()`), `firestore.GeoPoint`. Plus `export namespace FirebaseFirestoreTypes` with `Module`, `DocumentSnapshot`, `QueryDocumentSnapshot`, `QuerySnapshot`, `Query`, `Timestamp`, `GeoPoint`.

- [ ] **Step 1: Write the failing statics test**

`mobile-rn/src/firebase-web-shim/__tests__/firestore-statics.test.ts`:
```ts
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
  Timestamp: { fromDate: (d: Date) => ({ d }), now: () => ({ now: true }) },
  GeoPoint: class { constructor(public lat: number, public lng: number) {} },
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/firestore-statics.test.ts
```
Expected: FAIL — `firestore.FieldValue` is undefined.

- [ ] **Step 3: Add statics + type namespace to firestore.ts**

Add these imports to the existing import block in `firestore.ts`:
```ts
import {
  serverTimestamp as fbServerTimestamp,
  increment as fbIncrement,
  arrayUnion as fbArrayUnion,
  arrayRemove as fbArrayRemove,
  documentId as fbDocumentId,
  Timestamp as FbTimestamp,
  GeoPoint as FbGeoPoint,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
```

Then, immediately after the `export default function firestore()` definition, attach the statics and declare the type namespace:
```ts
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

export namespace FirebaseFirestoreTypes {
  export type Module = FirestoreModule;
  export type DocumentSnapshot = import('firebase/firestore').DocumentSnapshot;
  export type QueryDocumentSnapshot = import('firebase/firestore').QueryDocumentSnapshot;
  export type QuerySnapshot = import('firebase/firestore').QuerySnapshot;
  export type Query = InstanceType<typeof QueryClass>;
  export type Timestamp = FbTimestamp;
  export type GeoPoint = FbGeoPoint;
}
```

> Note: `QueryClass` is the exported `Query` class from Task 4 — add `Query as QueryClass` to the re-export at the bottom of the file: change `export { DocRef, CollectionRef, Query };` to `export { DocRef, CollectionRef, Query, Query as QueryClass };`. The unused `QueryDocumentSnapshot` value import is only for the type alias; if the linter flags it, keep it as the `import('...')` form already used above and drop it from the value import.

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/firestore-statics.test.ts
```
Expected: PASS (6 tests).

- [ ] **Step 5: Run the full shim test set + typecheck**

Run:
```bash
npx jest src/firebase-web-shim && npx tsc --noEmit
```
Expected: all shim tests PASS; `tsc` reports no errors (native typecheck still clean — the shim only adds files).

- [ ] **Step 6: Commit**

```bash
git add mobile-rn/src/firebase-web-shim/firestore.ts \
  mobile-rn/src/firebase-web-shim/__tests__/firestore-statics.test.ts
git commit -m "feat(mobile-rn): firebase-web-shim firestore statics + type namespace"
```

---

### Task 6: Shim functions + storage

**Files:**
- Create: `mobile-rn/src/firebase-web-shim/functions.ts`
- Create: `mobile-rn/src/firebase-web-shim/storage.ts`
- Test: `mobile-rn/src/firebase-web-shim/__tests__/functions-storage.test.ts`

**Interfaces:**
- Produces:
  - `functions.ts`: default `functions(): FunctionsModule` with `httpsCallable(name): (data?) => Promise<{ data: unknown }>` and `useEmulator(host, port)`. Plus `export namespace FirebaseFunctionsTypes { type Module = FunctionsModule; }`.
  - `storage.ts`: default `storage(): StorageModule` with `ref(path): StorageRef`, `refFromURL(url): StorageRef`, `useEmulator(host, port)`. `StorageRef`: `put(blob)`, `putString(data, format?, metadata?)`, `getDownloadURL()`, `delete()`, `putFile()` → throws `WebUnsupportedError`. Plus `export namespace FirebaseStorageTypes { type Module = StorageModule; type Reference = StorageRef; }`.

- [ ] **Step 1: Write the failing test**

`mobile-rn/src/firebase-web-shim/__tests__/functions-storage.test.ts`:
```ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/functions-storage.test.ts
```
Expected: FAIL — `Cannot find module '../functions'` / `'../storage'`.

- [ ] **Step 3: Implement functions.ts**

`mobile-rn/src/firebase-web-shim/functions.ts`:
```ts
import {
  getFunctions,
  httpsCallable as fbHttpsCallable,
  connectFunctionsEmulator,
  type Functions,
} from 'firebase/functions';
import { getWebFirebaseApp } from '../config/firebase.web';

type Callable = (data?: unknown) => Promise<{ data: unknown }>;

export interface FunctionsModule {
  httpsCallable(name: string): Callable;
  useEmulator(host: string, port: number): void;
}

function makeModule(instance: Functions): FunctionsModule {
  return {
    httpsCallable: (name) => {
      const fn = fbHttpsCallable(instance, name);
      return (data?: unknown) => fn(data) as Promise<{ data: unknown }>;
    },
    useEmulator: (host, port) => connectFunctionsEmulator(instance, host, port),
  };
}

export default function functions(): FunctionsModule {
  return makeModule(getFunctions(getWebFirebaseApp()));
}

export namespace FirebaseFunctionsTypes {
  export type Module = FunctionsModule;
}
```

- [ ] **Step 4: Implement storage.ts**

`mobile-rn/src/firebase-web-shim/storage.ts`:
```ts
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
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
npx jest src/firebase-web-shim/__tests__/functions-storage.test.ts
```
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add mobile-rn/src/firebase-web-shim/functions.ts mobile-rn/src/firebase-web-shim/storage.ts \
  mobile-rn/src/firebase-web-shim/__tests__/functions-storage.test.ts
git commit -m "feat(mobile-rn): firebase-web-shim functions + storage modules"
```

---

### Task 7: Wire webpack aliases to the shim and verify end-to-end on web

**Files:**
- Modify: `mobile-rn/webpack.config.js` (add the five firebase aliases)

**Interfaces:**
- Consumes: all shim modules from Tasks 3–6; `firebase.web.ts` from Task 2.
- Produces: a runnable web app where the existing repos/screens resolve `@react-native-firebase/*` to the shim.

- [ ] **Step 1: Add the firebase aliases**

In `mobile-rn/webpack.config.js`, replace the `resolve.alias` block with:
```js
    alias: {
      'react-native$': 'react-native-web',
      '@react-native-firebase/app': path.resolve(__dirname, 'src/firebase-web-shim/app.ts'),
      '@react-native-firebase/auth': path.resolve(__dirname, 'src/firebase-web-shim/auth.ts'),
      '@react-native-firebase/firestore': path.resolve(__dirname, 'src/firebase-web-shim/firestore.ts'),
      '@react-native-firebase/functions': path.resolve(__dirname, 'src/firebase-web-shim/functions.ts'),
      '@react-native-firebase/storage': path.resolve(__dirname, 'src/firebase-web-shim/storage.ts'),
    },
```

Also add the shim dir to the babel-loader `include` list (so `.ts` shim files transpile):
```js
        include: [path.resolve(__dirname, 'index.web.js'), path.resolve(__dirname, 'App.tsx'), path.resolve(__dirname, 'src'), ...compileNodeModules],
```
(`src` already covers `src/firebase-web-shim`, so no change is needed if `src` is present — verify it is.)

- [ ] **Step 2: Verify the production build is green with aliases active**

Run:
```bash
npm run build:web
```
Expected: webpack completes with no module-resolution errors for `@react-native-firebase/*` (they now resolve to the shim). Any error naming an unimplemented shim method indicates a surface gap — add that method to the relevant shim module with a focused test, then re-run.

- [ ] **Step 3: Provide real web Firebase config**

Confirm a local `mobile-rn/.env.web` exists (gitignored) with real values from the registered Firebase Web App (see Task 2, Step 5 outward action). Without it, the next step renders Login but sign-in fails.

- [ ] **Step 4: Manual smoke — login + a real-data admin screen**

Run:
```bash
npm run web
```
Then in a browser at `http://localhost:8082`:
- Expected: the Login screen renders.
- Sign in with a known admin account.
- Expected: navigation reaches the admin area and `AdminDashboard` renders real Firestore data (counts/lists populate), proving auth + firestore shim work end-to-end on web.

Document the result (works / which screen / any console error) for the M3 sweep plan.

- [ ] **Step 5: Final typecheck + full test run**

Run:
```bash
npx tsc --noEmit && npx jest
```
Expected: `tsc` clean; all tests pass (shim tests + pre-existing suites unaffected).

- [ ] **Step 6: Commit**

```bash
git add mobile-rn/webpack.config.js
git commit -m "feat(mobile-rn): alias @react-native-firebase/* to web shim; web login + admin dashboard work"
```

---

## Out of scope for this plan (next plan: M3/M4)

- Per-screen web sweep across all admin/desktop screens, fixing native-only widgets (maps, file/image pickers, `putFile` call sites) with web fallbacks.
- Documenting each deliberate native-only gap surfaced during the sweep.
- Env separation proof (web config not leaking prod creds into dev) and the final vault `09 Phase Checklist` update.

These get their own plan once M2 lands and the sweep reveals the actual per-screen gaps.

---

## Self-Review

**Spec coverage:**
- Webpack alias shim strategy → Tasks 2, 7. ✓
- Audited auth surface → Task 3. ✓
- Audited firestore surface (refs/query/snapshots/batch/transaction) → Tasks 4–5. ✓
- firestore statics (Timestamp/FieldValue/FieldPath/GeoPoint) → Task 5. ✓
- functions + storage surface, `putFile` web stub → Task 6. ✓
- `index.web.js`/`public/index.html`/`firebase.web.ts`/env wiring → Task 2. ✓
- Native build untouched → Global Constraints + `.web.*`/alias isolation. ✓
- Outward action (register Web App) → Task 2 Step 5, Task 7 Step 3. ✓
- Testing strategy (shim unit tests + tsc + build + manual smoke) → Tasks 3–7. ✓
- M3/M4 (full screen parity sweep, QA) → explicitly deferred to a follow-on plan (scope decision stated up front). 

**Type consistency:** `DocRef._ref` / `CollectionRef._coll` / `StorageRef._ref` referenced consistently by batch/transaction (Task 4) and tests. `FirestoreModule`, `AuthModule`, `FunctionsModule`, `StorageModule` names match between producer interfaces and `FirebaseXTypes.Module` aliases. `Query`/`QueryClass` re-export reconciled in Task 5 Step 3.

**Placeholder scan:** no TBD/TODO; every code step shows complete code; the only deferred work is the explicitly-scoped M3/M4 follow-on plan.
