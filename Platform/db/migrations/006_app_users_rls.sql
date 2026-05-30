-- Migration 006: definitive app_users RLS.
--
-- Fixes two recurring problems:
--   1) An agent / field officer logs in but sees the FARMER profile with no
--      data. Cause: the login lookup `select ... where auth_user_id = auth.uid()`
--      returned nothing because the effective SELECT policy was still keyed on
--      the old `id` column (which, after the multi_role migration, no longer
--      equals auth.uid()). With no rows returned the app falls back to a
--      default farmer profile.
--   2) "Could not register a farmer" — an agent could not INSERT a farmer row
--      tagged to them, because the only INSERT policy required
--      auth.uid() = auth_user_id (true only for your own row).
--
-- This migration sets SELECT / INSERT / UPDATE policies explicitly and is
-- idempotent. It does NOT touch your staff/admin policy, so back-office access
-- is unchanged. Run in: Supabase Dashboard -> SQL Editor.

ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

-- ── SELECT: any signed-in user can read app_users ──────────────────────────
-- The app must read other people's rows (expert directory, an agent's own
-- customers, admin lists) AND — critically — the caller's own role rows at
-- login. This matches the original schema's permissive read.
DROP POLICY IF EXISTS "staff_read_all"             ON public.app_users;
DROP POLICY IF EXISTS "app_users_select_own"       ON public.app_users;
DROP POLICY IF EXISTS "Users can read own profile" ON public.app_users;
DROP POLICY IF EXISTS "app_users_select_auth"      ON public.app_users;

CREATE POLICY "app_users_select_auth" ON public.app_users
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ── INSERT: own row, OR an agent registering a farmer tagged to them ───────
DROP POLICY IF EXISTS "app_users_insert_own"          ON public.app_users;
DROP POLICY IF EXISTS "app_users_insert_agent_farmer" ON public.app_users;

CREATE POLICY "app_users_insert_own" ON public.app_users
  FOR INSERT
  WITH CHECK (auth.uid() = auth_user_id);

CREATE POLICY "app_users_insert_agent_farmer" ON public.app_users
  FOR INSERT
  WITH CHECK (
    role = 'farmer'
    AND referral_agent_id IN (
      SELECT id FROM public.app_users WHERE auth_user_id = auth.uid()
    )
  );

-- ── UPDATE: a signed-in user may update their own row(s) ───────────────────
DROP POLICY IF EXISTS "app_users_update_own" ON public.app_users;
CREATE POLICY "app_users_update_own" ON public.app_users
  FOR UPDATE
  USING      (auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() = auth_user_id);

-- Verify (you should see app_users_select_auth for SELECT, two INSERT policies,
-- app_users_update_own for UPDATE, plus your existing staff/admin policy):
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'app_users' ORDER BY cmd, policyname;
