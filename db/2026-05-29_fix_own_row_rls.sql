-- ════════════════════════════════════════════════════════════════
-- Migration: 2026-05-29_fix_own_row_rls.sql
--
-- ROOT CAUSE FIX for "self-registered farmers / agents / field officers
-- never get saved" (and therefore never reach the admin Pending tab).
--
-- The 2026-05-29_multi_role.sql migration changed app_users.id into an
-- auto-generated random PK (gen_random_uuid) and moved the Supabase auth
-- link to the new auth_user_id column. But the own-row RLS policies still
-- checked `auth.uid() = id`. After the migration a new signup row has a
-- RANDOM id (≠ the user's auth uid), so the INSERT/UPDATE checks always
-- failed and every self-signup was silently rejected by RLS.
--
-- Fix: point the own-row INSERT/UPDATE policies at auth_user_id, which is
-- the column that now equals auth.uid().
-- ════════════════════════════════════════════════════════════════

-- ── INSERT: a signed-in user may create their own role row(s) ─────
DROP POLICY IF EXISTS "app_users_insert_own"         ON public.app_users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.app_users;

CREATE POLICY "app_users_insert_own" ON public.app_users
  FOR INSERT
  WITH CHECK (auth.uid() = auth_user_id);

-- ── UPDATE: a signed-in user may update their own row(s) ──────────
DROP POLICY IF EXISTS "app_users_update_own"         ON public.app_users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.app_users;

CREATE POLICY "app_users_update_own" ON public.app_users
  FOR UPDATE
  USING      (auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() = auth_user_id);

-- NOTE: the SELECT policy (auth.uid() IS NOT NULL) and the staff ALL
-- policy (app_users_staff_all) are correct and left unchanged.

-- ── Verify ────────────────────────────────────────────────────────
SELECT policyname, cmd, qual, with_check
FROM   pg_policies
WHERE  tablename = 'app_users'
ORDER  BY cmd;
