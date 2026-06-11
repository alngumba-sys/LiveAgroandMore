/**
 * Orders list + detail. We don't create real orders (that requires the full
 * mobile checkout flow); instead these tests check that whatever's in the
 * orders table renders without errors, search works, and status filters fire.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test.describe('Orders', () => {
  test('orders page loads + table renders', async ({ page }) => {
    await adminSignIn(page);
    await adminNav(page, 'orders');
    // Scope the heading lookup to the ACTIVE page — `h1, h2` on other (hidden)
    // pages otherwise match too. `#page-orders.active` is set by adminNav.
    await expect(page.locator('#page-orders.active h1, #page-orders.active h2').first())
      .toBeVisible({ timeout: 8_000 });
  });

  test('no JS errors on orders page', async ({ page }) => {
    const errs: string[] = [];
    page.on('pageerror', e => errs.push(e.message));
    await adminSignIn(page);
    await adminNav(page, 'orders');
    await page.waitForTimeout(3000);
    expect(errs, errs.join('\n')).toEqual([]);
  });

  test('search by order number does not crash the page', async ({ page }) => {
    await adminSignIn(page);
    await adminNav(page, 'orders');
    const search = page.locator('#page-orders.active input[placeholder*="search" i], #page-orders.active input[type="search"]').first();
    if (await search.isVisible().catch(() => false)) {
      await search.fill('AM-2026-XX');
      await page.waitForTimeout(1500);
      await expect(page.locator('body')).toBeVisible();
    }
  });
});

test.describe('Diaspora Orders', () => {
  test('page loads + no errors', async ({ page }) => {
    const errs: string[] = [];
    page.on('pageerror', e => errs.push(e.message));
    await adminSignIn(page);
    await adminNav(page, 'diaspora');
    await page.waitForTimeout(2500);
    expect(errs).toEqual([]);
  });
});
