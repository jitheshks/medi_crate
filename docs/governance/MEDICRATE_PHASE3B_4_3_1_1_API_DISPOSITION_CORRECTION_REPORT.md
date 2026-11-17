# MediCrate – Phase 3B.4.3.1.1: API Disposition Correction & Evidence Verification Report

> **Document Classification:** Governance & Architecture Audit Report  
> **Phase:** 3B.4.3.1.1 (Reconciliation & Count Verification)  
> **Audit Date:** November 9, 2026  
> **Auditor:** Antigravity AI – Senior Migration Architecture Agent  
> **Target Active Document:** `docs/active/MEDICRATE_PHASE3B_4_3_1_API_AND_FEATURE_DISPOSITION_MATRIX.md`  
> **Reference Baseline:** `api_audit/medivault_complete_api_requirements.csv` (MediVault Read-Only Reference)  
> **Active Target Repository:** `/home/blackhat/Documents/medi_crate`  
> **Read-Only Reference Repository:** `/home/blackhat/Documents/Reubro/medivalut`  

---

## 1. Executive Summary & Audit Mandate

During the Phase 3B.4.3.1 documentation review, an evidence-driven audit of `docs/active/MEDICRATE_PHASE3B_4_3_1_API_AND_FEATURE_DISPOSITION_MATRIX.md` revealed critical mathematical discrepancies between the narrative/summary category counts and the actual line items in the 64-endpoint table.

Specifically:
1. The narrative text and Mermaid pie chart cited **39 PostgREST endpoints**, whereas counting the listed table rows revealed **42 PostgREST endpoints**.
2. The report cited **14 Supabase Auth endpoints** for the set `A1–A8`, `A10`, `B1`, `B3–B5`. However, this set contains 13 IDs in total, and `B5` (Account Deletion) was assigned to a Security Definer RPC, leaving **12 Auth SDK endpoints**.
3. The report cited **7 Local Hive Aggregation endpoints**, but only **5 endpoints** (`F7`, `F8`, `AN1`, `DB1`, `T1`) have original endpoint IDs in the 64-endpoint baseline. The extra 2 endpoints were ungrounded speculative additions for local backup/export utilities.
4. The Mermaid pie chart omitted the **Security Definer RPC** category entirely, masking the count mismatch.
5. Legacy endpoint `B1` (`GET /users/me`) has dual dependencies (GoTrue Auth user session + `public.profiles` PostgREST query) but was inconsistently described.
6. The baseline CSV contains row 57 as `V0` (a domain validation enum specification with no HTTP route), whereas the codebase actively implements route `C6` (`GET /consultations/{id}/files/{fileId}`).

This report documents the corrective actions taken, provides the mathematical proof of the corrected counts, establishes the exact line-by-line primary disposition of all 64 endpoints, and details the architectural decisions for B1 and B5.

---

## 2. Discrepancy Analysis: Original vs. Corrected Counts

The table below contrasts the prior erroneous counts against the verified, mathematically reconciled counts:

| Primary Category | Prior Erroneous Count | Corrected Count | Delta | Root Cause & Resolution |
| :--- | :---: | :---: | :---: | :--- |
| **Supabase PostgREST Direct Tables** | 39 | **42** | +3 | **Miscalculation:** The narrative cited 39, but the 64-row table contained exactly 42 PostgREST rows ($1 + 5 + 5 + 5 + 1 + 5 + 5 + 5 + 5 + 5 = 42$). |
| **Supabase GoTrue Auth SDK** | 14 | **12** | -2 | **Double Counting & Misattribution:** The set `A1–A8, A10, B1, B3–B5` contains 13 IDs, not 14. `B5` was reclassified to RPC, leaving exactly 12 Auth SDK endpoints. |
| **Local Hive Aggregations** | 7 | **5** | -2 | **Ungrounded Scope Expansion:** Only `F7, F8, AN1, DB1, T1` are actual baseline endpoints. Speculative backup/export tools were removed from the count. |
| **Supabase Storage Buckets** | 3 | **3** | 0 | **Verified:** Binary upload/download routes for avatars (`F6`), consultations (`C6`), and reports (`R6`). |
| **Security Definer RPC** | 0 (Omitted) | **1** | +1 | **Missing Category:** `B5` (Account Deletion) was documented in text but completely omitted from the summary total and Mermaid pie chart. |
| **Excluded Features** | 1 | **1** | 0 | **Verified:** Apple Sign-In (`A9`) is explicitly excluded from MediCrate UI and scope. |
| **Total Endpoints** | **64** | **64** | **0** | **Exact Match:** The prior summary hid a $+3 - 2 - 2 + 1 = 0$ netting error. The corrected categories sum cleanly to $42 + 12 + 5 + 3 + 1 + 1 = 64$. |

---

## 3. Detailed Investigation of Findings

### Finding 1: Resolution of the PostgREST Table Count (42 Rows)

An exhaustive count of the 64 rows in the disposition matrix confirms that exactly 42 endpoints interact directly with PostgreSQL tables via PostgREST with Row Level Security:

1. **User Module (1):**
   - `B2`: `PUT /users/me` -> `UPDATE public.profiles WHERE is_primary = true`
2. **Family Member Module (5):**
   - `F1`: `GET /family-members` -> `SELECT * FROM public.profiles WHERE user_id = auth.uid()`
   - `F2`: `GET /family-members/{id}` -> `SELECT * FROM public.profiles WHERE id = :id`
   - `F3`: `POST /family-members` -> `INSERT INTO public.profiles ...`
   - `F4`: `PUT /family-members/{id}` -> `UPDATE public.profiles WHERE id = :id`
   - `F5`: `DELETE /family-members/{id}` -> `DELETE FROM public.profiles WHERE id = :id`
3. **Doctors Module (5):**
   - `D1` (List), `D2` (Create), `D3` (Get), `D4` (Update), `D5` (Delete) -> `public.doctors`
4. **Hospitals Module (5):**
   - `H1` (List), `H2` (Create), `H3` (Get), `H4` (Update), `H5` (Delete) -> `public.hospitals`
5. **Reference Taxonomy Module (1):**
   - `MD1`: `GET /medical-departments` -> `SELECT * FROM public.medical_departments`
6. **Consultations Module (5):**
   - `C1` (List), `C2` (Create), `C3` (Get), `C4` (Update), `C5` (Delete) -> `public.consultations` *(Note: C6 is Storage)*
7. **Appointments Module (5):**
   - `AP1` (List), `AP2` (Book), `AP3` (Get), `AP4` (Reschedule), `AP5` (Cancel) -> `public.appointments`
8. **Reports Module (5):**
   - `R1` (List), `R2` (Create), `R3` (Get), `R4` (Update), `R5` (Delete) -> `public.reports` *(Note: R6 is Storage)*
9. **Medicines Module (5):**
   - `M1` (List), `M2` (Create), `M3` (Get), `M4` (Update), `M5` (Delete) -> `public.prescriptions`
10. **Vitals Module (5):**
    - `V1` (Create), `V2` (List), `V3` (Get), `V4` (Update), `V5` (Delete) -> `public.measurements`

**Subtotal:** $1 + 5 + 5 + 5 + 1 + 5 + 5 + 5 + 5 + 5 = \mathbf{42\text{ PostgREST Endpoints}}$.

---

### Finding 2: Resolution of the Supabase Auth Count (12 IDs)

The previous report claimed 14 Auth endpoints, listing `A1–A8`, `A10`, `B1`, `B3–B5`.
Let us inspect the exact IDs in that set:
- A-series: `A1`, `A2`, `A3`, `A4`, `A5`, `A6`, `A7`, `A8`, `A10` $\rightarrow$ 9 endpoints.
- B-series: `B1`, `B3`, `B4`, `B5` $\rightarrow$ 4 endpoints.
- Combined: $9 + 4 = 13\text{ endpoints}$ (not 14).

Furthermore, `B5` (`DELETE /users/me`) cannot be executed by the client-side GoTrue Auth SDK because normal user JWTs lack administrative rights to delete records from `auth.users`. It requires a Security Definer RPC.

Removing `B5` from the Auth SDK category results in:
$$\mathbf{12\text{ Supabase Auth SDK Endpoints}}$$
- `A1`: `signUp()`
- `A2`: `verifyOTP(signup)`
- `A3`: `resend(signup)`
- `A4`: `signInWithPassword()`
- `A5`: `resetPasswordForEmail()`
- `A6`: `updateUser(password)`
- `A7`: GoTrue background token auto-refresh
- `A8`: `signInWithIdToken(google)`
- `A10`: `signOut()`
- `B1`: `currentUser` session resolution
- `B3`: `updateUser(password)`
- `B4`: `updateUser(email)`

---

### Finding 3: Resolution of Local Aggregations (5 IDs)

The previous report cited 7 local aggregation endpoints. However, a strict audit of the 64-endpoint baseline proves there are only **5 endpoints** that represent local aggregations:
1. `F7`: `GET /api/v1/family/dashboard` $\rightarrow$ `HomeRepository.getHomeSummary`
2. `F8`: `GET /api/v1/family/analytics` $\rightarrow$ `AnalyticsRepository.getInsightsSummary`
3. `AN1`: `GET /api/v1/analytics` $\rightarrow$ `AnalyticsRepository.getInsightsSummary`
4. `DB1`: `GET /api/v1/dashboard` $\rightarrow$ `HomeRepository.getHomeSummary`
5. `T1`: `GET /api/v1/timeline` $\rightarrow$ `TimelineRepository.getTimelineFeed`

The prior author reached "7" by adding hypothetical endpoints for on-device JSON export and local SQLite/Hive backup operations. Because those utility operations do not correspond to any legacy Laravel REST endpoint IDs in the 64-row benchmark, counting them as API endpoints violated audit rules. The correct count is strictly **5**.

---

### Finding 4: B1 Dual-Dependency Resolution

In legacy Laravel, `GET /api/v1/users/me` (`B1`) returned both account metadata from the `users` table and primary profile data from `profiles`.

In Supabase:
- User credentials and session identity reside in `auth.users`, accessed via `supabase.auth.currentUser`.
- Demographic and clinical attributes reside in `public.profiles`, accessed via PostgREST:
  ```sql
  SELECT * FROM public.profiles WHERE user_id = auth.uid() AND is_primary = true;
  ```

**Disposition Governance Rule:**
`B1` is classified under **Supabase GoTrue Auth SDK** as its **Primary Disposition** (resolving user identity and session). It holds an explicit **Secondary Dependency** on `public.profiles` via PostgREST. It is accounted for as **one single endpoint**, preventing double-counting.

---

### Finding 5: B5 Account Deletion Architecture & Unresolved Security Decisions

`DELETE /api/v1/users/me` (`B5`) is permanently classified as **Security Definer RPC**:

1. **Permission Boundary:**
   Client JWTs authenticated in Supabase possess the `authenticated` role. By Supabase design, `authenticated` users cannot perform `DELETE FROM auth.users WHERE id = auth.uid()`.
2. **Elevated RPC Function:**
   Phase 4 must deploy a PostgreSQL function defined with `SECURITY DEFINER` and `SET search_path = public, auth`:
   ```sql
   CREATE OR REPLACE FUNCTION public.delete_user_account()
   RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
   BEGIN
       DELETE FROM auth.users WHERE id = auth.uid();
   END;
   $$;
   ```
3. **Foreign Key Cascade:**
   `public.profiles` defines `user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE`. Deleting the `auth.users` row will cascade to all child clinical records.
4. **Storage Purge:**
   Database cascades do not automatically delete files in `storage.objects`. An Edge Function or storage trigger must purge the user's files from the `avatars`, `consultations`, and `reports` buckets.
5. **Unresolved Decisions for Phase 4:**
   - **Grace Period:** Implement immediate hard delete vs. 30-day soft delete (`account_status = 'pending_deletion'`).
   - **Re-authentication:** Mandate explicit re-entry of password (`signInWithPassword`) in the UI before invoking the RPC.
   - **Legal Retention:** Determine whether medical liability laws require anonymized retention of past encounter summaries.

---

### Finding 6: CSV vs. Codebase Baseline Reconciliation (V0 vs. C6)

During the audit, a structural divergence was identified between the master CSV and the active Flutter client:

- **Master CSV (`medivault_complete_api_requirements.csv`):**
  - Contains 64 rows.
  - Row 57 is `V0`: `Vital Type Reference`, Method `—`, Endpoint `—`.
  - It does NOT contain `C6` (Consultation File Download).
- **MediCrate Flutter Codebase:**
  - `lib/features/consultations/data/datasources/remote/consultation_remote_data_source.dart:295` explicitly implements `C6`:
    ```dart
    /// C6: GET /consultations/{consultation}/files/{file} — Streams binary file download.
    Future<Uint8List> downloadConsultationAttachment(dynamic consultationId, dynamic fileId) async ...
    ```
  - Both `C6` and `R6` are binary streaming routes that map to Supabase Storage signed URLs.
  - `V0` is a domain enum constraint (`bp`, `glucose`, `heart_rate`, `spo2`, `temperature`, `respiratory_rate`, `bmi`), not a network route.

**Resolution:**
The 64 active API endpoints in `MEDICRATE_PHASE3B_4_3_1_API_AND_FEATURE_DISPOSITION_MATRIX.md` include `C6` as a concrete network endpoint. `V0` is fully documented in Section 2 as a complementary domain validation specification that will be enforced via PostgreSQL check constraints in Phase 4.

---

## 4. Line-by-Line Primary Disposition Verification Table

Every endpoint ID appears **exactly once** in the primary disposition column. The sum of the primary classifications is **64**:

| No | ID | Route | Primary Disposition | Secondary Dependency | Proposed Target |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | **A1** | `POST /auth/signup` | Supabase Auth SDK | `public.profiles` trigger | `supabase.auth.signUp()` |
| 2 | **A2** | `POST /auth/verify-email` | Supabase Auth SDK | None | `supabase.auth.verifyOTP()` |
| 3 | **A3** | `POST /auth/resend-otp` | Supabase Auth SDK | None | `supabase.auth.resend()` |
| 4 | **A4** | `POST /auth/login` | Supabase Auth SDK | None | `supabase.auth.signInWithPassword()` |
| 5 | **A5** | `POST /auth/forgot-password` | Supabase Auth SDK | None | `supabase.auth.resetPasswordForEmail()` |
| 6 | **A6** | `POST /auth/reset-password` | Supabase Auth SDK | None | `supabase.auth.updateUser()` |
| 7 | **A7** | `POST /auth/refresh-token` | Supabase Auth SDK | None | GoTrue auto-refresh session |
| 8 | **A8** | `POST /auth/google-login` | Supabase Auth SDK | `public.profiles` trigger | `supabase.auth.signInWithIdToken()` |
| 9 | **A9** | `POST /auth/apple-login` | Excluded Feature | None | Excluded from scope |
| 10 | **A10**| `POST /auth/logout` | Supabase Auth SDK | Hive clear cache | `supabase.auth.signOut()` |
| 11 | **B1** | `GET /users/me` | Supabase Auth SDK | `public.profiles` query | `auth.currentUser` + `profiles` query |
| 12 | **B2** | `PUT /users/me` | PostgREST Table Update | `auth.users` metadata | `UPDATE public.profiles` |
| 13 | **B3** | `PUT /users/me/password` | Supabase Auth SDK | None | `supabase.auth.updateUser()` |
| 14 | **B4** | `PUT /users/me/email` | Supabase Auth SDK | None | `supabase.auth.updateUser()` |
| 15 | **B5** | `DELETE /users/me` | Security Definer RPC | Cascade DB & Storage | RPC `delete_user_account()` |
| 16 | **F1** | `GET /family-members` | PostgREST Table Query | None | `SELECT * FROM public.profiles` |
| 17 | **F2** | `GET /family-members/{id}` | PostgREST Table Query | None | `SELECT * FROM public.profiles WHERE id = :id` |
| 18 | **F3** | `POST /family-members` | PostgREST Table Insert | Client UUID | `INSERT INTO public.profiles` |
| 19 | **F4** | `PUT /family-members/{id}` | PostgREST Table Update | None | `UPDATE public.profiles WHERE id = :id` |
| 20 | **F5** | `DELETE /family-members/{id}`| PostgREST Table Delete | Cascade child records | `DELETE FROM public.profiles WHERE id = :id` |
| 21 | **F6** | `POST /family-members/{id}/photo` | Supabase Storage Bucket | `public.profiles` update | `storage.from('avatars').upload()` |
| 22 | **F7** | `GET /family/dashboard` | Local Hive Aggregation | None | `HomeRepository.getHomeSummary` |
| 23 | **F8** | `GET /family/analytics` | Local Hive Aggregation | None | `AnalyticsRepository.getInsightsSummary` |
| 24 | **D1** | `GET /doctors` | PostgREST Table Query | None | `SELECT * FROM public.doctors` |
| 25 | **D2** | `POST /doctors` | PostgREST Table Insert | Client UUID | `INSERT INTO public.doctors` |
| 26 | **D3** | `GET /doctors/{id}` | PostgREST Table Query | Joined relations | `SELECT * FROM public.doctors WHERE id = :id` |
| 27 | **D4** | `PUT /doctors/{id}` | PostgREST Table Update | None | `UPDATE public.doctors WHERE id = :id` |
| 28 | **D5** | `DELETE /doctors/{id}` | PostgREST Table Delete | Preserve doctor name | `DELETE FROM public.doctors WHERE id = :id` |
| 29 | **H1** | `GET /hospitals` | PostgREST Table Query | None | `SELECT * FROM public.hospitals` |
| 30 | **H2** | `POST /hospitals` | PostgREST Table Insert | Client UUID | `INSERT INTO public.hospitals` |
| 31 | **H3** | `GET /hospitals/{id}` | PostgREST Table Query | Joined relations | `SELECT * FROM public.hospitals WHERE id = :id` |
| 32 | **H4** | `PUT /hospitals/{id}` | PostgREST Table Update | None | `UPDATE public.hospitals WHERE id = :id` |
| 33 | **H5** | `DELETE /hospitals/{id}` | PostgREST Table Delete | Preserve facility name | `DELETE FROM public.hospitals WHERE id = :id` |
| 34 | **MD1**| `GET /medical-departments` | PostgREST Table Query | Public reference | `SELECT * FROM public.medical_departments` |
| 35 | **C1** | `GET /consultations` | PostgREST Table Query | None | `SELECT * FROM public.consultations` |
| 36 | **C2** | `POST /consultations` | PostgREST Table Insert | Storage upload for files | `INSERT INTO public.consultations` |
| 37 | **C3** | `GET /consultations/{id}` | PostgREST Table Query | Eager load relations | `SELECT * FROM public.consultations WHERE id = :id` |
| 38 | **C4** | `PUT /consultations/{id}` | PostgREST Table Update | None | `UPDATE public.consultations WHERE id = :id` |
| 39 | **C5** | `DELETE /consultations/{id}` | PostgREST Table Delete | Nullify foreign keys | `DELETE FROM public.consultations WHERE id = :id` |
| 40 | **C6** | `GET /consultations/{id}/files/{f}` | Supabase Storage Bucket | `public.consultations` RLS | `storage.from('consultations').createSignedUrl()` |
| 41 | **AP1**| `GET /appointments` | PostgREST Table Query | None | `SELECT * FROM public.appointments` |
| 42 | **AP2**| `POST /appointments` | PostgREST Table Insert | Local reminder alarm | `INSERT INTO public.appointments` |
| 43 | **AP3**| `GET /appointments/{id}` | PostgREST Table Query | None | `SELECT * FROM public.appointments WHERE id = :id` |
| 44 | **AP4**| `PUT /appointments/{id}` | PostgREST Table Update | Local alarm update | `UPDATE public.appointments WHERE id = :id` |
| 45 | **AP5**| `DELETE /appointments/{id}` | PostgREST Table Delete | Cancel local alarm | `DELETE FROM public.appointments WHERE id = :id` |
| 46 | **R1** | `GET /reports` | PostgREST Table Query | None | `SELECT * FROM public.reports` |
| 47 | **R2** | `POST /reports` | PostgREST Table Insert | Storage upload for files | `INSERT INTO public.reports` |
| 48 | **R3** | `GET /reports/{id}` | PostgREST Table Query | Joined expense & files | `SELECT * FROM public.reports WHERE id = :id` |
| 49 | **R4** | `PUT /reports/{id}` | PostgREST Table Update | None | `UPDATE public.reports WHERE id = :id` |
| 50 | **R5** | `DELETE /reports/{id}` | PostgREST Table Delete | Storage blob purge | `DELETE FROM public.reports WHERE id = :id` |
| 51 | **R6** | `GET /reports/{id}/files/{f}` | Supabase Storage Bucket | `public.reports` RLS | `storage.from('reports').createSignedUrl()` |
| 52 | **M1** | `GET /medicines` | PostgREST Table Query | None | `SELECT * FROM public.prescriptions` |
| 53 | **M2** | `POST /medicines` | PostgREST Table Insert | Local reminder alarm | `INSERT INTO public.prescriptions` |
| 54 | **M3** | `GET /medicines/{id}` | PostgREST Table Query | Joined consultation | `SELECT * FROM public.prescriptions WHERE id = :id` |
| 55 | **M4** | `PUT /medicines/{id}` | PostgREST Table Update | Local alarm update | `UPDATE public.prescriptions WHERE id = :id` |
| 56 | **M5** | `DELETE /medicines/{id}` | PostgREST Table Delete | Cancel local alarm | `DELETE FROM public.prescriptions WHERE id = :id` |
| 57 | **V1** | `POST /vitals` | PostgREST Table Insert | V0 whitelist enum check | `INSERT INTO public.measurements` |
| 58 | **V2** | `GET /vitals` | PostgREST Table Query | None | `SELECT * FROM public.measurements` |
| 59 | **V3** | `GET /vitals/{id}` | PostgREST Table Query | None | `SELECT * FROM public.measurements WHERE id = :id` |
| 60 | **V4** | `PUT /vitals/{id}` | PostgREST Table Update | BMI immutability check | `UPDATE public.measurements WHERE id = :id` |
| 61 | **V5** | `DELETE /vitals/{id}` | PostgREST Table Delete | None | `DELETE FROM public.measurements WHERE id = :id` |
| 62 | **AN1**| `GET /analytics` | Local Hive Aggregation | None | `AnalyticsRepository.getInsightsSummary` |
| 63 | **DB1**| `GET /dashboard` | Local Hive Aggregation | None | `HomeRepository.getHomeSummary` |
| 64 | **T1** | `GET /timeline` | Local Hive Aggregation | None | `TimelineRepository.getTimelineFeed` |

### Proof of Mathematical Integrity

$$\sum \text{Primary Endpoints} = 42\text{ (PostgREST)} + 12\text{ (Auth)} + 5\text{ (Local Hive)} + 3\text{ (Storage)} + 1\text{ (RPC)} + 1\text{ (Excluded)} = \mathbf{64}$$

- **Unique IDs:** 64
- **Duplicate IDs:** 0
- **Omitted IDs:** 0

---

## 5. Governance Statement & Phase 4 Readiness

1. **Reconciliation Complete:**
   The API Disposition Matrix (`docs/active/MEDICRATE_PHASE3B_4_3_1_API_AND_FEATURE_DISPOSITION_MATRIX.md`) is now fully reconciled, mathematically verified, and free of count contradictions.
2. **Read-Only Compliance Maintained:**
   MediVault reference repository `/home/blackhat/Documents/Reubro/medivalut` was accessed in strictly read-only mode. No modifications were made to reference files.
3. **Application Integrity Maintained:**
   No application source code, unit/widget tests, configuration files, `.env` secrets, or remote Supabase infrastructure have been modified or executed.
4. **Phase 4.1 Boundary Preserved:**
   Database implementation, DDL migration execution, table creation, and Supabase CLI push commands remain completely unstarted. All work in this phase was strictly confined to documentation correction and verification.

---

*Report Approved by: Antigravity AI – Senior Migration Architecture Agent*  
*Distribution: `docs/governance/`, `docs/active/`*  
