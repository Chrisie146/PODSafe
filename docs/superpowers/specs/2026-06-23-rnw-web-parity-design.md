# RNW Web Parity — Design Spec

- **Date**: 2026-06-23
- **Project**: PODSafe Flutter → React Native migration (`mobile-rn/`)
- **Phase**: 1 (remaining) — RNW web entry + web Firebase configuration
- **Branch**: `beta_v1.0`
- **Vault**: `PODSafe RN Migration/09 Phase Checklist`, `11 Environment and Native Setup`, `06 Package Mapping Decisions`

## Goal

Make `mobile-rn` build and run as a React Native Web (RNW) target so the admin/desktop
screens reach **full web parity**, without touching the working native (Android) build and
without regressing Phase 2/3 native screens.

The blocker: ~47 files import `@react-native-firebase/*` (native-only modules) directly —
repositories, model converters, and admin screens. These cannot run on web. The web target
needs the plain `firebase` JS SDK, whose API differs from RNFirebase's namespaced API.

## Confirmed decisions

| Decision | Choice | Why |
|---|---|---|
| Web scope | Full admin/desktop web parity | User direction (2026-06-23) |
| Firebase-on-web strategy | **A: Webpack alias shim** | Native code stays frozen; web problem isolated to one bounded shim layer instead of a 47-file refactor |
| Native build | Untouched | `.web.ts(x)` resolution + webpack alias are web-only; Metro never resolves them |
| `putFile` on web | Deliberate web stub that throws | POD photo capture is driver-mobile, not admin-web; no local file paths on web |

### Rejected approaches
- **B: Repository abstraction refactor** (`.native.ts`/`.web.ts` facade, rewrite all 47 files) — huge diff across working code, high native-regression risk.
- **C: Modular RNFirebase API migration** — those modules are still native-only; does nothing for web.

## Architecture

```
index.web.js          polyfill (react-native-get-random-values) → firebase.web init →
                      AppRegistry.runApplication mounts App into <div id="root">
webpack.config.js     alias: react-native → react-native-web
                      alias: @react-native-firebase/{app,auth,firestore,functions,storage}
                             → src/firebase-web-shim/*
                      resolve .web.tsx/.web.ts first; babel-loader for ts/tsx + RN deps;
                      html-webpack-plugin(public/index.html); DefinePlugin / dotenv for env
public/index.html     <div id="root">
src/config/firebase.web.ts   initializeApp(web config read from env)
src/firebase-web-shim/{app,auth,firestore,functions,storage}.ts
                      RNFirebase-shaped wrappers over the `firebase` JS SDK,
                      covering ONLY the audited API surface (below)
```

Web deps already present in `package.json`: `react-native-web`, `webpack`, `webpack-cli`,
`webpack-dev-server`, `babel-loader`, `html-webpack-plugin`. The `firebase` JS SDK must be
added.

## Audited RNFirebase API surface (the shim contract)

Derived from grepping `mobile-rn/src` on 2026-06-23. The shim must cover exactly this and
no more (YAGNI).

### auth — `auth()` module
- `currentUser`
- `onAuthStateChanged(cb)`
- `signInWithEmailAndPassword(email, password)`
- `createUserWithEmailAndPassword(email, password)`
- `signOut()`
- `sendPasswordResetEmail(email)`
- `useEmulator(url)` → `connectAuthEmulator`
- type namespace `FirebaseAuthTypes` (`User`, `Module`) — types only

### firestore — `firestore()` module + statics
Module methods: `collection`, `doc`, `batch`, `runTransaction`, `useEmulator` (→ `connectFirestoreEmulator`).
Statics on the default export: `Timestamp`, `FieldValue`, `FieldPath`, `GeoPoint`.
- **CollectionReference**: `doc()`, `where()`, `orderBy()`, `limit()`, `startAfter()`, `get()`, `add()`, `onSnapshot()`
- **DocumentReference**: `get()`, `set()`, `update()`, `delete()`, `collection()`, `onSnapshot()`, `id`
- **Query** (lazy chain): `where()`, `orderBy()`, `limit()`, `startAfter()`, `get()`, `onSnapshot()`
- **DocumentSnapshot**: `exists()` *(method — JS SDK exposes `exists` as a property; shim must convert)*, `data()`, `id`, `metadata`
- **QuerySnapshot**: `docs`, `size`, `empty`, `forEach()`
- **WriteBatch**: `set()`, `update()`, `delete()`, `commit()`
- **Timestamp**: `fromDate()`, `now()`, instance `toDate()`, `toMillis()` — re-export SDK `Timestamp`
- **FieldValue**: `serverTimestamp()`, `increment()`, `arrayUnion()`, `arrayRemove()`
- **FieldPath**: `documentId()`
- **GeoPoint**: constructor — re-export SDK `GeoPoint`
- type namespace `FirebaseFirestoreTypes` (`Module`, `DocumentSnapshot`, `QueryDocumentSnapshot`, `QuerySnapshot`, `Query`, `Timestamp`, `GeoPoint`)

### functions — `functions()` module
- `httpsCallable(name)`
- `useEmulator(host, port)` → `connectFunctionsEmulator`

### storage — `storage()` module
- `ref(path)`, `refFromURL(url)`, `useEmulator(host, port)` (→ `connectStorageEmulator`)
- ref: `put(blob)`, `putString(...)`, `getDownloadURL()`, `delete()`
- ref: `putFile(localPath)` → **throws `WebUnsupportedError`** (documented deliberate gap)

### app
- `getApp()` → returns the app initialized in `firebase.web.ts`

## Shim internals

Each `src/firebase-web-shim/<module>.ts` default-exports a callable returning a module
object, plus attached statics and re-exported `*Types` namespaces, so the 47 importing files
compile unchanged.

- `firestore.ts` — wrapper classes `CollectionRef` / `DocRef` / `Query` over JS-SDK modular
  functions (`collection`, `doc`, `query`, `where`, `orderBy`, `limit`, `startAfter`,
  `getDoc`, `getDocs`, `setDoc`, `updateDoc`, `addDoc`, `deleteDoc`, `onSnapshot`,
  `writeBatch`, `runTransaction`). `Query` is **lazy**: chained constraints accumulate and
  execute on `.get()`/`.onSnapshot()`. `DocSnap`/`QuerySnap` adapt SDK shapes —
  critically `exists` property → `exists()` method. `Timestamp`/`GeoPoint` re-exported from
  SDK. `FieldValue` static maps to `serverTimestamp`/`increment`/`arrayUnion`/`arrayRemove`.
  `FieldPath.documentId()` maps to SDK `documentId()`.
- `auth.ts` — module over modular auth fns; `useEmulator` → `connectAuthEmulator`.
- `functions.ts` — `httpsCallable` passthrough; `useEmulator` → `connectFunctionsEmulator`.
- `storage.ts` — `ref`/`refFromURL`/`getDownloadURL`/`put`/`putString`/`delete`;
  `putFile` throws `WebUnsupportedError`; `useEmulator` → `connectStorageEmulator`.
- `app.ts` — `getApp()` returns the `firebase.web.ts` app instance.

`src/config/firebaseEmulators.ts` is unchanged; it imports the aliased modules and its
`useEmulator` calls route through the shim on web.

## Data flow

1. `index.web.js` runs the crypto polyfill first, then imports `firebase.web.ts`
   (`initializeApp`), then `configureFirebaseEmulators()`, then mounts `App`.
2. Repos/screens call the namespaced API exactly as on native; webpack rewrites the import
   to the shim; the shim translates to JS-SDK modular calls against the initialized app.
3. Snapshots returned to converters expose `.exists()`/`.data()`/`.id`/`.docs` identically
   to native, so `*.converters.ts` need no changes.

## Milestones

Single spec, sequenced; each milestone independently verifiable.

1. **Toolchain** — add `firebase`; create `webpack.config.js`, `index.web.js`,
   `public/index.html`, `src/config/firebase.web.ts`, web env keys; `react-native-web` alias.
   **Verify**: `npm run web` boots to the Login screen (no Firebase calls yet); webpack build green.
2. **Shim + auth/firestore** — implement the shim package + jest unit tests for the tricky
   bits (`exists()` method conversion, `Timestamp.fromDate`, lazy query chaining,
   `FieldValue` mappings). **Verify**: web Login signs in; one Firestore-reading admin screen
   (AdminDashboard) renders real data on web.
3. **Sweep** — exercise every admin/desktop screen on web; fix per-screen web gaps
   (maps, file pickers, `putFile` call sites) with web-appropriate fallbacks; document each
   deliberate native-only gap. **Verify**: each admin/desktop screen renders and its core
   data path works on web.
4. **QA / parity** — env separation proof (web config does not leak prod creds into dev),
   web `tsc` clean, webpack build green, commit. **Verify**: checklist in vault updated.

## Outward actions (require user authorization at the time)

- Register a Firebase **Web App** in the `podsafe-f4a47` console to obtain web config keys
  (`apiKey`, `authDomain`, `projectId`, `storageBucket`, `messagingSenderId`, `appId`).
  Needed for M1 `firebase.web.ts`. Does not touch native.

## Testing strategy

- **Shim unit tests** (jest, jsdom): per-wrapper behaviour, focused on the divergences from
  the JS SDK (`exists()` as method, lazy query execution, `FieldValue`/`Timestamp`/`GeoPoint`
  mapping, `putFile` throwing).
- **Type check**: web tsconfig `tsc --noEmit` clean; native `tsc` still clean.
- **Build**: `npm run web` (webpack) green per milestone.
- **Manual smoke**: per milestone, render in browser and exercise the core data path
  (login → admin screen → Firestore read) against emulator or live project.

## Non-goals / deliberate gaps

- Driver POD capture on web (`putFile`, camera, geolocation, image picker) — driver flows are
  mobile-native; web is admin-only. `putFile` throws on web by design.
- iOS web specifics — not applicable.
- Offline queue / push notifications (Phase 6) — out of scope here.

## Risks

- **Shim surface drift**: a screen may use an RNFirebase method not in the audit. Mitigation:
  the shim throws a clear `not-implemented` error naming the missing method, surfaced during
  the M3 sweep rather than failing silently.
- **Lazy-query semantics**: native chains constraints then `.get()`; the shim must accumulate
  constraints and build a single JS-SDK `query()` at execution. Covered by M2 unit tests.
- **`onSnapshot` listener cleanup parity**: shim must return an unsubscribe function matching
  native. Covered by M2 unit tests.
