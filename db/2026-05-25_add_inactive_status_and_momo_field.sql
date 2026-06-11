-- ─────────────────────────────────────────────────────────────────
-- Migration: 2026-05-25
-- 1. Add 'inactive' to the user_status enum
--    (fixes "invalid input value for enum user_status: inactive"
--     error when deactivating agents / field officers from admin)
-- 2. Add commission_payout_phone column to app_users
--    (stores the mobile money number for commission payouts)
-- ─────────────────────────────────────────────────────────────────

-- 1. Extend the user_status enum
--    IF NOT EXISTS makes this safe to run more than once.
ALTER TYPE user_status ADD VALUE IF NOT EXISTS 'inactive';

-- 2. Add the commission payout phone column (if not already present)
ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS commission_payout_phone text;

-- 3. Add the commission payout phone column (if not already present)
--    (run separately after the above two statements have committed)
-- Optional index for inactive-user lookups — paste into a NEW query
-- after this script has finished, because PostgreSQL won't let you
-- reference a just-added enum value in the same transaction:
--
-- CREATE INDEX IF NOT EXISTS idx_app_users_status_inactive
--   ON app_users (status)
--   WHERE status = 'inactive';
