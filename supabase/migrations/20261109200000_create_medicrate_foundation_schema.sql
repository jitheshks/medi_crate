-- ==============================================================================
-- MediCrate Foundation Schema Migration
-- Migration ID: 20261109200000_create_medicrate_foundation_schema.sql
-- Description: Creates the 13 approved core relational tables, composite foreign
--              keys for tenant isolation, indexes, constraints, updated_at triggers,
--              primary profile protection triggers, primary profile bootstrap trigger,
--              and Row Level Security (RLS) policies.
-- PostgreSQL Version: 17+ (Supabase)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. UTILITIES & FUNCTIONS
-- ------------------------------------------------------------------------------

-- Generic timestamp updater function with hardened search path
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ------------------------------------------------------------------------------
-- 1. TABLE: public.profiles
-- Two-tier multi-profile clinical record root owned by auth.users(id).
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    client_uuid UUID,
    full_name TEXT NOT NULL,
    relationship TEXT NOT NULL DEFAULT 'Self',
    relationship_other TEXT,
    gender TEXT,
    date_of_birth DATE,
    blood_group TEXT,
    height_cm NUMERIC(5,2),
    weight_kg NUMERIC(5,2),
    allergies TEXT[] NOT NULL DEFAULT '{}',
    allergies_confirmed_none BOOLEAN NOT NULL DEFAULT FALSE,
    chronic_conditions TEXT[] NOT NULL DEFAULT '{}',
    chronic_conditions_confirmed_none BOOLEAN NOT NULL DEFAULT FALSE,
    photo_url TEXT,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_profiles_full_name_length CHECK (char_length(TRIM(full_name)) >= 1),
    CONSTRAINT check_profiles_relationship CHECK (
        relationship IN (
            'Self', 'Father', 'Mother', 'Spouse', 'Son', 'Daughter',
            'Brother', 'Sister', 'Grandfather', 'Grandmother', 'Guardian', 'Other'
        )
    ),
    CONSTRAINT check_profiles_gender CHECK (
        gender IS NULL OR gender IN ('Male', 'Female', 'Other', 'Others', 'Prefer not to say')
    ),
    CONSTRAINT check_profiles_blood_group CHECK (
        blood_group IS NULL OR blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
    ),
    CONSTRAINT check_profiles_height_cm CHECK (
        height_cm IS NULL OR (height_cm >= 10.0 AND height_cm <= 300.0)
    ),
    CONSTRAINT check_profiles_weight_kg CHECK (
        weight_kg IS NULL OR (weight_kg >= 1.0 AND weight_kg <= 500.0)
    ),

    -- Composite uniqueness for multi-tenant child FKs
    CONSTRAINT uq_profiles_id_user_id UNIQUE (id, user_id)
);

-- Profiles indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_user_primary 
    ON public.profiles(user_id) WHERE is_primary = TRUE;
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_client_uuid 
    ON public.profiles(user_id, client_uuid) WHERE client_uuid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_user_id 
    ON public.profiles(user_id);

CREATE OR REPLACE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Primary Profile Invariant Protection Functions & Triggers
-- 1. Disallow changing is_primary or re-assigning user_id on existing profile rows
CREATE OR REPLACE FUNCTION public.protect_profile_primary_invariant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF OLD.is_primary IS DISTINCT FROM NEW.is_primary THEN
        RAISE EXCEPTION 'Modifying is_primary on a profile is forbidden. Primary profile invariant cannot be altered.';
    END IF;

    IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
        RAISE EXCEPTION 'Modifying user_id on a profile is forbidden.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_protect_profile_primary_invariant
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_primary_invariant();

-- 2. Disallow deleting the primary profile in client/authenticated context
CREATE OR REPLACE FUNCTION public.protect_profile_primary_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF OLD.is_primary = TRUE AND auth.uid() IS NOT NULL THEN
        RAISE EXCEPTION 'Primary profile cannot be deleted.';
    END IF;
    RETURN OLD;
END;
$$;

CREATE OR REPLACE TRIGGER trg_protect_profile_primary_deletion
    BEFORE DELETE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_primary_deletion();

-- ------------------------------------------------------------------------------
-- 2. TABLE: public.medical_departments
-- System reference catalog for medical specialties and hospital departments.
-- Read-only for authenticated users. Seed data is maintained in supabase/seed.sql.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.medical_departments (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_medical_departments_name CHECK (char_length(TRIM(name)) >= 1)
);

CREATE INDEX IF NOT EXISTS idx_medical_departments_display_order 
    ON public.medical_departments(display_order, name);

-- ------------------------------------------------------------------------------
-- 3. TABLE: public.hospitals
-- Healthcare facilities, diagnostic clinics, and labs saved under a profile.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.hospitals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    client_uuid UUID,
    name TEXT NOT NULL,
    type TEXT DEFAULT 'Hospital',
    address TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_hospitals_name_length CHECK (char_length(TRIM(name)) >= 1),
    CONSTRAINT check_hospitals_type CHECK (
        type IS NULL OR LOWER(type) IN ('hospital', 'clinic', 'lab', 'diagnostic center', 'other')
    ),
    -- Composite tenant isolation FK
    CONSTRAINT fk_hospitals_profile FOREIGN KEY (profile_id, user_id)
        REFERENCES public.profiles(id, user_id) ON DELETE CASCADE,
    -- Composite uniqueness for referencing clinical tables
    CONSTRAINT uq_hospitals_id_user_id UNIQUE (id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_hospitals_profile_id ON public.hospitals(profile_id);
CREATE INDEX IF NOT EXISTS idx_hospitals_user_id ON public.hospitals(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_hospitals_client_uuid ON public.hospitals(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_hospitals_updated_at
    BEFORE UPDATE ON public.hospitals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 4. TABLE: public.doctors
-- Personal directory of clinicians and attending specialists.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.doctors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    client_uuid UUID,
    name TEXT NOT NULL,
    specialty TEXT NOT NULL,
    hospital_name TEXT,
    phone TEXT,
    email TEXT,
    notes TEXT,
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_doctors_name_length CHECK (char_length(TRIM(name)) >= 1),
    CONSTRAINT check_doctors_specialty_length CHECK (char_length(TRIM(specialty)) >= 1),
    -- Composite tenant isolation FK
    CONSTRAINT fk_doctors_profile FOREIGN KEY (profile_id, user_id)
        REFERENCES public.profiles(id, user_id) ON DELETE CASCADE,
    -- Composite uniqueness for referencing clinical tables
    CONSTRAINT uq_doctors_id_user_id UNIQUE (id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_doctors_profile_id ON public.doctors(profile_id);
CREATE INDEX IF NOT EXISTS idx_doctors_user_id ON public.doctors(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_doctors_client_uuid ON public.doctors(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_doctors_updated_at
    BEFORE UPDATE ON public.doctors
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 5. TABLE: public.doctor_hospitals
-- Junction table for clinician-to-hospital affiliations.
-- Enforces that both doctor and hospital belong to the exact same user_id.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.doctor_hospitals (
    doctor_id UUID NOT NULL,
    hospital_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (doctor_id, hospital_id),

    -- Composite FKs guarantee both doctor and hospital belong to the same user
    CONSTRAINT fk_doctor_hospitals_doctor FOREIGN KEY (doctor_id, user_id)
        REFERENCES public.doctors(id, user_id) ON DELETE CASCADE,
    CONSTRAINT fk_doctor_hospitals_hospital FOREIGN KEY (hospital_id, user_id)
        REFERENCES public.hospitals(id, user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_doctor_hospitals_hospital_id ON public.doctor_hospitals(hospital_id);
CREATE INDEX IF NOT EXISTS idx_doctor_hospitals_user_id ON public.doctor_hospitals(user_id);

-- ------------------------------------------------------------------------------
-- 6. TABLE: public.consultations
-- Primary consultation encounters with immutable historical clinical snapshots.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.consultations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    doctor_id UUID,
    doctor_name TEXT NOT NULL,
    doctor_specialty TEXT,
    hospital_id UUID,
    hospital_name TEXT,
    department_id INTEGER REFERENCES public.medical_departments(id) ON DELETE SET NULL,
    department TEXT,
    visit_date DATE NOT NULL,
    visit_time TEXT,
    chief_complaint TEXT NOT NULL,
    diagnosis TEXT NOT NULL,
    clinical_notes TEXT,
    is_follow_up_required BOOLEAN NOT NULL DEFAULT FALSE,
    follow_up_date DATE,
    follow_up_time TEXT,
    follow_up_reminder BOOLEAN NOT NULL DEFAULT FALSE,
    follow_up_notes TEXT,
    is_follow_up_done BOOLEAN NOT NULL DEFAULT FALSE,
    follow_up_status TEXT DEFAULT 'pending',
    tags TEXT[] DEFAULT '{}',
    consultation_fee NUMERIC(10,2),
    currency TEXT NOT NULL DEFAULT 'INR',
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_consultations_doctor_name CHECK (char_length(TRIM(doctor_name)) >= 1),
    CONSTRAINT check_consultations_chief_complaint CHECK (char_length(TRIM(chief_complaint)) >= 1),
    CONSTRAINT check_consultations_diagnosis CHECK (char_length(TRIM(diagnosis)) >= 1),
    CONSTRAINT check_consultations_follow_up_status CHECK (
        follow_up_status IS NULL OR LOWER(follow_up_status) IN ('pending', 'completed', 'missed', 'overdue', 'cancelled')
    ),
    CONSTRAINT check_consultations_fee CHECK (
        consultation_fee IS NULL OR consultation_fee >= 0
    ),
    -- Composite tenant isolation FK
    CONSTRAINT fk_consultations_profile FOREIGN KEY (profile_id, user_id)
        REFERENCES public.profiles(id, user_id) ON DELETE CASCADE,
    -- Composite tenant-safe doctor and hospital relationships
    CONSTRAINT fk_consultations_doctor FOREIGN KEY (doctor_id, user_id)
        REFERENCES public.doctors(id, user_id) ON DELETE SET NULL (doctor_id),
    CONSTRAINT fk_consultations_hospital FOREIGN KEY (hospital_id, user_id)
        REFERENCES public.hospitals(id, user_id) ON DELETE SET NULL (hospital_id),
    -- Composite uniqueness for child attachments and prescriptions/reports
    CONSTRAINT uq_consultations_id_user_id UNIQUE (id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_consultations_profile_date ON public.consultations(profile_id, visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_consultations_user_id ON public.consultations(user_id);
CREATE INDEX IF NOT EXISTS idx_consultations_doctor_id ON public.consultations(doctor_id);
CREATE INDEX IF NOT EXISTS idx_consultations_hospital_id ON public.consultations(hospital_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_consultations_client_uuid ON public.consultations(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_consultations_updated_at
    BEFORE UPDATE ON public.consultations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 7. TABLE: public.consultation_attachments
-- Relational metadata and storage paths for consultation attachments (Endpoint C6).
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.consultation_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consultation_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_type TEXT,
    size_bytes INTEGER,
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_consultation_attachments_name CHECK (char_length(TRIM(name)) >= 1),
    CONSTRAINT check_consultation_attachments_file_path CHECK (char_length(TRIM(file_path)) >= 1),
    CONSTRAINT check_consultation_attachments_size CHECK (
        size_bytes IS NULL OR (size_bytes >= 0 AND size_bytes <= 26214400)
    ),
    -- Composite FK tied to parent consultation and user
    CONSTRAINT fk_consultation_attachments_parent FOREIGN KEY (consultation_id, user_id)
        REFERENCES public.consultations(id, user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_consultation_attachments_consultation_id ON public.consultation_attachments(consultation_id);
CREATE INDEX IF NOT EXISTS idx_consultation_attachments_user_id ON public.consultation_attachments(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_consultation_attachments_client_uuid ON public.consultation_attachments(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 8. TABLE: public.appointments
-- Clinical appointment scheduling and follow-up tracking (Endpoints AP1–AP4).
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    title TEXT NOT NULL,
    doctor_id UUID,
    doctor_name TEXT NOT NULL,
    doctor_specialty TEXT,
    hospital_id UUID,
    hospital_name TEXT,
    department_id INTEGER REFERENCES public.medical_departments(id) ON DELETE SET NULL,
    department TEXT,
    appointment_date TIMESTAMPTZ NOT NULL,
    reminder_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    cost NUMERIC(10,2),
    currency TEXT NOT NULL DEFAULT 'INR',
    status TEXT NOT NULL DEFAULT 'upcoming',
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_appointments_title CHECK (char_length(TRIM(title)) >= 1),
    CONSTRAINT check_appointments_doctor_name CHECK (char_length(TRIM(doctor_name)) >= 1),
    CONSTRAINT check_appointments_status CHECK (
        LOWER(status) IN ('upcoming', 'scheduled', 'confirmed', 'completed', 'cancelled', 'missed', 'rescheduled')
    ),
    CONSTRAINT check_appointments_cost CHECK (
        cost IS NULL OR cost >= 0
    ),
    -- Composite tenant isolation FK
    CONSTRAINT fk_appointments_profile FOREIGN KEY (profile_id, user_id)
        REFERENCES public.profiles(id, user_id) ON DELETE CASCADE,
    -- Composite tenant-safe doctor and hospital relationships
    CONSTRAINT fk_appointments_doctor FOREIGN KEY (doctor_id, user_id)
        REFERENCES public.doctors(id, user_id) ON DELETE SET NULL (doctor_id),
    CONSTRAINT fk_appointments_hospital FOREIGN KEY (hospital_id, user_id)
        REFERENCES public.hospitals(id, user_id) ON DELETE SET NULL (hospital_id)
);

CREATE INDEX IF NOT EXISTS idx_appointments_profile_status_date ON public.appointments(profile_id, status, appointment_date DESC);
CREATE INDEX IF NOT EXISTS idx_appointments_user_id ON public.appointments(user_id);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_id ON public.appointments(doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_hospital_id ON public.appointments(hospital_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_appointments_client_uuid ON public.appointments(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_appointments_updated_at
    BEFORE UPDATE ON public.appointments
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 9. TABLE: public.prescriptions
-- Medication therapies, forms, dosages, and schedules.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.prescriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    consultation_id UUID,
    consultation_title TEXT,
    medicine_name TEXT NOT NULL,
    dosage TEXT NOT NULL,
    form TEXT,
    frequency TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    reminder BOOLEAN NOT NULL DEFAULT FALSE,
    reminder_times TEXT[] DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    instructions TEXT,
    notes TEXT,
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_prescriptions_medicine_name CHECK (char_length(TRIM(medicine_name)) >= 1),
    CONSTRAINT check_prescriptions_dosage CHECK (char_length(TRIM(dosage)) >= 1),
    CONSTRAINT check_prescriptions_form CHECK (
        form IS NULL OR form IN ('Tablet', 'Capsule', 'Syrup', 'Inhaler', 'Injection', 'Cream', 'Drops', 'Other')
    ),
    CONSTRAINT check_prescriptions_frequency CHECK (
        frequency IS NULL OR char_length(TRIM(frequency)) >= 1
    ),
    CONSTRAINT check_prescriptions_date_order CHECK (
        end_date IS NULL OR end_date >= start_date
    ),
    -- Composite tenant isolation FK
    CONSTRAINT fk_prescriptions_profile FOREIGN KEY (profile_id, user_id)
        REFERENCES public.profiles(id, user_id) ON DELETE CASCADE,
    -- Composite tenant-safe consultation relationship
    CONSTRAINT fk_prescriptions_consultation FOREIGN KEY (consultation_id, user_id)
        REFERENCES public.consultations(id, user_id) ON DELETE SET NULL (consultation_id)
);

CREATE INDEX IF NOT EXISTS idx_prescriptions_profile_active ON public.prescriptions(profile_id, is_active);
CREATE INDEX IF NOT EXISTS idx_prescriptions_user_id ON public.prescriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_consultation ON public.prescriptions(consultation_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_prescriptions_client_uuid ON public.prescriptions(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_prescriptions_updated_at
    BEFORE UPDATE ON public.prescriptions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 10. TABLE: public.reports
-- Diagnostic investigations, lab results, radiology, and certificates.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    consultation_id UUID,
    consultation_title TEXT,
    doctor_id UUID,
    doctor_name TEXT,
    hospital_id UUID,
    hospital_name TEXT,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    report_date DATE NOT NULL,
    notes TEXT,
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_reports_title CHECK (char_length(TRIM(title)) >= 1),
    CONSTRAINT check_reports_category CHECK (
        UPPER(category) IN ('LAB TEST', 'IMAGING', 'PRESCRIPTION', 'DISCHARGE', 'CERTIFICATE', 'VACCINATION', 'REFERRAL', 'OTHER', 'OTHERS')
    ),
    -- Composite tenant isolation FK
    CONSTRAINT fk_reports_profile FOREIGN KEY (profile_id, user_id)
        REFERENCES public.profiles(id, user_id) ON DELETE CASCADE,
    -- Composite tenant-safe consultation, doctor, and hospital relationships
    CONSTRAINT fk_reports_consultation FOREIGN KEY (consultation_id, user_id)
        REFERENCES public.consultations(id, user_id) ON DELETE SET NULL (consultation_id),
    CONSTRAINT fk_reports_doctor FOREIGN KEY (doctor_id, user_id)
        REFERENCES public.doctors(id, user_id) ON DELETE SET NULL (doctor_id),
    CONSTRAINT fk_reports_hospital FOREIGN KEY (hospital_id, user_id)
        REFERENCES public.hospitals(id, user_id) ON DELETE SET NULL (hospital_id),
    -- Composite uniqueness for child attachments and expenses
    CONSTRAINT uq_reports_id_user_id UNIQUE (id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reports_profile_category_date ON public.reports(profile_id, category, report_date DESC);
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON public.reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_consultation_id ON public.reports(consultation_id);
CREATE INDEX IF NOT EXISTS idx_reports_doctor_id ON public.reports(doctor_id);
CREATE INDEX IF NOT EXISTS idx_reports_hospital_id ON public.reports(hospital_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_client_uuid ON public.reports(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_reports_updated_at
    BEFORE UPDATE ON public.reports
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 11. TABLE: public.report_attachments
-- Relational metadata and storage paths for diagnostic files (Endpoint R6).
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.report_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_type TEXT,
    size_bytes INTEGER,
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_report_attachments_name CHECK (char_length(TRIM(name)) >= 1),
    CONSTRAINT check_report_attachments_file_path CHECK (char_length(TRIM(file_path)) >= 1),
    CONSTRAINT check_report_attachments_size CHECK (
        size_bytes IS NULL OR (size_bytes >= 0 AND size_bytes <= 26214400)
    ),
    -- Composite FK tied to parent report and user
    CONSTRAINT fk_report_attachments_parent FOREIGN KEY (report_id, user_id)
        REFERENCES public.reports(id, user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_report_attachments_report_id ON public.report_attachments(report_id);
CREATE INDEX IF NOT EXISTS idx_report_attachments_user_id ON public.report_attachments(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_attachments_client_uuid ON public.report_attachments(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 12. TABLE: public.report_expenses
-- Embedded financial expenditure tied 1:1 to a diagnostic investigation.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.report_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR',
    status TEXT NOT NULL DEFAULT 'PAID',
    description TEXT,
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT check_report_expenses_amount CHECK (amount >= 0),
    CONSTRAINT check_report_expenses_status CHECK (
        UPPER(status) IN ('PAID', 'PENDING', 'INSURANCE', 'REIMBURSED')
    ),
    -- Composite FK
    CONSTRAINT fk_report_expenses_parent FOREIGN KEY (report_id, user_id)
        REFERENCES public.reports(id, user_id) ON DELETE CASCADE,
    -- Enforce 1:1 constraint per report
    CONSTRAINT uq_report_expenses_report_id UNIQUE (report_id)
);

CREATE INDEX IF NOT EXISTS idx_report_expenses_user_id ON public.report_expenses(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_expenses_client_uuid ON public.report_expenses(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_report_expenses_updated_at
    BEFORE UPDATE ON public.report_expenses
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 13. TABLE: public.measurements
-- Polymorphic vital signs engine (V0–V5).
-- Invariant: BMI primary_value is calculated by client and committed as an
-- immutable snapshot; no PostgreSQL recalculation trigger is permitted.
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.measurements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL,
    type TEXT NOT NULL,
    title TEXT,
    value TEXT,
    primary_value NUMERIC(8,2) NOT NULL,
    secondary_value NUMERIC(8,2),
    unit TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'normal',
    source TEXT NOT NULL DEFAULT 'Manual',
    glucose_context TEXT,
    notes TEXT,
    recorded_at TIMESTAMPTZ NOT NULL,
    client_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Whitelist validation supporting both canonical formats ('blood_pressure' / 'bp')
    CONSTRAINT check_measurements_type CHECK (
        LOWER(type) IN (
            'blood_pressure', 'bp',
            'blood_glucose', 'glucose',
            'heart_rate',
            'spo2',
            'temperature',
            'respiratory_rate',
            'bmi'
        )
    ),
    CONSTRAINT check_measurements_bp_secondary CHECK (
        LOWER(type) NOT IN ('blood_pressure', 'bp') OR secondary_value IS NOT NULL
    ),
    CONSTRAINT check_measurements_glucose_context CHECK (
        glucose_context IS NULL OR LOWER(glucose_context) IN (
            'fasting', 'random', 'post_prandial', 'postprandial', 'before_meal', 'after_meal'
        )
    ),
    -- Composite tenant isolation FK
    CONSTRAINT fk_measurements_profile FOREIGN KEY (profile_id, user_id)
        REFERENCES public.profiles(id, user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_measurements_profile_type_date ON public.measurements(profile_id, type, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_measurements_user_id ON public.measurements(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_measurements_client_uuid ON public.measurements(user_id, client_uuid) WHERE client_uuid IS NOT NULL;

CREATE OR REPLACE TRIGGER trg_measurements_updated_at
    BEFORE UPDATE ON public.measurements
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 14. AUTH HOOK: PRIMARY PROFILE BOOTSTRAP
-- Automatically and idempotently provisions the initial 'Self' primary profile
-- upon auth.users account creation. Hardened search path and explicit error handling.
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_full_name TEXT;
BEGIN
    -- Idempotency check: exit safely if a primary profile already exists
    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE user_id = NEW.id AND is_primary = TRUE
    ) THEN
        RETURN NEW;
    END IF;

    -- Extract name from metadata or fallback gracefully to email user or 'Self'
    v_full_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
        NULLIF(TRIM(SPLIT_PART(NEW.email, '@', 1)), ''),
        'Self'
    );

    -- Insert primary profile; failures will explicitly abort transaction
    INSERT INTO public.profiles (
        user_id,
        full_name,
        relationship,
        is_primary
    ) VALUES (
        NEW.id,
        v_full_name,
        'Self',
        TRUE
    )
    ON CONFLICT (user_id) WHERE is_primary = TRUE DO NOTHING;

    RETURN NEW;
END;
$$;

-- Restrict execution privileges on auth trigger function
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role, supabase_auth_admin;

-- Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------------------------
-- 15. ROW LEVEL SECURITY (RLS) POLICIES
-- Strict multi-tenant isolation enforcing auth.uid() = user_id on all clinical tables.
-- ------------------------------------------------------------------------------

-- Enable RLS on all 13 tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_hospitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.measurements ENABLE ROW LEVEL SECURITY;

-- 1. Profiles RLS
CREATE POLICY "Users can view their own profiles"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own profiles"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profiles"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own non-primary profiles"
    ON public.profiles FOR DELETE
    TO authenticated
    USING (
        auth.uid() = user_id 
        AND is_primary = FALSE
    );

-- 2. Medical Departments (Read-only catalog for authenticated users)
CREATE POLICY "Authenticated users can view active medical departments"
    ON public.medical_departments FOR SELECT
    TO authenticated
    USING (is_active = TRUE);

-- 3. Hospitals RLS
CREATE POLICY "Users can view their own hospitals"
    ON public.hospitals FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own hospitals"
    ON public.hospitals FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own hospitals"
    ON public.hospitals FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own hospitals"
    ON public.hospitals FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 4. Doctors RLS
CREATE POLICY "Users can view their own doctors"
    ON public.doctors FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own doctors"
    ON public.doctors FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own doctors"
    ON public.doctors FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own doctors"
    ON public.doctors FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 5. Doctor Hospitals Junction RLS
CREATE POLICY "Users can view their doctor hospital affiliations"
    ON public.doctor_hospitals FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their doctor hospital affiliations"
    ON public.doctor_hospitals FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their doctor hospital affiliations"
    ON public.doctor_hospitals FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 6. Consultations RLS
CREATE POLICY "Users can view their own consultations"
    ON public.consultations FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own consultations"
    ON public.consultations FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own consultations"
    ON public.consultations FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own consultations"
    ON public.consultations FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 7. Consultation Attachments RLS
CREATE POLICY "Users can view their own consultation attachments"
    ON public.consultation_attachments FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own consultation attachments"
    ON public.consultation_attachments FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own consultation attachments"
    ON public.consultation_attachments FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 8. Appointments RLS
CREATE POLICY "Users can view their own appointments"
    ON public.appointments FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own appointments"
    ON public.appointments FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own appointments"
    ON public.appointments FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own appointments"
    ON public.appointments FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 9. Prescriptions RLS
CREATE POLICY "Users can view their own prescriptions"
    ON public.prescriptions FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own prescriptions"
    ON public.prescriptions FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own prescriptions"
    ON public.prescriptions FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own prescriptions"
    ON public.prescriptions FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 10. Reports RLS
CREATE POLICY "Users can view their own reports"
    ON public.reports FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own reports"
    ON public.reports FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own reports"
    ON public.reports FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own reports"
    ON public.reports FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 11. Report Attachments RLS
CREATE POLICY "Users can view their own report attachments"
    ON public.report_attachments FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own report attachments"
    ON public.report_attachments FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own report attachments"
    ON public.report_attachments FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 12. Report Expenses RLS
CREATE POLICY "Users can view their own report expenses"
    ON public.report_expenses FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own report expenses"
    ON public.report_expenses FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own report expenses"
    ON public.report_expenses FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own report expenses"
    ON public.report_expenses FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 13. Measurements RLS
CREATE POLICY "Users can view their own measurements"
    ON public.measurements FOR SELECT TO authenticated
    USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own measurements"
    ON public.measurements FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own measurements"
    ON public.measurements FOR UPDATE TO authenticated
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own measurements"
    ON public.measurements FOR DELETE TO authenticated
    USING (auth.uid() = user_id);
