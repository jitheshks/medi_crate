# MediCrate — Phase 8.2.4: Laravel API-Based Historical Data Extraction Feasibility Report

> **Document Version:** 1.0.0  
> **Evaluation Date:** November 12, 2026  
> **Status:** Feasibility Assessment Complete  
> **Baseline Benchmark:** MediVault 64-Endpoint Laravel REST API Architecture (`https://phplaravel-1505866-6585565.cloudwaysapps.com/api/v1`)  
> **Reference Directory:** `/home/blackhat/Documents/Reubro/medivalut` (Read-Only)  
> **Target Project:** `/home/blackhat/Documents/medi_crate`  

---

## 1. Executive Summary & Core Finding

Without direct MySQL database or Cloudways hosting access, the feasibility of migrating historical MediVault data into MediCrate was evaluated against the existing 64 Laravel REST API endpoints.

### Key Finding:
> ⚠️ **Historical migration CANNOT be performed as a full, automated database migration via the existing Laravel REST APIs.**
>
> The MediVault REST API is a **consumer-facing mobile client interface**, not an administrative data management or bulk export API. It enforces strict per-user authentication (`auth:sanctum`), lacks administrative user enumeration endpoints, hides password hashes, omits soft-deleted clinical records, and does not expose standalone medical expenses.

However, **per-user active clinical record extraction is technically feasible** for known accounts where user credentials (email/password) are available.

---

## 2. API Extraction Feasibility Matrix by Domain

Evaluation of the 15 migration domains against the 64-endpoint MediVault API contract:

| # | Domain | Available API Route | Auth & Scope | Completeness & Data Access | Feasibility Status |
| :-: | :--- | :--- | :--- | :--- | :---: |
| **1** | **Users (`users`)** | `GET /users/me` (`B1`) | Bearer token (`auth:sanctum`). Scoped to authenticated user. | Returns `id`, `name`, `email`, `phone`, `email_verified_at`. **Password hashes are hidden.** No user enumeration endpoint exists. | ⚠️ **Partial** (Per-User Only; 0% Passwords) |
| **2** | **User Profiles (`user_profiles`)** | Embedded in `GET /users/me` (`B1`) | Bearer token. Scoped to primary Self profile. | Returns primary demographics (`date_of_birth`, `gender`, `blood_group`, `allergies`, `chronic_conditions`). | ⚠️ **Partial** (Per-User Only) |
| **3** | **Profiles (`profiles`)** | `GET /family-members` (`F1`), `GET /family-members/{id}` (`F2`) | Bearer token. Scoped to user's family profiles. | Returns family profiles (`id`, `full_name`, `relationship`, `is_primary`, demographics). `serverProfileId` is exposed. | ⚠️ **Partial** (Per-User Only) |
| **4** | **Hospitals (`hospitals`)** | `GET /hospitals?profile_id={id}` (`H1`) | Bearer token. Scoped to `profile_id`. | Returns facility list for specified profile. Query parameter `limit` max 200. | ⚠️ **Partial** (Per-User & Per-Profile) |
| **5** | **Doctors (`doctors`)** | `GET /doctors?profile_id={id}` (`D1`) | Bearer token. Scoped to `profile_id`. | Returns clinicians for specified profile. Query parameter `limit` max 200. | ⚠️ **Partial** (Per-User & Per-Profile) |
| **6** | **Doctor Affiliations (`doctor_hospitals`)** | Nested in `GET /doctors/{id}` (`D3`) & `GET /hospitals/{id}` (`H3`) | Bearer token. Embedded relation. | Reconstructed from `affiliated_hospitals` list within doctor detail objects. | ⚠️ **Partial** (Indirect via joined detail calls) |
| **7** | **Consultations (`consultations`)** | `GET /consultations?profile_id={id}` (`C1`), `GET /consultations/{id}` (`C3`) | Bearer token. Scoped to `profile_id`. | Returns encounters (`visit_date`, `diagnosis`, `doctor_name`, `hospital_name`, `attachments`). **Soft-deleted encounters (`deleted_at`) are excluded.** | ⚠️ **Partial** (Active Records Only) |
| **8** | **Consultation Attachments (`consultation_attachments`)** | Embedded in `GET /consultations/{id}` (`C3`), download via `GET /consultations/{id}/files/{fileId}` (`C6`) | Bearer token. | Exposes attachment metadata (`id`, `file_name`, `size_bytes`, `created_at`). File binary downloaded via `C6`. Requires live Cloudways server. | ⚠️ **Partial** (Active Encounters Only) |
| **9** | **Appointments (`appointments`)** | `GET /appointments?profile_id={id}` (`AP1`), `GET /appointments/{id}` (`AP3`) | Bearer token. Scoped to `profile_id`. | Returns future and past visits (`appointment_date`, `status`, `doctor_id`, `hospital_id`). Soft-deleted records excluded. | ⚠️ **Partial** (Active Records Only) |
| **10**| **Prescriptions (`prescriptions`)** | `GET /medicines?profile_id={id}` (`M1`), `GET /medicines/{id}` (`M3`) | Bearer token. Scoped to `profile_id`. | Returns medication schedules (`medication_name`, `dosage`, `frequency`, `start_date`, `end_date`, `is_active`). | ⚠️ **Partial** (Active Records Only) |
| **11**| **Diagnostic Reports (`reports`)** | `GET /reports?profile_id={id}` (`R1`), `GET /reports/{id}` (`R3`) | Bearer token. Scoped to `profile_id`. | Returns investigations (`title`, `category`, `report_date`, `notes`, `attachments`, `expense`). Soft-deleted reports excluded. | ⚠️ **Partial** (Active Records Only) |
| **12**| **Report Attachments (`report_attachments`)** | Embedded in `GET /reports/{id}` (`R3`), download via `GET /reports/{id}/files/{fileId}` (`R6`) | Bearer token. | Exposes attachment metadata (`id`, `name`, `size_bytes`). Download via `R6`. Requires live Cloudways server. | ⚠️ **Partial** (Active Reports Only) |
| **13**| **Report Expenses (`report_expenses`)** | Embedded in `GET /reports/{id}` (`R3`) as `expense` object | Bearer token. Embedded relation. | Embedded 1:1 financial data (`amount`, `currency`, `status`, `description`). Only accessible when linked to a report. | ⚠️ **Partial** (Report-Linked Only) |
| **14**| **Health Measurements (`measurements`)** | `GET /vitals?profile_id={id}` (`V2`), `GET /vitals/{id}` (`V3`) | Bearer token. Scoped to `profile_id`. | Returns polymorphic vitals (`type`, `primary_value`, `secondary_value`, `measured_at`, `status`). | ⚠️ **Partial** (Active Records Only) |
| **15**| **Standalone Medical Expenses (`medical_expenses`)** | **NO ACTIVE ROUTE** in 64-endpoint contract | — | The 64 active API endpoints do **NOT** include `GET /expenses`. Standalone expenses (pharmacy bills, unlinked receipts) have **zero GET API exposure**. | ❌ **CANNOT BE EXTRACTED VIA API** |

---

## 3. Data Completeness & Irrecoverable Data Analysis

Extracting data exclusively via the Laravel REST API creates significant, irreversible information gaps compared to a direct MySQL dump:

### A. Global User Discovery & Authentication (Critical Blocker)
1. **No User Enumeration:** The API has no `GET /users` or administrative route. The migration script cannot discover user accounts. The migration team would need to know the email and password for **every single registered user** to log in and fetch their data.
2. **Zero Password Hashes:** In Laravel's Eloquent `User` model, the password hash is protected:
   ```php
   protected $hidden = ['password', 'remember_token'];
   ```
   Password hashes are never returned over HTTP. **100% of users migrated via API will have no password hash** and must use password reset / invitation workflows.

### B. Omission of Standalone Financial History
* The 64-endpoint MediVault contract only exposes expenses tied 1:1 to diagnostic reports (`GET /reports/{id}`).
* Standalone medical expenses (over-the-counter pharmacy purchases, clinic consultation fees, unlinked receipts) exist in the MySQL database table `medical_expenses` but **have no active GET endpoint in the mobile API**.
* All standalone financial history will be permanently lost if migrating via API alone.

### C. Omission of Soft-Deleted & Historical Audit Trails
* Laravel's `SoftDeletes` trait automatically adds `WHERE deleted_at IS NULL` to all Eloquent queries.
* Endpoints do not support `?with_trashed=true`.
* Any deleted consultations, archived prescriptions, cancelled appointments, or removed family members that exist in the MySQL database will be **completely invisible to the API**.

### D. Network Fragility of Media Attachment Downloads
* Binary files (PDF reports, prescription slips, avatar photos) must be individually downloaded over HTTP via signed stream endpoints (`/consultations/{id}/files/{fileId}`, `/reports/{id}/files/{fileId}`).
* For an active database with thousands of files, this requires thousands of sequential HTTP requests, subject to Cloudways rate-limiting (HTTP 429), timeouts, and potential bandwidth limits.

---

## 4. Proposed Read-Only Extraction Adapter Architecture

If individual account credentials are provided and API extraction is required, the adapter must feed directly into MediCrate's existing Phase 8.2.1 migration engine without building a parallel architecture:

```
┌─────────────────────────────────────────────────────────┐
│               Legacy Laravel REST APIs                  │
│       https://phplaravel-1505866-6585565.cloudways...   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼ (Read-Only GET calls via Bearer tokens)
┌─────────────────────────────────────────────────────────┐
│              ApiExtractionAdapter                       │
│  - Authenticates known accounts (POST /auth/login)      │
│  - Fetches profiles (GET /users/me, GET /family-members)│
│  - Iterates profiles and fetches domains (C1, M1, etc.) │
│  - Downloads media files into local storage directory   │
│  - Checkpoints extraction progress                      │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼ (Assembles structured JSON dump)
┌─────────────────────────────────────────────────────────┐
│             LegacyDatabaseDump (JSON)                   │
│          medivault_api_extracted.json                   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼ (Existing Phase 8.2.1-8.2.2.1 Engine)
┌─────────────────────────────────────────────────────────┐
│             tool/prepare_migration.dart                 │
│  --input=medivault_api_extracted.json                   │
│  --source-db-id=medivault_api_tenant                    │
│  --source-storage-dir=/extracted/storage/app/public     │
│  --production                                           │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│    MediCrate PostgreSQL SQL & Supabase Storage Manifest │
└─────────────────────────────────────────────────────────┘
```

### Adapter Design Requirements:
1. **Input:** A local, git-ignored `account_manifest.json` containing credentials for accounts authorized for migration.
2. **Rate Limiting & Retries:** Strict concurrency throttle (max 2 concurrent requests) and exponential backoff retry on HTTP 429 / 502 / 503.
3. **Resumability:** Checkpointing to `extraction_checkpoint.json` so interrupted file downloads or record batches do not re-fetch existing data.
4. **Output:** Formats responses into standard `LegacyDatabaseDump` JSON keys (`users`, `profiles`, `consultations`, etc.), preserving existing deterministic RFC 4122 v5 UUID mappings and reconciliation accounting.

---

## 5. Architectural Comparison & Final Recommendation

| Criterion | Direct MySQL Dump Migration | Laravel REST API Extraction |
| :--- | :--- | :--- |
| **Server Credentials Required** | Single MySQL / phpMyAdmin / SSH export by admin. | Email & password for **every individual user**. |
| **User Account Coverage** | **100% of all registered users.** | **Only known / supplied accounts.** |
| **Password Hashes** | **Preserved** (bcrypt hashes in `users.password`). | **0% Recoverable** (hidden by Eloquent). |
| **Soft-Deleted Audit Trails** | **Preserved** in relational tables. | **0% Recoverable** (suppressed by API). |
| **Standalone Financial History**| **100% Preserved** via `standaloneExpenses`. | **0% Recoverable** (no GET route exists). |
| **Attachment File Integrity** | Filesystem copy with direct SHA-256 validation. | Thousands of HTTP file downloads (fragile). |
| **Execution Safety** | 100% offline; zero network calls. | Remote HTTP calls subject to rate limits/timeouts. |

### Final Recommendations:

1. **Primary Recommendation (Mandatory for Complete Historical Migration):**
   Request a single `medivault_dump.sql` export and a zip of `storage/app/public/` from the Cloudways account owner or database administrator. This is the **only method that guarantees 100% data integrity, password reset eligibility, and complete clinical history**.
2. **Secondary Recommendation (Self-Service Data Portability Fallback):**
   If Cloudways hosting access is permanently lost, implement the proposed `ApiExtractionAdapter` strictly as a **per-user self-service data import tool**, allowing users who know their MediVault credentials to authenticate and import their personal and family health records into MediCrate.
