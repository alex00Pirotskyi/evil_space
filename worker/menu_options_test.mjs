import test from 'node:test';
import assert from 'node:assert/strict';

import {
  resolveMenuSelection,
  selectionSignature,
  validateMenuOptions,
} from './menu_options.js';

const coffeeOptions = [
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
    id: 'sugar',
    type: 'dots',
    name: { en: 'Sugar', ru: 'Сахар', vi: 'Đường' },
    min: 0,
    max: 3,
    default: 0,
    pricePerStepVnd: 0,
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
      {
        id: 'syrup',
        name: { en: 'Syrup', ru: 'Сироп', vi: 'Siro' },
        priceDeltaVnd: 10000,
      },
    ],
  },
];

test('validates reusable coffee settings', () => {
  const checked = validateMenuOptions(coffeeOptions);
  assert.equal(checked.error, undefined);
  assert.equal(checked.options.length, 4);
});

test('server calculates configured coffee price from trusted rules', () => {
  const resolved = resolveMenuSelection({
    itemName: 'Americano',
    basePriceVnd: 45000,
    options: coffeeOptions,
    selection: {
      size: 'large',
      strength: 2,
      sugar: 1,
      extras: ['milk'],
    },
  });
  assert.equal(resolved.error, undefined);
  assert.equal(resolved.unitPriceVnd, 85000);
  assert.deepEqual(resolved.selection, {
    size: 'large',
    strength: 2,
    sugar: 1,
    extras: ['milk'],
  });
  assert.match(resolved.displayName, /Americano/);
  assert.match(resolved.displayName, /0\.3 L/);
  assert.match(resolved.displayName, /Milk/);
});

test('required selectors fail closed', () => {
  const energy = [
    {
      id: 'brand',
      type: 'single',
      name: { en: 'Brand', ru: 'Бренд', vi: 'Loại' },
      required: true,
      values: [
        {
          id: 'monster',
          name: { en: 'Monster', ru: 'Monster', vi: 'Monster' },
          priceDeltaVnd: 0,
        },
      ],
    },
  ];
  const missing = resolveMenuSelection({
    itemName: 'Energy Drink',
    basePriceVnd: 45000,
    options: energy,
    selection: {},
  });
  assert.match(missing.error, /Choose/i);
});

test('selection signature separates differently configured copies', () => {
  assert.notEqual(
    selectionSignature('americano', { strength: 1 }),
    selectionSignature('americano', { strength: 2 }),
  );
  assert.equal(
    selectionSignature('americano', { size: 'large', strength: 2 }),
    selectionSignature('americano', { strength: 2, size: 'large' }),
  );
});
