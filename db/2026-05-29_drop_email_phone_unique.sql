-- ════════════════════════════════════════════════════════════════
-- Migration: 2026-05-29_drop_email_phone_unique.sql
--
-- ROOT CAUSE FIX for "agent (or any 2nd-role) signup never saves".
--
-- The multi_role migration added UNIQUE (auth_user_id, role) so one person
-- can hold several role rows (farmer + agent + field_officer, etc). But the
-- table still had the ORIGINAL global UNIQUE(email) and UNIQUE(phone)
-- constraints from before multi-role. Those limit each email/phone to a
-- single row — so once someone has, say, a field_officer row, trying to
-- create an agent row with the same email/phone is rejected by the unique
-- constraint, and saveProfile()'s insert fails silently. Result: the app
-- shows an in-memory fallback profile but nothing reaches the database, and
-- the agent never appears in the admin Pending tab.
--
-- Fix: drop the global email/phone uniqueness. Identity is the auth user
-- (auth_user_id) and the per-role row is keyed by UNIQUE(auth_user_id, role),
-- which stays in place.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE public.app_users DROP CONSTRAINT IF EXISTS app_users_email_key;
ALTER TABLE public.app_users DROP CONSTRAINT IF EXISTS app_users_phone_key;

-- Some installs created these as unique INDEXES rather than constraints —
-- drop those too, just in case.
DROP INDEX IF EXISTS app_users_email_key;
DROP INDEX IF EXISTS app_users_phone_key;

-- ── Verify: the only unique constraint left should be the (auth_user_id,
--    role) one. email / phone should NOT appear. ───────────────────
SELECT conname
FROM   pg_constraint
WHERE  conrelid = 'public.app_users'::regclass AND contype = 'u';
