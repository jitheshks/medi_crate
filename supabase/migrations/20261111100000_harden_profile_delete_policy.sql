-- ==============================================================================
-- Migration: 20261111100000_harden_profile_delete_policy.sql
-- Module: Profiles / Security & Authorization Hardening (Batch 2D)
--
-- Objective:
-- Eliminate the database-level security gap where authenticated users could
-- directly delete family profiles via PostgREST or direct Supabase API requests.
--
-- Security Model & Invariants:
-- 1. Family profiles must use the existing archive/restore workflow (UPDATE is_archived)
--    to prevent accidental permanent deletion of profiles and cascading loss of
--    associated clinical records (consultations, appointments, prescriptions,
--    reports, measurements, vitals).
-- 2. Authenticated users are completely barred from executing DELETE on public.profiles:
--    - RLS Layer: The permissive DELETE policy "Users can delete their own non-primary profiles"
--      is dropped. No replacement DELETE policy is granted to authenticated or anon roles.
--    - Table Privilege Layer: Direct DELETE privilege on public.profiles is explicitly
--      revoked from authenticated, anon, and public roles.
-- 3. Administrative / privileged service-role boundary is preserved:
--    - service_role and postgres retain table privileges (SELECT, INSERT, UPDATE, DELETE)
--      for future authorized administrative erasure operations or maintenance scripts.
--    - Existing foreign key constraints and ON DELETE CASCADE behaviors are strictly preserved.
-- 4. SELECT, INSERT, and UPDATE permissions and policies for authenticated users
--    remain intact, fully preserving profile viewing, creation, updates, and archival/restoration.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DROP AUTHENTICATED DELETE POLICIES ON public.profiles
-- ------------------------------------------------------------------------------

-- 1.1 Explicitly drop the legacy authenticated family profile DELETE policy
DROP POLICY IF EXISTS "Users can delete their own non-primary profiles" ON public.profiles;

-- 1.2 Dynamically drop any other lingering DELETE or ALL permissive policies
--     granting DELETE access to authenticated, anon, or public roles on public.profiles
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'profiles'
          AND cmd IN ('DELETE', 'ALL')
          AND ('authenticated' = ANY(roles) OR 'anon' = ANY(roles) OR 'public' = ANY(roles))
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
        RAISE NOTICE 'Dropped policy % from public.profiles', pol.policyname;
    END LOOP;
END $$;

-- ------------------------------------------------------------------------------
-- 2. DEFENSE IN DEPTH: REVOKE TABLE-LEVEL DELETE PRIVILEGES
-- ------------------------------------------------------------------------------

-- In PostgreSQL, executing an operation requires both SQL table-level privileges
-- and an applicable permissive RLS policy. Revoking DELETE privileges ensures that
-- even if an RLS policy is erroneously introduced in the future, client-facing
-- roles cannot execute DELETE queries against public.profiles.

REVOKE DELETE ON TABLE public.profiles FROM authenticated;
REVOKE DELETE ON TABLE public.profiles FROM anon;
REVOKE DELETE ON TABLE public.profiles FROM public;

-- ------------------------------------------------------------------------------
-- 3. PRESERVE SELECT, INSERT, UPDATE FOR CLIENT ROLES
-- ------------------------------------------------------------------------------

-- Explicitly ensure authenticated users retain required table privileges for
-- viewing, creating, updating, and archiving/restoring health profiles.
GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;

-- ------------------------------------------------------------------------------
-- 4. PRESERVE PRIVILEGED ADMINISTRATIVE SERVICE-ROLE BOUNDARY
-- ------------------------------------------------------------------------------

-- Privileged background services and administrative migrations operating via
-- service_role or postgres superuser retain full privileges, enabling future
-- authorized administrative deletion workflows (e.g., GDPR right-to-be-forgotten)
-- while never exposing this capability to end-user sessions.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO service_role;
GRANT ALL ON TABLE public.profiles TO postgres;

-- ------------------------------------------------------------------------------
-- 5. ACCURATE AUDIT COMMENTS
-- ------------------------------------------------------------------------------

COMMENT ON TABLE public.profiles IS
'Stores personal and family health profiles. Permanent deletion by authenticated users is forbidden; inactive profiles must use the archive/restore workflow (is_archived). Privileged hard deletion is restricted exclusively to authorized administrative service roles.';
