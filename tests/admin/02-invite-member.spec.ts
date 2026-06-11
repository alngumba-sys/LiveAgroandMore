/**
 * Admin: Invite Member → invited farmer can sign in.
 */
import { test, expect } from '@playwright/test';
import { generateOtp, qaEmail, cleanupTestUser, adminClient } from '../helpers/supabase';

const ADMIN_EMAIL = process.env.ADMIN_TEST_EMAIL!;
test.skip(!ADMIN_EMAIL, 'Set ADMIN_TEST_EMAIL in .env to a real admin user.');

async function adminSignIn(page: any) {
  await page.goto('/index.html');
  await page.locator('input[type="email"]').fill(ADMIN_EMAIL);
  await page.locator('button:has-text("Sign in"), button:has-text("Continue"), button[type="submit"]').first().click();
  await page.waitForSelector('input[maxlength="1"], input[inputmode="numeric"]', { timeout: 8000 });
  const otp = await generateOtp(ADMIN_EMAIL);
  const otpInputs = page.locator('input[maxlength="1"], input[inputmode="numeric"]');
  const c = await otpInputs.count();
  if (c >= 6) for (let i = 0; i < 6; i++) await otpInputs.nth(i).fill(otp[i]);
  else await otpInputs.first().fill(otp);
  await page.locator('button:has-text("Verify"), button:has-text("Continue")').first().click();
  await page.waitForURL(/admin\.html|dashboard/, { timeout: 15_000 });
}

test.describe('Admin → Invite Member', () => {
  let invitedEmail: string;

  test.beforeAll(() => { invitedEmail = qaEmail('invited'); });

  test.afterEach(async () => {
    if (invitedEmail) await cleanupTestUser(invitedEmail);
  });

  test('inviting a farmer creates app_users row with status pending_approval', async ({ page }) => {
    await adminSignIn(page);
    // Open Users or Members section + click "Invite Member"
    await page.locator('a:has-text("Users"), a:has-text("Members")').first().click();
    await page.locator('button:has-text("Invite"), button:has-text("+ Invite Member")').first().click();
    // Fill drawer
    await page.locator('#im-name').fill('QA Invited Farmer');
    await page.locator('#im-email').fill(invitedEmail);
    await page.locator('#im-role').selectOption({ label: 'Farmer' });
    // Save
    await page.locator('#invite-member-drawer .btn-primary, button:has-text("Send invite")').first().click();

    // Verify the DB row exists with correct fields
    const admin = adminClient();
    await page.waitForTimeout(1500);
    const { data } = await admin
      .from('app_users')
      .select('full_name, email, role, status, phone')
      .eq('email', invitedEmail)
      .maybeSingle();
    expect(data?.full_name).toBe('QA Invited Farmer');
    expect(data?.role).toBe('farmer');
    expect(['pending_approval', 'active']).toContain(data?.status);
    // Phone placeholder pattern
    expect(data?.phone).toMatch(/^inv-/);
  });

  test('invited farmer can then sign in on the mobile app', async ({ page, browser }) => {
    await adminSignIn(page);
    await page.locator('a:has-text("Users"), a:has-text("Members")').first().click();
    await page.locator('button:has-text("Invite"), button:has-text("+ Invite Member")').first().click();
    await page.locator('#im-name').fill('Invitee Test');
    await page.locator('#im-email').fill(invitedEmail);
    await page.locator('#im-role').selectOption({ label: 'Farmer' });
    await page.locator('#invite-member-drawer .btn-primary, button:has-text("Send invite")').first().click();
    await page.waitForTimeout(2000);

    // Now switch to mobile, sign in as the invited farmer
    const mobileCtx = await browser.newContext({ baseURL: 'https://agro-more-app.netlify.app' });
    const mobile = await mobileCtx.newPage();
    await mobile.goto('/app.html?mode=app#onboarding-2');
    await mobile.locator('a:has-text("Log in")').click();
    await mobile.locator('#sb-li-email').fill(invitedEmail);
    await mobile.locator('#sb-li-btn').click();
    await mobile.waitForURL(/#onboarding-8/, { timeout: 10_000 });
    const otp = await generateOtp(invitedEmail);
    const inputs = mobile.locator('.otp-row input');
    for (let i = 0; i < 6; i++) await inputs.nth(i).fill(otp[i]);
    await mobile.locator('button:has-text("Verify")').click();
    await mobile.waitForURL(/#home-1/, { timeout: 15_000 });
    // Greeting should use the admin-supplied name
    await expect(mobile.locator('.greet .name')).toContainText('Invitee');
    await mobileCtx.close();
  });
});
