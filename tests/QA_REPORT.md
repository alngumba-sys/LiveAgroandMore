# Agro and More — QA Findings Report

**Scope reviewed:** mobile PWA (`agro-more-app.netlify.app/app.html`), admin platform (`agroandmorehub.com/admin.html`), Supabase backend (project `nqyutflqzjjueemirgzr`), Resend email infrastructure.

**Verdict:** The platform is in a **launchable-with-monitoring state** for a pilot rollout. The biggest production-blocker issues — email delivery, OTP wiring, signup flow, profile data persistence, shop visibility — have all been resolved in the past 24 hours. What remains is mostly hardening, edge-case polish, and one substantial security concern that should be addressed *before* expanding beyond a pilot.

---

## 🔴 Top 3 Critical Issues (fix before broader launch)

### 1. RLS policies allow any authenticated user to UPDATE/DELETE any other user's row

**Where:** `Platform/db/schema.sql` — `staff_write` policy on `app_users`:
```sql
CREATE POLICY "staff_write" ON app_users FOR ALL USING (auth.uid() IS NOT NULL);
```

**Why it matters:** Any farmer with a valid session can run `sb.from('app_users').update({ full_name: 'PWNED' }).eq('id', otherFarmerId)` from their browser console and it succeeds. Equivalent risk on DELETE. This means a malicious user could mass-delete or vandalise other farmers' profiles.

**Reproduction:** included in `tests/mobile/07-edge-cases.spec.ts` → `RLS: authenticated user cannot UPDATE another user's row`. **The test currently fails** — that's the demonstration of the bug.

**Recommended fix (SQL):**
```sql
DROP POLICY "staff_write" ON app_users;

-- 1. Authenticated users can SELECT all (needed for staff dashboards, agent commission, etc.)
CREATE POLICY "app_users_select_all" ON app_users FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- 2. Users can ONLY update their own row
CREATE POLICY "app_users_update_own" ON app_users FOR UPDATE
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 3. Users can INSERT only with their own id (covers saveProfile signup path)
CREATE POLICY "app_users_insert_own" ON app_users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- 4. Staff roles can do anything (so the admin platform still works)
CREATE POLICY "app_users_staff_all" ON app_users FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM app_users me
      WHERE me.id = auth.uid()
        AND me.role IN ('md', 'it_admin', 'sales_manager')
    )
  );

-- 5. NO blanket DELETE for regular users.
```

**Effort:** 15 minutes (apply migration, redeploy admin, re-run failing test to confirm green).

---

### 2. Admin invite flow creates `app_users` rows with random UUIDs that won't match `auth.users.id`

**Where:** `Platform/admin.html` → `saveInviteMember()`.

**Why it matters:** When an admin invites a farmer, the row is inserted with `id = gen_random_uuid()` because the auth user doesn't exist yet. When that farmer later signs in, the verifyOtp flow creates a new `auth.users` entry with a *different* UUID. Mobile's `app.html` then does:

```javascript
sb.from('app_users').select(...).eq('id', authUser.id)   // not found
```

…misses, then falls back to email-match, then has to either *relink* the id (current behaviour — risky if other tables reference the old id) or *overwrite* the row. Either way it's a workaround for a flow that should never produce orphans in the first place.

**Recommended fix:** Either
- **Option A** (less work): Add a `pending_invite_email` column on `app_users` with a UNIQUE index, drop the random-uuid id for invites, and reconcile on first sign-in.
- **Option B** (cleanest): The admin invite should use the Supabase Admin API to **create the auth.users entry first** via `sb.auth.admin.createUser({ email, email_confirm: false })`. That returns the real id, which the admin then uses for the `app_users.id`. Requires the admin platform to call a server function (Edge Function or similar) that holds the service role key — don't put the service key in browser JS.

**Effort:** 1–3 hours depending on Option A vs B.

---

### 3. Service-worker cache strategy still produces stale states on update

**Where:** `service-worker.js`. The current strategy is network-first for HTML/navigations, cache-first for everything else.

**Why it matters:** When you ship a new `app.html`, returning users get the new HTML on next load — but the **service worker itself** is cached until the user explicitly closes all tabs and reopens. Users who keep the PWA open for days may run stale JS even though the HTML they fetched is fresh.

**Real-world signal:** During this session you saw the exact failure mode — fixes were deployed, the live HTML had them, but the user was still seeing the pre-fix UI because the service-worker had cached the OLD app.html. We fixed it by bumping `CACHE_VERSION`. We need a permanent guard.

**Recommended fix:**

```javascript
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    Promise.all([
      caches.keys().then(keys =>
        Promise.all(keys.filter(k => k !== CACHE_VERSION).map(k => caches.delete(k)))
      ),
      self.clients.claim(),
      // Force-reload every open client window so stale JS doesn't keep running
      self.clients.matchAll({ type: 'window' }).then(clients =>
        clients.forEach(c => c.navigate(c.url))
      ),
    ])
  );
});
```

This forces any open PWA window to reload itself when a new SW activates — the user doesn't have to know about hard-refresh.

Additionally, **add a build-time version stamp** to `CACHE_VERSION` (e.g. derived from a timestamp or git SHA via a tiny build step) so every deploy automatically triggers re-activation.

**Effort:** 1 hour including testing the auto-reload flow.

---

## 🟡 Important (fix soon)

| # | Issue | Where | Fix sketch |
|---|---|---|---|
| 4 | Phone-number validation accepts non-Ugandan formats and lets through invalid lengths | `app.html` → wireSignup phone handling | Add regex `^[7][0-9]{8}$` (Uganda mobile starts with 7) and explicit length check before submit |
| 5 | Invited users get placeholder phone like `inv-xxxx` which would never match real-world SMS lookups | `admin.html` → saveInviteMember | Make phone optional schema-wise, or prompt admin to enter the farmer's real phone in the invite form |
| 6 | Schema is missing columns the admin tried to insert (`invited_at`, `invited_by`, `outlet_id`, `pending_invite` status enum) | DB migrations | Apply the schema migration we drafted earlier so admin can record invitation provenance |
| 7 | AgroBot returns the *first* matching article, not the *best ranked*. For short questions this is fine; for ambiguous ones it can confidently return a wrong article. | `app.html` → wireAgroBot | Either upgrade to a tiny LLM (Claude Haiku ~$0.0008/chat) or surface the top 3 matches and let the user pick |
| 8 | `bot_conversations` logs both the rated and unrated entries — duplicates if user clicks 👍 (we insert twice) | `app.html` → wireAgroBot | Replace pre-log with `upsert`, or stash the inserted id and `update()` on rating |
| 9 | The "Open WhatsApp" relabel on advisory-7 (from earlier deploy) replaces the original SVG icon's neighbour text. If the SVG was the FIRST child node, the relabel can miss. | `wireAgroBot` final block | Use a wrapper `<span class="wa-label">` instead of mutating text nodes |
| 10 | The mock products with hardcoded prices in `app.html` (lines 2698–2768) — Mancozeb, Rocket, Round-up etc — render briefly before the real fetch overrides them. Same flash pattern as before. | shop-2 markup | Remove or hide the static product rows on screen render; rely on JS-injected ones |
| 11 | Cart screen ignores delivery method selection programmatically — the radio buttons are pure visual mockup, no JS picks one | shop-3 cart wiring | Wire the cards to actually set a selectedDelivery state used by checkout |
| 12 | No password-recovery flow on the admin platform — admins sign in solely via OTP. If their email is compromised, account takeover is single-factor. | Platform auth | Add a separate OTP-via-SMS path for admins, OR require admins to enable Supabase MFA |
| 13 | The `?mode=app` URL param is the only way to enter app mode. If a farmer types `agro-more-app.netlify.app` without the param, they see the design-preview mockup (all screens scrolled). | `index.html` | Add a server-side redirect (Netlify `_redirects`) from `/` to `/app.html?mode=app` |

---

## 🟢 Nice-to-have / polish

| # | Issue |
|---|---|
| 14 | Admin "Add Product" form doesn't validate that price ≥ stock floor or that SKU is unique before submit — relies on DB constraint errors |
| 15 | "Talk to a Field Officer" button on AgroBot opens WhatsApp web on desktop, but the message format is the same as mobile — could detect and tailor |
| 16 | Bottom-nav active state doesn't always match the current screen (e.g., on cart, the "Shop" tab isn't highlighted). The `data-role` attribute and class-applying happens at boot only |
| 17 | No analytics — you have no idea how farmers use the app post-launch. Add Plausible or Umami (privacy-first, free) |
| 18 | No error tracking — when something crashes in production you won't know. Add Sentry (free tier covers this scale) |
| 19 | Service worker doesn't pre-cache the `brand/` assets even though they're in SHELL — Netlify's cache headers may already cover this |
| 20 | The "Talk on WhatsApp" message doesn't include the article that the bot returned, so the FO has to start from scratch. Bundle the bot's last answer into the escalation message |

---

## How to use this report

1. **This week:** address issues 1, 2, 3 (the red list). They are the only ones that can cause data loss, security incidents, or a confusing user-facing breakage in production.
2. **Before pilot expands beyond 50 users:** work through issues 4–13.
3. **Before launching publicly:** address all yellow + polish items.
4. **Re-run the test suite after every fix:** `cd tests && npm test`. Add a regression test for any issue you fix — that's how the suite stays useful.

---

## What I tested + how

- **Mobile flows (PWA):** signup, signin, signout, shop browse, cart, AgroBot chat, profile populate, bottom-nav routing. Drove the real UI via Playwright in a Pixel 7-sized viewport.
- **Edge cases:** XSS, SQL injection, very-long names, rate-limit handling, RLS abuse, stale SW cache.
- **Admin flows:** Add Product → mobile visibility, Invite Member → farmer can sign in. Cross-system tests opening two browser contexts.
- **Manual checks:** see `MANUAL_CHECKLIST.md`.

OTP testing uses the Supabase admin API to retrieve codes without sending real emails (no inbox-polling flakiness, no Resend rate-limit issues). Cleanup runs after every test via service-role key.

## What I did NOT test

- Real payment flows (MTN MoMo / Airtel) — no sandbox credentials available; tests stub at the "Proceed to Pay" step.
- Push notifications — the Notifications admin page exists but no FCM/APNs integration is wired up.
- Native APK behaviour — the project is a PWA. If you wrap it via PWABuilder, retest the TWA Trusted Web Activity bridge separately.
- Multi-language (Luganda translation) — currently the KB is English-only and the UI strings are English with a few Luganda greetings.
- Image upload / storage flows — admin Product Images section uses URLs only, no `<input type=file>` testing was done.
