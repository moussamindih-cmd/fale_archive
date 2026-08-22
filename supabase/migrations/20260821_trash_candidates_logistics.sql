-- 20260821_trash_candidates_logistics.sql
-- Extends the Trash (soft-delete + restore) feature already used by
-- daily_archives to candidates and logistics_items, so deleted records
-- can be recovered from a trash view instead of being lost.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='candidates' AND column_name='deleted_at') THEN
        ALTER TABLE public.candidates ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='logistics_items' AND column_name='deleted_at') THEN
        ALTER TABLE public.logistics_items ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;
