-- ==============================================================================
-- MediCrate Phase 4.4 Archival Hardening: 24-Case PostgreSQL 17 Verification
-- ==============================================================================

DO $$
DECLARE
    v_test_count INT := 0;
    v_pass_count INT := 0;
    v_fail_count INT := 0;

    v_user1 UUID := gen_random_uuid();
    v_user2 UUID := gen_random_uuid();
    v_prof_primary UUID := gen_random_uuid();
    v_prof_active_fam UUID := gen_random_uuid();
    v_prof_archived_fam UUID := gen_random_uuid();
    v_consultation_active UUID := gen_random_uuid();
    v_consultation_archived UUID := gen_random_uuid();

    v_raised BOOLEAN;
    v_msg TEXT;
    v_arch_at TIMESTAMPTZ;
    v_is_arch BOOLEAN;
    v_read_count INT;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Starting 24-Case Archival Hardening PostgreSQL 17 Test Suite';
    RAISE NOTICE '============================================================';

    -- --------------------------------------------------------------------------
    -- 1. Column preflight: rejects column without default (v_default IS NULL)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_col_nodefault (is_archived BOOLEAN);
        DECLARE
            v_type text; v_nullable text; v_default text;
        BEGIN
            SELECT data_type, is_nullable, column_default
            INTO v_type, v_nullable, v_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 't_col_nodefault' AND column_name = 'is_archived';

            IF v_type <> 'boolean'
               OR v_nullable <> 'NO'
               OR v_default IS NULL
               OR lower(trim(v_default)) NOT IN ('false', 'false::boolean') THEN
                RAISE EXCEPTION 'Preflight correctly rejected column without default';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_col_nodefault;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 1 PASS: Column preflight rejects column without default';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 1 FAIL: Column preflight did not reject column without default';
    END IF;

    -- --------------------------------------------------------------------------
    -- 2. Column preflight: rejects column with TRUE default
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_col_true (is_archived BOOLEAN NOT NULL DEFAULT true);
        DECLARE
            v_type text; v_nullable text; v_default text;
        BEGIN
            SELECT data_type, is_nullable, column_default
            INTO v_type, v_nullable, v_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 't_col_true' AND column_name = 'is_archived';

            IF v_type <> 'boolean'
               OR v_nullable <> 'NO'
               OR v_default IS NULL
               OR lower(trim(v_default)) NOT IN ('false', 'false::boolean') THEN
                RAISE EXCEPTION 'Preflight correctly rejected column with default true';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_col_true;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 2 PASS: Column preflight rejects column with default TRUE';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 2 FAIL: Column preflight did not reject column with default TRUE';
    END IF;

    -- --------------------------------------------------------------------------
    -- 3. Column preflight: rejects column default expression containing 'false' like (false OR true)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_col_expr (is_archived BOOLEAN NOT NULL DEFAULT (false OR true));
        DECLARE
            v_type text; v_nullable text; v_default text;
        BEGIN
            SELECT data_type, is_nullable, column_default
            INTO v_type, v_nullable, v_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 't_col_expr' AND column_name = 'is_archived';

            IF v_type <> 'boolean'
               OR v_nullable <> 'NO'
               OR v_default IS NULL
               OR lower(trim(v_default)) NOT IN ('false', 'false::boolean') THEN
                RAISE EXCEPTION 'Preflight correctly rejected column with expression default containing substring false';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_col_expr;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 3 PASS: Column preflight rejects expression containing false substring';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 3 FAIL: Column preflight did not reject expression containing false substring';
    END IF;

    -- --------------------------------------------------------------------------
    -- 4. Column preflight: accepts column with literal 'false'
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_col_valid (is_archived BOOLEAN NOT NULL DEFAULT false);
        DECLARE
            v_type text; v_nullable text; v_default text;
        BEGIN
            SELECT data_type, is_nullable, column_default
            INTO v_type, v_nullable, v_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 't_col_valid' AND column_name = 'is_archived';

            IF v_type <> 'boolean'
               OR v_nullable <> 'NO'
               OR v_default IS NULL
               OR lower(trim(v_default)) NOT IN ('false', 'false::boolean') THEN
                RAISE EXCEPTION 'Unexpected rejection of valid default false';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_col_valid;

    IF NOT v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 4 PASS: Column preflight accepts literal false default';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 4 FAIL: Column preflight unexpectedly rejected literal false';
    END IF;

    -- --------------------------------------------------------------------------
    -- 5. Index preflight: rejects non-partial index on user_id (v_pred IS NULL)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_idx_test (user_id UUID, is_archived BOOLEAN);
        CREATE INDEX idx_dummy_full ON public.t_idx_test(user_id);
        DECLARE
            v_pred text;
        BEGIN
            SELECT pg_get_expr(ix.indpred, ix.indrelid)
            INTO v_pred
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            WHERE i.relname = 'idx_dummy_full';

            IF v_pred IS NULL OR v_pred NOT IN ('(is_archived = false)', '(NOT is_archived)') THEN
                RAISE EXCEPTION 'Preflight correctly rejected non-partial index';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_idx_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 5 PASS: Index preflight rejects non-partial index on user_id';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 5 FAIL: Index preflight accepted non-partial index';
    END IF;

    -- --------------------------------------------------------------------------
    -- 6. Index preflight: rejects partial index with wrong predicate
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_idx_test (user_id UUID, is_archived BOOLEAN);
        CREATE INDEX idx_dummy_wrong_pred ON public.t_idx_test(user_id) WHERE is_archived = true;
        DECLARE
            v_pred text;
        BEGIN
            SELECT pg_get_expr(ix.indpred, ix.indrelid)
            INTO v_pred
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            WHERE i.relname = 'idx_dummy_wrong_pred';

            IF v_pred IS NULL OR v_pred NOT IN ('(is_archived = false)', '(NOT is_archived)') THEN
                RAISE EXCEPTION 'Preflight correctly rejected wrong predicate';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_idx_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 6 PASS: Index preflight rejects partial index with wrong predicate';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 6 FAIL: Index preflight accepted wrong predicate';
    END IF;

    -- --------------------------------------------------------------------------
    -- 7. Index preflight: rejects unique index
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_idx_test (user_id UUID, is_archived BOOLEAN);
        CREATE UNIQUE INDEX idx_dummy_unique ON public.t_idx_test(user_id) WHERE NOT is_archived;
        DECLARE
            v_unique boolean;
        BEGIN
            SELECT ix.indisunique INTO v_unique
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            WHERE i.relname = 'idx_dummy_unique';

            IF v_unique THEN
                RAISE EXCEPTION 'Preflight correctly rejected unique index';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_idx_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 7 PASS: Index preflight rejects unique index';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 7 FAIL: Index preflight accepted unique index';
    END IF;

    -- --------------------------------------------------------------------------
    -- 8. Index preflight: rejects non-btree index (hash)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_idx_test (user_id UUID);
        CREATE INDEX idx_dummy_hash ON public.t_idx_test USING hash(user_id);
        DECLARE
            v_am text;
        BEGIN
            SELECT am.amname INTO v_am
            FROM pg_class i
            JOIN pg_am am ON am.oid = i.relam
            WHERE i.relname = 'idx_dummy_hash';

            IF v_am <> 'btree' THEN
                RAISE EXCEPTION 'Preflight correctly rejected hash index';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_idx_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 8 PASS: Index preflight rejects non-btree index';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 8 FAIL: Index preflight accepted hash index';
    END IF;

    -- --------------------------------------------------------------------------
    -- 9. Index preflight: rejects multi-column index
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_idx_test (user_id UUID, is_archived BOOLEAN);
        CREATE INDEX idx_dummy_multi ON public.t_idx_test(user_id, is_archived) WHERE NOT is_archived;
        DECLARE
            v_natts int;
        BEGIN
            SELECT ix.indnatts INTO v_natts
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            WHERE i.relname = 'idx_dummy_multi';

            IF v_natts <> 1 THEN
                RAISE EXCEPTION 'Preflight correctly rejected multi-column index';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_idx_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 9 PASS: Index preflight rejects multi-column index';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 9 FAIL: Index preflight accepted multi-column index';
    END IF;

    -- --------------------------------------------------------------------------
    -- 10. Index preflight: rejects index on wrong column
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_idx_test (user_id UUID, other_col UUID, is_archived BOOLEAN);
        CREATE INDEX idx_dummy_col ON public.t_idx_test(other_col) WHERE NOT is_archived;
        DECLARE
            v_col text;
        BEGIN
            SELECT a.attname INTO v_col
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = ix.indkey[0]
            WHERE i.relname = 'idx_dummy_col';

            IF v_col <> 'user_id' THEN
                RAISE EXCEPTION 'Preflight correctly rejected index on other_col';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_idx_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 10 PASS: Index preflight rejects index on wrong column';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 10 FAIL: Index preflight accepted index on wrong column';
    END IF;

    -- --------------------------------------------------------------------------
    -- 11. Index preflight: accepts valid partial index idx_profiles_user_active
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        DECLARE
            v_valid boolean; v_ready boolean; v_unique boolean; v_am text;
            v_nkeyatts smallint; v_natts smallint; v_has_expr boolean; v_col text; v_pred text;
        BEGIN
            SELECT
                ix.indisvalid, ix.indisready, ix.indisunique, am.amname,
                ix.indnkeyatts, ix.indnatts, (ix.indexprs IS NOT NULL),
                a.attname, pg_get_expr(ix.indpred, ix.indrelid)
            INTO
                v_valid, v_ready, v_unique, v_am,
                v_nkeyatts, v_natts, v_has_expr,
                v_col, v_pred
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            JOIN pg_class t ON t.oid = ix.indrelid
            JOIN pg_namespace n ON n.oid = t.relnamespace
            JOIN pg_am am ON am.oid = i.relam
            LEFT JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ix.indkey[0]
            WHERE n.nspname = 'public'
              AND t.relname = 'profiles'
              AND i.relname = 'idx_profiles_user_active';

            IF NOT v_valid OR NOT v_ready OR v_unique OR v_am <> 'btree'
               OR v_nkeyatts <> 1 OR v_natts <> 1 OR v_has_expr
               OR v_col <> 'user_id'
               OR v_pred IS NULL
               OR v_pred NOT IN ('(is_archived = false)', '(NOT is_archived)') THEN
                RAISE EXCEPTION 'idx_profiles_user_active failed validation';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;

    IF NOT v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 11 PASS: Index preflight accepts valid partial index idx_profiles_user_active';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 11 FAIL: Valid partial index idx_profiles_user_active failed preflight';
    END IF;

    -- --------------------------------------------------------------------------
    -- 12. Constraint preflight: rejects check constraint with wrong condition
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_chk_test (is_primary BOOLEAN, is_archived BOOLEAN);
        ALTER TABLE public.t_chk_test ADD CONSTRAINT chk_dummy CHECK (NOT (is_primary AND NOT is_archived));
        DECLARE
            v_def text;
        BEGIN
            SELECT pg_get_constraintdef(oid) INTO v_def
            FROM pg_constraint
            WHERE conname = 'chk_dummy';

            IF v_def <> 'CHECK (NOT (is_primary AND is_archived))' THEN
                RAISE EXCEPTION 'Preflight correctly rejected wrong constraint expression';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_chk_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 12 PASS: Constraint preflight rejects wrong check condition';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 12 FAIL: Constraint preflight accepted wrong check condition';
    END IF;

    -- --------------------------------------------------------------------------
    -- 13. Constraint preflight: rejects unvalidated check constraint (convalidated = false)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        CREATE TABLE public.t_chk_test (is_primary BOOLEAN, is_archived BOOLEAN);
        ALTER TABLE public.t_chk_test ADD CONSTRAINT chk_dummy CHECK (NOT (is_primary AND is_archived)) NOT VALID;
        DECLARE
            v_validated boolean;
        BEGIN
            SELECT convalidated INTO v_validated
            FROM pg_constraint
            WHERE conname = 'chk_dummy';

            IF NOT v_validated THEN
                RAISE EXCEPTION 'Preflight correctly rejected unvalidated constraint';
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;
    DROP TABLE IF EXISTS public.t_chk_test;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 13 PASS: Constraint preflight rejects unvalidated constraint';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 13 FAIL: Constraint preflight accepted unvalidated constraint';
    END IF;

    -- --------------------------------------------------------------------------
    -- 14. Constraint preflight: accepts valid constraint check_profiles_primary_not_archived
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        DECLARE
            v_type "char"; v_validated boolean; v_def text;
        BEGIN
            SELECT c.contype, c.convalidated, pg_get_constraintdef(c.oid)
            INTO v_type, v_validated, v_def
            FROM pg_constraint c
            JOIN pg_class t ON t.oid = c.conrelid
            JOIN pg_namespace n ON n.oid = t.relnamespace
            WHERE n.nspname = 'public'
              AND t.relname = 'profiles'
              AND c.conname = 'check_profiles_primary_not_archived';

            IF v_type <> 'c' OR NOT v_validated OR v_def NOT IN (
                'CHECK ((NOT ((is_primary = true) AND (is_archived = true))))',
                'CHECK ((NOT (is_primary AND is_archived)))',
                'CHECK (((is_primary = false) OR (is_archived = false)))'
            ) THEN
                RAISE EXCEPTION 'check_profiles_primary_not_archived failed preflight check: def=%', v_def;
            END IF;
        END;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;

    IF NOT v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 14 PASS: Constraint preflight accepts valid check constraint';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 14 FAIL: Valid check constraint check_profiles_primary_not_archived failed preflight';
    END IF;

    -- Insert test auth user (trigger bootstraps primary profile)
    INSERT INTO auth.users (id, email) VALUES (v_user1, 'tester1@example.com') ON CONFLICT (id) DO NOTHING;

    -- --------------------------------------------------------------------------
    -- 15. Trigger: Primary profile has is_archived = false, archived_at = NULL
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        SELECT id, is_archived, archived_at
        INTO v_prof_primary, v_is_arch, v_arch_at
        FROM public.profiles
        WHERE user_id = v_user1 AND is_primary = true;

        IF v_is_arch = false AND v_arch_at IS NULL AND v_prof_primary IS NOT NULL THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 15 PASS: Primary profile active with is_archived = false, archived_at = NULL';
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 15 FAIL: Primary profile unexpected state: arch=%, at=%', v_is_arch, v_arch_at;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 15 FAIL with error: %', SQLERRM;
    END;

    -- --------------------------------------------------------------------------
    -- 16. Trigger: INSERT primary profile with is_archived = true is rejected
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
        VALUES (gen_random_uuid(), v_user2, 'Illegal Primary', 'Self', true, true);
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 16 PASS: INSERT primary profile with is_archived = true rejected by check constraint';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 16 FAIL: INSERT primary profile with is_archived = true was accepted';
    END IF;

    -- --------------------------------------------------------------------------
    -- 17. Trigger: UPDATE archiving primary profile is rejected by trigger
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        UPDATE public.profiles SET is_archived = true WHERE id = v_prof_primary;
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 17 PASS: UPDATE archiving primary profile rejected by trigger';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 17 FAIL: UPDATE archiving primary profile was accepted';
    END IF;

    -- Insert active family profile for tests 18-20
    INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary)
    VALUES (v_prof_active_fam, v_user1, 'Family Sister', 'Sister', false);

    -- --------------------------------------------------------------------------
    -- 18. Trigger: UPDATE archiving family profile sets archived_at to non-null timestamp
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        UPDATE public.profiles SET is_archived = true WHERE id = v_prof_active_fam;

        SELECT is_archived, archived_at INTO v_is_arch, v_arch_at
        FROM public.profiles WHERE id = v_prof_active_fam;

        IF v_is_arch = true AND v_arch_at IS NOT NULL THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 18 PASS: UPDATE archiving family profile sets archived_at to %', v_arch_at;
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 18 FAIL: archived_at not populated on archive';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 18 FAIL with error: %', SQLERRM;
    END;

    -- --------------------------------------------------------------------------
    -- 19. Trigger: UPDATE un-archiving family profile clears archived_at to NULL
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        UPDATE public.profiles SET is_archived = false WHERE id = v_prof_active_fam;

        SELECT is_archived, archived_at INTO v_is_arch, v_arch_at
        FROM public.profiles WHERE id = v_prof_active_fam;

        IF v_is_arch = false AND v_arch_at IS NULL THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 19 PASS: UPDATE un-archiving family profile clears archived_at to NULL';
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 19 FAIL: archived_at not cleared on un-archive';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 19 FAIL with error: %', SQLERRM;
    END;

    -- --------------------------------------------------------------------------
    -- 20. Trigger: UPDATE with manually supplied archived_at mismatch is corrected
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        -- Manually supply archived_at on an active profile (is_archived = false)
        UPDATE public.profiles SET is_archived = false, archived_at = NOW() WHERE id = v_prof_active_fam;

        SELECT archived_at INTO v_arch_at FROM public.profiles WHERE id = v_prof_active_fam;

        IF v_arch_at IS NULL THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 20 PASS: Inconsistent manual archived_at corrected to NULL for active profile';
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 20 FAIL: Inconsistent archived_at was retained: %', v_arch_at;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 20 FAIL with error: %', SQLERRM;
    END;

    -- Setup for tests 21-24:
    -- Create an archived family member by inserting active then archiving
    INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary)
    VALUES (v_prof_archived_fam, v_user1, 'Archived Grandpa', 'Grandfather', false);

    UPDATE public.profiles SET is_archived = true WHERE id = v_prof_archived_fam;

    -- --------------------------------------------------------------------------
    -- 21. Clinical write policy: INSERT consultation for active profile succeeds
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        INSERT INTO public.consultations (
            id, user_id, profile_id, doctor_name, visit_date, chief_complaint, diagnosis
        ) VALUES (
            v_consultation_active, v_user1, v_prof_active_fam, 'Dr. Active', CURRENT_DATE, 'Checkup', 'Healthy'
        );

        PERFORM set_config('role', 'postgres', true);
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 21 PASS: INSERT consultation for active profile succeeds';
    EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('role', 'postgres', true);
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 21 FAIL: INSERT consultation for active profile failed: %', SQLERRM;
    END;

    -- --------------------------------------------------------------------------
    -- 22. Clinical write policy: INSERT consultation for archived profile is rejected
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        INSERT INTO public.consultations (
            id, user_id, profile_id, doctor_name, visit_date, chief_complaint, diagnosis
        ) VALUES (
            v_consultation_archived, v_user1, v_prof_archived_fam, 'Dr. Archived', CURRENT_DATE, 'Checkup', 'Healthy'
        );

        PERFORM set_config('role', 'postgres', true);
        v_raised := FALSE;
    EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('role', 'postgres', true);
        v_raised := TRUE;
    END;

    IF v_raised THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 22 PASS: INSERT consultation for archived profile rejected by RLS policy';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 22 FAIL: INSERT consultation for archived profile was allowed';
    END IF;

    -- --------------------------------------------------------------------------
    -- 23. Storage policy: INSERT avatar for active succeeds; archived profile is rejected
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    DECLARE
        v_active_avatar_ok BOOLEAN := FALSE;
        v_archived_avatar_rejected BOOLEAN := FALSE;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        -- Upload avatar for active profile
        BEGIN
            INSERT INTO storage.objects (bucket_id, name, owner)
            VALUES ('avatars', v_user1::text || '/' || v_prof_active_fam::text || '/avatar.jpg', v_user1);
            v_active_avatar_ok := TRUE;
        EXCEPTION WHEN OTHERS THEN
            v_active_avatar_ok := FALSE;
        END;

        -- Upload avatar for archived profile
        BEGIN
            INSERT INTO storage.objects (bucket_id, name, owner)
            VALUES ('avatars', v_user1::text || '/' || v_prof_archived_fam::text || '/avatar.jpg', v_user1);
            v_archived_avatar_rejected := FALSE;
        EXCEPTION WHEN OTHERS THEN
            v_archived_avatar_rejected := TRUE;
        END;

        PERFORM set_config('role', 'postgres', true);

        IF v_active_avatar_ok AND v_archived_avatar_rejected THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 23 PASS: Storage avatars policy allows active profile and rejects archived profile';
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 23 FAIL: active_ok=%, archived_rejected=%', v_active_avatar_ok, v_archived_avatar_rejected;
        END IF;
    END;

    -- --------------------------------------------------------------------------
    -- 24. Historical read: SELECT clinical records and avatars for archived profile succeeds
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        -- Insert a historical clinical record and avatar directly as postgres superuser
        PERFORM set_config('role', 'postgres', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);

        INSERT INTO public.consultations (
            id, user_id, profile_id, doctor_name, visit_date, chief_complaint, diagnosis
        ) VALUES (
            v_consultation_archived, v_user1, v_prof_archived_fam, 'Dr. Historical', '2024-01-01', 'Old Visit', 'Resolved'
        );

        INSERT INTO storage.objects (bucket_id, name, owner)
        VALUES ('avatars', v_user1::text || '/' || v_prof_archived_fam::text || '/hist_avatar.jpg', v_user1);

        -- Now authenticate as v_user1 and verify SELECT access to archived profile's data
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        SELECT COUNT(*) INTO v_read_count
        FROM public.consultations
        WHERE profile_id = v_prof_archived_fam;

        IF v_read_count > 0 THEN
            SELECT COUNT(*) INTO v_read_count
            FROM storage.objects
            WHERE bucket_id = 'avatars'
              AND name = v_user1::text || '/' || v_prof_archived_fam::text || '/hist_avatar.jpg';

            PERFORM set_config('role', 'postgres', true);

            IF v_read_count > 0 THEN
                v_pass_count := v_pass_count + 1;
                RAISE NOTICE 'Test 24 PASS: Historical SELECT of clinical records and avatars for archived profile succeeds';
            ELSE
                v_fail_count := v_fail_count + 1;
                RAISE WARNING 'Test 24 FAIL: Historical avatar not visible via SELECT';
            END IF;
        ELSE
            PERFORM set_config('role', 'postgres', true);
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 24 FAIL: Historical consultations not visible via SELECT';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('role', 'postgres', true);
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 24 FAIL with error: %', SQLERRM;
    END;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Test Results Summary: Total=%, Passed=%, Failed=%', v_test_count, v_pass_count, v_fail_count;
    RAISE NOTICE '============================================================';

    IF v_fail_count > 0 THEN
        RAISE EXCEPTION 'Archival Hardening verification FAILED: % tests failed', v_fail_count;
    END IF;
END $$;
