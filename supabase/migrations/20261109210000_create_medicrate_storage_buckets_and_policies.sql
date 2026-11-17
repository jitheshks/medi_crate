-- ==============================================================================
-- MediCrate Storage Foundation & Attachment Policies Migration
-- Migration ID: 20261109210000_create_medicrate_storage_buckets_and_policies.sql
-- Description: Creates private Supabase Storage buckets (consultations, reports, avatars),
--              configures file size limits and MIME type whitelists, and establishes
--              strict Row Level Security (RLS) policies on storage.objects with
--              positive parent ownership verification and tenant isolation.
-- PostgreSQL Version: 17+ (Supabase)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PRIVATE STORAGE BUCKETS CONFIGURATION
-- Buckets:
--   - consultations: max 25MB (26,214,400 bytes), PDF + Images (JPEG, PNG, WEBP)
--   - reports:       max 25MB (26,214,400 bytes), PDF + Images (JPEG, PNG, WEBP)
--   - avatars:       max 5MB  (5,242,880 bytes),  Images (JPEG, PNG, WEBP)
-- All buckets are strictly private (public = false).
-- ------------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    (
        'consultations',
        'consultations',
        FALSE,
        26214400,
        ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']::text[]
    ),
    (
        'reports',
        'reports',
        FALSE,
        26214400,
        ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']::text[]
    ),
    (
        'avatars',
        'avatars',
        FALSE,
        5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
    )
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ------------------------------------------------------------------------------
-- 2. ROW LEVEL SECURITY POLICIES ON storage.objects
-- Policies enforce:
--   1. Tenant Isolation: Top-level folder must match auth.uid()::text.
--   2. Strict Folder Depth: Path must strictly adhere to expected folder structure.
--   3. Positive Parent Ownership Verification:
--      - For consultations: Path must match an existing public.consultations record
--        where id::text = folder[2] AND user_id = auth.uid().
--      - For reports: Path must match an existing public.reports record
--        where id::text = folder[2] AND user_id = auth.uid().
--      - For avatars: Top folder must match auth.uid()::text.
--   4. Valid File Extensions: pdf, jpg, jpeg, png, webp.
-- ------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------
-- 2.1 CONSULTATIONS STORAGE POLICIES
-- Expected path pattern: {user_id}/{consultation_id}/{attachment_file}
-- ------------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view their own consultation attachments" ON storage.objects;
CREATE POLICY "Users can view their own consultation attachments"
    ON storage.objects FOR SELECT
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
        )
    );

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
        )
    );

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
        )
    );

DROP POLICY IF EXISTS "Users can delete their own consultation attachments" ON storage.objects;
CREATE POLICY "Users can delete their own consultation attachments"
    ON storage.objects FOR DELETE
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
        )
    );

-- ------------------------------------------------------------------------------
-- 2.2 REPORTS STORAGE POLICIES
-- Expected path pattern: {user_id}/{report_id}/{attachment_file}
-- ------------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view their own report attachments" ON storage.objects;
CREATE POLICY "Users can view their own report attachments"
    ON storage.objects FOR SELECT
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
        )
    );

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
        )
    );

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
        )
    );

DROP POLICY IF EXISTS "Users can delete their own report attachments" ON storage.objects;
CREATE POLICY "Users can delete their own report attachments"
    ON storage.objects FOR DELETE
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
        )
    );

-- ------------------------------------------------------------------------------
-- 2.3 AVATARS STORAGE POLICIES
-- Expected path pattern: {user_id}/{avatar_file} or {user_id}/{profile_id}/{avatar_file}
-- ------------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view their own avatars" ON storage.objects;
CREATE POLICY "Users can view their own avatars"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND array_length(storage.foldername(name), 1) >= 1
    );

DROP POLICY IF EXISTS "Users can upload their own avatars" ON storage.objects;
CREATE POLICY "Users can upload their own avatars"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND array_length(storage.foldername(name), 1) >= 1
        AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
    );

DROP POLICY IF EXISTS "Users can update their own avatars" ON storage.objects;
CREATE POLICY "Users can update their own avatars"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND array_length(storage.foldername(name), 1) >= 1
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND array_length(storage.foldername(name), 1) >= 1
        AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
    );

DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;
CREATE POLICY "Users can delete their own avatars"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND array_length(storage.foldername(name), 1) >= 1
    );
