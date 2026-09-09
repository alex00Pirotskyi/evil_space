CREATE TABLE IF NOT EXISTS menu_catalogs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  version INTEGER NOT NULL,
  source_json TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1)),
  created_at INTEGER NOT NULL,
  created_by_email TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_catalogs_active
  ON menu_catalogs(active)
  WHERE active = 1;

CREATE TABLE IF NOT EXISTS menu_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  catalog_id INTEGER NOT NULL,
  group_key TEXT NOT NULL,
  group_name TEXT NOT NULL,
  group_order INTEGER NOT NULL,
  item_key TEXT NOT NULL,
  name TEXT NOT NULL,
  price_vnd INTEGER NOT NULL CHECK (price_vnd > 0),
  description TEXT,
  item_order INTEGER NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  FOREIGN KEY (catalog_id) REFERENCES menu_catalogs(id) ON DELETE CASCADE,
  UNIQUE (catalog_id, item_key)
);

CREATE INDEX IF NOT EXISTS idx_menu_items_catalog_order
  ON menu_items(catalog_id, group_order, item_order, id);

CREATE TABLE IF NOT EXISTS menu_group_translations (
  catalog_id INTEGER NOT NULL,
  group_key TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_ru TEXT NOT NULL,
  name_vi TEXT NOT NULL,
  PRIMARY KEY (catalog_id, group_key),
  FOREIGN KEY (catalog_id) REFERENCES menu_catalogs(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS menu_orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  public_token_hash TEXT NOT NULL UNIQUE,
  order_code TEXT NOT NULL UNIQUE,
  catalog_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,
  item_key TEXT NOT NULL,
  item_name TEXT NOT NULL,
  amount_vnd INTEGER NOT NULL CHECK (amount_vnd > 0),
  payment_message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'paid', 'expired', 'cancelled')),
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  paid_at INTEGER,
  paid_by_email TEXT,
  paid_by_telegram_user_id INTEGER,
  FOREIGN KEY (catalog_id) REFERENCES menu_catalogs(id),
  FOREIGN KEY (item_id) REFERENCES menu_items(id)
);

CREATE INDEX IF NOT EXISTS idx_menu_orders_status_created
  ON menu_orders(status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_menu_orders_expires
  ON menu_orders(status, expires_at);
