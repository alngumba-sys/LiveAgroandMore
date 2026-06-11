-- ════════════════════════════════════════════════════════════════
-- Migration: 2026-05-29_ensure_agent_diaspora_columns.sql
--
-- Guarantees every app_users column the mobile app writes during AGENT
-- and DIASPORA self-signup exists. saveProfile() has no column-drop retry,
-- so a single missing column makes the whole insert fail silently (the
-- same trap that hid the fo_* columns and blocked Field Officer signups).
--
-- Specifically: home_outlet and years_in_trade were never added by any
-- prior migration, so agent signups (which always set them) were failing.
-- All columns are nullable text — safe for existing farmer/FO/diaspora rows.
-- Idempotent: safe to run more than once.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE public.app_users
  -- ── Agent ──────────────────────────────────────────────
  ADD COLUMN IF NOT EXISTS home_outlet             text,
  ADD COLUMN IF NOT EXISTS years_in_trade          text,
  ADD COLUMN IF NOT EXISTS national_id             text,
  ADD COLUMN IF NOT EXISTS bank_name               text,
  ADD COLUMN IF NOT EXISTS bank_account_number     text,
  ADD COLUMN IF NOT EXISTS bank_account_name       text,
  ADD COLUMN IF NOT EXISTS bank_branch             text,
  ADD COLUMN IF NOT EXISTS commission_payout_phone text,
  -- ── Diaspora ───────────────────────────────────────────
  ADD COLUMN IF NOT EXISTS country_of_residence    text,
  ADD COLUMN IF NOT EXISTS local_contact_name      text,
  ADD COLUMN IF NOT EXISTS local_contact_rel       text,
  ADD COLUMN IF NOT EXISTS local_contact_phone     text,
  ADD COLUMN IF NOT EXISTS local_contact_district  text,
  ADD COLUMN IF NOT EXISTS local_contact_village   text,
  ADD COLUMN IF NOT EXISTS local_contact_outlet    text;

-- ── Verify: all of these should be listed ─────────────────
SELECT column_name
FROM   information_schema.columns
WHERE  table_name = 'app_users'
  AND  column_name IN (
    'home_outlet','years_in_trade','national_id',
    'bank_name','bank_account_number','bank_account_name','bank_branch',
    'commission_payout_phone','country_of_residence',
    'local_contact_name','local_contact_rel','local_contact_phone',
    'local_contact_district','local_contact_village','local_contact_outlet'
  )
ORDER BY column_name;
