-- ============================================================
-- Field Officer fixes:
--   1) fo_languages was text but the app saves an array -> make it text[]
--   2) visit_ratings: farmers rate a farm visit; FO/staff read; the FO's
--      app_users.rating is kept up to date by a trigger.
-- Run once in the Supabase SQL editor (project: agroandmorehub.com).
-- Safe to re-run.
-- ============================================================

-- 1) fo_languages -> text[] (preserve any existing comma text) --------
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name='app_users' and column_name='fo_languages' and data_type='text'
  ) then
    alter table public.app_users
      alter column fo_languages type text[]
      using (case when fo_languages is null or fo_languages='' then null
                  else string_to_array(fo_languages, ',') end);
  end if;
end $$;

-- 2) visit_ratings ---------------------------------------------------
create table if not exists public.visit_ratings (
  id            uuid primary key default gen_random_uuid(),
  visit_id      uuid not null references public.farm_visits(id) on delete cascade,
  fo_id         uuid not null references public.app_users(id),
  farmer_phone  text,
  stars         integer not null check (stars between 1 and 5),
  comment       text,
  created_at    timestamptz not null default now(),
  unique (visit_id)                       -- one rating per visit
);
create index if not exists idx_visit_ratings_fo on public.visit_ratings (fo_id);

alter table public.visit_ratings enable row level security;

-- Farmer can leave a rating for a visit logged against their own phone.
drop policy if exists "visit_ratings_insert_farmer" on public.visit_ratings;
create policy "visit_ratings_insert_farmer"
  on public.visit_ratings for insert
  with check (
    exists (
      select 1 from public.farm_visits v
      join public.app_users u on u.auth_user_id = auth.uid()
      where v.id = visit_id and v.farmer_phone = u.phone
    )
  );

-- Read: the FO who owns the visit, the farmer who left it, or staff.
drop policy if exists "visit_ratings_select" on public.visit_ratings;
create policy "visit_ratings_select"
  on public.visit_ratings for select
  using (
    public.is_staff()
    or fo_id in (select id from public.app_users where auth_user_id = auth.uid())
    or farmer_phone in (select phone from public.app_users where auth_user_id = auth.uid())
  );

-- 3) Keep app_users.rating = average of the FO's visit ratings --------
create or replace function public.recompute_fo_rating()
returns trigger language plpgsql security definer set search_path = public as $$
declare target uuid := coalesce(new.fo_id, old.fo_id);
begin
  update public.app_users
     set rating = (select round(avg(stars)::numeric, 1) from public.visit_ratings where fo_id = target)
   where id = target;
  return null;
end; $$;

drop trigger if exists trg_recompute_fo_rating on public.visit_ratings;
create trigger trg_recompute_fo_rating
  after insert or update or delete on public.visit_ratings
  for each row execute function public.recompute_fo_rating();

-- NOTE: public.is_staff() is created by 2026-05-31_diaspora_orders_checkout.sql.
-- If you run this file first, create it with:
--   create or replace function public.is_staff() returns boolean
--   language sql stable security definer set search_path = public as
--   $f$ select exists (select 1 from staff_profiles where id = auth.uid()); $f$;
