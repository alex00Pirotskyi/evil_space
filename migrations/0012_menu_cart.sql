PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS menu_order_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,
  item_key TEXT NOT NULL,
  item_name TEXT NOT NULL,
  unit_price_vnd INTEGER NOT NULL CHECK (unit_price_vnd > 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0 AND quantity <= 20),
  line_total_vnd INTEGER NOT NULL CHECK (line_total_vnd > 0),
  created_at INTEGER NOT NULL,
  FOREIGN KEY (order_id) REFERENCES menu_orders(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES menu_items(id)
);

CREATE INDEX IF NOT EXISTS idx_menu_order_items_order
  ON menu_order_items(order_id, id);

ALTER TABLE menu_orders ADD COLUMN customer_id INTEGER;
ALTER TABLE menu_orders ADD COLUMN device_id TEXT;
