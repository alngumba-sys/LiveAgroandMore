# Agro and More — QA Test Suite

Playwright tests for the mobile PWA (`agro-more-app.netlify.app`) AND the admin platform (`agroandmorehub.com`) — every sidebar page + every Settings sub-tab.

## What's tested

| File | Coverage |
|---|---|
| `mobile/01-onboarding.spec.ts` | Splash → intro → role selection navigation |
| `mobile/02-signup-farmer.spec.ts` | Full farmer signup, validation, OTP, signup-overwrite-existing-email |
| `mobile/03-signin-signout.spec.ts` | Returning user log-in, sign-out lands on intro |
| `mobile/04-shop-browsing.spec.ts` | Category counts, list, loading state, race-protection token |
| `mobile/05-agrobot.spec.ts` | KB chat: suggestions, custom Q, fallback, thumbs-up logged |
| `mobile/06-profile-and-nav.spec.ts` | Profile data populated, bottom-nav routes to each tab |
| `mobile/07-edge-cases.spec.ts` | XSS, SQL injection, rate limit, RLS abuse attempt, SW version |
| `admin/00-auth.spec.ts` | Login, wrong password, empty form, forgot password, session persistence, logout |
| `admin/01-mfa.spec.ts` | TOTP enrollment + login challenge + disable (needs `npm i -D speakeasy`) |
| `admin/02-dashboard.spec.ts` | Dashboard KPIs render, sidebar nav loads every page without crashes |
| `admin/03-products.spec.ts` | Add/edit/archive product with full client-side validation |
| `admin/04-orders.spec.ts` | Orders + Diaspora Orders load without errors |
| `admin/05-analytics.spec.ts` | Analytics page: no demo banner, KPIs visible, month picker, CSV/PDF export |
| `admin/06-settings.spec.ts` | All 11 Settings sub-tabs load, password change validation |
| `admin/07-agents.spec.ts` | Agents leaderboard + tab switching |
| `admin/08-field-officers.spec.ts` | Field officers page loads |
| `admin/09-advisory-content.spec.ts` | Advisory content page loads |
| `admin/10-ai-chatbot.spec.ts` | AgroBot conversation logs page |
| `admin/11-push-notifications.spec.ts` | Push notifications page |
| `admin/12-finance.spec.ts` | Finance / Odoo page |
| `admin/13-users-roles.spec.ts` | Users list (all roles) |
| `admin/14-traceability.spec.ts` | Traceability batches |
| `admin/15-produce-prices.spec.ts` | Produce prices |
| `admin/16-for-hire.spec.ts` | For-hire providers |
| `admin/old: 01-add-product.spec.ts` | (was renumbered to 03-products.spec.ts) |

## Admin test account setup

The admin specs need a dedicated test admin in Supabase. `helpers/admin-auth.ts → ensureAdminAccount()` creates this idempotently on the first run, using the service role key. Default email is `qa-admin@example.com`. You can override the password by setting `ADMIN_TEST_PASSWORD` in `.env`.

After the first test run, you can verify the account exists in Supabase Dashboard → Authentication → Users.

## MFA tests

The admin MFA spec (`admin/01-mfa.spec.ts`) needs the `speakeasy` library to generate TOTP codes server-side:

```bash
npm install --save-dev speakeasy
```

Without it, the MFA tests are auto-skipped.

Everything tests against **live Supabase**. Cleanup runs after each test. Test emails always use the pattern `qa-test-<timestamp>-<rand>@example.com` (plus a few variants) so cleanup can find leftovers.

## Setup

```bash
cd tests
npm install
npx playwright install chromium

cp .env.example .env
# Edit .env and fill in SUPABASE_SERVICE_KEY (and ADMIN_TEST_EMAIL for admin tests)
```

The service-role key is required for OTP bypass and cleanup. Get it from Supabase dashboard → Project Settings → API → `service_role`.

## Running

```bash
npm test                 # all tests
npm run test:mobile      # mobile only
npm run test:admin       # admin only (skipped without ADMIN_TEST_EMAIL)
npm run test:headed      # see browser
npm run test:debug       # step through with inspector
npm run test:ui          # Playwright UI mode
npm run report           # open last HTML report

npm run cleanup          # nuke leftover qa-test-* records
```

## How OTP bypass works

Each test that needs auth calls `generateOtp(email)`, which hits Supabase's
admin endpoint `POST /auth/v1/admin/generate_link`. That endpoint returns the
6-digit code that *would have been emailed* — but no email is actually sent.
The test then types the 6 digits into the OTP UI normally.

This avoids:
- Real email delivery (and Resend's per-email 60s rate limit)
- Flaky inbox-polling tests
- Cleanup of test emails in real inboxes

## Cleanup

If a test crashes mid-run and leaves orphaned data, run:

```bash
npm run cleanup
```

That script deletes:
- `auth.users` rows where email matches `qa-test-%`, `victim-%`, `invited-%`, `ghost-%`
- `app_users` rows with the same email patterns
- `products` rows named `QA Test Product%` or `Draft Product%`
- `bot_conversations` from the AgroBot tests

## Known fragility

- **Selectors are text-based** in places (e.g., `button:has-text("Save")`).
  If you rename a button, update the selector. Prefer adding `data-testid`
  attributes long-term.
- **Tests run serially** (`workers: 1`) to avoid Supabase auth rate limits.
  A full mobile run takes ~3–5 minutes.
- **Admin tests require `ADMIN_TEST_EMAIL`** be a real admin user on the
  platform. They're skipped if the env var is missing.

## Adding new tests

1. Create a spec in `mobile/` or `admin/` named with a number prefix for ordering.
2. Always use a unique email via `qaEmail()` from `helpers/supabase.ts`.
3. Clean up in `afterEach` via `cleanupTestUser(email)`.
4. Follow the existing pattern: arrange (signup) → act (UI) → assert.
