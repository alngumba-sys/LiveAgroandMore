/**
 * POST /.netlify/functions/admin-magic-link
 *
 * Sends a one-time sign-in link to an existing staff user via Resend.
 * Used by the login page as the "sign in with email link" flow — replaces
 * Supabase's own OTP which would send the farmer-app email template.
 *
 * The user must already exist in staff_profiles (active = true).
 * Non-staff emails silently appear to succeed (security — no email enumeration).
 *
 * Input  (JSON): { email: string, redirectTo: string }
 * Output (JSON): { ok: true } | { ok: false, error: string }
 *
 * Required env vars: SUPABASE_URL, SUPABASE_SERVICE_KEY, RESEND_API_KEY
 */

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type':                 'application/json',
};

function reply(code, body) {
  return { statusCode: code, headers: CORS, body: JSON.stringify(body) };
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS, body: '' };
  if (event.httpMethod !== 'POST')   return reply(405, { ok: false, error: 'POST required' });

  const { SUPABASE_URL, SUPABASE_SERVICE_KEY, RESEND_API_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY || !RESEND_API_KEY) {
    return reply(500, { ok: false, error: 'Server not configured.' });
  }

  let body = {};
  try { body = JSON.parse(event.body || '{}'); } catch (_) {}

  const email      = String(body.email      || '').trim().toLowerCase();
  const redirectTo = String(body.redirectTo || '').trim();

  if (!email || !email.includes('@')) {
    return reply(400, { ok: false, error: 'Valid email required.' });
  }

  const sbHeaders = {
    apikey:         SUPABASE_SERVICE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    'Content-Type': 'application/json',
  };

  try {
    /* Verify this is a known staff member (active) — silently succeed for
       unknown emails so we don't leak whether an account exists. */
    const profileRes = await fetch(
      `${SUPABASE_URL}/rest/v1/staff_profiles?email=eq.${encodeURIComponent(email)}&select=full_name,role,active`,
      { headers: { apikey: SUPABASE_SERVICE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`, Accept: 'application/json' } }
    );
    const profiles = await profileRes.json().catch(() => []);
    const profile  = profiles[0];

    /* Always return ok:true to avoid email enumeration */
    if (!profile || profile.active === false) {
      console.log('[admin-magic-link] unknown or blocked email — silent success', email);
      return reply(200, { ok: true });
    }

    /* Generate a magic link pointing to the admin portal */
    const glRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/generate_link`, {
      method:  'POST',
      headers: sbHeaders,
      body: JSON.stringify({
        type:  'magiclink',
        email,
        ...(redirectTo ? { redirect_to: redirectTo } : {}),
      }),
    });

    if (!glRes.ok) {
      const errText = await glRes.text();
      console.error('[admin-magic-link] generate_link failed', glRes.status, errText);
      return reply(200, { ok: true }); // silent — don't expose errors
    }

    const glJson     = await glRes.json().catch(() => ({}));
    const actionLink = glJson.action_link || glJson.link || glJson.properties?.action_link;

    if (!actionLink) {
      console.error('[admin-magic-link] no action_link in response', JSON.stringify(glJson));
      return reply(200, { ok: true });
    }

    /* Send sign-in email via Resend */
    const firstName = (profile.full_name || email).split(' ')[0];
    const emailHtml = `
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto;color:#1a1a1a">
        <img src="https://agroandmorehub.com/icons/icon-192.png"
             alt="Agro &amp; More" width="56" height="56"
             style="border-radius:12px;margin-bottom:16px;display:block">
        <h2 style="color:#FF7D00;margin:0 0 8px">Your sign-in link</h2>
        <p>Hi ${firstName},</p>
        <p>Click the button below to sign in to the <strong>Agro and More admin portal</strong>.
           This link is valid for <strong>24 hours</strong> and can only be used once.</p>
        <p style="margin:28px 0">
          <a href="${actionLink}"
             style="background:#FF7D00;color:#fff;padding:12px 24px;border-radius:8px;
                    text-decoration:none;font-weight:700;display:inline-block">
            Sign in to the admin portal →
          </a>
        </p>
        <p style="font-size:12px;color:#888">
          If you didn't request this, you can safely ignore this email.
          Your account remains secure.
        </p>
      </div>`;

    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from:    'Agro & More <noreply@agroandmorehub.com>',
        to:      [email],
        subject: 'Your Agro & More admin portal sign-in link',
        html:    emailHtml,
      }),
    });

    if (!resendRes.ok) {
      console.error('[admin-magic-link] Resend failed', resendRes.status, await resendRes.text());
    } else {
      console.log('[admin-magic-link] sign-in link sent to', email);
    }

    return reply(200, { ok: true });
  } catch (e) {
    console.error('[admin-magic-link] unhandled', e);
    return reply(200, { ok: true }); // silent — never expose internals to login page
  }
};
