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
const buildDir = path.join(repoRoot, 'build');
const buildWebDir = path.join(buildDir, 'web');
const hadBuildWeb = existsSync(buildWebDir);
const port = 8794;
const baseUrl = `http://127.0.0.1:${port}`;
const adminEmail = `ci-${randomBytes(6).toString('hex')}@example.invalid`;
const reviewAdminEmail = `review-${randomBytes(6).toString('hex')}@example.invalid`;
const adminPassword = randomBytes(24).toString('base64url');
const reviewApprovalToken = randomBytes(32).toString('base64url');
const testPaymentAccount = String(randomInt(1000000000, 10000000000));
let dev = null;
let devOutput = '';

try {
  assert.match(wranglerVersion, /^4\.\d+\.\d+$/);
  await removePathWithRetry(persistDir, { required: true });
  mkdirSync(persistDir, { recursive: true });

  if (!hadBuildWeb) {
    mkdirSync(buildWebDir, { recursive: true });
    writeFileSync(
      path.join(buildWebDir, 'index.html'),
      readFileSync(path.join(repoRoot, 'web', 'index.html'), 'utf8'),
    );
    await buildSeo(buildWebDir);
  }

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
  if (!hadBuildWeb) await removePathWithRetry(buildDir);
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
      '--persist-to',
      persistDir,
      '--ip',
      '127.0.0.1',
      '--port',
      String(port),
      '--var',
      `VIETQR_ACCOUNT_NUMBER:${testPaymentAccount}`,
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
      assert.equal(redirect.headers.get('location'), 'https://evils.space/');
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
