-- ------------------------------------------------------------------------------
-- Migration ID: 20261110080000_prepare_profile_archival_support.sql
-- Description: Prepared schema update for safe Family Profile Archival.
--
-- IMPORTANT SAFETY NOTE:
-- This migration is PREPARED ONLY and has NOT been executed against hosted Supabase.
-- It introduces profile archival metadata, database invariants, and clinical write
-- protections. Archiving retains the profile row and preserves all historical clinical
-- records (consultations, appointments, prescriptions, reports, measurements, and
-- attachments) by avoiding cascading deletions when a family profile is retired.
-- Existing permanent-delete foreign-key behaviour remains unchanged.
-- ------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------
-- 1. PREFLIGHT COLUMN TYPE, NULLABILITY & DEFAULT VERIFICATION
-- Adds is_archived and archived_at while catching schema drift on existing columns.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    v_type text;
    v_nullable text;
    v_default text;
BEGIN
    -- 1.1 Verify or add is_archived
    SELECT data_type, is_nullable, column_default
    INTO v_type, v_nullable, v_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'is_archived';

    IF v_type IS NOT NULL THEN
        IF v_type <> 'boolean'
           OR v_nullable <> 'NO'
           OR v_default IS NULL
           OR lower(trim(v_default)) NOT IN ('false', 'false::boolean') THEN
            RAISE EXCEPTION 'Column public.profiles.is_archived already exists with incompatible definition (type=%, nullable=%, default=%; expected boolean NOT NULL DEFAULT false)',
                v_type, v_nullable, v_default;
        END IF;
    ELSE
        ALTER TABLE public.profiles
            ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT FALSE;
    END IF;

    -- 1.2 Verify or add archived_at
    SELECT data_type, is_nullable, column_default
    INTO v_type, v_nullable, v_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'archived_at';

    IF v_type IS NOT NULL THEN
        IF v_type <> 'timestamp with time zone' OR v_nullable <> 'YES' OR v_default IS NOT NULL THEN
            RAISE EXCEPTION 'Column public.profiles.archived_at already exists with incompatible definition (type=%, nullable=%, default=%; expected timestamptz NULL with no default)',
                v_type, v_nullable, v_default;
        END IF;
    ELSE
        ALTER TABLE public.profiles
            ADD COLUMN archived_at TIMESTAMPTZ;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. PRE-EXISTING DATA INTEGRITY VALIDATION
-- Halts migration if existing data violates archival invariants before applying rules.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    v_invalid_count int;
BEGIN
    -- 2.1 Primary profiles cannot be archived
    SELECT count(*) INTO v_invalid_count
    FROM public.profiles
    WHERE is_primary = TRUE AND is_archived = TRUE;

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'Data integrity violation: found % primary profiles already marked as archived.', v_invalid_count;
    END IF;

    -- 2.2 Active profiles cannot have an archival timestamp
    SELECT count(*) INTO v_invalid_count
    FROM public.profiles
    WHERE is_archived = FALSE AND archived_at IS NOT NULL;

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'Data integrity violation: found % active profiles with non-null archived_at timestamps.', v_invalid_count;
    END IF;

    -- 2.3 Archived profiles must have an archival timestamp
    SELECT count(*) INTO v_invalid_count
    FROM public.profiles
    WHERE is_archived = TRUE AND archived_at IS NULL;

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'Data integrity violation: found % archived profiles with null archived_at timestamps.', v_invalid_count;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. PRIMARY PROFILE ARCHIVAL IMMUTABILITY CONSTRAINT
-- Scoped to public.profiles relation, verifies exact expression, constraint type, and validation state.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    v_def text;
    v_validated boolean;
    v_contype "char";
BEGIN
    SELECT pg_get_constraintdef(oid), convalidated, contype
    INTO v_def, v_validated, v_contype
    FROM pg_constraint
    WHERE conname = 'check_profiles_primary_not_archived'
      AND conrelid = 'public.profiles'::regclass;

    IF v_def IS NULL THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT check_profiles_primary_not_archived
            CHECK (NOT (is_primary = TRUE AND is_archived = TRUE));
    ELSE
        IF v_contype <> 'c' THEN
            RAISE EXCEPTION 'Constraint check_profiles_primary_not_archived on public.profiles has unexpected constraint type: %, expected "c" (check)', v_contype;
        END IF;

        IF v_def NOT IN (
            'CHECK ((NOT ((is_primary = true) AND (is_archived = true))))',
            'CHECK ((NOT (is_primary AND is_archived)))',
            'CHECK (((is_primary = false) OR (is_archived = false)))'
        ) THEN
            RAISE EXCEPTION 'Constraint check_profiles_primary_not_archived on public.profiles has unexpected definition: %', v_def;
        END IF;

        IF NOT v_validated THEN
            RAISE EXCEPTION 'Constraint check_profiles_primary_not_archived on public.profiles is present but not validated!';
        END IF;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 4. PARTIAL INDEX FOR ACTIVE PROFILES
-- Validates index via system catalog (validity, readiness, btree, non-uniqueness, attribute, predicate).
-- Rejects incompatible existing indexes with unexpected columns, access methods, or expressions.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    v_valid boolean;
    v_ready boolean;
    v_unique boolean;
    v_am text;
    v_nkeyatts smallint;
    v_natts smallint;
    v_has_expr boolean;
    v_col text;
    v_pred text;
BEGIN
    SELECT
        ix.indisvalid,
        ix.indisready,
        ix.indisunique,
        am.amname,
        ix.indnkeyatts,
        ix.indnatts,
        (ix.indexprs IS NOT NULL),
        a.attname,
        pg_get_expr(ix.indpred, ix.indrelid)
    INTO v_valid, v_ready, v_unique, v_am, v_nkeyatts, v_natts, v_has_expr, v_col, v_pred
    FROM pg_index ix
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_class t ON t.oid = ix.indrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN pg_am am ON am.oid = i.relam
    LEFT JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ix.indkey[0]
    WHERE n.nspname = 'public'
      AND t.relname = 'profiles'
      AND i.relname = 'idx_profiles_user_active';

    IF v_valid IS NULL THEN
        CREATE INDEX idx_profiles_user_active
            ON public.profiles(user_id)
            WHERE is_archived = FALSE;
    ELSE
        IF NOT v_valid THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active exists on public.profiles but is marked invalid!';
        END IF;
        IF NOT v_ready THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active exists on public.profiles but is not marked ready!';
        END IF;
        IF v_unique THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active on public.profiles is unique, expected non-unique!';
        END IF;
        IF v_am <> 'btree' THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active on public.profiles uses access method %, expected btree!', v_am;
        END IF;
        IF v_nkeyatts <> 1 OR v_natts <> 1 THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active on public.profiles has % columns (% key attributes), expected exactly 1 key column (user_id)!', v_natts, v_nkeyatts;
        END IF;
        IF v_has_expr THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active on public.profiles contains expression keys, expected plain attribute (user_id)!';
        END IF;
        IF v_col IS NULL OR v_col <> 'user_id' THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active is indexed on %, expected user_id!', COALESCE(v_col, '<expression>');
        END IF;
        IF v_pred IS NULL OR v_pred NOT IN ('(is_archived = false)', '(NOT is_archived)') THEN
            RAISE EXCEPTION 'Index idx_profiles_user_active on public.profiles has unexpected predicate: %', v_pred;
        END IF;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 5. ARCHIVAL TRIGGER FUNCTION & TRIGGER
-- Procedural protection for archival status and timestamp invariants:
--   - Covers BOTH INSERT and UPDATE.
--   - Rejects inserting a profile that is already archived.
--   - Prohibits archiving the primary Self profile.
--   - Automatically sets archived_at to now() when transitioned active -> archived.
--   - Automatically clears archived_at to NULL when restored archived -> active.
--   - Strictly preserves OLD.archived_at during repeated updates while archived,
--     neutralizing any client-side tampering or accidental nullification.
--   - Enforces archived_at = NULL for active profiles.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_profile_archival_invariant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = 'pg_catalog'
AS $$
BEGIN
    -- 5.1 INSERT Handling: New profiles must be created active
    IF TG_OP = 'INSERT' THEN
        IF NEW.is_archived IS TRUE THEN
            RAISE EXCEPTION 'Cannot insert a profile that is already archived. New profiles must be created active.'
                USING ERRCODE = 'check_violation';
        END IF;

        IF NEW.archived_at IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot insert a profile with an archival timestamp. New profiles must be created active.'
                USING ERRCODE = 'check_violation';
        END IF;

        NEW.is_archived := FALSE;
        NEW.archived_at := NULL;
        RETURN NEW;
    END IF;

    -- 5.2 UPDATE Handling: Invariants & Server-Controlled Timestamps
    IF TG_OP = 'UPDATE' THEN
        IF NEW.is_primary = TRUE AND NEW.is_archived = TRUE THEN
            RAISE EXCEPTION 'Primary profile cannot be archived.'
                USING ERRCODE = 'check_violation';
        END IF;

        IF OLD.is_archived = FALSE AND NEW.is_archived = TRUE THEN
            -- Transition Active -> Archived: assign authoritative server timestamp
            NEW.archived_at := pg_catalog.now();
        ELSIF OLD.is_archived = TRUE AND NEW.is_archived = FALSE THEN
            -- Transition Archived -> Active: clear archival timestamp
            NEW.archived_at := NULL;
        ELSIF OLD.is_archived = TRUE AND NEW.is_archived = TRUE THEN
            -- Remained Archived: strictly preserve original archival timestamp, neutralizing client tampering
            NEW.archived_at := OLD.archived_at;
        ELSIF OLD.is_archived = FALSE AND NEW.is_archived = FALSE THEN
            -- Remained Active: ensure no archival timestamp can be attached
            NEW.archived_at := NULL;
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_archival_invariant ON public.profiles;
CREATE TRIGGER trg_protect_profile_archival_invariant
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_archival_invariant();

-- ------------------------------------------------------------------------------
-- 6. ACCURATE COLUMN COMMENTS
-- ------------------------------------------------------------------------------
COMMENT ON COLUMN public.profiles.is_archived IS
'Indicates whether a family profile is archived. Archiving retains the profile row and its linked clinical records. Application queries must exclude archived profiles from active profile selection while preserving access to historical clinical records.';

COMMENT ON COLUMN public.profiles.archived_at IS
'Timestamp when the family profile was transitioned from active to archived. Managed exclusively by trg_protect_profile_archival_invariant.';

-- ------------------------------------------------------------------------------
-- 7. CLINICAL DATA WRITE PROTECTION (HELPER & RLS POLICIES)
-- Prevents creating new clinical records or mutating existing records under archived
-- profiles, while keeping historical SELECT (read) and DELETE access completely available.
-- ------------------------------------------------------------------------------

-- 7.1 Hardened Active Profile Verification Helper (Pinned to auth.uid())
CREATE OR REPLACE FUNCTION public.is_profile_active(p_profile_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = p_profile_id
          AND user_id = auth.uid()
          AND is_archived = FALSE
    );
$$;

-- Restrict execution: Revoke default PUBLIC and anon privileges
REVOKE ALL ON FUNCTION public.is_profile_active(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_profile_active(UUID) TO authenticated, service_role;

COMMENT ON FUNCTION public.is_profile_active(UUID) IS
'Returns TRUE if and only if the specified profile belongs to the authenticated caller (auth.uid()) and is active (not archived).';

-- 7.2 Dedicated Privileged Helper for service_role administrative operations
CREATE OR REPLACE FUNCTION public.is_profile_active_for_user(p_profile_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = p_profile_id
          AND user_id = p_user_id
          AND is_archived = FALSE
    );
$$;

REVOKE ALL ON FUNCTION public.is_profile_active_for_user(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_profile_active_for_user(UUID, UUID) TO service_role;

COMMENT ON FUNCTION public.is_profile_active_for_user(UUID, UUID) IS
'Privileged helper restricted to service_role to verify active profile status for a designated user_id.';

-- 7.3 Consultations Write Protection
DROP POLICY IF EXISTS "Users can create their own consultations" ON public.consultations;
CREATE POLICY "Users can create their own consultations"
    ON public.consultations FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

DROP POLICY IF EXISTS "Users can update their own consultations" ON public.consultations;
CREATE POLICY "Users can update their own consultations"
    ON public.consultations FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    )
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

-- 7.4 Appointments Write Protection
DROP POLICY IF EXISTS "Users can create their own appointments" ON public.appointments;
CREATE POLICY "Users can create their own appointments"
    ON public.appointments FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

DROP POLICY IF EXISTS "Users can update their own appointments" ON public.appointments;
CREATE POLICY "Users can update their own appointments"
    ON public.appointments FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    )
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

-- 7.5 Prescriptions Write Protection
DROP POLICY IF EXISTS "Users can create their own prescriptions" ON public.prescriptions;
CREATE POLICY "Users can create their own prescriptions"
    ON public.prescriptions FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

DROP POLICY IF EXISTS "Users can update their own prescriptions" ON public.prescriptions;
CREATE POLICY "Users can update their own prescriptions"
    ON public.prescriptions FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    )
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

-- 7.6 Reports Write Protection
DROP POLICY IF EXISTS "Users can create their own reports" ON public.reports;
CREATE POLICY "Users can create their own reports"
    ON public.reports FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

DROP POLICY IF EXISTS "Users can update their own reports" ON public.reports;
CREATE POLICY "Users can update their own reports"
    ON public.reports FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    )
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

-- 7.7 Measurements Write Protection
DROP POLICY IF EXISTS "Users can create their own measurements" ON public.measurements;
CREATE POLICY "Users can create their own measurements"
    ON public.measurements FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

DROP POLICY IF EXISTS "Users can update their own measurements" ON public.measurements;
CREATE POLICY "Users can update their own measurements"
    ON public.measurements FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    )
    WITH CHECK (
        auth.uid() = user_id
        AND public.is_profile_active(profile_id)
    );

-- 7.8 Consultation Attachments Write Protection
DROP POLICY IF EXISTS "Users can create their own consultation attachments" ON public.consultation_attachments;
CREATE POLICY "Users can create their own consultation attachments"
    ON public.consultation_attachments FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.consultations c
            WHERE c.id = consultation_id
              AND c.user_id = auth.uid()
              AND public.is_profile_active(c.profile_id)
        )
    );

DROP POLICY IF EXISTS "Users can update their own consultation attachments" ON public.consultation_attachments;
CREATE POLICY "Users can update their own consultation attachments"
    ON public.consultation_attachments FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.consultations c
            WHERE c.id = consultation_id
              AND c.user_id = auth.uid()
              AND public.is_profile_active(c.profile_id)
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.consultations c
            WHERE c.id = consultation_id
              AND c.user_id = auth.uid()
              AND public.is_profile_active(c.profile_id)
        )
    );

-- 7.9 Report Attachments Write Protection
DROP POLICY IF EXISTS "Users can create their own report attachments" ON public.report_attachments;
CREATE POLICY "Users can create their own report attachments"
    ON public.report_attachments FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.reports r
            WHERE r.id = report_id
              AND r.user_id = auth.uid()
              AND public.is_profile_active(r.profile_id)
        )
    );

DROP POLICY IF EXISTS "Users can update their own report attachments" ON public.report_attachments;
CREATE POLICY "Users can update their own report attachments"
    ON public.report_attachments FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.reports r
            WHERE r.id = report_id
              AND r.user_id = auth.uid()
              AND public.is_profile_active(r.profile_id)
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.reports r
            WHERE r.id = report_id
              AND r.user_id = auth.uid()
              AND public.is_profile_active(r.profile_id)
        )
    );

-- 7.10 Report Expenses Write Protection
DROP POLICY IF EXISTS "Users can create their own report expenses" ON public.report_expenses;
CREATE POLICY "Users can create their own report expenses"
    ON public.report_expenses FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.reports r
            WHERE r.id = report_id
              AND r.user_id = auth.uid()
              AND public.is_profile_active(r.profile_id)
        )
    );

DROP POLICY IF EXISTS "Users can update their own report expenses" ON public.report_expenses;
CREATE POLICY "Users can update their own report expenses"
    ON public.report_expenses FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.reports r
            WHERE r.id = report_id
              AND r.user_id = auth.uid()
              AND public.is_profile_active(r.profile_id)
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM public.reports r
            WHERE r.id = report_id
              AND r.user_id = auth.uid()
              AND public.is_profile_active(r.profile_id)
        )
    );

-- ------------------------------------------------------------------------------
-- 8. STORAGE OBJECTS WRITE PROTECTION (UPLOADS & UPDATES)
-- Blocks new file uploads or updates to consultations/reports of archived profiles,
-- while preserving SELECT permissions for viewing/downloading historical attachments.
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'storage' AND tablename = 'objects'
    ) THEN
        -- 8.1 Consultations Upload Protection
        DROP POLICY IF EXISTS "Users can upload their own consultation attachments" ON storage.objects;
        CREATE POLICY "Users can upload their own consultation attachments"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (
                bucket_id = 'consultations'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (storage.foldername(name))[2] IS NOT NULL
                AND array_length(storage.foldername(name), 1) = 2
                AND LOWER(storage.extension(name)) IN ('pdf', 'jpg', 'jpeg', 'png', 'webp')
                AND EXISTS (
                    SELECT 1 FROM public.consultations c
                    WHERE c.id::text = (storage.foldername(name))[2]
                      AND c.user_id = auth.uid()
                      AND public.is_profile_active(c.profile_id)
                )
            );

        -- 8.2 Consultations Update Protection
        DROP POLICY IF EXISTS "Users can update their own consultation attachments" ON storage.objects;
        CREATE POLICY "Users can update their own consultation attachments"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (
                bucket_id = 'consultations'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (storage.foldername(name))[2] IS NOT NULL
                AND array_length(storage.foldername(name), 1) = 2
                AND EXISTS (
                    SELECT 1 FROM public.consultations c
                    WHERE c.id::text = (storage.foldername(name))[2]
                      AND c.user_id = auth.uid()
                      AND public.is_profile_active(c.profile_id)
                )
            )
            WITH CHECK (
                bucket_id = 'consultations'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (storage.foldername(name))[2] IS NOT NULL
                AND array_length(storage.foldername(name), 1) = 2
                AND LOWER(storage.extension(name)) IN ('pdf', 'jpg', 'jpeg', 'png', 'webp')
                AND EXISTS (
                    SELECT 1 FROM public.consultations c
                    WHERE c.id::text = (storage.foldername(name))[2]
                      AND c.user_id = auth.uid()
                      AND public.is_profile_active(c.profile_id)
                )
            );

        -- 8.3 Reports Upload Protection
        DROP POLICY IF EXISTS "Users can upload their own report attachments" ON storage.objects;
        CREATE POLICY "Users can upload their own report attachments"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (
                bucket_id = 'reports'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (storage.foldername(name))[2] IS NOT NULL
                AND array_length(storage.foldername(name), 1) = 2
                AND LOWER(storage.extension(name)) IN ('pdf', 'jpg', 'jpeg', 'png', 'webp')
                AND EXISTS (
                    SELECT 1 FROM public.reports r
                    WHERE r.id::text = (storage.foldername(name))[2]
                      AND r.user_id = auth.uid()
                      AND public.is_profile_active(r.profile_id)
                )
            );

        -- 8.4 Reports Update Protection
        DROP POLICY IF EXISTS "Users can update their own report attachments" ON storage.objects;
        CREATE POLICY "Users can update their own report attachments"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (
                bucket_id = 'reports'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (storage.foldername(name))[2] IS NOT NULL
                AND array_length(storage.foldername(name), 1) = 2
                AND EXISTS (
                    SELECT 1 FROM public.reports r
                    WHERE r.id::text = (storage.foldername(name))[2]
                      AND r.user_id = auth.uid()
                      AND public.is_profile_active(r.profile_id)
                )
            )
            WITH CHECK (
                bucket_id = 'reports'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (storage.foldername(name))[2] IS NOT NULL
                AND array_length(storage.foldername(name), 1) = 2
                AND LOWER(storage.extension(name)) IN ('pdf', 'jpg', 'jpeg', 'png', 'webp')
                AND EXISTS (
                    SELECT 1 FROM public.reports r
                    WHERE r.id::text = (storage.foldername(name))[2]
                      AND r.user_id = auth.uid()
                      AND public.is_profile_active(r.profile_id)
                )
            );

        -- 8.5 Avatars View Protection (SELECT)
        -- Preserves historical avatar access for profiles owned by auth.uid().
        DROP POLICY IF EXISTS "Users can view their own avatars" ON storage.objects;
        CREATE POLICY "Users can view their own avatars"
            ON storage.objects FOR SELECT
            TO authenticated
            USING (
                bucket_id = 'avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (
                    (array_length(storage.foldername(name), 1) = 1)
                    OR
                    (
                        array_length(storage.foldername(name), 1) = 2
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.id::text = (storage.foldername(name))[2]
                              AND p.user_id = auth.uid()
                        )
                    )
                )
            );

        -- 8.6 Avatars Upload Protection (INSERT)
        -- Blocks avatar uploads for archived profiles.
        DROP POLICY IF EXISTS "Users can upload their own avatars" ON storage.objects;
        CREATE POLICY "Users can upload their own avatars"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (
                bucket_id = 'avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
                AND (
                    (
                        array_length(storage.foldername(name), 1) = 1
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.user_id = auth.uid()
                              AND p.is_primary = TRUE
                              AND public.is_profile_active(p.id)
                        )
                    )
                    OR
                    (
                        array_length(storage.foldername(name), 1) = 2
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.id::text = (storage.foldername(name))[2]
                              AND p.user_id = auth.uid()
                              AND public.is_profile_active(p.id)
                        )
                    )
                )
            );

        -- 8.7 Avatars Update Protection (UPDATE)
        -- Blocks avatar replacements for archived profiles in both USING and WITH CHECK.
        DROP POLICY IF EXISTS "Users can update their own avatars" ON storage.objects;
        CREATE POLICY "Users can update their own avatars"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (
                bucket_id = 'avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (
                    (
                        array_length(storage.foldername(name), 1) = 1
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.user_id = auth.uid()
                              AND p.is_primary = TRUE
                              AND public.is_profile_active(p.id)
                        )
                    )
                    OR
                    (
                        array_length(storage.foldername(name), 1) = 2
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.id::text = (storage.foldername(name))[2]
                              AND p.user_id = auth.uid()
                              AND public.is_profile_active(p.id)
                        )
                    )
                )
            )
            WITH CHECK (
                bucket_id = 'avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
                AND (
                    (
                        array_length(storage.foldername(name), 1) = 1
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.user_id = auth.uid()
                              AND p.is_primary = TRUE
                              AND public.is_profile_active(p.id)
                        )
                    )
                    OR
                    (
                        array_length(storage.foldername(name), 1) = 2
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.id::text = (storage.foldername(name))[2]
                              AND p.user_id = auth.uid()
                              AND public.is_profile_active(p.id)
                        )
                    )
                )
            );

        -- 8.8 Avatars Delete Protection (DELETE)
        -- Allows deletion of avatars belonging to auth.uid(), even if the profile is archived.
        DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;
        CREATE POLICY "Users can delete their own avatars"
            ON storage.objects FOR DELETE
            TO authenticated
            USING (
                bucket_id = 'avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
                AND (
                    (array_length(storage.foldername(name), 1) = 1)
                    OR
                    (
                        array_length(storage.foldername(name), 1) = 2
                        AND EXISTS (
                            SELECT 1 FROM public.profiles p
                            WHERE p.id::text = (storage.foldername(name))[2]
                              AND p.user_id = auth.uid()
                        )
                    )
                )
            );
    END IF;
END $$;
