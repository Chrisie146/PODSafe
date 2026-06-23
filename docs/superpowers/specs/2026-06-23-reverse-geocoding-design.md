# Phase 6 — Real Reverse Geocoding (POD capture) — Design

**Date:** 2026-06-23
**Phase:** 6 (cross-cutting fixes) — first sub-project
**Parent vault note:** `PODSafe RN Migration/09 Phase Checklist.md` (Phase 6)
**Status:** Approved design, pending implementation plan

## Context

The RN port has no real reverse geocoding. `pods.location.address` is always stored as `''` — `podRepository.ts` `getCurrentLocation()` returns `address: ''` with a comment stating real reverse geocoding lands in Phase 6 (`locationRepository.ts`). The only "geocoding" in the RN app is a hardcoded 13-entry South-African city-center table in `LiveTracking.tsx` (forward geocoding for pending deliveries, ported verbatim from Flutter). Flutter's `location_service.dart` `getAddressFromCoordinates` is itself a placeholder returning a `"Lat: …, Lng: …"` string. No `locationRepository.ts` exists yet.

This sub-project replaces the empty-address gap with a real Google Geocoding API integration, persisted at POD capture time.

## Decisions (locked during brainstorming)

| Decision | Choice |
|---|---|
| Where the geocoding call runs | Server-side callable (Google Geocoding REST); key in functions config, never in the app bundle |
| When to geocode + persistence | Capture-time; the resolved address is written onto `pods.location.address` once and stored permanently |
| Scope of capture surfaces | PODs only (claims keep raw `gpsLocation`; LiveTracking city table unchanged) |
| Fallback on failure | `pods.location.address` stays `''`; pod write still proceeds |
| API key sourcing | Test the existing `AIzaSyChH7...` key from the callable first; if Google returns `REQUEST_DENIED` (Android-app-restricted key 403s from a server), create a server-restricted Geocoding key, re-set config, redeploy |

## Architecture

One new server-side callable `reverseGeocode` plus one new RN repository `locationRepository.ts` that wraps it. The pod capture flow grabs GPS coords, calls `reverseGeocode`, and writes the returned address onto the pod document's `location.address`. Geocoding is decoupled from pod persistence — the callable does one thing (lat/lng → address) and is reusable for a future backfill pass or claims without redesign.

```
PodCapture screen
  └─ podRepository: getCurrentLocation() → {latitude, longitude, accuracy}
  └─ locationRepository.reverseGeocode(lat, lng)
       └─ httpsCallable('reverseGeocode')
            └─ Google Geocoding REST (key from functions config)
            └─ returns {address}
  └─ podRepository writes pod doc with location.address populated
```

## Components

### `functions/src/location/reverseGeocode.ts` (new)
- `functions.https.onCall` handler.
- **Auth gate:** authenticated + active user (`users/{uid}.isActive === true`). **Not** admin-only — drivers capture PODs. No company gate (lat/lng are public; no company data is involved).
- **Input:** `{ latitude: number, longitude: number }`. Validate both are finite numbers in valid ranges (`-90..90`, `-180..180`); else `invalid-argument`.
- **Google call:** `GET https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${KEY}&language=en&region=za` via axios (already a `functions/` dependency, used by `generatePodPdf`'s `fetchImageBytes`).
- **Response parse:** if `status === 'OK'` and `results.length > 0`, return `{address: results[0].formatted_address}`. On `ZERO_RESULTS`, return `{address: ''}`. On any other status (`OVER_QUERY_LIMIT`, `REQUEST_DENIED`, `INVALID_REQUEST`, `UNKNOWN_ERROR`) or axios error/exception, return `{address: ''}` and `console.error` the status/message.
- **Return:** `{address: string}` (always a string, possibly empty).
- Exported from `functions/src/index.ts` (`export * from './location/reverseGeocode';`).

### `mobile-rn/src/repositories/locationRepository.ts` (new)
- Exports `reverseGeocode(latitude: number, longitude: number): Promise<string>`.
- Wraps `functions().httpsCallable('reverseGeocode')({ latitude, longitude })`, returns `response.data.address`.
- On any error (callable throws, network), returns `''`. **Never throws** — pod capture must not break on geocoding failure.
- The name `locationRepository.ts` is the one already anticipated by the `podRepository.ts` `getCurrentLocation()` comment.

### `podRepository.ts` capture path (modified)
- After `getCurrentLocation()` yields `{latitude, longitude, accuracy}`, call `locationRepository.reverseGeocode(latitude, longitude)` and put the returned address into the `LocationData` object written with the pod (`location: { latitude, longitude, accuracy, address }`).
- The exact capture call site (PodCapture screen → `podRepository` create/save method) is confirmed during implementation planning. The change is local to where the pod `location` object is assembled.
- If `getCurrentLocation()` itself fails (no GPS permission/fix), the existing behavior is unchanged — no pod location is written.

## Data flow

1. Driver completes POD capture; the capture flow requests GPS → `getCurrentLocation()` returns coords + accuracy.
2. The flow calls `locationRepository.reverseGeocode(lat, lng)`.
3. The callable validates input, calls Google Geocoding REST with the server-side key, parses `formatted_address`.
4. The address (or `''`) returns to the client.
5. `podRepository` writes the pod document with `location.address` populated.
6. Display surfaces (`PodDetails.tsx`, `PodViewerDesktop.tsx`, `LiveTracking.tsx` markers) already render `pod.location.address` when present — no display-side changes needed.

## Error handling

- **Callable input validation:** non-numeric / out-of-range coords → `functions.https.HttpsError('invalid-argument', ...)`.
- **Google `OK` + results:** return `formatted_address`.
- **Google `ZERO_RESULTS`:** return `{address: ''}` (legitimate — the coords have no address).
- **Google non-OK status / axios error / exception:** return `{address: ''}` + `console.error`. Capture must never fail because geocoding failed; a POD is legally valid with coordinates alone.
- **Client wrapper:** callable error → `''`. Never throws.
- **Offline at capture** (depends on the future offline-queue sub-project, not built here): the callable is unreachable → `''` → address backfilled on a later sync/re-capture. Noted as an interaction, not implemented in this sub-project.

## Key handling + prerequisite

- The key is read from Firebase functions config. The exact config path is chosen to match the existing `functions/` config convention (verified during planning — the BC integration already reads config/secrets). Set with `firebase functions:config:set` (or the project's existing secret mechanism) and never committed to the repo or shipped in the app.
- **Test-existing-key-first (locked decision):** deploy with the existing `AIzaSyChH7L0Ffmldc6AmiyPAm7D5BJDrG5SM8s` key in config, then curl the callable with a real admin token. If Google returns `REQUEST_DENIED` (the key is Android-app-restricted and 403s from a server IP), the user creates a new Geocoding API key restricted to the Geocoding API (optionally to Cloud Function egress IPs) in GCP Console, re-sets config, and redeploys. This is the one external prerequisite and the only step requiring user GCP Console access.

## Security

- Callable is auth-gated (authenticated + active user). lat/lng carry no company or tenant data, so no company gate is required.
- The Google API key lives only in functions config and is never present in the app bundle (unlike the existing Android Maps SDK key in `AndroidManifest.xml`, which is a separate, app-restricted key for the Maps SDK, not used here).
- Abuse risk is low: POD capture is a low-frequency, auth-gated action. Rely on Google's per-key quota + the auth gate. No per-user rate cap is added in this sub-project (can be revisited if quota becomes a concern).

## Testing

- **`functions/` (vitest):** unit-test the Google-response parser with mocked axios responses — `OK`+results → expected `formatted_address`; `ZERO_RESULTS` → `''`; `OVER_QUERY_LIMIT` / `REQUEST_DENIED` / axios error → `''`. `npm run build` (tsc) clean. (The `functions/` ESLint→TS wiring is pre-existing-broken; tsc is the real gate, per vault.)
- **`mobile-rn/` (jest):** test `locationRepository.reverseGeocode` with a mocked `httpsCallable` — success → address string; callable throws → `''`. Add a `@react-native-firebase/functions` mock entry if the existing mock set doesn't already cover it (verify during planning). `tsc` / `eslint` / `jest` clean (existing 2 suites + this addition).
- **Deploy smoke test:** `firebase deploy --only functions:reverseGeocode` → grant `roles/cloudfunctions.invoker` to `allUsers` (same `gcloud functions add-iam-policy-binding` pattern as session 9) → curl with `{"data":{"latitude":..,"longitude":..}}` + a real admin Bearer token → expect `{result:{address:"..."}}` (or `''` for a remote/zero-result coord). Unauthenticated curl → `UNAUTHENTICATED` (confirms auth gate).

## Out of scope

- Claims (`companies/{companyId}/claims.gpsLocation`) — no address field on the claim model today; left for a later sub-project.
- `LiveTracking.tsx` hardcoded SA city table — that is forward geocoding (address → coords) for pending deliveries, a different direction; unchanged here.
- Backfill of existing PODs with empty `address` — the callable is reusable for a future batch backfill, but no backfill pass is built in this sub-project.
- Offline-queue interaction — geocoding at capture assumes online; the offline case degrades gracefully to `''` and is fully handled when the offline-queue sub-project lands.

## Deploy + vault update

- `cd functions && npm run build && firebase deploy --only functions:reverseGeocode` against `podsafe-f4a47`.
- `gcloud functions add-iam-policy-binding reverseGeocode --role=roles/cloudfunctions.invoker --member=allUsers --region=us-central1` (1st Gen syntax).
- Curl smoke test (above).
- Update vault `08 Backend Gap Fix Tracker` + `09 Phase Checklist`: Phase 6 reverse-geocoding item → done; record deploy + key outcome (existing key worked / server key created). Note remaining Phase 6 items (offline queue, push notifications).

## Non-Flutter constraint

This sub-project touches only `functions/` and `mobile-rn/`. No Flutter/Dart files are created or edited (standing user constraint on this migration).