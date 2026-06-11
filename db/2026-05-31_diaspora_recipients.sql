-- ============================================================
-- Diaspora recipients — saved "people in Uganda you can send to"
-- Run once in the Supabase SQL editor (project: agroandmorehub.com).
-- Safe to re-run: guarded with IF NOT EXISTS / DROP POLICY IF EXISTS.
-- ============================================================

create table if not exists public.diaspora_recipients (
  id            uuid primary key default gen_random_uuid(),
  owner_email   text not null,                 -- the diaspora sender (auth email)
  name          text not null,
  relationship  text,
  phone         text not null,
  district      text,
  subcounty     text,
  village       text,
  outlet        text,                          -- nearest Agro & More pickup outlet
  is_default    boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_diaspora_recipients_owner
  on public.diaspora_recipients (owner_email);

-- Keep updated_at fresh on edits.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists trg_diaspora_recipients_updated on public.diaspora_recipients;
create trigger trg_diaspora_recipients_updated
  before update on public.diaspora_recipients
  for each row execute function public.set_updated_at();

-- ── Row Level Security: a user only ever sees/edits their own rows ──
alter table public.diaspora_recipients enable row level security;

drop policy if exists "diaspora_recipients_select_own" on public.diaspora_recipients;
create policy "diaspora_recipients_select_own"
  on public.diaspora_recipients for select
  using (owner_email = auth.email());

drop policy if exists "diaspora_recipients_insert_own" on public.diaspora_recipients;
create policy "diaspora_recipients_insert_own"
  on public.diaspora_recipients for insert
  with check (owner_email = auth.email());

drop policy if exists "diaspora_recipients_update_own" on public.diaspora_recipients;
create policy "diaspora_recipients_update_own"
  on public.diaspora_recipients for update
  using (owner_email = auth.email())
  with check (owner_email = auth.email());

drop policy if exists "diaspora_recipients_delete_own" on public.diaspora_recipients;
create policy "diaspora_recipients_delete_own"
  on public.diaspora_recipients for delete
  using (owner_email = auth.email());
