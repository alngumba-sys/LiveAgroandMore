/**
 * Produce Prices — list per crop + region, edit, save.
 * TODO: ensure mobile Sell My Produce reflects price changes.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('produce prices page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'prices');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
