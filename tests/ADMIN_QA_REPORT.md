# Admin Platform — QA Findings Report

**Scope reviewed:** `agroandmorehub.com` (admin platform) including all 15 sidebar sections and 11 Settings sub-tabs. Auth flows (password, MFA), cross-system sync with the mobile PWA, RLS enforcement, error handling, copy.

**Verdict:** The admin platform is **production-ready for a 1-10 admin pilot**, with three caveats worth fixing before broader staff onboarding. Most critical issues from earlier in this session have already been resolved (RLS hardening, analytics-on-real-data, admin invite ID match, MFA, product validation). What remains is cleanup, security-defense-in-depth, and one significant data-integrity gap.

---

## 🔴 Top 3 Critical Issues

### 1. Dashboard / Orders / Notifications pages still have `useDemo` fallbacks that show fake data when DB is empty

**Where:** Multiple functions in `admin.html` — most heavily in `loadDashboard()` (around line 3480), `loadOrders()` (around line 5007), Push Notifications (around line 8951).

**Why it matters:** We removed the "⚠ Illustrative data" pattern from Analytics, but other pages still fall back to demo numbers. An admin glancing at the Dashboard might see "Sales: UGX 12,480,000" when actual sales are zero, and act on it. The pattern is identical to the Analytics bug we just fixed.

**Reproduce:** Open the admin Dashboard on a freshly-seeded DB → KPIs show large numbers that don't match `SELECT SUM(total_ugx) FROM orders`. Open Push Notifications → fake "demo data" rows are listed.

**Fix:** Same approach as Analytics — drop the demo fallbacks, render the real DB state including empty-state messages. Search admin.html for `useDemo`, `_useDemo`, `useOrdersFB`, `useUsersFB`, `useItemsFB`, `demoBanner`, and the various `if (X.length === 0)` fallback patterns; replace each with real-data-or-empty-state.

**Effort:** 2-3 hours. Same edit pattern, applied across ~5 functions.

---

### 2. Service-role key is NOT in admin.html, but the platform leaks admin information via the public `email_exists` RPC

**Where:** Implementing the "block duplicate signup" feature added a `public.email_exists(email text)` function — necessary trade-off, but it lets unauthenticated callers enumerate which emails have accounts.

**Why it matters:** An attacker can iterate through likely Ugandan email addresses and learn which ones have Agro and More accounts. Combined with a leaked password from another breach, this gives them a targeted list to credential-stuff.

**Mitigation options (pick at least one):**

A. **Add per-IP rate limiting** at Supabase. The function is callable via `/rest/v1/rpc/email_exists` — add a Postgres-level rate limit (~10 calls per IP per minute) using `pgaudit` or a simple cache table.

B. **Move the check to a Supabase Edge Function** that requires a recent CAPTCHA token (Cloudflare Turnstile is free). Replaces the client's direct RPC call.

C. **Accept the risk for pilot scale** and revisit before any public marketing push. Document the trade-off clearly.

**Effort:** A) 30 min, B) 2-3 hrs, C) 5 min (write a note).

---

### 3. No audit trail for staff-side data mutations

**Where:** Every admin can edit products, change prices, approve agents, send notifications. There's a UI for an "Audit log" tab in Settings, but the DB has no table actively recording these mutations.

**Why it matters:**
- If a product price gets changed to UGX 1 (mistake or malice), no record of who/when.
- Compliance: AgriBusiness Developers Limited operates under Ugandan tax/finance regs; pricing changes should be traceable.
- Recovery: without audit logs, accidentally archiving 100 products has no easy rollback path.

**Recommended fix:**

1. **Create `audit_log` table:**
   ```sql
   CREATE TABLE audit_log (
     id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
     actor_id     uuid REFERENCES auth.users(id),
     actor_email  text,
     table_name   text NOT NULL,
     record_id    uuid,
     action       text NOT NULL,    -- 'INSERT'/'UPDATE'/'DELETE'
     before_data  jsonb,
     after_data   jsonb,
     created_at   timestamptz NOT NULL DEFAULT now()
   );
   ```

2. **Add Postgres triggers** on critical tables (`products`, `app_users`, `orders`, `settings`, `staff_profiles`) that insert into `audit_log` on every mutation.

3. **Wire the Settings → Audit log tab** to query this table with filters.

**Effort:** 4-6 hours (schema + triggers + UI wiring + testing).

---

## 🟡 Important (fix before scale)

| # | Issue | Where | Fix sketch |
|---|---|---|---|
| 4 | Admin platform has NO session-timeout enforcement — a session JWT can stay valid for hours/days even on shared computers. | Frontend logic | Add a 30-min idle timer that signs the user out automatically; show a "still here?" modal before. |
| 5 | "Forgot password" sends an email with a Supabase recovery link — but the redirect URL is `window.location.origin + '/admin.html'` which still has a hash-fragment vulnerability for crafted URLs. | `index.html` `showForgot` | Whitelist allowed redirect paths server-side via Supabase's auth `additional_redirect_urls` setting. |
| 6 | Admin product image upload accepts arbitrary URLs (anyone can use any hosted image, including externally-hosted malware-flagged content). | Product drawer image field | Either restrict to `agroandmorehub.com` / `supabase.co` storage URLs, or proxy them through Supabase Storage on save. |
| 7 | Analytics CSV export includes column headers but no provenance metadata (when generated, by whom, which filters). | `exportAnalyticsCSV()` | Prepend 2-3 rows: "Generated by: {email}", "Generated at: {iso}", "Month: {label}". |
| 8 | The login page background image URL is fetched from `settings.login_bg_url` and applied directly to CSS without strict validation. | `index.html` line 257-269 | Already validates `^https?://` but no domain whitelist. An attacker who gets settings write access could load tracking pixels or set up phishing. Tighten to specific allowed hosts (your CDN + Supabase Storage). |
| 9 | When an admin invites a member, the `auth.users.user_metadata.role` is set, but there's no guard if a non-MD admin tries to invite an MD (we check this client-side only). | `saveInviteMember` | Add a DB-level constraint or Postgres trigger that blocks MD role assignment unless the actor is itself an MD. |
| 10 | Settings → SMS provider tab is a stub; saving credentials there doesn't actually trigger SMS via the provider. | Whole tab | Either wire up Africa's Talking integration, or hide the tab with a "Coming soon" badge. |
| 11 | Push Notifications schedule field accepts any future date but doesn't show a count of how many users will receive it — admins may send to thousands by accident. | Push notification compose form | Add a "Audience: ~N farmers will receive this" line before the Send button, derived from a quick `app_users` count query. |
| 12 | The Knowledge Base in Settings has full CRUD but no preview of how the article renders in AgroBot's reply. | KB drawer | Add an "Preview as AgroBot answer" toggle so authors see the farmer's view. |

## 🟢 Polish

| # | Issue |
|---|---|
| 13 | Sidebar collapse state isn't persisted across reloads. |
| 14 | Some toasts use `'error'` type while others use `'destructive'` — inconsistent severity. |
| 15 | No keyboard shortcuts (Cmd/Ctrl+K for search, Esc to close drawers, etc.). |
| 16 | Order detail drawer doesn't show order number in the URL — can't deep-link to a specific order for support. |
| 17 | Diaspora Orders shows everything in UGX even though those orders were paid in USD — should show both with FX rate. |
| 18 | "AI Chatbot" admin page name should be "AgroBot Logs" or similar — clearer for non-technical staff. |
| 19 | No bulk-export of `bot_conversations` for offline analysis. |
| 20 | The "DEMO" badge on Dashboard KPIs (when in fallback mode) is barely visible — easy to miss. |

---

## How to use this report

1. **Right now:** Address issues 1, 2, 3 — they have the highest blast radius if they go wrong in production. Especially #1 since it's the same fix pattern we already proved works on Analytics.
2. **Before 10+ admin users onboarded:** Work through 4–12. These are baseline hygiene for a multi-staff system.
3. **Before going public-facing (KYC, regulator scrutiny):** Items 13–20 plus a formal pen-test by a third party.

---

## What I tested + how

- **All 15 sidebar pages** loaded under `adminSignIn()` — no JS errors on initial load.
- **Auth flows**: password login, wrong password, empty form, forgot password, session persistence, logout. MFA enrollment + login challenge + disable (specs gated on `speakeasy` lib install).
- **Products CRUD** end-to-end with cross-system mobile visibility check.
- **Settings sub-tabs** smoke-tested for crashes; deep behavior tested for Commission rate, Knowledge Base, Password & security.
- **Cross-system**: admin add product → mobile shop visible; admin invite → mobile farmer sign-in.
- **RLS**: confirmed in `tests/mobile/07-edge-cases.spec.ts` (attacker auth user can't UPDATE/DELETE other rows).

Manual checks covered in `ADMIN_MANUAL_CHECKLIST.md`.

## What I did NOT test

- **Actual payment provider integrations** (MTN/Airtel) — no sandbox credentials in this environment.
- **Push notification delivery** to physical Android devices via Firebase.
- **Odoo connection** — requires a live Odoo instance.
- **Image upload to Supabase Storage** — UI accepts URLs only; no file picker tested.
- **Data export schedule** firing — requires waiting for scheduled time.
- **Audit log** — depends on the unbuilt audit-log table (issue #3).
- **Browser compat on IE11 / very old Android browsers** — not in scope; Agro and More targets modern Chrome.
