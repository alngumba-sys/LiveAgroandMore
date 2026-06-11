-- ════════════════════════════════════════════════════════════════
-- Migration: 2026-05-29_multi_role.sql
--
-- Allow one email / auth user to have multiple roles
-- (farmer + agent, farmer + field_officer, etc.)
--
-- Strategy:
--   • Add auth_user_id (= the Supabase auth UID) to app_users
--   • Populate from existing id column (backward compat: old rows have id = auth UUID)
--   • Add DEFAULT gen_random_uuid() to id so new role rows get their own PK
--   • Add UNIQUE (auth_user_id, role) — one row per (person, role)
--   • Add index for fast lookup by auth_user_id
-- ════════════════════════════════════════════════════════════════

-- ── 1. Add auth_user_id column ────────────────────────────────────
ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS auth_user_id uuid;

-- ── 2. Populate from existing id (existing rows: id = auth UUID) ──
UPDATE public.app_users
  SET auth_user_id = id
  WHERE auth_user_id IS NULL;

-- ── 3. Enforce NOT NULL now that all rows are populated ───────────
ALTER TABLE public.app_users
  ALTER COLUMN auth_user_id SET NOT NULL;

-- ── 4. Auto-generate PK for new additional-role rows ─────────────
ALTER TABLE public.app_users
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- ── 5. Index for fast "all roles for this auth user" lookup ───────
CREATE INDEX IF NOT EXISTS app_users_auth_user_id_idx
  ON public.app_users(auth_user_id);

-- ── 6. Unique constraint: one row per (auth_user, role) ───────────
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

-- ── Sanity check ──────────────────────────────────────────────────
SELECT id, auth_user_id, role, full_name, status
FROM   public.app_users
ORDER  BY created_at
LIMIT  10;
