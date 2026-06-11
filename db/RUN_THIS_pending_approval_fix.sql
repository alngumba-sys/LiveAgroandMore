-- ════════════════════════════════════════════════════════════════
-- RUN THIS in Supabase → SQL Editor to fix FO/Agent signups not
-- persisting (and therefore never appearing under "Pending approval").
--
-- It applies two migrations the production DB is missing:
--   1. Field Officer profile columns (fo_university, fo_specialities, …)
--   2. Multi-role support: auth_user_id column + UNIQUE(auth_user_id, role)
--      — the constraint the app's profile upsert (onConflict) depends on.
--
-- Safe to run more than once (all steps are guarded / idempotent).
-- ════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- PART 1 · Field Officer profile columns
-- ─────────────────────────────────────────────────────────────────
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS fo_university        text,
  ADD COLUMN IF NOT EXISTS fo_grad_year         text,
  ADD COLUMN IF NOT EXISTS fo_experience        text,
  ADD COLUMN IF NOT EXISTS fo_specialities      text[],
  ADD COLUMN IF NOT EXISTS fo_districts_covered text[],
  ADD COLUMN IF NOT EXISTS fo_languages         text;

-- Back-fill existing FO rows from auth metadata where columns are still null.
UPDATE public.app_users u
SET
  fo_university        = COALESCE(u.fo_university,  (au.raw_user_meta_data->>'fo_university')),
  fo_grad_year         = COALESCE(u.fo_grad_year,   (au.raw_user_meta_data->>'fo_grad_year')),
  fo_experience        = COALESCE(u.fo_experience,  (au.raw_user_meta_data->>'fo_experience')),
  fo_specialities      = CASE
                           WHEN u.fo_specialities IS NOT NULL THEN u.fo_specialities
                           WHEN au.raw_user_meta_data ? 'fo_specialities'
                           THEN ARRAY(SELECT jsonb_array_elements_text(au.raw_user_meta_data->'fo_specialities'))
                           ELSE NULL
                         END,
  fo_districts_covered = CASE
                           WHEN u.fo_districts_covered IS NOT NULL THEN u.fo_districts_covered
                           WHEN au.raw_user_meta_data ? 'fo_districts_covered'
                           THEN ARRAY(SELECT jsonb_array_elements_text(au.raw_user_meta_data->'fo_districts_covered'))
                           ELSE NULL
                         END,
  fo_languages         = COALESCE(u.fo_languages,   (au.raw_user_meta_data->>'fo_languages'))
FROM auth.users au
WHERE au.id = u.id
  AND u.role = 'field_officer'
  AND (u.fo_university IS NULL OR u.fo_grad_year IS NULL
       OR u.fo_specialities IS NULL OR u.fo_districts_covered IS NULL);

-- ─────────────────────────────────────────────────────────────────
-- PART 2 · Multi-role support (auth_user_id + unique constraint)
-- ─────────────────────────────────────────────────────────────────
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS auth_user_id uuid;

UPDATE public.app_users
  SET auth_user_id = id
  WHERE auth_user_id IS NULL;

ALTER TABLE public.app_users
  ALTER COLUMN auth_user_id SET NOT NULL;

ALTER TABLE public.app_users
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

CREATE INDEX IF NOT EXISTS app_users_auth_user_id_idx
  ON public.app_users(auth_user_id);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'app_users_auth_user_role_unique'
      AND conrelid = 'public.app_users'::regclass
  ) THEN
    ALTER TABLE public.app_users
      ADD CONSTRAINT app_users_auth_user_role_unique
      UNIQUE (auth_user_id, role);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────
-- VERIFY · should return the new columns + the unique constraint
-- ─────────────────────────────────────────────────────────────────
SELECT column_name FROM information_schema.columns
WHERE table_name = 'app_users'
  AND column_name IN ('auth_user_id','fo_university','fo_specialities');

SELECT conname FROM pg_constraint
WHERE conrelid = 'public.app_users'::regclass AND contype = 'u';
