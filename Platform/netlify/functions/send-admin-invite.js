/**
 * POST /.netlify/functions/send-admin-invite
 *
 * Invite flow — creates a staff account with a temporary password and emails
 * it to the new staff member. Works for both new and existing Supabase users.
 *
 * Step 1 — Create the auth.users record with the temp password (no Supabase email).
 *          If user already exists, update their password so the temp password is fresh.
 * Step 2 — Send the invite email via Resend containing:
 *            • A direct link to the admin login page with their email pre-filled
 *            • Their temporary password (visible in the email)
 *          user_metadata.must_change_password = true is set so admin.html forces
 *          them to pick a new password on first login.
 *
 * Input  (JSON): {
 *   email:      string,
 *   loginUrl:   string,   // admin portal login page URL (e.g. https://admin.../index.html)
 *   data: { full_name, role, phone, invited_by, invited_at, outlet_id }
 * }
 * Output (JSON):
 *   { ok: true,  userId: string }                        — invited, email sent
 *   { ok: true,  userId: string, emailSkipped: true }    — created but Resend failed
 *   { ok: false, error: string }
 *
 * Required env vars: SUPABASE_URL, SUPABASE_SERVICE_KEY, RESEND_API_KEY
 */

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type':                  'application/json',
};

function reply(statusCode, body) {
  return { statusCode, headers: CORS, body: JSON.stringify(body) };
}

const ROLE_LABELS = {
  md: 'Managing Director', sales_manager: 'Sales / Operations Manager',
  finance: 'Finance Officer', it_admin: 'IT Admin',
  agronomist: 'Senior Agronomist', outlet_clerk: 'Outlet Clerk',
};

/** Generate a readable 12-char temporary password: Xxxx-0000-Xxxx style */
function generateTempPassword() {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghjkmnpqrstuvwxyz';
  const digits = '23456789';
  const rand = (set) => set[Math.floor(Math.random() * set.length)];
  // Format: Uull-dddd-Uull  (Upper, upper, lower, lower - digits - Upper, upper, lower, lower)
  return (
    rand(upper) + rand(upper) + rand(lower) + rand(lower) +
    '-' +
    rand(digits) + rand(digits) + rand(digits) + rand(digits) +
    '-' +
    rand(upper) + rand(upper) + rand(lower) + rand(lower)
  );
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS, body: '' };
  if (event.httpMethod !== 'POST')   return reply(405, { ok: false, error: 'POST required' });

  const { SUPABASE_URL, SUPABASE_SERVICE_KEY, RESEND_API_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    return reply(500, { ok: false, error: 'Server not configured.' });
  }

  let body = {};
  try { body = JSON.parse(event.body || '{}'); } catch (_) {}

  const email    = String(body.email    || '').trim().toLowerCase();
  const loginUrl = String(body.loginUrl || '').trim();
  const data     = body.data || {};

  if (!email || !email.includes('@')) {
    return reply(400, { ok: false, error: 'Valid email required.' });
  }

  const sbHeaders = {
    apikey:         SUPABASE_SERVICE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    'Content-Type': 'application/json',
  };

  const tempPassword = generateTempPassword();
  const userMeta = { ...data, must_change_password: true };

  try {
    /* ── Step 1: Create user or update existing ───────────────── */
    let userId  = null;
    let existed = false;

    const createRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
      method:  'POST',
      headers: sbHeaders,
      body: JSON.stringify({
        email,
        password:       tempPassword,
        email_confirm:  true,   // mark confirmed — Supabase sends no email
        user_metadata:  userMeta,
      }),
    });

    if (createRes.ok) {
      const created = await createRes.json().catch(() => ({}));
      userId  = created.id || null;
      existed = false;
      console.log('[send-admin-invite] new user created', userId);
    } else {
      /* User already exists (farmer or previous staff) — find their UUID
         and update password + metadata so the temp credentials are fresh. */
      existed = true;
      console.log('[send-admin-invite] user exists — looking up UUID');

      // Find UUID by listing users
      const listRes = await fetch(
        `${SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=1000`,
        { method: 'GET', headers: sbHeaders }
      );
      if (listRes.ok) {
        const lj = await listRes.json().catch(() => ({}));
        const match = (lj.users || []).find(u => u.email === email);
        if (match?.id) userId = match.id;
      }

      if (!userId) {
        console.error('[send-admin-invite] could not resolve userId for existing user');
        return reply(500, { ok: false, error: 'Could not find user account. Please try again.' });
      }

      // Update password and metadata on the existing account
      const updateRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`, {
        method:  'PUT',
        headers: sbHeaders,
        body: JSON.stringify({
          password:      tempPassword,
          user_metadata: userMeta,
        }),
      });
      if (!updateRes.ok) {
        const t = await updateRes.text();
        console.error('[send-admin-invite] password update failed', updateRes.status, t);
        return reply(500, { ok: false, error: 'Could not set temporary password. Please try again.' });
      }
      console.log('[send-admin-invite] existing user updated', userId);
    }

    /* ── Step 2: Send invite email via Resend ─────────────────── */
    if (RESEND_API_KEY) {
      const roleLabel = ROLE_LABELS[data.role] || data.role || 'staff member';
      const firstName = (data.full_name || email).split(' ')[0];

      const portalUrl = loginUrl || 'https://agroandmorehub.com/index.html';

      const emailHtml = `
        <div style="font-family:sans-serif;max-width:560px;margin:0 auto;color:#1a1a1a">
          <img src="https://agroandmorehub.com/icons/icon-192.png"
               alt="Agro &amp; More" width="56" height="56"
               style="border-radius:12px;margin-bottom:16px;display:block">
          <h2 style="color:#FF7D00;margin:0 0 8px">You've been invited to the Agro &amp; More Admin Portal</h2>
          <p>Hi ${firstName},</p>
          <p>You have been given access to the <strong>Agro and More admin panel</strong>
             as <strong>${roleLabel}</strong>.</p>
          <p>Use the details below to sign in. You will be asked to set a new password when you first log in.</p>

          <div style="background:#f5f5f5;border-radius:8px;padding:20px;margin:24px 0">
            <p style="margin:0 0 8px;font-size:13px;color:#888;text-transform:uppercase;letter-spacing:.05em">Your login details</p>
            <p style="margin:0 0 6px"><span style="color:#888;font-size:13px">Email:</span>
               <strong style="font-size:15px">&nbsp;${email}</strong></p>
            <p style="margin:0"><span style="color:#888;font-size:13px">Temporary password:</span>
               <strong style="font-size:18px;letter-spacing:.08em;font-family:monospace">&nbsp;${tempPassword}</strong></p>
          </div>

          <p style="margin:0 0 8px">Sign in to the admin portal here:</p>
          <p style="margin:0 0 28px">
            <a href="${portalUrl}" style="color:#FF7D00;font-weight:600">${portalUrl}</a>
          </p>
          <p style="font-size:12px;color:#888">
            If you did not expect this invitation, you can safely ignore this email.
          </p>
        </div>`;

      const resendRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from:    'Agro & More <noreply@agroandmorehub.com>',
          to:      [email],
          subject: "You've been invited to the Agro & More Admin Portal",
          html:    emailHtml,
        }),
      });

      if (!resendRes.ok) {
        const t = await resendRes.text();
        console.error('[send-admin-invite] Resend failed', resendRes.status, t);
        return reply(200, { ok: true, userId, existed, emailSkipped: true });
      }

      console.log('[send-admin-invite] invite email sent to', email, 'userId', userId);
      return reply(200, { ok: true, userId, existed });
    }

    console.warn('[send-admin-invite] email skipped — no RESEND_API_KEY');
    return reply(200, { ok: true, userId, existed, emailSkipped: true });

  } catch (e) {
    console.error('[send-admin-invite] unhandled', e);
    return reply(500, { ok: false, error: 'Internal error: ' + (e?.message || String(e)) });
  }
};
