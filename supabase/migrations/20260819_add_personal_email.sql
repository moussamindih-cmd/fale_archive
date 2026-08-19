-- 20260819_add_personal_email.sql
-- Adds personal_email column to employees table for dual email registration

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='personal_email') THEN
        ALTER TABLE public.employees ADD COLUMN personal_email TEXT;
    END IF;
END $$;
