PRAGMA foreign_keys = ON;

ALTER TABLE booking_requests RENAME TO booking_requests_before_telegram;

CREATE TABLE booking_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  contact_type TEXT NOT NULL
    CHECK (contact_type IN ('phone', 'telegram')),
  contact_value TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'new'
    CHECK (status IN ('new', 'processing', 'accepted', 'declined', 'cancelled')),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  handled_at INTEGER,
  handled_by_email TEXT,
  customer_id INTEGER,
  client_token_hash TEXT,
  accepted_visit_id INTEGER
);

INSERT INTO booking_requests (
  id,
  name,
  contact_type,
  contact_value,
  status,
  created_at,
  handled_at,
  handled_by_email,
  customer_id,
  client_token_hash,
  accepted_visit_id
)
SELECT
  id,
  name,
  contact_type,
  contact_value,
  status,
  created_at,
  handled_at,
  handled_by_email,
  customer_id,
  client_token_hash,
  accepted_visit_id
FROM booking_requests_before_telegram;

DROP TABLE booking_requests_before_telegram;

CREATE INDEX IF NOT EXISTS idx_booking_requests_status_created
  ON booking_requests(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_booking_requests_contact
  ON booking_requests(contact_type, contact_value);

CREATE INDEX IF NOT EXISTS idx_booking_requests_client_token_hash
  ON booking_requests(client_token_hash);

CREATE INDEX IF NOT EXISTS idx_booking_requests_accepted_visit_id
  ON booking_requests(accepted_visit_id);

CREATE INDEX IF NOT EXISTS idx_booking_requests_customer_id
  ON booking_requests(customer_id);

CREATE TABLE IF NOT EXISTS admin_telegram_links (
  admin_id INTEGER PRIMARY KEY,
  telegram_user_id INTEGER NOT NULL UNIQUE,
  telegram_chat_id INTEGER NOT NULL,
  telegram_username TEXT NOT NULL DEFAULT '',
  notifications_enabled INTEGER NOT NULL DEFAULT 1,
  booking_notifications INTEGER NOT NULL DEFAULT 1,
  purchase_notifications INTEGER NOT NULL DEFAULT 1,
  linked_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS admin_telegram_link_tokens (
  token_hash TEXT PRIMARY KEY,
  admin_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_admin_telegram_tokens_admin_expires
  ON admin_telegram_link_tokens(admin_id, expires_at);

CREATE TABLE IF NOT EXISTS customer_telegram_links (
  customer_id INTEGER PRIMARY KEY,
  telegram_user_id INTEGER NOT NULL UNIQUE,
  telegram_chat_id INTEGER NOT NULL,
  telegram_username TEXT NOT NULL DEFAULT '',
  linked_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS customer_telegram_link_tokens (
  token_hash TEXT PRIMARY KEY,
  booking_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  FOREIGN KEY (booking_id) REFERENCES booking_requests(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_customer_telegram_tokens_booking_expires
  ON customer_telegram_link_tokens(booking_id, expires_at);

CREATE TABLE IF NOT EXISTS telegram_admin_sessions (
  telegram_user_id INTEGER PRIMARY KEY,
  admin_id INTEGER NOT NULL,
  state TEXT NOT NULL,
  payload_json TEXT NOT NULL DEFAULT '{}',
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS telegram_booking_messages (
  booking_id INTEGER NOT NULL,
  telegram_chat_id INTEGER NOT NULL,
  telegram_message_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (booking_id, telegram_chat_id),
  FOREIGN KEY (booking_id) REFERENCES booking_requests(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS operation_audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER,
  actor_email TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL DEFAULT '',
  entity_id INTEGER,
  detail TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_operation_audit_created
  ON operation_audit(created_at DESC);
