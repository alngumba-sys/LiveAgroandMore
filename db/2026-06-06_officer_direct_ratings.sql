-- ============================================================
-- Officer direct ratings (visit-independent).
--   A farmer can review a Field Officer they TALKED TO from the
--   "Talk to an Expert" flow (Post-talk Rating screen, advisory-5),
--   without any logged farm visit.
--   One review per (officer, farmer) — re-submitting updates it.
--   The FO's app_users.rating is kept = the average across BOTH
--   visit_ratings and officer_ratings via a unified trigger.
-- Run once in the Supabase SQL editor (project: agroandmorehub.com).
-- Safe to re-run.
-- Requires: public.is_staff() (created by
--   2026-05-31_diaspora_orders_checkout.sql) and the visit_ratings
--   table (created by 2026-05-31_fo_ratings_and_fixes.sql).
-- ============================================================

-- 1) officer_ratings table -------------------------------------------
create table if not exists public.officer_ratings (
  id            uuid primary key default gen_random_uuid(),
  fo_id         uuid not null references public.app_users(id) on delete cascade,
  farmer_phone  text not null,
  stars         integer not null check (stars between 1 and 5),
  comment       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (fo_id, farmer_phone)            -- one review per farmer per officer
);
create index if not exists idx_officer_ratings_fo on public.officer_ratings (fo_id);

alter table public.officer_ratings enable row level security;

-- Farmer may leave a rating tied to their OWN phone number.
drop policy if exists "officer_ratings_insert_farmer" on public.officer_ratings;
create policy "officer_ratings_insert_farmer"
  on public.officer_ratings for insert
  with check (
    farmer_phone in (select phone from public.app_users where auth_user_id = auth.uid())
  );

-- Farmer may update (re-submit) their own review.
drop policy if exists "officer_ratings_update_farmer" on public.officer_ratings;
create policy "officer_ratings_update_farmer"
  on public.officer_ratings for update
  using (
    farmer_phone in (select phone from public.app_users where auth_user_id = auth.uid())
  )
  with check (
    farmer_phone in (select phone from public.app_users where auth_user_id = auth.uid())
  );

-- Read: the FO who was rated, the farmer who left it, or staff.
drop policy if exists "officer_ratings_select" on public.officer_ratings;
create policy "officer_ratings_select"
  on public.officer_ratings for select
  using (
    public.is_staff()
    or fo_id in (select id from public.app_users where auth_user_id = auth.uid())
    or farmer_phone in (select phone from public.app_users where auth_user_id = auth.uid())
  );

-- 2) Unified rating recompute ----------------------------------------
-- app_users.rating = average of stars across visit_ratings + officer_ratings.
create or replace function public.recompute_fo_rating()
returns trigger language plpgsql security definer set search_path = public as $$
declare target uuid := coalesce(new.fo_id, old.fo_id);
begin
  update public.app_users
     set rating = (
       select round(avg(s)::numeric, 1) from (
         select stars as s from public.visit_ratings   where fo_id = target
         union all
         select stars as s from public.officer_ratings where fo_id = target
       ) q
     )
   where id = target;
  return null;
end; $$;

-- Re-bind the visit_ratings trigger to the (now unified) function.
drop trigger if exists trg_recompute_fo_rating on public.visit_ratings;
create trigger trg_recompute_fo_rating
  after insert or update or delete on public.visit_ratings
  for each row execute function public.recompute_fo_rating();

-- Bind the same function to officer_ratings.
drop trigger if exists trg_recompute_fo_rating_officer on public.officer_ratings;
create trigger trg_recompute_fo_rating_officer
  after insert or update or delete on public.officer_ratings
  for each row execute function public.recompute_fo_rating();

-- 3) Backfill existing FO averages so the union takes effect now ------
update public.app_users u
   set rating = (
     select round(avg(s)::numeric, 1) from (
       select stars as s from public.visit_ratings   where fo_id = u.id
       union all
       select stars as s from public.officer_ratings where fo_id = u.id
     ) q
   )
 where u.role = 'field_officer';
