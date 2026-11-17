# MediCrate — Implementation 7.0: Native Offline-First Synchronization Verification Report

## Executive Summary

As part of **Implementation 7.0**, the native offline-first Supabase synchronization subsystem of MediCrate was subjected to rigorous end-to-end integration verification against the live hosted Supabase Tokyo instance (`wnaflcytkubqmrymbmcn`, PostgreSQL 17.11).

The synchronization architecture was verified across all **eight synchronized domains**, testing complete offline mutation queuing, coalescing, network reconnection dispatch, Storage asset synchronization, idempotency, foreign key dependency ordering, profile/session isolation, and failure recovery.

**Safety Guardrails Confirmed:**
- `SyncService.isRemoteSyncEnabled` remains **`false`** (default production state).
- `BackgroundSyncService.isBackgroundSyncEnabled` remains **`false`**.
- Zero production Hive boxes were opened, cleared, consumed, or touched.
- All testing utilized dedicated temporary Hive storage directories (`Directory.systemTemp`), disposable authentication test accounts (`sync_user_*@fldubai.com`), and test-scoped `IsolatedHiveService` instances.
- Upon completion of test runs, all disposable authentication users, clinical entities, and storage objects were completely purged from the hosted instance.

---

## 1. Synchronization Architecture Verified

The MediCrate offline-first synchronization subsystem operates on an active-lease, transactional queue model:

```
[UI / Feature Repository]
        │
        ▼ (Local writes to Hive & provisional UUIDs)
[Hive userBox / syncQueueBox]
        │
        ▼ (QueueCoalescer collapses pending mutations: create+update -> create; create+delete -> cancel)
[QueueCoalescer]
        │
        ▼ (SyncLock mutual exclusion with 15-minute lease & heartbeat renewal)
[SyncLock Lease Manager]
        │
        ▼ (Topological domain sorting: Profiles -> Hospitals -> Doctors -> Consultations -> Reports / Appointments / Prescriptions / Measurements)
[SupabaseSyncCoordinator]
        │
   ┌────┴──────────────────────────┐
   ▼                               ▼
[PostgREST Data Sources]     [SupabaseStorageService]
(8 Synchronized Domains)     (Private 'reports' & 'consultations' buckets)
```

### Components Inspected & Validated:
1. **`SyncService` (`lib/core/sync/sync_service.dart`)**:
   - Manages queue lifecycle, connectivity listening (`ConnectivityService`), priority sorting, and guarded dispatch.
   - Enforces the `isRemoteSyncEnabled` kill-switch: skips remote push unless explicitly overridden by `force: true` in controlled test runners.
2. **`BackgroundSyncService` (`lib/core/sync/background_sync_service.dart`)**:
   - Headless background worker registration (`Workmanager`).
   - Guarded by `isBackgroundSyncEnabled` which dynamically mirrors `SyncService.isRemoteSyncEnabled` (currently `false`).
3. **`SupabaseSyncCoordinator` (`lib/core/sync/supabase_sync_coordinator.dart`)**:
   - Authoritative dispatcher for queued mutations to PostgreSQL tables (`profiles`, `hospitals`, `doctors`, `consultations`, `reports`, `report_attachments`, `report_expenses`, `appointments`, `prescriptions`, `measurements`).
   - Resolves provisional local IDs (`hosp_offline_1`, `prof_local_1`) into server UUIDs via `client_uuid` and `userBox` reconciliation.
   - Manages attachment file upload to private Supabase Storage buckets before persisting child attachment metadata.
4. **`QueueCoalescer` (`lib/core/sync/queue_coalescer.dart`)**:
   - Implements offline queue optimization rules:
     - `create` + `update` -> collapsed `create` with latest merged state.
     - `create` + `delete` (unreached on server) -> zero remote traces (both discarded).
     - `update` + `update` -> latest merged `update`.
     - `update` + `delete` -> single `delete`.
5. **`SyncLock` (`lib/core/sync/sync_lock.dart`)**:
   - Atomic distributed lease mechanism using Hive metadata to prevent concurrent execution between foreground resume and background worker tasks.
6. **Retry, Backoff & Dead-Lettering**:
   - Permanent schema/constraint violations (PostgreSQL error codes `23514`, `22P02`, `ValidationException`) immediately dead-letter (`status = 'failed'`, `retryCount = 99`).
   - Foreign key dependencies (`23503`) defer execution until parent entities sync, preserving retry budgets.
   - Auth expirations (`42501`, `UnauthorizedException`) set `status = 'auth_required'` without consuming retry counts.

---

## 2. Test Harness & Isolation Strategy

To ensure zero impact on production queues or user data:
1. **Temporary Isolated Hive Storage**:
   - Each test run dynamically constructs a sandbox Hive environment in `/tmp/medi_crate_sync_test_<timestamp>/`.
   - Boxes created: `test_auth_*`, `test_sync_queue_*`, `test_user_*`, `test_settings_*`, `test_consent_*`, `test_profile_*`.
   - Production Hive boxes remain completely unopened.
2. **Dedicated Disposable Test Accounts**:
   - Two disposable accounts created dynamically per run: `sync_user_a_<timestamp>@fldubai.com` and `sync_user_b_<timestamp>@fldubai.com`.
   - Confirmed via administrative SQL (`email_confirmed_at = NOW()`).
   - User A owns primary profile and family profiles; User B verifies cross-account isolation and RLS rejection.
3. **Dedicated End-to-End Test Suite**:
   - Implemented in `test/integration/native_sync_verification_e2e_test.dart` (1,249 lines).
   - Contains 24 distinct integration test cases structured across 6 verification groups.

---

## 3. Test Results Across All Verification Groups

### Group 1: Core Offline-First Lifecycle (CREATE, UPDATE, DELETE)
- **1.1 Offline CREATE -> reconnect -> remote persistence in PostgreSQL**: **PASSED**
  - Queued hospital while disconnected; verified zero remote records.
  - Reconnected and synced; verified row created in `public.hospitals` with matching fields and `client_uuid`.
- **1.2 Offline UPDATE -> reconnect -> remote PostgreSQL row updated**: **PASSED**
  - Queued update to hospital while disconnected.
  - Reconnected and synced; verified `name`, `type`, and `address` updated remotely.
- **1.3 Offline DELETE -> reconnect -> remote PostgreSQL row deleted**: **PASSED**
  - Queued delete while disconnected; reconnected and verified row purged from hosted PostgreSQL.

### Group 2: Queue Coalescing & Durability
- **2.1 CREATE + UPDATE coalescing collapses to a single CREATE**: **PASSED**
  - Queued local hospital creation followed by an update while offline.
  - Verified queue length remained **1**; payload held latest merged state (`Coalesced Final Hospital Name`).
  - On reconnect, single insert occurred remotely.
- **2.2 CREATE + DELETE before upload cancels out entirely (CASE B)**: **PASSED**
  - Queued doctor creation followed by deletion while offline.
  - Verified queue length immediately dropped to **0**; zero remote traces created in PostgreSQL.
- **2.3 Multiple UPDATE operations collapse to latest update**: **PASSED**
  - Queued multiple consecutive updates for existing hospital; verified queue held only the final state.
- **2.4 Duplicate replay and client_uuid idempotency**: **PASSED**
  - Replayed identical create mutation twice; verified PostgreSQL contained exactly **1** row without duplication.

### Group 3: All Eight Synchronized Domains & Dependency Ordering
- **3.1 Domain 1: Profiles (family member creation & archival)**: **PASSED**
  - Family sub-profile created with relationship `'Son'`, verified in `public.profiles`.
- **3.2 Domain 2: Hospitals (facility creation & update)**: **PASSED**
  - Facility created and linked to family profile UUID.
- **3.3 Domain 3: Doctors (clinician creation & hospital association)**: **PASSED**
  - Clinician created with M:N hospital association in `hospital_ids`.
- **3.4 Domain 4: Consultations (visit record linked to doctor and hospital)**: **PASSED**
  - Consultation created with foreign keys to doctor, hospital, and profile.
- **3.5 Domain 5: Reports (diagnostic report linked to consultation)**: **PASSED**
  - Report created and linked to consultation and profile.
- **3.6 Domain 6: Appointments (clinical appointment linked to doctor & hospital)**: **PASSED**
  - Appointment created and verified in `public.appointments`.
- **3.7 Domain 7: Medicines / Prescriptions (medication linked to consultation)**: **PASSED**
  - Prescription created and linked to consultation in `public.prescriptions`.
- **3.8 Domain 8: Vitals / Measurements (vital readings with immutable recorded_at)**: **PASSED**
  - Blood pressure measurement created; UTC timestamp equivalence validated.
- **3.9 Parent-Child Dependency Ordering**: **PASSED**
  - Queued Doctor (priority 2) before Hospital (priority 1) while offline.
  - Topological queue prioritization processed Hospital first, satisfying foreign keys without failure.

### Group 4: Storage Lifecycle & Attachment Resilience
- **4.1 Report attachment upload (local file uploaded to private bucket with signed URL access)**: **PASSED**
  - Queued report with local attachment on disk (`blood_work_sample.pdf`).
  - Coordinator uploaded file to private `reports` bucket under object path `{userId}/{reportId}/{attachmentId}_{filename}`.
  - Persisted bucket relative path in `public.report_attachments.file_path`.
  - Generated temporary signed URL and verified file downloaded cleanly with HTTP 200 via unauthenticated client.
- **4.2 Report deletion cleans up both PostgreSQL records and Storage object**: **PASSED**
  - Queued report deletion; verified report and attachment metadata deleted from PostgreSQL.
  - Verified Storage file was purged from the `reports` bucket.

### Group 5: Session & Profile Isolation, Account Switching
- **5.1 User A cannot sync items with User B profile ID**: **PASSED**
  - User A attempted to sync item with User B's profile ID; mutation rejected by coordinator and PostgreSQL RLS.
  - Verified zero data leaked or created under User B's account.
- **5.2 Unauthenticated session sets status to auth_required without consuming retry budget**: **PASSED**
  - Attempted sync without valid session; item marked `status = 'auth_required'`, retry count remained **0**.

### Group 6: Concurrency Control, SyncLock, Heartbeat & Recovery
- **6.1 SyncLock mutual exclusion prevents concurrent worker execution**: **PASSED**
  - Worker 1 acquired lock; Worker 2 blocked from concurrent execution until Worker 1 released.
- **6.2 SyncLock renew extends valid lease window**: **PASSED**
  - Successfully refreshed active lease token.
- **6.3 Dead-letter behavior (check constraint violation immediately dead-letters)**: **PASSED**
  - Invalid entity (empty name) failed check constraint; immediately marked `status = 'failed'`, `retryCount = 99`.
- **6.4 Application restart & queue recovery restores and processes pending mutations**: **PASSED**
  - Pending mutation saved to Hive; new `SyncService` instance initialized (simulating cold app start); mutation reloaded and processed to completion.

---

## 4. Test Suite Execution Summary

| Test Suite | Total Tests | Passed | Failed | Status |
| :--- | :---: | :---: | :---: | :---: |
| `test/integration/native_sync_verification_e2e_test.dart` (Hosted Tokyo Supabase E2E) | 24 | 24 | 0 | **100% PASS** |
| `test/core/sync/supabase_native_synchronization_test.dart` | 20 | 20 | 0 | **100% PASS** |
| `test/core/sync/sync_safety_and_mutation_dispatch_test.dart` | 23 | 23 | 0 | **100% PASS** |
| `test/core/sync/synchronization_safety_corrections_test.dart` | 12 | 12 | 0 | **100% PASS** |
| **Total Synchronized Test Inventory** | **79** | **79** | **0** | **100% PASS** |

---

## 5. Bugs Identified & Surgical Fixes Applied

During E2E validation against the real hosted Supabase Tokyo environment, 4 architectural inconsistencies were identified and resolved:

1. **Storage Relative Path vs Local Filesystem Path in `ReportAttachmentModel` & `ConsultationAttachment`**:
   - *Problem*: `toSupabaseJson` was serializing `file_path: filePath ?? fileUrl`. When an attachment was created offline, `filePath` was the local path on device (`/tmp/...`). This stored the device's local file path into PostgreSQL `report_attachments.file_path` instead of the bucket-relative Storage path.
   - *Fix*: In `ReportAttachmentModel.toSupabaseJson` and `ConsultationAttachment.toSupabaseJson`, added path normalization that prioritizes remote bucket paths (`userId/parentId/...`) over local absolute paths (`/...` or `file:...`).
2. **Attachment Upload Detection Invariant in `SupabaseSyncCoordinator`**:
   - *Problem*: Line 1473 checked `!att.fileUrl!.contains('/')`. Because local filesystem paths also contain slashes (`/tmp/...`), local attachments were incorrectly detected as already uploaded and skipped.
   - *Fix*: Enhanced condition to explicitly check whether `att.fileUrl` is a valid remote storage path (`att.fileUrl!.startsWith('/') || att.fileUrl!.startsWith('file:') || !att.fileUrl!.contains('/')`) to ensure local files are always uploaded.
3. **Prescription Consultation Linkage Deserialization in `MedicineModel`**:
   - *Problem*: `MedicineModel.fromJson` only checked `json['linked_consultation_id']`, whereas Supabase PostgREST uses `consultation_id`. Also, `json['name']` was not checked as a fallback for medication name.
   - *Fix*: Updated `MedicineModel.fromJson` to read `(json['linked_consultation_id'] ?? json['consultation_id'])` and `(json['medicine_name'] ?? json['medication_name'] ?? json['name'])`.
4. **Appointment ID Normalization**:
   - *Problem*: `AppointmentModel.fromSupabaseJson` prefixes IDs with `'appointment_'` for local caching parity, causing exact string equality against pure UUIDs to fail in tests.
   - *Fix*: Standardized lookups to use `IdUtils.matches(a.id, expectedUuid) || a.clientUuid == expectedUuid`.

---

## 6. Remote Database State Verification

Following the completion of the verification suite, the hosted Supabase Tokyo database was queried via `supabase db query --linked`:

```json
{
  "sync_profiles": 0,
  "sync_test_users": 0,
  "total_appointments": 0,
  "total_consultations": 0,
  "total_doctors": 0,
  "total_hospitals": 0,
  "total_measurements": 0,
  "total_medical_departments": 79,
  "total_prescriptions": 0,
  "total_report_attachments": 0,
  "total_reports": 0,
  "remaining_storage_objects": 0
}
```

- **0 test users** remain in `auth.users`.
- **0 test clinical records** remain in any table.
- **0 test objects** remain in `storage.objects`.
- **All 79 canonical medical departments** seeded in Migration 6 remain intact.

---

## 7. Controlled Activation Readiness & Guardrails

The native synchronization subsystem is verified, resilient, and architecturally complete. However, to guarantee absolute safety for production users:

1. **`SyncService.isRemoteSyncEnabled` is currently `false`** and will remain `false` until an explicit rollout instruction is received.
2. **`BackgroundSyncService.isBackgroundSyncEnabled` is currently `false`** and will remain `false`.
3. To safely activate synchronization in future phases:
   - Ensure local user data has completed Phase 3 migration if applicable.
   - Set `SyncService.isRemoteSyncEnabled = true` in `lib/core/sync/sync_service.dart`.
   - The coordinator will automatically acquire `SyncLock`, drain pending offline mutations, and maintain real-time sync with hosted Supabase.
