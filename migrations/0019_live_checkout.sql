-- Serialize cart mutations without changing a paid order or its snapshots.
ALTER TABLE menu_orders ADD COLUMN checkout_revision INTEGER NOT NULL DEFAULT 0;
ALTER TABLE menu_orders ADD COLUMN checkout_mutation TEXT;
