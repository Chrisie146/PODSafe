# Reverse Geocoding (POD capture) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Populate `pods.location.address` with a real Google-Geocoded address at POD capture time, via a new server-side callable.

**Architecture:** A new `reverseGeocode` onCall Cloud Function calls the Google Geocoding REST API with a server-side key (read from functions config, never shipped in the app). A new RN `locationRepository.ts` wraps the callable and never throws (returns `''` on failure). The pod capture flow (`usePodStore.submitPod`) calls it after grabbing GPS coords and writes the address onto the persisted pod document.

**Tech Stack:** Firebase Cloud Functions (Node 20, 1st Gen, `firebase-functions` v1 onCall), axios (Google Geocoding REST), vitest (functions); React Native + `@react-native-firebase/functions` + Zustand (`usePodStore`), jest (mobile-rn).

## Global Constraints

- Firebase Cloud Functions: Node 20, 1st Gen, region `us-central1`, project `podsafe-f4a47` (Blaze plan). onCall wire format `{"data":{...}}`.
- The Google Geocoding API key lives ONLY in functions config (`google.geocoding_key`) / env (`GOOGLE_GEOCODING_KEY`), never committed to the repo, never shipped in the app bundle.
- Auth gate on the callable: authenticated + active user (`users/{uid}.isActive === true`). NOT admin-only (drivers capture PODs). No company gate (lat/lng are public).
- Fallback on any geocoding failure: `pods.location.address` stays `''`; the pod write still proceeds. A POD is legally valid with coordinates alone.
- **No Flutter/Dart files are created or edited** (standing user constraint on this migration). This plan touches only `functions/` and `mobile-rn/`.
- Functions build gate is `npm run build` (tsc, strict). The functions ESLint→TS wiring is pre-existing-broken; tsc is the real gate.
- Functions test files MUST use the `*.spec.ts` extension (tsconfig excludes `**/*.spec.ts` from the build; vitest runs both `*.test.ts` and `*.spec.ts`, but `*.test.ts` would be compiled by tsc and break the build).
- mobile-rn gates: `tsc --noEmit`, `eslint`, `jest` all clean.
- Test the existing Google key (`AIzaSyChH7L0Ffmldc6AmiyPAm7D5BJDrG5SM8s`) from the callable first; if Google returns `REQUEST_DENIED` (Android-app-restricted key 403s from a server), the user creates a server-restricted Geocoding key, re-sets config, redeploys.

## Spec refinement (call site)

The spec's "Components" section suggested modifying `podRepository.ts`. During planning the actual capture flow was confirmed: the pod document (including its `location` field) is assembled in `usePodStore.submitPod` (`mobile-rn/src/stores/usePodStore.ts:132-158`), which calls `podRepository.getCurrentLocation()` for GPS coords and then builds the `PodRecord`. Per the spec's data-flow diagram (which shows the capture flow calling `getCurrentLocation` and `reverseGeocode` separately) and its "exact call site confirmed during implementation planning" allowance, the geocode is injected in `usePodStore.submitPod`, and `podRepository.getCurrentLocation()` stays GPS-only (so live-preview calls to `getCurrentLocation` don't burn geocode quota). `podRepository.ts` is NOT modified by this plan.

## File Structure

- **Create** `functions/src/location/reverseGeocode.ts` — exports `reverseGeocodeCoords(latitude, longitude, apiKey)` (pure axios helper, returns `string`, never throws) + `reverseGeocode` (onCall wrapper: auth/active gate, input validation, reads key from config, returns `{address}`).
- **Create** `functions/src/location/reverseGeocode.spec.ts` — vitest unit tests for `reverseGeocodeCoords` (mocked axios): OK→address, ZERO_RESULTS→'', OVER_QUERY_LIMIT→'', REQUEST_DENIED→'', axios-throw→'', empty-key→'' (no call).
- **Modify** `functions/src/config.ts` — add a `googleGeocodingKey` getter following the existing `process.env.X || functions.config().ns?.key || default` convention.
- **Modify** `functions/src/index.ts` — `export * from './location/reverseGeocode';` in a new REVERSE GEOCODING section.
- **Create** `mobile-rn/src/repositories/locationRepository.ts` — `reverseGeocode(latitude, longitude): Promise<string>`; wraps `httpsCallable('reverseGeocode')`; returns `''` on any error (never throws).
- **Create** `mobile-rn/src/repositories/locationRepository.test.ts` — jest tests: success→address, callable throws→'', missing address field→''. Uses the existing manual mock `__mocks__/@react-native-firebase/functions.js`.
- **Modify** `mobile-rn/src/stores/usePodStore.ts` — in `submitPod`, after `getCurrentLocation()`, call `reverseGeocode` and put the address onto the `location` object written into the pod. Add the import.

---

### Task 1: `reverseGeocodeCoords` pure helper + vitest tests

**Files:**
- Create: `functions/src/location/reverseGeocode.ts`
- Create: `functions/src/location/reverseGeocode.spec.ts`

**Interfaces:**
- Consumes: `axios` (already a `functions/` dependency, `^1.6.0`).
- Produces: `reverseGeocodeCoords(latitude: number, longitude: number, apiKey: string): Promise<string>` — returns the `formatted_address` on Google `OK`+results, `''` on `ZERO_RESULTS` / any non-OK status / axios error / exception / empty key. Never throws.

- [ ] **Step 1: Write the failing test**

Create `functions/src/location/reverseGeocode.spec.ts`:

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';
import { reverseGeocodeCoords } from './reverseGeocode';

vi.mock('axios');

const mockedAxios = axios as unknown as { get: ReturnType<typeof vi.fn> };

beforeEach(() => {
  mockedAxios.get.mockReset();
});

describe('reverseGeocodeCoords', () => {
  it('returns formatted_address on OK with results', async () => {
    mockedAxios.get.mockResolvedValue({
      data: { status: 'OK', results: [{ formatted_address: '123 Main St, Johannesburg, South Africa' }] },
    });
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('123 Main St, Johannesburg, South Africa');
  });

  it('returns empty string on ZERO_RESULTS', async () => {
    mockedAxios.get.mockResolvedValue({ data: { status: 'ZERO_RESULTS', results: [] } });
    const address = await reverseGeocodeCoords(0, 0, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string on OVER_QUERY_LIMIT', async () => {
    mockedAxios.get.mockResolvedValue({ data: { status: 'OVER_QUERY_LIMIT', results: [] } });
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string on REQUEST_DENIED', async () => {
    mockedAxios.get.mockResolvedValue({ data: { status: 'REQUEST_DENIED', results: [] } });
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string when axios throws', async () => {
    mockedAxios.get.mockRejectedValue(new Error('network down'));
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string and does not call axios when apiKey is empty', async () => {
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, '');
    expect(address).toBe('');
    expect(mockedAxios.get).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run (from `functions/`):
```bash
npx vitest run src/location/reverseGeocode.spec.ts
```
Expected: FAIL — `reverseGeocodeCoords is not a function` / module `./reverseGeocode` not found.

- [ ] **Step 3: Write the minimal implementation**

Create `functions/src/location/reverseGeocode.ts`:

```ts
/**
 * Server-side reverse geocoding (Phase 6). lat/lng -> human address via the
 * Google Geocoding REST API. The `reverseGeocode` onCall wrapper (added in the
 * next task) wraps this pure helper with an auth/active-user gate and reads the
 * API key from functions config; the helper itself takes the key as a parameter
 * so it is unit-testable with a mocked axios and no Firebase runtime.
 *
 * On any non-OK Google status, an axios error, or an exception, returns ''
 * (empty string) — never throws. A POD is legally valid with coordinates alone,
 * so capture must never fail because geocoding failed.
 */
import axios from 'axios';

export interface GeocodeResult {
  results: Array<{ formatted_address: string }>;
  status: string;
}

export async function reverseGeocodeCoords(latitude: number, longitude: number, apiKey: string): Promise<string> {
  if (!apiKey) {
    console.error('reverseGeocode: missing Google Geocoding API key (functions config google.geocoding_key / GOOGLE_GEOCODING_KEY).');
    return '';
  }

  const url = 'https://maps.googleapis.com/maps/api/geocode/json';
  try {
    const response = await axios.get<GeocodeResult>(url, {
      params: { latlng: `${latitude},${longitude}`, key: apiKey, language: 'en', region: 'za' },
      timeout: 10000,
    });
    const { status, results } = response.data;
    if (status === 'OK' && results.length > 0) {
      return results[0].formatted_address;
    }
    if (status !== 'ZERO_RESULTS') {
      console.error(`reverseGeocode: Google status ${status} for ${latitude},${longitude}`);
    }
    return '';
  } catch (error) {
    console.error(`reverseGeocode: request failed for ${latitude},${longitude}:`, (error as Error).message);
    return '';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run (from `functions/`):
```bash
npx vitest run src/location/reverseGeocode.spec.ts
```
Expected: PASS — 6 tests passed.

- [ ] **Step 5: Verify the build still passes (spec file excluded from tsc)**

Run (from `functions/`):
```bash
npm run build
```
Expected: PASS — tsc compiles `lib/...` cleanly; the `.spec.ts` file is excluded by `tsconfig.json` (`"exclude": ["**/*.spec.ts"]`), and `reverseGeocode.ts` has no unused locals/params.

- [ ] **Step 6: Commit**

```bash
git add functions/src/location/reverseGeocode.ts functions/src/location/reverseGeocode.spec.ts
git commit -m "feat(functions): add reverseGeocodeCoords pure helper + vitest tests"
```

---

### Task 2: `reverseGeocode` onCall wrapper + config key + export

**Files:**
- Modify: `functions/src/location/reverseGeocode.ts` (append the onCall wrapper)
- Modify: `functions/src/config.ts:24` (add `googleGeocodingKey` getter)
- Modify: `functions/src/index.ts:401` (add export)

**Interfaces:**
- Consumes: `reverseGeocodeCoords` from Task 1; `config.googleGeocodingKey` (added this task); `firebase-functions` `https.onCall`; `firebase-admin` firestore (existing `admin.initializeApp()` is in `index.ts`).
- Produces: deployed Cloud Function `reverseGeocode` (onCall). Input `{latitude:number, longitude:number}`. Returns `{address: string}`. Throws `unauthenticated` / `invalid-argument` / `permission-denied` HttpsErrors.

- [ ] **Step 1: Add the `googleGeocodingKey` getter to config**

In `functions/src/config.ts`, insert this getter immediately after the `bcScope` getter (after line 24, before the `// API Configuration` comment on line 26):

```ts
  // Google Maps Geocoding API key (server-side, reverse geocoding at POD capture)
  get googleGeocodingKey() {
    return process.env.GOOGLE_GEOCODING_KEY || functions.config().google?.geocoding_key || '';
  },
```

- [ ] **Step 2: Append the onCall wrapper to `reverseGeocode.ts`**

Add to the top of `functions/src/location/reverseGeocode.ts` (new imports, below the existing `import axios from 'axios';`):

```ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { config } from '../config';
```

Then append at the end of the file:

```ts
export interface ReverseGeocodeData {
  latitude: number;
  longitude: number;
}

/**
 * onCall reverse geocoder. Authenticated + active users only (NOT admin-only —
 * drivers capture PODs). No company gate: lat/lng carry no tenant data. Reads
 * the Google Geocoding key from functions config and delegates to the pure
 * helper, which returns '' on any failure so capture never breaks on geocoding.
 */
export const reverseGeocode = functions.https.onCall(async (data: ReverseGeocodeData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to reverse geocode.');
  }

  const { latitude, longitude } = data ?? {};
  if (
    typeof latitude !== 'number' || typeof longitude !== 'number' ||
    !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180
  ) {
    throw new functions.https.HttpsError('invalid-argument', 'latitude and longitude must be finite numbers in valid ranges.');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const caller = callerDoc.data();
  if (!callerDoc.exists || !caller || caller.isActive !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Active user account required.');
  }

  const address = await reverseGeocodeCoords(latitude, longitude, config.googleGeocodingKey);
  return { address };
});
```

- [ ] **Step 3: Export the callable from `index.ts`**

In `functions/src/index.ts`, after line 401 (`export * from './pdf/generateBulkClaimsPdf';`) and before the final `console.log(...)` on line 403, insert:

```ts
// ==================== REVERSE GEOCODING ====================

export * from './location/reverseGeocode';
```

- [ ] **Step 4: Verify the build passes**

Run (from `functions/`):
```bash
npm run build
```
Expected: PASS — tsc compiles cleanly; `lib/location/reverseGeocode.js` is emitted; no unused-locals/params errors (the onCall wrapper uses every imported symbol: `functions`, `admin`, `config`).

- [ ] **Step 5: Verify the existing functions tests still pass**

Run (from `functions/`):
```bash
npm test
```
Expected: PASS — the Task 1 spec suite still passes (the new onCall wrapper is not referenced by the spec, so no regressions).

- [ ] **Step 6: Commit**

```bash
git add functions/src/location/reverseGeocode.ts functions/src/config.ts functions/src/index.ts
git commit -m "feat(functions): add reverseGeocode onCall wrapper + config key + export"
```

> **Test-design note (no wrapper unit test):** The onCall wrapper is intentionally not unit-tested. The existing `functions/` codebase has zero Cloud-Function tests and no firebase-functions/admin mock harness; building one for a single thin wrapper would be inconsistent over-engineering. The pure helper (`reverseGeocodeCoords`, Task 1) is the unit-tested logic. The wrapper's auth gate + input validation are verified by the deploy smoke test (Task 5): unauthenticated curl → `UNAUTHENTICATED`, valid token + bad coords → `invalid-argument`.

---

### Task 3: `locationRepository.reverseGeocode` (RN) + jest tests

**Files:**
- Create: `mobile-rn/src/repositories/locationRepository.ts`
- Create: `mobile-rn/src/repositories/locationRepository.test.ts`

**Interfaces:**
- Consumes: `@react-native-firebase/functions` (installed `^24.1.1`; manual mock at `mobile-rn/__mocks__/@react-native-firebase/functions.js`).
- Produces: `reverseGeocode(latitude: number, longitude: number): Promise<string>` — returns `response.data.address` on success, `''` on any error or missing field. Never throws.

- [ ] **Step 1: Write the failing test**

Create `mobile-rn/src/repositories/locationRepository.test.ts`:

```ts
import functions from '@react-native-firebase/functions';
import { reverseGeocode } from './locationRepository';

jest.mock('@react-native-firebase/functions');

const mockCallable = jest.fn();

beforeEach(() => {
  mockCallable.mockReset();
  (functions().httpsCallable as jest.Mock).mockReturnValue(mockCallable);
});

describe('reverseGeocode', () => {
  it('returns the address string on success and forwards lat/lng', async () => {
    mockCallable.mockResolvedValue({ data: { address: '123 Main St, Johannesburg' } });
    const address = await reverseGeocode(-26.2041, 28.0473);
    expect(address).toBe('123 Main St, Johannesburg');
    expect(mockCallable).toHaveBeenCalledWith({ latitude: -26.2041, longitude: 28.0473 });
  });

  it('returns empty string when the callable throws', async () => {
    mockCallable.mockRejectedValue(new Error('unavailable'));
    const address = await reverseGeocode(-26.2041, 28.0473);
    expect(address).toBe('');
  });

  it('returns empty string when address is missing from the response', async () => {
    mockCallable.mockResolvedValue({ data: {} });
    const address = await reverseGeocode(-26.2041, 28.0473);
    expect(address).toBe('');
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run (from `mobile-rn/`):
```bash
npx jest src/repositories/locationRepository.test.ts
```
Expected: FAIL — `Cannot find module './locationRepository'`.

- [ ] **Step 3: Write the minimal implementation**

Create `mobile-rn/src/repositories/locationRepository.ts`:

```ts
import functions from '@react-native-firebase/functions';

/**
 * Phase 6 reverse-geocoding client. Thin wrapper over the `reverseGeocode`
 * Cloud Function (functions/src/location/reverseGeocode.ts), which calls the
 * Google Geocoding API server-side so the billable key never ships in the app.
 *
 * Returns the resolved address string, or '' on any failure (callable throws,
 * network error, Google non-OK status, missing field). NEVER throws — pod
 * capture must not break on geocoding failure; a POD is valid with coordinates
 * alone. See the design spec for the empty-string fallback decision.
 */
export async function reverseGeocode(latitude: number, longitude: number): Promise<string> {
  try {
    const callable = functions().httpsCallable('reverseGeocode');
    const response = await callable({ latitude, longitude });
    const address = (response.data as { address?: string }).address;
    return typeof address === 'string' ? address : '';
  } catch (error) {
    console.warn('reverseGeocode failed:', (error as Error).message);
    return '';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run (from `mobile-rn/`):
```bash
npx jest src/repositories/locationRepository.test.ts
```
Expected: PASS — 3 tests passed. (The manual mock `__mocks__/@react-native-firebase/functions.js` makes `functions()` return an object whose `httpsCallable` is a `jest.fn`; `beforeEach` re-points it at `mockCallable`.)

- [ ] **Step 5: Verify all gates clean**

Run (from `mobile-rn/`):
```bash
npx tsc --noEmit
npx eslint src/repositories/locationRepository.ts src/repositories/locationRepository.test.ts
npm test
```
Expected: tsc PASS, eslint PASS, jest PASS (the new suite + the existing 2 suites all green).

- [ ] **Step 6: Commit**

```bash
git add mobile-rn/src/repositories/locationRepository.ts mobile-rn/src/repositories/locationRepository.test.ts
git commit -m "feat(mobile-rn): add locationRepository.reverseGeocode wrapper + jest tests"
```

---

### Task 4: Wire reverse geocoding into `usePodStore.submitPod`

**Files:**
- Modify: `mobile-rn/src/stores/usePodStore.ts` (import + lines 132-158 of `submitPod`)

**Interfaces:**
- Consumes: `reverseGeocode` from Task 3 (`../repositories/locationRepository`); `podRepository.getCurrentLocation()` (existing, unchanged — returns `LocationData | undefined` with `address: ''`).
- Produces: `submitPod` now persists `pods.location.address` populated (or `''` on geocode failure / no GPS).

- [ ] **Step 1: Add the import**

In `mobile-rn/src/stores/usePodStore.ts`, add to the imports near the other repository imports (after line 8, the `deliveryRepository` import):

```ts
import { reverseGeocode } from '../repositories/locationRepository';
```

- [ ] **Step 2: Replace the GPS-only location line in `submitPod`**

In `mobile-rn/src/stores/usePodStore.ts`, find line 132 inside `submitPod`:

```ts
    const location = await podRepository.getCurrentLocation();
```

Replace it with:

```ts
    const gpsLocation = await podRepository.getCurrentLocation();
    const location = gpsLocation
      ? { ...gpsLocation, address: await reverseGeocode(gpsLocation.latitude, gpsLocation.longitude) }
      : undefined;
```

The `location` variable is consumed unchanged at line 158 (`location,` inside the `PodRecord` literal). Its type is still `LocationData | undefined`, so no downstream type changes are needed.

- [ ] **Step 3: Verify all gates clean**

Run (from `mobile-rn/`):
```bash
npx tsc --noEmit
npx eslint src/stores/usePodStore.ts
npm test
```
Expected: tsc PASS (no unused locals — `gpsLocation` and `location` are both used; `reverseGeocode` is used), eslint PASS, jest PASS (no regressions; `usePodStore` has no existing test suite and isn't tested here — the unit-tested pieces are `reverseGeocodeCoords` and `reverseGeocode`; the wiring is a 4-line change reviewed against the spec).

- [ ] **Step 4: Commit**

```bash
git add mobile-rn/src/stores/usePodStore.ts
git commit -m "feat(mobile-rn): populate pods.location.address via reverseGeocode at capture"
```

---

### Task 5: Deploy, grant IAM, smoke test, verify key

**Files:** none (operational task — no code changes).

> **External prerequisite:** This task sets the Google Geocoding key in functions config. Per the locked decision, start with the existing key `AIzaSyChH7L0Ffmldc6AmiyPAm7D5BJDrG5SM8s` and test it server-side. If Google returns `REQUEST_DENIED`, the user must create a server-restricted Geocoding key in GCP Console (restricted to the Geocoding API, optionally to Cloud Function egress IPs) and provide it for step 2.

- [ ] **Step 1: Set the Geocoding key in functions config**

Run (from `functions/`):
```bash
firebase functions:config:set google.geocoding_key="AIzaSyChH7L0Ffmldc6AmiyPAm7D5BJDrG5SM8s" --project podsafe-f4a47
```
Expected: `✔ RTC Config updated.` (config is stored server-side, not committed.)

- [ ] **Step 2: Build + deploy the callable**

Run (from `functions/`):
```bash
npm run build && firebase deploy --only functions:reverseGeocode --project podsafe-f4a47
```
Expected: deploy succeeds; `reverseGeocode` (1st Gen, us-central1) is live. (If `firebase` CLI is missing, `npm install -g firebase-tools` first.)

- [ ] **Step 3: Grant invoker IAM to `allUsers`**

Run:
```bash
gcloud functions add-iam-policy-binding reverseGeocode --region=us-central1 --project podsafe-f4a47 --role=roles/cloudfunctions.invoker --member=allUsers
```
Expected: `bindings` updated, `allUsers` has `roles/cloudfunctions.invoker`. (Domain Restricted Sharing org policy blocks project-wide grants, so this per-function grant is required — same pattern as the bulk-export callables.)

- [ ] **Step 4: Smoke test — unauthenticated (confirms auth gate)**

Run:
```bash
curl -s -X POST "https://us-central1-podsafe-f4a47.cloudfunctions.net/reverseGeocode" \
  -H "Content-Type: application/json" \
  -d '{"data":{"latitude":-26.2041,"longitude":28.0473}}'
```
Expected: `{"error":{"status":"UNAUTHENTICATED","message":"User must be authenticated to reverse geocode."}}` (handler-authored message confirms the callable is wired and gated).

- [ ] **Step 5: Smoke test — authenticated with a real admin/driver token**

Obtain a fresh Firebase ID token for an active user (admin or driver), then:
```bash
curl -s -X POST "https://us-central1-podsafe-f4a47.cloudfunctions.net/reverseGeocode" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <FRESH_ID_TOKEN>" \
  -d '{"data":{"latitude":-26.2041,"longitude":28.0473}}'
```
Expected: `{"result":{"address":"<a real Johannesburg street address>"}}` — confirms the existing key works server-side (not Android-restricted).

**If instead `{"result":{"address":""}}` AND the functions log shows `Google status REQUEST_DENIED`:** the existing key is Android-app-restricted. The user must create a server-restricted Geocoding key in GCP Console, then:
```bash
firebase functions:config:set google.geocoding_key="<NEW_SERVER_KEY>" --project podsafe-f4a47
firebase deploy --only functions:reverseGeocode --project podsafe-f4a47
```
Re-run this curl. Expected: a real address.

- [ ] **Step 6: Smoke test — invalid-argument (confirms validation)**

```bash
curl -s -X POST "https://us-central1-podsafe-f4a47.cloudfunctions.net/reverseGeocode" \
  -H "Content-Type: application/json" -H "Authorization: Bearer <FRESH_ID_TOKEN>" \
  -d '{"data":{"latitude":999,"longitude":0}}'
```
Expected: `{"error":{"status":"INVALID_ARGUMENT","message":"latitude and longitude must be finite numbers in valid ranges."}}`.

- [ ] **Step 7: Record the key outcome**

Note in the commit message (Task 6 captures this in the vault): whether the existing key worked or a server key was created. No code to commit in this task.

---

### Task 6: Update vault (Phase Checklist + Backend Gap Fix Tracker)

**Files:** none in the repo — updates the Obsidian vault via the Obsidian MCP.

- [ ] **Step 1: Update `09 Phase Checklist.md`**

Via the Obsidian MCP (`obsidian_patch_content` on `PODSafe RN Migration/09 Phase Checklist.md`, frontmatter `last_updated` target — heading-target patching has failed before, so use frontmatter target or append to end), set Phase 6 reverse-geocoding item to done and update `last_updated` to `2026-06-23 (session 10)`. Record: `reverseGeocode` callable deployed + IAM granted + smoke-tested; existing Google key worked / server key created (per Task 5 step 7 outcome). Note remaining Phase 6 items: offline queue, push notifications.

- [ ] **Step 2: Update `08 Backend Gap Fix Tracker.md`**

Append a session-10 entry: `reverseGeocode` onCall (functions/src/location/reverseGeocode.ts) — auth+active gate, Google Geocoding REST via axios, key in `google.geocoding_key` config. Deployed + invoker IAM + curl-verified. RN side: `locationRepository.ts` + `usePodStore.submitPod` wiring. Gap closed.

- [ ] **Step 3: Confirm vault writes landed**

Re-read both notes via `obsidian_get_file_contents` to confirm the edits are present and encoding is intact (MCP returns double-escaped JSON; verify no em-dash/emoji corruption).

---

## Self-Review

**1. Spec coverage:**
- Server-side callable, Google Geocoding REST, key in functions config → Task 2 (+ config getter).
- Capture-time persist onto `pods.location.address` → Task 4.
- PODs only → no claim/LiveTracking tasks (correctly absent).
- Empty-string fallback on failure → Task 1 helper (never throws) + Task 3 wrapper (never throws) + Task 4 (address flows through as '' on failure).
- Auth gate authenticated + active, not admin, no company → Task 2 wrapper.
- Input validation (finite, ranges) → Task 2 wrapper.
- Test-existing-key-first / REQUEST_DENIED → server key → Task 5 steps 1 + 5 fallback.
- functions vitest parser tests (OK/ZERO_RESULTS/OVER_QUERY_LIMIT/REQUEST_DENIED/axios error) → Task 1 (6 tests, includes empty-key bonus).
- mobile-rn jest wrapper tests (success/throw/missing field) → Task 3.
- Deploy + invoker IAM + curl smoke test (auth gate, valid, invalid-arg) → Task 5.
- Vault update → Task 6.
- Non-Flutter constraint → enforced (only `functions/` + `mobile-rn/` touched).
- Out-of-scope items (claims, LiveTracking, backfill, offline interaction) → no tasks, correct.

**2. Placeholder scan:** No "TBD"/"TODO"/"add error handling"/"similar to Task N". Every code step has complete code. The two `<FRESH_ID_TOKEN>` / `<NEW_SERVER_KEY>` placeholders in Task 5 curl commands are runtime values supplied by the operator, not plan placeholders — they are explicitly described in their steps.

**3. Type consistency:**
- `reverseGeocodeCoords(latitude: number, longitude: number, apiKey: string): Promise<string>` — Task 1 defines, Task 2 calls with `config.googleGeocodingKey` (string). ✓
- `reverseGeocode(latitude: number, longitude: number): Promise<string>` — Task 3 defines, Task 4 calls with `gpsLocation.latitude`/`longitude` (numbers from `LocationData`). ✓
- `ReverseGeocodeData { latitude: number; longitude: number }` — Task 2 wrapper input matches Task 3 wrapper's `callable({ latitude, longitude })` payload and Task 4's call. ✓
- `locationRepository.ts` reads `response.data.address` as `string` — matches Task 2's `return { address }`. ✓
- `usePodStore` `location` stays `LocationData | undefined` — `getCurrentLocation()` returns `LocationData | undefined`; the spread `{ ...gpsLocation, address }` preserves the type. ✓
- config getter name `googleGeocodingKey` — Task 2 step 1 defines, Task 2 step 2 uses `config.googleGeocodingKey`. ✓
- Export path `./location/reverseGeocode` — Task 2 step 3 matches the file path `functions/src/location/reverseGeocode.ts`. ✓

No gaps, no placeholders, types consistent.