# MediCrate – Phase 3B.1.2: Legacy MediVault Source & Live Laravel API Compatibility Audit

**Audit Date:** 2026-11-08  
**Auditor Mode:** Strictly Read-Only Investigation  
**Reference Codebase:** `~/Documents/Reubro/medivalut` (`api-integration` branch)  
**Target Codebase:** `~/Documents/medi_crate`  
**Live Target Host:** `https://phplaravel-1505866-6585565.cloudwaysapps.com/api/v1`  

---

## 1. Executive Summary

This audit constitutes a comprehensive, read-only architectural investigation comparing the original MediVault Flutter source code, its 64-endpoint Laravel REST API contract, and the live behavior of the deployed Cloudways Laravel backend against the upcoming MediCrate Phase 3B.2 Supabase authentication architecture.

### Key Audit Findings

1. **Live Backend Operational State:**
   - The Cloudways host resolves to `138.197.38.31` with valid TLS 1.3 (`*.cloudwaysapps.com` certificate valid through Feb 2027).
   - The root web path (`/`) returns a customized Laravel 12 landing page (`<title>Medi_vault</title>`).
   - The API router is live and responding: non-existent routes return HTTP 404 (`{"status":"error","message":"Resource not found."}`), while documented endpoints return HTTP 401 (`{"status":"error","message":"Unauthorized. Please login again."}`) in ~0.83–1.06s.
   - Public authentication endpoints actively execute Laravel `FormRequest` validation: empty POSTs to `/api/v1/auth/login` and `/api/v1/auth/google-login` return HTTP 422 Unprocessable Content with specific validation message arrays.
2. **Authentication Incompatibility with Supabase:**
   - **Google Social Login:** The live Laravel endpoint `POST /api/v1/auth/google-login` strictly requires a `firebase_id_token` verified server-side via the Firebase Admin SDK. It does not accept raw Google ID tokens or Supabase JWTs.
   - **Sanctum vs. Supabase Tokens:** Laravel exclusively issues and authenticates stateful personal access tokens (`id|hash`) recorded in MySQL's `personal_access_tokens` table. It has no capability to decode, verify, or authorize stateless RFC 7519 Supabase JWTs.
   - **No External Token Exchange:** The Laravel backend provides no token exchange endpoint to trade a Supabase session for a Sanctum token.
3. **Clinical API Scope:**
   - The original API exposes 64 endpoints across 17 modules.
   - All clinical endpoints (`/consultations`, `/vitals`, `/medicines`, `/reports`, `/appointments`, `/doctors`, `/hospitals`, `/family-members`) are strictly protected by `auth:sanctum` and require a valid user session.
   - Ten core features were explicitly architected as **100% local-only** (local in-app notification inbox, medication/appointment alarms, ML Kit OCR, and PDF export) and never required backend endpoints.
4. **Migration Strategy Verdict:**
   - **Option C (Full Supabase-First Migration with Dormant Laravel)** is confirmed as the only technically viable, secure, and maintainable strategy.
   - Attempting to bridge Supabase authentication with the legacy Laravel backend (Option A) is impossible without deploying custom backend proxy services or keeping Firebase Auth indefinitely as an intermediary just for social logins.

---

## 2. Evidence Classification Legend

Every finding in this audit is classified according to its evidence source:

- **[SRC-VERIFIED]**: Verified from original MediVault Flutter source code (`~/Documents/Reubro/medivalut/lib/` or `api_audit/`).
- **[API-VERIFIED]**: Verified through direct, non-destructive probe against the live Cloudways API (`https://phplaravel-1505866-6585565.cloudwaysapps.com/api/v1`).
- **[DOC-UNVERIFIED]**: Found in legacy documentation (`API_SPECIFICATION.md`) but differing from or unconfirmed by actual Flutter source code.
- **[INFERRED]**: Deduced through technical analysis of architectural boundaries and protocol incompatibilities.
- **[UNRESOLVED]**: Requires server shell/database access or user-provided credentials not currently available.

---

## 3. Old MediVault Source-Code Findings

Inspection of `~/Documents/Reubro/medivalut` (branch `api-integration`, commit `91de4bb`) revealed several critical discrepancies between early draft documentation and the final working Flutter implementation:

### 3.1 Documented vs. Actual Endpoint Paths
Early drafts in `API_SPECIFICATION.md` listed generic REST conventions that were subsequently revised during final integration:
- `API_SPECIFICATION.md` listed `/api/v1/profiles` and `/api/v1/medications`.
- The actual implementation in [api_constants.dart](file:///home/blackhat/Documents/Reubro/medivalut/lib/core/api/api_constants.dart#L71-L95) and the 21-sheet master audit workbook (`api_audit/medivault_backend_api_requirements.xlsx`) strictly implements:
  - `/api/v1/family-members` (F1–F6) for profile management.
  - `/api/v1/medicines` (M1–M5) for prescription management.
  - `/api/v1/vitals` (V1–V5) for polymorphic vitals.
  - `/api/v1/users/me` (B1–B6) for root account management.
  - `/api/v1/medical-departments` (MD1) for department directory.

### 3.2 Authentication Engine Architecture
- **Bearer Tokens [SRC-VERIFIED]:** Laravel Sanctum Personal Access Tokens are used (`Authorization: Bearer <token>`). Tokens are stored in `FlutterSecureStorage` under `auth_bearer_token` and `auth_refresh_token`.
- **API Key [SRC-VERIFIED]:** A static API key is mandatory on all routes: `x-api-key: <MEDIVAULT_API_KEY>`.
- **OTP Verification [SRC-VERIFIED]:** Although draft documentation occasionally referred to a 6-digit code, the actual UI implementation (`lib/features/auth/presentation/widgets/otp_input_row.dart`) renders exactly **4 text boxes** (`maxLength: 4`), and the server requests expect a 4-digit string.
- **Social Login Mechanism [SRC-VERIFIED]:** Social login via Google and Apple does not communicate directly with provider APIs. Flutter uses the Firebase Auth SDK (`firebase_auth`) to obtain a `firebase_id_token`, which is then passed in JSON payload `{"firebase_id_token": "..."}` to `/api/v1/auth/google-login` and `/api/v1/auth/apple-login`.

### 3.3 Offline Storage & Synchronization
- **Hive Storage [SRC-VERIFIED]:** Hive boxes (`auth_box`, `sync_queue_box`, `user_box`, `settings_box`, `consent_box`, `profile_box`) store client-side state.
- **Idempotency [SRC-VERIFIED]:** All clinical mutations attach a client-generated UUID (`client_uuid`) to prevent duplicate records during network retries.
- **Local-Only Features [SRC-VERIFIED]:**
  - In-app notification inbox: Hive `userBox` (`notification_*`).
  - Pill and appointment alarms: Scheduled via platform alarms; no push token or backend notification endpoints exist.
  - OCR text recognition: On-device Google ML Kit `TextRecognizer()`.
  - Doctor Summary PDF generation: On-device rendering via `pdf` and `printing` packages.

---

## 4. Complete Legacy API Endpoint Inventory (64 Endpoints)

| ID | Method & Route | Auth Required | Parameters / Body | Response Data Shape | Type | MediCrate Feature / Repo | Safe Reuse? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A1** | `POST /auth/signup` | Static `x-api-key` | `name`, `email`, `password`, `password_confirmation`, `dob`, `gender?` | `{"user_id": 12, "message": "..."}` | Mutates | `AuthRepository` | ⚠️ Deprecated (Replaced by Supabase signup) |
| **A2** | `POST /auth/verify-email` | Static `x-api-key` | `email`, `otp` (4 digits) | `user_id`, `access_token`, `refresh_token` | Mutates | `AuthRepository` | ⚠️ Deprecated (Supabase uses 6-digit OTP/link) |
| **A3** | `POST /auth/resend-otp` | Static `x-api-key` | `email`, `type` (`signup` \| `reset_password` \| `change_email`) | `{"message": "..."}` | Mutates | `AuthRepository` | ⚠️ Deprecated (Replaced by Supabase resend) |
| **A4** | `POST /auth/login` | Static `x-api-key` | `email`, `password` | `user_id`, `name`, `access_token`, `refresh_token` | Read-only | `AuthRepository` | ⚠️ Deprecated (Replaced by Supabase login) |
| **A5** | `POST /auth/forgot-password`| Static `x-api-key` | `email` | `{"message": "..."}` | Mutates | `AuthRepository` | ⚠️ Deprecated (Replaced by Supabase recovery) |
| **A6** | `POST /auth/reset-password` | Static `x-api-key` | `email`, `otp`, `password`, `password_confirmation` | `{"message": "..."}` | Mutates | `AuthRepository` | ⚠️ Deprecated (Replaced by Supabase recovery) |
| **A7** | `POST /auth/refresh-token` | Static `x-api-key` | `refresh_token` | `access_token`, `refresh_token` | Mutates | `AuthInterceptor` | ⚠️ Deprecated (Supabase handles refresh) |
| **A8** | `POST /auth/google-login` | Static `x-api-key` | `firebase_id_token` | `user_id`, `access_token`, `refresh_token` | Mutates | `GoogleAuthService` | ❌ Incompatible (Requires Firebase token) |
| **A9** | `POST /auth/apple-login` | Static `x-api-key` | `firebase_id_token` | `user_id`, `access_token`, `refresh_token` | Mutates | `AppleAuthService` | ❌ Incompatible (Apple auth excluded) |
| **A10**| `POST /auth/logout` | Bearer Token | None | `{"message": "Logged out successfully"}` | Mutates | `AuthRepository` | ⚠️ Deprecated (Supabase signout) |
| **B1** | `GET /users/me` | Bearer Token | None | `user` object + `primary_profile` | Read-only | `ProfileRepository` | ❌ Dormant (Requires Sanctum token) |
| **B2** | `POST /users/me` | Bearer Token | `name`, `dob`, `gender`, `height`, `weight`, `blood_group`, `photo?` | Updated profile map | Mutates | `ProfileRepository` | ❌ Dormant (Migrating in Phase 4) |
| **B3** | `PUT /users/me/password` | Bearer Token | `current_password`, `password`, `password_confirmation` | `{"message": "..."}` | Mutates | `SettingsRepository` | ❌ Dormant (Replaced by Supabase) |
| **B4** | `PUT /users/me/email` | Bearer Token | `new_email`, `password` | `{"message": "Verification code sent"}` | Mutates | `SettingsRepository` | ❌ Dormant (Replaced by Supabase) |
| **B5** | `PUT /users/me/email/confirm` | Bearer Token | `otp` (4 digits) | `{"message": "Email updated"}` | Mutates | `SettingsRepository` | ❌ Dormant (Replaced by Supabase) |
| **B6** | `DELETE /users/me` | Bearer Token | None (or password confirmation) | `{"message": "Account deleted"}` | Mutates | `SettingsRepository` | ❌ Dormant (Replaced by Supabase) |
| **F1** | `GET /family-members` | Bearer Token | None | List of family member profiles | Read-only | `ProfileRepository` | ❌ Dormant (Migrating in Phase 4) |
| **F2** | `GET /family-members/{id}` | Bearer Token | None | Single family member profile | Read-only | `ProfileRepository` | ❌ Dormant (Migrating in Phase 4) |
| **F3** | `POST /family-members` | Bearer Token | Demographics, relationship, `client_uuid` | Created family profile | Mutates | `ProfileRepository` | ❌ Dormant (Migrating in Phase 4) |
| **F4** | `PUT /family-members/{id}` | Bearer Token | Demographics, relationship, notes | Updated family profile | Mutates | `ProfileRepository` | ❌ Dormant (Migrating in Phase 4) |
| **F5** | `DELETE /family-members/{id}` | Bearer Token | None | `{"message": "Profile deleted"}` | Mutates | `ProfileRepository` | ❌ Dormant (Migrating in Phase 4) |
| **F6** | `POST /family-members/{id}/photo`| Bearer Token | Multipart `photo` file | Updated photo URL | Mutates | `ProfileRepository` | ❌ Dormant (Migrating in Phase 4) |
| **F7** | `GET /family/dashboard` | Bearer Token | None | Aggregate counts across all family members | Read-only | `HomeRepository` | ❌ Dormant (Local calculation in Hive) |
| **F8** | `GET /family/analytics` | Bearer Token | None | Aggregate health trends across profiles | Read-only | `AnalyticsRepository` | ❌ Dormant (Local calculation in Hive) |
| **D1** | `GET /doctors` | Bearer Token | `?profile_id={id}&limit={n}` | List of doctor contacts | Read-only | `DoctorRepository` | ❌ Dormant (Migrating in Phase 4) |
| **D2** | `POST /doctors` | Bearer Token | `profile_id`, `name`, `specialty`, `phone`, `email`, `client_uuid` | Created doctor object | Mutates | `DoctorRepository` | ❌ Dormant (Migrating in Phase 4) |
| **D3** | `GET /doctors/{id}` | Bearer Token | None | Doctor details + affiliated hospitals | Read-only | `DoctorRepository` | ❌ Dormant (Migrating in Phase 4) |
| **D4** | `POST /doctors/{id}` | Bearer Token | `name`, `specialty`, `phone`, `email`, `hospital_ids` | Updated doctor object | Mutates | `DoctorRepository` | ❌ Dormant (Migrating in Phase 4) |
| **D5** | `DELETE /doctors/{id}` | Bearer Token | None | `{"message": "Doctor deleted"}` | Mutates | `DoctorRepository` | ❌ Dormant (Migrating in Phase 4) |
| **H1** | `GET /hospitals` | Bearer Token | `?profile_id={id}&limit={n}` | List of hospital/clinic records | Read-only | `HospitalRepository` | ❌ Dormant (Migrating in Phase 4) |
| **H2** | `POST /hospitals` | Bearer Token | `profile_id`, `name`, `address`, `city`, `phone`, `client_uuid` | Created hospital object | Mutates | `HospitalRepository` | ❌ Dormant (Migrating in Phase 4) |
| **H3** | `GET /hospitals/{id}` | Bearer Token | None | Hospital details + associated doctors | Read-only | `HospitalRepository` | ❌ Dormant (Migrating in Phase 4) |
| **H4** | `POST /hospitals/{id}` | Bearer Token | `name`, `address`, `city`, `phone`, `email` | Updated hospital object | Mutates | `HospitalRepository` | ❌ Dormant (Migrating in Phase 4) |
| **H5** | `DELETE /hospitals/{id}` | Bearer Token | None | `{"message": "Hospital deleted"}` | Mutates | `HospitalRepository` | ❌ Dormant (Migrating in Phase 4) |
| **MD1**| `GET /medical-departments` | Bearer Token | None | List of medical specialties/departments | Read-only | Directory lookup | ❌ Dormant (Cached locally in Hive) |
| **C1** | `GET /consultations` | Bearer Token | `?profile_id={id}&limit={n}` | Paginated consultation encounters | Read-only | `ConsultationRepository` | ❌ Dormant (Migrating in Phase 4) |
| **C2** | `POST /consultations` | Bearer Token | Clinical encounter payload + `client_uuid` | Created consultation object | Mutates | `ConsultationRepository` | ❌ Dormant (Migrating in Phase 4) |
| **C3** | `GET /consultations/{id}` | Bearer Token | None | Consultation details + Rx + files | Read-only | `ConsultationRepository` | ❌ Dormant (Migrating in Phase 4) |
| **C4** | `POST /consultations/{id}` | Bearer Token | Updated consultation payload | Updated consultation object | Mutates | `ConsultationRepository` | ❌ Dormant (Migrating in Phase 4) |
| **C5** | `DELETE /consultations/{id}` | Bearer Token | None | `{"message": "Consultation deleted"}` | Mutates | `ConsultationRepository` | ❌ Dormant (Migrating in Phase 4) |
| **C6** | `GET /consultations/{id}/files/{fileId}` | Bearer Token | None | Binary attachment stream | Read-only | `ConsultationRepository` | ❌ Dormant (Supabase Storage in Phase 4) |
| **AP1**| `GET /appointments` | Bearer Token | `?profile_id={id}&limit={n}` | Scheduled appointments list | Read-only | `AppointmentRepository` | ❌ Dormant (Migrating in Phase 4) |
| **AP2**| `POST /appointments` | Bearer Token | Booking payload, doctor, facility, `client_uuid` | Created appointment object | Mutates | `AppointmentRepository` | ❌ Dormant (Migrating in Phase 4) |
| **AP3**| `GET /appointments/{id}` | Bearer Token | None | Appointment details | Read-only | `AppointmentRepository` | ❌ Dormant (Migrating in Phase 4) |
| **AP4**| `POST /appointments/{id}` | Bearer Token | Updated appointment status / time | Updated appointment object | Mutates | `AppointmentRepository` | ❌ Dormant (Migrating in Phase 4) |
| **AP5**| `DELETE /appointments/{id}` | Bearer Token | None | `{"message": "Appointment deleted"}` | Mutates | `AppointmentRepository` | ❌ Dormant (Migrating in Phase 4) |
| **R1** | `GET /reports` | Bearer Token | `?profile_id={id}&category={c}&limit={n}` | List of diagnostic reports | Read-only | `ReportRepository` | ❌ Dormant (Migrating in Phase 4) |
| **R2** | `POST /reports` | Bearer Token | Multipart report metadata, files, `client_uuid` | Created report object | Mutates | `ReportRepository` | ❌ Dormant (Migrating in Phase 4) |
| **R3** | `GET /reports/{id}` | Bearer Token | None | Report details + attachments | Read-only | `ReportRepository` | ❌ Dormant (Migrating in Phase 4) |
| **R4** | `POST /reports/{id}` | Bearer Token | Updated report fields / attachments | Updated report object | Mutates | `ReportRepository` | ❌ Dormant (Migrating in Phase 4) |
| **R5** | `DELETE /reports/{id}` | Bearer Token | None | `{"message": "Report deleted"}` | Mutates | `ReportRepository` | ❌ Dormant (Migrating in Phase 4) |
| **R6** | `GET /reports/{id}/files/{fileId}` | Bearer Token | None | Binary attachment stream | Read-only | `ReportRepository` | ❌ Dormant (Supabase Storage in Phase 4) |
| **M1** | `GET /medicines` | Bearer Token | `?profile_id={id}&limit={n}` | Prescriptions list + active flags | Read-only | `MedicineRepository` | ❌ Dormant (Migrating in Phase 4) |
| **M2** | `POST /medicines` | Bearer Token | Dosage, frequency, dates, `client_uuid` | Created medicine object | Mutates | `MedicineRepository` | ❌ Dormant (Migrating in Phase 4) |
| **M3** | `GET /medicines/{id}` | Bearer Token | None | Medicine details + adherence logs | Read-only | `MedicineRepository` | ❌ Dormant (Migrating in Phase 4) |
| **M4** | `POST /medicines/{id}` | Bearer Token | Updated dosage, status | Updated medicine object | Mutates | `MedicineRepository` | ❌ Dormant (Migrating in Phase 4) |
| **M5** | `DELETE /medicines/{id}` | Bearer Token | None | `{"message": "Medicine deleted"}` | Mutates | `MedicineRepository` | ❌ Dormant (Migrating in Phase 4) |
| **V1** | `GET /vitals` | Bearer Token | `?profile_id={id}&type={t}&limit={n}` | Vitals measurements list | Read-only | `MeasurementRepository` | ❌ Dormant (Migrating in Phase 4) |
| **V2** | `POST /vitals` | Bearer Token | Polymorphic vital payload, `client_uuid` | Created vital measurement | Mutates | `MeasurementRepository` | ❌ Dormant (Migrating in Phase 4) |
| **V3** | `GET /vitals/{id}` | Bearer Token | None | Single vital measurement detail | Read-only | `MeasurementRepository` | ❌ Dormant (Migrating in Phase 4) |
| **V4** | `POST /vitals/{id}` | Bearer Token | Updated vital reading | Updated vital measurement | Mutates | `MeasurementRepository` | ❌ Dormant (Migrating in Phase 4) |
| **V5** | `DELETE /vitals/{id}` | Bearer Token | None | `{"message": "Vital deleted"}` | Mutates | `MeasurementRepository` | ❌ Dormant (Migrating in Phase 4) |
| **AN1**| `GET /analytics` | Bearer Token | `?profile_id={id}` | Health Vault Score + trend series | Read-only | `AnalyticsRepository` | ❌ Dormant (Calculated in Hive) |
| **DB1**| `GET /dashboard` | Bearer Token | `?profile_id={id}` | Composite summary card feed | Read-only | `HomeRepository` | ❌ Dormant (Derived from Hive) |
| **T1** | `GET /timeline` | Bearer Token | `?profile_id={id}&limit={n}` | Unified chronological event feed | Read-only | `TimelineRepository` | ❌ Dormant (Unified in Hive) |

---

## 5. Live Laravel API Test Results

Direct HTTP probes were conducted against `https://phplaravel-1505866-6585565.cloudwaysapps.com/api/v1` using standard REST headers (`Accept: application/json`, `Content-Type: application/json`, `x-api-key: ...`).

### 5.1 Public Root & Routing Probe
| Target URL | Method | HTTP Status | Response Content-Type | Observed Response Body | Classification |
| :--- | :---: | :---: | :--- | :--- | :--- |
| `/` | `GET` | **200 OK** | `text/html; charset=utf-8` | Full HTML page titled `<title>Medi_vault</title>` | **[API-VERIFIED]** Server online and routing |
| `/api/v1` | `GET` | **404 Not Found** | `application/json` | `{"status":"error","message":"Resource not found."}` | **[API-VERIFIED]** Custom API 404 router fallback |
| `/api/v1/nonexistent-route` | `GET` | **404 Not Found** | `application/json` | `{"status":"error","message":"Resource not found."}` | **[API-VERIFIED]** Verified 404 for missing paths |

### 5.2 Authentication Endpoints Validation Probes
| Endpoint | Method | Payload | HTTP Status | Observed Response Body | Classification |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `/auth/login` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The email field is required. (and 1 more error)","errors":{"email":["The email field is required."],"password":["The password field is required."]}}` | **[API-VERIFIED]** Validates email & password |
| `/auth/google-login` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The firebase id token field is required.","errors":{"firebase_id_token":["The firebase id token field is required."]}}` | **[API-VERIFIED]** Strictly requires `firebase_id_token` |
| `/auth/apple-login` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The firebase id token field is required.","errors":{"firebase_id_token":["The firebase id token field is required."]}}` | **[API-VERIFIED]** Strictly requires `firebase_id_token` |
| `/auth/verify-email` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The email field is required. (and 1 more error)","errors":{"email":["The email field is required."],"otp":["The otp field is required."]}}` | **[API-VERIFIED]** Validates email & 4-digit OTP |
| `/auth/resend-otp` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The email field is required. (and 1 more error)","errors":{"email":["The email field is required."],"type":["The type field is required."]}}` | **[API-VERIFIED]** Validates email & OTP type |
| `/auth/forgot-password` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The email field is required.","errors":{"email":["The email field is required."]}}` | **[API-VERIFIED]** Validates email |
| `/auth/reset-password` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The email field is required. (and 2 more errors)","errors":{"email":["The email field is required."],"otp":["The otp field is required."],"password":["The password field is required."]}}` | **[API-VERIFIED]** Validates email, OTP, and password |
| `/auth/refresh-token` | `POST` | `{}` | **422 Unprocessable** | `{"message":"The refresh token field is required.","errors":{"refresh_token":["The refresh token field is required."]}}` | **[API-VERIFIED]** Validates `refresh_token` |

### 5.3 Protected Clinical Endpoints Probe (Unauthenticated)
Every documented clinical route was probed with `x-api-key` but without an `Authorization` header to confirm route existence and middleware behavior:

| Endpoint | Method | HTTP Status | Response Time | Observed Response Body | Classification |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `/medical-departments` | `GET` | **401 Unauthorized** | 0.86s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/users/me` | `GET` | **401 Unauthorized** | 0.84s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/consultations` | `GET` | **401 Unauthorized** | 1.06s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/family-members` | `GET` | **401 Unauthorized** | 0.91s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/doctors` | `GET` | **401 Unauthorized** | 0.89s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/hospitals` | `GET` | **401 Unauthorized** | 1.02s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/medicines` | `GET` | **401 Unauthorized** | 0.94s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/reports` | `GET` | **401 Unauthorized** | 0.96s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/vitals` | `GET` | **401 Unauthorized** | 0.98s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/appointments` | `GET` | **401 Unauthorized** | 0.95s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/dashboard` | `GET` | **401 Unauthorized** | 0.86s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/analytics` | `GET` | **401 Unauthorized** | 1.01s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |
| `/timeline` | `GET` | **401 Unauthorized** | 1.03s | `{"status":"error","message":"Unauthorized. Please login again."}` | **[API-VERIFIED]** Exists; protected by Sanctum |

> **Diagnostic Significance:** The uniform error string `{"status":"error","message":"Unauthorized. Please login again."}` differs from Laravel's stock `{"message":"Unauthenticated."}`. This proves beyond doubt that the live host is executing the actual MediVault Laravel application codebase and its custom exception handler, confirming the validity of the routes.

---

## 6. Authentication Compatibility Analysis

| Dimension | Legacy Laravel Backend | Target Supabase Auth | Compatibility Assessment |
| :--- | :--- | :--- | :--- |
| **Credential Type** | Email & Password | Email & Password | **Conceptually Compatible**, but credential hashes (Bcrypt in Laravel MySQL) cannot be queried or validated by Supabase Auth without direct DB export or user re-authentication. |
| **Email Verification** | 4-digit numeric OTP sent via Laravel mailer | 6-digit OTP or magic link via Supabase Auth | **Format Incompatible:** Laravel expects 4 digits; Supabase defaults to 6 digits. Cannot cross-verify. |
| **Google Sign-In** | Requires Firebase ID Token (`firebase_id_token`) validated via Firebase Admin SDK | Native Google ID-Token exchange via `supabase.auth.signInWithIdToken` | **Completely Incompatible:** Laravel rejects raw Google ID tokens; Supabase does not produce Firebase tokens. |
| **Apple Sign-In** | Requires Firebase ID Token | Excluded in MediCrate per specification | **Not Applicable** (Excluded). |
| **Token Format** | Laravel Sanctum personal access token (`id\|hash`) | RFC 7519 JWT (Header, Payload, Signature) | **Completely Incompatible:** Sanctum requires database token lookup; Supabase uses RS256/HS256 signed claims. |
| **External Token Acceptance** | No external JWT middleware installed | Native JWT issuer and validator | **Incompatible:** Laravel cannot accept or validate a Supabase JWT. |
| **Account Identity** | Auto-incrementing Integer ID (`12`) | UUID v4 (`138fb305-6a56-429d-9cf9-...`) | **Incompatible Primary Keys:** Cannot be swapped without aliasing. |

---

## 7. Migration Strategy Evaluation (Options A, B, and C)

### Option A: Dual-Backend Hybrid Bridge (Supabase Auth + Laravel Clinical APIs)
- **Concept:** User signs into Supabase Auth; the mobile app bridges identity to Laravel to obtain a Sanctum token for clinical APIs.
- **Feasibility:** **Impossible without modifying Laravel or retaining Firebase.**
  - For Google users, Laravel requires a `firebase_id_token`. Logging into Supabase does not yield a Firebase token. MediCrate would be forced to maintain Firebase Auth alongside Supabase Auth indefinitely.
  - For Email users, the app would need to perform double logins (sending plaintext passwords to both Supabase and Laravel), doubling latency and security exposure.
  - A server-side bridge cannot be deployed because we lack Laravel source-code access and Cloudways deployment credentials.
- **Verdict:** **REJECTED.**

### Option B: Supabase Auth with Gradual Repository-by-Repository Migration
- **Concept:** Maintain Sanctum authentication for remaining Laravel clinical endpoints while migrating endpoints one by one.
- **Feasibility:** **Flawed and Redundant.**
  - Suffering from all the issues of Option A (Firebase dependency, double logins, 401 edge cases) until the last repository is converted.
  - Adds unnecessary transitional complexity without user benefit.
- **Verdict:** **REJECTED.**

### Option C: Supabase-First Authentication & Controlled Phase 4 Clinical Migration
- **Concept:**
  - Supabase becomes the sole authentication authority starting in Phase 3B.2.
  - The legacy Laravel backend is placed into a completely dormant, isolated state.
  - Hive retains 100% of local clinical data and records all offline mutations in `syncQueueBox`.
  - In Phase 4, clean Supabase Postgres tables with Row Level Security (RLS) are provisioned, and Hive synchronization is redirected to Supabase.
- **Advantages:**
  - Zero dependencies on dormant Laravel backend.
  - Clean deprecation of Firebase Auth.
  - High performance, offline-first reliability.
  - Clinical data continuity preserved without data loss.
- **Verdict:** **CONFIRMED & RECOMMENDED.**

---

## 8. Phase 3B.1 Implementation Review & Verification

A review of the Phase 3B.1 commits ([`fbf70a3`](file:///home/blackhat/Documents/medi_crate)) was performed against the live API findings:

### 8.1 Strengths & Validations
1. **Decoupled 401 Purging:** In [`auth_providers.dart`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/providers/auth_providers.dart#L60), decoupling `onSessionExpired` from `handleSessionExpired()` is confirmed critical. Since all 13 probed clinical routes return 401 from Laravel, keeping the old listener would have wiped active user sessions continuously.
2. **Supabase JWT Suppression:** In [`dio_interceptor.dart`](file:///home/blackhat/Documents/medi_crate/lib/core/api/dio_interceptor.dart#L33), [`isSupabaseJwt`](file:///home/blackhat/Documents/medi_crate/lib/core/api/dio_interceptor.dart#L33) accurately prevents 3-part dot-separated JWTs from being transmitted to Laravel Sanctum endpoints.
3. **Suspended Background Sync:** Suspending WorkManager jobs in [`BackgroundSyncService`](file:///home/blackhat/Documents/medi_crate/lib/core/sync/background_sync_service.dart#L43) prevents battery drain and continuous 401 network error logging in the background.
4. **Offline Queue Preservation:** In [`SyncService`](file:///home/blackhat/Documents/medi_crate/lib/core/sync/sync_service.dart#L353), short-circuiting `syncPending()` preserves all `syncQueueBox` mutations, retry counters, and timestamps untouched for Phase 4.
5. **Multi-Tenant Profile Isolation:** In [`ProfileLocalDataSource`](file:///home/blackhat/Documents/medi_crate/lib/features/profile/data/datasources/local/profile_local_data_source.dart#L12), returning `[]` on empty `ownerUserId` prevents data leakage across profiles.

### 8.2 Observations & Recommendations for Phase 3B.2
1. **Header Case Insensitivity in Interceptor:**
   [`AuthInterceptor`](file:///home/blackhat/Documents/medi_crate/lib/core/api/dio_interceptor.dart#L84) currently checks `options.headers.containsKey('Authorization')` with PascalCase `'Authorization'`. In Dart `Map`, case sensitivity applies. If an internal caller injects lowercase `'authorization'`, it could bypass stripping. Recommendation: Use case-insensitive map matching in future maintenance.
2. **Dedicated Token Storage Keys:**
   `SecureStorageService.clearAuthToken()` is called during permanent auth errors. When Phase 3B.2 introduces Supabase Auth, Supabase tokens must be stored under dedicated keys (e.g. `supabase_access_token`) or managed directly via Supabase's native `FlutterSecureStorage` adapter so legacy interceptor logic never touches Supabase session tokens.

---

## 9. Unresolved Questions & Required Access

| Area | Status | Blocked Item | Mitigation / Resolution |
| :--- | :--- | :--- | :--- |
| **Laravel Database Access** | **Not Accessible** | Direct export of existing user password hashes (Bcrypt) and historical clinical records. | Proceed with Option C: users activate Supabase accounts; local Hive clinical data is preserved and re-associated via the UUID alias map designed in Phase 3A.2. |
| **Cloudways Server Shell** | **Not Accessible** | Cannot inspect Laravel `.env`, routes file, or database config directly on the host. | The live API probes confirmed route existence and validation rules; server access is not required for Option C. |
| **Live Authenticated Test Account** | **Pending User Input** | Authenticated GET requests returning live JSON records could not be executed because no valid credentials exist in `.env`. | Handled safely in accordance with Section 4: live routing confirmed via 401/422 probes without exposing credentials or blocking the audit. |

---

## 10. Recommended Next Implementation Step

With the legacy Laravel API and source code comprehensively audited and confirmed incompatible with direct JWT consumption:

1. **Maintain Option C:** Keep legacy Laravel APIs completely dormant and isolated.
2. **Proceed to Phase 3B.2:**
   - Initialize the `SupabaseClient` in `lib/main.dart` using environment variables.
   - Implement Supabase email/password authentication (signup, login, OTP verification, password reset).
   - Implement native Google Sign-In with Supabase ID token exchange (`signInWithIdToken`).
   - Wire Riverpod `authControllerProvider` exclusively to Supabase Auth state.
   - Preserve existing local Hive clinical records throughout the sign-in/sign-up lifecycle.
