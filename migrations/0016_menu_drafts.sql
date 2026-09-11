PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS menu_drafts (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  source_json TEXT NOT NULL,
  base_catalog_id INTEGER,
  updated_at INTEGER NOT NULL,
  updated_by_email TEXT NOT NULL,
  FOREIGN KEY (base_catalog_id) REFERENCES menu_catalogs(id)
);

CREATE INDEX IF NOT EXISTS idx_menu_drafts_base
  ON menu_drafts(base_catalog_id);
