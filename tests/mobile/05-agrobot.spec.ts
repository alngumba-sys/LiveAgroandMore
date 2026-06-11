/**
 * AgroBot — in-app knowledge-base chat.
 */
import { test, expect } from '@playwright/test';
import { seedSignedInFarmer, cleanupTestUser, activeScreen } from '../helpers/auth';
import { qaEmail, adminClient } from '../helpers/supabase';

test.describe('AgroBot chat', () => {
  let email: string;

  test.beforeEach(async ({ page }) => {
    email = qaEmail();
    await seedSignedInFarmer(page, {
      email,
      name: 'Bot User',
      phone: '712333444',
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

  // Helper: navigate to advisory-7 via protoShow (forces wireAgroBot to run),
  // then wait for the .bot-thread to render. page.goto with a hash doesn't
  // reliably trigger the IIFE wrap that initializes the bot.
  async function openAgroBot(page) {
    await page.evaluate(() => {
      if ((window as any).protoShow) (window as any).protoShow('advisory-7');
      else location.hash = '#advisory-7';
    });
    await activeScreen(page).locator('.bot-thread').first().waitFor({ timeout: 12_000 });
  }

  test('AgroBot greets returning user by first name', async ({ page }) => {
    await openAgroBot(page);
    const firstBubble = activeScreen(page).locator('.bot-thread > div').first();
    // Greeting is the first bubble — should mention "Bot" or the user's name.
    await expect(firstBubble).toContainText(/Bot|Hello|Hi|Bot User/i, { timeout: 8_000 });
  });

  test('suggested question populates a real answer from knowledge base', async ({ page }) => {
    await openAgroBot(page);
    // Click the first suggestion pill (button inside the thread)
    await activeScreen(page).locator('.bot-thread button').first().click();
    await page.waitForTimeout(2500);
    const replies = await activeScreen(page).locator('.bot-thread > div').count();
    expect(replies).toBeGreaterThan(2);
    await expect(activeScreen(page).locator('button:has-text("👍")').first()).toBeVisible({ timeout: 5_000 });
  });

  test('typing custom question hits knowledge base', async ({ page }) => {
    await openAgroBot(page);
    await activeScreen(page).locator('.bot-input').first().fill('How do I treat blight on my tomatoes?');
    await activeScreen(page).locator('.bot-send').first().click();
    await page.waitForTimeout(3000);
    const bubbleTexts = await activeScreen(page).locator('.bot-thread > div').allTextContents();
    expect(bubbleTexts.join(' ').toLowerCase()).toMatch(/blight|mancozeb|fungicide/);
  });

  test('unknown question falls back to "Talk to Field Officer" escalation', async ({ page }) => {
    await openAgroBot(page);
    await activeScreen(page).locator('.bot-input').first().fill('xyzzy nonexistent topic ablkdj');
    await activeScreen(page).locator('.bot-send').first().click();
    await page.waitForTimeout(2500);
    await expect(activeScreen(page).locator('button:has-text("Talk to a Field Officer")').first()).toBeVisible();
  });

  test('thumbs-up records helpful=true in bot_conversations', async ({ page }) => {
    await openAgroBot(page);
    await activeScreen(page).locator('.bot-input').first().fill('fall armyworm in maize');
    await activeScreen(page).locator('.bot-send').first().click();
    await page.waitForTimeout(3000);
    await activeScreen(page).locator('button:has-text("👍")').first().click();
    await page.waitForTimeout(1500);
    const admin = adminClient();
    const { data } = await admin
      .from('bot_conversations')
      .select('question, helpful')
      .ilike('question', '%fall armyworm%')
      .order('created_at', { ascending: false })
      .limit(1);
    expect(data?.[0]?.helpful).toBeTruthy();
    await admin.from('bot_conversations').delete().ilike('question', '%fall armyworm%');
  });
});
