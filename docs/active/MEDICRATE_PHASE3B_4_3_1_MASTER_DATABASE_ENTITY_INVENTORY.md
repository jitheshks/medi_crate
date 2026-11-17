# MediCrate – Phase 3B.4.3.1: Master Database Entity Inventory & Classification

> **Document Status:** Authoritative & Complete  
> **Audit Date:** November 9, 2026  
> **Auditor:** Antigravity AI – Senior Migration Architecture Agent  
> **Active Target Repository:** `/home/blackhat/Documents/medi_crate`  
> **Read-Only Reference Repository:** `/home/blackhat/Documents/Reubro/medivalut`  

---

## 1. Executive Summary

This document establishes the definitive, reconciled **Master Database Entity Inventory** for MediCrate's migration to Supabase.

By rigorously cross-referencing the legacy Laravel database specifications (`DATABASE_DESIGN.md`), Flutter data models (`medi_crate/lib/`), Hive local storage boxes, and previous draft schema requirements, this inventory resolves the ambiguity surrounding table counts and candidate entities.

### Key Inventory Findings
1. **Resolved PostgreSQL Table Count:** Exactly **13 production tables** are required in PostgreSQL (public schema). This adds `public.consultation_attachments` to the 12 tables drafted in Phase 3B.4.3.0, ensuring full parity with `lib/features/consultations/` and endpoint `C6`.
2. **Identity & Auth Boundary:** The root user account entity is strictly delegated to `auth.users` in Supabase GoTrue Auth. No separate `public.users` table is required, avoiding duplicate user state.
3. **Local-Only Exclusions:** User preferences (`user_settings`), privacy consent records (`consent_records`), offline sync mutations (`sync_mutations`), and notification schedules operate **100% locally on-device** in Hive and SharedPreferences; they do NOT require server-side database tables.
4. **Binary Assets vs. Database Rows:** Document attachments and avatar photos are stored in **Supabase Storage buckets**, with lightweight relational metadata tables tracking file ownership, sizes, and MIME types.

---

## 2. Reconciled Master Entity Matrix

The table below reconciles all legacy, local, and candidate entities, providing definitive classifications and implementation recommendations:

| Entity | Legacy Evidence | Flutter Model / Local Storage | Existing Schema Specification | Required Purpose | Recommendation | Confidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **`auth_users`** | `users` table (`DATABASE_DESIGN.md` L214) | Stored in `authBox` / `SecureStorageService` | Managed by Supabase Auth (`auth.users`) | Root account credentials, email verification, session tokens, and OAuth IDs | **Supabase Auth-managed** (No custom table) | High |
| **`profiles`** | `profiles` & `user_profiles` (`DATABASE_DESIGN.md` L237, L258; F1–F5) | `ProfileModel` (`profile_box`, `userBox`) | Detailed in Schema Req Table #1 (`public.profiles`) | Multi-profile family records; root clinical scope for all health data | **Required table** (`public.profiles`) | High |
| **`medical_departments`** | `GET /medical-departments` (`MD1`; `DATABASE_DESIGN.md`) | `MedicalDepartmentModel` (`medicalDepartmentBox`) | Detailed in Schema Req Table #2 (`public.medical_departments`) | Controlled reference list of medical specialties (Cardiology, Pediatrics, etc.) | **Required table** (`public.medical_departments`) | High |
| **`hospitals`** | `hospitals` table (`DATABASE_DESIGN.md` L317; H1–H5) | `HospitalModel` (`userBox` with `hospital_` prefix) | Detailed in Schema Req Table #3 (`public.hospitals`) | Healthcare facilities, clinics, and diagnostic centers saved by user | **Required table** (`public.hospitals`) | High |
| **`doctors`** | `doctors` table (`DATABASE_DESIGN.md` L290; D1–D5) | `DoctorModel` (`userBox` with `doctor_` prefix) | Detailed in Schema Req Table #4 (`public.doctors`) | Attending physicians, clinicians, and medical specialists | **Required table** (`public.doctors`) | High |
| **`doctor_hospitals`** | M:N affiliation table (`DATABASE_DESIGN.md` L310) | `DoctorHospitalRelation` / `doctor.hospitalIds` | Detailed in Schema Req Table #5 (`public.doctor_hospitals`) | Associative join table linking doctors to their practicing clinics/hospitals | **Required table** (`public.doctor_hospitals`) | High |
| **`consultations`** | `consultations` table (`DATABASE_DESIGN.md` L342; C1–C5) | `ConsultationModel` (`userBox` with `consultation_` prefix) | Detailed in Schema Req Table #6 (`public.consultations`) | Clinical encounters, primary diagnosis, symptoms, and visit notes | **Required table** (`public.consultations`) | High |
| **`consultation_attachments`** | `GET /consultations/{id}/files/{fileId}` (`C6`) | `ConsultationAttachment` (`consultation.attachments`) | **OMITTED** in Phase 3B.4.3.0 Schema Report | Metadata and Storage references for prescriptions, clinical notes, and photos | **Required table** (`public.consultation_attachments`) | High |
| **`appointments`** | `appointments` table (`DATABASE_DESIGN.md`; AP1–AP5) | `AppointmentModel` (`userBox` with `appointment_` prefix) | Detailed in Schema Req Table #7 (`public.appointments`) | Scheduled clinic visits, follow-up dates, reminders, and visit status | **Required table** (`public.appointments`) | High |
| **`prescriptions`** | `prescriptions` table (`DATABASE_DESIGN.md` L367; M1–M5) | `MedicineModel` (`userBox` with `medicine_` prefix) | Detailed in Schema Req Table #8 (`public.prescriptions`) | Active and completed medication regimens, dosages, and schedules | **Required table** (`public.prescriptions`) | High |
| **`reports`** | `diagnostic_reports` / `reports` (R1–R5) | `ReportModel` (`userBox` with `report_` prefix) | Detailed in Schema Req Table #9 (`public.reports`) | Diagnostic lab results, imaging investigations, and health documents | **Required table** (`public.reports`) | High |
| **`report_attachments`** | `GET /reports/{id}/files/{file_id}` (`R6`) | `ReportAttachmentModel` (`report.attachments`) | Detailed in Schema Req Table #10 (`public.report_attachments`) | Metadata and storage paths for diagnostic report files (PDFs, images) | **Required table** (`public.report_attachments`) | High |
| **`report_expenses`** | `medical_expenses` (`DATABASE_DESIGN.md` L419) | `ReportExpenseModel` (`report.expense`) | Detailed in Schema Req Table #11 (`public.report_expenses`) | Financial expense metadata tied to diagnostic tests and lab reports | **Required table** (`public.report_expenses`) | High |
| **`measurements`** | `health_measurements` (`DATABASE_DESIGN.md` L391; V1–V5) | `MeasurementModel` (`userBox` with `vital_` prefix) | Detailed in Schema Req Table #12 (`public.measurements`) | Polymorphic clinical vitals engine (BP, glucose, heart rate, spo2, temp, BMI) | **Required table** (`public.measurements`) | High |
| **`user_settings`** | App settings & preferences | `SettingsModel` (`settings_box`, SharedPreferences) | Proposed in early draft notes | App-level preferences (theme, currency, biometrics, notification toggles) | **Hive-only / local-only** (No server table required) | High |
| **`sync_mutations`** | `sync_queues` (`DATABASE_DESIGN.md` L445) | `SyncQueueItem` (`sync_queue_box`) | Proposed as server queue in legacy docs | Local offline mutation staging queue with retry counters and leases | **Hive-only / local-only** (No server table required) | High |
| **`oauth_deletion_requests`** | Deletion compliance | `OAuthDeletionRequestDialog` | Speculative | Tracks user-initiated OAuth deletion requests | **External manual process** (Google Form; not required in DB) | High |
| **`audit_logs`** | Database triggers & audit trail | Not implemented in Flutter client | Mentioned in database review checklist | Tracks historical data alterations for enterprise compliance | **Optional future feature** (Phase 5 enterprise hardening) | Medium |
| **`profile_photos`** | `POST /family-members/{id}/photo` (`F6`) | `profile.photo` / `avatarUrl` | Binary storage | Profile picture binary image files | **Required Storage metadata** (Bucket `avatars`; column in `profiles`) | High |
| **`consent_records`** | Regulatory consent tracking | `ConsentRecordModel` (`consent_box`) | Mentioned in client storage | Stores user agreement timestamps for Terms & Privacy Policy | **Hive-only / local-only** (Client audit trail) | High |
| **`medical_expenses` (General)** | `medical_expenses` (`DATABASE_DESIGN.md` L419) | Handled via `consultation.fee` and `report.expense` | Embedded in consultations and report child tables | Standalone general medical expenses not tied to encounters or tests | **Not required** (Consolidated into consultation fee & report expenses) | High |

---

## 3. Entity Classification Summary

### 3.1 Required PostgreSQL Relational Tables (13 Tables)
1. `public.profiles` – Multi-profile health records scoped to authenticated accounts.
2. `public.medical_departments` – Reference dictionary of clinical specialties.
3. `public.hospitals` – User-saved healthcare facilities and diagnostic clinics.
4. `public.doctors` – User-saved attending physicians and specialists.
5. `public.doctor_hospitals` – Associative junction table for clinician hospital affiliations.
6. `public.consultations` – Longitudinal clinical encounters and diagnoses.
7. `public.consultation_attachments` – Prescriptions, doctor notes, and images linked to consultations.
8. `public.appointments` – Scheduled future clinic visits and reminders.
9. `public.prescriptions` – Medication therapies, forms, dosages, and instructions.
10. `public.reports` – Diagnostic investigations and pathology test records.
11. `public.report_attachments` – Binary file references linked to diagnostic reports.
12. `public.report_expenses` – Financial expenditures associated with lab tests.
13. `public.measurements` – Polymorphic vital signs and clinical metrics.

### 3.2 Supabase Auth-Managed Entities
- `auth.users` – Master authentication table managed by GoTrue. All `public.profiles` reference `auth.users(id) ON DELETE CASCADE`.

### 3.3 Supabase Storage Buckets
- `avatars` – Private bucket storing profile and family member photos.
- `reports` – Private bucket storing lab test results, imaging, and PDF documents.
- `consultations` – Private bucket storing consultation attachments, handwritten prescriptions, and clinic bills.

### 3.4 Hive-Only / Local-Only Persistence
- `sync_queue_box` – Staging queue for pending offline mutations (`SyncQueueItem`).
- `settings_box` & `SharedPreferences` – On-device user preferences (`SettingsModel`).
- `consent_box` – Local ledger of accepted privacy and terms versions (`ConsentRecordModel`).

### 3.5 Excluded / Consolidated Entities
- `public.users` – Retired; replaced by `auth.users`.
- `public.sync_queues` – Retired; replaced by client Hive box + idempotent PostgREST upserts.
- `public.oauth_deletion_requests` – Retired; handled via official Google Form.
- `public.medical_expenses` (Standalone) – Retired; unified into `public.consultations.fee` and `public.report_expenses`.

---
*Entity Inventory Finalized: November 9, 2026*  
*Author: Antigravity AI – Senior Migration Architecture Agent*
