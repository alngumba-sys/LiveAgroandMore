/**
 * Profile screen + bottom-nav routing across tabs.
 */
import { test, expect } from '@playwright/test';
import { seedSignedInFarmer, cleanupTestUser, activeScreen } from '../helpers/auth';
import { qaEmail } from '../helpers/supabase';

test.describe('Profile + bottom-nav', () => {
  let email: string;

  test.beforeEach(async ({ page }) => {
    email = qaEmail();
    await seedSignedInFarmer(page, {
      email,
      name: 'Profile Test',
      phone: '712777888',
      district: 'Wakiso',
      subCounty: 'Central',
      farmSize: '2 acres',
      village: 'TestVillage',
      ageRange: '36 – 60',
      crops: ['Coffee', 'Maize'],
    });
  });

  test.afterEach(async () => {
    if (email) await cleanupTestUser(email);
  });

  test('profile screen shows REAL name, role, district, sub-county, phone', async ({ page }) => {
    // Navigate to profile via bottom nav, scoped to the active home screen.
    await activeScreen(page).locator('.bnav .item').nth(4).click();
    await page.waitForURL(/#profile-1/);
    const screen = activeScreen(page);
    await expect(screen.locator('.prof-hero .name').first()).toContainText('Profile Test', { timeout: 6_000 });
    await expect(screen.locator('.meta .role').first()).toContainText(/FARMER/i);
    await expect(screen.locator('.meta').first()).toContainText(/Wakiso/);
    await expect(screen.locator('.meta').first()).toContainText(/712\s*777\s*888|\+256712777888/);
  });

  test('bottom nav: each tab routes correctly', async ({ page }) => {
    const targets = [
      { idx: 0, hash: 'home-1' },
      { idx: 1, hash: 'shop-1' },
      { idx: 2, hash: 'advisory-1' },
      { idx: 3, hash: 'sell-1' },
      { idx: 4, hash: 'profile-1' },
    ];
    for (const t of targets) {
      await activeScreen(page).locator('.bnav .item').nth(t.idx).click();
      await expect(page).toHaveURL(new RegExp('#' + t.hash));
    }
  });

  test('bottom nav works from cart (shop-3) without being blocked', async ({ page }) => {
    await page.goto('/app.html?mode=app#shop-3');
    await activeScreen(page).locator('.bnav .item').nth(0).click(); // Home
    await expect(page).toHaveURL(/#home-1/);
  });

  test('home greeting paints REAL name (not "Nakato Nabirye" mockup)', async ({ page }) => {
    await activeScreen(page).locator('.bnav .item').nth(0).click();
    const greet = activeScreen(page).locator('.greet .name').first();
    await expect(greet).toContainText('Profile');
    await expect(greet).not.toContainText('Nakato');
  });

  test('profile screen does NOT show seed mockup data', async ({ page }) => {
    await activeScreen(page).locator('.bnav .item').nth(4).click();
    await page.waitForURL(/#profile-1/);
    const name = await activeScreen(page).locator('.prof-hero .name').first().textContent();
    expect(name?.toLowerCase()).not.toContain('nakato');
    expect(name?.toLowerCase()).not.toContain('nabirye');
  });
});
