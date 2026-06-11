/**
 * Advisory Content — CRUD on videos / radio recordings.
 * TODO: add video URL, mark inactive, multi-language tag.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('advisory content page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'advisory');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
