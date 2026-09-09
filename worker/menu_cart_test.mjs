import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeCartInput } from './menu_cart.js';

test('cart keeps multiple items and quantities', () => {
  assert.deepEqual(
    normalizeCartInput({
      items: [
        { itemId: 'cola', quantity: 2 },
        { itemId: 'red-bull', quantity: 1 },
      ],
    }),
    {
      items: [
        { itemId: 'cola', quantity: 2 },
        { itemId: 'red-bull', quantity: 1 },
      ],
    },
  );
});

test('duplicate cart lines are combined', () => {
  assert.deepEqual(
    normalizeCartInput({
      items: [
        { itemId: 'cola', quantity: 1 },
        { itemId: 'cola', quantity: 2 },
      ],
    }),
    { items: [{ itemId: 'cola', quantity: 3 }] },
  );
});

test('legacy single item request remains compatible', () => {
  assert.deepEqual(normalizeCartInput({ itemId: 'cola', priceVnd: 1 }), {
    items: [{ itemId: 'cola', quantity: 1 }],
  });
});

test('cart rejects unsafe quantities', () => {
  assert.match(normalizeCartInput({ items: [{ itemId: 'cola', quantity: 0 }] }).error, /quantity/i);
  assert.match(normalizeCartInput({ items: [{ itemId: 'cola', quantity: 21 }] }).error, /quantity/i);
});
