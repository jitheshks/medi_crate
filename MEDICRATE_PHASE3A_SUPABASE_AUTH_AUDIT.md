# MediCrate – Phase 3A: Supabase Authentication Audit & Migration Architecture

> **Document Type:** Technical Audit & Architecture Specification  
> **Status:** Draft / Complete Audit (Pre-Implementation)  
> **Project Reference:** `wnaflcytkubqmrymbmcn` (Supabase Linked Project)  
> **Target Framework:** Flutter 3.47.x / Dart 3.13.x / Riverpod 3.5.0  
> **Date:** November 2026  

---

## Executive Summary

This document presents a comprehensive audit of the inherited MediVault authentication infrastructure and defines the target architecture for migrating MediCrate to **Supabase Auth** (Email/Password and Google OAuth).

The audit established that:
1. **Firebase is used exclusively as a client-side credential exchange shim**: It does not store application data, Firestore documents, or cloud storage buckets. Firebase Auth’s sole role is receiving native Google/Apple credentials, generating a Firebase ID token, and sending that token to Laravel.
2. **Laravel is the true identity and session authority**: The Laravel API (`/api/v1/auth/*`) verifies the Firebase token (or username/password), issues Laravel Sanctum Bearer tokens, and controls user accounts with integer IDs (`user_id: int`).
3. **Clinical data is profile-isolated**: All clinical models (consultations, reports, medicines, vitals, etc.) are associated with UUID `profile_id` strings belonging to an `ownerUserId` in local Hive storage.
4. **Apple Sign-In is completely dispensable**: In accordance with user requirements, Apple authentication will be cleanly deprecated without impacting core features.
5. **Google OAuth migration must use native ID token exchange (`signInWithIdToken`)**: This provides a frictionless user experience on Android Credential Manager and iOS without clunky external browser redirects or deep-link redirect dependencies.

---

## 1. Current Authentication Architecture

### 1.1 Architectural Overview
The inherited MediVault authentication flow is a hybrid three-tier model:

```
[Flutter Client UI]
       │
       ├─────────────────────────────────────────┐
       │ (Email & Password)                      │ (Google / Apple OAuth)
       ▼                                         ▼
[AuthRepository / DataSource]             [Native Platform SDK]
       │                                         │
       │                                         ▼
       │                                  [FirebaseAuth.instance]
       │                                         │ (Exchange for ID Token)
       │                                         ▼
       │                                  [Firebase ID Token]
       │                                         │
       └─────────────────┬───────────────────────┘
                         ▼
             [Laravel REST API v1]
           (Cloudways PHP Backend)
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
     [MySQL Database]        [Sanctum Token Engine]
     (Users Table: int id)   (Access & Refresh Tokens)
                         │
                         ▼
             [Flutter Client Storage]
             ├── SecureStorage: Bearer Tokens
             └── Hive: User Profile & Session Cache
```

### 1.2 Key Architectural Components

1. **Presentation Layer**:
   - [`SignInScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/sign_in_screen.dart): Renders email/password form and social buttons.
   - [`SignUpScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/sign_up_screen.dart): Collects name, email, password, DOB, and optional gender.
   - [`OtpVerificationScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/otp_verification_screen.dart): Collects 4-digit numeric OTP for email verification or password reset.
   - [`ForgotPasswordScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/forgot_password_screen.dart) & [`ResetPasswordScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/reset_password_screen.dart): Password recovery workflow.
   - [`SplashScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/splash_screen.dart): Gates startup on `authNotifier.initialSessionReady`.
2. **State Management**:
   - [`AuthNotifier`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/providers/auth_notifier.dart): Modern Riverpod 3.5 `Notifier<AuthState>` controlling `isLoading`, `isAuthenticated`, `user`, and error states.
   - [`authControllerProvider`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/providers/auth_providers.dart#L106): `NotifierProvider<AuthNotifier, AuthState>`.
3. **Repository & Data Sources**:
   - [`AuthRepository`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/repositories/auth_repository.dart): Coordinates offline checks, remote API calls, secure token persistence, and local caching.
   - [`AuthRemoteDataSource`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/datasources/remote/auth_remote_data_source.dart): Dio HTTP client executing endpoints A1–A10 against Laravel.
   - [`AuthLocalDataSource`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/datasources/local/auth_local_data_source.dart): Caches `UserModel` in Hive `userBox` and session flags in `authBox`.
4. **Network & Storage Interceptors**:
   - [`AuthInterceptor`](file:///home/blackhat/Documents/medi_crate/lib/core/api/dio_interceptor.dart): Injects `x-api-key` and `Authorization: Bearer <token>`, silently refreshes expired tokens via endpoint A7 upon receiving HTTP 401.
   - [`SecureStorageService`](file:///home/blackhat/Documents/medi_crate/lib/core/storage/secure_storage_service.dart): Encrypted storage backing Android KeyStore and iOS Keychain for access/refresh tokens.

---

## 2. Complete Firebase Dependency Map

### 2.1 Direct Imports in `lib/`
Only **5 files** in the entire codebase directly touch Firebase:

| File Path | Firebase API / Package Used | Purpose |
| :--- | :--- | :--- |
| [`lib/main.dart:1,26`](file:///home/blackhat/Documents/medi_crate/lib/main.dart#L1) | `firebase_core`: `Firebase.initializeApp(...)` | Initializes Firebase runtime during application bootstrap (`Future.wait`). |
| [`lib/firebase_options.dart:3,17`](file:///home/blackhat/Documents/medi_crate/lib/firebase_options.dart#L3) | `firebase_core`: `FirebaseOptions`, `DefaultFirebaseOptions` | Static platform credentials generated by FlutterFire CLI. |
| [`lib/features/auth/data/models/user_model.dart:1,45`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/models/user_model.dart#L1) | `firebase_auth`: `FirebaseAuth.instance.currentUser` | Resolves fallback provider string (`password`, `google.com`, `apple.com`). |
| [`lib/features/auth/data/services/google_auth_service.dart:1,51,119`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/services/google_auth_service.dart#L1) | `firebase_auth`: `FirebaseAuth`, `GoogleAuthProvider`, `signInWithCredential` | Exchanges Google ID token for Firebase user credential to retrieve `firebaseIdToken`. |
| [`lib/features/auth/data/services/apple_auth_service.dart:5,56,128,268`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/services/apple_auth_service.dart#L5) | `firebase_auth`: `FirebaseAuth`, `AppleAuthProvider`, `OAuthCredential` | Exchanges Apple identity token for Firebase credential to retrieve `firebaseIdToken`. |

### 2.2 Native Platform Configuration
- **Android**:
  - No `google-services.json` is committed in `android/app/`.
  - No `com.google.gms.google-services` Gradle plugin is applied in `android/app/build.gradle.kts`.
  - Android uses Dart-only initialization with `DefaultFirebaseOptions.android`.
- **iOS / macOS**:
  - No `GoogleService-Info.plist` is committed in `ios/Runner/`.
  - iOS uses Dart-only initialization with `DefaultFirebaseOptions.ios`.
- **Historical Evidence**:
  - In `lib/firebase_options.dart:68,78`, legacy bundle identifiers were discovered:
    - iOS Bundle ID: `com.reubro.medivault`
    - macOS Bundle ID: `com.example.medivalut`
    - Firebase Project ID: `medivault-428b2`

---

## 3. Complete Laravel Authentication Endpoint Inventory

The current application connects to the Laravel backend at `https://phplaravel-1505866-6585565.cloudwaysapps.com/api/v1`.

### 3.1 Section A: Authentication Endpoints (A1–A10)

| ID | Endpoint | Method | Request Payload | Response Data | Token & ID Formats | Calling Service / Provider | Status |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| **A1** | `/auth/signup` | POST | `name`, `email`, `password`, `password_confirmation`, `dob` (YYYY-MM-DD), `gender` | `{"status": "success", "data": {"user_id": 12, "message": "Verification code sent to your email"}}` (or `"pending_verification"`) | User ID: `int`. No tokens issued yet. | `AuthRemoteDataSource.signUp` / `AuthNotifier.signUp` | Active |
| **A2** | `/auth/verify-email` | POST | `email`, `otp` (4-digit string) | `{"status": "success", "data": {"user_id": 12, "name": "...", "email": "...", "access_token": "...", "refresh_token": "..."}}` | User ID: `int`. Access & Refresh tokens: Sanctum strings. | `AuthRemoteDataSource.verifyEmail` / `AuthNotifier.verifyEmail` | Active |
| **A3** | `/auth/resend-otp` | POST | `email`, `type` (`'signup' \| 'reset_password' \| 'change_email'`) | `{"status": "success", "data": {"message": "OTP resent successfully."}}` | No tokens. | `AuthRemoteDataSource.resendOtp` / `AuthNotifier.resendOtp` | Active |
| **A4** | `/auth/login` | POST | `email`, `password` | `{"status": "success", "data": {"user_id": 12, "name": "...", "email": "...", "access_token": "...", "refresh_token": "..."}}` (or `"pending_verification"`) | User ID: `int`. Tokens: Sanctum strings. | `AuthRemoteDataSource.login` / `AuthNotifier.signIn` | Active |
| **A5** | `/auth/forgot-password`| POST | `email` | `{"status": "success", "data": {"message": "Password reset OTP sent to email."}}` | No tokens. | `AuthRemoteDataSource.forgotPassword` / `AuthNotifier.forgotPassword` | Active |
| **A6** | `/auth/reset-password` | POST | `email`, `otp` (4-digit), `password`, `password_confirmation` | `{"status": "success", "data": {"message": "Password reset successful."}}` | All existing tokens revoked on server. | `AuthRemoteDataSource.resetPassword` / `AuthNotifier.resetPassword` | Active |
| **A7** | `/auth/refresh-token` | POST | `refresh_token` | `{"status": "success", "data": {"access_token": "...", "refresh_token": "..."}}` | Access & Refresh tokens: Sanctum strings. | `AuthRemoteDataSource.refreshToken` / `AuthInterceptor._performTokenRefresh` | Active |
| **A8** | `/auth/google-login` | POST | `firebase_id_token` | `{"status": "success", "data": {"user_id": 12, "name": "...", "email": "...", "access_token": "...", "refresh_token": "..."}}` | User ID: `int`. Tokens: Sanctum strings. | `AuthRemoteDataSource.googleLogin` / `AuthNotifier.signInWithGoogle` | Active |
| **A9** | `/auth/apple-login` | POST | `firebase_id_token` | `{"status": "success", "data": {"user_id": 12, "name": "...", "email": "...", "access_token": "...", "refresh_token": "..."}}` | User ID: `int`. Tokens: Sanctum strings. | `AuthRemoteDataSource.appleLogin` / `AuthNotifier.signInWithApple` | Deprecating |
| **A10**| `/auth/logout` | POST | *None* (Header: `Authorization: Bearer <token>`) | `{"status": "success", "data": {"message": "Successfully logged out."}}` | Revokes current Sanctum token on server. | `AuthRemoteDataSource.logout` / `AuthNotifier.signOut` | Active |

### 3.2 Section B: User Account Profile Endpoints (B1–B5)

| ID | Endpoint | Method | Request Payload | Response Data | Calling Service |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **B1** | `/users/me` | GET | *None* | `{"status": "success", "data": {"user": {...}, "profile": {...}}}` | `UserRemoteDataSource.getProfile` |
| **B2** | `/users/me` | POST / PUT | `fields` Map (optional multipart `photo`) | `{"status": "success", "data": {"user": {...}}}` | `UserRemoteDataSource.updateProfile` |
| **B3** | `/users/me/password` | POST | `current_password`, `new_password`, `new_password_confirmation` | `{"status": "success", "data": {"message": "Password changed successfully"}}` | `UserRemoteDataSource.changePassword` |
| **B4** | `/users/me/email` | POST | `current_password`, `new_email` | `{"status": "success", "data": {"message": "Verification code sent to your new email"}}` | `UserRemoteDataSource.requestChangeEmail` |
| **B4.2**| `/users/me/email/confirm` | POST | `otp` (4-digit) | `{"status": "success", "data": {"user": {...}}}` | `UserRemoteDataSource.confirmChangeEmail` |
| **B5** | `/users/me` | DELETE | `current_password` | `{"status": "success", "data": {"message": "Account deleted successfully"}}` | `UserRemoteDataSource.deleteAccount` |

---

## 4. Google Authentication: Current Flow vs. Target Flow

### 4.1 Current Inherited Flow
```
1. GoogleSignIn.authenticate() (google_sign_in package)
      │ Returns: GoogleSignInAccount (with account.authentication.idToken)
      ▼
2. GoogleAuthProvider.credential(idToken: idToken)
      ▼
3. FirebaseAuth.instance.signInWithCredential(credential)
      │ Returns: UserCredential
      ▼
4. userCredential.user.getIdToken()
      │ Returns: firebaseIdToken
      ▼
5. POST /api/v1/auth/google-login {'firebase_id_token': firebaseIdToken}
      │ Backend validates token with Firebase Admin SDK
      ▼
6. Returns Laravel Sanctum access_token and refresh_token
```

### 4.2 Target Supabase Auth Flow: Native ID Token (Recommended)
`supabase_flutter: 2.18.3` directly supports `signInWithIdToken`:

```
1. GoogleSignIn.authenticate() (native Credential Manager on Android / iOS sheet)
      │ Returns: GoogleSignInAccount (account.authentication.idToken)
      ▼
2. supabase.auth.signInWithIdToken(
     provider: OAuthProvider.google,
     idToken: account.authentication.idToken!,
     nonce: rawNonce, // optional/recommended for replay protection
   )
      │ Supabase Auth server validates Google ID token against Google OAuth
      ▼
3. Supabase Auth session established
      ├── supabase.auth.currentSession (JWT Access Token & Refresh Token)
      └── supabase.auth.currentUser (Supabase UUID)
```

### 4.3 Comparison with Browser-Based OAuth (`signInWithOAuth`)

| Dimension | Native ID Token Flow (`signInWithIdToken`) | Browser OAuth Flow (`signInWithOAuth`) |
| :--- | :--- | :--- |
| **User Experience** | Seamless native sheet / Android Credential Manager. User never leaves app. | Context switch to external browser / Custom Tab and redirect back. |
| **URL Schemes** | No custom URL schemes required. | Requires custom URL schemes in `AndroidManifest.xml` and `Info.plist`. |
| **Deep Link Failures** | Immune to broken deep links or browser tab closures. | Fragile if user closes tab, has default browser misconfigured, or adblockers. |
| **Required Client IDs** | Web Client ID (`serverClientId`), Android Client ID (matching SHA-1). | Web Client ID & Client Secret in Supabase dashboard. |
| **Recommendation** | **STRONGLY RECOMMENDED for MediCrate mobile app**. | Fallback only (or for web builds). |

### 4.4 External Configuration Requirements for Google Sign-In
1. **Google Cloud Console**:
   - OAuth 2.0 Web Client ID: `kGoogleWebServerClientId` (`574482098020-f1cghf914972a95c477i9f1cmlak73fa.apps.googleusercontent.com` in `.env.example`).
   - Android Client ID: Configured for Android package name and debug/release keystore SHA-1.
2. **Supabase Dashboard** (`wnaflcytkubqmrymbmcn`):
   - Authentication → Providers → Google: Toggle **Enabled**.
   - Client ID: Web Client ID.
   - Client Secret: Web Client Secret from Google Cloud Console.
   - Authorized Client IDs (skip verification): Android Client ID so Supabase accepts ID tokens generated on Android.

---

## 5. User Identity and Profile Architecture

### 5.1 The Three-Identity Challenge

```
┌─────────────────────────────────┐
│     Firebase Identity (UID)     │
│  "zXy891..." (Client-Only)      │
└────────────────┬────────────────┘
                 │ (Deprecated)
                 ▼
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│   Laravel Identity (Integer)    │       │     Supabase Identity (UUID)    │
│   id: 12 (MySQL Primary Key)    │◄─────►│ id: "a1d2f71e-..." (auth.users) │
└────────────────┬────────────────┘       └────────────────┬────────────────┘
                 │                                         │
                 └───────────────────┬─────────────────────┘
                                     ▼
                      ┌─────────────────────────────┐
                      │    MediCrate ProfileModel   │
                      │ profileId: UUID (Local Hive)│
                      │ serverProfileId: int/string │
                      │ ownerUserId: string         │
                      └─────────────────────────────┘
```

### 5.2 User ID Type Discrepancies
- **Firebase UID**: Never persisted in MediCrate Hive storage. Used only during transit.
- **Laravel User ID**: Integer (e.g. `12`), stored in `UserModel.id = "12"`, and referenced as `ProfileModel.ownerUserId = "12"`.
- **Supabase User ID**: UUID v4 (e.g. `a1d2f71e-9929-408d-ad19-e019d7699caf`).

### 5.3 Identity Mapping Proposal for Supabase
In Supabase PostgreSQL, create a `public.profiles` or `public.users` table extending `auth.users`:

```sql
CREATE TABLE public.user_accounts (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  legacy_laravel_user_id INT UNIQUE NULL,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  dob DATE NULL,
  gender TEXT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 5.4 Password Migration Limitation
> [!IMPORTANT]
> Passwords stored in Laravel's MySQL database cannot be exported or migrated to Supabase Auth because:
> 1. Passwords are one-way hashed using Laravel's `bcrypt` / `argon2` implementation.
> 2. Client-side migration cannot read existing hashes without administrative database access.
> 
> **Strategy for Existing Users**:
> - Users who signed in via **Google** will seamlessly authenticate: Supabase matches the verified Google email address automatically.
> - Users with legacy **Email/Password** accounts will use the **Password Reset / Forgot Password flow** in Supabase upon first launch, or an automated OTP verification flow to set a new password in Supabase Auth.

---

## 6. Session and Secure Storage Audit

### 6.1 Current Session Persistence Map

| Storage Layer | Key | Data Stored | Responsible Class | Lifecycle / Invalidation |
| :--- | :--- | :--- | :--- | :--- |
| **FlutterSecureStorage** | `auth_bearer_token` | Laravel Sanctum Access Token | `SecureStorageService` | Deleted on sign out, password reset, or 401 refresh failure |
| **FlutterSecureStorage** | `auth_refresh_token`| Laravel Sanctum Refresh Token | `SecureStorageService` | Deleted on sign out or 401 refresh failure |
| **Hive `user_box`** | `current_user` | `UserModel` serialized map | `AuthLocalDataSource` | Deleted on `clearSession()` |
| **Hive `user_box`** | `active_profile_id` | Active clinical profile ID string | `AuthLocalDataSource` | Reset on account switch or logout |
| **Hive `auth_box`** | `is_logged_in` | `{'isLoggedIn': bool}` | `AuthLocalDataSource` | Read on app startup before remote checks |
| **Hive `profile_box`** | `profile_id` | `ProfileModel` records | `ProfileLocalDataSource` | Preserved offline across launches |

### 6.2 Supabase Target Storage Changes
1. **Supabase Auto-Session**: `supabase_flutter` manages its own encrypted storage using `FlutterSecureStorage` under the hood. There is no need for manual token rotation logic or custom interceptors for Supabase tokens.
2. **Preventing Stale Laravel Tokens**: Upon successful migration to Supabase Auth, legacy keys (`auth_bearer_token`, `auth_refresh_token`) in `SecureStorageService` must be purged so stale credentials are never used.
3. **Hive Session Coordination**: `AuthLocalDataSource` will be adapted to reflect Supabase session presence (`supabase.auth.currentSession != null`).

---

## 7. Authentication-Dependent Feature Inventory

Every major feature in MediCrate connects to the authentication state:

| Feature / Subsystem | Current Dependency | Impact of Supabase Migration | Required Modification | Can Remain Laravel Temporarily? |
| :--- | :--- | :--- | :--- | :---: |
| **Router (`GoRouter`)** | Listens to `authControllerProvider.isAuthenticated` | High | None (remains bound to `authControllerProvider`) | N/A |
| **Splash Screen** | Awaits `authNotifier.initialSessionReady` | High | Reads `supabase.auth.currentSession` | N/A |
| **Profile Providers** | Watches `authControllerProvider.user` for `ownerUserId` | High | `ownerUserId` becomes Supabase UUID | Yes |
| **Background Sync** | Checks `authControllerProvider.isAuthenticated` before pulling | Medium | Reads Supabase session status | Yes |
| **Manual Sync** | Reads `authUser.id` to gate queue execution | Medium | Reads Supabase session status | Yes |
| **Account Drawer** | Displays `user.name`, `user.email`, and triggers `signOut()` | Medium | Consumes Supabase `User` metadata | N/A |
| **Settings / Security** | Displays auth provider; handles password change / delete | High | Uses `supabase.auth.updateUser` / RPC | No (moves to Supabase) |
| **Clinical Repositories** | Scoped to `profileId` (UUID) | Low | Independent of auth provider (relies on profile ID) | Yes |

---

## 8. Proposed Supabase Auth Architecture (Phase 3B)

The target architecture replaces Firebase Auth and Laravel Auth with pure Supabase Auth while adhering to **Riverpod 3.5.0** and the existing feature-first design:

```
[Presentation: SignIn / SignUp / OTP Screens]
                     │
                     ▼
       [AuthNotifier (Riverpod 3.5 Notifier)]
                     │
                     ▼
          [SupabaseAuthRepository]
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
[SupabaseAuthRemoteDataSource]  [AuthLocalDataSource (Hive)]
        │
        ▼
[supabase_flutter: SupabaseClient]
        │
   ┌────┴─────────────────────────┐
   ▼                              ▼
[supabase.auth.signUp/signIn]   [supabase.auth.signInWithIdToken]
(Email/Password)               (Native Google Sign-In)
```

### 8.1 Proposed Component Structure
- `lib/core/supabase/supabase_client_provider.dart`: Exposes `SupabaseClient` via Riverpod `Provider<SupabaseClient>`.
- `lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart`:
  - `signUpWithEmail(email, password, metadata)`
  - `signInWithEmail(email, password)`
  - `signInWithGoogleIdToken(idToken, rawNonce)`
  - `verifyEmailOtp(email, token)`
  - `resendEmailOtp(email)`
  - `sendPasswordResetEmail(email)`
  - `updatePassword(newPassword)`
  - `signOut()`
- `lib/features/auth/data/repositories/supabase_auth_repository.dart`: Maps Supabase `User` and `Session` to domain `UserModel` and caches in Hive.
- `lib/features/auth/presentation/providers/auth_notifier.dart`:
  - Listens to `supabase.auth.onAuthStateChange`.
  - Maintains `AuthState` (`isAuthenticated`, `isLoading`, `user`, error messages).

---

## 9. Migration Risks and Mitigation Strategy

| Risk ID | Risk Description | Severity | Mitigation Strategy |
| :--- | :--- | :---: | :--- |
| **R1** | **Password Incompatibility**: Legacy Laravel bcrypt hashes cannot be validated directly by Supabase client. | **High** | Provide password reset via Supabase email OTP. Google OAuth users are unaffected. |
| **R2** | **Duplicate User Accounts**: A user might sign up with Google on Supabase with the same email as their legacy password account. | **Medium** | Enable Supabase's automatic email linking (`enable_manual_linking = false` with identical verified email address). |
| **R3** | **Integer ID vs. UUID**: Clinical records in Hive reference `profile_id` (UUID), but `ProfileModel.ownerUserId` was an integer string (e.g. `"12"`). | **High** | Store `legacy_laravel_user_id` alongside the Supabase UUID so queries match both legacy and modern profile owners. |
| **R4** | **OTP Length Discrepancy**: Legacy Laravel OTP was 4 digits; Supabase default OTP is 6 digits. | **Medium** | Update `OtpInputRow` to support 6-digit inputs with automatic paste and auto-advance. |
| **R5** | **Offline Data Loss**: Existing Hive clinical data could be orphaned if user session is cleared without re-associating profiles. | **High** | Never delete `profile_box` or clinical records during auth migration; only refresh session credentials. |
| **R6** | **Google OAuth Fingerprint Mismatch**: Google Sign-In fails on Android if SHA-1/SHA-256 fingerprint does not match Google Console client ID. | **Medium** | Verify release and debug keystore SHA fingerprints before building release APKs. |

---

## 10. Required External Configuration

### 10.1 Supabase Dashboard Configuration (`wnaflcytkubqmrymbmcn`)
1. **Email Auth**:
   - Authentication → Providers → Email: Enable Email signup/login.
   - Confirm Email: Enable email confirmation with 6-digit OTP code (or disable email confirmation for staging).
   - Email Templates: Customize sender and subject lines for MediCrate.
2. **Google OAuth**:
   - Authentication → Providers → Google: Toggle Enabled.
   - Client ID: `574482098020-...` (Web OAuth client).
   - Client Secret: From Google Cloud Console.
   - Authorized Client IDs (skip verification): Android Client ID.

### 10.2 Google Cloud Console
1. **OAuth Consent Screen**: Set application name to "MediCrate", support email to verified address.
2. **Credentials**:
   - Web Client ID (for `serverClientId` in `google_sign_in`).
   - Android Client ID (with package name `com.example.medi_crate` or permanent `com.medicrate.app` and SHA-1).

---

## 11. Detailed Implementation Sequence for Phase 3B

Phase 3B should proceed in the following strict order:

```
Step 1: Core Supabase Client Integration
  └── Initialize Supabase.initialize in main.dart using SUPABASE_URL & SUPABASE_ANON_KEY.
  └── Create core/supabase/supabase_client_provider.dart.

Step 2: Supabase Auth Data Sources
  └── Create SupabaseAuthRemoteDataSource with email & Google signInWithIdToken methods.
  └── Adapt GoogleAuthService to pass idToken directly to Supabase instead of Firebase.

Step 3: Repository & Mapper Adaptation
  └── Implement SupabaseAuthRepository mapping Supabase User to UserModel.
  └── Adapt UserMapper and UserModel (remove FirebaseAuth.instance calls).

Step 4: UI & OTP Widget Adjustments
  └── Update OtpInputRow to 6 digits with adaptive length.
  └── Remove Apple Sign-In button from AuthSocialSignInButtons.
  └── Expand Google Sign-In button to full width.

Step 5: Riverpod State Migration
  └── Wire AuthNotifier to Supabase onAuthStateChange stream.
  └── Verify session restoration on startup and GoRouter redirect.

Step 6: Deprecate Firebase & Apple Auth Packages
  └── Remove firebase_core, firebase_auth, and sign_in_with_apple from pubspec.yaml.
  └── Delete firebase_options.dart, apple_auth_service.dart.

Step 7: Verification & Build
  └── Run flutter analyze, flutter test, and flutter build apk --debug.
```

---

## 12. Testing Strategy

### 12.1 Unit Tests
- `SupabaseAuthRemoteDataSource`: Mock `GoTrueClient` / `SupabaseClient` to test email signup, login, OTP verification, and error parsing.
- `SupabaseAuthRepository`: Test token storage, `UserModel` mapping, and Hive session persistence.
- `AuthNotifier`: Test state transitions (`isLoading`, `isAuthenticated`, `isPendingVerification`, error assignment).

### 12.2 Widget Tests
- `SignInScreen`: Verify form validation, password visibility toggle, Google Sign-In button tap.
- `SignUpScreen`: Verify required fields, DOB picker, and registration submission.
- `OtpVerificationScreen`: Verify 6-digit input entry, paste handling, and auto-submit.

### 12.3 Integration Tests
- End-to-end authentication flow against Supabase staging:
  1. Register with email/password.
  2. Verify OTP.
  3. Sign in.
  4. Restore session on cold app restart.
  5. Sign out and verify return to `/login`.

---

## 13. Unresolved Questions & Assumptions

1. **Email Confirmation in Supabase**: Does the client require mandatory email verification before login, or should accounts be immediately active? (Supabase supports both).
2. **Legacy User Password Reset Communication**: Will an email announcement or banner prompt legacy users to reset their passwords on first app launch?
3. **Laravel Coexistence vs. Clean Break**: Will the application transition completely to Supabase PostgreSQL in Phase 4 for all clinical data, or must Supabase issue tokens that a modified Laravel backend will accept during an intermediate phase?
4. **Support Email Status**: `support@medicrate.app` remains unverified until MX DNS records are confirmed by the domain administrator.

---
*End of Phase 3A Audit Document.*
