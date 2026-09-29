PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS menu_item_translations (
  catalog_id INTEGER NOT NULL,
  item_key TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_ru TEXT NOT NULL,
  name_vi TEXT NOT NULL,
  description_en TEXT,
  description_ru TEXT,
  description_vi TEXT,
  PRIMARY KEY (catalog_id, item_key),
  FOREIGN KEY (catalog_id) REFERENCES menu_catalogs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_menu_item_translations_catalog
  ON menu_item_translations(catalog_id, item_key);
