-- ==============================================================================
-- Migration: 20261112130000_create_delete_user_account_rpc.sql
-- Module: Auth / Account Deletion & Storage Lifecycle (B5)
--
-- Objective:
-- Implement an atomic, secure account deletion workflow for authenticated users (B5).
--
-- Security & Operational Invariants:
-- 1. Identity Verification: Operates strictly on auth.uid() to ensure callers can
--    only delete their own account.
-- 2. SECURITY DEFINER Privilege Boundary: Runs with elevated privileges to delete from
--    auth.users, with restricted search_path = public, auth, storage, pg_temp.
-- 3. Storage Precondition Check: Enforces that all user storage objects across
--    'avatars', 'consultations', and 'reports' buckets have been purged via the
--    Supabase Storage API before permitting database deletion. Direct deletion of
--    storage.objects is prohibited to prevent orphaned physical files.
-- 4. Primary Profile Protection Bypass: Sets transaction-local configuration
--    'app.deleting_user_account' = 'true' so protect_profile_primary_deletion()
--    permits the cascading deletion of the primary Self profile.
-- 5. Foreign Key Cascades: Deletion of auth.users(id) automatically and
--    transactionally cascades to public.profiles, public.consultations,
--    public.appointments, public.prescriptions, public.reports,
--    public.measurements, public.doctors, public.hospitals, and all child tables.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. UPDATE PRIMARY PROFILE DELETION TRIGGER FUNCTION
-- ------------------------------------------------------------------------------

-- Update protect_profile_primary_deletion() to allow cascading primary profile
-- deletion when executing within the authorized account deletion workflow.
CREATE OR REPLACE FUNCTION public.protect_profile_primary_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Permit deletion during complete account deletion workflow
    IF current_setting('app.deleting_user_account', true) = 'true' THEN
        RETURN OLD;
    END IF;

    -- Standard invariant: prevent direct/client deletion of primary profile
    IF OLD.is_primary = TRUE AND auth.uid() IS NOT NULL THEN
        RAISE EXCEPTION 'Primary profile cannot be deleted.';
    END IF;

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.protect_profile_primary_deletion() IS
'Prevents direct deletion of primary profiles during normal client operations, while allowing cascading deletion during full account deletion (app.deleting_user_account).';

-- ------------------------------------------------------------------------------
-- 2. CREATE ACCOUNT DELETION RPC FUNCTION
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    -- 1. Security Check: Active authenticated session is required
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Active authenticated session required to delete account.';
    END IF;

    -- 2. Storage Precondition Check:
    --    Verify that user files in private buckets have been purged via the Storage API.
    --    Direct deletion of storage.objects is strictly prohibited to prevent physical orphaned files.
    IF EXISTS (
        SELECT 1 FROM storage.objects
        WHERE bucket_id IN ('avatars', 'consultations', 'reports')
          AND (
              (storage.foldername(name))[1] = v_user_id::text
              OR name LIKE v_user_id::text || '/%'
              OR owner = v_user_id
          )
    ) THEN
        RAISE EXCEPTION 'Precondition Failed: Active storage objects remain. Purge storage files via Supabase Storage API before deleting account.';
    END IF;

    -- 3. Set transaction-local flag so primary profile deletion invariant allows cascade
    PERFORM set_config('app.deleting_user_account', 'true', true);

    -- 4. Delete the user from auth.users
    --    Foreign key constraints (ON DELETE CASCADE) across all public tables:
    --    profiles, hospitals, doctors, doctor_hospitals, consultations,
    --    consultation_attachments, appointments, prescriptions, reports,
    --    report_attachments, report_expenses, measurements
    --    will automatically and transactionally cascade delete all associated records.
    DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. PERMISSIONS & ROLE GRANTS
-- ------------------------------------------------------------------------------

-- Restrict execution: revoke from PUBLIC and anon, grant only to authenticated and service_role
REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_account() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO service_role;

-- ------------------------------------------------------------------------------
-- 4. AUDIT DOCUMENTATION
-- ------------------------------------------------------------------------------

COMMENT ON FUNCTION public.delete_user_account() IS
'Atomically deletes the calling authenticated user and cascades deletion across all public clinical tables via auth.users FK cascade. Enforces that all user storage objects were purged beforehand via the Storage API.';
