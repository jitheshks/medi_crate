# MediCrate – Phase 3B.4.1.4: Local Configuration Verification Report

**Repository:** `/home/blackhat/Documents/medi_crate`  
**Reference repository:** `/home/blackhat/Documents/Reubro/medivalut` — STRICTLY READ-ONLY  
**Supabase Project Ref:** `wnaflcytkubqmrymbmcn`  
**Supabase Project URL:** `https://wnaflcytkubqmrymbmcn.supabase.co`  
**Google Cloud Project ID:** `medicrate-b912a` (Project Number: `842207080347`)  
**Audit Date:** 2026-11-09  
**Execution Mode:** STRICTLY READ-ONLY AUDIT

---

## Executive Summary

Phase 3B.4.1.4 audited the current local workspace configuration, `.env` file, Google OAuth parameters, Supabase initialization, and email OTP template compatibility without modifying any application code, `.env`, or repository files.

### Key Audit Findings

1. **Environment Configuration Reconciled:** **PASS**. The `.env` file has been updated with the verified Web Client ID (`842207080347-...`), matching [`~/Downloads/medicrate web OAuth.json`](file:///home/blackhat/Downloads/medicrate%20web%20OAuth.json) exactly. `SUPABASE_URL` matches the MediCrate project URL, and `SUPABASE_ANON_KEY` is a valid modern `sb_publishable_` key.
2. **Google OAuth Pipeline Verified:** **PASS**. Native Google Sign-In extracts the ID token and exchanges it directly with Supabase GoTrue via `_auth.signInWithIdToken()`. Zero Firebase Auth or Laravel endpoints are active.
3. **Supabase Initialization Verified:** **PASS**. Initializes via `publishableKey` parameter in `supabase_flutter: 2.18.3`. Zero service-role keys are embedded in Flutter code. Session persistence is managed exclusively by the Supabase SDK.
4. **Email OTP Template Compatibility:** **BLOCKED / ACTION REQUIRED IN SUPABASE DASHBOARD**. The application strictly expects a **6-digit numeric OTP token** (`{{ .Token }}`) entered into [`OtpVerificationScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/otp_verification_screen.dart). The default Supabase email template provides only a clickable sign-in link (`{{ .ConfirmationURL }}`), which is **incompatible** because MediCrate does not use magic links or deep link redirect schemes.
5. **Android Manifest & Keystore Verified:** **PASS**. `<uses-permission android:name="android.permission.INTERNET"/>` is present in `android/app/src/main/AndroidManifest.xml`. Package ID is `com.example.medi_crate` and matches the Android OAuth client registered in Google Cloud project `842207080347`.
6. **Quality Gate:** `flutter analyze` reports 0 issues. All 28 auth regression and UI tests pass cleanly.

---

## 1. Git Baseline and Working-Tree Status

| Parameter | Recorded Value | Status | Notes |
|---|---|---|---|
| Active Branch | `master` | **PASS** | Default production branch |
| HEAD Commit Hash | `d25d6ada15530572965d21bf9e6cd06fac9aac11` | **PASS** | Baseline commit match |
| Modified Files (Unstaged) | `android/app/src/main/AndroidManifest.xml` | **PASS** | Single line addition: `android.permission.INTERNET` |
| Untracked Report Files | 5 previous Phase 3B.4.x reports | **PASS** | Documentation reports preserved |
| Reference Project (`medivalut`) | Strictly read-only | **PASS** | Untouched (0 modifications in session) |

---

## 2. Environment Configuration Validation

The local `.env` file was inspected using non-destructive structural validation without revealing secret values:

| Variable | Expected Value / Format | Actual Value in `.env` (Masked) | Validation Result | Status |
|---|---|---|---|---|
| `SUPABASE_URL` | `https://wnaflcytkubqmrymbmcn.supabase.co` | `https://wnaflcytkubqmrymbmcn.supabase.co` | Exact match (40 chars) | **PASS** |
| `SUPABASE_ANON_KEY` | Modern publishable key (`sb_publishable_...`) | `sb_publishable_...` (Length: 46 chars, 0 dots) | Valid modern publishable key | **PASS** |
| `GOOGLE_WEB_CLIENT_ID` | `842207080347-...apps.googleusercontent.com` | `842207080347-...apps.googleusercontent.com` | Exact match to `medicrate web OAuth.json` | **PASS** |
| Git Ignore Check | `.env` ignored | `.gitignore:51:.env` | Confirmed by `git check-ignore -v .env` | **PASS** |

### Web OAuth JSON Cross-Verification (`~/Downloads/medicrate web OAuth.json`)
- `web.project_id`: `medicrate-b912a` (**PASS**).
- `web.client_id` prefix: `842207080347` (**PASS**).
- `web.redirect_uris`: `['https://wnaflcytkubqmrymbmcn.supabase.co/auth/v1/callback']` (**PASS**).
- `web.client_secret`: Present (length 35 characters, non-empty) (**PASS**).
- **Exact Match:** The value of `GOOGLE_WEB_CLIENT_ID` in `.env` now matches the official MediCrate Web Client ID from `medicrate web OAuth.json` character-for-character.

---

## 3. Google Authentication Implementation Audit

Trace of production source code:

1. **Initialization with Verified Web Client ID:**
   [`lib/main.dart:24-34`](file:///home/blackhat/Documents/medi_crate/lib/main.dart#L24-L34) reads `GOOGLE_WEB_CLIENT_ID` from `.env` and passes it to `GoogleAuthService.initialize(serverClientId: googleClientId)`.
   [`lib/features/auth/data/services/google_auth_service.dart:79`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/services/google_auth_service.dart#L79) initializes `GoogleSignIn.instance.initialize(serverClientId: resolved)`.
2. **Native ID Token Extraction:**
   [`lib/features/auth/data/services/google_auth_service.dart:117-138`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/services/google_auth_service.dart#L117-L138) invokes `account = await googleSignIn.authenticate()` and extracts `account.authentication.idToken`.
3. **Direct Supabase Exchange:**
   [`lib/features/auth/presentation/providers/auth_notifier.dart:409`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/providers/auth_notifier.dart#L409) → [`lib/features/auth/data/repositories/auth_repository.dart:269`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/repositories/auth_repository.dart#L269) → [`lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart:244-247`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart#L244-L247):
   ```dart
   final response = await _auth.signInWithIdToken(
     provider: sb.OAuthProvider.google,
     idToken: idToken,
   );
   ```
4. **Firebase Independence:**
   Zero `Firebase.initializeApp` calls. Zero `FirebaseAuth` calls during Google Sign-In. Zero `google-services.json` files in the repository.
5. **Laravel Independence:**
   Zero calls to legacy Laravel endpoint `/auth/google`.

**Finding:** **PASS**

---

## 4. Supabase Initialization Audit

1. **Client Initialization Parameter:**
   [`lib/core/supabase/supabase_config.dart:107-111`](file:///home/blackhat/Documents/medi_crate/lib/core/supabase/supabase_config.dart#L107-L111) initializes Supabase via:
   ```dart
   await Supabase.initialize(
     url: config.url,
     publishableKey: config.anonKey,
   );
   ```
   Uses `publishableKey` in `supabase_flutter: 2.18.3`, correctly supporting modern `sb_publishable_` keys.
2. **No Embedded Service-Role Key:**
   Full workspace search confirms zero references to service-role secret keys.
3. **Session Persistence:**
   Supabase SDK manages GoTrue session storage internally. Refresh is handled via `_client.auth.refreshSession()`.
4. **No Token Duplication:**
   Hive stores only user profile metadata (`UserModel`) and `isLoggedIn: true`. `SecureStorageService` is never populated with Supabase JWTs.

**Finding:** **PASS**

---

## 5. Email Authentication and OTP Compatibility Audit

### 5.1 Exact Supabase API Calls & Methods

| Auth Flow | Screen | Repository / DataSource Method | Supabase SDK API Call | Parameters |
|---|---|---|---|---|
| **Email Signup** | `SignUpScreen` | `supabaseRemoteDataSource.signUp` | `_auth.signUp(...)` | `email`, `password`, `data: {'full_name': ..., 'dob': ..., 'gender': ...}` |
| **Email OTP Verification** | `OtpVerificationScreen` | `supabaseRemoteDataSource.verifyEmail` | `_auth.verifyOTP(...)` | `email: email, token: otp, type: OtpType.signup` |
| **Email Login** | `SignInScreen` | `supabaseRemoteDataSource.login` | `_auth.signInWithPassword(...)` | `email: email, password: password` |
| **Unconfirmed Email Catch** | `SignInScreen` | Handled on AuthException | `_auth.resend(...)` | `type: OtpType.signup, email: email` |
| **Forgot Password** | `ForgotPasswordScreen` | `supabaseRemoteDataSource.forgotPassword` | `_auth.resetPasswordForEmail(...)` | `email: email` |
| **Recovery OTP & Password Reset** | `OtpVerificationScreen` → `ResetPasswordScreen` | `supabaseRemoteDataSource.resetPassword` | 1. `_auth.verifyOTP(...)`<br>2. `_auth.updateUser(...)`<br>3. `_auth.signOut()` | 1. `email, token: otp, type: OtpType.recovery`<br>2. `UserAttributes(password: newPassword)` |

---

### 5.2 Critical Template Compatibility Analysis

> [!IMPORTANT]
> **Delivery Expectation Conflict:**  
> The application code strictly expects a **numeric 6-digit OTP code** that the user reads from their email and manually enters into the 6 input boxes of [`OtpVerificationScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/otp_verification_screen.dart).

1. **App Verification Strategy:**
   - When registration or password recovery completes, GoRouter navigates immediately to [`OtpVerificationScreen`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/screens/otp_verification_screen.dart).
   - The screen renders an [`OtpInputRow`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/widgets/otp_input_row.dart) with 6 individual digit fields.
   - On submitting, it calls `_auth.verifyOTP(token: code)`.
   - The app has **NO** magic link deep-link handler, intent filters, or URL scheme listeners in `AndroidManifest.xml`.
2. **Default Supabase Template Content:**
   - The default Supabase "Confirm signup" and "Reset password" templates contain:
     ```html
     <h2>Confirm your signup</h2>
     <p>Follow this link to confirm your user:</p>
     <p><a href="{{ .ConfirmationURL }}">Confirm your mail</a></p>
     ```
   - This delivers a clickable web link (`{{ .ConfirmationURL }}`), **NOT a standalone 6-digit numeric token**.
   - If a user receives the default email, there is no 6-digit code for them to type into the app. Clicking the link on mobile opens an external browser to the Supabase verification URL rather than returning the user to MediCrate.
3. **Template Compatibility Verdict:**
   - The default Supabase email template is **INCOMPATIBLE** with MediCrate's in-app 6-digit OTP flow.
4. **Required Template Configuration in Supabase Dashboard:**
   In Supabase Dashboard → **Authentication** → **Email Templates**:
   - **Confirm signup template:** Replace `{{ .ConfirmationURL }}` or add:
     ```html
     <h2>Confirm your signup</h2>
     <p>Your 6-digit verification code is:</p>
     <h1 style="letter-spacing: 4px;">{{ .Token }}</h1>
     ```
   - **Reset password template:** Add `{{ .Token }}`:
     ```html
     <h2>Reset your password</h2>
     <p>Your 6-digit password reset code is:</p>
     <h1 style="letter-spacing: 4px;">{{ .Token }}</h1>
     ```
5. **SMTP Requirement:**
   - Custom SMTP is **NOT** strictly required merely to edit templates. Supabase allows editing templates on the built-in email service.
   - However, Supabase's built-in email service has strict rate limits (typically 30 emails/hour). For production, custom SMTP (Resend, SendGrid, Amazon SES) is recommended.

**Finding:** **BLOCKED** until templates in Supabase Dashboard are updated to include `{{ .Token }}`.

---

## 6. Android Configuration Verification

| Item | Location | Verified Value | Status |
|---|---|---|---|
| `INTERNET` Permission | [`android/app/src/main/AndroidManifest.xml:2`](file:///home/blackhat/Documents/medi_crate/android/app/src/main/AndroidManifest.xml#L2) | `<uses-permission android:name="android.permission.INTERNET"/>` | **PASS** |
| Android Package ID | [`android/app/build.gradle.kts:20`](file:///home/blackhat/Documents/medi_crate/android/app/build.gradle.kts#L20) | `com.example.medi_crate` | **PASS** |
| Android OAuth Client | [`~/Downloads/MediCrate android OAuth.json`](file:///home/blackhat/Downloads/MediCrate%20android%20OAuth.json) | Package: `com.example.medi_crate`, Project: `842207080347` | **PASS** |
| Debug Keystore SHA-1 | `~/.android/debug.keystore` | `F6:01:AE:27:B3:71:46:2D:FD:D8:09:1A:96:42:15:BA:BE:16:CF:D1` | **PASS** |

**Finding:** **PASS**

---

## 7. Quality Checks

- **Static Analysis:**
  ```bash
  $ flutter analyze
  Analyzing medi_crate...
  No issues found! (ran in 6.3s)
  ```
  Result: **0 issues across 496 files**.
- **Auth Regression & UI Test Suites:**
  ```bash
  $ flutter test test/features/auth/auth_regression_verification_test.dart test/features/auth/auth_ui_refinement_test.dart
  00:02 +28: All tests passed!
  ```
  Result: **28/28 tests passed**.
- **APK Build Policy:** No APK build was executed (strictly adhering to guidelines).

---

## 8. Blockers & Recommended Next Steps

### Current Status Summary

| Area | Status | Notes |
|---|---|---|
| Git Working Tree | **PASS** | Baseline matched, no stray modifications |
| Local `.env` Credentials | **PASS** | Valid `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `GOOGLE_WEB_CLIENT_ID` matching project `842207080347` |
| Google OAuth Code Pipeline | **PASS** | Native Google Sign-In with direct Supabase GoTrue exchange |
| Supabase SDK Initialization | **PASS** | Initialized via `publishableKey` in `supabase_flutter: 2.18.3` |
| Android Manifest & Keystore | **PASS** | INTERNET permission present, debug SHA-1 confirmed |
| **Email Template Compatibility** | **BLOCKED** | Supabase email template must deliver `{{ .Token }}` instead of `{{ .ConfirmationURL }}` |
| **Supabase Google Provider** | **NOT VERIFIED** | Must be confirmed enabled in Supabase Dashboard with Web Client ID + Secret |
| **Device Connection** | **NOT VERIFIED** | ADB connection required before live smoke test |

---

### Exact Next Steps Before Runtime Testing

1. **Update Supabase Email Templates in Dashboard:**
   - Open [Supabase Dashboard → Authentication → Email Templates](https://supabase.com/dashboard/project/wnaflcytkubqmrymbmcn/auth/templates).
   - In **Confirm signup**, ensure the email body contains `{{ .Token }}`.
   - In **Reset password**, ensure the email body contains `{{ .Token }}`.
2. **Confirm Google Provider in Supabase Dashboard:**
   - In **Authentication** → **Providers** → **Google**:
     - Toggle **ON**.
     - Client ID: `842207080347-ne5...apps.googleusercontent.com`
     - Client Secret: Copied from `medicrate web OAuth.json`.
     - Authorized Client IDs: `842207080347-iua...apps.googleusercontent.com`.
3. **Connect Android Device:**
   - Connect physical phone via USB (with USB debugging enabled) or start `Pixel_8a` emulator:
     ```bash
     adb devices -l
     ```
4. **Proceed to Live Smoke Testing (Phase 3B.4.2).**

---
*Report generated in strictly READ-ONLY mode. No files were modified, staged, committed, or pushed.*
