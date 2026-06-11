/* Called by the app after the user returns from Pesapal. Confirms the payment
   status, updates the order, and reports back so the app can show the result. */
const { token, getStatus, markOrder, isPaid } = require('./_pesapal-shared');

exports.handler = async (event) => {
  const headers = { 'Access-Control-Allow-Origin':'*', 'Content-Type':'application/json' };
  const p = event.queryStringParameters || {};
  const trackingId = p.OrderTrackingId || p.orderTrackingId || p.tracking;
  const ref        = p.OrderMerchantReference || p.ref;
  if(!trackingId) return { statusCode:400, headers, body: JSON.stringify({error:'OrderTrackingId required'}) };
  try{
    const tok = await token();
    const st  = await getStatus(tok, trackingId);
    const paid = isPaid(st);
    await markOrder(ref, paid);
    return { statusCode:200, headers, body: JSON.stringify({ paid, status_description: st && st.payment_status_description, order_number: ref }) };
  }catch(e){
    return { statusCode:500, headers, body: JSON.stringify({ error: String(e && e.message || e) }) };
  }
};
