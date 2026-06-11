-- Migration 003: farm_visits table for Field Officer visit logging
-- Run this in: Supabase Dashboard → SQL Editor

CREATE TABLE IF NOT EXISTS farm_visits (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fo_id           uuid NOT NULL REFERENCES app_users(id),
  farmer_name     text NOT NULL,
  farmer_phone    text,
  district        text,
  sub_county      text,
  village         text,
  crop            text NOT NULL DEFAULT 'General',
  issue_observed  text NOT NULL,
  advice_given    text NOT NULL,
  urgency         text NOT NULL DEFAULT 'medium',  -- low | medium | high
  followup_weeks  integer,
  ask_rating      boolean NOT NULL DEFAULT true,
  lat             numeric,
  lng             numeric,
  gps_accuracy    text,
  location_type   text NOT NULL DEFAULT 'gps',     -- gps | manual
  status          text NOT NULL DEFAULT 'open',    -- open | resolved
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Row Level Security
ALTER TABLE farm_visits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "FO can read own visits"
  ON farm_visits FOR SELECT
  USING (auth.uid() = fo_id);

CREATE POLICY "FO can insert visits"
  ON farm_visits FOR INSERT
  WITH CHECK (auth.uid() = fo_id);

CREATE POLICY "FO can update own visits"
  ON farm_visits FOR UPDATE
  USING (auth.uid() = fo_id);

-- Admin staff can read all visits
CREATE POLICY "Authenticated can read all farm_visits"
  ON farm_visits FOR SELECT
  USING (auth.uid() IS NOT NULL);
