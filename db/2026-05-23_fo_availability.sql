-- FO availability toggles
-- Run in Supabase SQL Editor

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS fo_available         boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS fo_urgent_calls      boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN app_users.fo_available    IS 'Field Officer visible in Talk to an Expert directory';
COMMENT ON COLUMN app_users.fo_urgent_calls IS 'Allow high-rated farmers to call outside working hours';
