-- 20260819_add_soft_delete.sql
-- Adds deleted_at to daily_archives for the Trash feature

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_archives' AND column_name='deleted_at') THEN
        ALTER TABLE public.daily_archives ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;
