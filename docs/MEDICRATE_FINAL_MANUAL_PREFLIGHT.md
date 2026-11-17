# MediCrate — Final Deployment Safety Audit & Manual Preflight Package (Implementation 5.9.3)

> **Document Status:** CANONICAL MANUAL PREFLIGHT SPECIFICATION (FINAL REVISION & HARDENED)  
> **Target Project Reference:** `wnaflcytkubqmrymbmcn`  
> **Target Environment:** Hosted Supabase (AWS Asia Pacific - Tokyo `ap-northeast-1`)  
> **Database Engine:** PostgreSQL 17  
> **Preflight Mode:** Read-Only Operator Inspection & Safety Package  
> **Date:** November 15, 2026  

---

## 1. Executive Summary & Audit Scope

This document provides the final, execution-safe preflight inspection package for project `wnaflcytkubqmrymbmcn`. It resolves all remaining defects identified in the Implementation 5.9.2 review:
1. **Partial-Schema-Safe Query Planning:** Statically separates relation and column existence checks from data integrity queries. Prevents PostgreSQL planning errors (`ERROR: column "is_archived" does not exist`) if `public.profiles` is in a partially migrated state (e.g. Migration 1 applied, Migration 3 pending).
2. **Comprehensive Canonical Schema Parity:** Verifies relation kinds (`relkind = 'r'`), primary/foreign keys, composite tenant constraints, unique constraints, RLS enablement, RLS policies, triggers, and table privileges across all 13 canonical tables.
3. **Rigorous Function Security Audit:** Audits execution privileges, search paths (`search_path = ''` vs explicit schemas), volatility, and security modes (`SECURITY DEFINER` vs `INVOKER`) for all five critical database functions and RPCs.
4. **Complete 79-Department Reference Seed Verification:** Replaces partial checks with an authoritative 79-tuple Common Table Expression (`VALUES ((1, 'ANAESTHESIOLOGY'), ..., (79, 'OTHERS'))`) that verifies all 79 department names, detects missing IDs, identifies unexpected extra IDs, surfaces name collisions, and checks sequence state without mutating data.
5. **Storage RLS & Table Privilege Hardening:** Verifies RLS policies on `storage.objects` across all four operations (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) and confirms that `authenticated` has no `DELETE` privilege on `public.profiles`.
6. **Native OAuth & In-App OTP Guidance:** Accurately documents MediCrate's native Google Sign-In (`signInWithIdToken`), Web and Android Authorized Client IDs, Site/Redirect URL interactions, and in-app 6-digit OTP verification (`{{ .Token }}`).
7. **Production Recovery Hierarchy:** Eliminates manual migration history row deletions and destructive script rollbacks, establishing a strict 3-tier forward-fix and backup-restoration operational hierarchy.

### Preflight Readiness Determination
```
READY FOR MANUAL HOSTED PREFLIGHT
```

### Safety & Operational Guarantees
- **Strictly Read-Only Queries:** All queries in this package are pure `SELECT` operations. No `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`, or `TRUNCATE` statements exist.
- **Resilient to Missing Objects and Partial Columns:** Queries never reference potentially absent tables or columns without prior existence checks and explicit operator skip rules.
- **Zero Exposure of Secrets:** No database passwords, service-role keys, or client secrets are exposed.

---

## 2. Confirmed Findings from Actual Local Files

Inspection of local repository artifacts establishes the following canonical baseline:

| Artifact | Canonical Baseline State | Local Verification Source |
| :--- | :--- | :--- |
| **SQL Migrations** | Exactly 6 chronological migrations in [supabase/migrations/](file:///home/blackhat/Documents/medi_crate/supabase/migrations/) | `20261109200000_create_medicrate_foundation_schema.sql`<br>`20261109210000_create_medicrate_storage_buckets_and_policies.sql`<br>`20261110080000_prepare_profile_archival_support.sql`<br>`20261111100000_harden_profile_delete_policy.sql`<br>`20261111120000_harden_doctor_hospital_transactions_and_types.sql`<br>`20261112130000_create_delete_user_account_rpc.sql`. Strictly sequential, zero gaps or duplicates. |
| **Canonical Tables** | 13 base tables in `public` schema | `profiles`, `medical_departments`, `hospitals`, `doctors`, `doctor_hospitals`, `consultations`, `consultation_attachments`, `appointments`, `prescriptions`, `reports`, `report_attachments`, `report_expenses`, `measurements`. |
| **Domain Schema Mapping** | Medicines $\rightarrow$ `prescriptions`<br>Vitals $\rightarrow$ `measurements` | Flutter `MedicineModel` maps to `public.prescriptions`; Flutter `MeasurementModel` maps to `public.measurements`. Tables named `medicines`, `vitals`, or `documents` do not exist. |
| **Profile Archival Design** | In-place soft archival on `public.profiles` | Columns `is_archived BOOLEAN NOT NULL DEFAULT FALSE` and `archived_at TIMESTAMPTZ NULL`. Server-side trigger `trg_protect_profile_archival_invariant` manages timestamps. RLS helper `public.is_profile_active()` blocks clinical writes under archived profiles while preserving historical reads. |
| **Profile Deletion Invariant** | Hard DELETE revoked for client roles | `REVOKE DELETE ON TABLE public.profiles FROM authenticated, anon, public;`. Removal is restricted to soft archival (`UPDATE is_archived = true`). Table DELETE is reserved for `service_role`. |
| **Doctor/Hospital RPC** | `public.save_doctor_with_affiliations` | `SECURITY INVOKER` function in migration 5, called by [supabase_doctor_remote_data_source.dart#L273](file:///home/blackhat/Documents/medi_crate/lib/features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart#L273). Internal helper `private.check_doctor_ownership` prevents existence oracle leaks. |
| **Account Deletion RPC** | `public.delete_user_account` | `SECURITY DEFINER` function in migration 6, called by [supabase_auth_remote_data_source.dart#L415](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart#L415). Enforces storage purge precondition before cascading user deletion across all clinical tables. |
| **Storage Configuration** | 3 private buckets | `consultations` (25 MB), `reports` (25 MB), `avatars` (5 MB). All `public = false`. Allowed MIME: PDF, JPEG, PNG, WEBP. Matched in [supabase_storage_service.dart#L63-L69](file:///home/blackhat/Documents/medi_crate/lib/core/storage/supabase_storage_service.dart#L63-L69). |
| **Reference Seed Catalog** | 79 medical departments in [supabase/seed.sql](file:///home/blackhat/Documents/medi_crate/supabase/seed.sql) | Exactly IDs 1..79 with 'OTHERS' at ID 79. Protected by preflight conflict checks and sequence resynchronization. |
| **Flutter Authentication** | Native Google Sign-In & In-App OTP | Native on-device Google Sign-In with ID token exchange (`signInWithIdToken`); in-app 6-digit OTP verification (`verifyOTP`) for signup and password recovery. |

---

## 3. Remaining Unknown Hosted Conditions

The following conditions cannot be established through local inspection and require manual execution of the SQL inspection package in Supabase Studio:

1. **Hosted Migration Ledger State:** Whether `supabase_migrations.schema_migrations` contains 0 versions, a partial subset of the 6 canonical versions, or conflicting legacy timestamps.
2. **Public Schema Object Pre-existence:** Whether prototype tables, views, or collaterally named relations (`medicines`, `vitals`, `documents`, `family_members`, `users`) exist in `public`.
3. **Partial Schema States:** Whether tables exist from an interrupted run where columns added in later migrations (such as `is_archived` on `profiles`) are missing.
4. **Pre-Existing Auth Users:** Whether user accounts exist in `auth.users` without matching primary profiles in `public.profiles`.
5. **Storage Bucket & Object State:** Whether buckets were provisioned via UI, whether any bucket is marked `public = true`, and whether objects violate path depth conventions (`{user_id}/{parent_id}/{file}`).
6. **Dashboard Provider Configuration:** Whether Google OAuth is toggled ON with the verified Web Client ID and Android Client ID.

---

## 4. Hardened Read-Only SQL Inspection Package

> [!IMPORTANT]
> **Operator Execution Guide:** Open the [Supabase Studio SQL Editor](https://supabase.com/dashboard/project/wnaflcytkubqmrymbmcn/sql) for project `wnaflcytkubqmrymbmcn`. Execute each query group sequentially. Follow the skip instructions when an object is reported absent.

```
[Group 1: Migration Ledger] ──► [Group 2: Public Object Inventory] ──► [Group 3: Canonical Schema Parity]
                                                                                │
[Group 6: Reference Seed]   ◄── [Group 5: Storage State]          ◄── [Group 4: Auth & Profiles]
```

---

### Group 1: Environment & Migration Ledger Inspection

#### Query 1A: Database Engine & Migration Ledger Existence
```sql
-- QUERY 1A: Database Engine Verification and Migration Ledger Existence
SELECT current_setting('server_version') AS postgres_version,
       current_database() AS database_name,
       current_user AS session_user,
       EXISTS (
           SELECT 1 FROM information_schema.tables 
           WHERE table_schema = 'supabase_migrations' 
             AND table_name = 'schema_migrations'
       ) AS has_schema_migrations_table;
```

#### Query 1B: Recorded Migration History (Conditional)
> [!NOTE]
> **Skip Instruction:** Execute Query 1B **ONLY** if `has_schema_migrations_table = true` in Query 1A. If `false`, skip to Group 2 (indicates an unmigrated database with 0 recorded versions).

```sql
-- QUERY 1B: Recorded Migration History
SELECT version, inserted_at 
FROM supabase_migrations.schema_migrations 
ORDER BY version ASC;
```

---

### Group 2: Public Schema Object & Collision Detection

#### Query 2A: Catalog Inventory of Public Relations
```sql
-- QUERY 2A: Catalog Inventory of Public Relations (Tables, Views, MatViews, Foreign Tables)
SELECT c.relname AS relation_name,
       CASE c.relkind
           WHEN 'r' THEN 'BASE_TABLE'
           WHEN 'v' THEN 'VIEW'
           WHEN 'm' THEN 'MATERIALIZED_VIEW'
           WHEN 'f' THEN 'FOREIGN_TABLE'
           WHEN 'p' THEN 'PARTITIONED_TABLE'
           ELSE 'OTHER'
       END AS relation_type,
       CASE 
           WHEN c.relkind = 'r' AND c.relname IN (
               'profiles', 'medical_departments', 'hospitals', 'doctors',
               'doctor_hospitals', 'consultations', 'consultation_attachments',
               'appointments', 'prescriptions', 'reports',
               'report_attachments', 'report_expenses', 'measurements'
           ) THEN 'CANONICAL_BASE_TABLE'
           WHEN c.relname IN ('medicines', 'vitals', 'documents', 'family_members', 'users') THEN 'NON_CANONICAL_COLLISION'
           WHEN c.relkind != 'r' AND c.relname IN (
               'profiles', 'medical_departments', 'hospitals', 'doctors',
               'doctor_hospitals', 'consultations', 'consultation_attachments',
               'appointments', 'prescriptions', 'reports',
               'report_attachments', 'report_expenses', 'measurements'
           ) THEN 'COLLIDING_VIEW_OR_RELATION'
           ELSE 'OTHER_PUBLIC_OBJECT'
       END AS classification
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'v', 'm', 'f', 'p')
ORDER BY classification, c.relname;
```

#### Query 2B: Canonical Table Count Summary
```sql
-- QUERY 2B: Summary Counts of Canonical and Colliding Tables
SELECT count(*) FILTER (
           WHERE c.relkind = 'r' AND c.relname IN (
               'profiles', 'medical_departments', 'hospitals', 'doctors',
               'doctor_hospitals', 'consultations', 'consultation_attachments',
               'appointments', 'prescriptions', 'reports',
               'report_attachments', 'report_expenses', 'measurements'
           )
       ) AS existing_canonical_base_tables,
       count(*) FILTER (
           WHERE c.relname IN ('medicines', 'vitals', 'documents', 'family_members', 'users')
       ) AS non_canonical_collisions,
       count(*) FILTER (
           WHERE c.relkind != 'r' AND c.relname IN (
               'profiles', 'medical_departments', 'hospitals', 'doctors',
               'doctor_hospitals', 'consultations', 'consultation_attachments',
               'appointments', 'prescriptions', 'reports',
               'report_attachments', 'report_expenses', 'measurements'
           )
       ) AS colliding_views_or_foreign_tables
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public';
```

---

### Group 3: Canonical Schema Structural Parity & Security

> [!NOTE]
> **Skip Instruction:** Execute Group 3 queries **ONLY** if `existing_canonical_base_tables > 0` from Query 2B. If `0`, skip to Group 4 (expected for a pristine, unmigrated database). If `existing_canonical_base_tables` is between 1 and 12, the schema is in a **partial-schema state**; execute Group 3 to identify missing components.

#### Query 3A: 13 Base Tables Status & RLS Enablement
```sql
-- QUERY 3A: 13 Expected Base Tables Verification & RLS State
WITH expected_tables(expected_table) AS (
    VALUES
        ('profiles'), ('medical_departments'), ('hospitals'), ('doctors'),
        ('doctor_hospitals'), ('consultations'), ('consultation_attachments'),
        ('appointments'), ('prescriptions'), ('reports'),
        ('report_attachments'), ('report_expenses'), ('measurements')
)
SELECT e.expected_table,
       c.relname IS NOT NULL AS table_exists,
       CASE c.relkind
           WHEN 'r' THEN 'BASE_TABLE'
           WHEN 'v' THEN 'VIEW'
           WHEN 'm' THEN 'MATERIALIZED_VIEW'
           ELSE COALESCE(c.relkind::text, 'MISSING')
       END AS actual_relkind,
       COALESCE(c.relrowsecurity, false) AS rls_enabled,
       COALESCE(c.relforcerowsecurity, false) AS rls_forced,
       r.rolname AS table_owner
FROM expected_tables e
LEFT JOIN (
    pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
    JOIN pg_roles r ON r.oid = c.relowner
) ON c.relname = e.expected_table
ORDER BY e.expected_table;
```

#### Query 3B: Critical Canonical Columns & Types
```sql
-- QUERY 3B: Critical Columns and Types across Canonical Tables
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
      (table_name = 'profiles' AND column_name IN ('id', 'user_id', 'is_primary', 'is_archived', 'archived_at'))
   OR (table_name = 'medical_departments' AND column_name IN ('id', 'name', 'display_order', 'is_active'))
   OR (table_name = 'hospitals' AND column_name IN ('id', 'user_id', 'profile_id', 'name', 'type'))
   OR (table_name = 'doctors' AND column_name IN ('id', 'user_id', 'profile_id', 'name', 'specialty'))
   OR (table_name = 'doctor_hospitals' AND column_name IN ('doctor_id', 'hospital_id', 'user_id'))
   OR (table_name = 'consultations' AND column_name IN ('id', 'user_id', 'profile_id', 'doctor_id', 'hospital_id'))
   OR (table_name = 'consultation_attachments' AND column_name IN ('id', 'user_id', 'consultation_id', 'file_path'))
   OR (table_name = 'appointments' AND column_name IN ('id', 'user_id', 'profile_id', 'doctor_id', 'hospital_id', 'appointment_date'))
   OR (table_name = 'prescriptions' AND column_name IN ('id', 'user_id', 'profile_id', 'consultation_id', 'medication_name'))
   OR (table_name = 'reports' AND column_name IN ('id', 'user_id', 'profile_id', 'title'))
   OR (table_name = 'report_attachments' AND column_name IN ('id', 'user_id', 'report_id', 'file_path'))
   OR (table_name = 'report_expenses' AND column_name IN ('id', 'user_id', 'report_id', 'amount'))
   OR (table_name = 'measurements' AND column_name IN ('id', 'user_id', 'profile_id', 'type', 'value'))
  )
ORDER BY table_name, column_name;
```

#### Query 3C: Primary, Foreign & Composite Tenant Constraints
```sql
-- QUERY 3C: Primary, Foreign, Unique, and Composite Tenant Constraints
SELECT c.relname AS table_name,
       con.conname AS constraint_name,
       CASE con.contype
           WHEN 'p' THEN 'PRIMARY_KEY'
           WHEN 'u' THEN 'UNIQUE'
           WHEN 'f' THEN 'FOREIGN_KEY'
           WHEN 'c' THEN 'CHECK'
           ELSE con.contype::text
       END AS constraint_type,
       pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
      'profiles', 'medical_departments', 'hospitals', 'doctors',
      'doctor_hospitals', 'consultations', 'consultation_attachments',
      'appointments', 'prescriptions', 'reports',
      'report_attachments', 'report_expenses', 'measurements'
  )
ORDER BY c.relname, con.contype, con.conname;
```

#### Query 3D: RLS Policies on Canonical Tables
```sql
-- QUERY 3D: RLS Policies on Canonical Public Tables
SELECT tablename,
       policyname,
       permissive,
       roles,
       cmd,
       qual AS using_expression,
       with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

#### Query 3E: Triggers on Canonical Tables & Auth Hook
```sql
-- QUERY 3E: Triggers on Canonical Tables and Auth Hook
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       t.tgname AS trigger_name,
       p.proname AS function_name,
       CASE 
           WHEN (t.tgtype & 2) != 0 THEN 'BEFORE'
           WHEN (t.tgtype & 64) != 0 THEN 'INSTEAD_OF'
           ELSE 'AFTER'
       END AS timing,
       CASE
           WHEN (t.tgtype & 4) != 0 THEN 'INSERT'
           WHEN (t.tgtype & 8) != 0 THEN 'DELETE'
           WHEN (t.tgtype & 16) != 0 THEN 'UPDATE'
           ELSE 'UNKNOWN'
       END AS event,
       t.tgenabled AS is_enabled
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE (n.nspname = 'public' AND c.relname IN (
          'profiles', 'medical_departments', 'hospitals', 'doctors',
          'doctor_hospitals', 'consultations', 'consultation_attachments',
          'appointments', 'prescriptions', 'reports',
          'report_attachments', 'report_expenses', 'measurements'
      ))
   OR (n.nspname = 'auth' AND c.relname = 'users' AND t.tgname = 'on_auth_user_created')
ORDER BY n.nspname, c.relname, t.tgname;
```

#### Query 3F: Table Privileges (Hardened DELETE Verification)
```sql
-- QUERY 3F: Authenticated Role Privileges on Canonical Tables
SELECT c.relname AS table_name,
       bool_or(tp.privilege_type = 'SELECT') AS authenticated_has_select,
       bool_or(tp.privilege_type = 'INSERT') AS authenticated_has_insert,
       bool_or(tp.privilege_type = 'UPDATE') AS authenticated_has_update,
       bool_or(tp.privilege_type = 'DELETE') AS authenticated_has_delete
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN information_schema.table_privileges tp 
    ON tp.table_schema = n.nspname 
   AND tp.table_name = c.relname 
   AND tp.grantee = 'authenticated'
WHERE n.nspname = 'public'
  AND c.relname IN (
      'profiles', 'medical_departments', 'hospitals', 'doctors',
      'doctor_hospitals', 'consultations', 'consultation_attachments',
      'appointments', 'prescriptions', 'reports',
      'report_attachments', 'report_expenses', 'measurements'
  )
GROUP BY c.relname
ORDER BY c.relname;
```

#### Query 3G: Canonical Functions, RPCs, Security Mode, Owner & Search Path
```sql
-- QUERY 3G: Comprehensive Function Security, Search Path, Ownership & Execution Privilege Audit
SELECT n.nspname AS schema_name,
       p.proname AS function_name,
       CASE p.prosecdef WHEN true THEN 'SECURITY_DEFINER' ELSE 'SECURITY_INVOKER' END AS security_mode,
       r.rolname AS owner,
       COALESCE(array_to_string(p.proconfig, ', '), '(default / unset)') AS search_path,
       CASE p.provolatile WHEN 'i' THEN 'IMMUTABLE' WHEN 's' THEN 'STABLE' WHEN 'v' THEN 'VOLATILE' END AS volatility,
       pg_get_function_identity_arguments(p.oid) AS argument_types,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_roles r ON r.oid = p.proowner
WHERE (n.nspname = 'public' AND p.proname IN (
          'save_doctor_with_affiliations',
          'delete_user_account',
          'is_profile_active',
          'is_profile_active_for_user',
          'handle_new_user',
          'protect_profile_primary_deletion',
          'protect_profile_archival_invariant',
          'update_updated_at_column'
      ))
   OR (n.nspname = 'private' AND p.proname = 'check_doctor_ownership')
ORDER BY n.nspname, p.proname;
```

---

### Group 4: Auth Users & Partial-Schema-Safe Profile Invariants

#### Query 4A: Auth Users Baseline Metrics (Always Safe)
```sql
-- QUERY 4A: Auth Users Baseline Metrics
SELECT count(*) AS total_auth_users,
       min(created_at) AS earliest_user,
       max(created_at) AS latest_user
FROM auth.users;
```

#### Query 4B: Profiles Table & Column Precondition Check
> [!IMPORTANT]
> **Partial-Schema Protection:** In PostgreSQL, queries are validated during planning. Directly querying `SELECT ... FROM public.profiles WHERE is_archived = TRUE` on a database that only has Migration 1 applied causes an immediate fatal error: `ERROR: column "is_archived" does not exist`. Run Query 4B first to establish which columns actually exist.

```sql
-- QUERY 4B: Check Table & Column Existence on profiles Before Executing Invariants
SELECT 
    EXISTS (
        SELECT 1 FROM pg_class c 
        JOIN pg_namespace n ON n.oid = c.relnamespace 
        WHERE n.nspname = 'public' AND c.relname = 'profiles' AND c.relkind = 'r'
    ) AS has_profiles_table,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'is_primary'
    ) AS has_col_is_primary,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'is_archived'
    ) AS has_col_is_archived;
```

#### Query 4C: Bidirectional User-Profile Invariant Checks (Conditional Subqueries)

> [!NOTE]
> **Operator Skip Instructions:**
> - If `has_profiles_table = false`, **SKIP** all queries in 4C (profiles table does not exist).
> - Execute Queries 4C.1 and 4C.2 if `has_profiles_table = true`.
> - Execute Query 4C.3 **ONLY** if `has_col_is_primary = true`.
> - Execute Query 4C.4 **ONLY** if `has_col_is_primary = true` **AND** `has_col_is_archived = true`. If `has_col_is_archived = false`, **DO NOT execute Query 4C.4** and record that Migration 3 has not been applied.

```sql
-- QUERY 4C.1: Auth Users lacking any profile (Requires profiles table)
SELECT u.id AS unlinked_auth_user_id, u.email, u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON p.user_id = u.id
WHERE p.id IS NULL;

-- QUERY 4C.2: Orphaned Profiles with no corresponding Auth User (Requires profiles table)
SELECT p.id AS orphaned_profile_id, p.user_id AS unlinked_user_id, p.full_name
FROM public.profiles p
LEFT JOIN auth.users u ON u.id = p.user_id
WHERE u.id IS NULL;

-- QUERY 4C.3: Users with Multiple Primary Profiles (Run ONLY if has_col_is_primary = true)
SELECT user_id, count(*) AS primary_profile_count
FROM public.profiles
WHERE is_primary = TRUE
GROUP BY user_id
HAVING count(*) > 1;

-- QUERY 4C.4: Primary Profiles Marked as Archived (Run ONLY if has_col_is_primary = true AND has_col_is_archived = true)
SELECT id, user_id, full_name, archived_at
FROM public.profiles
WHERE is_primary = TRUE AND is_archived = TRUE;
```

---

### Group 5: Storage State & Policy Inspection

#### Query 5A: Clinical & Avatar Bucket Configuration
```sql
-- QUERY 5A: Configuration of Clinical & Avatar Storage Buckets
SELECT id, name, public, file_size_limit, allowed_mime_types, created_at
FROM storage.buckets
WHERE id IN ('consultations', 'reports', 'avatars')
ORDER BY id;
```

#### Query 5B: Storage Object Counts & Total Bytes
```sql
-- QUERY 5B: Object Population per Bucket
SELECT bucket_id, 
       count(*) AS object_count,
       coalesce(sum((metadata->>'size')::bigint), 0) AS total_bytes
FROM storage.objects
WHERE bucket_id IN ('consultations', 'reports', 'avatars')
GROUP BY bucket_id;
```

#### Query 5C: Path Depth & Anomaly Detection
```sql
-- QUERY 5C: Clinical Objects Violating Canonical Depth {user_id}/{parent_id}/{file} (depth = 2)
SELECT bucket_id, name, owner, created_at
FROM storage.objects
WHERE bucket_id IN ('consultations', 'reports')
  AND array_length(storage.foldername(name), 1) != 2
LIMIT 25;
```

#### Query 5D: Storage Policies on `storage.objects`
```sql
-- QUERY 5D: Storage Policies on storage.objects for MediCrate Buckets
SELECT policyname,
       roles,
       cmd,
       qual AS using_expression,
       with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
      policyname ILIKE '%consultation%'
   OR policyname ILIKE '%report%'
   OR policyname ILIKE '%avatar%'
  )
ORDER BY policyname;
```

---

### Group 6: Reference Seed State Verification

#### Query 6A: Check Base Table Existence (Distinguishing from Views)
```sql
-- QUERY 6A: Check if medical_departments Base Table Exists (Catalog relkind = 'r')
SELECT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' 
      AND c.relname = 'medical_departments' 
      AND c.relkind = 'r'
) AS has_medical_departments_base_table,
EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' 
      AND c.relname = 'medical_departments' 
      AND c.relkind != 'r'
) AS has_colliding_view_or_relation;
```

#### Query 6B: Exact 79-Department Integrity, Name Matching & Sequence Audit (Conditional)
> [!NOTE]
> **Skip Instruction:** Execute Query 6B **ONLY** if `has_medical_departments_base_table = true` in Query 6A. If `false`, skip Query 6B (seed script has not yet been applied).

```sql
-- QUERY 6B: Exact Reference Integrity, All 79 Names & Sequence Verification
WITH authoritative_seed(expected_id, expected_name) AS (
    VALUES
        (1, 'ANAESTHESIOLOGY'),
        (2, 'ASSOCIATE PHYSICIAN'),
        (3, 'BREAST ONCOPLASTIC SURGERY'),
        (4, 'CARDIO THORACIC VASCULAR ANESTHESIOLOGY'),
        (5, 'CARDIO VASCULAR SURGERY'),
        (6, 'CARDIOLOGY'),
        (7, 'CARDIOTHORACIC SURGEON'),
        (8, 'CLINICAL NEURO PSYCHOLOGY'),
        (9, 'CLINICAL PSYCHOLOGY'),
        (10, 'CTVC'),
        (11, 'DENTAL'),
        (12, 'DENTAL PROSTHODONTIST'),
        (13, 'DERMATOLOGY'),
        (14, 'DEVELOPMENTAL MEDICINE'),
        (15, 'DIABETOLOGY'),
        (16, 'DIALYSIS'),
        (17, 'DIETARY'),
        (18, 'E.N.T'),
        (19, 'EMERGENCY DEPARTMENT'),
        (20, 'ENDOCRINOLOGY'),
        (21, 'ENDOSCOPIC SPINE SURGEON'),
        (22, 'FAMILY MEDICINE'),
        (23, 'FORENSIC MEDICINE AND TOXICOLOGY'),
        (24, 'GASTROENTEROLOGY(MED)'),
        (25, 'GASTROENTEROLOGY(SURG)'),
        (26, 'GENERAL SURGERY'),
        (27, 'GYNAECOLOGICAL ONCOLOGY'),
        (28, 'HAND & MICROVASCULAR SURGERY'),
        (29, 'HEMATO ONCOLOGY'),
        (30, 'HEMATOLOGY'),
        (31, 'HEPATOLOGY'),
        (32, 'HPB & LIVER TRANSPLANT SURGEON'),
        (33, 'INTENSIVE CARE'),
        (34, 'INTERNAL MEDICINE'),
        (35, 'LABORATORY'),
        (36, 'LACTATION'),
        (37, 'LAPROSCOPIC AND GENERAL SURGEON'),
        (38, 'MAXILLOFACIAL SURGERY'),
        (39, 'MHC CONSULTANT'),
        (40, 'NEONATOLOGY'),
        (41, 'NEPHROLOGY'),
        (42, 'NEURO ANAESTHESIA'),
        (43, 'NEURO RADIOLOGY'),
        (44, 'NEURO SURGERY'),
        (45, 'NEUROLOGY'),
        (46, 'NEUROVASCULAR & INTERVENTIONAL RADIOLOGY'),
        (47, 'OBSTETRIC & GYNAECOLOGY'),
        (48, 'ONCOLOGY (MEDICAL)'),
        (49, 'ONCOLOGY (SURGICAL)'),
        (50, 'OPHTHALMOLOGY'),
        (51, 'ORAL & MAXILLO FACIAL SURGERY'),
        (52, 'ORTHOPAEDICS'),
        (53, 'ORTHOPAEDICS & SPINE SURGEON'),
        (54, 'PAEDIATRIC DENTAL'),
        (55, 'PAEDIATRIC DERMATOLOGY'),
        (56, 'PAEDIATRIC ENDOCRINOLOGY'),
        (57, 'PAEDIATRIC HAEMATO-ONCOLOGY'),
        (58, 'PAEDIATRIC NEPHROLOGY'),
        (59, 'PAEDIATRIC NEUROLOGY'),
        (60, 'PAEDIATRIC ORTHOPAEDICS'),
        (61, 'PAEDIATRIC PSYCHOLOGY'),
        (62, 'PAEDIATRIC PULMONOLOGY'),
        (63, 'PAEDIATRIC SURGERY'),
        (64, 'PAEDIATRICS'),
        (65, 'PAEDIATRICS N NEONATOLOGY'),
        (66, 'PAEDIATRICS-CARDIOLOGY'),
        (67, 'PHYSIOTHERAPY'),
        (68, 'PLASTIC SURGERY'),
        (69, 'PSYCHIATRY'),
        (70, 'PSYCHOLOGY'),
        (71, 'PULMONOLOGY'),
        (72, 'RADIOLOGY'),
        (73, 'RHEUMATOLOGY'),
        (74, 'SPEECH THERAPY'),
        (75, 'THORACIC SURGERY'),
        (76, 'UROLOGY'),
        (77, 'UROLOGY ANDROLOGY'),
        (78, 'VASCULAR SURGERY'),
        (79, 'OTHERS')
),
audit_summary AS (
    SELECT 
        (SELECT count(*) FROM public.medical_departments) AS actual_row_count,
        (SELECT count(*) FROM authoritative_seed) AS expected_canonical_count,
        (SELECT count(*) FROM public.medical_departments m JOIN authoritative_seed a ON m.id = a.expected_id AND m.name = a.expected_name) AS exact_matches,
        (SELECT count(*) FROM authoritative_seed a LEFT JOIN public.medical_departments m ON m.id = a.expected_id WHERE m.id IS NULL) AS missing_canonical_ids_count,
        (SELECT count(*) FROM public.medical_departments m LEFT JOIN authoritative_seed a ON a.expected_id = m.id WHERE a.expected_id IS NULL) AS unexpected_extra_ids_count,
        (SELECT count(*) FROM public.medical_departments m JOIN authoritative_seed a ON m.id = a.expected_id WHERE m.name <> a.expected_name) AS name_discrepancies_count,
        (SELECT pg_sequence_last_value(pg_get_serial_sequence('public.medical_departments', 'id'))) AS sequence_last_value
)
SELECT * FROM audit_summary;

-- Discrepancy Detail List (Returns 0 rows if database matches seed.sql perfectly)
WITH authoritative_seed(expected_id, expected_name) AS (
    VALUES
        (1, 'ANAESTHESIOLOGY'), (2, 'ASSOCIATE PHYSICIAN'), (3, 'BREAST ONCOPLASTIC SURGERY'),
        (4, 'CARDIO THORACIC VASCULAR ANESTHESIOLOGY'), (5, 'CARDIO VASCULAR SURGERY'), (6, 'CARDIOLOGY'),
        (7, 'CARDIOTHORACIC SURGEON'), (8, 'CLINICAL NEURO PSYCHOLOGY'), (9, 'CLINICAL PSYCHOLOGY'),
        (10, 'CTVC'), (11, 'DENTAL'), (12, 'DENTAL PROSTHODONTIST'),
        (13, 'DERMATOLOGY'), (14, 'DEVELOPMENTAL MEDICINE'), (15, 'DIABETOLOGY'),
        (16, 'DIALYSIS'), (17, 'DIETARY'), (18, 'E.N.T'),
        (19, 'EMERGENCY DEPARTMENT'), (20, 'ENDOCRINOLOGY'), (21, 'ENDOSCOPIC SPINE SURGEON'),
        (22, 'FAMILY MEDICINE'), (23, 'FORENSIC MEDICINE AND TOXICOLOGY'), (24, 'GASTROENTEROLOGY(MED)'),
        (25, 'GASTROENTEROLOGY(SURG)'), (26, 'GENERAL SURGERY'), (27, 'GYNAECOLOGICAL ONCOLOGY'),
        (28, 'HAND & MICROVASCULAR SURGERY'), (29, 'HEMATO ONCOLOGY'), (30, 'HEMATOLOGY'),
        (31, 'HEPATOLOGY'), (32, 'HPB & LIVER TRANSPLANT SURGEON'), (33, 'INTENSIVE CARE'),
        (34, 'INTERNAL MEDICINE'), (35, 'LABORATORY'), (36, 'LACTATION'),
        (37, 'LAPROSCOPIC AND GENERAL SURGEON'), (38, 'MAXILLOFACIAL SURGERY'), (39, 'MHC CONSULTANT'),
        (40, 'NEONATOLOGY'), (41, 'NEPHROLOGY'), (42, 'NEURO ANAESTHESIA'),
        (43, 'NEURO RADIOLOGY'), (44, 'NEURO SURGERY'), (45, 'NEUROLOGY'),
        (46, 'NEUROVASCULAR & INTERVENTIONAL RADIOLOGY'), (47, 'OBSTETRIC & GYNAECOLOGY'), (48, 'ONCOLOGY (MEDICAL)'),
        (49, 'ONCOLOGY (SURGICAL)'), (50, 'OPHTHALMOLOGY'), (51, 'ORAL & MAXILLO FACIAL SURGERY'),
        (52, 'ORTHOPAEDICS'), (53, 'ORTHOPAEDICS & SPINE SURGEON'), (54, 'PAEDIATRIC DENTAL'),
        (55, 'PAEDIATRIC DERMATOLOGY'), (56, 'PAEDIATRIC ENDOCRINOLOGY'), (57, 'PAEDIATRIC HAEMATO-ONCOLOGY'),
        (58, 'PAEDIATRIC NEPHROLOGY'), (59, 'PAEDIATRIC NEUROLOGY'), (60, 'PAEDIATRIC ORTHOPAEDICS'),
        (61, 'PAEDIATRIC PSYCHOLOGY'), (62, 'PAEDIATRIC PULMONOLOGY'), (63, 'PAEDIATRIC SURGERY'),
        (64, 'PAEDIATRICS'), (65, 'PAEDIATRICS N NEONATOLOGY'), (66, 'PAEDIATRICS-CARDIOLOGY'),
        (67, 'PHYSIOTHERAPY'), (68, 'PLASTIC SURGERY'), (69, 'PSYCHIATRY'),
        (70, 'PSYCHOLOGY'), (71, 'PULMONOLOGY'), (72, 'RADIOLOGY'),
        (73, 'RHEUMATOLOGY'), (74, 'SPEECH THERAPY'), (75, 'THORACIC SURGERY'),
        (76, 'UROLOGY'), (77, 'UROLOGY ANDROLOGY'), (78, 'VASCULAR SURGERY'),
        (79, 'OTHERS')
)
SELECT a.expected_id AS id, a.expected_name, 'MISSING_FROM_DATABASE' AS discrepancy_type
FROM authoritative_seed a
LEFT JOIN public.medical_departments m ON m.id = a.expected_id
WHERE m.id IS NULL

UNION ALL

SELECT m.id, m.name, 'NAME_DISCREPANCY: expected "' || a.expected_name || '"' AS discrepancy_type
FROM public.medical_departments m
JOIN authoritative_seed a ON m.id = a.expected_id
WHERE m.name <> a.expected_name

UNION ALL

SELECT m.id, m.name, 'NAME_COLLISION: belongs to canonical ID ' || a.expected_id::text AS discrepancy_type
FROM public.medical_departments m
JOIN authoritative_seed a ON m.name = a.expected_name
WHERE m.id <> a.expected_id

UNION ALL

SELECT m.id, m.name, 'UNEXPECTED_EXTRA_ID' AS discrepancy_type
FROM public.medical_departments m
LEFT JOIN authoritative_seed a ON a.expected_id = m.id
WHERE a.expected_id IS NULL

ORDER BY id;
```

---

## 5. Expected Output & Deployment Blocking Conditions

| Query Group | Expected Clean State | Acceptable Existing State | Blocking Condition (Deployment MUST Halt) |
| :--- | :--- | :--- | :--- |
| **G1: Migration Ledger** | `has_schema_migrations_table = false` OR Query 1B returns 0 rows. | Query 1B returns all 6 canonical versions (`20261109200000`..`20261112130000`). | Query 1B returns non-canonical versions, or partial subset where tables are missing/divergent. |
| **G2: Public Objects** | 0 tables in `public` (`existing_canonical_base_tables = 0`). | Exactly 13 canonical base tables exist with 0 non-canonical collisions. | Non-canonical tables exist (`medicines`, `vitals`, `documents`), or views collide with canonical table names. |
| **G3: Structural Parity** | Group 3 is skipped (tables do not exist). | All 13 canonical tables exist as `BASE_TABLE` (`relkind = 'r'`), RLS enabled on all 13, `profiles` has `is_archived BOOLEAN`, `archived_at TIMESTAMPTZ`, `check_profiles_primary_not_archived`, and `authenticated` DELETE revoked on `profiles`. | Any canonical table missing, relation kind is view, column types differ, composite constraint `uq_profiles_id_user_id` missing, RLS disabled on any table, or `authenticated` retains table DELETE privilege on `profiles`. |
| **G4: Auth & Profiles** | 0 auth users (Query 4C skipped). | All auth users have exactly 1 primary profile (`is_primary = true`, `is_archived = false`). 0 unlinked or archived primary profiles. | Users exist in `auth.users` without a primary profile, users have multiple primary profiles, or primary profiles are archived. |
| **G5: Storage State** | 0 rows in `storage.buckets`. | Buckets `consultations`, `reports`, `avatars` exist as `public = false` with 25MB/25MB/5MB limits, and 12 RLS policies exist on `storage.objects`. | Any bucket is `public = true`, missing storage policies, or existing objects violate `{user_id}/{parent_id}/{file}` depth. |
| **G6: Reference Seed** | Query 6A returns `false` (Query 6B skipped). | Exactly 79 rows, `exact_matches = 79`, `missing_canonical_ids_count = 0`, `unexpected_extra_ids_count = 0`, `name_discrepancies_count = 0`, and sequence value $\ge 79$. | Table exists with $< 79$ rows, any name mismatch, missing canonical IDs, or ID/name collisions. |

---

## 6. Corrected Google OAuth, Deep Linking & Auth Settings

### Architectural Trace of Flutter Auth Pipeline
Investigation of [supabase_auth_remote_data_source.dart](file:///home/blackhat/Documents/medi_crate/lib/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart) and [app_router.dart](file:///home/blackhat/Documents/medi_crate/lib/app/routes/app_router.dart) confirms:

1. **Native Google OAuth (No Browser Redirects):**
   - The Flutter mobile client uses the native Google Sign-In SDK (`google_sign_in`) to authenticate locally on Android/iOS.
   - The Google ID token is retrieved and passed directly to Supabase via `_auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken)`.
   - Browser redirect flows (`signInWithOAuth`) are **not** used by the mobile application during Google login.
2. **Authorized Client IDs (Audience Invariant):**
   - When an Android app requests an ID token from Google, the `aud` (audience) claim contains the Android Client ID.
   - Supabase GoTrue validates the token against its configured Google credentials.
   - If the Android Client ID (`842207080347-iua...`) is not present in Supabase's **Authorized Client IDs** list, GoTrue rejects the token with `400: Invalid token: audience mismatch`.
3. **Email Verification is In-App OTP:**
   - MediCrate does **not** rely on magic links or browser redirection for user signup confirmation or password resets.
   - The application presents dedicated OTP input screens and invokes:
     - `verifyOTP(email: email, token: otp, type: OtpType.signup)`
     - `verifyOTP(email: email, token: otp, type: OtpType.recovery)`
   - Therefore, email templates must supply the plain 6-digit code `{{ .Token }}`.
4. **Site URL and Redirect URLs:**
   - **Site URL:** Configured as the general project landing page (e.g. `https://wnaflcytkubqmrymbmcn.supabase.co`).
   - **Redirect URLs:** Configured with the Supabase auth callback `https://wnaflcytkubqmrymbmcn.supabase.co/auth/v1/callback` (required for Google Cloud Console OAuth redirect URI) and deep link fallback `io.supabase.medicrate://**`.

### Supabase Dashboard Configuration Checklist

```
Supabase Dashboard (wnaflcytkubqmrymbmcn)
├── Authentication -> Providers -> Google
│   ├── Enabled: ON
│   ├── Client ID: 842207080347-ne5...apps.googleusercontent.com (Web Client ID)
│   ├── Client Secret: Google Web Client Secret
│   └── Authorized Client IDs: MUST INCLUDE Android Client ID:
│       842207080347-iua...apps.googleusercontent.com
├── Authentication -> URL Configuration
│   ├── Site URL: https://wnaflcytkubqmrymbmcn.supabase.co
│   └── Redirect URLs:
│       ├── https://wnaflcytkubqmrymbmcn.supabase.co/auth/v1/callback
│       └── io.supabase.medicrate://**
└── Authentication -> Email Templates
    ├── Confirm signup: Must contain {{ .Token }} (6-digit OTP code)
    └── Reset password: Must contain {{ .Token }} (6-digit OTP code)
```

---

## 7. Function Security Architecture & Privileges

MediCrate employs strict function security boundaries across its RPCs and triggers:

| Function | Schema | Security Mode | `search_path` | Volatility | Execution Grants | Security Invariant |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `save_doctor_with_affiliations` | `public` | `SECURITY INVOKER` | `''` (empty) | `VOLATILE` | `authenticated` only | Executes with caller privileges so RLS is enforced on all child operations. Verifies profile ownership via `private.check_doctor_ownership`. Empty `search_path` prevents schema search path hijacking. |
| `delete_user_account` | `public` | `SECURITY DEFINER` | `public, auth, storage, pg_temp` | `VOLATILE` | `authenticated`, `service_role` | Requires elevated privileges to delete from `auth.users(id)` and trigger cascading FK deletes. Enforces storage purge precondition. Explicit `search_path` avoids injection while enabling cross-schema table resolution. |
| `is_profile_active` | `public` | `SECURITY DEFINER` | `''` (empty) | `STABLE` | `authenticated`, `service_role` | Fast STABLE security helper pinned to `auth.uid()`. Evaluates active status without granting callers direct table permissions. |
| `handle_new_user` | `public` | `SECURITY DEFINER` | `''` (empty) | `VOLATILE` | `postgres`, `service_role`, `supabase_auth_admin` | Trigger on `auth.users`. Revoked from `anon` and `authenticated`. Idempotently provisions initial primary 'Self' profile. |
| `check_doctor_ownership` | `private` | `SECURITY DEFINER` | `''` (empty) | `STABLE` | `authenticated` only | Encapsulated in non-exposed `private` schema. PostgREST cannot generate an HTTP endpoint for it. Prevents UUID existence oracle leaks. |

> [!IMPORTANT]
> **Search Path Security Rationale:** In PostgreSQL, functions created without an explicit `SET search_path` are vulnerable to search-path poisoning, where a malicious user could create an operator or function in a schema earlier in the search path. MediCrate pins `search_path = ''` on `SECURITY DEFINER` functions (requiring fully qualified references like `public.profiles` and `auth.uid()`), and pins a strict, trusted list (`public, auth, storage, pg_temp`) on `delete_user_account`.

---

## 8. Reference Seed Data Safety Audit & `ON CONFLICT` Behavior

Inspection of [supabase/seed.sql](file:///home/blackhat/Documents/medi_crate/supabase/seed.sql) confirms:
- **Record Count:** Exactly **79 departments** (IDs 1 through 79).
- **Special Placement:** ID 79 is reserved for `'OTHERS'` and positioned last in display order.
- **Preflight Protections:**
  1. *Check 1 (ID conflict):* Verifies no existing record in `public.medical_departments` has the same ID with a different name.
  2. *Check 2 (Name conflict):* Verifies no authoritative department name exists under a different ID.
  3. *Fail-Fast:* If either preflight check detects a conflict, the script throws a descriptive exception and rolls back without modifying any records.
- **Impact of `ON CONFLICT (id) DO UPDATE`:**
  - The script executes:
    ```sql
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        display_order = EXCLUDED.display_order,
        is_active = EXCLUDED.is_active;
    ```
  - **Operational Warning:** If an operator previously customized department names, customized display orders, or deactivated departments (`is_active = false`) in hosted Supabase, re-running `seed.sql` will **overwrite** those modifications with the canonical repository defaults.
- **Sequence Resynchronization:** Executes `SELECT setval(pg_get_serial_sequence('public.medical_departments', 'id'), MAX(id), true)`.
- **Decoupled Execution:** Seed execution is distinct from schema migration and must be authorized separately after migration verification.

---

## 9. Rollback Safety & Multi-Tier Production Recovery Hierarchy

### Flaws of Destructive Script Rollbacks
Destructive emergency rollback scripts (e.g. `DROP TABLE ... CASCADE` or `DELETE FROM storage.buckets`) are unsafe in production environments for several concrete reasons:
1. **Foreign Key Restraints on Buckets:** `DELETE FROM storage.buckets WHERE id IN (...)` fails immediately if storage objects exist due to foreign key constraints, or orphans physical binary files in storage.
2. **Function Dependency Ordering:** Dropping helper functions like `is_profile_active()` *before* dropping tables causes dependency errors because RLS policies and table constraints depend on those functions.
3. **Trigger Cascade on Active Users:** Dropping `handle_new_user() CASCADE` drops the trigger on `auth.users`, breaking user registration for any new users.
4. **Ledger Desynchronization:** Manually deleting rows from `supabase_migrations.schema_migrations` leaves the actual database state desynchronized from the migration ledger, making future migrations unpredictable.
5. **Storage API vs Raw SQL:** Deleting rows from `storage.objects` via SQL does **not** delete the underlying files on the S3/storage backend. File removal must always be performed via the Supabase Storage API (`remove()`).

### Recommended Multi-Tier Production Recovery Hierarchy

```
[Tier 1: Preferred] ──────► Forward-Fix Migration
                             └── Apply non-destructive, idempotent forward SQL migrations.

[Tier 2: Recovery]  ──────► Snapshot & PITR Restore
                             └── Restore database and storage from verified pre-deployment backups.

[Tier 3: Last Resort] ────► Explicitly Approved Reset
                             └── Applicable ONLY in confirmed disposable dev environments.
```

1. **Tier 1 (Preferred): Forward-Fix Migrations:** If a migration encounters an error during deployment, author an idempotent forward-fix migration (`.sql`) rather than attempting to reverse schema state.
2. **Tier 2: Comprehensive Pre-Deployment Backup:**
   - **Database Backup:** Capture a logical dump before migration:
     ```bash
     pg_dump --clean --if-exists --quote-all-identifiers -h <HOST> -U postgres -d postgres > pre_deployment_db_backup.sql
     ```
   - **Storage Backup:** Storage binary files are **not** included in `pg_dump`. If existing files reside in Storage, sync binary blobs via the Supabase Storage API or S3 CLI before deploying.
   - **Platform PITR:** Confirm that Point-in-Time Recovery (PITR) or daily automated backups are active in Supabase Dashboard (Settings $\rightarrow$ Database $\rightarrow$ Backups).
3. **Tier 3 (Disposable Dev Environments Only): Authorized Teardown:** If and only if the hosted database is confirmed to be an empty disposable development environment, clean teardown must follow this safe sequence:
   - Purge storage objects via the Supabase Storage API (`remove`), NEVER via raw SQL.
   - Drop public clinical tables in reverse dependency order (`CASCADE`).
   - Drop custom functions and `private` schema.
   - Clear migration history entries.

---

## 10. Final Operator Action Checklist

Before granting deployment approval, the operator must complete this checklist:

- [ ] **Step 1:** Execute Queries 1A through 6B in Supabase Studio SQL Editor against `wnaflcytkubqmrymbmcn`.
- [ ] **Step 2:** Compare query outputs against the **Expected Output & Blocking Conditions Matrix** (Section 5). Confirm zero blocking conditions.
- [ ] **Step 3:** In Supabase Dashboard $\rightarrow$ Authentication $\rightarrow$ Providers $\rightarrow$ Google, verify:
  - Google Provider: `ON`
  - Web Client ID: `842207080347-ne5...apps.googleusercontent.com`
  - Authorized Client IDs: includes Android Client ID `842207080347-iua...apps.googleusercontent.com`
- [ ] **Step 4:** In Supabase Dashboard $\rightarrow$ Authentication $\rightarrow$ Email Templates, verify:
  - "Confirm signup" and "Reset password" bodies contain `{{ .Token }}`.
- [ ] **Step 5:** Confirm a pre-deployment database backup is captured or platform backup is active.
- [ ] **Step 6:** Grant explicit authorization to proceed with `supabase db push` followed by `seed.sql`.

---

## 11. Readiness Determination

```
READY FOR MANUAL HOSTED PREFLIGHT
```

*(All local artifacts, migrations, and seed scripts are verified and safety-hardened. The inspection queries are protected against query-planning errors on missing relations and partial columns, the rollback script has been replaced with a three-tier recovery hierarchy, and the complete read-only inspection package is ready for manual operator execution in Supabase Studio.)*
