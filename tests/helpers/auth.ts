/**
 * Auth helpers for Playwright tests — drives the actual UI to sign up /
 * sign in, but uses the admin API to grab the OTP code so we don't depend
 * on real email delivery (or hit Resend's 60s cooldown).
 *
 * IMPORTANT: app.html keeps every onboarding/home/etc. mockup screen mounted
 * in the DOM at all times — only the screen with class `.proto-active` is
 * visible. Naive selectors like `page.locator('.role-card:has-text("Farmer")')`
 * therefore hit hidden screens too and explode Playwright's strict mode.
 * Use `activeScreen(page)` (a Locator scoped to the visible screen) for any
 * element that exists in multiple screens, and `waitForScreen(page, id)`
 * to wait for navigation between screens.
 */
import { Page, Locator, expect } from '@playwright/test';
import { generateOtp, deleteAuthUser, deleteAppUserByEmail } from './supabase';

export interface FarmerSignupOpts {
  email: string;
  name: string;
  phone: string;        // 9 digits, no country code
  district: string;
  subCounty: string;
  farmSize: string;
  village: string;
  ageRange: '18 – 35' | '36 – 60';
  crops: string[];      // e.g. ['Matooke', 'Coffee']
}

/**
 * Locator scoped to the currently visible app screen — i.e. the
 * `.grid > div.proto-active` element. The `.tab-section` wrapper also gets
 * `.proto-active`, which is broader than we want: the wrapper contains
 * sibling screens too (`onboarding-3` next to `onboarding-8`, etc), and any
 * locator scoped to it ends up matching elements in those siblings.
 */
export function activeScreen(page: Page): Locator {
  return page.locator('.grid > div.proto-active').first();
}

/**
 * Wait for a specific screen (by `data-proto-id`) to become active.
 * Falls back to URL fragment matching for screens that use hash routing.
 */
export async function waitForScreen(page: Page, id: string, timeoutMs = 10_000) {
  await page
    .locator(`[data-proto-id="${id}"].proto-active, [data-proto-id="${id}"]:visible`)
    .first()
    .waitFor({ timeout: timeoutMs })
    .catch(async () => {
      // Hash-based fallback (some flows use #onboarding-X without proto-active)
      await page.waitForURL(new RegExp(`#${id}`), { timeout: timeoutMs });
    });
}

/**
 * Walk through the Farmer signup flow end-to-end and return when the OTP
 * screen is shown (after which the caller should call typeOtpAndVerify).
 */
export async function fillFarmerSignup(page: Page, opts: FarmerSignupOpts) {
  // Splash → intro → role select → farmer signup
  await page.goto('/app.html?mode=app#onboarding-2');

  // Pick the Farmer role on onboarding-3
  const introBtn = activeScreen(page).locator('a:has-text("Get Started"), button:has-text("Get Started")').first();
  await introBtn.click({ timeout: 8000 }).catch(() => {});
  await waitForScreen(page, 'onboarding-3');

  // Scope the role-card click to the active screen, AND match by the .name
  // child (cards have descriptive text that mentions other roles).
  // The role card itself carries `data-proto-go`, so a single click navigates
  // to the role's signup screen — no separate "Continue" click is needed.
  const farmerCard = activeScreen(page)
    .locator('.role-card')
    .filter({ has: page.locator('.name', { hasText: /^Farmer$/i }) })
    .first();
  await farmerCard.click();
  await waitForScreen(page, 'onboarding-4');

  const screen = activeScreen(page);

  // Fill basic text inputs (scoped to active signup screen)
  await screen.locator('input[placeholder="Your full name"]').fill(opts.name);
  await screen.locator('input[placeholder="772 XXX XXX"]').fill(opts.phone);
  await screen.locator('input[placeholder="your@email.com"]').fill(opts.email);

  // District / sub-county dropdowns (real <select> after wireSignup runs)
  await screen.locator('select').nth(0).selectOption({ label: opts.district });
  await screen.locator('select').nth(1).selectOption({ label: opts.subCounty });

  // Age range pills
  await screen.locator('.pill', { hasText: opts.ageRange }).first().click();

  // Crops — toggle each one to ON. If already on, leave it.
  for (const crop of opts.crops) {
    const pill = screen.locator('.pill').filter({ hasText: crop }).first();
    const klass = await pill.getAttribute('class');
    if (!klass?.includes('on')) await pill.click();
  }

  // Farm size dropdown
  await screen.locator('select').nth(2).selectOption({ label: opts.farmSize });

  // Village
  await screen.locator('input[placeholder="e.g. Kayabwe"]').fill(opts.village);

  // Click "Send OTP" (scoped to the active signup screen)
  await screen.locator('.sticky-btn .btn.primary, button:has-text("Send OTP")').first().click();
  // Now we wait for the OTP screen
  await waitForScreen(page, 'onboarding-8');
}

/**
 * Type a 6-digit OTP into the 6 input boxes and verify.
 * Uses programmatically-generated OTP from Supabase admin API.
 */
export async function typeOtpAndVerify(page: Page, otp: string) {
  expect(otp.length).toBe(6);
  const inputs = activeScreen(page).locator('.otp-row input');
  for (let i = 0; i < 6; i++) {
    await inputs.nth(i).fill(otp[i]);
  }
  await activeScreen(page).locator('button:has-text("Verify")').first().click();
}

/**
 * Full programmatic signup: fill the form, grab the OTP via admin API,
 * type it, verify, and end up at the home screen.
 */
export async function signUpAsFarmer(page: Page, opts: FarmerSignupOpts) {
  await fillFarmerSignup(page, opts);
  // Generate OTP via admin API (no email actually sent to the user)
  const otp = await generateOtp(opts.email);
  await typeOtpAndVerify(page, otp);
  // After verify, user is on home-1
  await waitForScreen(page, 'home-1', 15_000);
}

/**
 * Sign in an EXISTING user.
 *
 * IMPORTANT: Supabase's signInWithOtp endpoint shares a 60-second per-email
 * rate limit with the signup flow. When this helper runs right after
 * `signUpAsFarmer`, clicking the real "Send sign-in code" button often hits
 * the rate limit and the OTP screen never opens — which is what we want to
 * test eventually, but it makes test runs flaky.
 *
 * To stay deterministic, we use the admin API to mint a fresh OTP token, then
 * call `sb.auth.verifyOtp` directly from the page. That re-uses the exact
 * server-side verification path the real UI uses (no auth shortcuts), but
 * skips the rate-limited send + the OTP-screen UI itself.
 */
export async function signInExisting(page: Page, email: string) {
  await page.goto('/app.html?mode=app#onboarding-2');
  // Mint an OTP via the admin endpoint (no per-email rate limit).
  const otp = await generateOtp(email);
  // Verify it through the real Supabase client mounted on the page.
  const res = await page.evaluate(async ({ e, t }) => {
    const sb = (window as any).sb || (window as any).__sb;
    if (!sb?.auth?.verifyOtp) return { error: 'no supabase client' };
    const r = await sb.auth.verifyOtp({ email: e, token: t, type: 'email' });
    return { error: r.error?.message || null };
  }, { e: email, t: otp });
  if (res.error) throw new Error(`signInExisting verifyOtp failed: ${res.error}`);
  // Pull the full app_users row using the service key so we can seed
  // `window.__amProfile` directly — that lets the home/profile wraps paint
  // the real user name instantly (otherwise they paint asynchronously after a
  // round-trip to Supabase, which races our assertion).
  const { adminClient: ac } = await import('./supabase');
  const { data: profile } = await ac().from('app_users').select('*').eq('email', email).single();
  await page.evaluate((p) => {
    if (p) (window as any).__amProfile = p;
    if ((window as any).protoShow) (window as any).protoShow('home-1');
    else location.hash = '#home-1';
  }, profile);
  await page.waitForURL(/#home-1|#agent-1|#fo-1|#fo-2|#diaspora-1/, { timeout: 15_000 });
  await page.waitForTimeout(800);
}

/**
 * Programmatic farmer seed — creates the auth user, the app_users row, and
 * lands the page on home-1 with a valid session, WITHOUT going through the
 * rate-limited Send-OTP UI button.
 *
 * Use this in `beforeEach` for specs that only need a signed-in farmer (shop
 * browsing, agrobot, profile, RLS). Specs that test the signup UI itself
 * (02-signup-farmer) keep using `signUpAsFarmer`.
 */
export async function seedSignedInFarmer(page: Page, opts: FarmerSignupOpts) {
  // 1. Mint the auth user via admin API (no email send, no rate limit).
  const SUPA_URL = process.env.SUPABASE_URL!;
  const SVC      = process.env.SUPABASE_SERVICE_KEY!;
  const create = await fetch(`${SUPA_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: SVC,
      Authorization: `Bearer ${SVC}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: opts.email,
      email_confirm: true,
      user_metadata: {
        full_name: opts.name,
        phone:     opts.phone,
        role:      'farmer',
        district:  opts.district,
        sub_county: opts.subCounty,
        village:   opts.village,
        farm_size: opts.farmSize,
        age_range: opts.ageRange,
        crops:     opts.crops,
      },
    }),
  });
  const createData = await create.json().catch(() => ({}));
  const userId = createData.id || createData.user?.id;
  if (!userId) throw new Error(`seedSignedInFarmer createUser failed: ${JSON.stringify(createData).slice(0, 200)}`);

  // 2. Upsert the corresponding app_users row with the farmer profile.
  // NOTE: app_users only has these columns — anything else lives in auth user
  // metadata (which is set via createUser above). Don't add columns the table
  // doesn't have or the upsert returns PGRST204.
  const { adminClient } = await import('./supabase');
  const admin = adminClient();
  const upsertRes = await admin.from('app_users').upsert(
    {
      id:          userId,
      email:       opts.email,
      full_name:   opts.name,
      phone:       opts.phone,
      role:        'farmer',
      district:    opts.district,
      sub_county:  opts.subCounty,
      status:      'active',
    },
    { onConflict: 'id' }
  ).select();
  if (upsertRes.error) {
    throw new Error(`seedSignedInFarmer app_users upsert failed: ${upsertRes.error.message} | code=${upsertRes.error.code} | details=${upsertRes.error.details}`);
  }

  // 3. Mint an OTP and verify it in the page's Supabase client — this
  // establishes a real session (matching what the UI would set).
  const otp = await generateOtp(opts.email);
  await page.goto('/app.html?mode=app');
  await page.waitForFunction(
    () => Boolean((window as any).sb || (window as any).__sb),
    null,
    { timeout: 10_000 }
  );
  const verify = await page.evaluate(async ({ e, t }) => {
    const sb = (window as any).sb || (window as any).__sb;
    if (!sb?.auth?.verifyOtp) return { error: 'no supabase client' };
    const r = await sb.auth.verifyOtp({ email: e, token: t, type: 'email' });
    return { error: r.error?.message || null };
  }, { e: opts.email, t: otp });
  if (verify.error) throw new Error(`seedSignedInFarmer verifyOtp failed: ${verify.error}`);

  // 4. Seed the wraps' cached profile so paintGreeting / populateProfileLanding
  // can run synchronously on the first protoShow call — without waiting for
  // `ensureFullProfile` to round-trip to Supabase. This is what makes the home
  // greeting actually paint the test user's name instead of the mockup default.
  // Stay aligned with the real app_users schema (no age_range/village/etc.).
  const cachedProfile = {
    id:          userId,
    email:       opts.email,
    full_name:   opts.name,
    phone:       opts.phone,
    role:        'farmer',
    district:    opts.district,
    sub_county:  opts.subCounty,
    status:      'active',
    created_at:  new Date().toISOString(),
  };
  await page.evaluate((profile) => {
    (window as any).__amProfile = profile;
    if ((window as any).protoShow) (window as any).protoShow('home-1');
    else location.hash = '#home-1';
  }, cachedProfile);
  await page.waitForURL(/#home-1/, { timeout: 10_000 });
  await page.waitForTimeout(800);
}

/**
 * Test cleanup helper — call from afterEach / afterAll.
 */
export async function cleanupTestUser(email: string) {
  await deleteAppUserByEmail(email);
  await deleteAuthUser(email);
}
