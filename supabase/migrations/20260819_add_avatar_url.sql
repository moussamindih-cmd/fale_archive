-- 20260819_add_avatar_url.sql
-- Adds avatar_url column to employees table and configures storage

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='avatar_url') THEN
        ALTER TABLE public.employees ADD COLUMN avatar_url TEXT;
    END IF;
END $$;

-- Configure storage for avatars
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies
-- Allow anyone to read avatars
CREATE POLICY "Avatar images are publicly accessible." 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'avatars' );

-- Allow authenticated users to upload avatars
CREATE POLICY "Users can upload their own avatar." 
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'avatars' AND auth.role() = 'authenticated' );

-- Allow users to update their own avatar
CREATE POLICY "Users can update their own avatar." 
ON storage.objects FOR UPDATE 
USING ( bucket_id = 'avatars' AND auth.role() = 'authenticated' );

-- Allow users to delete their own avatar
CREATE POLICY "Users can delete their own avatar." 
ON storage.objects FOR DELETE 
USING ( bucket_id = 'avatars' AND auth.role() = 'authenticated' );
