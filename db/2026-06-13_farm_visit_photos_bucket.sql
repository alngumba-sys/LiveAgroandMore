-- Ensure farm-visit-photos storage bucket exists with correct policies
-- Safe to re-run (all statements are idempotent)

-- Create bucket (public = true so photo URLs work without auth)
INSERT INTO storage.buckets (id, name, public)
VALUES ('farm-visit-photos', 'farm-visit-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow authenticated users (field officers) to upload
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'FO can upload visit photos'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "FO can upload visit photos"
        ON storage.objects FOR INSERT
        WITH CHECK (
          bucket_id = 'farm-visit-photos'
          AND auth.uid() IS NOT NULL
        )
    $pol$;
  END IF;
END $$;

-- Public read so URLs work in admin dashboard
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'Public can view visit photos'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "Public can view visit photos"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'farm-visit-photos')
    $pol$;
  END IF;
END $$;

-- Also ensure photo_urls column exists on farm_visits
ALTER TABLE farm_visits
  ADD COLUMN IF NOT EXISTS photo_urls text[];
