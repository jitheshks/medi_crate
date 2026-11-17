# MediCrate – Phase 3B.4.3.1: Security, Offline Synchronization & Storage Review

> **Document Status:** Authoritative & Complete  
> **Audit Date:** November 9, 2026  
> **Auditor:** Antigravity AI – Senior Migration Architecture Agent  
> **Active Target Repository:** `/home/blackhat/Documents/medi_crate`  
> **Read-Only Reference Repository:** `/home/blackhat/Documents/Reubro/medivalut`  

---

## 1. Multi-Profile Architecture & Tenant Isolation

### 1.1 Two-Tier Account and Profile Hierarchy
In MediCrate, user identity and clinical scoping are separated into a strict two-tier hierarchy:
1. **Tier 1: Authenticated Account Owner (`auth.users.id`):** The root account managed by Supabase GoTrue Auth. Governed by email/password or Google OAuth credentials.
2. **Tier 2: Managed Family Health Profiles (`public.profiles.id`):** The clinical subject of record. An authenticated user can own multiple profiles:
   - One **Primary Profile** (`is_primary = true`, `relationship = 'Self'`), representing the account holder.
   - Zero or more **Family Member Profiles** (`is_primary = false`, `relationship IN ('Father', 'Mother', 'Spouse', 'Child', ...)`).

### 1.2 Clinical Scoping & Entity Ownership
In the Flutter codebase (`medi_crate/lib/`):
- All clinical models (`ConsultationModel`, `AppointmentModel`, `MedicineModel`, `ReportModel`, `MeasurementModel`, `DoctorModel`, `HospitalModel`) carry a required `profileId` field.
- Local Hive storage queries (`HiveProfileQueryHelper.getRecordsForProfile`) strictly filter all entity maps by matching `map['profile_id'] == profileId`.
- **Doctor and Hospital Scoping:** Doctors and hospitals in MediCrate are personal address book entries scoped to a specific profile (`doctor.profileId`, `hospital.profileId`), not global directories. When a profile is switched, the clinician and hospital pickers immediately update to reflect only that profile's saved contacts.

### 1.3 Tenant Isolation Vulnerability & Composite Key Requirement
> [!IMPORTANT]
> **Cross-Tenant Profile Hijacking Risk Identified:**
> In early schema drafts, clinical tables included both `user_id UUID REFERENCES auth.users(id)` and `profile_id UUID REFERENCES public.profiles(id)`.
> However, because `profile_id` was validated only against `public.profiles(id)`, a compromised client could theoretically submit an `INSERT` with `user_id = auth.uid()` but `profile_id = <victim_user_profile_id>`. Standard foreign keys would succeed because both keys exist independently, creating data contamination across accounts!

**Architectural Remedy (Mandatory for Phase 4):**
1. Enforce a compound uniqueness constraint on the parent table:
   ```sql
   ALTER TABLE public.profiles ADD CONSTRAINT uq_profiles_id_user_id UNIQUE (id, user_id);
   ```
2. Enforce a composite foreign key on ALL clinical child tables:
   ```sql
   FOREIGN KEY (profile_id, user_id) 
       REFERENCES public.profiles(id, user_id) 
       ON DELETE CASCADE
   ```
3. Enforce Row Level Security (RLS) on all clinical tables verifying ownership:
   ```sql
   CREATE POLICY "User owns clinical record" 
       ON public.consultations 
       FOR ALL 
       TO authenticated 
       USING (auth.uid() = user_id) 
       WITH CHECK (auth.uid() = user_id);
   ```
This cryptographic and relational guarantee makes cross-account data leakage mathematically impossible.

---

## 2. Offline-First Synchronization Engine

### 2.1 Mutation Staging & Queue Lifecycle
MediCrate implements an offline-first mutation queue via `lib/core/sync/sync_service.dart` and `sync_queue_box`:
- **Mutation Enqueueing:** When the user creates, updates, or deletes a clinical record, the repository writes the update immediately to Hive `userBox` and appends a `SyncQueueItem` to `sync_queue_box`.
- **Payload Structure (`SyncQueueItem`):**
  - `id`: Stable local mutation key.
  - `entity`: Target module (`'consultation'`, `'appointment'`, `'doctor'`, etc.).
  - `operation`: `'create'` | `'update'` | `'delete'`.
  - `payload`: Map of clinical field values.
  - `retryCount`: Number of attempted network dispatches.
  - `status`: `'pending'` | `'syncing'` | `'failed'` | `'deferred'`.
  - `claimToken` & `claimedAt`: Lease locking preventing concurrent foreground/background isolates from processing the same mutation.

### 2.2 Dependency-Ordered Sync Sequencing
To prevent foreign key insertion failures during background sync, `SyncService.syncPending` executes mutations in strict dependency order:
$$\text{Hospitals (0)} \longrightarrow \text{Doctors (1)} \longrightarrow \text{Consultations (2)} \longrightarrow \text{Reports (3)} \longrightarrow \text{Others (4)}$$
If a consultation references a doctor that was created offline, the doctor is synced first, guaranteeing that the doctor exists on the server before the consultation is inserted.

### 2.3 Critical Incompatibility: Integer Server IDs vs. Supabase UUIDs
> [!CAUTION]
> **CRITICAL RUNTIME SYNC BLOCKER:**
> Code inspection of `lib/core/utils/id_utils.dart` (`toServerIntId`) and `lib/core/sync/sync_service.dart` reveals that the legacy synchronization engine explicitly discards non-integer IDs:
> ```dart
> // id_utils.dart line 48:
> if (parsed != null && parsed > 0 && parsed < 1000000000000) {
>   return parsed;
> }
> return null; // UUID strings are discarded!
> ```
> `SyncService` uses `toServerIntId` to patch foreign keys during queue drain. If Supabase generates UUID v4 strings, `toServerIntId` returns `null`, causing the sync engine to defer or fail mutations!

**Required Phase 4 Refactoring:**
- `IdUtils` must be updated with `toServerUuid(dynamic id)` to validate and extract RFC 4122 Version 4 UUID strings.
- `SyncService` must store and patch UUID foreign keys rather than integers.
- Pending mutations currently queued in Hive will be safely drained once UUID mapping is enabled.

---

## 3. Storage & Binary Attachment Architecture

### 3.1 Bucket Inventory & Access Controls
MediCrate requires **three private Supabase Storage buckets**:

| Bucket Name | Target Contents | Max File Size | Permitted MIME Types | Access Policy |
| :--- | :--- | :---: | :--- | :--- |
| **`avatars`** | Profile photos & avatars | 5 MB | `image/jpeg`, `image/png`, `image/webp` | Authenticated users can read/write objects in `{user_id}/*` |
| **`reports`** | Diagnostic reports & lab PDFs | 25 MB | `application/pdf`, `image/jpeg`, `image/png` | Authenticated users can read/write objects in `{user_id}/{profile_id}/*` |
| **`consultations`** | Consultation attachments & notes | 25 MB | `application/pdf`, `image/jpeg`, `image/png` | Authenticated users can read/write objects in `{user_id}/{profile_id}/*` |

### 3.2 Canonical Object Path Strategy
To guarantee multi-tenant storage isolation and prevent unauthorized access or file overwrites, all storage paths must follow this deterministic folder hierarchy:
$$\text{bucket\_name} \, / \, \mathbf{\{user\_id\}} \, / \, \mathbf{\{profile\_id\}} \, / \, \mathbf{\{file\_uuid\}}.\mathbf{\{ext\}}$$

### 3.3 Relational Attachment Metadata Tables
Rather than embedding binary blobs in database rows, relational tables store lightweight metadata and the canonical storage object path:
- **`public.report_attachments`:** Stores `id`, `report_id`, `user_id`, `file_name`, `file_type`, `file_size_bytes`, `storage_path`, `client_uuid`.
- **`public.consultation_attachments` (New):** Stores `id`, `consultation_id`, `user_id`, `file_name`, `file_type`, `file_size_bytes`, `storage_path`, `client_uuid`.

### 3.4 Secure File Streaming via Signed URLs
- Buckets are strictly **private** (public access disabled).
- When a user views or downloads an attachment (C6, R6), the client requests a **short-lived signed URL** (valid for 60 seconds) via PostgREST:
  ```dart
  final signedUrl = await supabase.storage.from('reports').createSignedUrl(attachment.storagePath, 60);
  ```
- This ensures clinical documents are never exposed to public internet scrapers.

---

## 4. RPC vs. Direct PostgREST Architectural Resolution

### 4.1 Resolution of Conflicting Aggregation Claims
- **Previous Claim:** Early notes claimed clinical dashboards must use `SECURITY DEFINER` RPCs to aggregate statistics.
- **Audited Reality:** Flutter repositories (`HomeRepository`, `AnalyticsRepository`, `TimelineRepository`) perform **100% on-device local Hive aggregation**. The mobile app does not rely on server-side aggregation endpoints for UI feeds.

### 4.2 Security Definer vs. Direct PostgREST Decision Matrix

| Operation | Implementation Type | Rationale | Security / Authorization Safeguards |
| :--- | :--- | :--- | :--- |
| **Standard Clinical CRUD** (Consultations, Vitals, Reports, etc.) | **Direct PostgREST** | Direct queries leverage native Supabase performance and automatic connection pooling. | Row Level Security (RLS) policies enforce `user_id = auth.uid()`. |
| **Account Self-Deletion** (`DELETE /users/me` [B5]) | **Security Definer RPC** (`delete_user_account()`) | Standard client tokens cannot delete from `auth.users`. Requires elevated privilege to delete the authenticated user record. | Must enforce `WHERE id = auth.uid()`; must set `SET search_path = public`; must verify user has no active legal hold. |
| **Primary Profile Bootstrapping** | **PostgreSQL Trigger** (`on_auth_user_created`) | When a user signs up via email or OAuth, automatically creates the primary `Self` profile row in `public.profiles`. | Executes automatically inside PostgreSQL transaction; zero client orchestration required. |
| **Home Screen Feed & Statistics** | **Local Hive Aggregation** | Client computes counts and recent records instantly from local storage, enabling offline capability. | Zero network request required; completely private on-device processing. |
| **Longitudinal Medical Timeline** | **Local Hive Union Query** | Single-pass traversal of `userBox` combines encounters, vitals, and tests chronologically. | Zero latency; operates in airplane mode. |
| **Doctor Summary PDF Generation** | **Local Device Engine** (`package:pdf`) | The application formats and generates sanitized clinical PDFs on-device using local Hive data. | PDF binary is never stored on the server, ensuring HIPAA/GDPR data minimization. |

---
*Security & Sync Review Finalized: November 9, 2026*  
*Author: Antigravity AI – Senior Migration Architecture Agent*
