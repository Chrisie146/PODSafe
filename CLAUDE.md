# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PODSafe is a Flutter + Firebase multi-tenant Proof-of-Delivery app. Drivers capture signed/photographed/GPS-verified delivery confirmations on mobile; admins manage deliveries, drivers, customers, claims, and reporting from a responsive desktop layout of the same Flutter app. A Node/TypeScript Cloud Functions backend handles privileged operations (user/company creation) and a Microsoft Dynamics Business Central integration (OAuth, shipment pull, POD push).

## Repository layout gotcha

There is a `podsafe/` subdirectory at the repo root that is a **full duplicate copy** of the entire project (its own `lib/`, `android/`, docs, etc.), and it is tracked in git. It is not a git submodule and has no Firebase/build relationship to the root project. Always work in the repo root (`lib/`, `functions/`, etc.) — don't edit files under `podsafe/` unless explicitly asked to.

The repo root also has several hundred dated status/summary `*.md` files (e.g. `BACKUP_*.md`, `ADMIN_DASHBOARD_*.md`, `BC_*.md`) left over from prior work sessions. These are historical notes, not living documentation — don't treat them as current specs; verify any claim against the actual code.

## Commands

### Flutter app
```bash
flutter pub get                          # install dependencies
flutter run -d chrome                    # run web (admin/dev convenience)
flutter run                              # run on connected device/emulator
flutter analyze                          # static analysis (flutter_lints)
flutter test                             # run all tests
flutter test test/unit/logic_tests.dart  # run a single test file
flutter test --coverage                  # with coverage report
```
`run_tests.sh` / `run_tests.bat` just wrap `flutter test test/unit/logic_tests.dart`.

### Cloud Functions (`functions/`)
```bash
cd functions
npm install
npm run build       # tsc compile src/ -> lib/
npm run deploy      # build + firebase deploy --only functions
npm run serve       # build + firebase emulators:start --only functions
npm test            # vitest run
```
Functions are written in TypeScript under `functions/src/`; `functions/lib/` is the compiled JS output consumed by Firebase — don't hand-edit `lib/`.

### Firebase environments
```bash
firebase use dev    # podsafe-92a3e (default/day-to-day)
firebase use prod   # podsafe-production
firebase deploy --only firestore:rules,storage:rules,functions,hosting
```
The Flutter client does **not** switch environments via `--dart-define`. It's controlled by a hardcoded constant: `lib/config/environment.dart` → `EnvironmentConfig.current` (`Environment.development` or `Environment.production`). `lib/main.dart` picks `firebase_options.dart` (dev) vs `firebase_options_prod.dart` (prod) based on that constant. To build for production, flip `current` to `Environment.production` before building — this is also a common source of "wrong database" bugs, so check it when debugging environment-specific issues.

### Security rules testing
```bash
npm run test:security        # node test_security_rules.js (against emulator/dev project)
npm run setup:test-data      # node setup_test_data.js
```

## Architecture

### Multi-tenancy & RBAC
Every data document carries a `companyId`; almost all Firestore queries filter on it (`where('companyId', '==', user.companyId)`). `firestore.rules` re-derives the caller's role/company by `get()`-ing their `users/{uid}` doc and enforces company-scoping and role checks there — security is enforced server-side in rules, not just client-side.

Roles (`UserRole` in [lib/models/user_model.dart](lib/models/user_model.dart)): `admin`, `manager`, `logistics`, `accountant`, `filing_clerk`, `driver`. Beyond coarse role checks, there's a granular permission system in [lib/models/permission.dart](lib/models/permission.dart) (`Permission` enum like `deliveriesManage`, `podsApprove`, `claimsApprove`) mapped per-role by `PermissionService` ([lib/services/permission_service.dart](lib/services/permission_service.dart)) and enforced in UI via the `PermissionGuard` widget ([lib/widgets/permission_guard.dart](lib/widgets/permission_guard.dart)).

Companies and users are never created directly from the client (Firestore rules `allow create: if false` on `companies`) — creation goes through Cloud Functions (`createCompanyWithAdmin`, functions in `functions/src/auth/userManagement.ts`) so privileged Admin SDK operations stay server-side.

### Flutter app structure
- `lib/models/` — plain data classes with `fromFirestore`/`toFirestore` (or `fromMap`/`toMap`) converters.
- `lib/services/` — Firebase/business logic (one per domain: `auth_service`, `delivery_service`, `pod_service`, `claim_service`, `chat_service`, `business_central_service`, etc.).
- `lib/providers/` — `ChangeNotifier` state holders wired up via `provider` in `main.dart`'s `MultiProvider`; screens consume them with `Consumer`/`context.read`/`context.watch`.
- `lib/screens/{admin,driver,auth,setup,public,external,debug,developer}/` — UI, split by user-facing area.
- `lib/widgets/` — shared widgets.
- The OCR "document intake" flow under `lib/services/pod_repository.dart` + `lib/services/pod_controller.dart` is a newer **repository/controller** pattern (controller is a `ChangeNotifier` injected with a repository + parser) rather than the older service/provider split — don't assume one pattern applies everywhere.

### Responsive admin screens
Admin screens follow a split-by-width convention: `lib/screens/admin/foo_screen.dart` is a thin `LayoutBuilder` that renders a desktop variant (`foo_dashboard_desktop.dart` or similarly named) when `constraints.maxWidth > 1000`, otherwise a mobile widget (often defined in the same `_screen.dart` file). When changing admin UI behavior, check both the `_screen.dart` and the matching `_desktop.dart` file — logic can diverge between them since they're largely independent implementations, not a shared widget with breakpoints.

### Web/mobile conditional code
Several services need different implementations on Flutter Web vs. native (file system access, downloads). They use Dart's conditional import pattern: `service.dart` imports `service_web.dart` or `service_mobile.dart`/`service_stub.dart` via `import 'x_web.dart' if (dart.library.io) 'x_mobile.dart';`. Examples: `csv_export_service.dart`, `pdf_export_service.dart`, `delivery_export_service.dart`, `bulk_pod_download_service.dart`. When editing these, update the platform-specific file, not just the dispatcher.

### Cloud Functions (`functions/src/`)
- `index.ts` — exports/entry point for all functions (HTTPS endpoints, scheduled jobs, Firestore triggers).
- `auth/` — `bcAuth.ts` (Business Central OAuth redirect/callback), `userManagement.ts` (invite-only user creation/management).
- `integrations/businessCentral/` — `client.ts` (BC API client), `pull.ts` (pull shipments from BC into Firestore `deliveries`), `push.ts` (push POD data back to BC).
- `store/firestore.ts` — Firestore read/write helpers used by the integration layer.
- `createCompanyWithAdmin.ts` — self-service company+admin signup endpoint.
- BC sync also runs via a daily scheduled function (`bcScheduledPull`) and a Firestore `onUpdate` trigger on `deliveries/{deliveryId}` (`bcAutoPushPod`) that auto-pushes PODs to BC when a delivery reaches a final status.

### Public/external access without login
- `lib/screens/public/public_pod_view_screen.dart` — customers view a POD via `/pod/:deliveryId?token=xxx`, validated against `lib/models/pod_access_token.dart` / `lib/services/pod_token_service.dart`.
- `lib/screens/external/upload_screen.dart` — external (non-employee) document upload via `/upload/:token`, backed by `lib/models/external_delivery_token.dart` / `lib/services/external_upload_service.dart`.
Both routes are handled by custom `onGenerateRoute` logic in `lib/main.dart` rather than the static `routes` map — check there when adding similar token-based public routes.

### Admin web dashboard
`admin_web_dashboard/` is a separate, minimal static HTML dashboard (not part of the Flutter build). The real, actively-developed admin interface is the Flutter app's `lib/screens/admin/*` (built for web via `flutter build web`), not this folder.

## Firebase project structure
- Firestore rules: `firestore.rules` is the deployed file (other `*.rules.*` variants in the repo root like `.secure`, `.rbac`, `.simple`, `.backup.*` are historical/alternate copies — confirm which file `firebase.json` points to before assuming one is live; currently it's `firestore.rules`).
- Same caveat applies to `storage.rules` vs. `storage.rules.secure`.
- Firestore region: `africa-south1` (set in `firebase.json`).

## Project Instructions
- Always read through the obsidian vault before anything and always update the obsidian vault.
- Use mempalace everywhere where necessary !!IMPORTANT!!
- Make sure all mcp servers are working, if not do not do anything, ask me to check the servers and/or give you permission to proceed
- You will give a short summary for yourself to use to continue.
