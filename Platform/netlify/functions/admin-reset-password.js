/**
 * POST /.netlify/functions/admin-reset-password
 *
 * Resets a staff member's password to a new temporary password and emails it
 * to them. On next login they will be forced to set a permanent password.
 *
 * Caller must be authenticated and have role 'md' or 'it_admin'.
 *
 * Input  (JSON): { userId: string, email: string, fullName: string, loginUrl: string }
 * Output (JSON): { ok: true } | { ok: false, error: string }
 *
 * Required env vars: SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, RESEND_API_KEY
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

/** Readable 12-char temp password: AABB-2345-CCDD */
function generateTempPassword() {
  const upper  = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower  = 'abcdefghjkmnpqrstuvwxyz';
  const digits = '23456789';
  const rand   = (set) => set[Math.floor(Math.random() * set.length)];
  return (
    rand(upper) + rand(upper) + rand(lower) + rand(lower) +
    '-' +
    rand(digits) + rand(digits) + rand(digits) + rand(digits) +
    '-' +
    rand(upper) + rand(upper) + rand(lower) + rand(lower)
  );
}

/** Look up an auth user's id by email (admin API, paginated search). */
async function findAuthUserIdByEmail(SUPABASE_URL, SUPABASE_SERVICE_KEY, email) {
  const needle = String(email || '').trim().toLowerCase();
  if (!needle) return null;
  const listRes = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=1000`,
    {
      headers: {
        apikey:        SUPABASE_SERVICE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
        Accept:        'application/json',
      },
    }
  );
  if (!listRes.ok) {
    const t = await listRes.text();
    console.error('[admin-reset-password] user list failed', listRes.status, t);
    return null;
  }
  const lj    = await listRes.json().catch(() => ({}));
  const users = Array.isArray(lj) ? lj : (lj.users || []);
  const match = users.find((u) => (u.email || '').trim().toLowerCase() === needle);
  return match ? match.id : null;
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS, body: '' };
  if (event.httpMethod !== 'POST')   return reply(405, { ok: false, error: 'POST required' });

  try {
  const { SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, RESEND_API_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    return reply(500, { ok: false, error: 'Server not configured.' });
  }

  /* ── Authenticate the caller ──────────────────────────── */
  const authHeader  = event.headers['authorization'] || event.headers['Authorization'] || '';
  const callerToken = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!callerToken) return reply(401, { ok: false, error: 'Not authenticated.' });

  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey:        SUPABASE_ANON_KEY || SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${callerToken}`,
    },
  });
  if (!userRes.ok) return reply(401, { ok: false, error: 'Invalid session.' });
  const userJson = await userRes.json().catch(() => ({}));
  const callerId = userJson.id;
  if (!callerId) return reply(401, { ok: false, error: 'Could not identify caller.' });

  /* Verify caller is MD or IT Admin */
  const profileRes = await fetch(
    `${SUPABASE_URL}/rest/v1/staff_profiles?id=eq.${callerId}&select=role`,
    {
      headers: {
        apikey:        SUPABASE_SERVICE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
        Accept:        'application/json',
      },
    }
  );
  const profiles   = await profileRes.json().catch(() => []);
  const callerRole = profiles[0]?.role;
  if (!['md', 'it_admin'].includes(callerRole)) {
    return reply(403, { ok: false, error: 'Only MD or IT Admin can reset passwords.' });
  }

  /* ── Parse request body ───────────────────────────────── */
  let body = {};
  try { body = JSON.parse(event.body || '{}'); } catch (_) {}

  const { userId, email, fullName, loginUrl } = body;
  if (!userId && !email) return reply(400, { ok: false, error: 'userId or email required.' });
  if (!email)            return reply(400, { ok: false, error: 'email required.' });

  /* Prevent resetting the caller's own password this way */
  if (userId && userId === callerId) {
    return reply(400, { ok: false, error: 'Use the profile settings to change your own password.' });
  }

  const tempPassword = generateTempPassword();

  /* ── Update password + set must_change_password flag ─── */
  const payload = JSON.stringify({
    password:      tempPassword,
    user_metadata: { must_change_password: true },
  });
  const putUser = (uid) => fetch(`${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(uid)}`, {
    method:  'PUT',
    headers: {
      apikey:         SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: payload,
  });

  let updateRes = userId ? await putUser(userId) : { ok: false, status: 0, _skipped: true };

  /* If the supplied id isn't a real auth user (id/auth mismatch), fall back
     to resolving the auth user by email — the same approach send-admin-invite
     uses — then retry once. */
  if (!updateRes.ok) {
    if (!updateRes._skipped) {
      const t = await updateRes.text().catch(() => '');
      console.warn('[admin-reset-password] direct update by id failed, trying email lookup', updateRes.status, t);
    }
    const resolvedId = await findAuthUserIdByEmail(SUPABASE_URL, SUPABASE_SERVICE_KEY, email);
    if (!resolvedId) {
      return reply(404, { ok: false, error: `No account found for ${email}. The user may not have finished signing up.` });
    }
    if (resolvedId === callerId) {
      return reply(400, { ok: false, error: 'Use the profile settings to change your own password.' });
    }
    updateRes = await putUser(resolvedId);
  }

  if (!updateRes.ok) {
    const t = await updateRes.text().catch(() => '');
    console.error('[admin-reset-password] update failed', updateRes.status, t);
    return reply(502, { ok: false, error: `Could not reset password (auth error ${updateRes.status}). ${t.slice(0, 200)}` });
  }

  /* ── Send email via Resend ────────────────────────────── */
  if (RESEND_API_KEY) {
    const firstName = (fullName || email).split(' ')[0];
    const portalUrl = loginUrl || 'https://agroandmorehub.com/index.html';

    const emailHtml = `
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto;color:#1a1a1a">
        <img src="https://agroandmorehub.com/icons/icon-192.png"
             alt="Agro &amp; More" width="56" height="56"
             style="border-radius:12px;margin-bottom:16px;display:block">
        <h2 style="color:#FF7D00;margin:0 0 8px">Your password has been reset</h2>
        <p>Hi ${firstName},</p>
        <p>Your Agro and More admin portal password has been reset by an administrator.
           Use the temporary password below to sign in — you will be asked to set a new password immediately.</p>

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
          If you did not request this, please contact your administrator immediately.
        </p>
      </div>`;

    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from:    'Agro & More <noreply@agroandmorehub.com>',
        to:      [email],
        subject: 'Your Agro & More admin portal password has been reset',
        html:    emailHtml,
      }),
    });

    if (!resendRes.ok) {
      const t = await resendRes.text();
      console.error('[admin-reset-password] Resend failed', resendRes.status, t);
      // Password was reset but email failed — still return ok so admin knows
      return reply(200, { ok: true, emailSkipped: true });
    }

    console.log('[admin-reset-password] password reset and email sent to', email);
  }

  return reply(200, { ok: true });
  } catch (e) {
    console.error('[admin-reset-password] unhandled', e);
    return reply(500, { ok: false, error: `Server error: ${(e && e.message) || e}` });
  }
};
