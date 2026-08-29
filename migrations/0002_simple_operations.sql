PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS memberships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  starts_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_memberships_expires_at
  ON memberships(expires_at);

CREATE TABLE IF NOT EXISTS visits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('day', 'month')),
  membership_id INTEGER,
  amount INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  created_by_email TEXT,
  FOREIGN KEY (membership_id) REFERENCES memberships(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_visits_created_at
  ON visits(created_at);

CREATE INDEX IF NOT EXISTS idx_visits_membership_id
  ON visits(membership_id);

CREATE TABLE IF NOT EXISTS purchase_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'needed'
    CHECK (status IN ('needed', 'bought')),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  bought_at INTEGER,
  created_by_email TEXT,
  bought_by_email TEXT
);

CREATE INDEX IF NOT EXISTS idx_purchase_requests_status_created
  ON purchase_requests(status, created_at DESC);
