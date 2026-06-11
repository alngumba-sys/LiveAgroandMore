/**
 * POST /.netlify/functions/admin-staff-manage
 *
 * Performs privileged staff_profiles operations that require the service key
 * (RLS on the anon key blocks cross-user updates/deletes).
 *
 * Input (JSON):
 *   { action: 'block',   id: uuid }   → sets active = false
 *   { action: 'unblock', id: uuid }   → sets active = true
 *   { action: 'delete',  id: uuid }   → deletes the row
 *
 * Caller must be authenticated (Authorization: Bearer <user_access_token>)
 * and must have role 'md' or 'it_admin' in staff_profiles.
 *
 * Required env vars: SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY
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

  const { SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    return reply(500, { ok: false, error: 'Server not configured.' });
  }

  /* ── Authenticate the caller ──────────────────────────── */
  const authHeader = event.headers['authorization'] || event.headers['Authorization'] || '';
  const callerToken = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!callerToken) return reply(401, { ok: false, error: 'Not authenticated.' });

  /* Verify token and load caller's profile */
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

  /* Load caller's staff role */
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
  const profiles = await profileRes.json().catch(() => []);
  const callerRole = profiles[0]?.role;
  const ALLOWED_ROLES = ['md', 'it_admin'];
  if (!ALLOWED_ROLES.includes(callerRole)) {
    return reply(403, { ok: false, error: 'Only MD or IT Admin can manage staff accounts.' });
  }

  /* ── Parse action ─────────────────────────────────────── */
  let body = {};
  try { body = JSON.parse(event.body || '{}'); } catch (_) {}
  const { action, id } = body;

  if (!id)     return reply(400, { ok: false, error: 'User id required.' });
  if (!action) return reply(400, { ok: false, error: 'Action required (block/unblock/delete).' });

  /* Prevent self-action */
  if (id === callerId) return reply(400, { ok: false, error: 'You cannot perform this action on your own account.' });

  const sbServiceHeaders = {
    apikey:         SUPABASE_SERVICE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    'Content-Type': 'application/json',
    Prefer:         'return=representation',
  };

  /* ── Execute ──────────────────────────────────────────── */
  if (action === 'block' || action === 'unblock') {
    const active = action === 'unblock';
    const patchRes = await fetch(
      `${SUPABASE_URL}/rest/v1/staff_profiles?id=eq.${encodeURIComponent(id)}`,
      {
        method:  'PATCH',
        headers: sbServiceHeaders,
        body:    JSON.stringify({ active }),
      }
    );
    if (!patchRes.ok) {
      const t = await patchRes.text();
      console.error('[admin-staff-manage] patch failed', patchRes.status, t);
      return reply(500, { ok: false, error: `Could not ${action} user.` });
    }
    return reply(200, { ok: true });
  }

  if (action === 'delete') {
    /* First verify target is blocked — enforce block-before-delete rule */
    const checkRes = await fetch(
      `${SUPABASE_URL}/rest/v1/staff_profiles?id=eq.${encodeURIComponent(id)}&select=active,role`,
      { headers: { apikey: SUPABASE_SERVICE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`, Accept: 'application/json' } }
    );
    const rows = await checkRes.json().catch(() => []);
    if (!rows.length) return reply(404, { ok: false, error: 'User not found.' });
    if (rows[0].active !== false) return reply(400, { ok: false, error: 'Block the user before deleting.' });
    if (rows[0].role === 'md') return reply(403, { ok: false, error: 'Cannot delete an MD account.' });

    /* Step 1 — delete staff_profiles row */
    const delProfileRes = await fetch(
      `${SUPABASE_URL}/rest/v1/staff_profiles?id=eq.${encodeURIComponent(id)}`,
      { method: 'DELETE', headers: { apikey: SUPABASE_SERVICE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_KEY}` } }
    );
    if (!delProfileRes.ok) {
      const t = await delProfileRes.text();
      console.error('[admin-staff-manage] delete staff_profiles failed', delProfileRes.status, t);
      return reply(500, { ok: false, error: 'Could not delete staff profile.' });
    }

    /* Step 2 — delete from auth.users so they can be cleanly re-invited later */
    const delAuthRes = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(id)}`,
      { method: 'DELETE', headers: { apikey: SUPABASE_SERVICE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_KEY}` } }
    );
    if (!delAuthRes.ok) {
      /* Auth delete failing is non-fatal — profile is already gone.
         Log it but return success so the UI doesn't confuse the admin. */
      const t = await delAuthRes.text();
      console.warn('[admin-staff-manage] auth user delete failed (non-fatal)', delAuthRes.status, t);
    }

    return reply(200, { ok: true });
  }

  return reply(400, { ok: false, error: `Unknown action: ${action}` });
};
