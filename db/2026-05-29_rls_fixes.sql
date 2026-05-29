-- ════════════════════════════════════════════════════════════════
-- Migration: 2026-05-29_rls_fixes.sql
-- Fix two RLS gaps found in security audit:
--   1. settings table writable by any authenticated staff → restrict to md/it_admin
--   2. app_sessions missing DELETE policy
-- ════════════════════════════════════════════════════════════════

-- ── 1. settings: restrict writes to md + it_admin ────────────────
-- Previously any authenticated staff could modify payment codes,
-- API keys, and org settings. Now limited to md and it_admin only.
DROP POLICY IF EXISTS "staff_write" ON settings;

CREATE POLICY "admin_write_settings" ON settings
  FOR ALL
  USING      (current_staff_role() IN ('md', 'it_admin'))
  WITH CHECK (current_staff_role() IN ('md', 'it_admin'));

-- Read policy unchanged: all authenticated staff can read settings.
-- (The SELECT-only policy "staff_read_all" remains in place.)


-- ── 2. app_sessions: add DELETE for staff cleanup ─────────────────
-- app_sessions only had INSERT + SELECT policies; DELETE was missing,
-- so stale sessions could never be pruned by staff.
DROP POLICY IF EXISTS "staff_delete_sessions" ON app_sessions;

CREATE POLICY "staff_delete_sessions" ON app_sessions
  FOR DELETE
  USING (auth.uid() IS NOT NULL);


-- ── Verify ────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd
FROM   pg_policies
WHERE  tablename IN ('settings', 'app_sessions')
ORDER  BY tablename, cmd;
