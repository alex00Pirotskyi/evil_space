import assert from 'node:assert/strict';
import test from 'node:test';

import { resolvePromoForCart } from './promo_engine.js';

class FakeDb {
  constructor({ grant, groups = [], items = [] }) {
    this.grant = grant;
    this.groups = groups;
    this.items = items;
  }

  prepare(sql) {
    return new FakeStatement(this, sql);
  }
}

class FakeStatement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql;
    this.args = [];
  }

  bind(...args) {
    this.args = args;
    return this;
  }

  async first() {
    if (this.sql.includes('FROM customer_promo_grants g') && this.sql.includes('JOIN marketing_promotions p')) {
      const [grantId, customerId] = this.args;
      if (Number(grantId) !== Number(this.db.grant.id) || Number(customerId) !== Number(this.db.grant.customer_id)) {
        return null;
      }
      return this.db.grant;
    }
    if (this.sql.includes('SELECT COUNT(*) AS count') && this.sql.includes('promo_redemptions')) {
      return { count: 0 };
    }
    return null;
  }

  async all() {
    if (this.sql.includes('FROM promo_redemptions') && this.sql.includes("status = 'reserved'")) {
      return { results: [] };
    }
    if (this.sql.includes('FROM marketing_promotion_groups')) {
      return { results: this.db.groups.map((group_key) => ({ group_key })) };
    }
    if (this.sql.includes('FROM marketing_promotion_items')) {
      return { results: this.db.items };
    }
    return { results: [] };
  }

  async run() {
    return { meta: { changes: 0 } };
  }
}

function environment(overrides = {}) {
  const grant = {
    id: 11,
    customer_id: 7,
    promotion_id: 3,
    granted_uses: 1,
    used_uses: 0,
    reserved_uses: 0,
    status: 'active',
    promo_key: 'WELCOME50',
    revision: 1,
    name: 'Welcome 50%',
    description: 'Welcome',
    discount_type: 'percent',
    discount_value: 50,
    max_discount_vnd: null,
    minimum_subtotal_vnd: 0,
    valid_from: 0,
    expires_at: null,
    max_total_uses: null,
    active: 1,
    ...overrides,
  };
  return {
    evil_space: new FakeDb({
      grant,
      groups: ['coworking'],
      items: [],
    }),
  };
}

const mixedCart = [
  {
    itemKey: 'coworking-day',
    groupKey: 'coworking',
    lineTotalVnd: 200000,
  },
  {
    itemKey: 'cola',
    groupKey: 'drinks',
    lineTotalVnd: 25000,
  },
];

test('50% coworking promo only discounts eligible group lines in a mixed cart', async () => {
  const pricing = await resolvePromoForCart(environment(), 7, 11, mixedCart, 2_000_000_000);
  assert.equal(pricing.error, undefined);
  assert.equal(pricing.originalAmountVnd, 225000);
  assert.equal(pricing.eligibleAmountVnd, 200000);
  assert.equal(pricing.discountVnd, 100000);
  assert.equal(pricing.finalAmountVnd, 125000);
});

test('a customer cannot price an order with somebody elses promo grant', async () => {
  const pricing = await resolvePromoForCart(environment(), 8, 11, mixedCart, 2_000_000_000);
  assert.equal(pricing.error, 'Promo is not available.');
});

test('expired and exhausted promos are rejected server-side', async () => {
  const expired = await resolvePromoForCart(
    environment({ expires_at: 1_999_999_999 }),
    7,
    11,
    mixedCart,
    2_000_000_000,
  );
  assert.equal(expired.error, 'Promo has expired.');

  const exhausted = await resolvePromoForCart(
    environment({ used_uses: 1 }),
    7,
    11,
    mixedCart,
    2_000_000_000,
  );
  assert.equal(exhausted.error, 'Promo has no uses remaining.');
});

test('fixed discount is capped by eligible amount and max discount', async () => {
  const env = environment({
    discount_type: 'fixed_vnd',
    discount_value: 90000,
    max_discount_vnd: 40000,
  });
  const pricing = await resolvePromoForCart(env, 7, 11, mixedCart, 2_000_000_000);
  assert.equal(pricing.discountVnd, 40000);
  assert.equal(pricing.finalAmountVnd, 185000);
});
