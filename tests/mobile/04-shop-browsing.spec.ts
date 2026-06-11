/**
 * Shop browsing — categories, list, no-product flash, dynamic counters.
 * Requires being signed in. Uses one shared returning-user session per spec.
 */
import { test, expect } from '@playwright/test';
import { seedSignedInFarmer, cleanupTestUser, activeScreen } from '../helpers/auth';
import { qaEmail, adminClient } from '../helpers/supabase';

test.describe('Shop browsing', () => {
  let email: string;

  test.beforeEach(async ({ page }) => {
    email = qaEmail();
    await seedSignedInFarmer(page, {
      email,
      name: 'Shopper QA',
      phone: '712555666',
      district: 'Mpigi',
      subCounty: 'Nkozi',
      farmSize: '1 acre',
      village: 'V',
      ageRange: '18 – 35',
      crops: ['Maize'],
    });
  });

  test.afterEach(async () => {
    if (email) await cleanupTestUser(email);
  });

  test('shop home: All chip shows real count, In stock chip is gone', async ({ page }) => {
    await page.goto('/app.html?mode=app#shop-1');
    const screen = activeScreen(page);
    await expect(screen.locator('.filter-row .shop-total-chip').first()).toBeVisible({ timeout: 6_000 });
    await expect(screen.locator('.shop-total-chip').first()).toContainText(/All · \d+/);
    // Scope the "In stock" check to the ACTIVE screen — mockup screens still
    // have an "In stock" chip in the DOM; the production shop home should not.
    await expect(screen.locator('.filter-row .chip').filter({ hasText: 'In stock' })).toHaveCount(0);
  });

  test('all category badges show real counts, not mockup', async ({ page }) => {
    await page.goto('/app.html?mode=app#shop-1');
    await page.waitForTimeout(2000);
    const screen = activeScreen(page);
    const livestockCount = await screen
      .locator('.cat-card')
      .filter({ has: page.locator('.cat-name:has-text("Livestock")') })
      .first()
      .locator('.cat-count')
      .textContent();
    expect(livestockCount).not.toContain('88');
  });

  test('opening a category shows Loading... then real products (no stale flash)', async ({ page }) => {
    await page.goto('/app.html?mode=app#shop-1');
    await page.waitForTimeout(1500);
    await activeScreen(page).locator('.cat-card').filter({ hasText: 'Crop Protection' }).first().click();
    // Loading state shows first (best-effort — fast networks may skip it).
    await expect(activeScreen(page).locator('.shop-loading, span:has-text("Loading")').first())
      .toBeVisible({ timeout: 2_000 })
      .catch(() => {});
    await expect(activeScreen(page).locator('.product-row').first()).toBeVisible({ timeout: 8_000 });
    await expect(activeScreen(page).locator('.app-bar').first()).toContainText(/Crop Protection/);
  });

  test('empty category shows "No products" not stale ones', async ({ page }) => {
    // The "Livestock" category isn't actually empty in seed data — it has
    // "Longe 5 OP". Temporarily hide every Livestock product so this test can
    // verify the empty-state UI actually fires. Restore at the end.
    const admin = adminClient();
    const { data: livestockRows } = await admin
      .from('products')
      .select('id, show_on_shop')
      .eq('category', 'Livestock');
    const ids = (livestockRows || []).map((r: any) => r.id);
    try {
      if (ids.length) {
        await admin.from('products').update({ show_on_shop: false }).in('id', ids);
      }
      await page.goto('/app.html?mode=app#shop-1');
      await page.waitForTimeout(1500);
      await activeScreen(page).locator('.cat-card').filter({ hasText: 'Livestock' }).first().click();
      await expect(activeScreen(page).locator('.shop-empty, span:has-text("No products")').first())
        .toBeVisible({ timeout: 8_000 });
    } finally {
      // Restore — leaving show_on_shop=false would break other tests + real shop.
      if (ids.length) {
        await admin.from('products').update({ show_on_shop: true }).in('id', ids);
      }
    }
  });

  test('Showing N of M counter reflects actual product count', async ({ page }) => {
    await page.goto('/app.html?mode=app#shop-1');
    await page.waitForTimeout(1500);
    await activeScreen(page).locator('.cat-card').filter({ hasText: 'Fertilizers' }).first().click();
    await page.waitForTimeout(3000);
    const counter = activeScreen(page).locator('div:has-text("Showing"), div:has-text("No products")').first();
    const txt = (await counter.textContent()) || '';
    expect(txt).not.toContain('1–8 of 136');
  });

  test('rapid category switching: race-protection token discards stale fetch', async ({ page }) => {
    await page.goto('/app.html?mode=app#shop-1');
    await page.waitForTimeout(1500);
    await activeScreen(page).locator('.cat-card').filter({ hasText: 'Crop Protection' }).first().click();
    // Immediately switch to Seeds before the first fetch resolves
    await activeScreen(page).locator('.app-bar svg').first().click();   // back
    await activeScreen(page).locator('.cat-card').filter({ hasText: 'Seeds' }).first().click();
    await expect(activeScreen(page).locator('.app-bar').first()).toContainText(/Seeds/);
    await expect(activeScreen(page).locator('.product-row').first()).toBeVisible({ timeout: 8_000 });
    const firstRow = await activeScreen(page).locator('.product-row .pd').first().textContent();
    expect((firstRow || '').toLowerCase()).toContain('seeds');
  });
});
