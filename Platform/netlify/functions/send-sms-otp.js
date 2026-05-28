/**
 * POST /.netlify/functions/send-sms-otp
 *
 * Issues a 6-digit code, stores the SHA-256 hash in sms_otp_codes,
 * and dispatches the code via Africa's Talking REST API.
 *
 * Input  (JSON):  { email: string }
 * Output (JSON):  { ok:true,  masked_phone: '+256 7** *** 678', expires_in: 300 }
 *                 { ok:false, error: string, code?: 'NO_PHONE_ON_FILE' | 'RATE_LIMITED' | ... }
 *
 * Reads AT credentials (at_username, at_api_key, at_sender_id) from the
 * public.settings table via Supabase service key (RLS-bypass). MD manages
 * those credentials in Settings → SMS provider.
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

function maskPhone(phone) {
  if (!phone) return '';
  const digits = String(phone).replace(/[^0-9]/g, '');
  if (digits.length < 9) return phone;
  return `+${digits.slice(0,3)} ${digits[3]}** *** ${digits.slice(-3)}`;
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
    return reply(500, { ok:false, error:'Server not configured (SUPABASE_URL / SUPABASE_SERVICE_KEY missing).' });
  }

  try {
    let body = {};
    try { body = JSON.parse(event.body || '{}'); } catch (_) {}
    const email = String(body.email || '').trim().toLowerCase();
    if (!email || !email.includes('@')) return reply(400, { ok:false, error:'Valid email required' });

    /* 1) Find the user's phone — must be a real phone, not a placeholder. */
    const u = await sbREST(`/app_users?select=email,phone&email=eq.${encodeURIComponent(email)}&limit=1`);
    if (!u.ok) { console.error('[send-sms-otp] DB lookup failed', u.data); return reply(500, { ok:false, error:'Could not look up account. Please try again.' }); }
    const user = Array.isArray(u.data) ? u.data[0] : null;
    if (!user || !user.phone)   return reply(200, { ok:false, error:'no_phone', code:'NO_PHONE_ON_FILE' });
    if (String(user.phone).startsWith('ph-'))
      return reply(200, { ok:false, error:'no_phone', code:'NO_PHONE_ON_FILE' });

    /* 2) Rate-limit: one SMS per email per 60s. */
    const since = new Date(Date.now() - 60_000).toISOString();
    const r = await sbREST(`/sms_otp_codes?select=created_at&email=eq.${encodeURIComponent(email)}&created_at=gte.${since}&order=created_at.desc&limit=1`);
    if (r.ok && Array.isArray(r.data) && r.data.length) {
      const ms = 60_000 - (Date.now() - new Date(r.data[0].created_at).getTime());
      const wait = Math.max(1, Math.ceil(ms / 1000));
      return reply(429, { ok:false, error:`Please wait ${wait}s before requesting another SMS.`, code:'RATE_LIMITED' });
    }

    /* 3) Generate code (6 digits), store SHA-256 hash with 5-min TTL. */
    const code     = String(Math.floor(100000 + Math.random() * 900000));
    const codeHash = sha256(code);
    const expires  = new Date(Date.now() + 5 * 60_000).toISOString();
    const ipHash   = sha256(event.headers['x-forwarded-for'] || event.headers['client-ip'] || 'unknown');
    const ins = await sbREST(`/sms_otp_codes`, {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ email, phone: user.phone, code_hash: codeHash, expires_at: expires, ip_hash: ipHash }),
    });
    if (!ins.ok) { console.error('[send-sms-otp] OTP store failed', ins.data); return reply(500, { ok:false, error:'Could not send verification code. Please try again.' }); }

    /* 4) Pull AT credentials from settings. */
    const s = await sbREST(`/settings?select=key,value&key=in.(at_username,at_api_key,at_sender_id)`);
    if (!s.ok) { console.error('[send-sms-otp] settings read failed', s.data); return reply(500, { ok:false, error:'SMS service unavailable. Please try again.' }); }
    const cfg = {};
    (s.data || []).forEach(row => { cfg[row.key] = String(row.value || '').trim(); });
    if (!cfg.at_username || !cfg.at_api_key) {
      return reply(500, { ok:false, error:'SMS provider not configured (admin must set AT credentials in Settings → SMS provider).' });
    }

    /* 5) Send via Africa's Talking REST API.
          Sandbox username uses sandbox endpoint, anything else uses production. */
    const isSandbox = cfg.at_username.toLowerCase() === 'sandbox';
    const atUrl = isSandbox
      ? 'https://api.sandbox.africastalking.com/version1/messaging'
      : 'https://api.africastalking.com/version1/messaging';
    const message =
      `Your Agro & More verification code is ${code}. ` +
      `It expires in 5 minutes. Don't share it with anyone.`;
    const params = new URLSearchParams({ username: cfg.at_username, to: user.phone, message });
    if (cfg.at_sender_id) params.append('from', cfg.at_sender_id);

    const atRes = await fetch(atUrl, {
      method: 'POST',
      headers: {
        'Accept':       'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'apiKey':       cfg.at_api_key,
      },
      body: params.toString(),
    });
    const atText = await atRes.text();
    let parsed = {};
    try { parsed = JSON.parse(atText); } catch (_) {}
    const recipient = parsed?.SMSMessageData?.Recipients?.[0];
    if (!atRes.ok || (recipient && recipient.statusCode && recipient.statusCode >= 400)) {
      console.error('[send-sms-otp] AT failed', atRes.status, atText);
      return reply(502, { ok:false, error:'SMS gateway failed: ' + (recipient?.status || atText.slice(0, 120)) });
    }

    return reply(200, { ok:true, masked_phone: maskPhone(user.phone), expires_in: 300 });
  } catch (e) {
    console.error('[send-sms-otp] unhandled', e);
    return reply(500, { ok:false, error: 'Internal error. Please try again.' });
  }
};
