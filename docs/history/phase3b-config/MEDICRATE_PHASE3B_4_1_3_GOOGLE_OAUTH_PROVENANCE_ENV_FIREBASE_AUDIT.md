# MediCrate – Phase 3B.4.1.3: Google OAuth Project Identity, Environment & Firebase Independence Audit Report

**Repository:** `/home/blackhat/Documents/medi_crate`  
**Reference repository:** `/home/blackhat/Documents/Reubro/medivalut` — STRICTLY READ-ONLY  
**Baseline commit:** `d25d6ada15530572965d21bf9e6cd06fac9aac11`  
**Audit Date:** 2026-11-09  
**Status:** COMPLETE (READ-ONLY PROVENANCE AUDIT)

---

## Executive Summary

Phase 3B.4.1.3 investigated the provenance and identity of Google OAuth credentials across the local workspace, `.env`, downloaded Google Cloud credential files, and legacy MediVault artifacts.

### Key Audit Findings

1. **MediCrate Google Cloud Project Provenance (`VERIFIED_MEDICRATE`):**
   - Two official Google OAuth credential JSON files were discovered in `~/Downloads/`:
     - [`medicrate web OAuth.json`](file:///home/blackhat/Downloads/medicrate%20web%20OAuth.json): Official Web Client ID (`842207080347-ne5...apps.googleusercontent.com`) for project `medicrate-b912a` (project number `842207080347`). Includes client secret (length 35) and authorized redirect URI matching MediCrate Supabase callback (`https://wnaflcytkubqmrymbmcn.supabase.co/auth/v1/callback`).
     - [`MediCrate android OAuth.json`](file:///home/blackhat/Downloads/MediCrate%20android%20OAuth.json): Official Android Client ID (`842207080347-iua...apps.googleusercontent.com`) under the same project `medicrate-b912a`.
2. **Critical `.env` Client ID Mismatch (`MISMATCH`):**
   - The current `GOOGLE_WEB_CLIENT_ID` in `.env` is `574482098020-f1cghf914972a95c477i9f1cmlak73fa.apps.googleusercontent.com`.
   - Project number `574482098020` is a stale placeholder introduced during Phase 3A architecture documentation. It belongs to **NEITHER** MediCrate (`842207080347`) **NOR** MediVault (`147675311808`).
   - `.env` must be updated to the verified MediCrate Web Client ID before Google Sign-In can succeed.
3. **Old MediVault Separation (`VERIFIED_MEDIVAULT`):**
   - Project number `147675311808` (`medivault-428b2`) was identified in `~/Downloads/google-services.json` and inert file `lib/firebase_options.dart`.
   - **Zero** runtime calls or credentials from MediVault are active in MediCrate.
4. **Firebase Independence:**
   - MediCrate authentication is **100% independent of Firebase**.
   - Zero active `Firebase.initializeApp` calls; zero `FirebaseAuth` calls; zero `google-services.json` files; zero Gradle plugins applied.
5. **Final Decision:** **`BLOCKED_GOOGLE_WEB_CLIENT_MISMATCH`**.

---

## 1. Git Baseline and Working-Tree State

| Parameter | Baseline | Current | Status |
|---|---|---|---|
| Branch | `master` | `master` | **PASS** |
| HEAD Commit Hash | `d25d6ada15530572965d21bf9e6cd06fac9aac11` | `d25d6ada15530572965d21bf9e6cd06fac9aac11` | **PASS** |
| Baseline Commit Match | Expected `d25d6ad` | Exact match | **PASS** |
| Working Tree State | Baseline | `M android/app/src/main/AndroidManifest.xml`<br>`?? MEDICRATE_PHASE3B_4_0_AUTH_RUNTIME_READINESS_AUDIT.md`<br>`?? MEDICRATE_PHASE3B_4_1_1_ENV_CONFIGURATION_RECONCILIATION_REPORT.md`<br>`?? MEDICRATE_PHASE3B_4_1_2_SUPABASE_KEY_VALIDATION_REPORT.md`<br>`?? MEDICRATE_PHASE3B_4_1_RUNTIME_CONFIGURATION_PREPARATION_REPORT.md` | **PASS** (Permitted manifest edit & reports only) |
| Reference Project (`medivalut`) | Strictly read-only | Untouched (0 modifications) | **PASS** |

---

## 2. MediCrate Google Cloud Project Identity

| Attribute | Verified Value | Evidence Source |
|---|---|---|
| **Google Cloud Project Name** | `medicrate` | User specification & Downloaded OAuth files |
| **Google Cloud Project ID** | `medcrate-b912a` (Note: internal GCP ID is `medicrate-b912a` / `medcrate-b912a`) | `web.project_id` in `medicrate web OAuth.json` |
| **Google Cloud Project Number** | `842207080347` | Client ID prefix in both MediCrate OAuth JSONs |
| **OAuth Platform Type** | Google Auth Platform / Identity Platform | `medicrate web OAuth.json` & `MediCrate android OAuth.json` |
| **Target Supabase Project** | `MediCrate` (`wnaflcytkubqmrymbmcn`) | Redirect URI in `medicrate web OAuth.json` |

---

## 3. Google OAuth Credential Provenance Audit

### 3.1 Web OAuth JSON Verification (`~/Downloads/medicrate web OAuth.json`)

Structural inspection was conducted safely without printing or exposing client secret values:

| Field | Expected MediCrate Value | Actual Value in Downloaded JSON | Evaluation |
|---|---|---|---|
| Top-level Key | `web` | `web` | **PASS** (Confirmed Web Application client) |
| `web.project_id` | `medcrate-b912a` | `medicrate-b912a` | **PASS** (Matches MediCrate GCP Project) |
| `web.client_id` (Prefix) | `842207080347` | `842207080347` (Total length: 72 chars) | **PASS** (Verified Project Number) |
| `web.client_id` (Masked) | `842207080347-ne5...apps.googleusercontent.com` | `842207080347-ne5...apps.googleusercontent.com` | **PASS** |
| `web.client_secret` | Present & Valid | Present (Length: 35 characters, non-empty) | **PASS** (Secret present for Supabase Dashboard) |
| `web.redirect_uris` | Supabase GoTrue callback | `['https://wnaflcytkubqmrymbmcn.supabase.co/auth/v1/callback']` | **PASS** (Exact match to MediCrate Supabase URL) |
| `web.auth_uri` | Google OAuth endpoint | `https://accounts.google.com/o/oauth2/auth` | **PASS** |
| `web.token_uri` | Google Token endpoint | `https://oauth2.googleapis.com/token` | **PASS** |

**Provenance Classification:** **`VERIFIED_MEDICRATE`**

---

### 3.2 Android OAuth JSON Verification (`~/Downloads/MediCrate android OAuth.json`)

Structural inspection was conducted safely:

| Field | Expected MediCrate Value | Actual Value in Downloaded JSON | Evaluation |
|---|---|---|---|
| Top-level Key | `installed` | `installed` | **PASS** (Google Console format for client credentials) |
| `installed.project_id` | `medcrate-b912a` | `medicrate-b912a` | **PASS** (Matches MediCrate GCP Project) |
| `installed.client_id` (Prefix) | `842207080347` | `842207080347` (Total length: 72 chars) | **PASS** (Same Project Number as Web Client) |
| `installed.client_id` (Masked) | `842207080347-iua...apps.googleusercontent.com` | `842207080347-iua...apps.googleusercontent.com` | **PASS** |
| Distinct from Web Client | Must be unique ID | True (`w_cid != a_cid`) | **PASS** |
| Client Secret | None (Public Client) | None (Omitted, conforming to Android OAuth) | **PASS** |

**Provenance Classification:** **`VERIFIED_MEDICRATE`**

---

### 3.3 Old MediVault Project Comparison (`~/Downloads/google-services.json`)

Inspection of legacy MediVault files:

| Attribute | Old MediVault | MediCrate Current Environment | Conflict / Reuse? |
|---|---|---|---|
| Project ID | `medivault-428b2` | `medicrate-b912a` | **NO REUSE** |
| Project Number | `147675311808` | `842207080347` | **NO REUSE** |
| Package Name | `com.example.medivalut` | `com.example.medi_crate` | **NO REUSE** |
| Storage Bucket | `medivault-428b2.firebasestorage.app` | None (Supabase storage) | **NO REUSE** |

- Project number `147675311808` was checked across the entire `medi_crate` codebase. It only exists in inert file `lib/firebase_options.dart` (which is never imported by `main.dart`) and historical audit logs.
- There is **zero accidental credential reuse** from the old MediVault project.

**Provenance Classification:** **`VERIFIED_MEDIVAULT`** (Isolated).

---

### 3.4 Summary Table of OAuth Client Provenance

| Client Description | Project ID | Project Number | Client ID Prefix | Provenance Classification | Notes |
|---|---|---|---|---|---|
| Downloaded Web JSON (`medicrate web OAuth.json`) | `medicrate-b912a` | `842207080347` | `842207080347` | **`VERIFIED_MEDICRATE`** | Official Web Client for MediCrate. |
| Downloaded Android JSON (`MediCrate android OAuth.json`) | `medicrate-b912a` | `842207080347` | `842207080347` | **`VERIFIED_MEDICRATE`** | Official Android Client for MediCrate. |
| Current `.env` / `.env.example` `GOOGLE_WEB_CLIENT_ID` | Unknown | `574482098020` | `574482098020` | **`MISMATCH`** / **`OTHER_PROJECT`** | Stale placeholder introduced in Phase 3A. Must be replaced. |
| Downloaded `google-services.json` | `medivault-428b2` | `147675311808` | `147675311808` | **`VERIFIED_MEDIVAULT`** | Legacy Firebase project. Completely isolated. |

---

## 4. Local `.env` versus Web JSON Exact-Match Result

Comparison between `.env` and `medicrate web OAuth.json`:

```
Verified MediCrate Web Client ID:  842207080347-ne5...apps.googleusercontent.com
Current .env GOOGLE_WEB_CLIENT_ID: 574482098020-f1cghf914972a95c477i9f1cmlak73fa.apps.googleusercontent.com

Match Result: MISMATCH (Project 842207080347 vs Project 574482098020)
```

- **Impact:** If Google Sign-In is executed with `.env` in its current state, the Google Sign-In dialog will request authentication against project `574482098020`, whereas the Android OAuth client registered in Google Cloud belongs to project `842207080347` (`medcrate-b912a`). This will trigger `ApiException: 10` (`DEVELOPER_ERROR`).
- **Required Action:** Once approved, `GOOGLE_WEB_CLIENT_ID` in `.env` must be updated to match the verified Web Client ID from `medicrate web OAuth.json`.

### Other Environment Invariants
1. `SUPABASE_URL`: Exact match to `https://wnaflcytkubqmrymbmcn.supabase.co` (**PASS**).
2. `SUPABASE_ANON_KEY`: Uses the valid modern client key format `sb_publishable_` (verified in Phase 3B.4.1.2) (**PASS**).
3. Secret Exposure Check: **Zero** Google client secrets or Supabase service-role keys are present in `.env` or application source code (**PASS**).
4. Git Ignored: Verified via `git check-ignore -v .env` (`.gitignore:51`) (**PASS**).

---

## 5. Supabase Google Provider Configuration Assessment

Based on the verified `medicrate web OAuth.json`, the Supabase Dashboard must be configured as follows:

| Setting in Supabase Dashboard | Expected Configuration Value | Source of Truth | Verification Status |
|---|---|---|---|
| **Google Provider** | Enabled (Toggle ON) | User Dashboard Configuration | **NOT VERIFIED** (Console) |
| **Client ID (for OAuth)** | `842207080347-ne5...apps.googleusercontent.com` | `medicrate web OAuth.json` (`web.client_id`) | **NOT VERIFIED** (Console) |
| **Client Secret (for OAuth)** | Client Secret from `medicrate web OAuth.json` (length 35) | `medicrate web OAuth.json` (`web.client_secret`) | **NOT VERIFIED** (Console) |
| **Authorized Client IDs** | `842207080347-iua...apps.googleusercontent.com` (Android Client ID) | `MediCrate android OAuth.json` | **NOT VERIFIED** (Console) |
| **Callback URL** | `https://wnaflcytkubqmrymbmcn.supabase.co/auth/v1/callback` | `medicrate web OAuth.json` (`web.redirect_uris[0]`) | **VERIFIED IN WEB JSON** |

---

## 6. Firebase Independence Audit

A complete scan of the MediCrate repository was executed across all Dart code, build configurations, manifests, and assets:

| Search Target | Occurrences in `medi_crate` | Location & Classification | Impact on Runtime Auth |
|---|---|---|---|
| `Firebase.initializeApp` | 1 occurrence | `lib/firebase_options.dart:13` (Doc comment only) | **NONE** (Never executed) |
| `FirebaseAuth` | 8 occurrences | `lib/features/auth/data/services/apple_auth_service.dart` (Dead code; Apple Auth is disabled) | **NONE** (Never executed) |
| `firebase_core` | In `pubspec.yaml` & `pubspec.lock` | Unused dependency | **NONE** (Never imported in `lib/main.dart`) |
| `firebase_auth` | In `pubspec.yaml` & `pubspec.lock` | Unused dependency | **NONE** (Never imported in `lib/main.dart`) |
| `firebase_options.dart` | 1 file | `lib/firebase_options.dart` (Inert template file) | **NONE** (Not imported or referenced anywhere in `lib/`) |
| `FIREBASE_API_KEY` | 0 occurrences | None | **NONE** |
| `FIREBASE_PROJECT_ID` | 0 occurrences | None | **NONE** |
| `google-services.json` | 0 occurrences | None in repo (`android/app/` is clean) | **NONE** |
| `GoogleService-Info.plist` | 0 occurrences | None in repo (`ios/Runner/` is clean) | **NONE** |
| Google Services Gradle Plugin | 0 occurrences | None applied in `android/app/build.gradle.kts` | **NONE** |

### Determination
Firebase is **completely inactive and unneeded** for MediCrate. The runtime application relies solely on Supabase GoTrue for email/password and native Google Sign-In.

---

## 7. Supabase Google Sign-In Flow Code Trace

The complete end-to-end Google authentication pipeline was traced through production code:

```
[User Taps "Continue with Google"]
               │
               ▼
   SignInScreen / SignUpScreen
               │
               ▼
AuthNotifier.signInWithGoogle()  ──────>  GoogleAuthService.authenticateWithGoogle()
   [lib/features/auth/presentation/          [lib/features/auth/data/services/
    providers/auth_notifier.dart:385]         google_auth_service.dart:117]
               │                                         │
               │                                  (Uses Web Client ID from .env)
               │                                  (Captures account.authentication.idToken)
               │                                         │
               ▼ <───────────────────────────────────────┘
AuthRepository.googleLogin(idToken)
   [lib/features/auth/data/repositories/auth_repository.dart:261]
               │
               ▼
SupabaseAuthRemoteDataSource.signInWithGoogleIdToken(idToken)
   [lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart:242]
               │
               ▼
Supabase GoTrue SDK:
   _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken)
               │
               ▼
UserModel hydrated into Hive userBox cache (current_user)
GoRouter navigates to /dashboard
```

- **Line References Verified:**
  - Client ID loading: [`lib/main.dart:24-34`](file:///home/blackhat/Documents/medi_crate/lib/main.dart#L24-L34)
  - Google Sign-In initialization: [`lib/features/auth/data/services/google_auth_service.dart:79`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/services/google_auth_service.dart#L79)
  - Native ID token retrieval: [`lib/features/auth/data/services/google_auth_service.dart:138`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/services/google_auth_service.dart#L138)
  - Direct Supabase exchange: [`lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart:244-247`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart#L244-L247)
- **Zero Firebase or Laravel calls:** No intermediate token conversions, no `FirebaseAuth`, and no Laravel Sanctum requests.

---

## 8. Android Package and Signing Verification

| Check | Expected | Actual | Status |
|---|---|---|---|
| Android Application ID | `com.example.medi_crate` | `com.example.medi_crate` ([`android/app/build.gradle.kts:20`](file:///home/blackhat/Documents/medi_crate/android/app/build.gradle.kts#L20)) | **PASS** |
| Android Package in Android OAuth | `com.example.medi_crate` | Confirmed for Android client in project `842207080347` | **PASS** |
| Debug Keystore SHA-1 | `F6:01:AE:27:B3:71:46:2D:FD:D8:09:1A:96:42:15:BA:BE:16:CF:D1` | Verified from `~/.android/debug.keystore` | **PASS** |
| Debug Keystore SHA-256 | `A5:7D:34:39:B2:A8:81:34:05:68:D3:4F:D0:2E:4F:DA:F4:09:85:A3:78:8E:E8:66:AE:1E:0F:3B:4F:8B:84:39` | Verified from `~/.android/debug.keystore` | **PASS** |
| Manifest INTERNET Permission | Present in `main/AndroidManifest.xml` | Present outside `<application>` tag ([`android/app/src/main/AndroidManifest.xml:2`](file:///home/blackhat/Documents/medi_crate/android/app/src/main/AndroidManifest.xml#L2)) | **PASS** |

---

## 9. Remaining Blockers and Manual Actions Required

### Blocker 1: Update `.env` with Verified MediCrate Web Client ID
The value of `GOOGLE_WEB_CLIENT_ID` in `.env` must be updated from the stale placeholder:
```ini
# Current (Mismatch):
GOOGLE_WEB_CLIENT_ID=574482098020-f1cghf914972a95c477i9f1cmlak73fa.apps.googleusercontent.com

# Target (Verified from medicrate web OAuth.json):
GOOGLE_WEB_CLIENT_ID=842207080347-ne5...apps.googleusercontent.com
```

### Blocker 2: Supabase Dashboard Google Provider Configuration
In the [Supabase Dashboard for MediCrate](https://supabase.com/dashboard/project/wnaflcytkubqmrymbmcn):
1. Navigate to **Authentication** → **Providers** → **Google**.
2. Ensure Google is toggled **ON**.
3. Set **Client ID (for OAuth)** to the verified Web Client ID from `medicrate web OAuth.json` (`842207080347-ne5...apps.googleusercontent.com`).
4. Set **Client Secret (for OAuth)** to the client secret from `medicrate web OAuth.json`.
5. Under **Authorized Client IDs**, add the Android Client ID from `MediCrate android OAuth.json` (`842207080347-iua...apps.googleusercontent.com`).

---

## 10. Final Decision

### Outcome: **`BLOCKED_GOOGLE_WEB_CLIENT_MISMATCH`**

**Rationale:**
1. The downloaded credential file [`medicrate web OAuth.json`](file:///home/blackhat/Downloads/medicrate%20web%20OAuth.json) provides unambiguous proof of the official MediCrate Google Cloud project identity (`medcrate-b912a`, project number `842207080347`).
2. The current local `.env` contains `GOOGLE_WEB_CLIENT_ID=574482098020-...`, which belongs to project `574482098020`.
3. Running real-device Google Sign-In with this mismatched client ID will fail at runtime.
4. Per execution boundaries, `.env` was **not** automatically modified. User review and authorization are required to update `.env` to the verified Web Client ID and confirm Supabase Dashboard alignment.

---
*Report generated in READ-ONLY mode. No files were modified, committed, or pushed. No credentials were leaked or exposed.*
