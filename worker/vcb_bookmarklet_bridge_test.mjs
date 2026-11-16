import test from 'node:test';
import assert from 'node:assert/strict';
import bridge, {normalizeBookmarkletCredit} from './vcb_bookmarklet_bridge.js';

const account = '0123456789';
const vnDate = () => {
  const t = new Date(Date.now() + 7 * 3600000);
  return [String(t.getUTCDate()).padStart(2, '0'),
    String(t.getUTCMonth() + 1).padStart(2, '0'),t.getUTCFullYear()].join('/');
};
const credit = () => ({
  source:'vcb_web_history', direction:'credit', accountNumber:account,
  reference:'FT2611161234', amountVnd:250000, description:'NAPAS EVIL ABC234', date:vnDate(),
});

test('extracts a valid incoming VCB history credit', () => {
  const tx=normalizeBookmarkletCredit(credit());
  assert.equal(tx.orderCode,'ABC234');
  assert.equal(tx.amountVnd,250000);
  assert.equal(tx.transactionId,'acct:0123456789:date:'+tx.bankDate+':ref:FT2611161234');
  assert.equal(tx.transactionAt,null);
});
test('accepts VCB Digibank Web space-padded numeric reference', () => {
  const tx = normalizeBookmarkletCredit({
    ...credit(),
    description:'EVIL VLWYLT#SP#BANKTRANSFER',
    reference:'5389 - 10535',
    amountVnd:25000,
  });
  assert.equal(tx.orderCode,'VLWYLT');
  assert.equal(tx.amountVnd,25000);
  assert.equal(tx.bankReference,'5389-10535');
  assert.match(tx.transactionId,/date:\\d{4}-\\d{2}-\\d{2}:ref:5389-10535$/);
});
test('rejects invalid credits and forged order codes', () => {
  for(const bad of [
    {direction:'debit'},{source:'other'},{reference:''},
    {amountVnd:0},{amountVnd:-1},{accountNumber:'123'},
    {description:'No EVIL code'},{description:'EVIL O0I1LZ'},
    {date:'31/02/2026'},{date:'01/01/2020'},
  ]) assert.equal(normalizeBookmarkletCredit({...credit(),...bad}),null);
});
test('serves a same-site relay without new secret configuration', async () => {
  const r=await bridge.fetch(new Request('https://evils.space/api/admin/vcb-relay'),{});
  assert.equal(r.status,200);
  assert.match(await r.text(),/api\/admin\/vcb-confirm/);
});
test('rejects cross-site posts and requests without admin login',async () => {
  const url='https://evils.space/api/admin/vcb-confirm';
  const cross=new Request(url,{method:'POST',headers:{Origin:'https://attacker.test'},body:JSON.stringify(credit())});
  assert.equal((await bridge.fetch(cross,{})).status,403);
  const noAdmin=new Request(url,{method:'POST',headers:{Origin:'https://evils.space'},body:JSON.stringify(credit())});
  assert.equal((await bridge.fetch(noAdmin,{})).status,401);
});
function makeDb() {
  let order={id:17,order_code:'ABC234',amount_vnd:250000,status:'pending',
    created_at:Math.floor(Date.now()/1000)-30,checkout_revision:0,
    payment_provider:null,payment_transaction_id:null};
  const db={
    prepare(sql) {
      return {bind(...params) {
        return {
          async first() {
            if(sql.includes('FROM admin_sessions')) return {id:1,email:'admin@example.test'};
            if(sql.includes('FROM menu_orders')) return {...order};
            return null;
          },
          async run() {
            if(sql.includes("SET status = 'paid'") && order.status==='pending') {
              order={...order,status:'paid',payment_provider:params[1],
                payment_transaction_id:params[2]};
              return {meta:{changes:1}};
            }
            return {meta:{changes:0}};
          },
        };
      }};
    },
    async batch(_) {return [];},
  };
  return {db,getOrder:()=>order};
}
test('returns a clear diagnostic for unknown checkout order', async () => {
  const {db}=makeDb();
  const env={evil_space:db,VIETQR_ACCOUNT_NUMBER:account};
  const url='https://evils.space/api/admin/vcb-confirm';
  const headers={Origin:'https://evils.space',Cookie:'__Host-evil_admin_session='+('A'.repeat(48))};
  const request=new Request(url,{method:'POST',headers,body:JSON.stringify({
    ...credit(),reference:'5389 - 10535',amountVnd:200000,
  })});
  const r=await bridge.fetch(request,env);
  assert.equal(r.status,200);
  const data=await r.json();
  assert.equal(data.status,'ignored');
  assert.match(data.reason,/amount differs/i);
});
test('admin relay marks exact matching order once and ignores mismatches',async()=>{
  const {db,getOrder}=makeDb();
  const env={evil_space:db,VIETQR_ACCOUNT_NUMBER:account};
  const url='https://evils.space/api/admin/vcb-confirm';
  const headers={Origin:'https://evils.space',Cookie:'__Host-evil_admin_session='+('A'.repeat(48))};
  const send=(v)=>bridge.fetch(new Request(url,{
    method:'POST',headers,body:JSON.stringify(v),
  }),env);
  const mismatch=await send({...credit(),amountVnd:200000});
  assert.equal((await mismatch.json()).status,'ignored');
  assert.equal(getOrder().status,'pending');
  const ok=await send(credit());
  assert.equal((await ok.json()).status,'matched');
  assert.equal(getOrder().status,'paid');
  const replay=await send(credit());
  assert.equal((await replay.json()).status,'already_paid');
});
