/* Odoo integration backend (server-side JSON-RPC — no CORS, key stays secret).
   Env: ODOO_URL, ODOO_DB, ODOO_LOGIN, ODOO_API_KEY
        SUPABASE_URL, SUPABASE_SERVICE_KEY (for product/stock/customer/order sync)
   Actions (POST {action:...} or GET ?action=...):
     ping            – authenticate + return uid & server version (connectivity test)
     (more added as each sync flow is built: pull_products, pull_stock,
      push_customer, push_order)
   Diagnostic: GET ?action=diag returns presence/length of env (no secrets). */

const URL  = () => (process.env.ODOO_URL || '').replace(/\/$/, '');
const DB   = () => process.env.ODOO_DB || '';
const LOGIN= () => (process.env.ODOO_LOGIN || '').trim();
const KEY  = () => (process.env.ODOO_API_KEY || '').trim();

async function rpc(payload){
  const r = await fetch(URL() + '/jsonrpc', {
    method:'POST',
    headers:{ 'Content-Type':'application/json', 'Accept':'application/json' },
    body: JSON.stringify({ jsonrpc:'2.0', method:'call', id: Date.now(), params: payload })
  });
  const j = await r.json();
  if(j.error) throw new Error(j.error.data ? (j.error.data.message || JSON.stringify(j.error.data)) : (j.error.message || 'Odoo RPC error'));
  return j.result;
}

async function authenticate(){
  const uid = await rpc({ service:'common', method:'authenticate', args:[ DB(), LOGIN(), KEY(), {} ] });
  if(!uid) throw new Error('Odoo authentication failed — check DB, login email, and API key.');
  return uid;
}

async function version(){ return rpc({ service:'common', method:'version', args:[] }); }

/* Generic model call: execute_kw(model, method, args, kwargs) */
async function execKw(uid, model, method, args, kwargs){
  return rpc({ service:'object', method:'execute_kw', args:[ DB(), uid, KEY(), model, method, args || [], kwargs || {} ] });
}


function sbREST(path, opts){
  var base=(process.env.SUPABASE_URL||'').replace(/\/$/, '');
  var key=process.env.SUPABASE_SERVICE_KEY||'';
  return fetch(base + '/rest/v1/' + path, Object.assign({ headers:{ apikey:key, Authorization:'Bearer '+key, 'Content-Type':'application/json' } }, opts||{}));
}

exports.handler = async (event) => {
  const headers = { 'Access-Control-Allow-Origin':'*', 'Access-Control-Allow-Headers':'Content-Type', 'Content-Type':'application/json' };
  if(event.httpMethod === 'OPTIONS') return { statusCode:200, headers, body:'' };
  const q = event.queryStringParameters || {};
  let body = {}; try{ body = JSON.parse(event.body || '{}'); }catch(e){}
  const action = body.action || q.action || 'ping';

  if(action === 'diag'){
    return { statusCode:200, headers, body: JSON.stringify({
      url: URL() || '(unset)', db: DB() || '(unset)',
      login_set: !!LOGIN(), login_len: LOGIN().length,
      key_set: !!KEY(), key_len: KEY().length,
      supabase_url_set: !!process.env.SUPABASE_URL, service_key_set: !!process.env.SUPABASE_SERVICE_KEY
    }) };
  }

  try{
    if(action === 'summary'){
      const uid = await authenticate();
      const products  = await execKw(uid, 'product.template', 'search_count', [[]]);
      const sellable  = await execKw(uid, 'product.template', 'search_count', [[['sale_ok','=',true]]]);
      const partners  = await execKw(uid, 'res.partner', 'search_count', [[]]);
      const customers = await execKw(uid, 'res.partner', 'search_count', [[['customer_rank','>',0]]]);
      const orders    = await execKw(uid, 'sale.order', 'search_count', [[]]);
      const sample    = await execKw(uid, 'product.template', 'search_read', [[]], { fields:['name','default_code','list_price','qty_available'], limit:5 });
      return { statusCode:200, headers, body: JSON.stringify({ ok:true, products, sellable_products:sellable, partners, customers, sale_orders:orders, sample_products:sample }) };
    }
    if(action === 'pull_products'){
      var commit = (body.commit === true || q.commit === '1');
      var lim = Number(body.limit || q.limit || 5000);
      var uid = await authenticate();
      var fields=['id','name','default_code','list_price','qty_available','categ_id','sale_ok','active'];
      var odooProds = await execKw(uid,'product.template','search_read',[[['active','=',true],['type','!=','service']]],{ fields:fields, limit:lim });
      var exRes = await sbREST('products?select=id,name,odoo_id&limit=10000'); var existing=[]; try{ existing=await exRes.json(); }catch(e){}
      if(!Array.isArray(existing)) existing=[];
      var byOdoo={}, byName={};
      existing.forEach(function(p){ if(p.odoo_id!=null) byOdoo[p.odoo_id]=p; if(p.name) byName[String(p.name).trim().toLowerCase()]=p; });
      function mapCat(oc){ var c=String(oc||'').toLowerCase(); if(c.indexOf(' - ')>=0) c=c.split(' - ').pop();
        if(c.indexOf('herbicid')>=0) return 'Herbicides';
        if(c.indexOf('insecticid')>=0) return 'Insecticides';
        if(c.indexOf('fungicid')>=0) return 'Fungicides';
        if(c.indexOf('seed')>=0) return 'Seeds';
        if(c.indexOf('fertil')>=0) return 'Ferterlizers';
        if(c.indexOf('tool')>=0||c.indexOf('pump')>=0||c.indexOf('sprayer')>=0) return 'Tools';
        if(c.indexOf('irrigat')>=0) return 'Irrigation';
        if(c.indexOf('livestock')>=0||c.indexOf('animal')>=0) return 'Livestock';
        return 'Other Inputs';
      }
      var updates=[], inserts=[], nUpdate=0,nLink=0,nInsert=0, sample=[];
      odooProds.forEach(function(o){
        var rawCat=(o.categ_id && o.categ_id[1]) ? String(o.categ_id[1]).split('/').pop().trim() : '';
        var match = byOdoo[o.id] || byName[String(o.name||'').trim().toLowerCase()];
        var price=Math.round(o.list_price||0), stk=o.qty_available;
        if(match){ if(byOdoo[o.id]) nUpdate++; else nLink++;
          updates.push({ id:match.id, odoo_id:o.id, price_ugx:price, stock_qty:stk });
        } else { nInsert++;
          inserts.push({ name:o.name, category:mapCat(rawCat), price_ugx:price, stock_qty:stk, odoo_id:o.id, status:'active', show_on_shop:false });
        }
        if(sample.length<10) sample.push({ kind: match?'update(price+stock only)':'insert(hidden)', name:o.name, price_ugx:price, stock:stk, odoo_cat:rawCat, app_cat: match?'(unchanged)':mapCat(rawCat) });
      });
      if(!commit){ return { statusCode:200, headers, body: JSON.stringify({ ok:true, dry_run:true, plan:{ update:nUpdate, link_update:nLink, insert:nInsert }, sample:sample }) }; }
      var SK=process.env.SUPABASE_SERVICE_KEY||'';
      var H={ apikey:SK, Authorization:'Bearer '+SK, 'Content-Type':'application/json', Prefer:'return=minimal' };
      var done=0, errs=[];
      /* Existing products: real PATCH (update price/stock/link only — never name/category/flags). */
      for(var i=0;i<updates.length;i+=25){
        var chunk=updates.slice(i,i+25);
        var results=await Promise.all(chunk.map(function(row){
          return sbREST('products?id=eq.'+encodeURIComponent(row.id), { method:'PATCH', headers:H, body: JSON.stringify({ odoo_id:row.odoo_id, price_ugx:row.price_ugx, stock_qty:row.stock_qty }) })
            .then(function(r){ if(!r.ok && errs.length<3){ return r.text().then(function(t){ errs.push('update '+r.status+': '+t.slice(0,160)); return false; }); } return r.ok; })
            .catch(function(){ return false; });
        }));
        results.forEach(function(ok){ if(ok) done++; });
      }
      /* New products: plain insert (idempotent — re-runs match by name/odoo_id and become updates). */
      for(var j=0;j<inserts.length;j+=200){
        var batch=inserts.slice(j,j+200); if(!batch.length) continue;
        var ir=await sbREST('products', { method:'POST', headers:H, body: JSON.stringify(batch) });
        if(ir.ok){ done+=batch.length; } else { var t2=''; try{ t2=await ir.text(); }catch(e){} errs.push('insert '+ir.status+': '+t2.slice(0,200)); }
      }
      try{ await sbREST('settings?on_conflict=key', { method:'POST', headers:{ apikey:process.env.SUPABASE_SERVICE_KEY, Authorization:'Bearer '+process.env.SUPABASE_SERVICE_KEY, 'Content-Type':'application/json', Prefer:'resolution=merge-duplicates,return=minimal' }, body: JSON.stringify({ key:'odoo_last_sync', value:new Date().toISOString() }) }); }catch(e){}
      return { statusCode:200, headers, body: JSON.stringify({ ok:true, committed:done, total:(updates.length+inserts.length), updated:updates.length, inserted:inserts.length, errors:errs.slice(0,3) }) };
    }
    if(action === 'push_order'){
      var commit = (body.commit === true || q.commit === '1');
      var orderNo = body.order_number || q.order_number;
      if(!orderNo) return { statusCode:400, headers, body: JSON.stringify({ error:'order_number required' }) };
      var uid = await authenticate();
      /* ── Farmer/agent order (orders + order_items) ───────────────────────
         Diaspora gift orders are 'AM-D-...'; everything else is a farmer/agent
         shop order in the `orders` table. Idempotent via client_order_ref. */
      if(!/^AM-D-/i.test(orderNo)){
        var foRes = await sbREST('orders?order_number=eq.'+encodeURIComponent(orderNo)+'&select=*&limit=1');
        var fos=[]; try{ fos=await foRes.json(); }catch(e){}
        var fo = Array.isArray(fos)?fos[0]:null;
        if(!fo) return { statusCode:404, headers, body: JSON.stringify({ error:'Order not found: '+orderNo }) };
        var fForce = (body.force===true || q.force==='1');
        var existing = await execKw(uid,'sale.order','search',[[['client_order_ref','=',orderNo]]],{ limit:1 });
        if(existing && existing.length && !fForce){
          if(!commit) return { statusCode:200, headers, body: JSON.stringify({ ok:true, dry_run:true, order_number:orderNo, table:'orders', already_pushed:true, odoo_sale_order_id:existing[0] }) };
          return { statusCode:200, headers, body: JSON.stringify({ ok:true, already_pushed:true, odoo_sale_order_id:existing[0], note:'Already in Odoo; pass force=1 to re-create.' }) };
        }
        var fiRes = await sbREST('order_items?order_id=eq.'+encodeURIComponent(fo.id)+'&select=product_id,product_name,quantity,unit_price_ugx,total_ugx');
        var fitems=[]; try{ fitems=await fiRes.json(); }catch(e){} if(!Array.isArray(fitems)) fitems=[];
        var fpids=fitems.map(function(i){return i.product_id;}).filter(Boolean);
        var fmap={};
        if(fpids.length){ var fpr=await sbREST('products?id=in.('+fpids.join(',')+')&select=id,odoo_id,name'); var fprods=[]; try{ fprods=await fpr.json(); }catch(e){} (fprods||[]).forEach(function(p){ fmap[p.id]=p; }); }
        var ftmpl=Object.values(fmap).map(function(p){return p.odoo_id;}).filter(Boolean);
        var fvar={};
        if(ftmpl.length){ var fvrs=await execKw(uid,'product.product','search_read',[[['product_tmpl_id','in',ftmpl]]],{ fields:['id','product_tmpl_id'] }); (fvrs||[]).forEach(function(v){ var t=Array.isArray(v.product_tmpl_id)?v.product_tmpl_id[0]:v.product_tmpl_id; if(!fvar[t]) fvar[t]=v.id; }); }
        /* resolve partner: prefer app_users email, then phone, then name */
        var femail=null, fphone=fo.customer_phone||null;
        if(fo.customer_id){ try{ var ur=await sbREST('app_users?id=eq.'+encodeURIComponent(fo.customer_id)+'&select=email,phone,full_name&limit=1'); var us=await ur.json(); if(Array.isArray(us)&&us[0]){ femail=us[0].email||null; if(!fphone) fphone=us[0].phone||null; } }catch(e){} }
        var fpartner=null, fcreated=false, fdomain;
        if(femail) fdomain=[['email','=',femail]];
        else if(fphone) fdomain=[['phone','=',fphone]];
        else fdomain=[['name','=',fo.customer_name||'Customer']];
        var ff=await execKw(uid,'res.partner','search',[fdomain],{ limit:1 });
        if(ff&&ff.length){ fpartner=ff[0]; }
        else if(commit){ fpartner=await execKw(uid,'res.partner','create',[{ name: fo.customer_name||femail||'Customer', email: femail||false, phone: fphone||false, customer_rank:1, comment:'Created by Agro & More app' }]); fcreated=true; }
        var flines=[], fprev=[];
        fitems.forEach(function(it){
          var ap=fmap[it.product_id]; var variant = ap&&ap.odoo_id ? fvar[ap.odoo_id] : null;
          var price=Number(it.unit_price_ugx)||0;
          if(variant){ flines.push([0,0,{ product_id:variant, product_uom_qty: it.quantity||1, price_unit:price }]); fprev.push({ product:it.product_name, qty:it.quantity||1, odoo_product_id:variant, price_ugx:price }); }
          else { flines.push([0,0,{ name: it.product_name||'Item', product_uom_qty: it.quantity||1, price_unit:price }]); fprev.push({ product:it.product_name, qty:it.quantity||1, odoo_product_id:null, price_ugx:price, note:'no Odoo match — generic line' }); }
        });
        if(!commit){
          return { statusCode:200, headers, body: JSON.stringify({ ok:true, dry_run:true, order_number:orderNo, table:'orders', partner_id:fpartner, partner_will_be_created:!fpartner, lines:fprev }) };
        }
        var fso = await execKw(uid,'sale.order','create',[{ partner_id:fpartner, client_order_ref:orderNo, order_line:flines }]);
        return { statusCode:200, headers, body: JSON.stringify({ ok:true, order_number:orderNo, table:'orders', odoo_sale_order_id:fso, partner_id:fpartner, partner_created:fcreated, lines:flines.length }) };
      }
      var oRes = await sbREST('diaspora_orders?order_number=eq.'+encodeURIComponent(orderNo)+'&select=*&limit=1');
      var orders=[]; try{ orders=await oRes.json(); }catch(e){}
      var order = Array.isArray(orders) ? orders[0] : null;
      if(!order) return { statusCode:404, headers, body: JSON.stringify({ error:'Order not found: '+orderNo }) };
      if(order.odoo_order_id && !commit) { /* already pushed — still allow re-preview */ }
      var iRes = await sbREST('diaspora_order_items?diaspora_order_id=eq.'+encodeURIComponent(order.id)+'&select=product_id,product_name,quantity,unit_price_usd,total_usd');
      var items=[]; try{ items=await iRes.json(); }catch(e){} if(!Array.isArray(items)) items=[];
      /* map app product_id -> Odoo template id */
      var pids=items.map(function(i){return i.product_id;}).filter(Boolean);
      var prodMap={};
      if(pids.length){ var pr=await sbREST('products?id=in.('+pids.join(',')+')&select=id,odoo_id,name'); var prods=[]; try{ prods=await pr.json(); }catch(e){} (prods||[]).forEach(function(p){ prodMap[p.id]=p; }); }
      /* resolve template ids -> product.product (variant) ids */
      var tmplIds=Object.values(prodMap).map(function(p){return p.odoo_id;}).filter(Boolean);
      var variantOf={};
      if(tmplIds.length){ var vrs=await execKw(uid,'product.product','search_read',[[['product_tmpl_id','in',tmplIds]]],{ fields:['id','product_tmpl_id'] }); (vrs||[]).forEach(function(v){ var t=Array.isArray(v.product_tmpl_id)?v.product_tmpl_id[0]:v.product_tmpl_id; if(!variantOf[t]) variantOf[t]=v.id; }); }
      /* find-or-create partner */
      var partnerId=null, partnerCreated=false;
      var domain = order.payer_email ? [['email','=',order.payer_email]] : [['name','=',order.payer_name||'']];
      var found = await execKw(uid,'res.partner','search',[domain],{ limit:1 });
      if(found && found.length){ partnerId=found[0]; }
      else if(commit){ partnerId=await execKw(uid,'res.partner','create',[{ name: order.payer_name||order.payer_email||'Diaspora customer', email: order.payer_email||false, customer_rank:1, comment:'Created by Agro & More app' }]); partnerCreated=true; }
      /* build order lines */
      var lines=[], preview=[];
      items.forEach(function(it){
        var ap=prodMap[it.product_id]; var variant = ap && ap.odoo_id ? variantOf[ap.odoo_id] : null;
        if(variant){ lines.push([0,0,{ product_id: variant, product_uom_qty: it.quantity||1 }]); preview.push({ product:it.product_name, qty:it.quantity||1, odoo_product_id:variant }); }
        else { lines.push([0,0,{ name: it.product_name||'Item', product_uom_qty: it.quantity||1, price_unit: 0 }]); preview.push({ product:it.product_name, qty:it.quantity||1, odoo_product_id:null, note:'no Odoo match — generic line' }); }
      });
      if(!commit){
        return { statusCode:200, headers, body: JSON.stringify({ ok:true, dry_run:true, order_number:orderNo, partner_id:partnerId, partner_will_be_created: !partnerId, lines:preview, already_pushed: !!order.odoo_order_id }) };
      }
      if(order.odoo_order_id && !(body.force===true || q.force==='1')){
        return { statusCode:200, headers, body: JSON.stringify({ ok:true, already_pushed:true, odoo_sale_order_id: order.odoo_order_id, note:'Order already in Odoo; pass force=1 to re-create.' }) };
      }
      var soId = await execKw(uid,'sale.order','create',[{ partner_id: partnerId, client_order_ref: order.order_number, order_line: lines }]);
      try{ await sbREST('diaspora_orders?id=eq.'+encodeURIComponent(order.id), { method:'PATCH', headers:{ apikey:process.env.SUPABASE_SERVICE_KEY, Authorization:'Bearer '+process.env.SUPABASE_SERVICE_KEY, 'Content-Type':'application/json', Prefer:'return=minimal' }, body: JSON.stringify({ odoo_order_id: soId }) }); }catch(e){}
      return { statusCode:200, headers, body: JSON.stringify({ ok:true, order_number:orderNo, odoo_sale_order_id: soId, partner_id: partnerId, partner_created: partnerCreated, lines: lines.length }) };
    }
    if(action === 'cleanup_services'){
      var commit = (body.commit === true || q.commit === '1');
      var SK=process.env.SUPABASE_SERVICE_KEY||'';
      var uid = await authenticate();
      var svc = await execKw(uid,'product.template','search_read',[[['type','=','service']]],{ fields:['id','name'], limit:2000 });
      var ids = (svc||[]).map(function(x){return x.id;});
      if(!ids.length) return { statusCode:200, headers, body: JSON.stringify({ ok:true, odoo_services:0, note:'No service products in Odoo.' }) };
      var pr = await sbREST('products?odoo_id=in.('+ids.join(',')+')&select=id,name,odoo_id,show_on_shop&limit=2000');
      var matched=[]; try{ matched=await pr.json(); }catch(e){} if(!Array.isArray(matched)) matched=[];
      var toDelete = matched.filter(function(p){ return p.show_on_shop===false || p.show_on_shop==null; });
      if(!commit){
        return { statusCode:200, headers, body: JSON.stringify({ ok:true, dry_run:true, odoo_services:ids.length, matched_in_app:matched.length, would_delete:toDelete.length, sample: toDelete.slice(0,15).map(function(p){return p.name;}) }) };
      }
      var delIds = toDelete.map(function(p){return p.odoo_id;}); var done=0, errs=[];
      for(var i=0;i<delIds.length;i+=100){
        var batch=delIds.slice(i,i+100); if(!batch.length) continue;
        var r=await sbREST('products?odoo_id=in.('+batch.join(',')+')&show_on_shop=eq.false', { method:'DELETE', headers:{ apikey:SK, Authorization:'Bearer '+SK, 'Content-Type':'application/json', Prefer:'return=minimal' } });
        if(r.ok){ done+=batch.length; } else { var t=''; try{ t=await r.text(); }catch(e){} errs.push(r.status+': '+t.slice(0,160)); }
      }
      return { statusCode:200, headers, body: JSON.stringify({ ok:true, deleted: done, errors: errs }) };
    }
    if(action === 'ping'){
      const ver = await version();
      const uid = await authenticate();
      return { statusCode:200, headers, body: JSON.stringify({ ok:true, uid, server_version: ver && ver.server_version, db: DB() }) };
    }
    return { statusCode:400, headers, body: JSON.stringify({ error:'Unknown action: ' + action }) };
  }catch(e){
    return { statusCode:500, headers, body: JSON.stringify({ ok:false, error: String(e && e.message || e) }) };
  }
};
