-- Migration 004: fix farm_visits RLS after the multi-role migration.
--
-- Problem: migration 003 created policies comparing  auth.uid() = fo_id.
-- But fo_id stores the app_users ROW id, which is no longer equal to
-- auth.uid() (the auth link is the app_users.auth_user_id column). Every
-- Field Officer visit insert therefore failed with:
--   "new row violates row-level security policy for table farm_visits"
--
-- Fix: match fo_id against the caller's own app_users row(s) via auth_user_id.
-- Run this in: Supabase Dashboard -> SQL Editor.

ALTER TABLE farm_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "FO can read own visits"   ON farm_visits;
DROP POLICY IF EXISTS "FO can insert visits"     ON farm_visits;
DROP POLICY IF EXISTS "FO can update own visits" ON farm_visits;

CREATE POLICY "FO can read own visits"
  ON farm_visits FOR SELECT
  USING (fo_id IN (SELECT id FROM app_users WHERE auth_user_id = auth.uid()));

CREATE POLICY "FO can insert visits"
  ON farm_visits FOR INSERT
  WITH CHECK (fo_id IN (SELECT id FROM app_users WHERE auth_user_id = auth.uid()));

CREATE POLICY "FO can update own visits"
  ON farm_visits FOR UPDATE
  USING      (fo_id IN (SELECT id FROM app_users WHERE auth_user_id = auth.uid()))
  WITH CHECK (fo_id IN (SELECT id FROM app_users WHERE auth_user_id = auth.uid()));

-- The "Authenticated can read all farm_visits" policy from migration 003
-- stays as-is so admin staff keep full read access.
