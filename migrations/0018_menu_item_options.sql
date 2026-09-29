PRAGMA foreign_keys = ON;

ALTER TABLE menu_items ADD COLUMN options_json TEXT;

ALTER TABLE menu_order_items ADD COLUMN selection_json TEXT;
ALTER TABLE menu_order_items ADD COLUMN selection_summary TEXT;
