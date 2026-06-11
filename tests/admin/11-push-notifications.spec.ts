/**
 * Push Notifications — create draft, schedule, send.
 * TODO: send to single role, view delivery stats.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('push notifications page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'notifications');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
