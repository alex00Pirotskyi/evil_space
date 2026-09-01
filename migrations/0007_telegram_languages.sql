PRAGMA foreign_keys = ON;

ALTER TABLE admin_telegram_links
  ADD COLUMN language TEXT NOT NULL DEFAULT 'en'
  CHECK (language IN ('en', 'ru', 'vi'));

ALTER TABLE admin_telegram_link_tokens
  ADD COLUMN language TEXT NOT NULL DEFAULT 'en'
  CHECK (language IN ('en', 'ru', 'vi'));

ALTER TABLE customer_telegram_links
  ADD COLUMN language TEXT NOT NULL DEFAULT 'en'
  CHECK (language IN ('en', 'ru', 'vi'));

ALTER TABLE customer_telegram_link_tokens
  ADD COLUMN language TEXT NOT NULL DEFAULT 'en'
  CHECK (language IN ('en', 'ru', 'vi'));

CREATE INDEX IF NOT EXISTS idx_admin_telegram_language
  ON admin_telegram_links(language);

CREATE INDEX IF NOT EXISTS idx_customer_telegram_language
  ON customer_telegram_links(language);
