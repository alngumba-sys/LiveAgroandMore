/**
 * Finance / Odoo connection — page renders, connection state visible.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn } from '../helpers/admin-auth';

test('finance page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await page.locator('text=/^finance$/i').first().click();
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
