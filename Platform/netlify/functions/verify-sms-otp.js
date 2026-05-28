/**
 * POST /.netlify/functions/verify-sms-otp
 *
 * Input  (JSON): { email: string, code: string }
 * Output (JSON):
 *   ok:    { ok:true, token: "<6-digit-magiclink-otp>" } — caller passes the
 *          returned token to sb.auth.verifyOtp({ email, token, type:'email' })
 *          to establish a real Supabase session.
 *   fail:  { ok:false, error: string, code?: 'EXPIRED'|'TOO_MANY_ATTEMPTS'|'INVALID' }
 *
 * On a valid SMS code: marks the row consumed, then calls Supabase's
 * admin /auth/v1/admin/generate_link to mint a magic-link OTP for the
 * same email. The mobile client uses that token to sign in normally.
 *
 * Required Netlify env vars: SUPABASE_URL, SUPABASE_SERVICE_KEY
 */
const crypto = require('crypto');

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type':                  'application/json',
};
function reply(statusCode, body) {
  return { statusCode, headers: CORS, body: JSON.stringify(body) };
}
function sha256(s) {
  return crypto.createHash('sha256').update(s).digest('hex');
}
async function sbREST(path, opts = {}) {
  const url = `${process.env.SUPABASE_URL}/rest/v1${path}`;
  const r = await fetch(url, {
    ...opts,
    headers: {
      apikey:        process.env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_KEY}`,
      'Content-Type':'application/json',
      ...(opts.headers || {}),
    },
  });
  const text = await r.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch (_) { data = text; }
  return { ok: r.ok, status: r.status, data };
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS, body: '' };
  if (event.httpMethod !== 'POST')   return reply(405, { ok:false, error:'POST required' });

  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY) {
    return reply(500, { ok:false, error:'Server not configured.' });
  }

  try {
    let body = {};
    try { body = JSON.parse(event.body || '{}'); } catch (_) {}
    const email = String(body.email || '').trim().toLowerCase();
    const code  = String(body.code  || '').trim();
    if (!email || !email.includes('@')) return reply(400, { ok:false, error:'Valid email required' });
    if (!/^\d{6}$/.test(code))          return reply(400, { ok:false, error:'6-digit code required' });

    /* 1) Find the latest unconsumed code for this email. */
    const r = await sbREST(`/sms_otp_codes?select=id,code_hash,expires_at,attempts,consumed_at&email=eq.${encodeURIComponent(email)}&consumed_at=is.null&order=created_at.desc&limit=1`);
    if (!r.ok) { console.error('[verify-sms-otp] DB lookup failed', r.data); return reply(500, { ok:false, error:'Verification failed. Please try again.' }); }
    const row = Array.isArray(r.data) ? r.data[0] : null;
    if (!row) return reply(400, { ok:false, error:'No active SMS code for this email. Tap "Resend".', code:'NO_ACTIVE_CODE' });

    /* 2) Expiry + attempts cap. */
    if (new Date(row.expires_at).getTime() < Date.now()) {
      return reply(400, { ok:false, error:'Code expired. Tap "Resend" to get a new one.', code:'EXPIRED' });
    }
    if ((row.attempts || 0) >= 5) {
      return reply(400, { ok:false, error:'Too many wrong attempts. Tap "Resend" for a new code.', code:'TOO_MANY_ATTEMPTS' });
    }

    /* 3) Compare hashes. */
    const matches = sha256(code) === row.code_hash;
    if (!matches) {
      // Bump attempts. Best-effort — not fatal if it fails.
      await sbREST(`/sms_otp_codes?id=eq.${row.id}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ attempts: (row.attempts || 0) + 1 }),
      });
      return reply(400, { ok:false, error:'Wrong code. Try again.', code:'INVALID' });
    }

    /* 4) Mark consumed so it can't be replayed. */
    await sbREST(`/sms_otp_codes?id=eq.${row.id}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ consumed_at: new Date().toISOString() }),
    });

    /* 5) Mint a Supabase magic-link OTP for this email. Returns email_otp
          (a 6-digit code) that the client uses against sb.auth.verifyOtp
          to establish a real session. */
    const linkRes = await fetch(`${process.env.SUPABASE_URL}/auth/v1/admin/generate_link`, {
      method: 'POST',
      headers: {
        apikey:        process.env.SUPABASE_SERVICE_KEY,
        Authorization: `Bearer ${process.env.SUPABASE_SERVICE_KEY}`,
        'Content-Type':'application/json',
      },
      body: JSON.stringify({ type: 'magiclink', email }),
    });
    const linkBody = await linkRes.json().catch(() => ({}));
    const token = linkBody.email_otp || linkBody.properties?.email_otp;
    if (!linkRes.ok || !token) {
      console.error('[verify-sms-otp] generate_link failed', linkRes.status, linkBody);
      console.error('[verify-sms-otp] generate_link failed detail:', linkBody.msg || linkBody.error_description);
      return reply(500, { ok:false, error:'Authentication failed. Please try again.' });
    }

    return reply(200, { ok:true, token });
  } catch (e) {
    console.error('[verify-sms-otp] unhandled', e);
    return reply(500, { ok:false, error: 'Internal error. Please try again.' });
  }
};
