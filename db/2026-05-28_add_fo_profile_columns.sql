-- ─────────────────────────────────────────────────────────────────────────────
-- 2026-05-28 · Add Field Officer profile columns to app_users
--
-- These columns capture the extra information FOs fill in during self-signup
-- (university, graduation year, experience, specialities, districts, languages).
-- They are also used by the FO pending-approval screen (fo-1) and the admin
-- Users & Roles panel.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS fo_university        text,
  ADD COLUMN IF NOT EXISTS fo_grad_year         text,
  ADD COLUMN IF NOT EXISTS fo_experience        text,
  ADD COLUMN IF NOT EXISTS fo_specialities      text[],
  ADD COLUMN IF NOT EXISTS fo_districts_covered text[],
  ADD COLUMN IF NOT EXISTS fo_languages         text;

COMMENT ON COLUMN public.app_users.fo_university        IS 'University/college attended (Field Officers only).';
COMMENT ON COLUMN public.app_users.fo_grad_year         IS 'Graduation year (Field Officers only).';
COMMENT ON COLUMN public.app_users.fo_experience        IS 'Years of field experience (Field Officers only).';
COMMENT ON COLUMN public.app_users.fo_specialities      IS 'Crop/livestock specialities selected during FO signup.';
COMMENT ON COLUMN public.app_users.fo_districts_covered IS 'Districts the FO is willing to cover.';
COMMENT ON COLUMN public.app_users.fo_languages         IS 'Languages spoken (Field Officers only).';

-- Back-fill existing FO rows from auth.users.user_metadata where the columns
-- are now null but the metadata was captured at signup time.
-- This is safe to run multiple times (only updates rows where the column is
-- still null AND the metadata key exists).
UPDATE public.app_users u
SET
  fo_university        = COALESCE(u.fo_university,        (au.raw_user_meta_data->>'fo_university')),
  fo_grad_year         = COALESCE(u.fo_grad_year,         (au.raw_user_meta_data->>'fo_grad_year')),
  fo_experience        = COALESCE(u.fo_experience,        (au.raw_user_meta_data->>'fo_experience')),
  fo_specialities      = CASE
                           WHEN u.fo_specialities IS NOT NULL THEN u.fo_specialities
                           WHEN au.raw_user_meta_data ? 'fo_specialities'
                           THEN ARRAY(
                             SELECT jsonb_array_elements_text(au.raw_user_meta_data->'fo_specialities')
                           )
                           ELSE NULL
                         END,
  fo_districts_covered = CASE
                           WHEN u.fo_districts_covered IS NOT NULL THEN u.fo_districts_covered
                           WHEN au.raw_user_meta_data ? 'fo_districts_covered'
                           THEN ARRAY(
                             SELECT jsonb_array_elements_text(au.raw_user_meta_data->'fo_districts_covered')
                           )
                           ELSE NULL
                         END,
  fo_languages         = COALESCE(u.fo_languages,         (au.raw_user_meta_data->>'fo_languages'))
FROM auth.users au
WHERE au.id = u.id
  AND u.role = 'field_officer'
  AND (
    u.fo_university IS NULL OR
    u.fo_grad_year  IS NULL OR
    u.fo_specialities IS NULL OR
    u.fo_districts_covered IS NULL
  );
