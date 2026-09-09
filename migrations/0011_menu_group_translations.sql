CREATE TABLE IF NOT EXISTS menu_group_translations (
  catalog_id INTEGER NOT NULL,
  group_key TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_ru TEXT NOT NULL,
  name_vi TEXT NOT NULL,
  PRIMARY KEY (catalog_id, group_key),
  FOREIGN KEY (catalog_id) REFERENCES menu_catalogs(id) ON DELETE CASCADE
);
