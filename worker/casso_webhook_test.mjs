import test from 'node:test';
import assert from 'node:assert/strict';
import {
  extractOrderCode,
  normalizeCassoTransactions,
  transactionMatchesConfiguredAccount,
} from './casso_webhook.js';

test('extracts EVIL order reference case-insensitively', () => {
  assert.equal(extractOrderCode('MBVCB.123 evil AB2CD3 coffee'), 'AB2CD3');
  assert.equal(extractOrderCode('Transfer: EVIL-XY2Z34'), 'XY2Z34');
  assert.equal(extractOrderCode('EVIL O0I1LZ'), '');
});

test('normalizes Casso webhook transaction', () => {
  const tx = normalizeCassoTransactions({
    error: 0,
    data: [{
      id: 321,
      amount: 75000,
      description: 'EVIL ABC234',
      accountNumber: '0123456789',
      reference: 'FT26001',
      transactionDateTime: '2026-10-07 19:42:00',
    }],
  });
  assert.deepEqual(tx, [{
    transactionId: 'id:321',
    bankReference: 'FT26001',
    amountVnd: 75000,
    description: 'EVIL ABC234',
    orderCode: 'ABC234',
    accountNumber: '0123456789',
    transactionAt: '2026-10-07 19:42:00',
  }]);
});

test('accepts missing provider account but rejects an explicit different account', () => {
  assert.equal(transactionMatchesConfiguredAccount({ accountNumber: '' }, '0123456789'), true);
  assert.equal(transactionMatchesConfiguredAccount({ accountNumber: '0123456789' }, '0123456789'), true);
  assert.equal(transactionMatchesConfiguredAccount({ accountNumber: '9999999999' }, '0123456789'), false);
});
