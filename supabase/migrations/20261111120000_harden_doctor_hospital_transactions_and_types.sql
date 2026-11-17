-- ==============================================================================
-- MediCrate Migration: 20261111120000_harden_doctor_hospital_transactions_and_types.sql
-- Module: Doctors & Hospitals (Implementation 1 Review & Hardening)
--
-- Objective:
--   1. Harden facility type constraint on public.hospitals to support all MediVault
--      types (including 'Pharmacy', 'Specialty Center', and 'Other').
--   2. Introduce atomic PostgreSQL RPC `public.save_doctor_with_affiliations`
--      to guarantee ACID transaction safety when creating/updating doctors and
--      their affiliated hospital junctions.
--
-- Mandatory constraints:
--   - Idempotent and safe to run multiple times.
--   - Uses auth.uid() authorization boundary.
--   - Does not affect existing consultations or clinical records.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. UPDATE check_hospitals_type CONSTRAINT
-- ------------------------------------------------------------------------------

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'check_hospitals_type'
          AND conrelid = 'public.hospitals'::regclass
    ) THEN
        ALTER TABLE public.hospitals DROP CONSTRAINT check_hospitals_type;
    END IF;
END $$;

ALTER TABLE public.hospitals
    ADD CONSTRAINT check_hospitals_type CHECK (
        type IS NULL OR LOWER(type) IN (
            'hospital',
            'clinic',
            'lab',
            'diagnostic center',
            'pharmacy',
            'specialty center',
            'other'
        )
    );

-- ------------------------------------------------------------------------------
-- 2. PRIVATE SCHEMA & INTERNAL OWNERSHIP HELPER
-- Encapsulated in non-exposed schema `private` so it cannot be invoked through
-- the public Supabase Data API (PostgREST), preventing UUID-existence oracle attacks.
-- ------------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

DO $$
BEGIN
    DROP FUNCTION IF EXISTS public.check_doctor_ownership(UUID);
    DROP FUNCTION IF EXISTS public.check_doctor_ownership(UUID, UUID);
END $$;

CREATE OR REPLACE FUNCTION private.check_doctor_ownership(
    p_doctor_id UUID,
    p_profile_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_doc_user_id UUID;
    v_doc_profile_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN 'UNAUTHENTICATED';
    END IF;

    SELECT d.user_id, d.profile_id
    INTO v_doc_user_id, v_doc_profile_id
    FROM public.doctors d
    WHERE d.id = p_doctor_id;

    IF NOT FOUND THEN
        RETURN 'NOT_FOUND';
    END IF;

    IF v_doc_user_id != v_user_id THEN
        RETURN 'CROSS_USER';
    END IF;

    IF v_doc_profile_id != p_profile_id THEN
        RETURN 'CROSS_PROFILE';
    END IF;

    RETURN 'OWNED';
END;
$$;

REVOKE ALL ON FUNCTION private.check_doctor_ownership(UUID, UUID) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION private.check_doctor_ownership(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION private.check_doctor_ownership(UUID, UUID) IS
'Internal security helper encapsulated in private schema returning ownership state token without disclosing foreign user or profile IDs or exposing an existence oracle to the public Data API.';

-- ------------------------------------------------------------------------------
-- 3. ATOMIC RPC: public.save_doctor_with_affiliations
-- Creates or updates a clinician directory record and synchronizes their hospital
-- affiliations in a single atomic database transaction.
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.save_doctor_with_affiliations(
    p_profile_id UUID,
    p_name TEXT,
    p_specialty TEXT,
    p_doctor_id UUID DEFAULT NULL,
    p_client_uuid UUID DEFAULT NULL,
    p_hospital_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_is_favorite BOOLEAN DEFAULT FALSE,
    p_hospital_ids UUID[] DEFAULT '{}'::UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_doc_id UUID;
    v_result RECORD;
    v_hosp_id UUID;
    v_sanitized_name TEXT;
    v_sanitized_specialty TEXT;
    v_ownership_status TEXT;
    v_is_update BOOLEAN := FALSE;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Verify profile belongs to authenticated user and is not archived
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_profile_id
          AND user_id = v_user_id
          AND is_archived = FALSE
    ) THEN
        RAISE EXCEPTION 'Active profile % not found for authenticated user.', p_profile_id
            USING ERRCODE = '23503';
    END IF;

    v_sanitized_name := TRIM(COALESCE(p_name, ''));
    v_sanitized_specialty := TRIM(COALESCE(p_specialty, ''));

    IF char_length(v_sanitized_name) < 1 THEN
        RAISE EXCEPTION 'Doctor name cannot be empty.' USING ERRCODE = '23514';
    END IF;
    IF char_length(v_sanitized_specialty) < 1 THEN
        RAISE EXCEPTION 'Doctor specialty cannot be empty.' USING ERRCODE = '23514';
    END IF;

    -- 1. Explicitly validate an existing p_doctor_id against auth.uid() and p_profile_id
    IF p_doctor_id IS NOT NULL THEN
        v_ownership_status := private.check_doctor_ownership(p_doctor_id, p_profile_id);

        IF v_ownership_status IN ('CROSS_USER', 'CROSS_PROFILE') THEN
            RAISE EXCEPTION 'Doctor % does not belong to active user and profile %.', p_doctor_id, p_profile_id
                USING ERRCODE = '42501';
        ELSIF v_ownership_status = 'OWNED' THEN
            v_is_update := TRUE;
        ELSIF v_ownership_status = 'NOT_FOUND' THEN
            v_is_update := FALSE;
        ELSE
            RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 2. Validate every supplied p_hospital_ids entry against user and profile BEFORE modifying any records
    IF p_hospital_ids IS NOT NULL AND array_length(p_hospital_ids, 1) > 0 THEN
        FOREACH v_hosp_id IN ARRAY p_hospital_ids LOOP
            IF v_hosp_id IS NULL THEN
                RAISE EXCEPTION 'Hospital ID in affiliation list cannot be null.'
                    USING ERRCODE = '23502';
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM public.hospitals
                WHERE id = v_hosp_id
                  AND user_id = v_user_id
                  AND profile_id = p_profile_id
            ) THEN
                RAISE EXCEPTION 'Hospital % does not exist or does not belong to active user and profile %.', v_hosp_id, p_profile_id
                    USING ERRCODE = '23503';
            END IF;
        END LOOP;
    END IF;

    -- Upsert doctor row
    IF v_is_update THEN
        v_doc_id := p_doctor_id;
        UPDATE public.doctors
        SET name = v_sanitized_name,
            specialty = v_sanitized_specialty,
            hospital_name = NULLIF(TRIM(p_hospital_name), ''),
            phone = NULLIF(TRIM(p_phone), ''),
            email = NULLIF(TRIM(p_email), ''),
            notes = NULLIF(TRIM(p_notes), ''),
            is_favorite = COALESCE(p_is_favorite, FALSE),
            client_uuid = COALESCE(p_client_uuid, client_uuid),
            updated_at = NOW()
        WHERE id = v_doc_id AND user_id = v_user_id AND profile_id = p_profile_id
        RETURNING * INTO v_result;

        -- Never continue with junction-table modifications if the doctor UPDATE affects zero rows
        IF NOT FOUND OR v_result.id IS NULL THEN
            RAISE EXCEPTION 'Doctor % update affected zero rows or unauthorized for profile %.', v_doc_id, p_profile_id
                USING ERRCODE = '42501';
        END IF;
    ELSE
        v_doc_id := COALESCE(p_doctor_id, gen_random_uuid());
        INSERT INTO public.doctors (
            id, user_id, profile_id, client_uuid,
            name, specialty, hospital_name,
            phone, email, notes, is_favorite
        ) VALUES (
            v_doc_id, v_user_id, p_profile_id, p_client_uuid,
            v_sanitized_name, v_sanitized_specialty, NULLIF(TRIM(p_hospital_name), ''),
            NULLIF(TRIM(p_phone), ''), NULLIF(TRIM(p_email), ''), NULLIF(TRIM(p_notes), ''),
            COALESCE(p_is_favorite, FALSE)
        )
        RETURNING * INTO v_result;

        IF NOT FOUND OR v_result.id IS NULL THEN
            RAISE EXCEPTION 'Failed to create doctor record.'
                USING ERRCODE = '40000';
        END IF;
    END IF;

    -- Ensure junction table synchronization operates strictly on the validated doctor
    v_doc_id := v_result.id;

    -- Synchronize doctor_hospitals junction table in the same transaction
    DELETE FROM public.doctor_hospitals
    WHERE doctor_id = v_doc_id AND user_id = v_user_id;

    IF p_hospital_ids IS NOT NULL AND array_length(p_hospital_ids, 1) > 0 THEN
        FOREACH v_hosp_id IN ARRAY p_hospital_ids LOOP
            INSERT INTO public.doctor_hospitals (doctor_id, hospital_id, user_id)
            VALUES (v_doc_id, v_hosp_id, v_user_id)
            ON CONFLICT (doctor_id, hospital_id) DO NOTHING;
        END LOOP;
    END IF;

    -- Return full JSON representation including persisted hospital affiliations
    RETURN jsonb_build_object(
        'id', v_result.id,
        'user_id', v_result.user_id,
        'profile_id', v_result.profile_id,
        'client_uuid', v_result.client_uuid,
        'name', v_result.name,
        'specialty', v_result.specialty,
        'hospital_name', v_result.hospital_name,
        'phone', v_result.phone,
        'email', v_result.email,
        'notes', v_result.notes,
        'is_favorite', v_result.is_favorite,
        'created_at', v_result.created_at,
        'updated_at', v_result.updated_at,
        'hospital_ids', COALESCE((
            SELECT jsonb_agg(hospital_id)
            FROM public.doctor_hospitals
            WHERE doctor_id = v_doc_id AND user_id = v_user_id
        ), '[]'::jsonb)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. PERMISSIONS
-- ------------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.save_doctor_with_affiliations(
    UUID, TEXT, TEXT, UUID, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, UUID[]
) FROM public, anon, service_role;

GRANT EXECUTE ON FUNCTION public.save_doctor_with_affiliations(
    UUID, TEXT, TEXT, UUID, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, UUID[]
) TO authenticated;
