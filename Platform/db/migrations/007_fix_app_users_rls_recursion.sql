-- Migration 007: fix infinite recursion in app_users RLS (BLOCKER).
--
-- ROOT CAUSE
-- Migration 006 added this INSERT policy on app_users:
--
--   CREATE POLICY "app_users_insert_agent_farmer" ON public.app_users
--     FOR INSERT WITH CHECK (
--       role = 'farmer'
--       AND referral_agent_id IN (
--         SELECT id FROM public.app_users WHERE auth_user_id = auth.uid()  -- <-- self-reference
--       )
--     );
--
-- The subquery selects from app_users *inside* an app_users policy, so
-- evaluating the policy re-triggers the same policy → Postgres aborts with
--   42P17  "infinite recursion detected in policy for relation app_users".
--
-- EFFECT (verified against the live DB on 2026-05-30):
--   • Any authenticated INSERT into app_users fails with 42P17. This silently
--     breaks (a) new agent/field-officer self-signup persistence (saveProfile
--     only console.warns, so the user just sees "under review" and never lands
--     in the admin Pending tab) and (b) an agent registering a farmer
--     (referral_agent_id stays NULL on every row → agents have zero customers).
--
-- FIX
-- Resolve the caller's app_users row id(s) through a SECURITY DEFINER helper.
-- A SECURITY DEFINER function runs as its owner (postgres) and therefore reads
-- app_users *without* re-entering RLS — exactly how current_staff_role() already
-- avoids recursion in this schema. The policy then references the function
-- instead of an inline self-subquery.
--
-- Idempotent. Run in: Supabase Dashboard -> SQL Editor.
-- ============================================================================

ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

-- ── Helper: the app_users row id(s) owned by the current auth user ──────────
-- SECURITY DEFINER => bypasses RLS on app_users inside the function body, so it
-- can be referenced from an app_users policy without recursion.
CREATE OR REPLACE FUNCTION public.current_app_user_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.app_users WHERE auth_user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.current_app_user_ids() FROM public;
GRANT EXECUTE ON FUNCTION public.current_app_user_ids() TO authenticated, anon;

-- ── Recreate the agent-registers-farmer INSERT policy WITHOUT the self-subquery
DROP POLICY IF EXISTS "app_users_insert_agent_farmer" ON public.app_users;

CREATE POLICY "app_users_insert_agent_farmer" ON public.app_users
  FOR INSERT
  WITH CHECK (
    role = 'farmer'
    AND referral_agent_id IN (SELECT public.current_app_user_ids())
  );

-- The other app_users policies from migration 006 are correct and left as-is:
--   app_users_select_auth   (SELECT  : auth.uid() IS NOT NULL)
--   app_users_insert_own    (INSERT  : auth.uid() = auth_user_id)
--   app_users_update_own    (UPDATE  : auth.uid() = auth_user_id)
--   staff_write             (ALL     : auth.uid() IS NOT NULL)  -- back-office, unchanged

-- ── Verify ──────────────────────────────────────────────────────────────────
-- Expect: app_users_insert_agent_farmer present, and NO policy whose
-- qual/with_check contains a bare "FROM app_users" subquery.
SELECT policyname, cmd, qual, with_check
FROM   pg_policies
WHERE  tablename = 'app_users'
ORDER  BY cmd, policyname;
