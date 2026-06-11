/* Submit an order to Pesapal (API 3.0) and return the hosted redirect URL.
   Secrets come from Netlify env vars — never hard-code them.
   Env: PESAPAL_CONSUMER_KEY, PESAPAL_CONSUMER_SECRET, PESAPAL_ENV (sandbox|live)
   Optional: PESAPAL_IPN_ID, APP_URL
   Diagnostic: GET ?diag=1 reports what the function sees (no secrets). */

const BASE = () => (process.env.PESAPAL_ENV === 'live')
  ? 'https://pay.pesapal.com/v3'
  : 'https://cybqa.pesapal.com/pesapalv3';

/* ── Module-level cache (lives as long as the Lambda container is warm) ── */
let _tokenCache = null;   // { value, expiresAt }
let _ipnIdCache  = null;  // string

async function token() {
  const now = Date.now();
  if (_tokenCache && _tokenCache.expiresAt > now + 10_000) return _tokenCache.value;

  const key    = (process.env.PESAPAL_CONSUMER_KEY    || '').trim();
  const secret = (process.env.PESAPAL_CONSUMER_SECRET || '').trim();
  const r = await fetch(BASE() + '/api/Auth/RequestToken', {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body:    JSON.stringify({ consumer_key: key, consumer_secret: secret })
  });
  const j = await r.json();
  if (!j || !j.token) throw new Error('Pesapal auth failed: ' + JSON.stringify(j));

  /* Pesapal tokens are valid for 5 minutes; cache for 4 min 30 s */
  _tokenCache = { value: j.token, expiresAt: now + 270_000 };
  return j.token;
}

async function ipnId(tok, ipnUrl) {
  if (process.env.PESAPAL_IPN_ID) return process.env.PESAPAL_IPN_ID;
  if (_ipnIdCache) return _ipnIdCache;

  const r = await fetch(BASE() + '/api/URLSetup/RegisterIPN', {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + tok },
    body:    JSON.stringify({ url: ipnUrl, ipn_notification_type: 'GET' })
  });
  const j = await r.json();
  if (!j || !j.ipn_id) throw new Error('Pesapal IPN register failed: ' + JSON.stringify(j));
  _ipnIdCache = j.ipn_id;
  return j.ipn_id;
}

async function submitOrder(tok, payload) {
  const r = await fetch(BASE() + '/api/Transactions/SubmitOrderRequest', {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + tok },
    body:    JSON.stringify(payload)
  });
  return r.json();
}

exports.handler = async (event) => {
  const headers = {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type':                 'application/json'
  };
  if (event.httpMethod === 'OPTIONS') return { statusCode: 200, headers, body: '' };

  if (event.httpMethod === 'GET' && (event.queryStringParameters || {}).diag === '1') {
    const k = (process.env.PESAPAL_CONSUMER_KEY || ''), s = (process.env.PESAPAL_CONSUMER_SECRET || '');
    return { statusCode: 200, headers, body: JSON.stringify({
      env:                       process.env.PESAPAL_ENV || '(unset)',
      base:                      BASE(),
      consumer_key_set:          !!k, consumer_key_len: k.length, consumer_key_trimmed_len: k.trim().length,
      consumer_secret_set:       !!s, consumer_secret_len: s.length, consumer_secret_trimmed_len: s.trim().length,
      supabase_url_set:          !!process.env.SUPABASE_URL,
      service_key_set:           !!process.env.SUPABASE_SERVICE_KEY,
      token_cached:              !!_tokenCache,
      token_expires_in_seconds:  _tokenCache ? Math.round((_tokenCache.expiresAt - Date.now()) / 1000) : null,
      ipn_id_cached:             _ipnIdCache || process.env.PESAPAL_IPN_ID || null
    }) };
  }

  if (event.httpMethod !== 'POST') return { statusCode: 405, headers, body: JSON.stringify({ error: 'POST only' }) };

  try {
    const b = JSON.parse(event.body || '{}');
    if (!b.order_number || !b.amount)
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'order_number and amount are required' }) };

    const origin      = process.env.APP_URL || ('https://' + (event.headers.host || 'agro-more-app.netlify.app'));
    const callbackUrl = origin + '/?pesapal=callback';
    const notifyUrl   = origin + '/.netlify/functions/pesapal-ipn';

    const tok = await token();
    const id  = await ipnId(tok, notifyUrl);

    const payload = {
      id:              String(b.order_number),
      currency:        b.currency || 'USD',
      amount:          Number(b.amount),
      description:     (b.description || ('Agro & More order ' + b.order_number)).slice(0, 100),
      callback_url:    callbackUrl,
      notification_id: id,
      billing_address: {
        email_address: b.email      || '',
        phone_number:  b.phone      || '',
        first_name:    b.first_name || 'Customer',
        last_name:     b.last_name  || ''
      }
    };

    let j = await submitOrder(tok, payload);

    /* ── Retry once: refresh token and resubmit if no redirect_url ── */
    if (!j || !j.redirect_url) {
      console.warn('Pesapal first attempt failed, retrying with fresh token. detail:', JSON.stringify(j));
      _tokenCache = null; // force fresh token
      const tok2 = await token();
      j = await submitOrder(tok2, payload);
    }

    if (!j || !j.redirect_url)
      return { statusCode: 502, headers, body: JSON.stringify({ error: 'Pesapal did not return a redirect URL', detail: j }) };

    return { statusCode: 200, headers, body: JSON.stringify({ redirect_url: j.redirect_url, order_tracking_id: j.order_tracking_id }) };

  } catch (e) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: String(e && e.message || e) }) };
  }
};
