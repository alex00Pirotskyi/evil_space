import assert from 'node:assert/strict';
import {
  VIETCOMBANK_BIN,
  buildVietQrPayload,
  crc16Ccitt,
  crc16Hex,
} from './vietqr.js';

assert.equal(VIETCOMBANK_BIN, '970436');
assert.equal(crc16Ccitt('123456789'), 0x29b1);
assert.equal(crc16Hex('123456789'), '29B1');

const payload = buildVietQrPayload({
  accountNumber: '0123456789',
  amountVnd: 30000,
  description: 'EVIL ABC123',
});

assert.equal(
  payload,
  '00020101021238540010A00000072701240006970436011001234567890208QRIBFTTA53037045405300005802VN62150811EVIL ABC12363045517',
);
assert.match(payload, /5303704/);
assert.match(payload, /540530000/);
assert.match(payload, /62150811EVIL ABC123/);
assert.equal(payload.slice(-8, -4), '6304');
assert.equal(payload.slice(-4), crc16Hex(payload.slice(0, -4)));

assert.throws(
  () =>
    buildVietQrPayload({
      accountNumber: '',
      amountVnd: 30000,
      description: 'EVIL ABC123',
    }),
  /Account number is invalid/,
);

console.log('VietQR tests passed.');
