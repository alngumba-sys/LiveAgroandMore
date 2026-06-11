/* Shared Pesapal helpers for IPN + status functions. */
const BASE = () => (process.env.PESAPAL_ENV === 'live')
  ? 'https://pay.pesapal.com/v3'
  : 'https://cybqa.pesapal.com/pesapalv3';

async function token(){
  const r = await fetch(BASE() + '/api/Auth/RequestToken', {
    method:'POST',
    headers:{'Content-Type':'application/json','Accept':'application/json'},
    body: JSON.stringify({ consumer_key: process.env.PESAPAL_CONSUMER_KEY, consumer_secret: process.env.PESAPAL_CONSUMER_SECRET })
  });
  const j = await r.json();
  if(!j || !j.token) throw new Error('Pesapal auth failed');
  return j.token;
}

async function getStatus(tok, trackingId){
  const r = await fetch(BASE() + '/api/Transactions/GetTransactionStatus?orderTrackingId=' + encodeURIComponent(trackingId), {
    headers:{'Accept':'application/json','Authorization':'Bearer '+tok}
  });
  return r.json();
}

/* Marks the diaspora order confirmed once paid. We ONLY patch on success — on
   failure we leave the order as 'awaiting_payment' so the customer can retry
   (and so we never write an enum value the column doesn't allow). */
async function markOrder(orderNumber, paid){
  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_KEY;
  if(!url || !key || !orderNumber || !paid) return;
  /* Farmer/agent orders use order_number like 'AM-2026-06-00004'; diaspora gift
     orders use 'AM-D-...'. Route the confirmation to the matching table. */
  const table = /^AM-D-/i.test(orderNumber) ? 'diaspora_orders' : 'orders';
  await fetch(url.replace(/\/$/,'') + '/rest/v1/' + table + '?order_number=eq.' + encodeURIComponent(orderNumber), {
    method:'PATCH',
    headers:{ 'apikey':key, 'Authorization':'Bearer '+key, 'Content-Type':'application/json', 'Prefer':'return=minimal' },
    body: JSON.stringify({ status: 'confirmed' })
  });
  /* Best-effort: push the paid order into Odoo as a sale order. Never block
     payment confirmation if Odoo is slow/unreachable; push_order is idempotent. */
  try{
    const base = process.env.APP_URL || 'https://agro-more-app.netlify.app';
    await fetch(base + '/.netlify/functions/odoo-sync?action=push_order&commit=1&order_number=' + encodeURIComponent(orderNumber));
  }catch(e){}
}

function isPaid(st){
  const d = (st && (st.payment_status_description || st.status_code)) || '';
  return String(d).toLowerCase() === 'completed' || String(st && st.status_code) === '1';
}

module.exports = { BASE, token, getStatus, markOrder, isPaid };
