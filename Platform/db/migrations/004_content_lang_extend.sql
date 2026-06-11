-- ════════════════════════════════════════════════════════════════════
-- 004_content_lang_extend.sql
-- Extend the content_lang enum so the admin "Add Content" form's
-- language dropdown values all match the database.
--
-- Mismatch found on 2026-05-25:
--   Form offers : english, luganda, lusoga, runyankore, luo
--   DB enum has : english, luganda, runyankole, ateso, acholi
--
-- Strategy: add the missing values (lusoga, runyankore, luo).
-- We DO NOT rename the existing 'runyankole' — that would break any
-- rows already saved. Instead the form will now match the DB and
-- continue to accept the historical spelling too.
--
-- Run this in the Supabase SQL editor:
--   https://app.supabase.com/project/nqyutflqzjjueemirgzr/sql
-- (Each ALTER TYPE ADD VALUE must run as its own statement — they
--  cannot share a transaction. Supabase SQL editor handles this.)
-- ════════════════════════════════════════════════════════════════════

ALTER TYPE content_lang ADD VALUE IF NOT EXISTS 'lusoga';
ALTER TYPE content_lang ADD VALUE IF NOT EXISTS 'runyankore';
ALTER TYPE content_lang ADD VALUE IF NOT EXISTS 'luo';

-- Optional: verify the enum contents afterwards
-- SELECT enum_range(NULL::content_lang);
