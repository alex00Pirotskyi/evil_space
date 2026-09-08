import assert from 'node:assert/strict';
import { pbkdf2Sync, createHash } from 'node:crypto';
import { once } from 'node:events';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const wranglerVersion = readFileSync(
  path.join(repoRoot, 'tool', 'wrangler_version.txt'),
  'utf8',
).trim();
const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';
const persistDir = path.join(repoRoot, '.wrangler', 'integration-test');
const buildDir = path.join(repoRoot, 'build');
const buildWebDir = path.join(buildDir, 'web');
const hadBuildWeb = existsSync(buildWebDir);
const port = 8794;
const baseUrl = `http://127.0.0.1:${port}`;
let dev = null;
let devOutput = '';

try {
  assert.match(wranglerVersion, /^4\.\d+\.\d+$/);
  rmSync(persistDir, { recursive: true, force: true });
  mkdirSync(persistDir, { recursive: true });

  if (!hadBuildWeb) {
    mkdirSync(buildWebDir, { recursive: true });
    writeFileSync(
      path.join(buildWebDir, 'index.html'),
      '<!doctype html><title>Evil Space integration test</title>',
    );
  }

  runWrangler([
    'd1',
    'migrations',
    'apply',
    'evil-space',
    '--local',
    '--persist-to',
    persistDir,
  ]);

  seedAdmins();
  dev = startDev();
  await waitForServer();
  await runFlow();
  console.log('Worker integration flow passed.');
} finally {
  await stopDev();
  rmSync(persistDir, { recursive: true, force: true });
  if (!hadBuildWeb) rmSync(buildDir, { recursive: true, force: true });
}

function wranglerArgs(args) {
  return ['--yes', `wrangler@${wranglerVersion}`, ...args];
}

function runWrangler(args) {
  const result = spawnSync(npx, wranglerArgs(args), {
    cwd: repoRoot,
    encoding: 'utf8',
    env: {
      ...process.env,
      CI: 'true',
      WRANGLER_SEND_METRICS: 'false',
    },
  });
  if (result.status !== 0) {
    throw new Error(
      `Wrangler failed: ${args.join(' ')}\n${result.stdout ?? ''}\n${result.stderr ?? ''}`,
    );
  }
  return result.stdout ?? '';
}

function seedAdmins() {
  const now = Math.floor(Date.now() / 1000);
  const salt = Buffer.alloc(16, 7);
  const saltBase64 = salt.toString('base64');
  const passwordHash = pbkdf2Sync(
    '1234',
    salt,
    50000,
    32,
    'sha256',
  ).toString('base64');
  const reviewToken = reviewApprovalToken();
  const reviewHash = createHash('sha256')
    .update(reviewToken)
    .digest('base64url');

  const sql = `
    DELETE FROM admins WHERE email IN ('ci-admin@evils.space', 'review-admin@evils.space');
    INSERT INTO admins
      (email, password_hash, password_salt, status, approval_token_hash,
       approval_expires_at, created_at, approved_at)
    VALUES
      ('ci-admin@evils.space', ${sqlString(passwordHash)}, ${sqlString(saltBase64)},
       'approved', NULL, NULL, ${now}, ${now});
    INSERT INTO admins
      (email, password_hash, password_salt, status, approval_token_hash,
       approval_expires_at, created_at, approved_at)
    VALUES
      ('review-admin@evils.space', ${sqlString(passwordHash)}, ${sqlString(saltBase64)},
       'pending', ${sqlString(reviewHash)}, ${now + 3600}, ${now}, NULL);
  `;

  runWrangler([
    'd1',
    'execute',
    'evil-space',
    '--local',
    '--persist-to',
    persistDir,
    '--command',
    sql,
  ]);
}

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function reviewApprovalToken() {
  return 'integration-review-token-0123456789-ABCDEFGH';
}

function startDev() {
  const child = spawn(
    npx,
    wranglerArgs([
      'dev',
      '--local',
      '--persist-to',
      persistDir,
      '--ip',
      '127.0.0.1',
      '--port',
      String(port),
      '--log-level',
      'warn',
    ]),
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        CI: 'true',
        WRANGLER_SEND_METRICS: 'false',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  child.stdout.on('data', (chunk) => {
    devOutput += chunk.toString();
  });
  child.stderr.on('data', (chunk) => {
    devOutput += chunk.toString();
  });
  return child;
}

async function waitForServer() {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (dev?.exitCode !== null) {
      throw new Error(`Wrangler dev exited early.\n${devOutput}`);
    }
    try {
      const response = await fetch(`${baseUrl}/api/health`);
      if (response.status === 200) return;
    } catch {}
    await delay(200);
  }
  throw new Error(`Wrangler dev did not become ready.\n${devOutput}`);
}

async function runFlow() {
  let response = await fetch(`${baseUrl}/api/public/not-a-route`);
  assert.equal(response.status, 404);

  response = await fetch(`${baseUrl}/api/admin/operations`);
  assert.equal(response.status, 401);

  response = await jsonRequest('/api/admin/login', {
    email: 'ci-admin@evils.space',
    password: '1234',
  });
  assert.equal(response.status, 200);
  const setCookie = response.headers.get('set-cookie');
  assert.ok(setCookie?.includes('__Host-evil_admin_session='));
  const cookie = setCookie.split(';', 1)[0];

  response = await fetch(`${baseUrl}/api/admin/session`, {
    headers: { Cookie: cookie },
  });
  assert.equal(response.status, 200);
  let payload = await response.json();
  assert.equal(payload.authenticated, true);
  assert.equal(payload.email, 'ci-admin@evils.space');

  response = await fetch(`${baseUrl}/api/public/status`);
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.ok, true);
  assert.ok(Number(payload.status.total) > 0);

  const contactValue = `+8490${Date.now()}`;
  response = await jsonRequest('/api/public/book', {
    name: 'Integration Test',
    contactType: 'phone',
    contactValue,
    serviceDate: nhaTrangDateKey(),
    language: 'en',
  });
  assert.equal(response.status, 201);
  const booking = await response.json();
  assert.equal(booking.ok, true);
  assert.equal(booking.status, 'pending');
  assert.ok(typeof booking.token === 'string' && booking.token.length >= 32);

  response = await fetch(
    `${baseUrl}/api/public/booking?token=${encodeURIComponent(booking.token)}`,
  );
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.status, 'pending');

  response = await fetch(`${baseUrl}/api/admin/operations`, {
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

  response = await fetch(
    `${baseUrl}/api/public/booking?token=${encodeURIComponent(booking.token)}`,
  );
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.status, 'accepted');

  response = await fetch(`${baseUrl}/api/public/status`);
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.ok(Number(payload.status.occupied) >= 1);

  const reviewToken = reviewApprovalToken();
  response = await fetch(
    `${baseUrl}/api/admin/review?token=${encodeURIComponent(reviewToken)}`,
  );
  assert.equal(response.status, 200);
  let html = await response.text();
  assert.match(html, /APPROVE ADMIN/);
  assert.match(html, /REJECT ADMIN/);

  response = await fetch(`${baseUrl}/api/admin/decision`, {
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

  response = await fetch(
    `${baseUrl}/api/admin/review?token=${encodeURIComponent(reviewToken)}`,
  );
  assert.equal(response.status, 404);

  response = await jsonRequest('/api/admin/logout', {}, { Cookie: cookie });
  assert.equal(response.status, 200);

  response = await fetch(`${baseUrl}/api/admin/session`, {
    headers: { Cookie: cookie },
  });
  assert.equal(response.status, 200);
  payload = await response.json();
  assert.equal(payload.authenticated, false);
}

async function jsonRequest(pathname, body, headers = {}) {
  return fetch(`${baseUrl}${pathname}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: baseUrl,
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function nhaTrangDateKey() {
  return new Date(Date.now() + 7 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function stopDev() {
  if (!dev || dev.exitCode !== null) return;
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/pid', String(dev.pid), '/T', '/F'], {
      stdio: 'ignore',
    });
    return;
  }
  dev.kill('SIGTERM');
  await Promise.race([once(dev, 'exit'), delay(3000)]);
  if (dev.exitCode === null) dev.kill('SIGKILL');
}
