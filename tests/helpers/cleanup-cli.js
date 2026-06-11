#!/usr/bin/env node
/**
 * Standalone cleanup script — wipes all qa-test-* leftover users + products.
 * Run with `npm run cleanup` from the tests/ directory.
 *
 * Safe to run anytime. Idempotent.
 */
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const URL = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_KEY;
if (!URL || !KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in .env');
  process.exit(1);
}
const sb = createClient(URL, KEY, { auth: { persistSession: false } });

async function deleteAuthUsersMatching(pattern) {
  let deleted = 0;
  // Paginate through auth users
  let page = 1;
  for (;;) {
    const r = await fetch(`${URL}/auth/v1/admin/users?per_page=200&page=${page}`, {
      headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
    });
    const data = await r.json();
    const users = data.users || [];
    if (!users.length) break;
    for (const u of users) {
      const e = (u.email || '').toLowerCase();
      if (pattern.test(e)) {
        await fetch(`${URL}/auth/v1/admin/users/${u.id}`, {
          method: 'DELETE',
          headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
        });
        deleted++;
        console.log('  deleted auth user', e);
      }
    }
    if (users.length < 200) break;
    page++;
  }
  return deleted;
}

(async () => {
  console.log('=== QA cleanup starting ===');

  // 1. auth.users matching qa-test-*, victim-*, invited-*, ghost-*
  const pat = /^(qa-test|victim|invited|ghost)-/i;
  const a = await deleteAuthUsersMatching(pat);
  console.log(`auth users deleted: ${a}`);

  // 2. app_users rows with those email patterns
  const { error: e1, count: c1 } = await sb
    .from('app_users')
    .delete({ count: 'exact' })
    .or('email.like.qa-test-%,email.like.victim-%,email.like.invited-%,email.like.ghost-%');
  if (e1) console.warn('app_users delete error:', e1.message);
  else console.log(`app_users deleted: ${c1 ?? 0}`);

  // 3. products with QA-named test entries
  const { error: e2, count: c2 } = await sb
    .from('products')
    .delete({ count: 'exact' })
    .or('name.like.QA Test Product%,name.like.Draft Product%');
  if (e2) console.warn('products delete error:', e2.message);
  else console.log(`products deleted: ${c2 ?? 0}`);

  // 4. bot_conversations created during QA
  const { error: e3, count: c3 } = await sb
    .from('bot_conversations')
    .delete({ count: 'exact' })
    .like('question', '%fall armyworm%');
  if (e3) console.warn('bot_conversations delete error:', e3.message);
  else console.log(`bot_conversations deleted: ${c3 ?? 0}`);

  console.log('=== Cleanup done ===');
})();
