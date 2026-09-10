import assert from 'node:assert/strict';
import test from 'node:test';

import {
  csrfTokensMatch,
  validateGoogleTokenInfo,
} from './google_account.js';

const now = 2_000_000_000;
const clientId = 'evil-space.apps.googleusercontent.com';
const valid = {
  iss: 'https://accounts.google.com',
  sub: '11223344556677889900',
  aud: clientId,
  exp: String(now + 300),
  email_verified: 'true',
  email: 'member@example.com',
};

test('Google token info accepts a valid Google ID token', () => {
  assert.equal(validateGoogleTokenInfo(valid, clientId, now), true);
  assert.equal(
    validateGoogleTokenInfo({ ...valid, iss: 'accounts.google.com' }, clientId, now),
    true,
  );
});

test('Google token info rejects wrong audience', () => {
  assert.equal(
    validateGoogleTokenInfo({ ...valid, aud: 'other-client' }, clientId, now),
    false,
  );
});

test('Google token info rejects wrong issuer', () => {
  assert.equal(
    validateGoogleTokenInfo({ ...valid, iss: 'https://example.com' }, clientId, now),
    false,
  );
});

test('Google token info rejects expired credentials', () => {
  assert.equal(
    validateGoogleTokenInfo({ ...valid, exp: String(now) }, clientId, now),
    false,
  );
});

test('Google token info requires a verified email and subject', () => {
  assert.equal(
    validateGoogleTokenInfo({ ...valid, email_verified: 'false' }, clientId, now),
    false,
  );
  assert.equal(
    validateGoogleTokenInfo({ ...valid, email: '' }, clientId, now),
    false,
  );
  assert.equal(
    validateGoogleTokenInfo({ ...valid, sub: '' }, clientId, now),
    false,
  );
});

test('Google redirect accepts only matching CSRF cookie and form token', () => {
  const token = 'csrf-token-1234567890';
  assert.equal(csrfTokensMatch(token, token), true);
  assert.equal(csrfTokensMatch(token, 'csrf-token-xxxxxxxxxx'), false);
  assert.equal(csrfTokensMatch('', ''), false);
  assert.equal(csrfTokensMatch(token, ''), false);
});
