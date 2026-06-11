-- ─────────────────────────────────────────────────────────────────────
-- Migration: add bank payout details to app_users for Agent role.
-- Run in Supabase SQL editor:
--   https://app.supabase.com/project/nqyutflqzjjueemirgzr/sql
--
-- Agent registration captures bank info so finance can deposit
-- commission payouts directly. Columns are nullable so existing
-- farmer / diaspora / FO rows stay valid.
-- ─────────────────────────────────────────────────────────────────────

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS bank_name              text,
  ADD COLUMN IF NOT EXISTS bank_account_number    text,
  ADD COLUMN IF NOT EXISTS bank_account_name      text,
  ADD COLUMN IF NOT EXISTS bank_branch            text;

COMMENT ON COLUMN app_users.bank_name           IS 'Bank used for agent commission payouts (e.g. Stanbic, Centenary).';
COMMENT ON COLUMN app_users.bank_account_number IS 'Account number on the named bank — used by finance for payout.';
COMMENT ON COLUMN app_users.bank_account_name   IS 'Name on the bank account (may differ from full_name for joint / business accounts).';
COMMENT ON COLUMN app_users.bank_branch         IS 'Optional branch name to disambiguate same-number accounts across branches.';

-- Sanity check: list any agents with missing payout info, so MD can
-- prompt them to update via Edit Profile.
-- SELECT id, full_name, email, district FROM app_users
--   WHERE role = 'agent' AND (bank_name IS NULL OR bank_account_number IS NULL);
