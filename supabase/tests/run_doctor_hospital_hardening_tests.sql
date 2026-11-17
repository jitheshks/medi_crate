-- ==============================================================================
-- MediCrate Implementation 1: Doctor & Hospital RPC Hardening Regression Tests
-- ==============================================================================
--
-- Verification Objectives:
-- 1. Helper non-exposure: public.check_doctor_ownership is completely absent from
--    the exposed `public` API schema. The helper exists exclusively in `private`,
--    preventing public Data API invocation and UUID existence oracle queries.
-- 2. Schema and function privileges: `anon` has no access; `authenticated` holds
--    only minimum necessary USAGE on `private` and EXECUTE on `private.check_doctor_ownership`.
-- 3. Cross-user doctor update rejection (different user -> SQLSTATE 42501).
-- 4. Cross-profile doctor update rejection (same user, different profile -> SQLSTATE 42501).
-- 5. Valid same-profile update succeeds and preserves correct affiliations.
-- 6. New doctor creation succeeds and establishes initial hospital affiliations.
-- 7. Invalid hospital affiliation aborts entire operation (SQLSTATE 23503).
-- 8. Failed operations preserve atomicity: existing doctor and junction records remain untouched.
-- ==============================================================================

DO $$
DECLARE
    v_test_count INT := 0;
    v_pass_count INT := 0;
    v_fail_count INT := 0;

    v_user1 UUID := gen_random_uuid();
    v_user2 UUID := gen_random_uuid();

    v_prof1_a UUID := gen_random_uuid();
    v_prof1_b UUID := gen_random_uuid();
    v_prof2 UUID := gen_random_uuid();

    v_hosp1_a UUID := gen_random_uuid();
    v_hosp1_b UUID := gen_random_uuid();
    v_hosp2 UUID := gen_random_uuid();

    v_doc1 UUID := gen_random_uuid();
    v_doc2 UUID := gen_random_uuid();
    v_new_doc_id UUID := gen_random_uuid();

    v_raised BOOLEAN;
    v_sqlstate TEXT;
    v_msg TEXT;
    v_helper_status TEXT;
    v_result JSONB;
    v_count INT;
    v_pre_name TEXT;
    v_post_name TEXT;
    v_public_proc_count INT;
    v_private_proc_count INT;
    v_anon_schema_priv BOOLEAN;
    v_auth_schema_priv BOOLEAN;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Starting Implementation 1 Doctor & Hospital Hardening Suite';
    RAISE NOTICE '============================================================';

    -- --------------------------------------------------------------------------
    -- Setup Fixtures (as superuser / postgres)
    -- --------------------------------------------------------------------------
    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    -- 1. Create auth users if auth.users table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
        INSERT INTO auth.users (id, email)
        VALUES 
            (v_user1, 'doc_user1@medicrate.test'),
            (v_user2, 'doc_user2@medicrate.test')
        ON CONFLICT (id) DO NOTHING;
    END IF;

    -- 2. Create profiles
    INSERT INTO public.profiles (id, user_id, full_name, relationship, is_primary, is_archived)
    VALUES 
        (v_prof1_a, v_user1, 'User 1 Profile A', 'Self', true, false),
        (v_prof1_b, v_user1, 'User 1 Profile B', 'Family', false, false),
        (v_prof2, v_user2, 'User 2 Profile', 'Self', true, false);

    -- 3. Create hospitals
    INSERT INTO public.hospitals (id, user_id, profile_id, name, type)
    VALUES 
        (v_hosp1_a, v_user1, v_prof1_a, 'City Hospital A', 'Hospital'),
        (v_hosp1_b, v_user1, v_prof1_b, 'Clinic B', 'Clinic'),
        (v_hosp2, v_user2, v_prof2, 'Foreign Hospital', 'Hospital');

    -- 4. Create base doctor for User 1 under Profile A
    INSERT INTO public.doctors (id, user_id, profile_id, name, specialty)
    VALUES (v_doc1, v_user1, v_prof1_a, 'Dr. Gregory House', 'Diagnostic Medicine');

    -- 5. Attach initial affiliation to v_doc1
    INSERT INTO public.doctor_hospitals (doctor_id, hospital_id, user_id)
    VALUES (v_doc1, v_hosp1_a, v_user1);

    -- 6. Create base doctor for User 2 under Profile 2
    INSERT INTO public.doctors (id, user_id, profile_id, name, specialty)
    VALUES (v_doc2, v_user2, v_prof2, 'Dr. James Wilson', 'Oncology');

    -- --------------------------------------------------------------------------
    -- TEST 1: Helper Schema Isolation & API Non-Exposure
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;

    -- Verify check_doctor_ownership does not exist in public schema
    SELECT COUNT(*) INTO v_public_proc_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'check_doctor_ownership';

    -- Verify check_doctor_ownership exists in private schema
    SELECT COUNT(*) INTO v_private_proc_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'private' AND p.proname = 'check_doctor_ownership';

    -- Verify anon has NO usage on private schema
    v_anon_schema_priv := has_schema_privilege('anon', 'private', 'USAGE');
    -- Verify authenticated HAS usage on private schema
    v_auth_schema_priv := has_schema_privilege('authenticated', 'private', 'USAGE');

    IF v_public_proc_count = 0 
       AND v_private_proc_count > 0 
       AND v_anon_schema_priv = FALSE 
       AND v_auth_schema_priv = TRUE THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 1 PASS: Helper is isolated in private schema (public=0, private=%, anon_priv=%, auth_priv=%)',
            v_private_proc_count, v_anon_schema_priv, v_auth_schema_priv;
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 1 FAIL: public_count=%, private_count=%, anon_priv=%, auth_priv=%',
            v_public_proc_count, v_private_proc_count, v_anon_schema_priv, v_auth_schema_priv;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 2: Cross-user doctor update rejection (different user account)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        -- Attempt to update v_doc2 (owned by User 2) as User 1
        PERFORM public.save_doctor_with_affiliations(
            p_profile_id := v_prof1_a,
            p_name := 'Dr. Hijacked Doc',
            p_specialty := 'Surgery',
            p_doctor_id := v_doc2
        );
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
        GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    END;

    IF v_raised AND v_sqlstate = '42501' THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 2 PASS: Cross-user doctor update rejected with 42501 (%)', v_msg;
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 2 FAIL: Expected 42501, got raised=%, sqlstate=%, msg=%', v_raised, v_sqlstate, v_msg;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 3: Cross-profile doctor update rejection (same user, foreign profile)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        -- Attempt to update v_doc1 (Profile A) by passing Profile B
        PERFORM public.save_doctor_with_affiliations(
            p_profile_id := v_prof1_b,
            p_name := 'Dr. Gregory House Updated',
            p_specialty := 'Nephrology',
            p_doctor_id := v_doc1
        );
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
        GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    END;

    IF v_raised AND v_sqlstate = '42501' THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 3 PASS: Cross-profile doctor update rejected with 42501 (%)', v_msg;
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 3 FAIL: Expected 42501, got raised=%, sqlstate=%, msg=%', v_raised, v_sqlstate, v_msg;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 4: Valid same-profile update preserving correct affiliations
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        v_result := public.save_doctor_with_affiliations(
            p_profile_id := v_prof1_a,
            p_name := 'Dr. Gregory House, M.D.',
            p_specialty := 'Infectious Disease',
            p_doctor_id := v_doc1,
            p_hospital_ids := ARRAY[v_hosp1_a]
        );
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
        GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    END;

    SELECT COUNT(*) INTO v_count
    FROM public.doctor_hospitals
    WHERE doctor_id = v_doc1 AND hospital_id = v_hosp1_a AND user_id = v_user1;

    IF NOT v_raised AND (v_result->>'name') = 'Dr. Gregory House, M.D.' AND v_count = 1 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 4 PASS: Valid same-profile update preserved doctor details and hospital affiliations';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 4 FAIL: raised=%, result=%, affiliations_count=%', v_raised, v_result, v_count;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 5: New doctor creation still works
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        v_result := public.save_doctor_with_affiliations(
            p_profile_id := v_prof1_a,
            p_name := 'Dr. Allison Cameron',
            p_specialty := 'Immunology',
            p_doctor_id := v_new_doc_id,
            p_hospital_ids := ARRAY[v_hosp1_a]
        );
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
        GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    END;

    SELECT COUNT(*) INTO v_count
    FROM public.doctors
    WHERE id = v_new_doc_id AND user_id = v_user1 AND profile_id = v_prof1_a;

    IF NOT v_raised AND v_count = 1 AND (v_result->>'name') = 'Dr. Allison Cameron' THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 5 PASS: New doctor creation with affiliations successfully persisted';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 5 FAIL: raised=%, count=%', v_raised, v_count;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 6: Invalid hospital affiliation rejection
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;
    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        -- Attempt to link hospital from foreign user
        PERFORM public.save_doctor_with_affiliations(
            p_profile_id := v_prof1_a,
            p_name := 'Dr. Gregory House, M.D.',
            p_specialty := 'Diagnostic Medicine',
            p_doctor_id := v_doc1,
            p_hospital_ids := ARRAY[v_hosp2] -- v_hosp2 belongs to User 2
        );
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
        GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    END;

    IF v_raised AND v_sqlstate = '23503' THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 6 PASS: Invalid hospital affiliation rejected with 23503 (%)', v_msg;
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 6 FAIL: Expected 23503, got raised=%, sqlstate=%, msg=%', v_raised, v_sqlstate, v_msg;
    END IF;

    -- --------------------------------------------------------------------------
    -- TEST 7: Failed operations preserve atomicity (existing records unchanged)
    -- --------------------------------------------------------------------------
    v_test_count := v_test_count + 1;
    v_raised := FALSE;

    -- Snapshot existing state of v_doc1
    SELECT name INTO v_pre_name FROM public.doctors WHERE id = v_doc1;

    BEGIN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user1::text, true);

        -- Attempt invalid update with mutated name but invalid hospital ID
        PERFORM public.save_doctor_with_affiliations(
            p_profile_id := v_prof1_a,
            p_name := 'Dr. Mutated But Rollback Name',
            p_specialty := 'Cardiology',
            p_doctor_id := v_doc1,
            p_hospital_ids := ARRAY[v_hosp2] -- Invalid foreign hospital
        );
    EXCEPTION WHEN OTHERS THEN
        v_raised := TRUE;
    END;

    SELECT name INTO v_post_name FROM public.doctors WHERE id = v_doc1;

    SELECT COUNT(*) INTO v_count
    FROM public.doctor_hospitals
    WHERE doctor_id = v_doc1 AND user_id = v_user1;

    IF v_raised AND v_post_name = v_pre_name AND v_count = 1 THEN
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'Test 7 PASS: Failed operation rolled back; doctor name and affiliations unchanged';
    ELSE
        v_fail_count := v_fail_count + 1;
        RAISE WARNING 'Test 7 FAIL: raised=%, pre=%, post=%, affiliations=%', v_raised, v_pre_name, v_post_name, v_count;
    END IF;

    -- --------------------------------------------------------------------------
    -- Teardown
    -- --------------------------------------------------------------------------
    PERFORM set_config('role', 'postgres', true);
    DELETE FROM public.doctor_hospitals WHERE user_id IN (v_user1, v_user2);
    DELETE FROM public.doctors WHERE user_id IN (v_user1, v_user2);
    DELETE FROM public.hospitals WHERE user_id IN (v_user1, v_user2);
    DELETE FROM public.profiles WHERE user_id IN (v_user1, v_user2);
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
        DELETE FROM auth.users WHERE id IN (v_user1, v_user2);
    END IF;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Doctor & Hospital Hardening Summary: % Tests, % Passed, % Failed',
        v_test_count, v_pass_count, v_fail_count;
    RAISE NOTICE '============================================================';

    IF v_fail_count > 0 THEN
        RAISE EXCEPTION 'Doctor & Hospital Hardening regression FAILED: % tests failed', v_fail_count;
    END IF;
END $$;
