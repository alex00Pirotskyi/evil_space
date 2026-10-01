import assert from 'node:assert/strict';
import { createHash, pbkdf2Sync, randomBytes, randomInt } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { buildSeo } from '../tool/build_seo.mjs';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const wranglerVersion = readFileSync(
  path.join(repoRoot, 'tool', 'wrangler_version.txt'),
  'utf8',
).trim();
const npxInvocation = resolveNpxInvocation();
const persistDir = path.join(repoRoot, '.wrangler', 'integration-test');
const testAssetsDir = path.join(persistDir, 'assets');
const port = 8794;
const baseUrl = `http://127.0.0.1:${port}`;
const adminEmail = `ci-${randomBytes(6).toString('hex')}@example.invalid`;
const reviewAdminEmail = `review-${randomBytes(6).toString('hex')}@example.invalid`;
const adminPassword = randomBytes(24).toString('base64url');
const reviewApprovalToken = randomBytes(32).toString('base64url');
const testPaymentAccount = String(randomInt(1000000000, 10000000000));
const liveCustomerToken = randomBytes(32).toString('base64url');
const otherCustomerToken = randomBytes(32).toString('base64url');
let dev = null;
let devOutput = '';

try {
  assert.match(wranglerVersion, /^4\.\d+\.\d+$/);
  await removePathWithRetry(persistDir, { required: true });
  mkdirSync(testAssetsDir, { recursive: true });
  writeFileSync(
    path.join(testAssetsDir, 'index.html'),
    readFileSync(path.join(repoRoot, 'web', 'index.html'), 'utf8'),
  );
  await buildSeo(testAssetsDir);

  console.log('Integration: applying clean local D1 migrations');
  await runWrangler([
    'd1',
    'migrations',
    'apply',
    'evil-space',
    '--local',
    '--persist-to',
    persistDir,
  ]);

  console.log('Integration: seeding admin fixtures');
  await seedAdmins();

  console.log('Integration: starting local Worker');
  dev = startDev();
  await waitForServer();

  console.log('Integration: running API flow');
  await runFlow();
  console.log('Integration: checking root-only search routes');
  await runSeoFlow();
  console.log('Worker integration flow passed.');
} finally {
  await stopDev();
  await removePathWithRetry(persistDir);
}

function resolveNpxInvocation() {
  if (process.platform !== 'win32') {
    return { executable: 'npx', prefixArgs: [] };
  }

  const searchDirs = new Set([
    path.dirname(process.execPath),
    ...(process.env.PATH ?? '')
      .split(path.delimiter)
      .map((entry) => entry.trim().replace(/^"|"$/g, ''))
      .filter(Boolean),
  ]);
  for (const directory of searchDirs) {
    const cli = path.join(directory, 'node_modules', 'npm', 'bin', 'npx-cli.js');
    if (existsSync(cli)) {
      return { executable: process.execPath, prefixArgs: [cli] };
    }
  }

  throw new Error(
    'Could not locate npm npx-cli.js on Windows. Reinstall Node.js with npm or add the Node.js directory to PATH.',
  );
}

function wranglerArgs(args) {
  return [
    ...npxInvocation.prefixArgs,
    '--yes',
    `wrangler@${wranglerVersion}`,
    ...args,
  ];
}

async function runWrangler(args, { timeoutMs = 120000 } = {}) {
  const result = await runProcess(
    npxInvocation.executable,
    wranglerArgs(args),
    {
      timeoutMs,
      input: 'y\n',
      echo: true,
    },
  );
  if (result.code !== 0) {
    throw new Error(
      `Wrangler failed (${result.code}): ${args.join(' ')}\n${result.output}`,
    );
  }
  return result.output;
}

function runProcess(
  executable,
  args,
  { timeoutMs, input = '', echo = false } = {},
) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, {
      cwd: repoRoot,
      detached: process.platform !== 'win32',
      env: {
        ...process.env,
        CI: 'true',
        WRANGLER_SEND_METRICS: 'false',
      },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let output = '';
    let settled = false;
    let timer = null;

    const collect = (chunk) => {
      const text = chunk.toString();
      output += text;
      if (echo) process.stdout.write(text);
    };
    child.stdout.on('data', collect);
    child.stderr.on('data', collect);

    const finish = (callback) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      callback();
    };

    child.on('error', (error) => {
      finish(() => reject(error));
    });
    child.on('exit', (code, signal) => {
      finish(() => resolve({ code: code ?? (signal ? 1 : 0), output }));
    });

    if (input) child.stdin.end(input);
    else child.stdin.end();

    if (timeoutMs != null) {
      timer = setTimeout(() => {
        if (settled) return;
        killProcessTree(child);
        finish(() =>
          reject(
            new Error(
              `${executable} ${args.join(' ')} timed out after ${timeoutMs} ms.\n${output}`,
            ),
          ),
        );
      }, timeoutMs);
    }
  });
}

async function seedAdmins() {
  const now = Math.floor(Date.now() / 1000);
  const salt = randomBytes(16);
  const saltBase64 = salt.toString('base64');
  const passwordHash = pbkdf2Sync(
    adminPassword,
    salt,
    50000,
    32,
    'sha256',
  ).toString('base64');
  const reviewHash = createHash('sha256')
    .update(reviewApprovalToken)
    .digest('base64url');

  const sql = `
    INSERT INTO customers (id, name, created_at, updated_at)
      VALUES (9001, 'Live checkout customer', ${now}, ${now}),
             (9002, 'Other checkout customer', ${now}, ${now});
    INSERT INTO customer_sessions (customer_id, token_hash, created_at, expires_at, last_seen_at)
      VALUES (9001, ${sqlString(createHash('sha256').update(liveCustomerToken).digest('base64url'))}, ${now}, ${now + 3600}, ${now}),
             (9002, ${sqlString(createHash('sha256').update(otherCustomerToken).digest('base64url'))}, ${now}, ${now + 3600}, ${now});
    INSERT INTO marketing_promotions (id, promo_key, name, discount_type, discount_value,
      distribution_type, max_total_uses, created_at, created_by_email)
      VALUES (9101, 'LIVE10', 'Ten thousand off', 'fixed_vnd', 10000, 'manual', NULL, ${now}, 'test'),
             (9102, 'LIVE20', 'Twenty thousand off', 'fixed_vnd', 20000, 'manual', NULL, ${now}, 'test'),
             (9103, 'LIVE_LIMIT', 'Limited campaign', 'fixed_vnd', 5000, 'manual', 1, ${now}, 'test');
    INSERT INTO marketing_promotion_groups (promotion_id, group_key)
      VALUES (9101, 'beverages'), (9102, 'beverages'), (9103, 'beverages');
    INSERT INTO customer_promo_grants (id, customer_id, promotion_id, granted_uses, granted_at)
      VALUES (9201, 9001, 9101, 1, ${now}), (9202, 9001, 9102, 1, ${now}),
             (9203, 9001, 9103, 1, ${now}), (9204, 9002, 9103, 1, ${now});
    CREATE TRIGGER test_cart_insert_failure BEFORE INSERT ON menu_order_items
      WHEN NEW.quantity = 19 BEGIN SELECT RAISE(ABORT, 'forced test insert failure'); END;
    DELETE FROM admins WHERE email IN (${sqlString(adminEmail)}, ${sqlString(reviewAdminEmail)});
    INSERT INTO admins
      (email, password_hash, password_salt, status, approval_token_hash,
       approval_expires_at, created_at, approved_at)
    VALUES
      (${sqlString(adminEmail)}, ${sqlString(passwordHash)}, ${sqlString(saltBase64)},
       'approved', NULL, NULL, ${now}, ${now});
    INSERT INTO admins
      (email, password_hash, password_salt, status, approval_token_hash,
       approval_expires_at, created_at, approved_at)
    VALUES
      (${sqlString(reviewAdminEmail)}, ${sqlString(passwordHash)}, ${sqlString(saltBase64)},
       'pending', ${sqlString(reviewHash)}, ${now + 3600}, ${now}, NULL);
  `;
  const seedFile = path.join(persistDir, 'admin-seed.sql');
  writeFileSync(seedFile, sql, 'utf8');

  await runWrangler([
    'd1',
    'execute',
    'evil-space',
    '--local',
    '--persist-to',
    persistDir,
    '--file',
    seedFile,
  ]);
}

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function startDev() {
  const child = spawn(
    npxInvocation.executable,
    wranglerArgs([
      'dev',
      '--local',
      '--assets',
      testAssetsDir,
      '--persist-to',
      persistDir,
      '--ip',
      '127.0.0.1',
      '--port',
      String(port),
      '--var',
      `VIETQR_ACCOUNT_NUMBER:${testPaymentAccount}`,
      '--var',
      'EVIL_SPACE_DISABLE_STATUS_CACHE:1',
      '--log-level',
      'warn',
    ]),
    {
      cwd: repoRoot,
      detached: process.platform !== 'win32',
      env: {
        ...process.env,
        CI: 'true',
        WRANGLER_SEND_METRICS: 'false',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );

  const collect = (chunk) => {
    const text = chunk.toString();
    devOutput += text;
    process.stdout.write(text);
  };
  child.stdout.on('data', collect);
  child.stderr.on('data', collect);
  return child;
}

async function waitForServer() {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (dev?.exitCode !== null) {
      throw new Error(`Wrangler dev exited early.\n${devOutput}`);
    }
    try {
      const response = await fetch(`${baseUrl}/api/health`, {
        signal: AbortSignal.timeout(1000),
      });
      if (response.status === 200) return;
    } catch {}
    await delay(200);
  }
  throw new Error(`Wrangler dev did not become ready.\n${devOutput}`);
}

async function runSeoFlow() {
  const root = await http('/');
  assert.equal(root.status, 200);
  assert.match(await root.text(), /<title>Evil Space \| Coworking Space in Nha Trang<\/title>/);
  for (const lang of ['en', 'ru', 'vi']) {
    for (const slug of ['/', '/pricing/', '/visit/']) {
      const redirect = await fetch(`${baseUrl}/${lang}${slug}`, { redirect: 'manual' });
      assert.equal(redirect.status, 301);
      // Wrangler dev rewrites the redirect host to its local origin.
      assert.equal(new URL(redirect.headers.get('location')).pathname, '/');
    }

    const unknown = await http(`/${lang}/this-page-does-not-exist`);
    assert.equal(unknown.status, 404);
  }

  const robots = await http('/robots.txt');
  assert.equal(robots.status, 200);
  assert.match(await robots.text(), /Sitemap: https:\/\/evils\.space\/sitemap\.xml/);
  const sitemap = await http('/sitemap.xml');
  assert.equal(sitemap.status, 200);
  assert.deepEqual([...((await sitemap.text()).matchAll(/<loc>([^<]+)<\/loc>/g))].map((m) => m[1]), ['https://evils.space/']);
  const admin = await http('/admin');
  assert.equal(admin.headers.get('x-robots-tag'), 'noindex, follow');
}

async function runFlow() {
  let response = await http('/api/public/not-a-route');
  assert.equal(response.status, 404);

  response = await http('/api/admin/operations');
  assert.equal(response.status, 401);

  response = await jsonRequest('/api/admin/login', {
    email: adminEmail,
    password: adminPassword,
  });
  assert.equal(response.status, 200);
  const setCookie = response.headers.get('set-cookie');
  assert.ok(setCookie?.includes('__Host-evil_admin_session='));
  const cookie = setCookie.split(';', 1)[0];

  response = await http('/api/admin/session', {
    headers: { Cookie: cookie },
  });
  assert.equal(response.status, 200);
  let payload = await response.json();
  assert.equal(payload.authenticated, true);
  assert.equal(payload.email, adminEmail);

  response = await jsonRequest(
    '/api/admin/menu/upload',
    {
      version: 1,
      groups: [
        {
          id: 'beverages',
          name: 'Beverages',
          items: [
            {
              id: 'cola',
              name: 'Cola',
              priceVnd: 30000,
              description: null,
            },
            {
              id: 'americano',
              name: 'Americano',
              priceVnd: 45000,
              description: null,
              options: [
                {
                  id: 'size',
                  type: 'single',
                  name: { en: 'Size', ru: 'Размер', vi: 'Kích cỡ' },
                  required: true,
                  default: 'small',
                  values: [
                    {
                      id: 'small',
                      name: { en: '0.2 L', ru: '0.2 л', vi: '0.2 L' },
                      priceDeltaVnd: 0,
                    },
                    {
                      id: 'large',
                      name: { en: '0.3 L', ru: '0.3 л', vi: '0.3 L' },
                      priceDeltaVnd: 15000,
                    },
                  ],
                },
                {
                  id: 'strength',
                  type: 'dots',
                  name: { en: 'Strength', ru: 'Крепость', vi: 'Độ đậm' },
                  min: 1,
                  max: 3,
                  default: 1,
                  pricePerStepVnd: 20000,
                },
                {
                  id: 'extras',
                  type: 'multiple',
                  name: { en: 'Extras', ru: 'Добавки', vi: 'Thêm' },
                  values: [
                    {
                      id: 'milk',
                      name: { en: 'Milk', ru: 'Молоко', vi: 'Sữa' },
                      priceDeltaVnd: 5000,
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
    { Cookie: cookie },
  );
  assert.equal(response.status, 201);
  payload = await response.json();
  assert.equal(payload.snapshot.catalog.version, 1);
  assert.equal(payload.snapshot.catalog.groups[0].items[0].priceVnd, 30000);
  assert.equal(payload.snapshot.paymentConfigured, true);

  response = await http('/api/public/menu');
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.menu.groups[0].items[0].id, 'cola');
  assert.equal(payload.menu.groups[0].items[0].priceVnd, 30000);

  const americano = payload.menu.groups[0].items.find((item) => item.id === 'americano');
  assert.ok(americano);
  assert.equal(americano.options.length, 3);
  assert.equal(americano.options[0].name.ru, 'Размер');

  response = await jsonRequest('/api/public/menu/order', {
    items: [
      {
        itemId: 'americano',
        quantity: 1,
        options: {
          size: 'large',
          strength: 2,
          extras: ['milk'],
        },
      },
    ],
  });
  assert.equal(response.status, 201);
  const configuredOrder = (await response.json()).order;
  assert.equal(configuredOrder.amountVnd, 85000);
  assert.match(configuredOrder.itemName, /Americano/);
  assert.match(configuredOrder.itemName, /0\.3 L/);
  assert.match(configuredOrder.itemName, /Milk/);

  response = await jsonRequest('/api/public/menu/order', {
    itemId: 'cola',
    priceVnd: 1,
  });
  assert.equal(response.status, 201);
  const menuOrder = (await response.json()).order;
  assert.equal(menuOrder.itemName, 'Cola');
  assert.equal(menuOrder.amountVnd, 30000);
  assert.match(menuOrder.paymentMessage, /^EVIL [A-Z2-9]{6}$/);
  assert.match(menuOrder.qrPayload, /5303704540530000/);
  assert.ok(typeof menuOrder.token === 'string' && menuOrder.token.length >= 32);

  response = await http(
    `/api/public/menu/order?token=${encodeURIComponent(menuOrder.token)}`,
  );
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.order.status, 'pending');
  assert.equal(payload.order.amountVnd, 30000);

  response = await http('/api/admin/menu', { headers: { Cookie: cookie } });
  assert.equal(response.status, 200);
  payload = await response.json();
  const adminMenuOrder = payload.snapshot.orders.find(
    (row) => row.orderCode === menuOrder.orderCode,
  );
  assert.ok(adminMenuOrder?.id);

  response = await jsonRequest(
    '/api/admin/menu/order/paid',
    { id: adminMenuOrder.id },
    { Cookie: cookie },
  );
  assert.equal(response.status, 200);

  response = await http(
    `/api/public/menu/order?token=${encodeURIComponent(menuOrder.token)}`,
  );
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.order.status, 'paid');

  await runLiveCartFlow(cookie);

  response = await http('/api/public/status');
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.ok, true);
  assert.ok(Number(payload.status.total) > 0);

  const contactValue = `@integration_${randomBytes(6).toString('hex')}`;
  response = await jsonRequest('/api/public/book', {
    name: 'Integration Test',
    contactType: 'telegram',
    contactValue,
    serviceDate: nhaTrangDateKey(),
    language: 'en',
  });
  assert.equal(response.status, 201);
  const booking = await response.json();
  assert.equal(booking.ok, true);
  assert.equal(booking.status, 'pending');
  assert.ok(typeof booking.token === 'string' && booking.token.length >= 32);

  response = await http(
    `/api/public/booking?token=${encodeURIComponent(booking.token)}`,
  );
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.status, 'pending');

  response = await http('/api/admin/operations', {
    headers: { Cookie: cookie },
  });
  assert.equal(response.status, 200);
  payload = await response.json();
  const requestRow = payload.snapshot.booking_requests.find(
    (row) => row.contact_value === contactValue,
  );
  assert.ok(requestRow?.id);

  response = await jsonRequest(
    '/api/admin/booking/accept',
    { id: requestRow.id },
    { Cookie: cookie },
  );
  assert.equal(response.status, 200);

  response = await http(
    `/api/public/booking?token=${encodeURIComponent(booking.token)}`,
  );
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.status, 'accepted');

  response = await http('/api/public/status');
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.ok(Number(payload.status.occupied) >= 1);

  const reviewToken = reviewApprovalToken;
  response = await http(
    `/api/admin/review?token=${encodeURIComponent(reviewToken)}`,
  );
  assert.equal(response.status, 200);
  let html = await response.text();
  assert.match(html, /APPROVE ADMIN/);
  assert.match(html, /REJECT ADMIN/);

  response = await http('/api/admin/decision', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Origin: baseUrl,
    },
    body: new URLSearchParams({ token: reviewToken, decision: 'reject' }),
  });
  assert.equal(response.status, 200);
  html = await response.text();
  assert.match(html, /Admin rejected/);

  response = await http(
    `/api/admin/review?token=${encodeURIComponent(reviewToken)}`,
  );
  assert.equal(response.status, 404);

  response = await jsonRequest('/api/admin/logout', {}, { Cookie: cookie });
  assert.equal(response.status, 200);

  response = await http('/api/admin/session', {
    headers: { Cookie: cookie },
  });
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.authenticated, false);
}

async function runLiveCartFlow(adminCookie) {
  const customerCookie = `__Host-evil_customer_session=${liveCustomerToken}`;
  const otherCookie = `__Host-evil_customer_session=${otherCustomerToken}`;
  const headers = {Cookie: customerCookie};
  const items = [{itemId: 'cola', quantity: 2}];
  const token = randomBytes(32).toString('base64url');
  async function post(endpoint, body, who = headers) {
    // Separate these fixtures from earlier legacy checkout scenarios. A fast
    // local run must not exhaust the six-creates-per-minute production limit.
    const testIp = who.Cookie === customerCookie ? '192.0.2.101'
      : who.Cookie === otherCookie ? '192.0.2.102' : '192.0.2.103';
    const response = await jsonRequest(`/api/public/menu/${endpoint}`, body,
      {...who, 'CF-Connecting-IP': testIp});
    const data = await response.json();
    return {response, data};
  }
  async function wallet(who = headers) {
    const response = await http('/api/public/account/promos', {headers: who});
    assert.equal(response.status, 200);
    return (await response.json()).promos;
  }
  async function grant(id) { return (await wallet()).find(p => p.id === id); }
  async function adminOrder(code) {
    const response = await http('/api/admin/menu', {headers: {Cookie: adminCookie}});
    return (await response.json()).snapshot.orders.find(o => o.orderCode === code);
  }
  let result = await post('order', {token, items, promoGrantId: 9201, amountVnd: 1});
  assert.equal(result.response.status, 201, JSON.stringify(result.data));
  const initial = result.data.order;
  assert.equal(initial.amountVnd, 50000);
  assert.equal(initial.expiresAt, 0);

  // Legacy pending payments and their promo reservation remain valid even
  // after their old deadline. No data migration or recreation is required.
  const tokenHash = createHash('sha256').update(token).digest('base64url');
  const legacyFile = path.join(persistDir, 'legacy-checkout-expiry.sql');
  writeFileSync(legacyFile, `
    UPDATE menu_orders SET expires_at = 1 WHERE public_token_hash = ${sqlString(tokenHash)};
    UPDATE promo_redemptions SET expires_at = 1 WHERE order_type = 'menu'
      AND order_id IN (SELECT id FROM menu_orders WHERE public_token_hash = ${sqlString(tokenHash)});
  `);
  await runWrangler(['d1', 'execute', 'evil-space', '--local', '--persist-to', persistDir, '--file', legacyFile]);
  const oldStatus = await http(`/api/public/menu/order?token=${encodeURIComponent(token)}`);
  assert.equal(oldStatus.status, 200);
  const oldOrder = (await oldStatus.json()).order;
  assert.equal(oldOrder.status, 'pending');
  assert.equal(oldOrder.expiresAt, 0);
  assert.equal((await grant(9201)).reservedUses, 1);

  // A lost create response/retry updates the same order and never reserves twice.
  result = await post('order', {token, items, promoGrantId: 9201});
  assert.equal(result.response.status, 200);
  assert.equal(result.data.order.orderCode, initial.orderCode);
  assert.equal((await grant(9201)).reservedUses, 1);

  result = await post('promos', {items, paymentToken: token});
  assert.ok(result.data.promos.some(p => p.grantId === 9201));
  result = await post('promos', {items});
  assert.ok(!result.data.promos.some(p => p.grantId === 9201));
  result = await post('promos', {items, paymentToken: token}, {Cookie: otherCookie});
  assert.ok(!result.data.promos.some(p => p.grantId === 9201));

  result = await post('order/update', {token, items: [{itemId: 'cola', quantity: 3}], promoGrantId: 9201});
  assert.equal(result.response.status, 200);
  assert.equal(result.data.order.amountVnd, 80000);
  assert.equal(result.data.order.paymentMessage, initial.paymentMessage);
  assert.notEqual(result.data.order.qrPayload, initial.qrPayload);
  assert.equal((await grant(9201)).reservedUses, 1);

  // Switching, removing and reapplying promos reuse the redemption row safely.
  result = await post('order/update', {token, items, promoGrantId: 9202});
  assert.equal(result.response.status, 200, JSON.stringify(result.data));
  assert.equal(result.data.order.amountVnd, 40000);
  assert.equal((await grant(9201)).remainingUses, 1);
  assert.equal((await grant(9202)).reservedUses, 1);
  result = await post('order/update', {token, items});
  assert.equal(result.response.status, 200);
  assert.equal(result.data.order.amountVnd, 60000);
  assert.equal((await grant(9202)).remainingUses, 1);
  result = await post('order/update', {token, items, promoGrantId: 9201});
  assert.equal(result.response.status, 200);

  // Unavailable items, another customer's grant, and insert failures roll back
  // both the order snapshot and the previous promo reservation.
  result = await post('order/update', {token, items: [{itemId: 'missing', quantity: 1}], promoGrantId: 9202});
  assert.equal(result.response.status, 409);
  result = await post('order/update', {token, items, promoGrantId: 9201}, {Cookie: otherCookie});
  assert.equal(result.response.status, 403);
  result = await post('order/update', {token, items, promoGrantId: 9201}, {});
  assert.equal(result.response.status, 401);
  result = await post('order/update', {token, items: [{itemId: 'cola', quantity: 19}], promoGrantId: 9202});
  assert.equal(result.response.status, 500);
  assert.equal((await grant(9201)).reservedUses, 1);
  assert.equal((await grant(9202)).remainingUses, 1);
  const pending = await adminOrder(initial.orderCode);
  assert.equal(pending.amountVnd, 50000);
  assert.match(pending.itemName, /2 × Cola/);

  // Staff confirmation wins against later edits/cancellation. Repeated paid
  // confirmations consume exactly one use; no paid snapshot is overwritten.
  let stale = await jsonRequest('/api/admin/menu/order/paid', {id: pending.id, revision: 0}, {Cookie: adminCookie});
  assert.equal(stale.status, 409);
  let response = await jsonRequest('/api/admin/menu/order/paid', {id: pending.id, revision: pending.checkoutRevision}, {Cookie: adminCookie});
  assert.equal(response.status, 200);
  response = await jsonRequest('/api/admin/menu/order/paid', {id: pending.id, revision: pending.checkoutRevision}, {Cookie: adminCookie});
  assert.equal(response.status, 200);
  result = await post('order/update', {token, items: [{itemId: 'cola', quantity: 4}], promoGrantId: 9202});
  assert.equal(result.response.status, 409);
  result = await post('order/cancel', {token});
  assert.equal(result.response.status, 409);
  assert.equal((await grant(9201)).usedUses, 1);
  assert.equal((await grant(9201)).reservedUses, 0);
  const paid = await adminOrder(initial.orderCode);
  assert.equal(paid.status, 'paid');
  assert.equal(paid.amountVnd, 50000);
  assert.match(paid.itemName, /2 × Cola/);

  const cancelToken = randomBytes(32).toString('base64url');
  result = await post('order', {token: cancelToken, items, promoGrantId: 9202});
  assert.equal(result.response.status, 201);
  const cancelled = await Promise.all([post('order/cancel', {token: cancelToken}), post('order/cancel', {token: cancelToken})]);
  assert.deepEqual(cancelled.map(r => r.response.status), [200, 200]);
  assert.equal((await adminOrder(result.data.order.orderCode)).status, 'cancelled');
  result = await post('order/cancel', {token: randomBytes(32).toString('base64url')});
  assert.equal(result.response.status, 404);
  assert.equal((await grant(9202)).reservedUses, 0);
  assert.equal((await grant(9202)).remainingUses, 1);
  result = await post('order/update', {token: cancelToken, items});
  assert.equal(result.response.status, 409);

  // A campaign with one remaining use may be reserved by only one order.
  const limited = await Promise.all([
    post('order', {items, promoGrantId: 9203}),
    post('order', {items, promoGrantId: 9204}, {Cookie: otherCookie}),
  ]);
  assert.deepEqual(limited.map(r => r.response.status).sort(), [201, 409]);
  const winner = limited.find(r => r.response.status === 201).data.order;
  const winnerCookie = winner.promoGrantId === 9203 ? headers : {Cookie: otherCookie};
  result = await post('order/update', {token: winner.token, items: [{itemId: 'cola', quantity: 3}],
    promoGrantId: winner.promoGrantId}, winnerCookie);
  assert.equal(result.response.status, 200); // Own reservation isn't the campaign cap.
  await post('order/cancel', {token: winner.token}, winnerCookie);

  // If the post-payment promo consumption was interrupted, wallet cleanup
  // repairs the paid reservation by status, without waiting for a deadline.
  const recoveryToken = randomBytes(32).toString('base64url');
  result = await post('order', {token: recoveryToken, items, promoGrantId: 9202});
  assert.equal(result.response.status, 201);
  const recoveryHash = createHash('sha256').update(recoveryToken).digest('base64url');
  const recoveryFile = path.join(persistDir, 'paid-promo-recovery.sql');
  writeFileSync(recoveryFile, `UPDATE menu_orders SET status = 'paid',
    paid_at = ${Math.floor(Date.now() / 1000)} WHERE public_token_hash = ${sqlString(recoveryHash)};`);
  await runWrangler(['d1', 'execute', 'evil-space', '--local', '--persist-to', persistDir, '--file', recoveryFile]);
  await Promise.all([wallet(), wallet()]);
  assert.equal((await grant(9202)).reservedUses, 0);
  assert.equal((await grant(9202)).usedUses, 1);

  // Deleting a configured line keeps the other variant and reprices the
  // existing payment; removing the final line cancels it.
  const variants = [
    {itemId: 'americano', quantity: 2, options: {extras: ['milk']}},
    {itemId: 'americano', quantity: 1, options: {extras: []}},
  ];
  result = await post('order', {items: variants});
  assert.equal(result.response.status, 201);
  const variantsOrder = result.data.order;
  assert.equal(variantsOrder.items.length, 2);
  assert.equal(variantsOrder.amountVnd, 145000);
  result = await post('order/update', {token: variantsOrder.token, items: [variants[1]]});
  assert.equal(result.response.status, 200);
  assert.equal(result.data.order.paymentMessage, variantsOrder.paymentMessage);
  assert.equal(result.data.order.items.length, 1);
  assert.equal(result.data.order.amountVnd, 45000);
  assert.deepEqual(result.data.order.items[0].selection.extras, []);
  const remainingOrder = await adminOrder(variantsOrder.orderCode);
  assert.equal(remainingOrder.amountVnd, 45000);
  assert.doesNotMatch(remainingOrder.itemName, /Milk/);
  result = await post('order/cancel', {token: variantsOrder.token});
  assert.equal(result.response.status, 200);
  assert.equal((await adminOrder(variantsOrder.orderCode)).status, 'cancelled');

  const snapshotResponse = await http('/api/admin/menu', {headers: {Cookie: adminCookie}});
  const allOrders = (await snapshotResponse.json()).snapshot.orders;
  assert.equal(allOrders.filter(o => o.orderCode === initial.orderCode).length, 1);
  console.log('Integration: live cart retry, repricing, promo switching, rollback and confirmation passed');
}

async function http(pathname, options = {}) {
  return fetch(`${baseUrl}${pathname}`, {
    ...options,
    signal: AbortSignal.timeout(10000),
  });
}

async function jsonRequest(pathname, body, headers = {}) {
  return http(pathname, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: baseUrl,
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function removePathWithRetry(target, { required = false } = {}) {
  let lastError = null;
  const attempts = process.platform === 'win32' ? 30 : 5;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      rmSync(target, {
        recursive: true,
        force: true,
        maxRetries: 3,
        retryDelay: 100,
      });
      return;
    } catch (error) {
      lastError = error;
      const code = String(error?.code ?? '');
      if (!['EPERM', 'EBUSY', 'ENOTEMPTY'].includes(code)) break;
      await delay(100 + attempt * 50);
    }
  }

  if (required && lastError) throw lastError;
  if (lastError) {
    console.warn(
      `Integration cleanup warning: could not remove ${target}: ${lastError.message ?? lastError}`,
    );
  }
}

function nhaTrangDateKey() {
  return new Date(Date.now() + 7 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

async function stopDev() {
  if (!dev || dev.exitCode !== null) return;
  killProcessTree(dev);
  for (let attempt = 0; attempt < 30 && dev.exitCode === null; attempt += 1) {
    await delay(100);
  }
}

function killProcessTree(child) {
  if (!child || child.exitCode !== null) return;
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/pid', String(child.pid), '/T', '/F'], {
      stdio: 'ignore',
      timeout: 10000,
    });
    return;
  }
  try {
    process.kill(-child.pid, 'SIGKILL');
  } catch {
    try {
      child.kill('SIGKILL');
    } catch {}
  }
}
