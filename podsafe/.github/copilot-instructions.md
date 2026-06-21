# PODSafe AI Coding Instructions

## Architecture Overview
PODSafe is a Flutter + Firebase multi-tenant Proof of Delivery app with company-based data isolation. Core components:
- **Frontend**: Flutter app with Provider state management
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions)
- **Security**: Role-based access (admin/driver) with Firestore security rules
- **Multi-tenancy**: Company-scoped data access via `companyId` field

Key directories: `lib/models/` (data structures), `lib/services/` (Firebase operations), `lib/providers/` (state), `lib/screens/` (UI), `functions/` (server-side logic).

## Critical Patterns
- **Company Isolation**: All queries filter by `companyId` from user document. Example: `where('companyId', '==', user.companyId)`
- **Role Checks**: Use `user.role` ('admin'/'driver') for UI/feature gating. Admins see management screens, drivers see delivery interface.
- **Offline Support**: Use `ConnectivityPlus` for network checks, cache data locally with `SharedPreferences`.
- **Error Handling**: Wrap Firebase calls in try-catch, show user-friendly messages via `ScaffoldMessenger`.
- **State Management**: Update providers after Firebase operations, listen with `Consumer` widgets.

## Developer Workflows
- **Multi-Environment**: Switch with `firebase use dev|staging|prod`. Dev for development, staging for testing, prod for live.
- **Local Development**: `flutter run -d chrome` (web) or device. Hot reload with 'r'.
- **Testing**: Run `flutter test` or `./run_tests.sh`. Unit tests in `test/unit/`.
- **Deployment**: Build web with `flutter build web --dart-define=ENV=production`, deploy with `firebase deploy`.
- **Cloud Functions**: Develop in `functions/`, deploy with `npm run deploy` from functions directory.

## Integration Points
- **Firebase Auth**: User creation via Cloud Functions to avoid client-side permission issues.
- **Firestore Rules**: Enforce company boundaries and roles. Test rules with Firebase emulator.
- **Storage**: Upload POD photos/signatures to `companies/{companyId}/pods/`.
- **GPS**: Use `Geolocator` for location capture, require accuracy < 50m.

## Common Pitfalls
- Missing `companyId` in documents breaks data visibility.
- Direct user creation from client causes permission errors; use Cloud Functions.
- Forgetting environment switch leads to wrong database modifications.
- Not handling offline state causes crashes; check connectivity first.

Reference: `README.md` (overview), `firestore.rules` (security), `MULTI_ENVIRONMENT_WORKFLOW.md` (deployment), `ROADMAP.md` (phases).</content>
<parameter name="filePath">c:\Users\christopherm\PODSafe\podsafe\.github\copilot-instructions.md