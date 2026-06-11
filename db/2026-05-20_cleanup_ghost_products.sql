-- ─────────────────────────────────────────────────────────────────────
-- Cleanup: products that show on the mobile app even after "delete"
--
-- Symptom: a category tile shows "1 item" on the app even though the
-- admin shows zero active products in that category.
--
-- Cause: the admin's archive / draft / pause actions flip status to
-- 'archived' or 'draft' AND show_on_shop to false — but if a row's
-- show_on_shop somehow stayed true (e.g. an older edit before the
-- two-flag rule, or a bulk import) the mobile app's previous query
-- (filtered only on show_on_shop=true) would still surface it.
--
-- The app-side fix (also require status='active') ships in agmore-v37,
-- but this query also fixes the underlying data so the issue can't
-- come back via a different surface (search, agent ordering, etc.).
--
-- Run in Supabase SQL editor:
--   https://app.supabase.com/project/nqyutflqzjjueemirgzr/sql
-- ─────────────────────────────────────────────────────────────────────

-- 1) Show the offenders first (read-only). Comment out before running
--    the UPDATE if you want to skip the preview.
select id, name, category, status, show_on_shop, updated_at
  from public.products
 where show_on_shop = true
   and status is distinct from 'active'
 order by category, name;

-- 2) Auto-fix: any row that is NOT active should not be shown on shop.
update public.products
   set show_on_shop = false,
       updated_at   = now()
 where show_on_shop = true
   and status is distinct from 'active';

-- 3) Re-check the Livestock count (should match the admin's count).
select category, count(*) as live_items
  from public.products
 where show_on_shop = true and status = 'active'
 group by category
 order by category;
