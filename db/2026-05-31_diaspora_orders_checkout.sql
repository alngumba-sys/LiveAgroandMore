-- ============================================================
-- Diaspora checkout support: gift message, refund requests, and
-- proper per-sender row-level security on diaspora_orders / _items.
-- Run once in the Supabase SQL editor (project: agroandmorehub.com).
-- Safe to re-run.
-- ============================================================

-- 1) New columns -------------------------------------------------
alter table public.diaspora_orders add column if not exists message              text;
alter table public.diaspora_orders add column if not exists refund_requested     boolean not null default false;
alter table public.diaspora_orders add column if not exists refund_reason        text;
alter table public.diaspora_orders add column if not exists refund_requested_at  timestamptz;

-- 2) Helper: is the caller a staff member? -----------------------
-- staff_profiles.id == auth.uid() for admin-portal users.
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from staff_profiles where id = auth.uid());
$$;

-- 3) diaspora_orders RLS ----------------------------------------
alter table public.diaspora_orders enable row level security;

-- Remove the over-broad "any authenticated user" policies from schema.sql
drop policy if exists "staff_read_all" on public.diaspora_orders;
drop policy if exists "staff_write"    on public.diaspora_orders;
drop policy if exists "diaspora_orders_select" on public.diaspora_orders;
drop policy if exists "diaspora_orders_insert" on public.diaspora_orders;
drop policy if exists "diaspora_orders_update" on public.diaspora_orders;

-- Sender sees only their own orders; staff see all.
create policy "diaspora_orders_select"
  on public.diaspora_orders for select
  using (payer_email = auth.email() or public.is_staff());

-- Sender can create an order for themselves; staff can too.
create policy "diaspora_orders_insert"
  on public.diaspora_orders for insert
  with check (payer_email = auth.email() or public.is_staff());

-- Sender can update their own (e.g. request a refund); staff can update any.
create policy "diaspora_orders_update"
  on public.diaspora_orders for update
  using (payer_email = auth.email() or public.is_staff())
  with check (payer_email = auth.email() or public.is_staff());

-- 4) diaspora_order_items RLS -----------------------------------
alter table public.diaspora_order_items enable row level security;

drop policy if exists "staff_read_all"  on public.diaspora_order_items;
drop policy if exists "staff_write"     on public.diaspora_order_items;
drop policy if exists "diaspora_order_items_select" on public.diaspora_order_items;
drop policy if exists "diaspora_order_items_insert" on public.diaspora_order_items;

create policy "diaspora_order_items_select"
  on public.diaspora_order_items for select
  using (
    public.is_staff()
    or exists (select 1 from public.diaspora_orders o
               where o.id = diaspora_order_id and o.payer_email = auth.email())
  );

create policy "diaspora_order_items_insert"
  on public.diaspora_order_items for insert
  with check (
    public.is_staff()
    or exists (select 1 from public.diaspora_orders o
               where o.id = diaspora_order_id and o.payer_email = auth.email())
  );
