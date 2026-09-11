import assert from 'node:assert/strict';
import test from 'node:test';

import { validateDraftMenu } from './menu_builder.js';

const valid = {
  version: 4,
  groups: [
    {
      id: 'coworking',
      name: { en: 'Coworking', ru: 'Коворкинг', vi: 'Coworking' },
      items: [
        {
          id: 'coworking-day',
          name: 'Coworking Day',
          priceVnd: 200000,
          description: 'Full day access',
          enabled: true,
        },
      ],
    },
  ],
};

test('menu builder accepts localized groups and stable ids', () => {
  const result = validateDraftMenu(valid);
  assert.equal(result.error, undefined);
  assert.equal(result.menu.version, 4);
  assert.equal(result.menu.groups[0].id, 'coworking');
  assert.deepEqual(result.menu.groups[0].name, {
    en: 'Coworking',
    ru: 'Коворкинг',
    vi: 'Coworking',
  });
  assert.equal(result.menu.groups[0].items[0].priceVnd, 200000);
});

test('draft may temporarily contain an empty group but publish validation may not', () => {
  const draft = {
    version: 1,
    groups: [
      {
        id: 'drinks',
        name: { en: 'Drinks', ru: 'Напитки', vi: 'Đồ uống' },
        items: [],
      },
    ],
  };
  assert.equal(validateDraftMenu(draft, { allowEmptyGroups: true }).error, undefined);
  assert.match(validateDraftMenu(draft).error, /at least one item/i);
});

test('menu builder rejects duplicate stable item ids', () => {
  const menu = structuredClone(valid);
  menu.groups.push({
    id: 'drinks',
    name: { en: 'Drinks', ru: 'Напитки', vi: 'Đồ uống' },
    items: [{ id: 'coworking-day', name: 'Cola', priceVnd: 25000 }],
  });
  assert.match(validateDraftMenu(menu).error, /duplicate item/i);
});

test('menu builder rejects incomplete translations and invalid prices', () => {
  const missing = structuredClone(valid);
  missing.groups[0].name.vi = '';
  assert.match(validateDraftMenu(missing).error, /localized name|English, Russian and Vietnamese/i);

  const price = structuredClone(valid);
  price.groups[0].items[0].priceVnd = -1;
  assert.match(validateDraftMenu(price).error, /Invalid price/i);
});
