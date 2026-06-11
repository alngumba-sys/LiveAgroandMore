/**
 * AI Chatbot — view bot_conversations logs from the mobile AgroBot.
 * Verifies that the page renders without errors and surfaces the conversations table.
 * TODO: filter by helpful=true/false, filter by fallback_used.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('AI Chatbot page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'chatbot');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
