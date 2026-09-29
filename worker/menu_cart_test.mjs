import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeCartInput } from './menu_cart.js';

test('cart keeps multiple items and quantities', () => {
  assert.deepEqual(
    normalizeCartInput({
      items: [
        { itemId: 'cola', quantity: 2, options: {} },
        { itemId: 'red-bull', quantity: 1, options: {} },
      ],
    }),
    {
      items: [
        { itemId: 'cola', quantity: 2, options: {} },
        { itemId: 'red-bull', quantity: 1, options: {} },
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
    { items: [{ itemId: 'cola', quantity: 3, options: {} }] },
  );
});

test('legacy single item request remains compatible', () => {
  assert.deepEqual(normalizeCartInput({ itemId: 'cola', priceVnd: 1 }), {
    items: [{ itemId: 'cola', quantity: 1, options: {} }],
  });
});

test('cart rejects unsafe quantities', () => {
  assert.match(normalizeCartInput({ items: [{ itemId: 'cola', quantity: 0 }] }).error, /quantity/i);
  assert.match(normalizeCartInput({ items: [{ itemId: 'cola', quantity: 21 }] }).error, /quantity/i);
});


test('same item with different settings stays as separate cart lines', () => {
  const result = normalizeCartInput({
    items: [
      { itemId: 'americano', quantity: 1, options: { strength: 1 } },
      { itemId: 'americano', quantity: 1, options: { strength: 2 } },
    ],
  });
  assert.equal(result.items.length, 2);
  assert.deepEqual(result.items[0].options, { strength: 1 });
  assert.deepEqual(result.items[1].options, { strength: 2 });
});

test('same configured item is combined', () => {
  assert.deepEqual(
    normalizeCartInput({
      items: [
        { itemId: 'americano', quantity: 1, options: { size: 'large', strength: 2 } },
        { itemId: 'americano', quantity: 2, options: { strength: 2, size: 'large' } },
      ],
    }),
    {
      items: [
        {
          itemId: 'americano',
          quantity: 3,
          options: { size: 'large', strength: 2 },
        },
      ],
    },
  );
});
