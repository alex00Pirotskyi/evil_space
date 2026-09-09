PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS admins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  approval_token_hash TEXT,
  approval_expires_at INTEGER,
  created_at INTEGER NOT NULL,
  approved_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_admins_approval_token
  ON admins(approval_token_hash);

CREATE TABLE IF NOT EXISTS admin_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_token
  ON admin_sessions(token_hash);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires
  ON admin_sessions(expires_at);

CREATE TABLE IF NOT EXISTS site_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  total_desks INTEGER NOT NULL DEFAULT 12,
  occupied_desks INTEGER NOT NULL DEFAULT 5,
  updated_at INTEGER NOT NULL
);

INSERT OR IGNORE INTO site_state (id, total_desks, occupied_desks, updated_at)
VALUES (1, 12, 5, unixepoch());

CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT,
  start_date TEXT,
  end_date TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'paid',
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS purchases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  amount INTEGER,
  status TEXT NOT NULL DEFAULT 'needed',
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);
