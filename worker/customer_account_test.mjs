import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeVietnamPhone, sanitizeDeviceProfile } from './customer_account.js';

test('Vietnam phone numbers normalize to E.164', () => {
  assert.equal(normalizeVietnamPhone('090 123 4567'), '+84901234567');
  assert.equal(normalizeVietnamPhone('84 901234567'), '+84901234567');
  assert.equal(normalizeVietnamPhone('+84 901 234 567'), '+84901234567');
  assert.equal(normalizeVietnamPhone('123'), '');
});

test('device profile keeps bounded useful browser metadata', () => {
  const device = sanitizeDeviceProfile({
    deviceId: 'device_1234567890abcdef',
    platform: 'Windows',
    userAgent: 'Browser/1.0',
    language: 'en-US',
    timezoneOffsetMinutes: -420,
    screenWidth: 1920,
    screenHeight: 1080,
    viewportWidth: 1500,
    viewportHeight: 900,
    pixelRatio: 1.25,
    touchPoints: 0,
    hardwareConcurrency: 16,
    vendor: 'Example',
    referrer: 'https://example.com/',
    canvasFingerprint: 'must-not-be-kept',
  });

  assert.equal(device.deviceId, 'device_1234567890abcdef');
  assert.equal(device.platform, 'Windows');
  assert.equal(device.hardwareConcurrency, 16);
  assert.equal('canvasFingerprint' in device, false);
});

test('device profile requires a stable first-party random id', () => {
  assert.equal(sanitizeDeviceProfile({ deviceId: 'short' }), null);
});
