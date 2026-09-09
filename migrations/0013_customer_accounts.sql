PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS customer_identities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('phone', 'telegram', 'google')),
  provider_subject TEXT NOT NULL,
  display_value TEXT NOT NULL DEFAULT '',
  verified_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  UNIQUE (provider, provider_subject)
);

CREATE INDEX IF NOT EXISTS idx_customer_identities_customer
  ON customer_identities(customer_id, provider);

CREATE TABLE IF NOT EXISTS customer_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_customer_sessions_customer
  ON customer_sessions(customer_id, expires_at);

CREATE INDEX IF NOT EXISTS idx_customer_sessions_expires
  ON customer_sessions(expires_at);

CREATE TABLE IF NOT EXISTS customer_devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  device_id TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT '',
  user_agent TEXT NOT NULL DEFAULT '',
  language TEXT NOT NULL DEFAULT '',
  timezone_offset_minutes INTEGER,
  info_json TEXT NOT NULL DEFAULT '{}',
  first_seen_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  UNIQUE (customer_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_customer_devices_device
  ON customer_devices(device_id, last_seen_at DESC);

CREATE TABLE IF NOT EXISTS customer_signup_tokens (
  token_hash TEXT PRIMARY KEY,
  provider TEXT NOT NULL CHECK (provider IN ('telegram')),
  customer_id INTEGER,
  state TEXT NOT NULL DEFAULT 'pending'
    CHECK (state IN ('pending', 'completed', 'used', 'expired')),
  payload_json TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_customer_signup_tokens_expires
  ON customer_signup_tokens(state, expires_at);

CREATE TABLE IF NOT EXISTS customer_phone_otps (
  challenge_hash TEXT PRIMARY KEY,
  phone_e164 TEXT NOT NULL,
  name TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  device_json TEXT NOT NULL DEFAULT '{}',
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_customer_phone_otps_phone
  ON customer_phone_otps(phone_e164, created_at DESC);
