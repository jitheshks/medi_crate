# MediCrate – Phase 3B.2.1: Firebase Independence & Google OAuth Configuration Audit Report

**Date:** 2026-11-08  
**Author:** Antigravity Agent  
**Status:** Completed & Verified  
**Target Repository:** `~/Documents/medi_crate`  
**Reference Project (Read-Only):** `~/Documents/Reubro/medivalut`  

---

## 1. Executive Summary & Architectural Decisions

Following the completion of **Phase 3B.2** (Supabase Client Initialization & Authentication Implementation), this audit rigorously evaluated the application's runtime dependencies on Firebase, its Google OAuth configuration, and secure storage usage.

### Core Architectural Mandates
1. **Supabase as Sole Authentication Authority:** Supabase GoTrue manages all session persistence, identity records, and token refreshes. No secondary authentication authority (Firebase or Laravel Sanctum) is required.
2. **Native Google OAuth Without Firebase:** Device-level Google Sign-In extracts the raw Google ID token (`GoogleSignInAuthentication.idToken`) and exchanges it directly with Supabase via `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: ...)`. Firebase Auth is completely bypassed.
3. **No Foreign Identity Poisoning:** All hardcoded MediVault Google OAuth client IDs and silent fallbacks have been eliminated. Missing or unconfigured environment variables produce clear, fail-fast diagnostic errors instead of silently routing credentials to MediVault's Firebase project (`medivault-428b2`).
4. **Offline Clinical Storage Protection:** Hive clinical records (`userBox`, `profileBox`, `syncQueueBox`) remain completely decoupled from authentication providers. Sign-in, token refresh, and sign-out operations do not destroy or modify clinical data.

---

## 2. Complete Firebase Reference Inventory & Classification

A codebase-wide audit of `lib/`, `android/`, `ios/`, `pubspec.yaml`, and `test/` was performed to identify and classify every Firebase-related reference.

### 2.1 Inventory Table

| Component / File | Reference Type | Former State | Action Taken in Phase 3B.2.1 | Classification |
| :--- | :--- | :--- | :--- | :--- |
| `lib/main.dart` | Code | `await Firebase.initializeApp(...)` executed on app boot | **Removed entirely**. App startup is 100% independent of Firebase. | **Unnecessary Firebase Initialization (Removed)** |
| `lib/main.dart` | Imports | `import 'package:firebase_core/firebase_core.dart';` & `import 'firebase_options.dart';` | **Removed**. | **Unnecessary Import (Removed)** |
| `lib/firebase_options.dart` | Code / Config | Auto-generated options containing API keys for `medivault-428b2` (MediVault Firebase project) | Retained as inert file to prevent breakage pending Phase 3B.4 dependency pruning. Not imported or referenced anywhere in `lib/`. | **Configuration-Only Reference (Inert)** |
| `lib/features/auth/data/services/google_auth_service.dart` | Code | Imported `package:firebase_auth/firebase_auth.dart`, accepted `FirebaseAuth` instance, hardcoded MediVault Web Client ID `147675311808-...` | **Completely purged**. Removed `firebase_auth` import, removed `FirebaseAuth` fields, replaced hardcoded fallback with strict environment validation. | **Unused Firebase Dependency (Purged)** |
| `lib/features/auth/data/models/user_model.dart` | Code | `resolveFirebaseProvider()` queried `FirebaseAuth.instance.currentUser` | **Decoupled**. Removed `firebase_auth` import. Returns `AuthProviderType.emailPassword` safely without calling Firebase. | **Unused Firebase Dependency (Purged)** |
| `pubspec.yaml` | Dependencies | `firebase_core: ^5.1.0`<br>`firebase_auth: ^7.0.1` | Preserved in `pubspec.yaml` for Phase 3B.4 package cleanup per project boundaries. **Zero runtime calls**. | **Unused Firebase Dependency (Scheduled for Phase 3B.4 removal)** |
| `android/app/google-services.json` | Config | Does not exist in `medi_crate`. | Confirmed absent. | **N/A (Clean)** |
| `android/build.gradle.kts` | Build Script | No `com.google.gms.google-services` plugin applied. | Confirmed absent. | **N/A (Clean)** |
| `android/app/build.gradle.kts` | Build Script | No `com.google.gms.google-services` or Firebase plugins applied. | Confirmed absent. | **N/A (Clean)** |
| `ios/Runner/GoogleService-Info.plist` | Config | Does not exist in `medi_crate`. | Confirmed absent. | **N/A (Clean)** |
| `ios/Podfile` / `Podfile.lock` | iOS Build | Pods downloaded via transitive pubspec dependencies. | Untouched until Phase 3B.4. | **Unused Transitive Native Dependency** |
| `test/` | Tests | No test references Firebase APIs. | Confirmed clean. | **N/A (Clean)** |

---

## 3. Firebase Initialization Removal Details

### 3.1 Changes in `lib/main.dart`
Prior to Phase 3B.2.1, `lib/main.dart` initialized Firebase before Supabase:
```dart
// FORMER CODE (REMOVED):
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Inside main():
try {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppLogger.info('Firebase initialized successfully.');
} catch (e, st) {
  AppLogger.error('Firebase initialization failed: $e\n$st');
}
```

### 3.2 Current Implementation
`Firebase.initializeApp()` was deleted from `lib/main.dart`. The application startup sequence now only initializes:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `dotenv.load(fileName: '.env')` (with graceful fallback if unpopulated)
3. `SupabaseConfig.initialize()` (Supabase as the single authority)
4. `HiveService.init()` (Local clinical persistence & encryption)
5. `GoogleAuthService.initialize(serverClientId: ...)` (Native Google Sign-In)
6. `BackgroundSyncService.initialize()` (Legacy sync suspended for migration)
7. `runApp(ProviderScope(child: MediCrateApp()))`

### 3.3 Boot Verification
- The app compiles and initializes without `Firebase.initializeApp()`.
- No `[core/no-app]` or `FirebaseException` errors occur during cold start.
- `flutter test` executes all 68 unit, repository, and widget tests without Firebase errors.

---

## 4. Native Google OAuth Configuration Findings

### 4.1 Discovery & Origin of Hardcoded Client ID
In `GoogleAuthService`, the following hardcoded constant was previously present:
```dart
const String kGoogleWebServerClientId =
    '147675311808-e7nh1pk2a214rhak4un8uvme0rr7a5fr.apps.googleusercontent.com';
```
**Origin:** Cross-referencing `~/Documents/Reubro/medivalut/android/app/google-services.json` confirmed that project number `147675311808` corresponds to the old **MediVault Firebase project** (`medivault-428b2`).  
**Risk Identified:** If `GOOGLE_WEB_CLIENT_ID` was omitted from `.env`, the app would silently issue Google ID tokens targeted for MediVault's Firebase project. When sent to Supabase GoTrue for MediCrate, Supabase would reject the token with an audience mismatch (`aud` claim != Supabase Google Client ID), or worse, associate identity with the wrong client credentials.

### 4.2 Hardened Implementation
1. **Constant Eliminated:** `kGoogleWebServerClientId` and all silent fallbacks were completely deleted from `lib/features/auth/data/services/google_auth_service.dart`.
2. **Mandatory Configuration:** `GoogleAuthService.initialize({String? serverClientId})` requires a non-empty string.
3. **Graceful Diagnostic Error:** If `GOOGLE_WEB_CLIENT_ID` is missing from `.env` or empty:
   - `GoogleAuthService.isInitialized` remains `false`.
   - `GoogleAuthService.lastInitError` records:
     ```
     Google Sign-In is unconfigured: GOOGLE_WEB_CLIENT_ID environment variable is missing or empty. Please configure GOOGLE_WEB_CLIENT_ID in your .env or environment configuration.
     ```
   - Attempting Google Sign-In returns `GoogleAuthResult.failure` with `failureStage: 'A_ACCOUNT_SELECTION'` and a clear descriptive error message, preventing crashes or ambiguous auth failures.
4. **Direct Supabase Token Exchange:** When configured, `GoogleSignIn` yields `GoogleSignInAuthentication.idToken`. This ID token is passed directly to `SupabaseAuthRemoteDataSource.signInWithGoogleIdToken(idToken)` -> `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken)`.

---

## 5. Secure Storage Usage Inventory

A comprehensive inspection of `SecureStorageService` (`lib/core/storage/secure_storage_service.dart`) was conducted to ensure Supabase tokens are not mismanaged or leaked to legacy mechanisms.

### 5.1 Storage Inventory

| Key Constant | Description | Former Usage (MediVault / Laravel) | Current Usage (MediCrate / Supabase) | Target State (Phase 3B.4) |
| :--- | :--- | :--- | :--- | :--- |
| `auth_bearer_token` | HTTP Bearer access token | Stored Laravel Sanctum access token for `DioInterceptor` | **Never written by Supabase**. `AuthRepository.signOut()` and `deleteAccount()` clear this key if present for legacy cleanup safety. | Remove class and package. |
| `auth_refresh_token` | HTTP Bearer refresh token | Stored Laravel Sanctum refresh token | **Never written by Supabase**. | Remove class and package. |

### 5.2 Supabase Session Persistence Independence
- Supabase GoTrue manages its own session persistence internally via its built-in client storage mechanism (`SharedPreferences` on Android/iOS).
- Supabase access tokens, refresh tokens, and JWT expiry timestamps are never manually copied to or read from `SecureStorageService`.
- Unit tests in Group 7 verify that `AuthRepository.signIn`, `googleLogin`, `verifyEmail`, and `checkSession` operate with a 100% empty `SecureStorageService`.
- `SecureStorageService` is purely retained as a no-op safety harness until Phase 3B.4, when `flutter_secure_storage` will be pruned from `pubspec.yaml`.

---

## 6. Dependency Removal Recommendations for Phase 3B.4

To ensure stability across Phase 3B milestones, dependency pruning was deferred to **Phase 3B.4** per the project roadmap. The following items are slated for removal:

1. **`firebase_core: ^5.1.0`** (in `pubspec.yaml`)
2. **`firebase_auth: ^7.0.1`** (in `pubspec.yaml`)
3. **`lib/firebase_options.dart`** (inert file deletion)
4. **`flutter_secure_storage: ^9.2.4`** (in `pubspec.yaml`)
5. **`lib/core/storage/secure_storage_service.dart`** (deletion after replacing any residual references with Hive/in-memory helpers)

Removing these will reduce Android APK size, eliminate Kotlin Gradle Plugin (KGP) warnings during builds, and reduce iOS Pod compilation overhead.

---

## 7. Test & Build Results

### 7.1 Static Code Analysis
Command: `flutter analyze`
```
Analyzing medi_crate...
No issues found! (ran in 5.3s)
```
**Result:** 0 issues found.

### 7.2 Unit & Integration Test Suite
Command: `flutter test`
```
00:05 +68: All tests passed!
```
**Result:** 68/68 tests passed across all 11 test suites.

#### Specific Group 7 Test Assertions (`supabase_auth_test.dart`):
- `UserModel.resolveFirebaseProvider returns emailPassword without calling FirebaseAuth`: **PASSED**
- `Google OAuth login executes direct ID-token exchange with Supabase GoTrue with zero Firebase or Laravel involvement`: **PASSED**
- `Supabase session and auth state restore correctly without SecureStorageService tokens`: **PASSED**
- `GoogleAuthService enforces serverClientId requirement and disallows silent fallback to MediVault client ID`: **PASSED**

### 7.3 Debug APK Compilation
Command: `flutter build apk --debug`
```
Running Gradle task 'assembleDebug'...                             14.8s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```
**Result:** Build succeeded with exit code 0. No Firebase runtime or Google Services plugin dependencies required.

---

## 8. Manual Google Cloud & Supabase Dashboard Configuration Steps

To enable native Google Sign-In with direct Supabase token exchange in production, perform the following setup:

### Step 1: Create Google Cloud OAuth 2.0 Credentials
1. Go to the [Google Cloud Console](https://console.cloud.google.com/) for your MediCrate Google Cloud project.
2. Navigate to **APIs & Services** > **Credentials**.
3. Create **OAuth client ID**:
   - **Type 1: Web application** (used as Server Client ID for token verification):
     - Name: `MediCrate Web / Backend Client`
     - Authorized redirect URIs: Add your Supabase project callback URL:
       `https://<your-supabase-project-id>.supabase.co/auth/v1/callback`
     - Note the generated **Client ID** and **Client Secret**.
   - **Type 2: Android**:
     - Name: `MediCrate Android Client`
     - Package name: `com.example.medi_crate` (or your configured application ID)
     - SHA-1 certificate fingerprint: Add debug and release SHA-1 fingerprints (`keytool -list -v -keystore ...`).
   - **Type 3: iOS** (if deploying to iOS):
     - Name: `MediCrate iOS Client`
     - Bundle ID: `com.example.mediCrate`

### Step 2: Configure Google Provider in Supabase Dashboard
1. Open the [Supabase Dashboard](https://app.supabase.com/) and select your MediCrate project.
2. Go to **Authentication** > **Providers** > **Google**.
3. Enable the Google provider.
4. Set **Client ID** to the **Web application Client ID** created in Step 1.
5. Set **Client Secret** to the **Web application Client Secret** created in Step 1.
6. Enable **Skip nonce check** if required by the native Google Sign-In SDK version, or verify nonce configuration.
7. Click **Save**.

### Step 3: Configure MediCrate Environment (.env)
Add the Web application Client ID to your local `.env` file:
```env
SUPABASE_URL=https://<your-supabase-project-id>.supabase.co
SUPABASE_ANON_KEY=<your-supabase-anon-key>
GOOGLE_WEB_CLIENT_ID=<your-web-client-id>.apps.googleusercontent.com
```

---

## 9. Remaining Unresolved Issues & Risks

1. **Gradle KGP Warning:** `firebase_auth` and `firebase_core` trigger a Gradle Kotlin Gradle Plugin (KGP) deprecation warning during `assembleDebug`. This warning is harmless and will disappear when both packages are pruned in Phase 3B.4.
2. **Missing `GOOGLE_WEB_CLIENT_ID` in Fresh Clones:** If a developer runs the app without setting `GOOGLE_WEB_CLIENT_ID` in `.env`, Google Sign-In displays a clean error banner indicating the configuration is missing, while Email/Password authentication continues to function uninterrupted.
3. **Old MediVault Reference Isolation:** Verified that `~/Documents/Reubro/medivalut` was completely untouched during this phase.

---
**Phase 3B.2.1 Audit Complete.** Ready for user review and commit.
