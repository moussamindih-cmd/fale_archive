-- =====================================================================
-- 20260821_document_storage.sql
-- Persist attached documents (candidates, logistics items, daily
-- archives) in a private, organization-isolated Storage bucket instead
-- of only keeping them in memory client-side.
-- =====================================================================

-- 1. Private bucket for archived documents (invoices, CVs, justificatifs...)
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- 2. RLS policies on storage.objects: only members of the organization
-- that owns a file (first path segment = organization_id) can read/write it.
-- Reuses public.current_user_organization_id() defined in 20260817_init_saas.sql.
DROP POLICY IF EXISTS "Isolation par organisation" ON storage.objects;

CREATE POLICY "Isolation par organisation" ON storage.objects
    FOR ALL USING (
        bucket_id = 'documents'
        AND (storage.foldername(name))[1] = public.current_user_organization_id()::text
    )
    WITH CHECK (
        bucket_id = 'documents'
        AND (storage.foldername(name))[1] = public.current_user_organization_id()::text
    );

-- 3. Columns to store the uploaded files' metadata (name, extension,
-- size, storage path) as JSONB arrays.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='candidates' AND column_name='documents') THEN
        ALTER TABLE public.candidates ADD COLUMN documents JSONB NOT NULL DEFAULT '[]'::jsonb;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='logistics_items' AND column_name='documents') THEN
        ALTER TABLE public.logistics_items ADD COLUMN documents JSONB NOT NULL DEFAULT '[]'::jsonb;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_archives' AND column_name='documents') THEN
        ALTER TABLE public.daily_archives ADD COLUMN documents JSONB NOT NULL DEFAULT '[]'::jsonb;
    END IF;
END $$;
