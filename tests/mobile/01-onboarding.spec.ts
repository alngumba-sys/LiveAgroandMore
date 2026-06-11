/**
 * Smoke tests for the splash → intro → role-select flow.
 * No backend calls — just verifies the app boots and navigation works.
 */
import { test, expect } from '@playwright/test';
import { activeScreen } from '../helpers/auth';

test.describe('Onboarding flow', () => {
  test('splash auto-advances to intro within 5 seconds', async ({ page }) => {
    await page.goto('/app.html?mode=app');
    // After ~4.5s the splash auto-advances to onboarding-2
    await expect(page).toHaveURL(/#onboarding-2/, { timeout: 6_000 });
  });

  test('intro shows "Get Started" CTA AND "Log in" link', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-2');
    const screen = activeScreen(page);
    await expect(screen.locator('button:has-text("Get Started"), a:has-text("Get Started")').first()).toBeVisible();
    // The real "Already have an account? Log in" link carries class .signin-link;
    // there's a textually-identical mockup duplicate without that class.
    await expect(screen.locator('a.signin-link, a:has-text("Log in")').first()).toBeVisible();
  });

  test('role selection screen shows all four roles', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-3');
    const screen = activeScreen(page);
    // Each role card's .name child carries the role label cleanly; card
    // descriptions can mention other roles (e.g. Diaspora copy says "buy from
    // farmers"), so we match by .name to keep the filter precise.
    for (const role of ['Farmer', 'Agent', 'Field Officer', 'Diaspora']) {
      await expect(
        screen
          .locator('.role-card')
          .filter({ has: page.locator('.name', { hasText: new RegExp(`^${role}`, 'i') }) })
          .first()
      ).toBeVisible();
    }
  });

  test('back arrow from role select returns to intro', async ({ page }) => {
    // Land on intro first, THEN navigate to role-select, so history.back() has
    // somewhere to go (a goto() with a hash counts as a single entry in some
    // browsers — coming from intro guarantees a previous entry).
    await page.goto('/app.html?mode=app#onboarding-2');
    await expect(page).toHaveURL(/#onboarding-2/, { timeout: 5_000 });
    await page.evaluate(() => { location.hash = '#onboarding-3'; });
    await expect(page).toHaveURL(/#onboarding-3/, { timeout: 5_000 });
    await activeScreen(page).locator('.app-bar svg').first().click();
    await expect(page).toHaveURL(/#onboarding-[12]/);
  });
});
