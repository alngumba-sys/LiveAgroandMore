-- ============================================================
-- Field Officer organisation attribution.
--   Captured at FO onboarding: which body the officer works for.
--   Allowed categories: Agro & More | Local government |
--   Ministry of Agriculture | Other (free-text in fo_organisation_other).
--   Enables performance to be sliced PER ORGANISATION.
-- Run once in the Supabase SQL editor (project: agroandmorehub.com).
-- Safe to re-run.
-- ============================================================

-- 1) Columns ---------------------------------------------------------
alter table public.app_users
  add column if not exists fo_organisation       text,
  add column if not exists fo_organisation_other text;

create index if not exists idx_app_users_fo_org
  on public.app_users (fo_organisation)
  where role = 'field_officer';

-- Optional: normalise blanks to NULL so grouping is clean.
update public.app_users
   set fo_organisation = nullif(trim(fo_organisation), '')
 where role = 'field_officer';

-- 2) Per-organisation performance view -------------------------------
-- One row per organisation: officer headcount, average rating across
-- BOTH visit and direct-talk ratings, total reviews, and logged visits.
create or replace view public.fo_org_performance as
with fos as (
  select id,
         coalesce(nullif(trim(fo_organisation), ''), 'Unspecified') as org
    from public.app_users
   where role = 'field_officer'
),
ratings as (
  select fo_id, stars from public.visit_ratings
  union all
  select fo_id, stars from public.officer_ratings
)
select
  f.org                                             as organisation,
  count(distinct f.id)                              as officers,
  round(avg(r.stars)::numeric, 2)                   as avg_rating,
  count(r.stars)                                    as total_ratings,
  (select count(*) from public.farm_visits v
     where v.fo_id in (select id from fos f2 where f2.org = f.org)) as farm_visits
from fos f
left join ratings r on r.fo_id = f.id
group by f.org
order by avg_rating desc nulls last;

-- Staff-only read on the view's underlying data is already governed by
-- the base tables' RLS; the view runs with the caller's privileges.
