-- Migration: create_weather_alerts
-- Run in Supabase → SQL Editor

create table if not exists public.weather_alerts (
  id          uuid        primary key default gen_random_uuid(),
  region      text        not null
                          check (region in ('national','central','eastern','northern','western')),
  severity    text        not null
                          check (severity in ('info','warning','danger')),
  headline    text        not null,
  message     text,
  valid_from  date,
  valid_until date,
  active      boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz
);

alter table public.weather_alerts enable row level security;

-- Staff (admins) can do everything
create policy "Staff manage weather_alerts"
  on public.weather_alerts
  for all
  using (
    exists (
      select 1 from public.staff_profiles
      where id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.staff_profiles
      where id = auth.uid()
    )
  );

-- Authenticated app users can read active alerts
create policy "Active alerts readable by authenticated users"
  on public.weather_alerts
  for select
  using (active = true and auth.role() = 'authenticated');
