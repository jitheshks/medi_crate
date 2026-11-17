-- ==============================================================================
-- MediCrate Phase 4.4 Batch 2D: Profile DELETE Policy Hardening Regression Suite
-- ==============================================================================
--
-- Verification Objectives:
-- 1. Verify the legacy policy "Users can delete their own non-primary profiles" is absent.
-- 2. Verify no other permissive DELETE or ALL policy exists for authenticated/anon/public.
-- 3. Verify authenticated users cannot directly delete their own non-primary profiles (SQLSTATE 42501).
-- 4. Verify authenticated users cannot delete their primary Self profile (SQLSTATE 42501).
-- 5. Verify authenticated users cannot delete another user's profile (SQLSTATE 42501).
-- 6. Verify profile archival remains fully permitted for the authorized owner.
-- 7. Verify profile restoration remains fully permitted for the authorized owner.
-- 8. Verify historical SELECT access to clinical records of archived profiles remains intact.
-- 9. Verify clinical INSERT restrictions on archived profiles remain intact (SQLSTATE 42501).
-- 10. Verify clinical UPDATE restrictions on archived profiles remain intact (0 rows, record unchanged).
-- 11. Verify service_role has DELETE privilege and can execute deletion.
-- 12. Verify postgres retains DELETE privilege and client roles (authenticated, anon) have DELETE revoked.
-- ==============================================================================

DO $$
DECLARE
    v_test_count INT := 0;
    v_pass_count INT := 0;
    v_fail_count INT := 0;
    v_skip_count INT := 0;

    v_user1 UUID := gen_random_uuid();
    v_user2 UUID := gen_random_uuid();

    v_prof_primary1 UUID;
    v_prof_family1 UUID := gen_random_uuid();
    v_prof_archived1 UUID := gen_random_uuid();
    v_prof_for_update UUID := gen_random_uuid();

    v_prof_primary2 UUID;
    v_prof_family2 UUID := gen_random_uuid();

    v_consultation_hist UUID := gen_random_uuid();
    v_consultation_blocked UUID := gen_random_uuid();
    v_consultation_to_update UUID := gen_random_uuid();
    v_service_test_prof UUID := gen_random_uuid();
    v_admin_test_prof UUID := gen_random_uuid();

    v_count INT;
    v_raised BOOLEAN;
    v_sqlstate TEXT;
    v_msg TEXT;
    v_is_arch BOOLEAN;
    v_arch_at TIMESTAMPTZ;
    v_rows_affected INT;
    v_complaint TEXT;
    v_diagnosis TEXT;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Starting Batch 2D Profile DELETE Policy Hardening Test Suite';
    RAISE NOTICE '============================================================';

    -- --------------------------------------------------------------------------
    -- Setup Test Fixtures (as superuser / postgres)
    -- --------------------------------------------------------------------------
    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    -- 1. Create valid disposable Supabase Auth user fixtures satisfying public.profiles.user_id FK
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
        INSERT INTO auth.users (id, email, raw_user_meta_data)
        VALUES 
            (v_user1, 'tester_delete_1@example.com', '{"full_name": "Primary User One"}'::jsonb),
            (v_user2, 'tester_delete_2@example.com', '{"full_name": "Primary User Two"}'::jsonb)
        ON CONFLICT (id) DO NOTHING;
    END IF;

    -- 2. Obtain or ensure primary Self profiles (trigger on_auth_user_created bootstraps primary)
    SELECT id INTO v_prof_primary1 FROM public.profiles WHERE user_id = v_user1 AND is_primary = true;
    IF v_prof_primary1 IS NULL THEN
        v_prof_primary1 := gen_random_uuid();
        INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
        VALUES (v_prof_primary1, v_user1, 'Primary User One', 'Self', true, false);
    END IF;

    SELECT id INTO v_prof_primary2 FROM public.profiles WHERE user_id = v_user2 AND is_primary = true;
    IF v_prof_primary2 IS NULL THEN
        v_prof_primary2 := gen_random_uuid();
        INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
        VALUES (v_prof_primary2, v_user2, 'Primary User Two', 'Self', true, false);
    END IF;

    -- 3. User 1 family profiles
    INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
    VALUES (v_prof_family1, v_user1, 'Family Son One', 'Son', false, false);

    INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
    VALUES (v_prof_archived1, v_user1, 'Archived Grandpa', 'Grandfather', false, false);
    UPDATE public.profiles SET is_archived = true WHERE id = v_prof_archived1;

    INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
    VALUES (v_prof_for_update, v_user1, 'Family Sister For Update', 'Sister', false, false);

    -- 4. User 2 family profile
    INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
    VALUES (v_prof_family2, v_user2, 'Family Daughter Two', 'Daughter', false, false);

    -- 5. Historical consultation linked to archived profile of User 1
    INSERT INTO public.consultations (
        id, user_id, profile_id, doctor_name, visit_date, chief_complaint, diagnosis
    ) VALUES (
        v_consultation_hist, v_user1, v_prof_archived1, 'Dr. Historical', CURRENT_DATE - 30, 'Old Cough', 'Resolved'
    );

    -- 6. Clinical consultation created while profile is active (for subsequent UPDATE test)
    INSERT INTO public.consultations (
        id, user_id, profile_id, doctor_name, visit_date, chief_complaint, diagnosis
    ) VALUES (
        v_consultation_to_update, v_user1, v_prof_for_update, 'Dr. Original', CURRENT_DATE - 10, 'Mild Cough', 'Common Cold'
    );

    -- 7. Archive the profile AFTER consultation creation to test UPDATE blocking
    UPDATE public.profiles SET is_archived = true WHERE id = v_prof_for_update;

    -- --------------------------------------------------------------------------
    -- TEST 1: Original authenticated family-profile DELETE policy is absent
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Users can delete their own non-primary profiles';

    IF v_count = 0 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 1 PASS: Legacy policy "Users can delete their own non-primary profiles" is absent';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 1 FAIL: Legacy policy "Users can delete their own non-primary profiles" is still present';
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 2: No other authenticated DELETE policy independently permits deletion
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND cmd IN ('DELETE', 'ALL')
      AND ('authenticated' = ANY(roles) OR 'anon' = ANY(roles) OR 'public' = ANY(roles));

    IF v_count = 0 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 2 PASS: No permissive DELETE or ALL policy exists for client roles on public.profiles';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 2 FAIL: Found % permissive DELETE/ALL policies on public.profiles', v_count;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 3: Authenticated users cannot directly delete their own non-primary profile
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    v_sqlstate := NULL;
    v_msg := NULL;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        DELETE FROM public.profiles WHERE id = v_prof_family1;
    EXCEPTION WHEN insufficient_privilege THEN -- SQLSTATE 42501
        v_raised := TRUE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    WHEN OTHERS THEN
        v_raised := FALSE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    END;

    -- Return to postgres superuser to inspect table state
    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
    SELECT COUNT(*) INTO v_count FROM public.profiles WHERE id = v_prof_family1;

    IF v_raised = TRUE AND v_sqlstate = '42501' AND v_count = 1 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 3 PASS: Authenticated user cannot delete own non-primary profile (SQLSTATE 42501, row preserved)';
    ELSIF v_sqlstate IS NOT NULL AND v_sqlstate <> '42501' THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 3 FAIL: Unexpected error instead of insufficient_privilege (42501): SQLSTATE=%, MSG=%', v_sqlstate, v_msg;
    ELSIF v_count <> 1 THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 3 FAIL: Own non-primary profile was unexpectedly deleted!';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 3 FAIL: DELETE did not raise expected insufficient_privilege (42501)';
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 4: Authenticated users cannot delete primary Self profile
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    v_sqlstate := NULL;
    v_msg := NULL;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        DELETE FROM public.profiles WHERE id = v_prof_primary1;
    EXCEPTION WHEN insufficient_privilege THEN -- SQLSTATE 42501
        v_raised := TRUE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    WHEN OTHERS THEN
        v_raised := FALSE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    END;

    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
    SELECT COUNT(*) INTO v_count FROM public.profiles WHERE id = v_prof_primary1;

    IF v_raised = TRUE AND v_sqlstate = '42501' AND v_count = 1 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 4 PASS: Authenticated user cannot delete primary Self profile (SQLSTATE 42501, row preserved)';
    ELSIF v_sqlstate IS NOT NULL AND v_sqlstate <> '42501' THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 4 FAIL: Unexpected error instead of insufficient_privilege (42501): SQLSTATE=%, MSG=%', v_sqlstate, v_msg;
    ELSIF v_count <> 1 THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 4 FAIL: Primary Self profile was unexpectedly deleted!';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 4 FAIL: DELETE did not raise expected insufficient_privilege (42501)';
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 5: Another user's profile cannot be deleted
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    v_sqlstate := NULL;
    v_msg := NULL;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        DELETE FROM public.profiles WHERE id = v_prof_family2;
    EXCEPTION WHEN insufficient_privilege THEN -- SQLSTATE 42501
        v_raised := TRUE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    WHEN OTHERS THEN
        v_raised := FALSE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    END;

    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
    SELECT COUNT(*) INTO v_count FROM public.profiles WHERE id = v_prof_family2;

    IF v_raised = TRUE AND v_sqlstate = '42501' AND v_count = 1 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 5 PASS: User 1 cannot delete User 2 family profile (SQLSTATE 42501, row preserved)';
    ELSIF v_sqlstate IS NOT NULL AND v_sqlstate <> '42501' THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 5 FAIL: Unexpected error instead of insufficient_privilege (42501): SQLSTATE=%, MSG=%', v_sqlstate, v_msg;
    ELSIF v_count <> 1 THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 5 FAIL: User 2 profile was deleted by User 1!';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 5 FAIL: DELETE did not raise expected insufficient_privilege (42501)';
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 6: Profile archival remains permitted for an authorized owner
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        UPDATE public.profiles
        SET is_archived = true
        WHERE id = v_prof_family1 AND user_id = v_user1;

        PERFORM set_config('role', 'postgres', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
        SELECT is_archived, archived_at INTO v_is_arch, v_arch_at
        FROM public.profiles WHERE id = v_prof_family1;

        IF v_is_arch = true AND v_arch_at IS NOT NULL THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 6 PASS: Profile archival UPDATE succeeds and sets archived_at timestamp';
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 6 FAIL: Profile archival UPDATE failed to set is_archived=true or archived_at';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('role', 'postgres', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 6 FAIL with exception: %', SQLERRM;
    END;

    -- --------------------------------------------------------------------------
    -- TEST 7: Profile restoration remains permitted for an authorized owner
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        UPDATE public.profiles
        SET is_archived = false
        WHERE id = v_prof_family1 AND user_id = v_user1;

        PERFORM set_config('role', 'postgres', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
        SELECT is_archived, archived_at INTO v_is_arch, v_arch_at
        FROM public.profiles WHERE id = v_prof_family1;

        IF v_is_arch = false AND v_arch_at IS NULL THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 7 PASS: Profile restoration UPDATE succeeds and clears archived_at to NULL';
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 7 FAIL: Profile restoration failed to clear is_archived or archived_at';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('role', 'postgres', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 7 FAIL with exception: %', SQLERRM;
    END;

    -- --------------------------------------------------------------------------
    -- TEST 8: Clinical historical SELECT access remains intact
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        SELECT COUNT(*) INTO v_count
        FROM public.consultations
        WHERE profile_id = v_prof_archived1;

        PERFORM set_config('role', 'postgres', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
        IF v_count > 0 THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 8 PASS: Historical SELECT of clinical records for archived profile succeeds (count=%)', v_count;
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 8 FAIL: Historical clinical records of archived profile not visible via SELECT';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('role', 'postgres', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 8 FAIL with exception: %', SQLERRM;
    END;

    -- --------------------------------------------------------------------------
    -- TEST 9: Archived-profile clinical INSERT restriction remains intact
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    v_sqlstate := NULL;
    v_msg := NULL;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        INSERT INTO public.consultations (
            id, user_id, profile_id, doctor_name, visit_date, chief_complaint, diagnosis
        ) VALUES (
            v_consultation_blocked, v_user1, v_prof_archived1, 'Dr. Blocked', CURRENT_DATE, 'New Visit', 'Rejected'
        );
    EXCEPTION WHEN insufficient_privilege THEN -- SQLSTATE 42501 (RLS policy check failure)
        v_raised := TRUE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    WHEN check_violation THEN -- SQLSTATE 23514
        v_raised := TRUE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    WHEN OTHERS THEN
        v_raised := FALSE;
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
    END;

    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
    SELECT COUNT(*) INTO v_count FROM public.consultations WHERE id = v_consultation_blocked;

    IF v_raised = TRUE AND v_sqlstate = '42501' AND v_count = 0 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 9 PASS: Clinical INSERT for archived profile correctly rejected by RLS policy (SQLSTATE 42501, 0 rows inserted)';
    ELSIF v_sqlstate IS NOT NULL AND v_sqlstate <> '42501' THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 9 FAIL: Clinical INSERT failed with unexpected error instead of RLS rejection: SQLSTATE=%, MSG=%', v_sqlstate, v_msg;
    ELSIF v_count > 0 THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 9 FAIL: Clinical INSERT for archived profile was unexpectedly permitted into consultations table!';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 9 FAIL: Clinical INSERT did not raise expected RLS insufficient_privilege (42501)';
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 10: Archived-profile clinical UPDATE restriction remains intact
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_rows_affected := 0;
    v_sqlstate := '00000';
    v_msg := NULL;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        -- Attempt to update existing clinical record belonging to the now-archived family profile
        UPDATE public.consultations
        SET chief_complaint = 'Severe Cough - Tampered Update',
            diagnosis = 'Pneumonia'
        WHERE id = v_consultation_to_update;
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    EXCEPTION WHEN OTHERS THEN
        v_sqlstate := SQLSTATE;
        v_msg := SQLERRM;
        v_rows_affected := -1;
    END;

    -- Return to postgres superuser to inspect actual row data in database
    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    SELECT chief_complaint, diagnosis
    INTO v_complaint, v_diagnosis
    FROM public.consultations
    WHERE id = v_consultation_to_update;

    IF v_sqlstate = '00000'
       AND v_rows_affected = 0
       AND v_complaint = 'Mild Cough'
       AND v_diagnosis = 'Common Cold' THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 10 PASS: Clinical UPDATE for archived profile correctly filtered by RLS USING clause (0 rows affected, record preserved)';
    ELSIF v_sqlstate <> '00000' THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 10 FAIL: Clinical UPDATE failed with unexpected SQL error instead of clean zero-row RLS filtering: SQLSTATE=%, MSG=%', v_sqlstate, v_msg;
    ELSIF v_rows_affected > 0 THEN
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 10 FAIL: Clinical UPDATE for archived profile updated % rows! complaint=%, diagnosis=%',
            v_rows_affected, v_complaint, v_diagnosis;
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 10 FAIL: Consultation data modified: complaint=%, diagnosis=%', v_complaint, v_diagnosis;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 11: Privileged service_role DELETE execution
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    DECLARE
        v_service_role_exists BOOLEAN := FALSE;
        v_service_priv BOOLEAN := FALSE;
        v_service_del_ok BOOLEAN := FALSE;
    BEGIN
        SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role')
        INTO v_service_role_exists;

        IF NOT v_service_role_exists THEN
            -- In vanilla Postgres environments lacking Supabase roles, document environment state
            -- Do NOT count as passed; increment v_skip_count separately
            v_skip_count := v_skip_count + 1;
            RAISE NOTICE 'Test 11 SKIPPED: Role service_role does not exist in this database cluster (vanilla Postgres environment)';
        ELSE
            -- 1. Verify service_role has DELETE privilege
            v_service_priv := has_table_privilege('service_role', 'public.profiles', 'DELETE');

            -- 2. Create target profile as superuser
            INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary)
            VALUES (v_service_test_prof, v_user1, 'Service Role Erasure Test', 'Other', false);

            -- 3. Safely assume service_role
            BEGIN
                PERFORM set_config('role', 'service_role', true);
                PERFORM set_config('request.jwt.claim.sub', '', true);

                DELETE FROM public.profiles WHERE id = v_service_test_prof;
            EXCEPTION WHEN OTHERS THEN
                v_msg := SQLERRM;
            END;

            -- 4. Return to superuser to verify deletion
            PERFORM set_config('role', 'postgres', true);
            PERFORM set_config('request.jwt.claim.sub', '', true);
            SELECT COUNT(*) INTO v_count FROM public.profiles WHERE id = v_service_test_prof;
            v_service_del_ok := (v_count = 0);

            IF v_service_priv = TRUE AND v_service_del_ok = TRUE THEN
                v_pass_count := v_pass_count + 1;
                RAISE NOTICE 'Test 11 PASS: service_role has DELETE privilege and successfully deleted target profile row';
            ELSE
                v_fail_count := v_fail_count + 1;
                RAISE WARNING 'Test 11 FAIL: service_role DELETE execution failed: privilege=%, deleted=%',
                    v_service_priv, v_service_del_ok;
            END IF;
        END IF;
    END;

    -- --------------------------------------------------------------------------
    -- TEST 12: Superuser postgres deletion & client table privilege denial
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    DECLARE
        v_postgres_priv BOOLEAN := FALSE;
        v_auth_priv BOOLEAN := FALSE;
        v_anon_priv BOOLEAN := FALSE;
        v_postgres_del_ok BOOLEAN := FALSE;
    BEGIN
        v_postgres_priv := has_table_privilege('postgres', 'public.profiles', 'DELETE');
        v_auth_priv := has_table_privilege('authenticated', 'public.profiles', 'DELETE');
        v_anon_priv := has_table_privilege('anon', 'public.profiles', 'DELETE');

        -- Create a temporary profile and delete it via superuser postgres
        INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary)
        VALUES (v_admin_test_prof, v_user1, 'Superuser Erasure Test', 'Other', false);

        DELETE FROM public.profiles WHERE id = v_admin_test_prof;
        SELECT COUNT(*) INTO v_count FROM public.profiles WHERE id = v_admin_test_prof;
        v_postgres_del_ok := (v_count = 0);

        IF v_postgres_priv = TRUE AND v_auth_priv = FALSE AND v_anon_priv = FALSE
           AND v_postgres_del_ok = TRUE THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'Test 12 PASS: postgres has DELETE privilege and client roles (authenticated, anon) have DELETE privilege revoked';
        ELSE
            v_fail_count := v_fail_count + 1;
            RAISE WARNING 'Test 12 FAIL: postgres=%, auth=%, anon=%, postgres_del=%',
                v_postgres_priv, v_auth_priv, v_anon_priv, v_postgres_del_ok;
        END IF;
    END;

    -- --------------------------------------------------------------------------
    -- Teardown Test Fixtures
    -- --------------------------------------------------------------------------
    DELETE FROM public.consultations WHERE user_id IN (v_user1, v_user2);
    DELETE FROM public.profiles WHERE user_id IN (v_user1, v_user2);

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
        DELETE FROM auth.users WHERE id IN (v_user1, v_user2);
    END IF;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Batch 2D Test Results Summary: Total=%, Passed=%, Failed=%, Skipped=%', 
        v_test_count, v_pass_count, v_fail_count, v_skip_count;
    RAISE NOTICE '============================================================';

    IF v_fail_count > 0 THEN
        RAISE EXCEPTION 'Profile DELETE Policy Hardening regression FAILED: % tests failed (% passed, % skipped)', 
            v_fail_count, v_pass_count, v_skip_count;
    END IF;
END $$;
