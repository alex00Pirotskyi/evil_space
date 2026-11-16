import test from 'node:test';
import assert from 'node:assert/strict';
import webhook, { normalizeBrowserTransaction } from './vcb_browser_webhook.js';

const secret = 'x'.repeat(48);
const accountNumber = '0123456789';
const source = {
  source: 'vcb_web_history', direction: 'credit', accountNumber,
  reference: 'FT2611160023', amountVnd: 250000, orderCode: 'ABC234',
};
test('bank history credit is validated; debit, invalid dates, and amounts are rejected', () => {
  const epoch = Date.parse('2026-11-16T08:40:00Z');
  const valid = { ...source, date: '16/11/2026' };
  const result = normalizeBrowserTransaction(valid, epoch);
  assert.equal(result.orderCode, 'ABC234');
  assert.equal(result.transactionId, 'ref:FT2611160023');
  assert.equal(result.amountVnd, 250000);
  for (const changes of [
    { direction: 'debit' }, { source: 'anything_else' }, { reference: '' },
    { accountNumber: '123' }, { date: '31/02/2026' },
    { date: '10/11/2026' }, { amountVnd: -1 }, { orderCode: 'AAAAAA0' },
  ]) assert.equal(normalizeBrowserTransaction({...valid, ...changes},epoch),null);
});

async function post(body,{origin='https://vcbdigibank.vietcombank.com.vn',badSignature=false}={}) {
  const raw = JSON.stringify(body);
  const stamp = String(Math.floor(Date.now()/1000));
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw',encoder.encode(secret),
    {name:'HMAC',hash:'SHA-256'},false,['sign']);
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC',key,encoder.encode(stamp+'\n'+raw)));
  const signature = badSignature ? '0'.repeat(64) : Array.from(mac,n=>n.toString(16).padStart(2,'0')).join('');
  return new Request('https://evils.space/api/webhooks/vcb-browser',{
    method:'POST',
    headers:{Origin:origin,'Content-Type':'application/json','X-Evil-Timestamp':stamp,'X-Evil-Signature':signature},
    body:raw,
  });
}
const env = {VCB_BROWSER_HMAC_SECRET:secret,VIETQR_ACCOUNT_NUMBER:accountNumber};
test('requires signed messages and accepts correctly signed ping',async()=>{
  const ping=await webhook.fetch(await post({type:'ping'}),env);
  assert.equal(ping.status,200);
  assert.equal((await ping.json()).type,'pong');
  assert.equal((await webhook.fetch(await post({type:'ping'},{badSignature:true}),env)).status,401);
  assert.equal((await webhook.fetch(await post({type:'ping'},{origin:'https://attacker.example'}),env)).status,403);
});
test('allows extension service-worker origin, rejects disallowed origins',async()=>{
  const r=await webhook.fetch(await post({type:'ping'},{origin:'chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}),env);
  assert.equal(r.status,200);
  assert.equal(r.headers.get('Access-Control-Allow-Origin'),'chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
});
test('rejects mismatched account before database lookup',async()=>{
  const r=await webhook.fetch(await post({...source,date:'16/11/2026'}),{
    ...env,VIETQR_ACCOUNT_NUMBER:'9999999999'
  });
  assert.equal((await r.json()).status,'ignored');
});
