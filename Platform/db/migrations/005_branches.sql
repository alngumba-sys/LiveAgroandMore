-- Migration 005: restrict the platform to its 7 official branches.
-- Branches: Mpigi, Gomba, Butambala, Isingiro, Nakapiripirit, Moroto, Soroti.
-- All outlet/branch selectors load from this table, so this is the single
-- source of truth. Run in: Supabase Dashboard -> SQL Editor.

-- 1) Ensure the 7 branches exist (idempotent by name).
INSERT INTO outlets (name, district, sub_county)
SELECT v.name, v.district, v.sub_county FROM (VALUES
  ('Mpigi Branch',         'Mpigi',         'Mpigi Town Council'),
  ('Gomba Branch',         'Gomba',         'Maddu'),
  ('Butambala Branch',     'Butambala',     'Gombe'),
  ('Isingiro Branch',      'Isingiro',      'Isingiro Town Council'),
  ('Nakapiripirit Branch', 'Nakapiripirit', 'Nakapiripirit Town Council'),
  ('Moroto Branch',        'Moroto',        'Moroto Municipality'),
  ('Soroti Branch',        'Soroti',        'Soroti City')
) AS v(name, district, sub_county)
WHERE NOT EXISTS (SELECT 1 FROM outlets o WHERE o.name = v.name);

-- 2) Remove every other outlet so ONLY the 7 branches remain.
--    NOTE: selectors do not filter on `active`, so old outlets must actually
--    be deleted. If this DELETE raises a foreign-key error, some existing
--    orders / product_outlet_stock rows still point at an old outlet —
--    reassign or remove those rows first, then re-run. (If you would rather
--    keep history, replace this DELETE with:  UPDATE outlets SET active=false
--    WHERE name NOT IN (...the 7...);  and add `.eq('active',true)` to the
--    outlet SELECT queries.)
DELETE FROM outlets
WHERE name NOT IN (
  'Mpigi Branch','Gomba Branch','Butambala Branch','Isingiro Branch',
  'Nakapiripirit Branch','Moroto Branch','Soroti Branch'
);
