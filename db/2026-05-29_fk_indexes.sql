-- ════════════════════════════════════════════════════════════════
-- Migration: 2026-05-29_fk_indexes.sql
-- Add missing indexes on foreign-key columns.
-- Uses a dynamic approach so it only indexes columns that actually
-- exist in the live DB — safe to run against any schema state.
-- ════════════════════════════════════════════════════════════════

DO $$
DECLARE
  r RECORD;
  idx_name text;
BEGIN
  -- Loop over every FK column in the public schema
  FOR r IN
    SELECT
      tc.table_name,
      kcu.column_name
    FROM information_schema.table_constraints  tc
    JOIN information_schema.key_column_usage   kcu
      ON  tc.constraint_name = kcu.constraint_name
      AND tc.table_schema    = kcu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema    = 'public'
    ORDER BY tc.table_name, kcu.column_name
  LOOP
    idx_name := 'idx_' || r.table_name || '_' || r.column_name;

    -- Skip if an index on this (table, column) already exists
    IF EXISTS (
      SELECT 1
      FROM   pg_indexes
      WHERE  schemaname = 'public'
        AND  tablename  = r.table_name
        AND  indexdef   LIKE '%(' || r.column_name || ')%'
    ) THEN
      RAISE NOTICE 'Skipping % (already indexed)', idx_name;
      CONTINUE;
    END IF;

    RAISE NOTICE 'Creating %', idx_name;
    EXECUTE format(
      'CREATE INDEX IF NOT EXISTS %I ON %I(%I)',
      idx_name, r.table_name, r.column_name
    );
  END LOOP;
END $$;

-- Show all newly created idx_ indexes for verification
SELECT indexname, tablename
FROM   pg_indexes
WHERE  schemaname = 'public'
  AND  indexname  LIKE 'idx_%'
ORDER  BY tablename, indexname;
