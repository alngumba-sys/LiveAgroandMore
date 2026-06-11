async function wrap(){ var scr=()=>({dataset:{},querySelector:()=>({})}); var window={__sb:{}}; var sb={from:()=>({select:()=>({in:async()=>({data:[]}),eq:()=>({single:async()=>({})})})})};
  async function wireAgroBot(){
    var container = scr('advisory-7'); if(!container) return;
    if(container.dataset.botWired) return; container.dataset.botWired='1';
    var sb = window.__sb; if(!sb) return;

    /* ── 1) Fetch the WhatsApp escalation number once. ───────────
       Prefer the AgroBot-specific number the MD sets in admin
       (settings key 'chatbot_whatsapp_number'); fall back to the
       general support number ('whatsapp_number') only if it's blank. */
    var waNumber = '';
    try {
      var nRes = await sb.from('settings').select('key,value').in('key',['chatbot_whatsapp_number','whatsapp_number']);
}
