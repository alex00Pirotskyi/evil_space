PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS marketing_promotions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  promo_key TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  code TEXT,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('percent', 'fixed_vnd')),
  discount_value INTEGER NOT NULL CHECK (discount_value > 0),
  max_discount_vnd INTEGER,
  minimum_subtotal_vnd INTEGER NOT NULL DEFAULT 0 CHECK (minimum_subtotal_vnd >= 0),
  valid_from INTEGER NOT NULL DEFAULT 0,
  expires_at INTEGER,
  max_uses_per_customer INTEGER NOT NULL DEFAULT 1 CHECK (max_uses_per_customer > 0),
  max_total_uses INTEGER,
  distribution_type TEXT NOT NULL DEFAULT 'manual'
    CHECK (distribution_type IN ('signup', 'manual', 'everyone', 'code')),
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
  created_at INTEGER NOT NULL,
  created_by_email TEXT NOT NULL,
  superseded_at INTEGER,
  UNIQUE (promo_key, revision),
  CHECK (discount_type != 'percent' OR discount_value <= 100),
  CHECK (max_discount_vnd IS NULL OR max_discount_vnd > 0),
  CHECK (expires_at IS NULL OR expires_at > valid_from),
  CHECK (max_total_uses IS NULL OR max_total_uses > 0)
);

CREATE INDEX IF NOT EXISTS idx_marketing_promotions_active
  ON marketing_promotions(active, distribution_type, valid_from, expires_at, id DESC);

CREATE INDEX IF NOT EXISTS idx_marketing_promotions_code
  ON marketing_promotions(code, active)
  WHERE code IS NOT NULL;

CREATE TABLE IF NOT EXISTS marketing_promotion_groups (
  promotion_id INTEGER NOT NULL,
  group_key TEXT NOT NULL,
  PRIMARY KEY (promotion_id, group_key),
  FOREIGN KEY (promotion_id) REFERENCES marketing_promotions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_marketing_promotion_groups_group
  ON marketing_promotion_groups(group_key, promotion_id);

CREATE TABLE IF NOT EXISTS marketing_promotion_items (
  promotion_id INTEGER NOT NULL,
  item_key TEXT NOT NULL,
  rule TEXT NOT NULL CHECK (rule IN ('include', 'exclude')),
  PRIMARY KEY (promotion_id, item_key),
  FOREIGN KEY (promotion_id) REFERENCES marketing_promotions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS customer_promo_grants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  promotion_id INTEGER NOT NULL,
  grant_key TEXT,
  source TEXT NOT NULL DEFAULT 'manual',
  granted_uses INTEGER NOT NULL CHECK (granted_uses > 0),
  used_uses INTEGER NOT NULL DEFAULT 0 CHECK (used_uses >= 0),
  reserved_uses INTEGER NOT NULL DEFAULT 0 CHECK (reserved_uses >= 0),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'revoked', 'exhausted')),
  granted_at INTEGER NOT NULL,
  granted_by_email TEXT,
  revoked_at INTEGER,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  FOREIGN KEY (promotion_id) REFERENCES marketing_promotions(id),
  UNIQUE (customer_id, grant_key),
  CHECK (used_uses + reserved_uses <= granted_uses)
);

CREATE INDEX IF NOT EXISTS idx_customer_promo_grants_customer
  ON customer_promo_grants(customer_id, status, id DESC);

CREATE INDEX IF NOT EXISTS idx_customer_promo_grants_promotion
  ON customer_promo_grants(promotion_id, status, id DESC);

CREATE TABLE IF NOT EXISTS promo_redemptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_promo_id INTEGER NOT NULL,
  customer_id INTEGER NOT NULL,
  order_type TEXT NOT NULL CHECK (order_type IN ('menu', 'booking')),
  order_id INTEGER NOT NULL,
  original_amount_vnd INTEGER NOT NULL CHECK (original_amount_vnd > 0),
  eligible_amount_vnd INTEGER NOT NULL CHECK (eligible_amount_vnd >= 0),
  discount_vnd INTEGER NOT NULL CHECK (discount_vnd > 0),
  final_amount_vnd INTEGER NOT NULL CHECK (final_amount_vnd >= 0),
  status TEXT NOT NULL DEFAULT 'reserved'
    CHECK (status IN ('reserved', 'consumed', 'released')),
  reserved_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  consumed_at INTEGER,
  released_at INTEGER,
  FOREIGN KEY (customer_promo_id) REFERENCES customer_promo_grants(id),
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  UNIQUE (order_type, order_id)
);

CREATE INDEX IF NOT EXISTS idx_promo_redemptions_reserved
  ON promo_redemptions(status, expires_at, id);

CREATE INDEX IF NOT EXISTS idx_promo_redemptions_customer
  ON promo_redemptions(customer_id, reserved_at DESC, id DESC);

ALTER TABLE menu_orders ADD COLUMN original_amount_vnd INTEGER;
ALTER TABLE menu_orders ADD COLUMN promo_eligible_amount_vnd INTEGER NOT NULL DEFAULT 0;
ALTER TABLE menu_orders ADD COLUMN promo_discount_vnd INTEGER NOT NULL DEFAULT 0;
ALTER TABLE menu_orders ADD COLUMN promo_grant_id INTEGER;

UPDATE menu_orders
SET original_amount_vnd = amount_vnd
WHERE original_amount_vnd IS NULL;

ALTER TABLE menu_order_items ADD COLUMN group_key TEXT;

UPDATE menu_order_items
SET group_key = (
  SELECT mi.group_key
  FROM menu_items mi
  WHERE mi.id = menu_order_items.item_id
)
WHERE group_key IS NULL;

INSERT INTO marketing_promotions (
  promo_key, revision, name, description, code, discount_type, discount_value,
  max_discount_vnd, minimum_subtotal_vnd, valid_from, expires_at,
  max_uses_per_customer, max_total_uses, distribution_type, active,
  created_at, created_by_email
)
SELECT
  'WELCOME50', 1, 'Welcome 50%', '50% off one eligible coworking purchase after signup',
  NULL, 'percent', 50, NULL, 0, 0, NULL, 1, NULL, 'signup', 1,
  CAST(strftime('%s','now') AS INTEGER), 'system'
WHERE NOT EXISTS (
  SELECT 1 FROM marketing_promotions WHERE promo_key = 'WELCOME50' AND revision = 1
);

INSERT OR IGNORE INTO marketing_promotion_groups (promotion_id, group_key)
SELECT id, 'coworking'
FROM marketing_promotions
WHERE promo_key = 'WELCOME50' AND revision = 1;

INSERT OR IGNORE INTO customer_promo_grants (
  customer_id, promotion_id, grant_key, source, granted_uses,
  used_uses, reserved_uses, status, granted_at, granted_by_email
)
SELECT
  c.id,
  p.id,
  'signup:WELCOME50',
  'signup',
  p.max_uses_per_customer,
  0,
  0,
  'active',
  CAST(strftime('%s','now') AS INTEGER),
  'system'
FROM customers c
JOIN marketing_promotions p
  ON p.promo_key = 'WELCOME50' AND p.revision = 1
WHERE p.active = 1;

CREATE TRIGGER IF NOT EXISTS trg_customer_signup_promos
AFTER INSERT ON customers
BEGIN
  INSERT OR IGNORE INTO customer_promo_grants (
    customer_id, promotion_id, grant_key, source, granted_uses,
    used_uses, reserved_uses, status, granted_at, granted_by_email
  )
  SELECT
    NEW.id,
    p.id,
    'signup:' || p.promo_key,
    'signup',
    p.max_uses_per_customer,
    0,
    0,
    'active',
    CAST(strftime('%s','now') AS INTEGER),
    'system'
  FROM marketing_promotions p
  WHERE p.active = 1
    AND p.superseded_at IS NULL
    AND p.distribution_type = 'signup'
    AND p.valid_from <= CAST(strftime('%s','now') AS INTEGER)
    AND (p.expires_at IS NULL OR p.expires_at > CAST(strftime('%s','now') AS INTEGER));
END;
