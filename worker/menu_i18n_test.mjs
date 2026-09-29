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
        items: [
          {
            id: 'Cola',
            name: { en: 'Coca-Cola', ru: 'Кока-Кола', vi: 'Coca-Cola' },
            priceVnd: 25000,
            description: {
              en: 'Cold can',
              ru: 'Холодная банка',
              vi: 'Lon lạnh',
            },
          },
        ],
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
  assert.equal(result.workerMenu.groups[0].items[0].id, 'cola');
  assert.equal(result.workerMenu.groups[0].items[0].name, 'Coca-Cola');
  assert.equal(result.workerMenu.groups[0].items[0].description, 'Cold can');
  assert.deepEqual(result.namesByItem.get('cola'), {
    en: 'Coca-Cola',
    ru: 'Кока-Кола',
    vi: 'Coca-Cola',
  });
  assert.deepEqual(result.descriptionsByItem.get('cola'), {
    en: 'Cold can',
    ru: 'Холодная банка',
    vi: 'Lon lạnh',
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

test('localized item name requires en ru and vi', () => {
  assert.throws(
    () =>
      normalizeMenuGroupNames({
        groups: [
          {
            id: 'drinks',
            name: 'Drinks',
            items: [
              {
                id: 'cola',
                name: { en: 'Cola', ru: 'Кола' },
                priceVnd: 25000,
              },
            ],
          },
        ],
      }),
    /localized name/,
  );
});


test('localized option labels survive English core normalization', () => {
  const result = normalizeMenuGroupNames({
    groups: [
      {
        id: 'coffee',
        name: { en: 'Coffee', ru: 'Кофе', vi: 'Cà phê' },
        items: [
          {
            id: 'americano',
            name: { en: 'Americano', ru: 'Американо', vi: 'Americano' },
            priceVnd: 45000,
            options: [
              {
                id: 'strength',
                type: 'dots',
                name: { en: 'Strength', ru: 'Крепость', vi: 'Độ đậm' },
                min: 1,
                max: 3,
                default: 1,
                pricePerStepVnd: 20000,
              },
            ],
          },
        ],
      },
    ],
  });
  assert.equal(result.workerMenu.groups[0].items[0].name, 'Americano');
  assert.deepEqual(result.workerMenu.groups[0].items[0].options[0].name, {
    en: 'Strength',
    ru: 'Крепость',
    vi: 'Độ đậm',
  });
});
