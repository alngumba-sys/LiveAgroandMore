/* Pesapal IPN endpoint. Pesapal calls this (GET) when a transaction status
   changes; we fetch the real status and mark the order paid, then ACK. */
const { token, getStatus, markOrder, isPaid } = require('./_pesapal-shared');

exports.handler = async (event) => {
  const p = event.queryStringParameters || {};
  const trackingId = p.OrderTrackingId || p.orderTrackingId;
  const ref        = p.OrderMerchantReference || p.orderMerchantReference;
  try{
    if(trackingId){
      const tok = await token();
      const st  = await getStatus(tok, trackingId);
      await markOrder(ref, isPaid(st));
    }
  }catch(e){ /* swallow — still ACK so Pesapal stops retrying on our errors */ }
  return {
    statusCode:200,
    headers:{ 'Content-Type':'application/json' },
    body: JSON.stringify({ orderNotificationType:'IPNCHANGE', orderTrackingId: trackingId, orderMerchantReference: ref, status:200 })
  };
};
