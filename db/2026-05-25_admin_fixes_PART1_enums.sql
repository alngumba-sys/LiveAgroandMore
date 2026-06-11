-- ═══════════════════════════════════════════════════════════════════
-- PART 1 of 4 — Enum additions
-- Run this FIRST, alone, after closing any admin.html browser tabs.
-- `ALTER TYPE ... ADD VALUE` needs its own transaction; the new value
-- can't be used in the same transaction that added it.
-- ═══════════════════════════════════════════════════════════════════

ALTER TYPE staff_role  ADD VALUE IF NOT EXISTS 'finance';
ALTER TYPE user_status ADD VALUE IF NOT EXISTS 'rejected';

-- Verify
SELECT 'staff_role'   AS enum, string_agg(enumlabel, ', ') AS values
FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname='staff_role')
UNION ALL
SELECT 'user_status', string_agg(enumlabel, ', ')
FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname='user_status');
