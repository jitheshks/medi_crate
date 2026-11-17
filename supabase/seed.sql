-- ==============================================================================
-- MediCrate - Local Development & Deterministic Reference Seed Data
-- ==============================================================================
-- File: supabase/seed.sql
-- Description:
--   Seeds authoritative reference data for medical departments after migrations
--   during 'supabase db reset' or local database initialization.
--   All seed operations are strictly idempotent with preflight conflict protection.
--
-- AUTHORITATIVE REFERENCE CATALOG:
--   79 production medical departments verified from MediVault live API (MD1).
--   Explicit IDs 1..79 with 'OTHERS' assigned ID 79 and positioned last.
--
-- PREFLIGHT INTEGRITY & CONFLICT POLICY:
--   1. Validates that no existing record with an authoritative ID has a different name.
--   2. Validates that no existing record with an authoritative name has a different ID.
--   3. If any conflict or provisional data mismatch is detected, execution immediately
--      fails with a descriptive exception WITHOUT modifying any records.
--   4. Never renames, deletes, or modifies clinical records (consultations, appointments).
--   5. Calculates display_order dynamically (alphabetical by trimmed uppercase name,
--      with 'OTHERS' pinned last).
--   6. Synchronizes the SERIAL sequence to match max(id).
-- ==============================================================================

DO $$
DECLARE
    v_conflict_id INTEGER;
    v_existing_name TEXT;
    v_expected_name TEXT;
    v_expected_id INTEGER;
BEGIN
    -- 1. Create temporary staging table with the 79 authoritative production departments
    CREATE TEMP TABLE IF NOT EXISTS temp_authoritative_departments (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        is_active BOOLEAN NOT NULL DEFAULT TRUE
    ) ON COMMIT DROP;

    TRUNCATE temp_authoritative_departments;

    INSERT INTO temp_authoritative_departments (id, name, is_active)
    VALUES
        (1, 'ANAESTHESIOLOGY', TRUE),
        (2, 'ASSOCIATE PHYSICIAN', TRUE),
        (3, 'BREAST ONCOPLASTIC SURGERY', TRUE),
        (4, 'CARDIO THORACIC VASCULAR ANESTHESIOLOGY', TRUE),
        (5, 'CARDIO VASCULAR SURGERY', TRUE),
        (6, 'CARDIOLOGY', TRUE),
        (7, 'CARDIOTHORACIC SURGEON', TRUE),
        (8, 'CLINICAL NEURO PSYCHOLOGY', TRUE),
        (9, 'CLINICAL PSYCHOLOGY', TRUE),
        (10, 'CTVC', TRUE),
        (11, 'DENTAL', TRUE),
        (12, 'DENTAL PROSTHODONTIST', TRUE),
        (13, 'DERMATOLOGY', TRUE),
        (14, 'DEVELOPMENTAL MEDICINE', TRUE),
        (15, 'DIABETOLOGY', TRUE),
        (16, 'DIALYSIS', TRUE),
        (17, 'DIETARY', TRUE),
        (18, 'E.N.T', TRUE),
        (19, 'EMERGENCY DEPARTMENT', TRUE),
        (20, 'ENDOCRINOLOGY', TRUE),
        (21, 'ENDOSCOPIC SPINE SURGEON', TRUE),
        (22, 'FAMILY MEDICINE', TRUE),
        (23, 'FORENSIC MEDICINE AND TOXICOLOGY', TRUE),
        (24, 'GASTROENTEROLOGY(MED)', TRUE),
        (25, 'GASTROENTEROLOGY(SURG)', TRUE),
        (26, 'GENERAL SURGERY', TRUE),
        (27, 'GYNAECOLOGICAL ONCOLOGY', TRUE),
        (28, 'HAND & MICROVASCULAR SURGERY', TRUE),
        (29, 'HEMATO ONCOLOGY', TRUE),
        (30, 'HEMATOLOGY', TRUE),
        (31, 'HEPATOLOGY', TRUE),
        (32, 'HPB & LIVER TRANSPLANT SURGEON', TRUE),
        (33, 'INTENSIVE CARE', TRUE),
        (34, 'INTERNAL MEDICINE', TRUE),
        (35, 'LABORATORY', TRUE),
        (36, 'LACTATION', TRUE),
        (37, 'LAPROSCOPIC AND GENERAL SURGEON', TRUE),
        (38, 'MAXILLOFACIAL SURGERY', TRUE),
        (39, 'MHC CONSULTANT', TRUE),
        (40, 'NEONATOLOGY', TRUE),
        (41, 'NEPHROLOGY', TRUE),
        (42, 'NEURO ANAESTHESIA', TRUE),
        (43, 'NEURO RADIOLOGY', TRUE),
        (44, 'NEURO SURGERY', TRUE),
        (45, 'NEUROLOGY', TRUE),
        (46, 'NEUROVASCULAR & INTERVENTIONAL RADIOLOGY', TRUE),
        (47, 'OBSTETRIC & GYNAECOLOGY', TRUE),
        (48, 'ONCOLOGY (MEDICAL)', TRUE),
        (49, 'ONCOLOGY (SURGICAL)', TRUE),
        (50, 'OPHTHALMOLOGY', TRUE),
        (51, 'ORAL & MAXILLO FACIAL SURGERY', TRUE),
        (52, 'ORTHOPAEDICS', TRUE),
        (53, 'ORTHOPAEDICS & SPINE SURGEON', TRUE),
        (54, 'PAEDIATRIC DENTAL', TRUE),
        (55, 'PAEDIATRIC DERMATOLOGY', TRUE),
        (56, 'PAEDIATRIC ENDOCRINOLOGY', TRUE),
        (57, 'PAEDIATRIC HAEMATO-ONCOLOGY', TRUE),
        (58, 'PAEDIATRIC NEPHROLOGY', TRUE),
        (59, 'PAEDIATRIC NEUROLOGY', TRUE),
        (60, 'PAEDIATRIC ORTHOPAEDICS', TRUE),
        (61, 'PAEDIATRIC PSYCHOLOGY', TRUE),
        (62, 'PAEDIATRIC PULMONOLOGY', TRUE),
        (63, 'PAEDIATRIC SURGERY', TRUE),
        (64, 'PAEDIATRICS', TRUE),
        (65, 'PAEDIATRICS N NEONATOLOGY', TRUE),
        (66, 'PAEDIATRICS-CARDIOLOGY', TRUE),
        (67, 'PHYSIOTHERAPY', TRUE),
        (68, 'PLASTIC SURGERY', TRUE),
        (69, 'PSYCHIATRY', TRUE),
        (70, 'PSYCHOLOGY', TRUE),
        (71, 'PULMONOLOGY', TRUE),
        (72, 'RADIOLOGY', TRUE),
        (73, 'RHEUMATOLOGY', TRUE),
        (74, 'SPEECH THERAPY', TRUE),
        (75, 'THORACIC SURGERY', TRUE),
        (76, 'UROLOGY', TRUE),
        (77, 'UROLOGY ANDROLOGY', TRUE),
        (78, 'VASCULAR SURGERY', TRUE),
        (79, 'OTHERS', TRUE);

    -- 2. PREFLIGHT CHECK 1:
    --    Verify that no existing ID has a different department name
    SELECT m.id, m.name, a.name
    INTO v_conflict_id, v_existing_name, v_expected_name
    FROM public.medical_departments m
    JOIN temp_authoritative_departments a ON m.id = a.id
    WHERE m.name <> a.name
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Preflight check failed: medical_departments contains conflicting record for ID % (existing: "%", expected: "%"). Refusing to seed over conflicting catalogue without manual migration.',
            v_conflict_id, v_existing_name, v_expected_name;
    END IF;

    -- 3. PREFLIGHT CHECK 2:
    --    Verify that no authoritative department name exists under a different ID
    SELECT m.id, m.name, a.id
    INTO v_conflict_id, v_existing_name, v_expected_id
    FROM public.medical_departments m
    JOIN temp_authoritative_departments a ON m.name = a.name
    WHERE m.id <> a.id
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Preflight check failed: medical_departments contains conflicting record for department "%" (existing ID: %, expected ID: %). Refusing to seed over conflicting catalogue without manual migration.',
            v_existing_name, v_conflict_id, v_expected_id;
    END IF;

    -- 4. SAFE IDEMPOTENT REFERENCE SEEDING:
    --    Calculate display_order dynamically: alphabetical by uppercase trimmed name, with 'OTHERS' last.
    INSERT INTO public.medical_departments (id, name, display_order, is_active)
    SELECT
        a.id,
        a.name,
        ROW_NUMBER() OVER (
            ORDER BY
                CASE WHEN UPPER(TRIM(a.name)) = 'OTHERS' THEN 1 ELSE 0 END,
                UPPER(TRIM(a.name)) ASC
        ) AS display_order,
        a.is_active
    FROM temp_authoritative_departments a
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        display_order = EXCLUDED.display_order,
        is_active = EXCLUDED.is_active;

    -- 5. SYNCHRONIZE SERIAL SEQUENCE:
    PERFORM setval(
        pg_get_serial_sequence('public.medical_departments', 'id'),
        COALESCE((SELECT MAX(id) FROM public.medical_departments), 1),
        true
    );
END $$;
