-- Add plot_size to farm_visits — captured by the FO "Log Farm Visit" form
-- (acre-range dropdown: "< 0.5 acre", "0.5–1 acre", "1–2 acres", "2–5 acres", "5+ acres")
-- Run in Supabase SQL Editor (safe to re-run).

ALTER TABLE farm_visits
  ADD COLUMN IF NOT EXISTS plot_size text;
