ALTER TABLE menu_orders ADD COLUMN payment_provider TEXT;
ALTER TABLE menu_orders ADD COLUMN payment_transaction_id TEXT;
ALTER TABLE menu_orders ADD COLUMN payment_bank_reference TEXT;
ALTER TABLE menu_orders ADD COLUMN payment_transaction_at TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_orders_provider_transaction
  ON menu_orders(payment_provider, payment_transaction_id)
  WHERE payment_provider IS NOT NULL AND payment_transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_menu_orders_payment_message_pending
  ON menu_orders(payment_message, status);
