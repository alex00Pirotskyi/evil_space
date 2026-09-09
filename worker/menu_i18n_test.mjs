import test from 'node:test';
import assert from 'node:assert/strict';

import { normalizeMenuGroupNames } from './menu_i18n.js';

test('localized group names preserve en ru vi and feed English to core menu worker', () => {
  const result = normalizeMenuGroupNames({
    version: 1,
    groups: [
      {
        id: 'Drinks',
        name: {
          en: 'Drinks',
          ru: 'Напитки',
          vi: 'Đồ uống',
        },
        items: [],
      },
    ],
  });

  assert.equal(result.workerMenu.groups[0].id, 'drinks');
  assert.equal(result.workerMenu.groups[0].name, 'Drinks');
  assert.deepEqual(result.namesByGroup.get('drinks'), {
    en: 'Drinks',
    ru: 'Напитки',
    vi: 'Đồ uống',
  });
});

test('legacy string group name stays compatible in all languages', () => {
  const result = normalizeMenuGroupNames({
    groups: [{ id: 'snacks', name: 'Snacks', items: [] }],
  });

  assert.deepEqual(result.namesByGroup.get('snacks'), {
    en: 'Snacks',
    ru: 'Snacks',
    vi: 'Snacks',
  });
});

test('localized group name requires en ru and vi', () => {
  assert.throws(
    () =>
      normalizeMenuGroupNames({
        groups: [
          {
            id: 'drinks',
            name: { en: 'Drinks', ru: 'Напитки' },
            items: [],
          },
        ],
      }),
    /localized name/,
  );
});
