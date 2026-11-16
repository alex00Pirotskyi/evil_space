import { applyTransaction, extractOrderCode } from './casso_webhook.js';
import { authenticatedAdmin } from './menu.js';

const RELAY_PATH = '/api/admin/vcb-relay';
const CONFIRM_PATH = '/api/admin/vcb-confirm';
const LIMIT = 2048;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === RELAY_PATH && request.method === 'GET') return relayPage();
    if (url.pathname !== CONFIRM_PATH || request.method !== 'POST') return json({ok: false, error: 'Not found'}, 404);
    if (request.headers.get('origin') !== url.origin) return json({ok: false, error: 'Invalid origin'}, 403);
    const admin = await authenticatedAdmin(request, env);
    if (!admin) return json({ok: false, error: 'Sign in to Evil Space admin'}, 401);
    if (Number(request.headers.get('content-length') ?? 0) > LIMIT) return json({ok: false, error: 'Payload too large'}, 413);
    const raw = await request.text();
    if (new TextEncoder().encode(raw).length > LIMIT) return json({ok: false, error: 'Payload too large'}, 413);
    let body;
    try { body = JSON.parse(raw); } catch { return json({ok: false, error: 'Invalid JSON'}, 400); }
    const transaction = normalizeBookmarkletCredit(body);
    if (!transaction) return json({ok: true, status: 'ignored', reason: 'Unsupported transaction details or reference format'});
    const account = String(env.VIETQR_ACCOUNT_NUMBER ?? '');
    if (!/^\d{6,20}$/.test(account)) return json({ok: false, error: 'VietQR account not configured'}, 503);
    if (transaction.accountNumber !== account) return json({ok: true, status: 'ignored', reason: 'Selected VCB account differs from VietQR receiving account'});
    const status = await applyTransaction(env, transaction, 'vcb_browser');
    const reason = status === 'ignored' ? await explainUnmatched(env, transaction) : undefined;
    return json({ok: true, status, ...(reason ? {reason} : {}), orderCode: transaction.orderCode});
  },
};

export function normalizeBookmarkletCredit(body, now = Date.now()) {
  if (!body || body.source !== 'vcb_web_history' || body.direction !== 'credit') return null;
  const accountNumber = String(body.accountNumber ?? '');
  // VCB Digibank Web displays a reference such as '5389 - 10535'.
  // Normalize presentation whitespace, not the reference's identity.
  const reference = String(body.reference ?? '').trim().replace(/\s*[-–—]\s*/g, '-').replace(/\s+/g, '');
  const description = String(body.description ?? '').trim();
  const amountVnd = Number(body.amountVnd);
  const date = String(body.date ?? '');
  const orderCode = extractOrderCode(description);
  if (!/^\d{6,20}$/.test(accountNumber) || !/^[A-Za-z0-9._-]{6,80}$/.test(reference) ||
      !orderCode || description.length > 512 || !Number.isSafeInteger(amountVnd) ||
      amountVnd < 1 || amountVnd > 10_000_000_000 || !/^\d{2}\/\d{2}\/\d{4}$/.test(date)) return null;
  const [day, month, year] = date.split('/').map(Number);
  const utc = Date.UTC(year, month - 1, day);
  const check = new Date(utc);
  if (check.getUTCDate() !== day || check.getUTCMonth() + 1 !== month || check.getUTCFullYear() !== year) return null;
  const bankDate = check.toISOString().slice(0, 10);
  const vietnamDate = (ms) => new Date(ms + 7 * 3600000).toISOString().slice(0, 10);
  if (bankDate !== vietnamDate(now) && bankDate !== vietnamDate(now - 86400000)) return null;
  return {
    transactionId: 'acct:' + accountNumber + ':date:' + bankDate + ':ref:' + reference.toUpperCase(),
    bankReference: reference,
    transactionAt: null, // History exposes only a date.
    bankDate,
    accountNumber,
    amountVnd,
    description,
    orderCode,
  };
}

async function explainUnmatched(env, transaction) {
  const order = await env.evil_space.prepare(`
    SELECT status, amount_vnd, created_at FROM menu_orders
    WHERE order_code = ? LIMIT 1
  `).bind(transaction.orderCode).first();
  if (!order) return 'No checkout order with this EVIL code';
  if (String(order.status) === 'paid') return 'Checkout already paid (possibly via Telegram)';
  if (String(order.status) !== 'pending') return 'Checkout is no longer pending';
  if (Number(order.amount_vnd) !== transaction.amountVnd) return 'Transfer amount differs from checkout total';
  const created = Number(order.created_at);
  const now = Math.floor(Date.now() / 1000);
  const vietnamDay = (seconds) => new Date((seconds + 7 * 3600) * 1000).toISOString().slice(0, 10);
  if (!Number.isSafeInteger(created) || created > now + 120 || now - created > 172800 ||
      transaction.bankDate < vietnamDay(created) || transaction.bankDate > vietnamDay(now)) {
    return 'Transfer date does not match active checkout';
  }
  return 'Transaction did not pass final order checks';
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {status, headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  }});
}

function relayPage() {
  return new Response(RELAY_HTML, {headers: {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    'content-security-policy': "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'",
  }});
}

const RELAY_HTML = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Evil Space · VCB relay</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
 body{background:#141619;color:#f5f6f6;font:14px system-ui;margin:0;padding:22px}
 small{letter-spacing:2px;color:#b9f3d0}h2{font-size:22px;margin:13px 0}
 #status{padding:13px;border:1px solid #434c4c;border-radius:10px;background:#252c2d;min-height:22px}
 p{color:#b6bec0;line-height:1.5}a{color:#b9f3d0}
 button{border:0;border-radius:8px;background:#b9f3d0;color:#101a14;font-weight:700;padding:11px 14px;cursor:pointer}
 #last{font-size:12px;margin-top:14px;overflow-wrap:anywhere}
</style></head><body><small>EVIL SPACE · VCB WATCH</small>
<h2>Payment relay</h2><div id="status">Checking Evil Space login…</div>
<p>Uses your existing Evil Space admin session. Keep this window open while the bookmarklet is running.</p>
<p><a href="/admin" target="_blank" rel="noopener">Sign in to Evil Space admin</a></p>
<button id="check">Check connection</button><div id="last"></div>
<script>
(() => {
 'use strict';
 const BANK = 'https://vcbdigibank.vietcombank.com.vn';
 const text = document.getElementById('status');
 const last = document.getElementById('last');
 let authorized = false;
 function reply(kind, fields) {
   if (window.opener && !window.opener.closed) window.opener.postMessage(Object.assign({kind},fields||{}),BANK);
 }
 async function checkSession() {
   try {
     const response = await fetch('/api/admin/session', {credentials:'same-origin',cache:'no-store'});
     const data = await response.json();
     authorized = response.ok && data.authenticated === true;
     text.textContent = authorized ? 'Connected · Watching for VCB payments' : 'Sign in to Evil Space admin, then click Check connection';
   } catch (_) {
     authorized = false;
     text.textContent = 'Connection unavailable. Try again.';
   }
   reply('EVIL_VCB_READY',{authorized});
 }
 document.getElementById('check').addEventListener('click',checkSession);
 window.addEventListener('message', async (event) => {
   if (event.origin !== BANK || event.source !== window.opener || !event.data || event.data.kind !== 'EVIL_VCB_CREDIT') return;
   const id = String(event.data.id || '').slice(0,200);
   if (!id || !authorized) { reply('EVIL_VCB_ACK',{id,status:'login-required'}); return; }
   try {
     const response = await fetch('/api/admin/vcb-confirm', {
       method:'POST', credentials:'same-origin',
       headers:{'Content-Type':'application/json'}, body:JSON.stringify(event.data.credit),
     });
     const data = await response.json();
     if (response.status === 401) { authorized = false; await checkSession(); }
     const status = response.ok && data.ok ? data.status : 'retry';
     const reason = response.ok && data.ok ? String(data.reason || '') : 'HTTP ' + response.status + ' ' + String(data.error || '');
     last.textContent = status + (reason ? ' · ' + reason : '') + ' · EVIL ' + (data.orderCode || '') + ' · ' + new Date().toLocaleTimeString();
     reply('EVIL_VCB_ACK',{id,status,reason});
   } catch (_) { reply('EVIL_VCB_ACK',{id,status:'retry',reason:'Could not reach Evil Space server'}); }
 });
 checkSession();
 setInterval(checkSession,30000);
})();
</script></body></html>`;
