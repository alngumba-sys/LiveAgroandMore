# Agent Role — End-to-End Audit (report only)

**Date:** 2026-05-30
**Scope:** Agent role only (Field Officer & Diaspora untouched). No production code changed, nothing deployed.
**Method:** Code read of `app.html` (agent-facing app) + `Platform/admin.html` (MD/Admin), live Supabase inspection via REST (project `nqyutflqzjjueemirgzr`), and an empirical end-to-end test using a labelled demo agent (`zztest.agent.audit@example.com`) signed in with a real JWT to exercise RLS. **All demo data was deleted afterwards** — agent count is back to the original 3, no `ZZTEST` rows remain.

---

## TL;DR — what's actually breaking the Agent role

Two root causes explain almost everything you're seeing:

1. **`app_users` INSERT is dead for any logged-in user** — a recursive RLS policy throws `42P17 infinite recursion`. This silently breaks (a) new agent self-signup persistence and (b) an agent registering a farmer. *(Verified live.)*
2. **Orders never carry `agent_id` (or the farmer's identity).** The checkout writes the *agent* as the customer and leaves `agent_id` NULL, so every commission, customer count, leaderboard and payout — in both the app and admin — computes to **zero**. *(Verified live: the one real order has an agent as `customer_name` and `agent_id = null`.)*

Everything an agent "does" downstream (customers, commission, leaderboard, MD's commission report) hangs off those two facts.

---

## Live data snapshot (evidence)

- 3 agents, all `status=active`, `verified=true`; **all have `agent_code=null` and `commission_rate=null`**.
- `referral_agent_id` is **null on every row in the table** — i.e. **no agent has ever successfully registered a farmer**, despite the flow being wired.
- Only 1 order exists: `AM-2026-05-00001`, `customer_name="Odoobo Calvin"` (who is an agent), **`agent_id=null`**.
- RLS probe as an authenticated agent (anon key + real JWT):
  - SELECT `app_users` → **works**, returns all 12 rows (see Major #4 — over-broad read).
  - INSERT `app_users` (own row) → **`42P17 infinite recursion`**.
  - UPDATE own `app_users` row → **works**.
  - INSERT `orders` with `agent_id` set → **allowed by RLS** (only failed on a missing `customer_phone` NOT-NULL, not on policy). Confirms the attribution fix is viable without an RLS change.

---

## BLOCKERS

### B1 — Recursive RLS policy on `app_users` kills all authenticated INSERTs
- **Stage:** 1 (signup) & 3 (agent registers farmer)
- **Location:** Database — RLS policy on `public.app_users` (the `app_users_staff_all` FOR ALL policy referenced as "left unchanged" in `db/2026-05-29_fix_own_row_rls.sql:36`; its definition is not in the `db/` folder, so it was created in the dashboard or an earlier migration).
- **Broken:** Any `INSERT` into `app_users` by a logged-in (non-service) user returns `42P17 infinite recursion detected in policy for relation "app_users"`.
- **Observed vs expected:** Expected a new agent's profile row to be written on first sign-in (`saveProfile`), and an agent-registered farmer to insert. Observed: insert rejected at the DB; app swallows it (`saveProfile` only `console.warn`s) and falls back to an in-memory profile.
- **Root cause:** The staff/admin policy's `USING`/`WITH CHECK` subqueries `app_users` itself (classic pattern: `EXISTS (SELECT 1 FROM app_users WHERE id = auth.uid() AND role IN ('md','it_admin'))`). Evaluating that subquery re-triggers RLS on `app_users` → infinite recursion. It surfaces on INSERT specifically (SELECT/own-UPDATE pass via the permissive own-row policies first).
- **Proposed fix:** Replace the self-referential subquery with a `SECURITY DEFINER` helper that does not re-enter RLS — the codebase **already has this pattern**: `current_staff_role()` is used in `db/2026-05-29_rls_fixes.sql:16`. Rewrite the `app_users` staff policy to use `current_staff_role() IN ('md','it_admin', …)` (or check `staff_profiles`, which is a different table and won't recurse). Then re-test the four operations above.
- **Confirm first:** `SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename='app_users';` — I could not read this live (Supabase management MCP returns 403, and PostgREST doesn't expose `pg_catalog`). The fix should be written against the actual policy text.

### B2 — Orders are never attributed to the agent (or the farmer)
- **Stage:** 3 (actions) & 4/5 (visibility)
- **Location:** `app.html` lines **12364–12374** (the single shared checkout `placeOrder`).
- **Broken:** The insert sets `customer_id = profile.id`, `customer_name = profile.full_name` (the **agent's** identity) and **never sets `agent_id`**, and **never reads `window.__amOrderFarmer`** (the farmer the agent picked).
- **Observed vs expected:** Expected an agent's order to record the farmer as customer and the agent in `agent_id`. Observed (live): order shows the agent as the customer, `agent_id=null`.
- **Downstream impact (all verified by code path):**
  - `foFetchOrders` (`app.html:16527-16534`) filters `orders.agent_id == profile.id` → always empty → agent **Commission** (`renderAgentCommission`), **Customers** stats (`renderAgentCustomers`), **Leaderboard** and **Payouts** screens all show 0.
  - Admin `getAgentSales` (`admin.html:11002`) filters `o.agent_id === agentId`; `loadAgents` (`admin.html:10933-10937`) pulls orders to compute each agent's sales → **MD's commission report, leaderboard and per-agent sales are all 0** for every agent.
  - Admin order list "via agent {name}" (`admin.html:5717`) never renders because there's no agent attribution.
- **Root cause:** The agent shop reuses the generic farmer checkout, which has no concept of "ordering on behalf of." The "Ordering for {farmer}" banner (`app.html:17332`) is cosmetic — it sets `__amOrderFarmer` but the checkout ignores it.
- **Proposed fix:** In the checkout, when `window.__amOrderFarmer` is set and `profile.role === 'agent'`, write `agent_id = <agent's app_users id>`, `customer_id = farmer.id`, `customer_name = farmer.full_name`, `customer_phone = farmer.phone`. RLS already permits this (verified). Decision needed on walk-in orders (no farmer selected) — see Decisions.

### B3 — Agent-registered farmer insert is invalid even without the recursion
- **Stage:** 3 (actions)
- **Location:** `app.html` lines **17283-17290** (farmer registration in the "Order for a farmer" flow).
- **Broken:** The new farmer row is inserted with `auth_user_id = <random UUID>`. The own-row INSERT policy (`db/2026-05-29_fix_own_row_rls.sql:22`) requires `auth.uid() = auth_user_id`. A random UUID ≠ the agent's `auth.uid()`, so even after B1 is fixed this insert will be **rejected by RLS**.
- **Observed vs expected:** Expected the farmer to be saved and tagged to the agent. Observed: 0 farmers in the DB have `referral_agent_id` set.
- **Root cause:** `app_users.auth_user_id` is NOT NULL with no FK; the code invents a UUID to satisfy NOT-NULL, but that breaks the RLS check. Agents aren't staff, so no staff policy covers them either.
- **Proposed fix (needs a decision):** allow agents to create farmer rows. Options: (a) an RLS policy permitting an `agent`-role user to INSERT rows where `role='farmer'` AND `referral_agent_id = <their app_users id>` (via a `SECURITY DEFINER` helper that resolves the caller's agent row id); or (b) route agent-created farmers through a `SECURITY DEFINER` RPC. Either way, `auth_user_id` for a login-less farmer should be handled deliberately (nullable, or a sentinel) rather than a random UUID that fails the own-row check.

---

## MAJOR

### M1 — `agent_code` is never generated
- **Stage:** 1 (signup) & 5 (admin)
- **Location:** `saveProfile` (`app.html:13597-13604`) writes no `agent_code`; admin `approveAgent` (`admin.html:11305`) sets only `verified+status`. Admin renders `agent_code || '—'` (`admin.html:11481`, `11503`).
- **Broken/observed:** All 3 agents have `agent_code=null`; admin always shows "—". No referral-by-code mechanism exists.
- **Fix:** Generate a unique `agent_code` on approval (or signup), e.g. `AG-XXXX`. Decide the format/uniqueness rule (see Decisions).

### M2 — `commission_rate` never stored; effective rate is display-only
- **Stage:** 3/5
- **Location:** App falls back to `5` for display (`app.html:16556`, `16586`); admin falls back to global rate or `5` (`admin.html:11222`, `11258`). Stored value is null for all agents.
- **Impact:** Cosmetically fine today, but per-agent overrides set in admin (`admin.html:7190`) write `commission_rate` — and any payout actually computed from the stored value would be null. Once B2 is fixed and real money is computed, the null-vs-global behaviour must be deliberate.
- **Fix:** On approval, persist the effective `commission_rate` (or clearly treat null = "use global" everywhere, consistently).

### M3 — Any logged-in user can read the entire `app_users` table
- **Stage:** 4 (data scoping) — privacy/leak
- **Location:** `app_users` SELECT policy is `auth.uid() IS NOT NULL` (noted in `db/2026-05-29_fix_own_row_rls.sql:35-36`). Verified live: the test agent read all 12 rows.
- **Broken:** An agent (or any farmer/FO) can read every other user's row — names, phones, **national_id/NIN, bank account numbers, payout phones**. The app's own `renderAgentCustomers` relies on this broad read rather than a scoped policy.
- **Fix (needs decision):** Tighten the SELECT policy to own rows + rows the user is entitled to (e.g. farmers where `referral_agent_id = caller's agent id`, resolved via a `SECURITY DEFINER` helper), and let staff read all via the (de-recursed) staff policy. Note this is the same helper needed for B1/B3.

### M4 — `loadOrderForCustomers` vs `renderAgentCustomers` use inconsistent filters
- **Stage:** 4
- **Location:** `app.html:17139` filters `.eq('referral_agent_id', id).eq('status','active')`; `app.html:16583` filters only `.eq('referral_agent_id', id)`.
- **Impact:** Minor today (registered farmers are `active`), but the two "my customers" surfaces can diverge. Align them after B3 is fixed.

---

## MINOR / NOTES

- **N1 — Silent failure UX.** `saveProfile` only `console.warn`s on error (`app.html:13637`), so B1/B3 fail invisibly — the user sees "under review" with no row written. Surfacing insert errors to the user (or to a logger) would have caught these. (Stage 1/3.)
- **N2 — Stat counters unused.** `app_users.farmers_helped` / `visits` exist and are 0 for all agents; nothing increments them. Decide whether to drive these from real data or drop them. (Stage 5.)
- **N3 — Signup extras inconsistent across existing agents.** George One has bank/outlet/years populated; Odoobo and Kate have them all null. The self-signup form *requires* bank details (`app.html:14546-14555`), so the null rows were likely admin-created or pre-date those fields — a data artifact, not a code bug. Worth confirming how Odoobo/Kate were created.
- **N4 — Mobile-money payout phone never captured for the 3 live agents** (`commission_payout_phone` null on all). Tied to N3.

---

## What WORKS (validated, don't touch)

- `checkSession` correctly keys on `auth_user_id` (`app.html:14799`) — the post-multi-role lookup is right.
- Routing/gating: pending agents → `agent-flows-1` waiting room, active → `agent-1` home, with safety-net redirects (`app.html:10284`, `goHome` `13563`). Stage 2 is solid.
- Authenticated **SELECT** on `app_users`, **UPDATE** of own row, and **orders INSERT with `agent_id`** all pass RLS (verified live). So the attribution fix (B2) needs no orders-RLS change.
- Agent bottom nav and screen wiring are intact (`app.html:8082`, `8088`).

---

## Needs a DB / schema change
1. **B1:** Rewrite the recursive `app_users` staff RLS policy using `current_staff_role()` (or `staff_profiles`) — `SECURITY DEFINER`, no self-reference. *(Confirm exact policy text first.)*
2. **B3:** New RLS policy (or RPC) letting an `agent` create `farmer` rows tagged with their `referral_agent_id`; decide `auth_user_id` handling for login-less farmers.
3. **M3:** Tighten `app_users` SELECT policy from "any logged-in user" to scoped reads.
4. **M1/M2:** Decide whether `agent_code` / `commission_rate` get persisted columns/triggers on approval (columns already exist).

## Needs a decision from you
1. **Walk-in orders:** when an agent checks out with **no** farmer selected, should `agent_id` still be set (agent gets commission) with `customer_name='Walk-in'`? Or block checkout until a farmer is chosen?
2. **`agent_code` format & when assigned** (on signup vs on approval); is it used for any public referral link?
3. **`commission_rate` semantics:** store effective rate on the agent, or keep null = "inherit global" everywhere?
4. **Farmer privacy (M3):** confirm an agent should see *only* their own referred farmers (recommended) vs the current "all users".
5. **Login-less farmers:** confirm agent-registered farmers never get an auth login (affects `auth_user_id` design in B3).

---

*No code was modified and nothing was deployed. Awaiting your go-ahead on fixes — recommend tackling B1 → B2 → B3 first, since the rest depends on them.*
