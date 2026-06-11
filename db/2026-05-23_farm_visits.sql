-- Patch farm_visits — adds followup_weeks, photo_urls columns and performance index
-- Also creates farm-visit-photos storage bucket
-- Run in Supabase SQL Editor (safe to run if already applied)

ALTER TABLE farm_visits
  ADD COLUMN IF NOT EXISTS followup_weeks integer,
  ADD COLUMN IF NOT EXISTS photo_urls     text[];

CREATE INDEX IF NOT EXISTS farm_visits_fo_id_idx
  ON farm_visits (fo_id, created_at DESC);

-- Storage bucket for farm visit photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('farm-visit-photos', 'farm-visit-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated field officers to upload
CREATE POLICY "FO can upload visit photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'farm-visit-photos'
    AND auth.uid() IS NOT NULL
  );

-- Public read (so photo URLs work in admin dashboard)
CREATE POLICY "Public can view visit photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'farm-visit-photos');
