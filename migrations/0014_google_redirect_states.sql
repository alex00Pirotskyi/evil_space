PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS customer_google_redirect_states (
  state_digest TEXT PRIMARY KEY,
  customer_id INTEGER,
  device_json TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_customer_google_redirect_states_expires
  ON customer_google_redirect_states(expires_at, used_at);
