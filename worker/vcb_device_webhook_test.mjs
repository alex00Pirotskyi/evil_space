import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeDeviceTransaction } from './vcb_device_webhook.js';

const notification = {
  source: 'com.VCB', accountNumber: '0123456789',
  amountVnd: 270000, description: 'EVILABC234#SP#BANKREFERENCE20261014',
  transactionAt: '2026-10-14T12:02:01+07:00',
};
test('VCB screenshot notification normalizes to matching Evil Space code', async () => {
  const actual = await normalizeDeviceTransaction(notification);
  assert.equal(actual.orderCode, 'ABC234');
  assert.equal(actual.amountVnd, 270000);
  assert.equal(actual.accountNumber, '0123456789');
  assert.match(actual.transactionId, /^sha256:[a-f0-9]{64}$/);
});
test('repeated notification uses one stable transaction id', async () => {
  const a = await normalizeDeviceTransaction(notification);
  const b = await normalizeDeviceTransaction({...notification});
  assert.equal(a.transactionId, b.transactionId);
});
test('foreign source, missing order code, and impossible amounts are ignored', async () => {
  assert.equal(await normalizeDeviceTransaction({...notification, source:'com.fake.vcb'}), null);
  assert.equal(await normalizeDeviceTransaction({...notification, description:'Transfer from A'}), null);
  assert.equal(await normalizeDeviceTransaction({...notification, amountVnd:-270000}), null);
  assert.equal(await normalizeDeviceTransaction({...notification, accountNumber:'123'}), null);
});
