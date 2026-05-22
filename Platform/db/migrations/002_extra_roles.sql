-- ── Migration 002: Multi-role support for staff ──────────────────────────
-- Adds extra_roles to staff_profiles (used for login session / access control)
-- and to app_users (used for team management display).
-- Run in the Supabase SQL editor:
--   https://supabase.com/dashboard/project/nqyutflqzjjueemirgzr/sql

ALTER TABLE staff_profiles
  ADD COLUMN IF NOT EXISTS extra_roles text[] NOT NULL DEFAULT '{}';

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS extra_roles text[] NOT NULL DEFAULT '{}';

-- RLS: staff can update their own extra_roles (already covered by staff_write policy)
-- No new policies needed — existing UPDATE policy on staff_profiles covers this column.
