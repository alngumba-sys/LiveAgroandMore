/**
 * Traceability — batch list, stage management.
 * TODO: create batch, advance stage, link to mobile Trace lookup.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('traceability page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'traceability');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
